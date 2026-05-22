import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../mongodb_service.dart';
import 'db_connection.dart';
import '../api_service.dart';

class DbPaymentsService {
  DbPaymentsService(DbConnectionService connection);

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

  /// Create a new payment record
  Future<Map<String, dynamic>> createPaymentRecord(Map<String, dynamic> data) async {
    final paymentId = DateTime.now().microsecondsSinceEpoch.toString();
    final payment = {
      'id': paymentId,
      'groupId': data['groupId'],
      'senderEmail': data['senderEmail'].toString().toLowerCase().trim(),
      'recipientEmail': data['recipientEmail'].toString().toLowerCase().trim(),
      'amount': (data['amount'] as num).toDouble(),
      'upiId': data['upiId'].toString().trim(),
      'status': data['status'], // 'pending' | 'success' | 'failed'
      'timestamp': DateTime.now().toIso8601String(),
      'billingPeriod': data['billingPeriod'], // e.g. "2026-05"
    };

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final paymentsJson = prefs.getString('web_payments') ?? '[]';
        final payments = List<dynamic>.from(jsonDecode(paymentsJson));
        payments.add(payment);
        await prefs.setString('web_payments', jsonEncode(payments));
        return {'success': true, 'message': 'Payment declared successfully', 'payment': payment};
      } catch (e) {
        return {'success': false, 'message': 'Web createPaymentRecord failed: $e'};
      }
    }

    try {
      final res = await ApiService().createPaymentRecord(payment);
      if (res['success'] == true) {
        // Trigger a silent sync notify for both sender and recipient
        MongoDbService.notifySync(payment['senderEmail'] as String);
        MongoDbService.notifySync(payment['recipientEmail'] as String);
      }
      return res;
    } catch (e) {
      return {'success': false, 'message': 'Create payment record failed: $e'};
    }
  }

  /// Get payments for a family group and specific billing period
  Future<List<Map<String, dynamic>>> getPaymentsForGroup(String groupId, String billingPeriod) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final paymentsJson = prefs.getString('web_payments') ?? '[]';
        final payments = List<dynamic>.from(jsonDecode(paymentsJson));
        final list = <Map<String, dynamic>>[];
        for (var p in payments) {
          final payment = Map<String, dynamic>.from(p);
          if (payment['groupId'] == groupId && payment['billingPeriod'] == billingPeriod) {
            list.add(payment);
          }
        }
        return list;
      } catch (e) {
        debugPrint('Web getPaymentsForGroup failed: $e');
        return [];
      }
    }

    try {
      final list = await ApiService().getPaymentsForGroup(groupId, billingPeriod);
      return list.map((e) => _serializeMongoMap(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      debugPrint('Native getPaymentsForGroup failed: $e');
      return [];
    }
  }

  /// Update the status of a payment record (Approve / Reject)
  Future<Map<String, dynamic>> updatePaymentStatus(String paymentId, String status, String userEmail) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final paymentsJson = prefs.getString('web_payments') ?? '[]';
        final payments = List<dynamic>.from(jsonDecode(paymentsJson));
        int foundIndex = -1;
        for (int i = 0; i < payments.length; i++) {
          final payment = Map<String, dynamic>.from(payments[i]);
          if (payment['id'] == paymentId) {
            foundIndex = i;
            break;
          }
        }

        if (foundIndex == -1) {
          return {'success': false, 'message': 'Payment record not found'};
        }

        final payment = Map<String, dynamic>.from(payments[foundIndex]);
        payment['status'] = status;
        payments[foundIndex] = payment;
        await prefs.setString('web_payments', jsonEncode(payments));

        return {
          'success': true,
          'message': 'Payment status updated to $status successfully',
          'payment': payment
        };
      } catch (e) {
        return {'success': false, 'message': 'Web updatePaymentStatus failed: $e'};
      }
    }

    try {
      final res = await ApiService().updatePaymentStatus(paymentId, status, userEmail);
      if (res['success'] == true && res['payment'] != null) {
        final payment = Map<String, dynamic>.from(res['payment']);
        // Trigger sync notification for both sender and receiver to redraw dashboards
        final sender = payment['senderEmail'] as String;
        final receiver = payment['recipientEmail'] as String;
        MongoDbService.notifySync(sender);
        MongoDbService.notifySync(receiver);
      }
      return res;
    } catch (e) {
      return {'success': false, 'message': 'Update payment status failed: $e'};
    }
  }
}
