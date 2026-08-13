import 'dart:typed_data';

/// Represents an installed app on the device.
class AppInfo {
  final String packageName;
  final String appName;
  final Uint8List? icon;
  bool isLocked;

  AppInfo({
    required this.packageName,
    required this.appName,
    this.icon,
    this.isLocked = false,
  });

  factory AppInfo.fromMap(Map<String, dynamic> map, {bool isLocked = false}) {
    return AppInfo(
      packageName: map['packageName'] as String,
      appName: map['appName'] as String,
      isLocked: isLocked || (map['isLocked'] ?? false),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'packageName': packageName,
      'appName': appName,
      'isLocked': isLocked,
    };
  }
}
