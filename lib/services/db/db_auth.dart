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
    final cleanName = name.trim();

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final usersJson = prefs.getString('web_users') ?? '{}';
        final users = Map<String, dynamic>.from(jsonDecode(usersJson));

        if (users.containsKey(cleanEmail)) {
          return {'success': false, 'message': 'An account with this email already exists'};
        }

        users[cleanEmail] = {
          'name': cleanName,
          'password': _hashPassword(password),
          'createdAt': DateTime.now().toIso8601String(),
        };

        await prefs.setString('web_users', jsonEncode(users));
        return {
          'success': true,
          'message': 'Account created successfully (Saved locally)',
          'user': {
            'name': cleanName,
            'email': cleanEmail,
          },
        };
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

      final existing = await users.findOne(mongo.where.match('email', '^${RegExp.escape(cleanEmail)}\$', caseInsensitive: true));
      if (existing != null) {
        return {'success': false, 'message': 'An account with this email already exists'};
      }

      await users.insertOne({
        'name': cleanName,
        'email': cleanEmail,
        'password': _hashPassword(password),
        'createdAt': DateTime.now().toIso8601String(),
      });

      return {
        'success': true,
        'message': 'Account created successfully',
        'user': {
          'name': cleanName,
          'email': cleanEmail,
        },
      };
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

      final user = await users.findOne(mongo.where.match('email', '^${RegExp.escape(cleanEmail)}\$', caseInsensitive: true));
      if (user == null) {
        return {'success': false, 'message': 'No account found with this email'};
      }

      if (user['password'] != _hashPassword(password)) {
        return {'success': false, 'message': 'Incorrect password'};
      }

      final dbEmail = user['email'] as String? ?? '';
      if (dbEmail != cleanEmail && dbEmail.isNotEmpty) {
        _migrateUserEmail(dbEmail, cleanEmail);
      }

      return {
        'success': true,
        'message': 'Login successful',
        'user': {
          'name': user['name'],
          'email': cleanEmail,
        },
      };
    } catch (e) {
      return {'success': false, 'message': 'Login failed: $e'};
    }
  }

  /// Background migration to convert a user's mixed-case or uncleaned email representation in all collections to lowercase
  void _migrateUserEmail(String oldEmail, String newEmail) {
    Future.microtask(() async {
      try {
        await _connection.ensureConnected();
        if (!_connection.isConnected || _connection.db == null) return;

        final db = _connection.db!;
        debugPrint('Starting self-healing email migration from "$oldEmail" to "$newEmail"...');

        // 1. Migrate user document
        final usersColl = db.collection('users');
        await usersColl.updateOne(
          mongo.where.eq('email', oldEmail),
          mongo.modify.set('email', newEmail),
        );

        // 2. Migrate subscriptions
        final subsColl = db.collection('subscriptions');
        await subsColl.updateMany(
          mongo.where.match('email', '^${RegExp.escape(oldEmail)}\$', caseInsensitive: true),
          mongo.modify.set('email', newEmail),
        );

        // 3. Migrate groups (ownerEmail)
        final groupsColl = db.collection('groups');
        await groupsColl.updateMany(
          mongo.where.match('ownerEmail', '^${RegExp.escape(oldEmail)}\$', caseInsensitive: true),
          mongo.modify.set('ownerEmail', newEmail),
        );

        // 4. Migrate groups (members and pendingInvites arrays)
        final matchingGroups = await groupsColl.find(
          mongo.where.match('members', '^${RegExp.escape(oldEmail)}\$', caseInsensitive: true)
          .or(mongo.where.match('pendingInvites', '^${RegExp.escape(oldEmail)}\$', caseInsensitive: true))
        ).toList();

        for (final g in matchingGroups) {
          final members = List<String>.from(g['members'] ?? []);
          bool changed = false;
          for (int i = 0; i < members.length; i++) {
            if (members[i].toLowerCase().trim() == newEmail) {
              if (members[i] != newEmail) {
                members[i] = newEmail;
                changed = true;
              }
            }
          }
          final pending = List<String>.from(g['pendingInvites'] ?? []);
          for (int i = 0; i < pending.length; i++) {
            if (pending[i].toLowerCase().trim() == newEmail) {
              if (pending[i] != newEmail) {
                pending[i] = newEmail;
                changed = true;
              }
            }
          }
          if (changed) {
            await groupsColl.updateOne(
              mongo.where.eq('id', g['id']),
              mongo.modify.set('members', members).set('pendingInvites', pending),
            );
          }
        }
        debugPrint('Self-healing email migration completed successfully.');
      } catch (e) {
        debugPrint('Error during self-healing email migration: $e');
      }
    });
  }
}
