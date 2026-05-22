import 'dart:async';

class DbConnectionService {
  static final DbConnectionService _instance = DbConnectionService._internal();
  factory DbConnectionService() => _instance;
  DbConnectionService._internal();

  dynamic get db => null;
  bool get isConnected => true;
  String get currentUri => 'api_proxy::nextjs_server';
  String? get errorMessage => null;

  /// Connect stub (Always true)
  Future<bool> connect({
    String host = '127.0.0.1',
    int port = 27017,
    String dbName = 'sub_manager',
    String? connectionString,
  }) async {
    return true;
  }

  /// Close stub
  Future<void> close() async {}

  /// Collection stub
  dynamic getCollection(String name) => null;

  /// Connection health check stub (Always true)
  Future<bool> ensureConnected() async {
    return true;
  }
}

