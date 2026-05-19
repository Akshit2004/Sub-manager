import 'dart:async';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'db/db_connection.dart';
import 'db/db_auth.dart';
import 'db/db_subscriptions.dart';
import 'db/db_groups.dart';

class MongoDbService {
  static final MongoDbService _instance = MongoDbService._internal();
  factory MongoDbService() => _instance;
  MongoDbService._internal();

  // Reactive Sync Stream to broadcast background sync completions to active controllers
  static final StreamController<String> _syncController = StreamController<String>.broadcast();
  static Stream<String> get syncStream => _syncController.stream;

  static void notifySync(String email) {
    _syncController.add(email);
  }

  final _conn = DbConnectionService();
  late final _auth = DbAuthService(_conn);
  late final _subs = DbSubscriptionsService(_conn);
  late final _groups = DbGroupsService(_conn);

  // Connection Parameters & Getters
  mongo.Db? get db => _conn.db;
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
  mongo.DbCollection? getCollection(String name) => _conn.getCollection(name);

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

  // ── Subscriptions Service Delegation ────────────────────

  Future<List<Map<String, dynamic>>> getSubscriptions(String email) =>
      _subs.getSubscriptions(email);

  Future<bool> addSubscription(String email, Map<String, dynamic> data) =>
      _subs.addSubscription(email, data);

  Future<bool> updateSubscriptionNotes(String email, String id, String notes) =>
      _subs.updateSubscriptionNotes(email, id, notes);

  Future<bool> updateSubscriptionGroup(String email, String id, String? groupId) =>
      _subs.updateSubscriptionGroup(email, id, groupId);

  Future<bool> deleteSubscriptions(String email, List<String> ids) =>
      _subs.deleteSubscriptions(email, ids);

  // ── Family Groups Service Delegation ────────────────────

  Future<Map<String, dynamic>?> getUserGroup(String email) =>
      _groups.getUserGroup(email);

  Future<List<Map<String, dynamic>>> getInvitesForUser(String email) =>
      _groups.getInvitesForUser(email);

  Future<Map<String, dynamic>> createGroup(String name, String ownerEmail) =>
      _groups.createGroup(name, ownerEmail);

  Future<Map<String, dynamic>> inviteMember(String groupId, String email) =>
      _groups.inviteMember(groupId, email);

  Future<Map<String, dynamic>> acceptInvite(String groupId, String email) =>
      _groups.acceptInvite(groupId, email);

  Future<Map<String, dynamic>> declineInvite(String groupId, String email) =>
      _groups.declineInvite(groupId, email);

  Future<Map<String, dynamic>> leaveGroup(String groupId, String email) =>
      _groups.leaveGroup(groupId, email);
}
