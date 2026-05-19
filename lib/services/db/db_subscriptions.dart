import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:shared_preferences/shared_preferences.dart';
import '../mongodb_service.dart';
import 'db_connection.dart';

class DbSubscriptionsService {
  final DbConnectionService _connection;
  DbSubscriptionsService(this._connection);

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

  /// Internal utility to find user groups without circular dependencies
  Future<Map<String, dynamic>?> _getUserGroup(String email) async {
    final cleanEmail = email.toLowerCase().trim();
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final groupsJson = prefs.getString('web_groups') ?? '[]';
      final groups = List<dynamic>.from(jsonDecode(groupsJson));
      for (var g in groups) {
        final group = Map<String, dynamic>.from(g);
        final members = List<String>.from(group['members'] ?? []);
        if (members.contains(cleanEmail) || group['ownerEmail'] == cleanEmail) {
          return group;
        }
      }
      return null;
    }

    await _connection.ensureConnected();
    if (!_connection.isConnected || _connection.db == null) return null;
    final coll = _connection.db!.collection('groups');
    final group = await coll.findOne(mongo.where.eq('members', cleanEmail));
    return group != null ? _serializeMongoMap(Map<String, dynamic>.from(group)) : null;
  }

  /// Unified retrieval: reads from local cache first, then syncs in background if stale (> 5 min)
  Future<List<Map<String, dynamic>>> getSubscriptions(String email) async {
    final cleanEmail = email.toLowerCase().trim();
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Read from local cache first
    final cacheKey = 'local_subs_$cleanEmail';
    final cachedJson = prefs.getString(cacheKey);
    List<Map<String, dynamic>> cachedList = [];
    if (cachedJson != null) {
      try {
        final decoded = List<dynamic>.from(jsonDecode(cachedJson));
        cachedList = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (e) {
        debugPrint('Error parsing cached subscriptions: $e');
      }
    }
    
    // 2. Check if cache is stale (older than 5 minutes)
    final lastFetchKey = 'last_fetch_$cleanEmail';
    final lastFetchTime = prefs.getInt(lastFetchKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final isStale = (now - lastFetchTime) > 300000; // 5 minutes in milliseconds
    
    if (kIsWeb) {
      return cachedList;
    }
    
    if (isStale) {
      _triggerBackgroundSync(cleanEmail);
    }
    
    // If cached data exists, return it instantly (0ms load!)
    if (cachedList.isNotEmpty) {
      return cachedList;
    }
    
    // Fallback: if cache is empty, we must fetch synchronously the first time
    return await _fetchAndCache(cleanEmail);
  }

  /// Fetch from remote MongoDB and overwrite local cache with standard serialized formats
  Future<List<Map<String, dynamic>>> _fetchAndCache(String email) async {
    final cleanEmail = email.toLowerCase().trim();
    try {
      await _connection.ensureConnected();
      if (!_connection.isConnected || _connection.db == null) return [];
      
      String? userGroupId;
      final group = await _getUserGroup(cleanEmail);
      if (group != null) {
        userGroupId = group['id']?.toString();
      }

      final coll = _connection.db!.collection('subscriptions');
      mongo.SelectorBuilder selector;
      if (userGroupId != null) {
        selector = mongo.where.eq('email', cleanEmail).or(mongo.where.eq('groupId', userGroupId));
      } else {
        selector = mongo.where.eq('email', cleanEmail);
      }
      
      final list = await coll.find(selector).toList();
      final freshList = list.map((e) => _serializeMongoMap(Map<String, dynamic>.from(e))).toList();
      
      // Save safely to local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_subs_$cleanEmail', jsonEncode(freshList));
      await prefs.setInt('last_fetch_$cleanEmail', DateTime.now().millisecondsSinceEpoch);
      
      return freshList;
    } catch (e) {
      debugPrint('Remote subscriptions fetch failed: $e');
      return [];
    }
  }

  /// Silent background sync execution
  void _triggerBackgroundSync(String email) {
    Future.microtask(() async {
      final freshList = await _fetchAndCache(email);
      if (freshList.isNotEmpty) {
        // Notify active controllers that new cache is loaded
        MongoDbService.notifySync(email);
      }
    });
  }

  /// Add subscription (forces refresh)
  Future<bool> addSubscription(String email, Map<String, dynamic> data) async {
    final cleanEmail = email.toLowerCase().trim();
    final uniqueId = DateTime.now().microsecondsSinceEpoch.toString();
    final item = {
      ...data,
      'id': uniqueId,
      'email': cleanEmail,
      'createdAt': DateTime.now().toIso8601String(),
    };

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final subs = await getSubscriptions(cleanEmail);
        subs.add(item);
        await prefs.setString('web_subs_$cleanEmail', jsonEncode(subs));
        return true;
      } catch (e) {
        debugPrint('Web addSubscription failed: $e');
        return false;
      }
    }

    try {
      await _connection.ensureConnected();
      if (!_connection.isConnected || _connection.db == null) return false;
      final coll = _connection.db!.collection('subscriptions');
      await coll.insertOne(item);
      
      // Invalidate cache immediately on mutation
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_fetch_$cleanEmail');
      _triggerBackgroundSync(cleanEmail);
      
      return true;
    } catch (e) {
      debugPrint('Native addSubscription failed: $e');
      return false;
    }
  }

  /// Update notes on subscription (forces refresh)
  Future<bool> updateSubscriptionNotes(String email, String id, String notes) async {
    final cleanEmail = email.toLowerCase().trim();

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final list = await getSubscriptions(cleanEmail);
        for (var item in list) {
          final itemId = (item['id'] ?? item['createdAt'] ?? '').toString();
          if (itemId == id) {
            item['notes'] = notes;
            break;
          }
        }
        await prefs.setString('web_subs_$cleanEmail', jsonEncode(list));
        return true;
      } catch (e) {
        debugPrint('Web updateSubscriptionNotes failed: $e');
        return false;
      }
    }

    try {
      await _connection.ensureConnected();
      if (!_connection.isConnected || _connection.db == null) return false;
      final coll = _connection.db!.collection('subscriptions');
      
      try {
        final objId = mongo.ObjectId.fromHexString(id);
        final res = await coll.updateOne(
          mongo.where.eq('email', cleanEmail).and(mongo.where.eq('_id', objId)),
          mongo.modify.set('notes', notes),
        );
        if (res.isSuccess) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('last_fetch_$cleanEmail');
          _triggerBackgroundSync(cleanEmail);
          return true;
        }
      } catch (_) {}

      await coll.updateOne(
        mongo.where.eq('email', cleanEmail).and(mongo.where.eq('id', id)),
        mongo.modify.set('notes', notes),
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_fetch_$cleanEmail');
      _triggerBackgroundSync(cleanEmail);
      
      return true;
    } catch (e) {
      debugPrint('Native updateSubscriptionNotes failed: $e');
      return false;
    }
  }

  /// Toggle subscription group settings (forces refresh)
  Future<bool> updateSubscriptionGroup(String email, String id, String? groupId) async {
    final cleanEmail = email.toLowerCase().trim();

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final list = await getSubscriptions(cleanEmail);
        for (var item in list) {
          final itemId = (item['id'] ?? item['createdAt'] ?? '').toString();
          if (itemId == id) {
            item['groupId'] = groupId;
            break;
          }
        }
        await prefs.setString('web_subs_$cleanEmail', jsonEncode(list));
        return true;
      } catch (e) {
        debugPrint('Web updateSubscriptionGroup failed: $e');
        return false;
      }
    }

    try {
      await _connection.ensureConnected();
      if (!_connection.isConnected || _connection.db == null) return false;
      final coll = _connection.db!.collection('subscriptions');
      
      try {
        final objId = mongo.ObjectId.fromHexString(id);
        await coll.updateOne(
          mongo.where.eq('email', cleanEmail).and(mongo.where.eq('_id', objId)),
          groupId == null ? mongo.modify.unset('groupId') : mongo.modify.set('groupId', groupId),
        );
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_fetch_$cleanEmail');
        _triggerBackgroundSync(cleanEmail);
        
        return true;
      } catch (_) {}

      await coll.updateOne(
        mongo.where.eq('email', cleanEmail).and(mongo.where.eq('id', id)),
        groupId == null ? mongo.modify.unset('groupId') : mongo.modify.set('groupId', groupId),
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_fetch_$cleanEmail');
      _triggerBackgroundSync(cleanEmail);
      
      return true;
    } catch (e) {
      debugPrint('Native updateSubscriptionGroup failed: $e');
      return false;
    }
  }

  /// Delete subscription (forces refresh)
  Future<bool> deleteSubscriptions(String email, List<String> ids) async {
    final cleanEmail = email.toLowerCase().trim();

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final list = await getSubscriptions(cleanEmail);
        list.removeWhere((item) => ids.contains(item['id'] ?? item['createdAt']));
        await prefs.setString('web_subs_$cleanEmail', jsonEncode(list));
        return true;
      } catch (e) {
        debugPrint('Web deleteSubscriptions failed: $e');
        return false;
      }
    }

    try {
      await _connection.ensureConnected();
      if (!_connection.isConnected || _connection.db == null) return false;
      final coll = _connection.db!.collection('subscriptions');
      
      final objectIds = <mongo.ObjectId>[];
      final stringIds = <String>[];
      
      for (final id in ids) {
        try {
          objectIds.add(mongo.ObjectId.fromHexString(id));
        } catch (_) {
          stringIds.add(id);
        }
      }

      if (objectIds.isNotEmpty) {
        await coll.remove(mongo.where.eq('email', cleanEmail).and(mongo.where.oneFrom('_id', objectIds)));
      }
      if (stringIds.isNotEmpty) {
        await coll.remove(mongo.where.eq('email', cleanEmail).and(mongo.where.oneFrom('id', stringIds)));
      }
      
      // Invalidate cache immediately on mutation
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_fetch_$cleanEmail');
      _triggerBackgroundSync(cleanEmail);
      
      return true;
    } catch (e) {
      debugPrint('Native deleteSubscriptions failed: $e');
      return false;
    }
  }
}
