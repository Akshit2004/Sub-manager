import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// Resolve API Base URL automatically based on build and platform
  String get baseUrl {
    if (kReleaseMode) {
      // Hosted production URL
      return dotenv.env['API_PRODUCTION_URL']?.trim() ?? 'https://submanageradmin.vercel.app';
    }

    // Local development URL
    final envUrl = dotenv.env['API_BASE_URL']?.trim() ?? 'http://10.0.2.2:3000';
    
    // Auto-detect Android emulator and rewrite localhost/127.0.0.1
    if (defaultTargetPlatform == TargetPlatform.android &&
        (envUrl.contains('localhost') || envUrl.contains('127.0.0.1'))) {
      return envUrl
          .replaceAll('localhost', '10.0.2.2')
          .replaceAll('127.0.0.1', '10.0.2.2');
    }
    return envUrl;
  }

  // ── Helper HTTP requests ─────────────────────────────────

  Future<http.Response> _get(String path) {
    final url = Uri.parse('$baseUrl$path');
    debugPrint('[API GET] $url');
    return http.get(url, headers: {'Content-Type': 'application/json'}).timeout(
      const Duration(seconds: 15),
    );
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) {
    final url = Uri.parse('$baseUrl$path');
    debugPrint('[API POST] $url -> body: ${jsonEncode(body)}');
    return http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));
  }

  Future<http.Response> _put(String path, Map<String, dynamic> body) {
    final url = Uri.parse('$baseUrl$path');
    debugPrint('[API PUT] $url -> body: ${jsonEncode(body)}');
    return http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));
  }

  Future<http.Response> _delete(String path, Map<String, dynamic> body) {
    final url = Uri.parse('$baseUrl$path');
    debugPrint('[API DELETE] $url -> body: ${jsonEncode(body)}');
    return http.delete(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));
  }

  // ── Auth Services ────────────────────────────────────────

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final res = await _post('/api/app/auth/register', {
        'name': name,
        'email': email,
        'password': password,
      });

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        return Map<String, dynamic>.from(data);
      }
      return {'success': false, 'message': data['message'] ?? 'Registration failed'};
    } catch (e) {
      debugPrint('[API Auth Error] register failed: $e');
      return {'success': false, 'message': 'Failed to connect to auth server: $e'};
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _post('/api/app/auth/login', {
        'email': email,
        'password': password,
      });

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(data);
      }
      return {'success': false, 'message': data['message'] ?? 'Login failed'};
    } catch (e) {
      debugPrint('[API Auth Error] login failed: $e');
      return {'success': false, 'message': 'Failed to connect to auth server: $e'};
    }
  }

  Future<Map<String, dynamic>> sendPasswordResetOtp(String email) async {
    try {
      final res = await _post('/api/app/auth/forgot-password', {
        'email': email,
      });

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(data);
      }
      return {'success': false, 'message': data['message'] ?? 'Failed to send OTP'};
    } catch (e) {
      debugPrint('[API Auth Error] sendOtp failed: $e');
      return {'success': false, 'message': 'Failed to connect to auth server: $e'};
    }
  }

  Future<Map<String, dynamic>> verifyOtpAndResetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final res = await _post('/api/app/auth/reset-password', {
        'email': email,
        'otp': otp,
        'newPassword': newPassword,
      });

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(data);
      }
      return {'success': false, 'message': data['message'] ?? 'Password reset failed'};
    } catch (e) {
      debugPrint('[API Auth Error] verifyOtpAndResetPassword failed: $e');
      return {'success': false, 'message': 'Failed to connect to auth server: $e'};
    }
  }

  // ── Subscription Services ────────────────────────────────

  Future<List<Map<String, dynamic>>> getSubscriptions(String email) async {
    try {
      final res = await _get('/api/app/subscriptions?email=${Uri.encodeComponent(email)}');
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      debugPrint('[API Sub Error] getSubscriptions failed: ${res.statusCode}');
      return [];
    } catch (e) {
      debugPrint('[API Sub Error] getSubscriptions failed: $e');
      return [];
    }
  }

  Future<bool> addSubscription(String email, Map<String, dynamic> data) async {
    try {
      final res = await _post('/api/app/subscriptions', {
        'email': email,
        ...data,
      });
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return body['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[API Sub Error] addSubscription failed: $e');
      return false;
    }
  }

  Future<bool> updateSubscriptionNotes(String email, String id, String notes) async {
    try {
      final res = await _put('/api/app/subscriptions', {
        'email': email,
        'id': id,
        'notes': notes,
      });
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return body['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[API Sub Error] updateSubscriptionNotes failed: $e');
      return false;
    }
  }

  Future<bool> updateSubscriptionGroup(String email, String id, String? groupId) async {
    try {
      final res = await _put('/api/app/subscriptions', {
        'email': email,
        'id': id,
        'groupId': groupId,
      });
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return body['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[API Sub Error] updateSubscriptionGroup failed: $e');
      return false;
    }
  }

  Future<bool> updateSubscription(String email, String id, Map<String, dynamic> data) async {
    try {
      final res = await _put('/api/app/subscriptions', {
        'email': email,
        'id': id,
        ...data,
      });
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return body['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[API Sub Error] updateSubscription failed: $e');
      return false;
    }
  }

  Future<bool> deleteSubscriptions(String email, List<String> ids) async {
    try {
      final res = await _delete('/api/app/subscriptions', {
        'email': email,
        'ids': ids,
      });
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return body['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[API Sub Error] deleteSubscriptions failed: $e');
      return false;
    }
  }

  // ── Family Groups Services ───────────────────────────────

  Future<List<Map<String, dynamic>>> getUserGroups(String email) async {
    try {
      final res = await _get('/api/app/groups?email=${Uri.encodeComponent(email)}');
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[API Group Error] getUserGroups failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getInvitesForUser(String email) async {
    try {
      final res = await _get('/api/app/groups/invites?email=${Uri.encodeComponent(email)}');
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[API Group Error] getInvitesForUser failed: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createGroup(String name, String ownerEmail) async {
    try {
      final res = await _post('/api/app/groups', {
        'name': name,
        'ownerEmail': ownerEmail,
      });
      final data = jsonDecode(res.body);
      return Map<String, dynamic>.from(data);
    } catch (e) {
      debugPrint('[API Group Error] createGroup failed: $e');
      return {'success': false, 'message': 'Failed to connect to group server: $e'};
    }
  }

  Future<Map<String, dynamic>> inviteMember(String groupId, String email) async {
    try {
      final res = await _post('/api/app/groups/invite', {
        'groupId': groupId,
        'email': email,
      });
      final data = jsonDecode(res.body);
      return Map<String, dynamic>.from(data);
    } catch (e) {
      debugPrint('[API Group Error] inviteMember failed: $e');
      return {'success': false, 'message': 'Failed to connect to group server: $e'};
    }
  }

  Future<Map<String, dynamic>> acceptInvite(String groupId, String email) async {
    try {
      final res = await _post('/api/app/groups/accept', {
        'groupId': groupId,
        'email': email,
      });
      final data = jsonDecode(res.body);
      return Map<String, dynamic>.from(data);
    } catch (e) {
      debugPrint('[API Group Error] acceptInvite failed: $e');
      return {'success': false, 'message': 'Failed to connect to group server: $e'};
    }
  }

  Future<Map<String, dynamic>> declineInvite(String groupId, String email) async {
    try {
      final res = await _post('/api/app/groups/decline', {
        'groupId': groupId,
        'email': email,
      });
      final data = jsonDecode(res.body);
      return Map<String, dynamic>.from(data);
    } catch (e) {
      debugPrint('[API Group Error] declineInvite failed: $e');
      return {'success': false, 'message': 'Failed to connect to group server: $e'};
    }
  }

  Future<Map<String, dynamic>> leaveGroup(String groupId, String email) async {
    try {
      final res = await _post('/api/app/groups/leave', {
        'groupId': groupId,
        'email': email,
      });
      final data = jsonDecode(res.body);
      return Map<String, dynamic>.from(data);
    } catch (e) {
      debugPrint('[API Group Error] leaveGroup failed: $e');
      return {'success': false, 'message': 'Failed to connect to group server: $e'};
    }
  }

  Future<Map<String, dynamic>> updateGroupUpiId(String groupId, String upiId, String email) async {
    try {
      final res = await _post('/api/app/groups/upi', {
        'groupId': groupId,
        'upiId': upiId,
        'email': email,
      });
      final data = jsonDecode(res.body);
      return Map<String, dynamic>.from(data);
    } catch (e) {
      debugPrint('[API Group Error] updateGroupUpiId failed: $e');
      return {'success': false, 'message': 'Failed to connect to group server: $e'};
    }
  }

  // ── Payment Services ─────────────────────────────────────

  Future<Map<String, dynamic>> createPaymentRecord(Map<String, dynamic> data) async {
    try {
      final res = await _post('/api/app/payments', data);
      final body = jsonDecode(res.body);
      return Map<String, dynamic>.from(body);
    } catch (e) {
      debugPrint('[API Payment Error] createPaymentRecord failed: $e');
      return {'success': false, 'message': 'Failed to connect to payment server: $e'};
    }
  }

  Future<List<Map<String, dynamic>>> getPaymentsForGroup(String groupId, String billingPeriod) async {
    try {
      final res = await _get('/api/app/payments?groupId=${Uri.encodeComponent(groupId)}&billingPeriod=${Uri.encodeComponent(billingPeriod)}');
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[API Payment Error] getPaymentsForGroup failed: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> updatePaymentStatus(String paymentId, String status, String userEmail) async {
    try {
      final res = await _put('/api/app/payments', {
        'paymentId': paymentId,
        'status': status,
        'userEmail': userEmail,
      });
      final body = jsonDecode(res.body);
      return Map<String, dynamic>.from(body);
    } catch (e) {
      debugPrint('[API Payment Error] updatePaymentStatus failed: $e');
      return {'success': false, 'message': 'Failed to connect to payment server: $e'};
    }
  }
}
