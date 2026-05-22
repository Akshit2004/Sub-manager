import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart' as sb;

class SubManagerShorebirdService {
  static final SubManagerShorebirdService _instance = SubManagerShorebirdService._internal();
  factory SubManagerShorebirdService() => _instance;
  SubManagerShorebirdService._internal();

  final sb.ShorebirdUpdater _updater = sb.ShorebirdUpdater();

  /// Check if Shorebird is active and supported on the current device
  bool isShorebirdAvailable() {
    try {
      return _updater.isAvailable;
    } catch (e) {
      debugPrint('Error checking Shorebird availability: $e');
      return false;
    }
  }

  /// Fetch the active patch number running on this device
  Future<int?> currentPatchNumber() async {
    if (!isShorebirdAvailable()) return null;
    try {
      final patch = await _updater.readCurrentPatch();
      return patch?.number;
    } catch (e) {
      debugPrint('Error getting Shorebird patch number: $e');
      return null;
    }
  }

  /// Checks if a new update is available on the Shorebird server.
  /// If an update is available, it downloads it in the background and returns `true`.
  /// Otherwise, returns `false`.
  Future<bool> checkForUpdates() async {
    if (!isShorebirdAvailable()) {
      debugPrint('Shorebird is not available or initialized on this device.');
      return false;
    }

    try {
      debugPrint('Checking for Shorebird updates...');
      final status = await _updater.checkForUpdate();
      
      if (status == sb.UpdateStatus.outdated) {
        debugPrint('New Shorebird patch found! Starting download...');
        await _updater.update();
        debugPrint('Shorebird patch downloaded and ready for next launch.');
        return true;
      } else if (status == sb.UpdateStatus.restartRequired) {
        debugPrint('Shorebird patch already downloaded, restart required.');
        return true;
      }
      debugPrint('Shorebird update status: $status');
    } catch (e) {
      debugPrint('Error handling Shorebird update: $e');
    }
    return false;
  }
}
