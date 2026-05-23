import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'shorebird_updater.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  
  Future<void>? _initFuture;

  ApiService._internal() {
    // Dynamically load the patch version asynchronously when initialized
    _initFuture = initVersions();
  }

  String _appVersion = '1.0.0';
  int? _patchVersion;

  /// Fetch and cache active App version and Shorebird patch version
  Future<void> initVersions() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      debugPrint('[ApiService] Loaded dynamic App version: $_appVersion');
      
      final updater = SubManagerShorebirdService();
      if (updater.isShorebirdAvailable()) {
        _patchVersion = await updater.currentPatchNumber();
        debugPrint('[ApiService] Loaded Shorebird patch version: $_patchVersion');
      }
    } catch (e) {
      debugPrint('[ApiService] Failed to fetch Shorebird version details: $e');
    }
  }

  Future<Map<String, String>> _buildHeaders() async {
    if (_initFuture != null) {
      await _initFuture;
    }
    return {
      'Content-Type': 'application/json',
      'x-app-version': _appVersion,
      'x-patch-version': (_patchVersion ?? 0).toString(),
    };
  }

  String get baseUrl {
    if (kReleaseMode) {
      // Hosted production URL (dynamically corrected at runtime to bypass unpatchable .env assets)
      final url = dotenv.env['API_PRODUCTION_URL']?.trim() ?? 'https://submanageradmin.vercel.app';
      if (url.contains('submanager-admin.vercel.app')) {
        return 'https://submanageradmin.vercel.app';
      }
      return url;
    }

    // Local development URL (using live hosted backend)
    final envUrl = dotenv.env['API_BASE_URL']?.trim() ?? 'https://submanageradmin.vercel.app';
    
    return envUrl;
  }

  // ── Helper HTTP requests ─────────────────────────────────

  Future<http.Response> _get(String path) async {
    final url = Uri.parse('$baseUrl$path');
    debugPrint('[API GET] $url');
    final headers = await _buildHeaders();
    return http.get(url, headers: headers).timeout(
      const Duration(seconds: 15),
    );
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl$path');
    debugPrint('[API POST] $url -> body: ${jsonEncode(body)}');
    final headers = await _buildHeaders();
    return http.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));
  }

  Future<http.Response> _put(String path, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl$path');
    debugPrint('[API PUT] $url -> body: ${jsonEncode(body)}');
    final headers = await _buildHeaders();
    return http.put(
      url,
      headers: headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));
  }

  Future<http.Response> _delete(String path, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl$path');
    debugPrint('[API DELETE] $url -> body: ${jsonEncode(body)}');
    final headers = await _buildHeaders();
    return http.delete(
      url,
      headers: headers,
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
