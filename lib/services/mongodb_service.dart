import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:shared_preferences/shared_preferences.dart';

class MongoDbService {
  static final MongoDbService _instance = MongoDbService._internal();
  factory MongoDbService() => _instance;
  MongoDbService._internal();

  mongo.Db? _db;
  bool _isConnected = false;
  String _currentUri = '';
  String? _errorMessage;

  mongo.Db? get db => _db;
  bool get isConnected => _isConnected;
  String get currentUri => _currentUri;
  String? get errorMessage => _errorMessage;

  /// Attempt to connect to the database
  Future<bool> connect({
    String host = '127.0.0.1',
    int port = 27017,
    String dbName = 'sub_manager',
    String? connectionString,
  }) async {
    // ── web mode fallback ──────────────────────────────────
    if (kIsWeb) {
      _isConnected = true;
      _currentUri = 'shared_preferences::web_fallback';
      _errorMessage = null;
      debugPrint('Web Mode: Local persistence activated successfully (Direct MongoDB TCP blocked by browser sandbox).');
      return true;
    }

    // ── native mode (windows/mobile) ───────────────────────
    String activeUri = connectionString ?? '';
    if (activeUri.isEmpty) {
      String actualHost = host;
      if (host == 'localhost' || host == '127.0.0.1') {
        if (defaultTargetPlatform == TargetPlatform.android) {
          actualHost = '10.0.2.2';
        }
      }
      activeUri = 'mongodb://$actualHost:$port/$dbName';
    } else {
      // If the connection string ends with a slash, automatically append the database name
      if (activeUri.endsWith('/')) {
        activeUri = '$activeUri$dbName';
      } else {
        // If it doesn't contain a path slash after the protocol, e.g. "mongodb+srv://user:pass@cluster.mongodb.net"
        final schemaIndex = activeUri.indexOf('://');
        if (schemaIndex != -1) {
          final hostPortPart = activeUri.substring(schemaIndex + 3);
          if (!hostPortPart.contains('/')) {
            activeUri = '$activeUri/$dbName';
          }
        }
      }
    }

    _currentUri = activeUri;
    _errorMessage = null;

    try {
      if (_db != null) {
        await close();
      }

      _db = await mongo.Db.create(activeUri);
      await _db!.open().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException(
            'Connection timed out. Ensure MongoDB is running on $activeUri.',
          );
        },
      );

