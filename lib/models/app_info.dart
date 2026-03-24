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
    Uint8List? iconBytes;
    if (map['icon'] != null) {
      try {
        iconBytes = _decodeBase64(map['icon'] as String);
      } catch (_) {
        iconBytes = null;
      }
    }

    return AppInfo(
      packageName: map['packageName'] as String,
      appName: map['appName'] as String,
      icon: iconBytes,
      isLocked: isLocked,
    );
  }

  static Uint8List _decodeBase64(String base64String) {
    // Dart's base64Decode
    return Uint8List.fromList(
      List<int>.from(Uri.parse('data:;base64,$base64String').data!.contentAsBytes()),
    );
  }
}
