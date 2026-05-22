import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../mongodb_service.dart';
import 'db_connection.dart';
import '../api_service.dart';

class DbGroupsService {
  DbGroupsService(DbConnectionService connection);

  /// Helper to convert custom MongoDB values (like ObjectId and DateTime) into JSON-safe types
  Map<String, dynamic> _serializeMongoMap(Map<String, dynamic> document) {
    final copy = Map<String, dynamic>.from(document);
    copy.forEach((key, value) {
      if (value is DateTime) {
        copy[key] = value.toIso8601String();
      } else if (value is Map) {
        copy[key] = _serializeMongoMap(Map<String, dynamic>.from(value));
      }
    });
    return copy;
  }

  /// Fetch user groups (reads from local cache first, syncs in background if > 5 min old)
  Future<List<Map<String, dynamic>>> getUserGroups(String email) async {
    final cleanEmail = email.toLowerCase().trim();
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Read cached groups
    final cacheKey = 'local_groups_$cleanEmail';
    final cachedJson = prefs.getString(cacheKey);
    List<Map<String, dynamic>> cachedGroups = [];
    if (cachedJson != null && cachedJson != 'null') {
      try {
        final decoded = List<dynamic>.from(jsonDecode(cachedJson));
        cachedGroups = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }
    
    // 2. Check if stale
    final lastFetchKey = 'last_group_fetch_$cleanEmail';
    final lastFetchTime = prefs.getInt(lastFetchKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final isStale = (now - lastFetchTime) > 300000; // 5 minutes
    
    if (kIsWeb) {
      return cachedGroups;
    }
    
    if (isStale) {
      _triggerBackgroundGroupSync(cleanEmail);
    }
    
    // Return cached groups instantly if they exist
    if (cachedGroups.isNotEmpty) {
      return cachedGroups;
    }
    
    return await _fetchAndCacheGroups(cleanEmail);
  }

  /// Sync groups state with remote MongoDB via REST API
  Future<List<Map<String, dynamic>>> _fetchAndCacheGroups(String email) async {
    final cleanEmail = email.toLowerCase().trim();
    try {
      final list = await ApiService().getUserGroups(cleanEmail);
      
      final prefs = await SharedPreferences.getInstance();
      if (list.isNotEmpty) {
        final parsed = list.map((e) => _serializeMongoMap(Map<String, dynamic>.from(e))).toList();
        await prefs.setString('local_groups_$cleanEmail', jsonEncode(parsed));
      } else {
        await prefs.setString('local_groups_$cleanEmail', '[]');
      }
      await prefs.setInt('last_group_fetch_$cleanEmail', DateTime.now().millisecondsSinceEpoch);
      
      return list.map((e) => _serializeMongoMap(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      debugPrint('Sync groups fetch failed: $e');
      return [];
    }
  }

  /// Silent background group updates
  void _triggerBackgroundGroupSync(String email) {
    Future.microtask(() async {
      await _fetchAndCacheGroups(email);
      // Trigger a silent sync notification to redraw components
      MongoDbService.notifySync(email);
    });
  }

  /// Get pending invites for a user
  Future<List<Map<String, dynamic>>> getInvitesForUser(String email) async {
    final cleanEmail = email.toLowerCase().trim();

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final groupsJson = prefs.getString('web_groups') ?? '[]';
        final groups = List<dynamic>.from(jsonDecode(groupsJson));
        final invites = <Map<String, dynamic>>[];
        for (var g in groups) {
          final group = Map<String, dynamic>.from(g);
          final pending = List<String>.from(group['pendingInvites'] ?? []);
          if (pending.contains(cleanEmail)) {
            invites.add(group);
          }
        }
        return invites;
      } catch (e) {
        debugPrint('Web getInvitesForUser failed: $e');
        return [];
      }
    }

    try {
      final list = await ApiService().getInvitesForUser(cleanEmail);
      final serializedList = list.map((e) => _serializeMongoMap(Map<String, dynamic>.from(e))).toList();
      return serializedList;
    } catch (e) {
      debugPrint('Native getInvitesForUser failed: $e');
      return [];
    }
  }

  /// Create a new family group (forces cache refresh)
  Future<Map<String, dynamic>> createGroup(String name, String ownerEmail) async {
    final cleanEmail = ownerEmail.toLowerCase().trim();
    final groupId = DateTime.now().microsecondsSinceEpoch.toString();
    final group = {
      'id': groupId,
      'name': name.trim(),
      'ownerEmail': cleanEmail,
      'members': [cleanEmail],
      'pendingInvites': <String>[],
      'upiId': '',
      'createdAt': DateTime.now().toIso8601String(),
    };

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final groupsJson = prefs.getString('web_groups') ?? '[]';
        final groups = List<dynamic>.from(jsonDecode(groupsJson));
        groups.add(group);
        await prefs.setString('web_groups', jsonEncode(groups));
        return {'success': true, 'message': 'Family Group created successfully', 'group': group};
      } catch (e) {
        return {'success': false, 'message': 'Web createGroup failed: $e'};
      }
    }

    try {
      final res = await ApiService().createGroup(name.trim(), cleanEmail);
      if (res['success'] == true) {
        // Invalidate group cache immediately
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_group_fetch_$cleanEmail');
        await prefs.remove('local_groups_$cleanEmail');
        _triggerBackgroundGroupSync(cleanEmail);
      }
      return res;
    } catch (e) {
      return {'success': false, 'message': 'Create Group failed: $e'};
    }
  }

