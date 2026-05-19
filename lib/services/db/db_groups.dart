import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:shared_preferences/shared_preferences.dart';
import '../mongodb_service.dart';
import 'db_connection.dart';

class DbGroupsService {
  final DbConnectionService _connection;
  DbGroupsService(this._connection);

  /// Helper to convert custom MongoDB values (like ObjectId and DateTime) into JSON-safe types
  Map<String, dynamic> _serializeMongoMap(Map<String, dynamic> document) {
    final copy = Map<String, dynamic>.from(document);
    copy.forEach((key, value) {
      if (value is DateTime) {
        copy[key] = value.toIso8601String();
      } else if (value is mongo.ObjectId) {
        copy[key] = value.toHexString();
      } else if (value is Map) {
        copy[key] = _serializeMongoMap(Map<String, dynamic>.from(value));
      }
    });
    return copy;
  }

  /// Fetch user group (reads from local cache first, syncs in background if > 5 min old)
  Future<Map<String, dynamic>?> getUserGroup(String email) async {
    final cleanEmail = email.toLowerCase().trim();
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Read cached group
    final cacheKey = 'local_group_$cleanEmail';
    final cachedJson = prefs.getString(cacheKey);
    Map<String, dynamic>? cachedGroup;
    if (cachedJson != null && cachedJson != 'null') {
      try {
        cachedGroup = Map<String, dynamic>.from(jsonDecode(cachedJson));
      } catch (_) {}
    }
    
    // 2. Check if stale
    final lastFetchKey = 'last_group_fetch_$cleanEmail';
    final lastFetchTime = prefs.getInt(lastFetchKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final isStale = (now - lastFetchTime) > 300000; // 5 minutes
    
    if (kIsWeb) {
      return cachedGroup;
    }
    
    if (isStale) {
      _triggerBackgroundGroupSync(cleanEmail);
    }
    
    // Return cached group instantly if exists
    if (cachedGroup != null) {
      return cachedGroup;
    }
    
    return await _fetchAndCacheGroup(cleanEmail);
  }

  /// Sync group state with remote MongoDB
  Future<Map<String, dynamic>?> _fetchAndCacheGroup(String email) async {
    final cleanEmail = email.toLowerCase().trim();
    try {
      await _connection.ensureConnected();
      if (!_connection.isConnected || _connection.db == null) return null;
      final coll = _connection.db!.collection('groups');
      final group = await coll.findOne(mongo.where.eq('members', cleanEmail));
      
      final prefs = await SharedPreferences.getInstance();
      if (group != null) {
        final parsed = _serializeMongoMap(Map<String, dynamic>.from(group));
        await prefs.setString('local_group_$cleanEmail', jsonEncode(parsed));
      } else {
        await prefs.setString('local_group_$cleanEmail', 'null');
      }
      await prefs.setInt('last_group_fetch_$cleanEmail', DateTime.now().millisecondsSinceEpoch);
      
      return group != null ? _serializeMongoMap(Map<String, dynamic>.from(group)) : null;
    } catch (e) {
      debugPrint('Sync group fetch failed: $e');
      return null;
    }
  }

  /// Silent background group updates
  void _triggerBackgroundGroupSync(String email) {
    Future.microtask(() async {
      await _fetchAndCacheGroup(email);
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
      await _connection.ensureConnected();
      if (!_connection.isConnected || _connection.db == null) return [];
      final coll = _connection.db!.collection('groups');
      final list = await coll.find(mongo.where.eq('pendingInvites', cleanEmail)).toList();
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
      'createdAt': DateTime.now().toIso8601String(),
    };

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final existingGroup = await getUserGroup(cleanEmail);
        if (existingGroup != null) {
          return {'success': false, 'message': 'You are already in a Family Group'};
        }

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
      await _connection.ensureConnected();
      if (!_connection.isConnected || _connection.db == null) {
        return {'success': false, 'message': 'Database not connected'};
      }

      final coll = _connection.db!.collection('groups');
      final existingGroup = await coll.findOne(mongo.where.eq('members', cleanEmail));
      if (existingGroup != null) {
        return {'success': false, 'message': 'You are already in a Family Group'};
      }

      await coll.insertOne(group);
      
      // Invalidate group cache immediately
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_group_fetch_$cleanEmail');
      _triggerBackgroundGroupSync(cleanEmail);
      
      return {'success': true, 'message': 'Family Group created successfully', 'group': group};
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

        final userExistingGroup = await getUserGroup(cleanEmail);
        if (userExistingGroup != null) {
          return {'success': false, 'message': 'This user is already a member of another Family Group'};
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
      await _connection.ensureConnected();
      if (!_connection.isConnected || _connection.db == null) return {'success': false, 'message': 'Database not connected'};
      final coll = _connection.db!.collection('groups');
      final group = await coll.findOne(mongo.where.eq('id', groupId));
      if (group == null) {
        return {'success': false, 'message': 'Group not found'};
      }

      final members = List<String>.from(group['members'] ?? []);
      final pending = List<String>.from(group['pendingInvites'] ?? []);

      if (members.contains(cleanEmail)) {
        return {'success': false, 'message': 'User is already a member of this group'};
      }

      if (pending.contains(cleanEmail)) {
        return {'success': false, 'message': 'User already has a pending invite'};
      }

      final userExistingGroup = await coll.findOne(mongo.where.eq('members', cleanEmail));
      if (userExistingGroup != null) {
        return {'success': false, 'message': 'This user is already a member of another Family Group'};
      }

      await coll.updateOne(
        mongo.where.eq('id', groupId),
        mongo.modify.push('pendingInvites', cleanEmail),
      );
      
      // Invalidate cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_group_fetch_$cleanEmail');
      _triggerBackgroundGroupSync(cleanEmail);
      
      return {'success': true, 'message': 'Invite sent successfully'};
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
      await _connection.ensureConnected();
      if (!_connection.isConnected || _connection.db == null) return {'success': false, 'message': 'Database not connected'};
      final coll = _connection.db!.collection('groups');
      
      await coll.updateOne(
        mongo.where.eq('id', groupId),
        mongo.modify.pull('pendingInvites', cleanEmail),
      );
      await coll.updateOne(
        mongo.where.eq('id', groupId),
        mongo.modify.push('members', cleanEmail),
      );

      // Invalidate cache immediately
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_group_fetch_$cleanEmail');
      _triggerBackgroundGroupSync(cleanEmail);
      
      return {'success': true, 'message': 'Joined Family Group successfully!'};
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
      await _connection.ensureConnected();
      if (!_connection.isConnected || _connection.db == null) return {'success': false, 'message': 'Database not connected'};
      final coll = _connection.db!.collection('groups');
      await coll.updateOne(
        mongo.where.eq('id', groupId),
        mongo.modify.pull('pendingInvites', cleanEmail),
      );
      
      // Invalidate cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_group_fetch_$cleanEmail');
      _triggerBackgroundGroupSync(cleanEmail);
      
      return {'success': true, 'message': 'Invite declined'};
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
      await _connection.ensureConnected();
      if (!_connection.isConnected || _connection.db == null) return {'success': false, 'message': 'Database not connected'};
      final coll = _connection.db!.collection('groups');
      final group = await coll.findOne(mongo.where.eq('id', groupId));
      if (group == null) {
        return {'success': false, 'message': 'Group not found'};
      }

      if (group['ownerEmail'] == cleanEmail) {
        await coll.remove(mongo.where.eq('id', groupId));
      } else {
        await coll.updateOne(
          mongo.where.eq('id', groupId),
          mongo.modify.pull('members', cleanEmail),
        );
      }
      
      // Invalidate cache immediately on departure/disband
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_group_fetch_$cleanEmail');
      _triggerBackgroundGroupSync(cleanEmail);
      
      return {
        'success': true,
        'message': group['ownerEmail'] == cleanEmail 
            ? 'Family Group disbanded successfully' 
            : 'Left Family Group successfully'
      };
    } catch (e) {
      return {'success': false, 'message': 'Leave group failed: $e'};
    }
  }
}
