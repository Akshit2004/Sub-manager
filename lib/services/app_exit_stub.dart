import 'package:flutter/services.dart';

/// Stub implementation of terminateApp for platforms where dart:io is unavailable (e.g. Web)
void terminateApp() {
  SystemNavigator.pop();
}