  /// Invite a new member
  Future<Map<String, dynamic>> inviteMember(String groupId, String email) async {
    final cleanEmail = email.toLowerCase().trim();

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final groupsJson = prefs.getString('web_groups') ?? '[]';
        final groups = List<dynamic>.from(jsonDecode(groupsJson));
        
        int foundIndex = -1;
        for (int i = 0; i < groups.length; i++) {
          final group = Map<String, dynamic>.from(groups[i]);
          if (group['id'] == groupId) {
            foundIndex = i;
            break;
          }
        }

        if (foundIndex == -1) {
          return {'success': false, 'message': 'Group not found'};
        }

        final group = Map<String, dynamic>.from(groups[foundIndex]);
        final members = List<String>.from(group['members'] ?? []);
        final pending = List<String>.from(group['pendingInvites'] ?? []);

        if (members.contains(cleanEmail)) {
          return {'success': false, 'message': 'User is already a member of this group'};
        }

        if (pending.contains(cleanEmail)) {
          return {'success': false, 'message': 'User already has a pending invite'};
        }

        pending.add(cleanEmail);
        group['pendingInvites'] = pending;
        groups[foundIndex] = group;
        await prefs.setString('web_groups', jsonEncode(groups));
        return {'success': true, 'message': 'Invite sent successfully'};
      } catch (e) {
        return {'success': false, 'message': 'Web invite failed: $e'};
      }
    }

    try {
      final res = await ApiService().inviteMember(groupId, cleanEmail);
      if (res['success'] == true) {
        // Invalidate cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_group_fetch_$cleanEmail');
        await prefs.remove('local_groups_$cleanEmail');
        _triggerBackgroundGroupSync(cleanEmail);
      }
      return res;
    } catch (e) {
      return {'success': false, 'message': 'Invite failed: $e'};
    }
  }

  /// Accept family group invitation (forces cache refresh)
  Future<Map<String, dynamic>> acceptInvite(String groupId, String email) async {
    final cleanEmail = email.toLowerCase().trim();

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final groupsJson = prefs.getString('web_groups') ?? '[]';
        final groups = List<dynamic>.from(jsonDecode(groupsJson));

        int foundIndex = -1;
        for (int i = 0; i < groups.length; i++) {
          final group = Map<String, dynamic>.from(groups[i]);
          if (group['id'] == groupId) {
            foundIndex = i;
            break;
          }
        }

        if (foundIndex == -1) {
          return {'success': false, 'message': 'Group not found'};
        }

        final group = Map<String, dynamic>.from(groups[foundIndex]);
        final members = List<String>.from(group['members'] ?? []);
        final pending = List<String>.from(group['pendingInvites'] ?? []);

        pending.remove(cleanEmail);
        if (!members.contains(cleanEmail)) {
          members.add(cleanEmail);
        }

        group['members'] = members;
        group['pendingInvites'] = pending;
        groups[foundIndex] = group;
        await prefs.setString('web_groups', jsonEncode(groups));
        return {'success': true, 'message': 'Joined Family Group successfully!'};
      } catch (e) {
        return {'success': false, 'message': 'Web acceptInvite failed: $e'};
      }
    }

    try {
      final res = await ApiService().acceptInvite(groupId, cleanEmail);
      if (res['success'] == true) {
        // Invalidate cache immediately
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_group_fetch_$cleanEmail');
        await prefs.remove('local_groups_$cleanEmail');
        _triggerBackgroundGroupSync(cleanEmail);
      }
      return res;
    } catch (e) {
      return {'success': false, 'message': 'Accept invite failed: $e'};
    }
  }

  /// Decline invitation
  Future<Map<String, dynamic>> declineInvite(String groupId, String email) async {
    final cleanEmail = email.toLowerCase().trim();

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final groupsJson = prefs.getString('web_groups') ?? '[]';
        final groups = List<dynamic>.from(jsonDecode(groupsJson));

        int foundIndex = -1;
        for (int i = 0; i < groups.length; i++) {
          final group = Map<String, dynamic>.from(groups[i]);
          if (group['id'] == groupId) {
            foundIndex = i;
            break;
          }
        }

        if (foundIndex == -1) {
          return {'success': false, 'message': 'Group not found'};
        }

        final group = Map<String, dynamic>.from(groups[foundIndex]);
        final pending = List<String>.from(group['pendingInvites'] ?? []);

        pending.remove(cleanEmail);
        group['pendingInvites'] = pending;
        groups[foundIndex] = group;
        await prefs.setString('web_groups', jsonEncode(groups));
        return {'success': true, 'message': 'Invite declined'};
      } catch (e) {
        return {'success': false, 'message': 'Web declineInvite failed: $e'};
      }
    }

    try {
      final res = await ApiService().declineInvite(groupId, cleanEmail);
      if (res['success'] == true) {
        // Invalidate cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_group_fetch_$cleanEmail');
        await prefs.remove('local_groups_$cleanEmail');
        _triggerBackgroundGroupSync(cleanEmail);
      }
      return res;
    } catch (e) {
      return {'success': false, 'message': 'Decline invite failed: $e'};
    }
  }

  /// Leave or disband Family Group (forces cache refresh)
  Future<Map<String, dynamic>> leaveGroup(String groupId, String email) async {
    final cleanEmail = email.toLowerCase().trim();

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final groupsJson = prefs.getString('web_groups') ?? '[]';
        final groups = List<dynamic>.from(jsonDecode(groupsJson));

        int foundIndex = -1;
        for (int i = 0; i < groups.length; i++) {
          final group = Map<String, dynamic>.from(groups[i]);
          if (group['id'] == groupId) {
            foundIndex = i;
            break;
          }
        }

        if (foundIndex == -1) {
          return {'success': false, 'message': 'Group not found'};
        }

        final group = Map<String, dynamic>.from(groups[foundIndex]);
        
        if (group['ownerEmail'] == cleanEmail) {
          groups.removeAt(foundIndex);
          await prefs.setString('web_groups', jsonEncode(groups));
          return {'success': true, 'message': 'Family Group disbanded successfully'};
        } else {
          final members = List<String>.from(group['members'] ?? []);
          members.remove(cleanEmail);
          group['members'] = members;
          groups[foundIndex] = group;
          await prefs.setString('web_groups', jsonEncode(groups));
          return {'success': true, 'message': 'Left Family Group successfully'};
        }
      } catch (e) {
        return {'success': false, 'message': 'Web leaveGroup failed: $e'};
      }
    }

    try {
      final res = await ApiService().leaveGroup(groupId, cleanEmail);
      if (res['success'] == true) {
        // Invalidate cache immediately on departure/disband
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_group_fetch_$cleanEmail');
        await prefs.remove('local_groups_$cleanEmail');
        _triggerBackgroundGroupSync(cleanEmail);
      }
      return res;
    } catch (e) {
      return {'success': false, 'message': 'Leave group failed: $e'};
    }
  }

  /// Update the UPI ID for a family group (payment settings)
  Future<Map<String, dynamic>> updateGroupUpiId(String groupId, String upiId, String email) async {
    final cleanEmail = email.toLowerCase().trim();

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final groupsJson = prefs.getString('web_groups') ?? '[]';
        final groups = List<dynamic>.from(jsonDecode(groupsJson));
        int foundIndex = -1;
        for (int i = 0; i < groups.length; i++) {
          final group = Map<String, dynamic>.from(groups[i]);
          if (group['id'] == groupId) {
            foundIndex = i;
            break;
          }
        }
        if (foundIndex == -1) {
          return {'success': false, 'message': 'Group not found'};
        }
        groups[foundIndex]['upiId'] = upiId.trim();
        await prefs.setString('web_groups', jsonEncode(groups));
        return {'success': true, 'message': 'UPI ID updated successfully'};
      } catch (e) {
        return {'success': false, 'message': 'Web update UPI ID failed: $e'};
      }
    }

    try {
      final res = await ApiService().updateGroupUpiId(groupId, upiId, cleanEmail);
      if (res['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_group_fetch_$cleanEmail');
        await prefs.remove('local_groups_$cleanEmail');
        _triggerBackgroundGroupSync(cleanEmail);
      }
      return res;
    } catch (e) {
      return {'success': false, 'message': 'Update UPI ID failed: $e'};
    }
  }
}
