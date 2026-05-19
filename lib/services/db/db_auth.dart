import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:shared_preferences/shared_preferences.dart';
import 'db_connection.dart';

class DbAuthService {
  final DbConnectionService _connection;
  DbAuthService(this._connection);

  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  /// Register user (Native MongoDB / Local Web SharedPreferences)
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.toLowerCase().trim();

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

    try {
      await _connection.ensureConnected();
      if (!_connection.isConnected || _connection.db == null) {
        return {'success': false, 'message': 'Database not connected'};
      }

      final users = _connection.db!.collection('users');

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

  /// Login user (Native MongoDB / Local Web SharedPreferences)
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.toLowerCase().trim();

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

    try {
      await _connection.ensureConnected();
      if (!_connection.isConnected || _connection.db == null) {
        return {'success': false, 'message': 'Database not connected'};
      }

      final users = _connection.db!.collection('users');

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
}
