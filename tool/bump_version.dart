// ignore_for_file: avoid_print
import 'dart:io';


void main() {
  final file = File('pubspec.yaml');
  if (!file.existsSync()) {
    print('Error: pubspec.yaml not found.');
    exit(1);
  }

  final content = file.readAsStringSync();
  
  // Match 'version: x.y.z+w' or 'version: x.y.z'
  final versionRegExp = RegExp(r'^version:\s*(\d+\.\d+\.\d+)(?:\+(\d+))?$', multiLine: true);
  final match = versionRegExp.firstMatch(content);
  
  if (match == null) {
    print('Could not find version line matching pattern (e.g. version: 1.0.0+1 or version: 1.0.0) in pubspec.yaml');
    exit(1);
  }
  
  final semVer = match.group(1)!;
  final buildNumStr = match.group(2);
  final buildNum = buildNumStr != null ? int.parse(buildNumStr) : 0;
  final newBuildNum = buildNum + 1;
  final newVersionLine = 'version: $semVer+$newBuildNum';
  
  final newContent = content.replaceAll(versionRegExp, newVersionLine);
  file.writeAsStringSync(newContent);
  
  print('Bumping version from ${match.group(0)} to $newVersionLine');
  
  // Automatically stage the pubspec.yaml change
  final result = Process.runSync('git', ['add', 'pubspec.yaml']);
  if (result.exitCode != 0) {
    print('Failed to run git add pubspec.yaml: \${result.stderr}');
    exit(result.exitCode);
  }
}
