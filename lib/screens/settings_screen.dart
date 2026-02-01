import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_widgets.dart';
import '../providers/app_providers.dart';
import '../widgets/app_scaffold.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isChecking = false;
  Map<String, dynamic> _systemInfo = {};

  @override
  void initState() {
    super.initState();
    _checkSystem();
  }

  Future<void> _checkSystem() async {
    setState(() => _isChecking = true);

    final info = <String, dynamic>{};

    // Prüfe cdparanoia
    try {
      final result = await Process.run('cdparanoia', ['-V']);
      final output = result.stderr.toString();
      final versionMatch = RegExp(
        r'cdparanoia\s+(?:III\s+)?(?:release\s+)?([^\s]+)',
      ).firstMatch(output);
      info['cdparanoia'] = {
        'installed': true,
        'version': versionMatch?.group(1) ?? 'Unbekannt',
        'output': output,
      };
    } catch (e) {
      info['cdparanoia'] = {'installed': false};
    }

    // Prüfe ffmpeg
    try {
      final result = await Process.run('ffmpeg', ['-version']);
      final output = result.stdout.toString();
      final versionMatch = RegExp(
        r'ffmpeg version ([^\s]+)',
      ).firstMatch(output);
      info['ffmpeg'] = {
        'installed': true,
        'version': versionMatch?.group(1) ?? 'Unbekannt',
        'output': output,
      };
    } catch (e) {
      info['ffmpeg'] = {'installed': false};
    }

    // Prüfe Python libdiscid (für korrekte Disc-ID Berechnung)
    try {
      // Versuche beide Import-Varianten (native discid oder libdiscid.compat)
      final result = await Process.run('python3', [
        '-c',
        '''try:
    import discid
    print(discid.__version__)
except ImportError:
    from libdiscid.compat import discid
    print(discid.__version__)'''
      ]);
      if (result.exitCode == 0) {
        final version = result.stdout.toString().trim();
        info['python-discid'] = {
          'installed': true,
          'version': version,
        };
      } else {
        info['python-discid'] = {'installed': false};
      }
    } catch (e) {
      info['python-discid'] = {'installed': false};
    }

    // Prüfe eject (optional)
    try {
      final result = await Process.run('eject', ['--version']);
      final output = result.stdout.toString() + result.stderr.toString();
      final versionMatch = RegExp(
        r'eject\s+version\s+([^\s]+)',
      ).firstMatch(output);
      info['eject'] = {
        'installed': true,
        'version': versionMatch?.group(1) ?? 'Installiert',
        'output': output,
      };
    } catch (e) {
      info['eject'] = {'installed': false};
    }

    // Prüfe CD-Laufwerk
    final cdDevices = ['/dev/cdrom', '/dev/sr0', '/dev/dvd'];
    final availableDevices = <String>[];
    for (final device in cdDevices) {
      if (await File(device).exists()) {
        availableDevices.add(device);
      }
    }
    info['cdDevices'] = availableDevices;

    setState(() {
      _systemInfo = info;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Einstellungen',
      currentRoute: '/settings',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _checkSystem,
          tooltip: 'System neu prüfen',
        ),
      ],
      body: _isChecking
          ? _buildLoadingView()
          : _buildSettingsContent(),
    );
  }


  Widget _buildLoadingView() {
    return Center(
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'System wird geprüft...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSystemStatusCard(),
          const SizedBox(height: 24),
          _buildMusicBrainzCard(),
          const SizedBox(height: 24),
          _buildToolCard(
            name: 'cdparanoia',
            description: 'CD-Ripping Tool',
            info: _systemInfo['cdparanoia'],
            icon: Icons.album,
          ),
          const SizedBox(height: 16),
          _buildToolCard(
            name: 'FFmpeg',
            description: 'Audio-Konvertierung',
            info: _systemInfo['ffmpeg'],
            icon: Icons.audiotrack,
          ),
          const SizedBox(height: 16),
          _buildToolCard(
            name: 'Python libdiscid',
            description: 'CD-Identifikation (für korrekte MusicBrainz Disc-IDs)',
            info: _systemInfo['python-discid'],
            icon: Icons.fingerprint,
            optional: false,
          ),
          const SizedBox(height: 16),
          _buildToolCard(
            name: 'eject',
            description: 'CD-Auswurf',
            info: _systemInfo['eject'],
            icon: Icons.eject,
            optional: true,
          ),
          const SizedBox(height: 24),
          _buildCDDevicesCard(),
          const SizedBox(height: 24),
          _buildAboutCard(),
        ],
      ),
    );
  }

  Widget _buildSystemStatusCard() {
    final cdparanoiaOk = _systemInfo['cdparanoia']?['installed'] ?? false;
    final ffmpegOk = _systemInfo['ffmpeg']?['installed'] ?? false;
    final allOk = cdparanoiaOk && ffmpegOk;

    return GlassCard(
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: allOk
                  ? const LinearGradient(
                      colors: [Colors.green, Colors.lightGreenAccent],
                    )
                  : const LinearGradient(
                      colors: [Colors.orange, Colors.deepOrange],
                    ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: allOk
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.orange.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              allOk ? Icons.check_circle : Icons.warning,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            allOk ? 'System bereit' : 'Fehlende Komponenten',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            allOk
                ? 'Alle erforderlichen Tools sind installiert'
                : 'Bitte installieren Sie die fehlenden Tools',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMusicBrainzCard() {
    final settings = ref.watch(settingsProvider);
    final email = settings.when(
      data: (v) => v,
      loading: () => null,
      error: (_, stack) => null,
    );

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const GradientIcon(
                icon: Icons.cloud,
                size: 28,
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'MusicBrainz',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Kontakt-E-Mail (wird im User-Agent an MusicBrainz gesendet).',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  email ?? 'Nicht gesetzt',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  final controller = TextEditingController(text: email ?? '');
                  if (!mounted) return;
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('MusicBrainz Kontakt-E-Mail'),
                      content: TextField(
                        controller: controller,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'me@example.com',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Abbrechen'),
                        ),
                        TextButton(
                          onPressed: () async {
                            await ref
                                .read(settingsProvider.notifier)
                                .setContactEmail(controller.text.trim());
                            if (context.mounted) {
                              Navigator.of(context).pop(true);
                            }
                          },
                          child: const Text('Speichern'),
                        ),
                      ],
                    ),
                  );

                  if (result == true && mounted) {
                    // Optionally show a short confirmation
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Kontakt-E-Mail gespeichert. Bitte App neu starten, damit der User-Agent übernommen wird.',
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard({
    required String name,
    required String description,
    required Map<String, dynamic>? info,
    required IconData icon,
    bool optional = false,
  }) {
    final isInstalled = info?['installed'] ?? false;
    final version = info?['version'];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: isInstalled
                      ? const LinearGradient(
                          colors: [Colors.green, Colors.lightGreen],
                        )
                      : const LinearGradient(
                          colors: [Colors.red, Colors.deepOrange],
                        ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (optional) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Optional',
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  if (isInstalled) ...[
                    IconButton(
                      icon: const Icon(Icons.info_outline, size: 20),
                      onPressed: () => _showToolInfo(context, name, info),
                      tooltip: 'Weitere Informationen',
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ],
                  Icon(
                    isInstalled ? Icons.check_circle : Icons.cancel,
                    color: isInstalled ? Colors.green : Colors.red,
                    size: 32,
                  ),
                ],
              ),
            ],
          ),
          if (isInstalled && version != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Version: $version',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
          if (!isInstalled) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _buildInstallInstructions(name),
          ],
        ],
      ),
    );
  }

  Widget _buildInstallInstructions(String toolName) {
    final instructions = _getInstallInstructions(toolName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.terminal, size: 16, color: AppTheme.accentColor),
            const SizedBox(width: 8),
            const Text(
              'Installationsanleitung',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...instructions.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: entry.value));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Befehl in die Zwischenablage kopiert'),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        tooltip: 'Kopieren',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Map<String, String> _getInstallInstructions(String tool) {
    final toolLower = tool.toLowerCase();

    if (toolLower == 'cdparanoia') {
      return {
        'Ubuntu/Debian': 'sudo apt-get install cdparanoia',
        'Fedora/RHEL': 'sudo dnf install cdparanoia',
        'Arch Linux': 'sudo pacman -S cdparanoia',
      };
    } else if (toolLower == 'ffmpeg') {
      return {
        'Ubuntu/Debian': 'sudo apt-get install ffmpeg',
        'Fedora/RHEL': 'sudo dnf install ffmpeg',
        'Arch Linux': 'sudo pacman -S ffmpeg',
      };
    } else if (toolLower == 'python libdiscid') {
      return {
        'Ubuntu/Debian': 'sudo apt-get install python3-libdiscid',
        'Fedora/RHEL': 'sudo dnf install python3-libdiscid',
        'Arch Linux': 'sudo pacman -S python-discid',
      };
    } else if (toolLower == 'eject') {
      return {
        'Ubuntu/Debian': 'sudo apt-get install eject',
        'Fedora/RHEL': 'sudo dnf install eject',
        'Arch Linux': 'sudo pacman -S util-linux',
      };
    }

    return {};
  }

  Widget _buildCDDevicesCard() {
    final devices = _systemInfo['cdDevices'] as List<String>? ?? [];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const GradientIcon(
                icon: Icons.disc_full,
                size: 28,
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'CD-Laufwerke',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (devices.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Keine CD-Laufwerke gefunden. Stellen Sie sicher, dass ein CD-Laufwerk angeschlossen ist.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            )
          else
            ...devices.map(
              (device) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        device,
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAboutCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const GradientIcon(
                icon: Icons.info,
                size: 28,
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Über',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('App', 'CD Ripper Pro'),
          _buildInfoRow('Version', '1.0.0'),
          _buildInfoRow('Flutter', '3.10.7+'),
          const SizedBox(height: 12),
          Text(
            'Ein modernes Frontend für cdparanoia zum Rippen und Konvertieren von Audio-CDs mit MusicBrainz-Integration.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  void _showToolInfo(BuildContext context, String name, Map<String, dynamic>? info) {
    final String content = _getToolInfoText(name, info);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline),
            const SizedBox(width: 12),
            Expanded(
              child: Text(name),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(content),
              if (info?['version'] != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Version: ${info!['version']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
              if (info?['output'] != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    (info!['output'] as String).split('\\n').take(10).join('\\n'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  String _getToolInfoText(String name, Map<String, dynamic>? info) {
    final nameLower = name.toLowerCase();
    
    if (nameLower == 'cdparanoia') {
      return 'cdparanoia ist das Haupt-Tool zum Auslesen (Rippen) von Audio-CDs. '
          'Es liest die Audiodaten sektorweise vom CD-Laufwerk und korrigiert dabei '
          'automatisch Lesefehler.\\n\\n'
          'Ohne cdparanoia kann die App keine CDs rippen.';
    } else if (nameLower == 'ffmpeg') {
      return 'FFmpeg wird verwendet, um die von cdparanoia erstellten WAV-Dateien '
          'in verschiedene Formate zu konvertieren (MP3, FLAC, AAC, etc.).\\n\\n'
          'Ohne FFmpeg können CDs nur als unkomprimierte WAV-Dateien gespeichert werden.';
    } else if (nameLower == 'python libdiscid') {
      return 'Python libdiscid ist die offizielle Bibliothek zur Berechnung von '
          'MusicBrainz Disc-IDs. Diese IDs werden verwendet, um CDs eindeutig zu '
          'identifizieren und Metadaten (Titel, Interpret, Tracks) von MusicBrainz '
          'abzurufen.\\n\\n'
          'libdiscid ignoriert automatisch Data-Tracks und berechnet die Disc-ID '
          'korrekt nach MusicBrainz-Spezifikation.\\n\\n'
          'Ohne libdiscid fällt die App auf cdparanoia zurück, was bei Multi-Session-CDs '
          '(Audio + Data) zu ungenauen Ergebnissen führen kann.';
    } else if (nameLower == 'eject') {
      return 'Das eject-Tool wird verwendet, um das CD-Laufwerk nach dem Rippen '
          'automatisch auszuwerfen.\\n\\n'
          'Dies ist optional und nur eine Komfortfunktion.';
    }
    
    return 'Keine zusätzlichen Informationen verfügbar.';
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
