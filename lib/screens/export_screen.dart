import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/cd_info.dart';
import '../models/ripping_config.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/app_scaffold.dart';

enum ExportErrorAction { retry, skip, abort }

class ExportScreen extends ConsumerStatefulWidget {
  final RippingConfig? config;

  const ExportScreen({super.key, this.config});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  AudioFormat _selectedFormat = AudioFormat.flac;
  int _quality = 8; // FLAC: 0-10, MP3: 0-9
  int _bitrate = 320; // für CBR
  bool _useVBR = true;
  String? _outputDirectory;
  bool _isExporting = false;
  bool _autoStarted = false;
  final Map<int, double> _trackProgress = {};
  final Map<int, String> _trackStatus = {};

  @override
  void initState() {
    super.initState();
    if (widget.config != null) {
      _loadFromConfig();
    } else {
      _loadDefaultOutputDirectory();
    }
  }

  void _loadFromConfig() {
    final config = widget.config!;
    setState(() {
      _selectedFormat = config.format;
      _outputDirectory = config.outputDirectory;
      // Load format-specific options
      if (config.formatOptions.containsKey(FormatOptions.mp3ModeKey)) {
        _useVBR = config.formatOptions[FormatOptions.mp3ModeKey] == 'vbr';
      }
      if (config.formatOptions.containsKey(FormatOptions.mp3QualityKey)) {
        _quality = config.formatOptions[FormatOptions.mp3QualityKey];
      }
      if (config.formatOptions.containsKey(FormatOptions.aacBitrateKey)) {
        _bitrate = config.formatOptions[FormatOptions.aacBitrateKey];
      }
    });

    // Auto-start export after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_autoStarted && mounted) {
        _autoStarted = true;
        _startExportWithConfig();
      }
    });
  }

  Future<void> _loadDefaultOutputDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    setState(() {
      _outputDirectory = '${directory.path}/CD_Rips';
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isExporting, // Verhindere Zurück-Navigation während Export
      child: Stack(
        children: [
          AppScaffold(
            title: 'Export & Konvertierung',
            currentRoute: '/export', // Not in sidebar, but ensures consistent look
            body: _isExporting
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _buildProgressSection(),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildFormatSelection(),
                        const SizedBox(height: 24),
                        _buildQualitySettings(),
                        const SizedBox(height: 24),
                        _buildOutputDirectory(),
                        const SizedBox(height: 24),
                        _buildSelectedTracks(),
                        const SizedBox(height: 24),
                        _buildExportButton(),
                      ],
                    ),
                  ),
          ),
          // Modal Barrier während Export
          if (_isExporting)
            ModalBarrier(
              dismissible: false,
              color: Colors.black.withValues(alpha: 0.5),
            ),
          // Progress Overlay
          if (_isExporting)
            Center(
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  constraints: BoxConstraints(
                    minWidth: 400,
                    maxWidth: MediaQuery.of(context).size.width * 0.9,
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  margin: const EdgeInsets.all(24),
                  child: GlassCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Export läuft...',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Bitte warten Sie, bis der Vorgang abgeschlossen ist.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Flexible(
                          child: SingleChildScrollView(
                            child: _buildProgressList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildFormatSelection() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const GradientIcon(
                icon: Icons.audiotrack,
                size: 28,
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Audio-Format',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: AudioFormat.values.map((format) {
              final isSelected = _selectedFormat == format;
              return InkWell(
                onTap: _isExporting
                    ? null
                    : () {
                        setState(() {
                          _selectedFormat = format;
                          // Standard-Qualität für Format setzen
                          if (format == AudioFormat.flac) {
                            _quality = 8;
                          } else if (format == AudioFormat.mp3) {
                            _quality = 2;
                            _bitrate = 320;
                          } else if (format == AudioFormat.ogg) {
                            _quality = 6;
                          }
                        });
                      },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppTheme.primaryGradient : null,
                    color: isSelected
                        ? null
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        format.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getFormatDescription(format),
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.9)
                              : Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _getFormatDescription(AudioFormat format) {
    switch (format) {
      case AudioFormat.flac:
        return 'Verlustfrei';
      case AudioFormat.mp3:
        return 'Universal';
      case AudioFormat.aac:
        return 'Apple/iTunes';
      case AudioFormat.opus:
        return 'Modern';
      case AudioFormat.ogg:
        return 'Open Source';
      case AudioFormat.wav:
        return 'Unkomprimiert';
      case AudioFormat.alac:
        return 'Apple Lossless';
      case AudioFormat.ape:
        return 'Kompression';
    }
  }

  Widget _buildQualitySettings() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Qualität & Einstellungen',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          if (_selectedFormat == AudioFormat.mp3) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    _useVBR
                        ? 'VBR (Variable Bitrate)'
                        : 'CBR (Konstante Bitrate)',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                Switch(
                  value: _useVBR,
                  onChanged: _isExporting
                      ? null
                      : (value) => setState(() => _useVBR = value),
                  activeThumbColor: AppTheme.primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_useVBR) ...[
              Text(
                'VBR Qualität: ${_getMP3QualityLabel(_quality)}',
                style: const TextStyle(fontSize: 16),
              ),
              Slider(
                value: _quality.toDouble(),
                min: 0,
                max: 9,
                divisions: 9,
                label: _getMP3QualityLabel(_quality),
                onChanged: _isExporting
                    ? null
                    : (value) => setState(() => _quality = value.round()),
                activeColor: AppTheme.primaryColor,
              ),
            ] else ...[
              Text(
                'Bitrate: $_bitrate kbps',
                style: const TextStyle(fontSize: 16),
              ),
              Slider(
                value: _bitrate.toDouble(),
                min: 128,
                max: 320,
                divisions: 6,
                label: '$_bitrate kbps',
                onChanged: _isExporting
                    ? null
                    : (value) {
                        final values = [128, 160, 192, 224, 256, 288, 320];
                        final index = ((value - 128) / 32).round();
                        setState(() => _bitrate = values[index.clamp(0, 6)]);
                      },
                activeColor: AppTheme.primaryColor,
              ),
            ],
          ] else if (_selectedFormat == AudioFormat.flac) ...[
            Text(
              'Kompressionslevel: $_quality',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Schnell',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _quality.toDouble(),
                    min: 0,
                    max: 8,
                    divisions: 8,
                    label: _quality.toString(),
                    onChanged: _isExporting
                        ? null
                        : (value) => setState(() => _quality = value.round()),
                    activeColor: AppTheme.primaryColor,
                  ),
                ),
                Text(
                  'Klein',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ] else if (_selectedFormat == AudioFormat.ogg) ...[
            Text(
              'Qualität: ${_getOggQualityLabel(_quality)}',
              style: const TextStyle(fontSize: 16),
            ),
            Slider(
              value: _quality.toDouble(),
              min: -1,
              max: 10,
              divisions: 11,
              label: _getOggQualityLabel(_quality),
              onChanged: _isExporting
                  ? null
                  : (value) => setState(() => _quality = value.round()),
              activeColor: AppTheme.primaryColor,
            ),
          ] else if (_selectedFormat == AudioFormat.aac ||
              _selectedFormat == AudioFormat.opus) ...[
            Text(
              'Bitrate: $_bitrate kbps',
              style: const TextStyle(fontSize: 16),
            ),
            Slider(
              value: _bitrate.toDouble(),
              min: 96,
              max: 320,
              divisions: 8,
              label: '$_bitrate kbps',
              onChanged: _isExporting
                  ? null
                  : (value) =>
                        setState(() => _bitrate = value.round() ~/ 32 * 32),
              activeColor: AppTheme.primaryColor,
            ),
          ],
        ],
      ),
    );
  }

  String _getMP3QualityLabel(int quality) {
    const labels = [
      'Beste (V0 ~245kbps)',
      'V1 (~225kbps)',
      'V2 (~190kbps)',
      'V3 (~175kbps)',
      'V4 (~165kbps)',
      'V5 (~130kbps)',
      'V6 (~115kbps)',
      'V7 (~100kbps)',
      'V8 (~85kbps)',
      'V9 (~65kbps)',
    ];
    return labels[quality.clamp(0, 9)];
  }

  String _getOggQualityLabel(int quality) {
    if (quality < 0) return 'Niedrig (~64kbps)';
    if (quality <= 3) return 'Mittel (~112kbps)';
    if (quality <= 6) return 'Gut (~160kbps)';
    if (quality <= 8) return 'Sehr gut (~192kbps)';
    return 'Exzellent (~256kbps)';
  }

  Widget _buildOutputDirectory() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ausgabe-Verzeichnis',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _outputDirectory ?? 'Nicht ausgewählt',
                          style: const TextStyle(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isExporting ? null : _selectOutputDirectory,
                icon: const Icon(Icons.folder_open),
                label: const Text('Ändern'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTracks() {
    // Wenn Config vorhanden ist, verwende Tracks aus Config
    if (widget.config != null) {
      final cdInfoAsync = ref.watch(cdInfoProvider);

      return cdInfoAsync.when(
        data: (cdInfo) {
          if (cdInfo == null) return const SizedBox.shrink();

          final tracks = cdInfo.tracks
              .where((t) => widget.config!.selectedTracks.contains(t.number))
              .toList();

          return GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ausgewählte Tracks (${tracks.length})',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...tracks.map((track) => _buildTrackPreview(track)),
              ],
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (error, stack) => const SizedBox.shrink(),
      );
    }

    // Sonst verwende selectedTracksProvider (Legacy)
    final selectedTracks = ref.watch(selectedTracksProvider);
    final cdInfoAsync = ref.watch(cdInfoProvider);

    return cdInfoAsync.when(
      data: (cdInfo) {
        if (cdInfo == null) return const SizedBox.shrink();

        final tracks = cdInfo.tracks
            .where((t) => selectedTracks.contains(t.number))
            .toList();

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ausgewählte Tracks (${tracks.length})',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...tracks.map((track) => _buildTrackPreview(track)),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildTrackPreview(Track track) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                track.number.toString(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              track.metadata?.title ?? 'Track ${track.number}',
              style: const TextStyle(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _formatDuration(track.duration),
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    // Verwende Tracks aus Config wenn vorhanden, sonst selectedTracksProvider
    final trackNumbers = widget.config != null
        ? widget.config!.selectedTracks
        : ref.watch(selectedTracksProvider);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Export läuft...',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const PulsingDot(color: AppTheme.primaryColor),
            ],
          ),
          const SizedBox(height: 20),
          ...trackNumbers.map((trackNum) {
            final progress = _trackProgress[trackNum] ?? 0.0;
            return _buildTrackProgress(trackNum, progress);
          }),
        ],
      ),
    );
  }

  Widget _buildTrackProgress(int trackNumber, double progress) {
    final status = _trackStatus[trackNumber] ?? 'Warten...';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Track $trackNumber',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedProgressBar(
            progress: progress,
            gradient: AppTheme.primaryGradient,
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton() {
    final selectedTracks = ref.watch(selectedTracksProvider);

    return ElevatedButton.icon(
      onPressed: selectedTracks.isEmpty || _outputDirectory == null
          ? null
          : _startExport,
      icon: const Icon(Icons.download),
      label: Text(
        'Export starten (${selectedTracks.length} Track${selectedTracks.length > 1 ? 's' : ''})',
      ),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 20),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _selectOutputDirectory() async {
    // In einer echten Implementierung würde hier ein Verzeichnis-Picker verwendet
    // Für Linux könnte man einen Dialog mit file_picker verwenden
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ausgabe-Verzeichnis'),
        content: TextField(
          controller: TextEditingController(text: _outputDirectory),
          decoration: const InputDecoration(
            labelText: 'Pfad',
            hintText: '/home/user/Music/CD_Rips',
          ),
          onChanged: (value) => _outputDirectory = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<ExportErrorAction> _showErrorDialog(String title, String message) async {
    return await showDialog<ExportErrorAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ExportErrorAction.abort),
            child: const Text('Export abbrechen', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ExportErrorAction.skip),
            child: const Text('Track überspringen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ExportErrorAction.retry),
            child: const Text('Wiederholen'),
          ),
        ],
      ),
    ) ?? ExportErrorAction.abort;
  }

  Future<void> _startExport() async {
    if (_outputDirectory == null) return;

    setState(() {
      _isExporting = true;
      _trackProgress.clear();
      _trackStatus.clear();

      // Initialisiere alle Tracks mit "Warten..." Status
      final selectedTracks = ref.read(selectedTracksProvider);
      for (final trackNum in selectedTracks) {
        _trackProgress[trackNum] = 0.0;
        _trackStatus[trackNum] = 'Warten...';
      }
    });

    ref.read(isRippingProvider.notifier).setRipping(true);

    final cdInfoAsync = ref.read(cdInfoProvider);
    final cdService = ref.read(cdServiceProvider);
    final ffmpegService = ref.read(ffmpegServiceProvider);
    final selectedTracks = ref.read(selectedTracksProvider);

    cdInfoAsync.whenData((cdInfo) async {
      if (cdInfo == null) return;

      // Ausgabe-Verzeichnis erstellen
      final outputDir = Directory(_outputDirectory!);
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      // Temporäres Verzeichnis für WAV-Dateien
      final tempDir = Directory('${outputDir.path}/temp_wav');
      if (!await tempDir.exists()) {
        await tempDir.create();
      }

      try {
        final tracks = cdInfo.tracks
            .where((t) => selectedTracks.contains(t.number))
            .toList();

        for (int i = 0; i < tracks.length; i++) {
          final track = tracks[i];
          bool trackSuccess = false;

          while (!trackSuccess) {
            try {
              // Track rippen
              ref
                  .read(cdInfoProvider.notifier)
                  .updateTrackRipProgress(track.number, 0.0);

              final wavPath = await cdService.ripTrack(
                track: track,
                outputPath: tempDir.path,
                onProgress: (progress) {
                  setState(() {
                    _trackProgress[track.number] = progress * 0.5; // Rippen = 50%
                  });
                  ref
                      .read(cdInfoProvider.notifier)
                      .updateTrackRipProgress(track.number, progress);
                },
              );

              if (wavPath == null) {
                throw Exception('Ripping fehlgeschlagen');
              }

              // Konvertieren
              await ffmpegService.convertAudioLegacy(
                inputPath: wavPath,
                outputDir: outputDir.path,
                format: _selectedFormat,
                track: track,
                cdMetadata: cdInfo.metadata,
                trackMetadata: track.metadata,
                quality: _useVBR ? _quality : null,
                bitrate: _useVBR ? null : _bitrate,
                onProgress: (progress) {
                  setState(() {
                    _trackProgress[track.number] =
                        0.5 + (progress * 0.5); // Konvertierung = 50%
                  });
                },
              );

              ref.read(cdInfoProvider.notifier).markTrackCompleted(track.number);

              // WAV-Datei löschen
              await File(wavPath).delete();
              trackSuccess = true;
            } catch (e) {
              if (mounted) {
                final action = await _showErrorDialog(
                  'Fehler bei Track ${track.number}',
                  e.toString(),
                );

                if (action == ExportErrorAction.abort) {
                  rethrow;
                } else if (action == ExportErrorAction.skip) {
                   ref.read(cdInfoProvider.notifier).markTrackError(track.number);
                   break;
                }
                // retry: loop continues
              } else {
                 rethrow;
              }
            }
          }
        }

        // Temp-Verzeichnis löschen
        await tempDir.delete(recursive: true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Export erfolgreich abgeschlossen!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler beim Export: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } finally {
        setState(() => _isExporting = false);
        ref.read(isRippingProvider.notifier).setRipping(false);
      }
    });
  }

  Future<void> _startExportWithConfig() async {
    if (_outputDirectory == null || widget.config == null) return;

    setState(() {
      _isExporting = true;
      _trackProgress.clear();
      _trackStatus.clear();

      // Initialisiere alle Tracks mit "Warten..." Status
      for (final trackNum in widget.config!.selectedTracks) {
        _trackProgress[trackNum] = 0.0;
        _trackStatus[trackNum] = 'Warten...';
      }
    });

    ref.read(isRippingProvider.notifier).setRipping(true);

    final cdInfoAsync = ref.read(cdInfoProvider);
    final cdService = ref.read(cdServiceProvider);
    final ffmpegService = ref.read(ffmpegServiceProvider);
    final config = widget.config!;

    cdInfoAsync.whenData((cdInfo) async {
      if (cdInfo == null) return;

      // Ausgabe-Verzeichnis erstellen
      final outputDir = Directory(_outputDirectory!);
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      // Temporäres Verzeichnis für WAV-Dateien
      final tempDir = Directory('${outputDir.path}/temp_wav');
      if (!await tempDir.exists()) {
        await tempDir.create();
      }

      try {
        final tracks = cdInfo.tracks
            .where((t) => config.selectedTracks.contains(t.number))
            .toList();

        for (int i = 0; i < tracks.length; i++) {
          final track = tracks[i];
          if (!mounted) break;
          bool trackSuccess = false;
          
          while (!trackSuccess) {
            try {
              // Track rippen
              ref
                  .read(cdInfoProvider.notifier)
                  .updateTrackRipProgress(track.number, 0.0);

              if (mounted) {
                setState(() {
                  _trackStatus[track.number] = 'Rippen von CD...';
                });
              }

              _logDebug('Starting to rip track ${track.number}...');

              final wavPath = await cdService.ripTrack(
                track: track,
                outputPath: tempDir.path,
                onProgress: (progress) {
                  if (mounted) {
                    setState(() {
                      _trackProgress[track.number] = progress * 0.5; // Rippen = 50%
                      _trackStatus[track.number] =
                          'Rippen von CD... ${(progress * 100).toInt()}%';
                    });
                    ref
                        .read(cdInfoProvider.notifier)
                        .updateTrackRipProgress(track.number, progress);
                  }
                },
              );

              if (wavPath == null) {
                _logDebug('Failed to rip track ${track.number}');
                throw Exception('Ripping fehlgeschlagen');
              }

              _logDebug(
                'Track ${track.number} ripped to $wavPath, starting conversion...',
              );

              if (mounted) {
                setState(() {
                  _trackStatus[track.number] =
                      'Konvertierung zu ${config.format.extension.toUpperCase()}...';
                });
              }

              // Generiere Dateinamen aus Template
              final filename = config.generateFilename(
                track,
                cdInfo.metadata,
                track.number,
              );
              final outputPath =
                  '${outputDir.path}/$filename.${config.format.extension}';

              // Konvertieren mit Config-Optionen
              final success = await ffmpegService.convertAudio(
                inputPath: wavPath,
                outputPath: outputPath,
                format: config.format,
                formatOptions: config.formatOptions,
                track: track,
                cdMetadata: cdInfo.metadata,
                onProgress: (progress) {
                  if (mounted) {
                    setState(() {
                      _trackProgress[track.number] =
                          0.5 + (progress * 0.5); // Konvertierung = 50%
                      _trackStatus[track.number] =
                          'Konvertierung zu ${config.format.extension.toUpperCase()}... ${(progress * 100).toInt()}%';
                    });
                  }
                },
              );

              if (success) {
                _logDebug('Track ${track.number} converted successfully');
                if (mounted) {
                  setState(() {
                    _trackStatus[track.number] = 'Fertig ✓';
                    _trackProgress[track.number] = 1.0;
                  });
                }
                ref.read(cdInfoProvider.notifier).markTrackCompleted(track.number);
              } else {
                _logDebug('Failed to convert track ${track.number}');
                throw Exception('Konvertierung fehlgeschlagen');
              }

              // WAV-Datei löschen
              try {
                await File(wavPath).delete();
              } catch (e) {
                _logDebug('Could not delete temp WAV: $e');
              }
              trackSuccess = true;
            } catch (e) {
              _logDebug('Error with track ${track.number}: $e');
              
              if (mounted) {
                 final action = await _showErrorDialog(
                  'Fehler bei Track ${track.number}',
                  e.toString(),
                );
                
                if (action == ExportErrorAction.abort) {
                  rethrow;
                } else if (action == ExportErrorAction.skip) {
                   ref.read(cdInfoProvider.notifier).markTrackError(track.number);
                   setState(() {
                      _trackStatus[track.number] = 'Übersprungen';
                    });
                   break;
                }
                // retry: loop continues
              } else {
                rethrow;
              }
            }
          }
        }

        // Temp-Verzeichnis löschen
        try {
          await tempDir.delete(recursive: true);
        } catch (e) {
          _logDebug('Could not delete temp directory: $e');
        }

        // Export erfolgreich - CD auswerfen und zurück zum Hauptscreen
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Export abgeschlossen! CD wird ausgeworfen...'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // CD auswerfen
          try {
            await cdService.ejectCD();
          } catch (e) {
            _logDebug('Could not eject CD: $e');
          }

          // Kurz warten, dann zum Hauptscreen zurückkehren
          await Future.delayed(const Duration(seconds: 2));

          if (mounted) {
            // Zurück zum Hauptscreen (alle Routes außer der ersten entfernen)
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        }
      } catch (e) {
        _logDebug('Export error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler beim Export: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isExporting = false);
        }
        ref.read(isRippingProvider.notifier).setRipping(false);
      }
    });
  }

  Widget _buildProgressList() {
    final cdInfoAsync = ref.watch(cdInfoProvider);
    
    return cdInfoAsync.when(
      data: (cdInfo) {
        if (cdInfo == null) return const SizedBox.shrink();
        
        final tracksToRip = cdInfo.tracks
            .where((t) => _trackProgress.containsKey(t.number))
            .toList();
        
        if (tracksToRip.isEmpty) return const SizedBox.shrink();
        
        return Column(
          children: tracksToRip.map((track) {
            final progress = _trackProgress[track.number] ?? 0.0;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        fit: FlexFit.loose,
                        child: Text(
                          '${track.number}. ${track.metadata?.title ?? 'Track ${track.number}'}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          softWrap: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }
}

