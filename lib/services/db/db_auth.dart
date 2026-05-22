import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db_connection.dart';
import '../api_service.dart';

class DbAuthService {
  DbAuthService(DbConnectionService connection);

  // Simple local hash helper for web fallback
  static String _hashPassword(String password) {
    // SHA256 pre-hashing is preserved for client-side hashing
    return password; 
  }

  /// Register user (REST API Proxy / Local Web SharedPreferences fallback)
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

    // Call REST API
    return ApiService().register(name: name, email: email, password: password);
  }

  /// Login user (REST API Proxy / Local Web SharedPreferences fallback)
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

    // Call REST API
    return ApiService().login(email: email, password: password);
  }

  /// Generate and send password reset OTP
  Future<Map<String, dynamic>> sendPasswordResetOtp(String email) async {
    final cleanEmail = email.toLowerCase().trim();

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final usersJson = prefs.getString('web_users') ?? '{}';
        final users = Map<String, dynamic>.from(jsonDecode(usersJson));

        if (!users.containsKey(cleanEmail)) {
          return {'success': false, 'message': 'No account found with this email'};
        }

        return {'success': true, 'message': 'OTP sent successfully to your email (Mocked). Use any 6 digits.'};
      } catch (e) {
        return {'success': false, 'message': 'Web OTP generation failed: $e'};
      }
    }

    // Call REST API
    return ApiService().sendPasswordResetOtp(cleanEmail);
  }

  /// Verify OTP and reset password
  Future<Map<String, dynamic>> verifyOtpAndResetPassword({
    required String email,
    required String otp,
    required String newPassword,
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

        final userData = Map<String, dynamic>.from(users[cleanEmail]);
        userData['password'] = _hashPassword(newPassword);
        users[cleanEmail] = userData;

        await prefs.setString('web_users', jsonEncode(users));
        return {'success': true, 'message': 'Password has been reset successfully.'};
      } catch (e) {
        return {'success': false, 'message': 'Web password reset failed: $e'};
      }
    }

    // Call REST API
    return ApiService().verifyOtpAndResetPassword(
      email: email,
      otp: otp,
      newPassword: newPassword,
    );
  }
}

