import 'dart:async';
import 'package:flutter/foundation.dart';
import 'db/db_connection.dart';
import 'db/db_auth.dart';
import 'db/db_subscriptions.dart';
import 'db/db_groups.dart';
import 'db/db_payments.dart';

class _CacheEntry<T> {
  final T data;
  final DateTime expiry;
  _CacheEntry(this.data, Duration ttl) : expiry = DateTime.now().add(ttl);
  bool get isValid => DateTime.now().isBefore(expiry);
}

class MongoDbService {
  static final MongoDbService _instance = MongoDbService._internal();
  factory MongoDbService() => _instance;
  MongoDbService._internal();

  // ── Cache Configuration ─────────────────────────────────
  static const _cacheTtl = Duration(minutes: 2);
  final Map<String, _CacheEntry<dynamic>> _cache = {};

  /// Read from cache if valid, otherwise fetch and cache
  Future<T> _cached<T>(String key, Future<T> Function() fetcher) async {
    final entry = _cache[key];
    if (entry != null && entry.isValid) {
      debugPrint('[Cache HIT] $key');
      return entry.data as T;
    }
    debugPrint('[Cache MISS] $key → fetching from DB');
    final data = await fetcher();
    _cache[key] = _CacheEntry<T>(data, _cacheTtl);
    return data;
  }

  /// Invalidate specific cache keys by prefix
  void _invalidate(List<String> prefixes) {
    _cache.removeWhere((key, _) => prefixes.any((p) => key.startsWith(p)));
  }

  /// Clear all caches (use on logout or manual refresh)
  void clearCache() => _cache.clear();

  // ── Reactive Sync Stream ────────────────────────────────
  static final StreamController<String> _syncController = StreamController<String>.broadcast();
  static Stream<String> get syncStream => _syncController.stream;

  static void notifySync(String email) {
    _syncController.add(email);
  }

  final _conn = DbConnectionService();
  late final _auth = DbAuthService(_conn);
  late final _subs = DbSubscriptionsService(_conn);
  late final _groups = DbGroupsService(_conn);
  late final _payments = DbPaymentsService(_conn);

  // Connection Parameters & Getters
  dynamic get db => _conn.db;
  bool get isConnected => _conn.isConnected;
  String get currentUri => _conn.currentUri;
  String? get errorMessage => _conn.errorMessage;

  /// Establish dynamic connection to MongoDB
  Future<bool> connect({
    String host = '127.0.0.1',
    int port = 27017,
    String dbName = 'sub_manager',
    String? connectionString,
  }) => _conn.connect(
        host: host,
        port: port,
        dbName: dbName,
        connectionString: connectionString,
      );

  /// Close connection
  Future<void> close() => _conn.close();

  /// Retrieve active collection reference
  dynamic getCollection(String name) => _conn.getCollection(name);

  // ── Authentication Service Delegation ───────────────────

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) => _auth.register(name: name, email: email, password: password);

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) => _auth.login(email: email, password: password);

  Future<Map<String, dynamic>> sendPasswordResetOtp(String email) =>
      _auth.sendPasswordResetOtp(email);

  Future<Map<String, dynamic>> verifyOtpAndResetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) =>
      _auth.verifyOtpAndResetPassword(
        email: email,
        otp: otp,
        newPassword: newPassword,
      );

  // ── Subscriptions Service Delegation (CACHED) ───────────

  Future<List<Map<String, dynamic>>> getSubscriptions(String email) =>
      _cached('subs:$email', () => _subs.getSubscriptions(email));

  Future<bool> addSubscription(String email, Map<String, dynamic> data) async {
    final result = await _subs.addSubscription(email, data);
    if (result) _invalidate(['subs:$email']);
    return result;
  }

  Future<bool> updateSubscriptionNotes(String email, String id, String notes) async {
    final result = await _subs.updateSubscriptionNotes(email, id, notes);
    if (result) _invalidate(['subs:$email']);
    return result;
  }

  Future<bool> updateSubscriptionGroup(String email, String id, String? groupId) async {
    final result = await _subs.updateSubscriptionGroup(email, id, groupId);
    if (result) _invalidate(['subs:$email']);
    return result;
  }

  Future<bool> updateSubscription(String email, String id, Map<String, dynamic> data) async {
    final result = await _subs.updateSubscription(email, id, data);
    if (result) _invalidate(['subs:$email']);
    return result;
  }

  Future<bool> deleteSubscriptions(String email, List<String> ids) async {
    final result = await _subs.deleteSubscriptions(email, ids);
    if (result) _invalidate(['subs:$email']);
    return result;
  }

  // ── Family Groups Service Delegation (CACHED) ──────────

  Future<List<Map<String, dynamic>>> getUserGroups(String email) =>
      _cached('groups:$email', () => _groups.getUserGroups(email));

  Future<List<Map<String, dynamic>>> getInvitesForUser(String email) =>
      _cached('invites:$email', () => _groups.getInvitesForUser(email));

  Future<Map<String, dynamic>> createGroup(String name, String ownerEmail) async {
    final res = await _groups.createGroup(name, ownerEmail);
    if (res['success'] == true) _invalidate(['groups:$ownerEmail']);
    return res;
  }

  Future<Map<String, dynamic>> inviteMember(String groupId, String email) async {
    final res = await _groups.inviteMember(groupId, email);
    if (res['success'] == true) _invalidate(['groups:', 'invites:']);
    return res;
  }

  Future<Map<String, dynamic>> acceptInvite(String groupId, String email) async {
    final res = await _groups.acceptInvite(groupId, email);
    if (res['success'] == true) _invalidate(['groups:', 'invites:']);
    return res;
  }

  Future<Map<String, dynamic>> declineInvite(String groupId, String email) async {
    final res = await _groups.declineInvite(groupId, email);
    if (res['success'] == true) _invalidate(['invites:$email']);
    return res;
  }

  Future<Map<String, dynamic>> leaveGroup(String groupId, String email) async {
    final res = await _groups.leaveGroup(groupId, email);
    if (res['success'] == true) _invalidate(['groups:']);
    return res;
  }

  Future<Map<String, dynamic>> updateGroupUpiId(String groupId, String upiId, String email) async {
    final res = await _groups.updateGroupUpiId(groupId, upiId, email);
    if (res['success'] == true) _invalidate(['groups:$email']);
    return res;
  }

  // ── Payments Service Delegation (CACHED) ────────────────

  Future<Map<String, dynamic>> createPaymentRecord(Map<String, dynamic> data) async {
    final res = await _payments.createPaymentRecord(data);
    if (res['success'] == true) _invalidate(['payments:']);
    return res;
  }

  Future<List<Map<String, dynamic>>> getPaymentsForGroup(String groupId, String billingPeriod) =>
      _cached('payments:$groupId:$billingPeriod', () => _payments.getPaymentsForGroup(groupId, billingPeriod));

  Future<Map<String, dynamic>> updatePaymentStatus(String paymentId, String status, String userEmail) async {
    final res = await _payments.updatePaymentStatus(paymentId, status, userEmail);
    if (res['success'] == true) _invalidate(['payments:']);
    return res;
  }
}
