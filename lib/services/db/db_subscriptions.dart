import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../mongodb_service.dart';
import 'db_connection.dart';
import '../notification_service.dart';
import '../api_service.dart';

class DbSubscriptionsService {
  DbSubscriptionsService(DbConnectionService connection);

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

  /// Fetch from remote REST API and overwrite local cache with standard serialized formats
  Future<List<Map<String, dynamic>>> _fetchAndCache(String email) async {
    final cleanEmail = email.toLowerCase().trim();
    try {
      // Call Next.js API
      final freshList = await ApiService().getSubscriptions(cleanEmail);
      
      // Save safely to local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_subs_$cleanEmail', jsonEncode(freshList));
      await prefs.setInt('last_fetch_$cleanEmail', DateTime.now().millisecondsSinceEpoch);
      
      // Bulk sync local scheduled reminders in background
      NotificationService().syncAllSubscriptionsReminders(freshList);
      
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
      // Call Next.js API
      final success = await ApiService().addSubscription(cleanEmail, item);
      if (success) {
        // Schedule reminders immediately
        NotificationService().scheduleSubscriptionReminders(item);
        
        // Invalidate cache immediately on mutation
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_fetch_$cleanEmail');
        _triggerBackgroundSync(cleanEmail);
        return true;
      }
      return false;
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
      // Call Next.js API
      final success = await ApiService().updateSubscriptionNotes(cleanEmail, id, notes);
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_fetch_$cleanEmail');
        _triggerBackgroundSync(cleanEmail);
        return true;
      }
      return false;
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
      // Call Next.js API
      final success = await ApiService().updateSubscriptionGroup(cleanEmail, id, groupId);
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_fetch_$cleanEmail');
        _triggerBackgroundSync(cleanEmail);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Native updateSubscriptionGroup failed: $e');
      return false;
    }
  }

  /// Update subscription fields (name, plan, price, currency, renewalDate, category, color)
  Future<bool> updateSubscription(String email, String id, Map<String, dynamic> data) async {
    final cleanEmail = email.toLowerCase().trim();

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final list = await getSubscriptions(cleanEmail);
        for (var item in list) {
          final itemId = (item['id'] ?? item['createdAt'] ?? '').toString();
          if (itemId == id) {
            data.forEach((key, value) { item[key] = value; });
            break;
          }
        }
        await prefs.setString('web_subs_$cleanEmail', jsonEncode(list));
        return true;
      } catch (e) {
        debugPrint('Web updateSubscription failed: $e');
        return false;
      }
    }

    try {
      // Call Next.js API
      final success = await ApiService().updateSubscription(cleanEmail, id, data);
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_fetch_$cleanEmail');
        _triggerBackgroundSync(cleanEmail);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Native updateSubscription failed: $e');
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
      // Call Next.js API
      final success = await ApiService().deleteSubscriptions(cleanEmail, ids);
      if (success) {
        // Cancel pending notifications for deleted IDs
        for (final id in ids) {
          NotificationService().cancelSubscriptionReminders(id);
        }
        
        // Invalidate cache immediately on mutation
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_fetch_$cleanEmail');
        _triggerBackgroundSync(cleanEmail);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Native deleteSubscriptions failed: $e');
      return false;
    }
  }
}

