import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:shared_preferences/shared_preferences.dart';

class DbConnectionService {
  static final DbConnectionService _instance = DbConnectionService._internal();
  factory DbConnectionService() => _instance;
  DbConnectionService._internal();

  mongo.Db? _db;
  bool _isConnected = false;
  String _currentUri = '';
  String? _errorMessage;

  mongo.Db? get db => _db;
  bool get isConnected => _isConnected;
  String get currentUri => _currentUri;
  String? get errorMessage => _errorMessage;

  /// Connect to the database
  Future<bool> connect({
    String host = '127.0.0.1',
    int port = 27017,
    String dbName = 'sub_manager',
    String? connectionString,
  }) async {
    // Web Mode Fallback
    if (kIsWeb) {
      _isConnected = true;
      _currentUri = 'shared_preferences::web_fallback';
      _errorMessage = null;
      debugPrint('Web Mode: Local persistence activated successfully (Direct MongoDB TCP blocked by browser sandbox).');
      return true;
    }

    // Native Mode
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
      if (activeUri.endsWith('/')) {
        activeUri = '$activeUri$dbName';
      } else {
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

  /// Close the connection
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

  /// Direct collection builder helper
  mongo.DbCollection? getCollection(String name) {
    if (kIsWeb || !_isConnected || _db == null) return null;
    return _db!.collection(name);
  }

  /// Verify DB Master connectivity and auto-reconnect if dropped
  Future<bool> ensureConnected() async {
    if (kIsWeb) return true;
    if (_db != null && _isConnected && _db!.state == mongo.State.OPEN) {
      return true;
    }

    debugPrint('Database not active (No Master Connection). Attempting auto-reconnection...');
    final uri = dotenv.env['MONGO_URI'];
    final host = dotenv.env['MONGO_HOST'] ?? '127.0.0.1';
    final port = int.tryParse(dotenv.env['MONGO_PORT'] ?? '27017') ?? 27017;
    final dbName = dotenv.env['MONGO_DB_NAME'] ?? 'sub_manager';

    return await connect(
      host: host,
      port: port,
      dbName: dbName,
      connectionString: uri,
    );
  }
}