      _isConnected = true;
      _errorMessage = null;
      debugPrint('Successfully connected to MongoDB at $connectionString');
      return true;
    } catch (e) {
      _isConnected = false;
      _errorMessage = e.toString();
      debugPrint('Error connecting to MongoDB: $e');
      return false;
    }
  }

  /// Close the database connection
  Future<void> close() async {
    if (kIsWeb) {
      _isConnected = false;
      return;
    }

    try {
      if (_db != null) {
        await _db!.close();
        _db = null;
      }
    } catch (e) {
      debugPrint('Error closing MongoDB connection: $e');
    } finally {
      _isConnected = false;
    }
  }

  /// Helper to get a collection
  mongo.DbCollection? getCollection(String name) {
    if (kIsWeb || !_isConnected || _db == null) return null;
    return _db!.collection(name);
  }

  // ── auth helpers ─────────────────────────────────────────

  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  /// Register a new user. Works on both Mongo (Native) and SharedPrefs (Web).
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.toLowerCase().trim();

    // ── web mode registration ──────────────────────────────
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final usersJson = prefs.getString('web_users') ?? '{}';
        final users = Map<String, dynamic>.from(jsonDecode(usersJson));

        if (users.containsKey(cleanEmail)) {
          return {'success': false, 'message': 'An account with this email already exists'};
        }

        users[cleanEmail] = {
          'name': name.trim(),
          'password': _hashPassword(password),
          'createdAt': DateTime.now().toIso8601String(),
        };

        await prefs.setString('web_users', jsonEncode(users));
        return {'success': true, 'message': 'Account created successfully (Saved locally)'};
      } catch (e) {
        return {'success': false, 'message': 'Web registration failed: $e'};
      }
    }

    // ── native mode registration ───────────────────────────
    try {
      if (!_isConnected || _db == null) {
        return {'success': false, 'message': 'Database not connected'};
      }

      final users = _db!.collection('users');

      final existing = await users.findOne(mongo.where.eq('email', cleanEmail));
      if (existing != null) {
        return {'success': false, 'message': 'An account with this email already exists'};
      }

      await users.insertOne({
        'name': name.trim(),
        'email': cleanEmail,
        'password': _hashPassword(password),
        'createdAt': DateTime.now().toIso8601String(),
      });

      return {'success': true, 'message': 'Account created successfully'};
    } catch (e) {
      return {'success': false, 'message': 'Registration failed: $e'};
    }
  }

  /// Login an existing user. Works on both Mongo (Native) and SharedPrefs (Web).
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.toLowerCase().trim();

    // ── web mode login ─────────────────────────────────────
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final usersJson = prefs.getString('web_users') ?? '{}';
        final users = Map<String, dynamic>.from(jsonDecode(usersJson));

        if (!users.containsKey(cleanEmail)) {
          return {'success': false, 'message': 'No account found with this email'};
        }

        final userData = users[cleanEmail] as Map<String, dynamic>;
        if (userData['password'] != _hashPassword(password)) {
          return {'success': false, 'message': 'Incorrect password'};
        }

        return {
          'success': true,
          'message': 'Login successful',
          'user': {
            'name': userData['name'],
            'email': cleanEmail,
          },
        };
      } catch (e) {
        return {'success': false, 'message': 'Web login failed: $e'};
      }
    }

    // ── native mode login ──────────────────────────────────
    try {
      if (!_isConnected || _db == null) {
        return {'success': false, 'message': 'Database not connected'};
      }

      final users = _db!.collection('users');

      final user = await users.findOne(mongo.where.eq('email', cleanEmail));
      if (user == null) {
        return {'success': false, 'message': 'No account found with this email'};
      }

      if (user['password'] != _hashPassword(password)) {
        return {'success': false, 'message': 'Incorrect password'};
      }

      return {
        'success': true,
        'message': 'Login successful',
        'user': {
          'name': user['name'],
          'email': user['email'],
        },
      };
    } catch (e) {
      return {'success': false, 'message': 'Login failed: $e'};
    }
  }

  // ── subscription helpers ─────────────────────────────────

  /// Fetch subscriptions for a user email.
  Future<List<Map<String, dynamic>>> getSubscriptions(String email) async {
    final cleanEmail = email.toLowerCase().trim();

    // ── web mode fallback ──────────────────────────────────
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final subsJson = prefs.getString('web_subs_$cleanEmail') ?? '[]';
        final decoded = List<dynamic>.from(jsonDecode(subsJson));
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (e) {
        debugPrint('Web getSubscriptions failed: $e');
        return [];
      }
    }

    // ── native mode ────────────────────────────────────────
    try {
      if (!_isConnected || _db == null) return [];
      final coll = _db!.collection('subscriptions');
      final list = await coll.find(mongo.where.eq('email', cleanEmail)).toList();
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('Native getSubscriptions failed: $e');
      return [];
    }
  }

  /// Add a new subscription.
  Future<bool> addSubscription(String email, Map<String, dynamic> data) async {
    final cleanEmail = email.toLowerCase().trim();
    final uniqueId = DateTime.now().microsecondsSinceEpoch.toString();
    final item = {
      ...data,
      'id': uniqueId, // Unified platform-agnostic identifier
      'email': cleanEmail,
      'createdAt': DateTime.now().toIso8601String(),
    };

    // ── web mode fallback ──────────────────────────────────
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

    // ── native mode ────────────────────────────────────────
    try {
      if (!_isConnected || _db == null) return false;
      final coll = _db!.collection('subscriptions');
      await coll.insertOne(item);
      return true;
    } catch (e) {
      debugPrint('Native addSubscription failed: $e');
      return false;
    }
  }

  /// Update notes of a subscription.
  Future<bool> updateSubscriptionNotes(String email, String id, String notes) async {
    final cleanEmail = email.toLowerCase().trim();

    // ── web mode fallback ──────────────────────────────────
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

    // ── native mode ────────────────────────────────────────
    try {
      if (!_isConnected || _db == null) return false;
      final coll = _db!.collection('subscriptions');
      
      // Try treating as ObjectId first
      try {
        final objId = mongo.ObjectId.fromHexString(id);
        final res = await coll.updateOne(
          mongo.where.eq('email', cleanEmail).and(mongo.where.eq('_id', objId)),
          mongo.modify.set('notes', notes),
        );
        if (res.isSuccess) return true;
      } catch (_) {}

      // Fallback/direct matching by custom 'id' field
      await coll.updateOne(
        mongo.where.eq('email', cleanEmail).and(mongo.where.eq('id', id)),
        mongo.modify.set('notes', notes),
      );
      return true;
    } catch (e) {
      debugPrint('Native updateSubscriptionNotes failed: $e');
      return false;
    }
  }

  /// Delete a list of subscriptions by their unique IDs (supports bulk delete).
  Future<bool> deleteSubscriptions(String email, List<String> ids) async {
    final cleanEmail = email.toLowerCase().trim();

    // ── web mode fallback ──────────────────────────────────
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

    // ── native mode ────────────────────────────────────────
    try {
      if (!_isConnected || _db == null) return false;
      final coll = _db!.collection('subscriptions');
      
      final objectIds = <mongo.ObjectId>[];
      final stringIds = <String>[];
      
      for (final id in ids) {
        try {
          // If the ID is a valid hex string for a MongoDB ObjectId
          objectIds.add(mongo.ObjectId.fromHexString(id));
        } catch (_) {
          // Otherwise treat it as a standard custom string 'id'
          stringIds.add(id);
        }
      }

      // Delete by either native _id or custom id field
      if (objectIds.isNotEmpty) {
        await coll.remove(mongo.where.eq('email', cleanEmail).and(mongo.where.oneFrom('_id', objectIds)));
      }
      if (stringIds.isNotEmpty) {
        await coll.remove(mongo.where.eq('email', cleanEmail).and(mongo.where.oneFrom('id', stringIds)));
      }
      return true;
    } catch (e) {
      debugPrint('Native deleteSubscriptions failed: $e');
      return false;
    }
  }
}
