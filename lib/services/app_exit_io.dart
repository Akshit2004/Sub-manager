import 'dart:io';

/// Native implementation of terminateApp using exit(0) to force-kill the process on Android/iOS
void terminateApp() {
  exit(0);
}
