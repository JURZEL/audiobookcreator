import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final systemStatusProvider = FutureProvider.autoDispose<SystemStatus>((
  ref,
) async {
  return await SystemStatusChecker.checkStatus();
});

class SystemStatus {
  final bool cdparanoiaInstalled;
  final bool ffmpegInstalled;
  final bool cdDiscIdInstalled;
  final List<String> cdDrives;
  final String osInfo;
  final String appVersion;

  SystemStatus({
    required this.cdparanoiaInstalled,
    required this.ffmpegInstalled,
    required this.cdDiscIdInstalled,
    required this.cdDrives,
    required this.osInfo,
    this.appVersion = '1.0.0',
  });

  bool get allDependenciesInstalled =>
      cdparanoiaInstalled && ffmpegInstalled && cdDiscIdInstalled;

  bool get hasCdDrives => cdDrives.isNotEmpty;
}

class SystemStatusChecker {
  static Future<SystemStatus> checkStatus() async {
    final cdparanoia = await _checkCommand('cdparanoia');
    final ffmpeg = await _checkCommand('ffmpeg');
    final cdDiscId = await _checkCommand('cd-discid');
    final drives = await _detectCdDrives();
    final os = _getOsInfo();

    return SystemStatus(
      cdparanoiaInstalled: cdparanoia,
      ffmpegInstalled: ffmpeg,
      cdDiscIdInstalled: cdDiscId,
      cdDrives: drives,
      osInfo: os,
    );
  }

  static Future<bool> _checkCommand(String command) async {
    try {
      final result = await Process.run('which', [command]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  static Future<List<String>> _detectCdDrives() async {
    final devices = [
      '/dev/sr0',
      '/dev/sr1',
      '/dev/sr2',
      '/dev/cdrom',
      '/dev/dvd',
    ];
    final found = <String>[];

    for (final device in devices) {
      if (await File(device).exists()) {
        found.add(device);
      }
    }

    return found;
  }

  static String _getOsInfo() {
    if (Platform.isLinux) {
      return 'Linux';
    } else if (Platform.isMacOS) {
      return 'macOS';
    } else if (Platform.isWindows) {
      return 'Windows';
    }
    return 'Unknown';
  }
}
