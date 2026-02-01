import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../models/cd_info.dart';
import '../models/ripping_config.dart';
import '../widgets/glass_widgets.dart'; // Still used for GlassCard (flat)
import '../widgets/app_scaffold.dart';

class RippingConfigScreen extends ConsumerStatefulWidget {
  final CDInfo cdInfo;

  const RippingConfigScreen({super.key, required this.cdInfo});

  @override
  ConsumerState<RippingConfigScreen> createState() =>
      _RippingConfigScreenState();
}

class _RippingConfigScreenState extends ConsumerState<RippingConfigScreen> {
  late RippingConfig _config;
  late Set<int> _selectedTracks;
  final TextEditingController _outputDirController = TextEditingController();
  final TextEditingController _filenameTemplateController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedTracks = Set.from(
      List.generate(widget.cdInfo.tracks.length, (i) => i + 1),
    );
    _config = RippingConfig(
      format: AudioFormat.flac,
      outputDirectory: _getDefaultOutputDirectory(),
      filenameTemplate: RippingConfig.predefinedTemplates['Standard']!,
      formatOptions: FormatOptions.getDefaultOptions(AudioFormat.flac),
      selectedTracks: _selectedTracks.toList(),
    );
    _outputDirController.text = _config.outputDirectory;
    _filenameTemplateController.text = _config.filenameTemplate;
  }

  String _getDefaultOutputDirectory() {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '/tmp';
    return '$home/Music/CD_Rips';
  }

  @override
  void dispose() {
    _outputDirController.dispose();
    _filenameTemplateController.dispose();
    super.dispose();
  }

  Future<void> _selectOutputDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      setState(() {
        _config = _config.copyWith(outputDirectory: selectedDirectory);
        _outputDirController.text = selectedDirectory;
      });
    }
  }

  void _startRipping() {
    if (_selectedTracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte wählen Sie mindestens einen Track aus'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_config.outputDirectory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte wählen Sie einen Ausgabe-Ordner'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Navigiere zum Export-Screen mit der Konfiguration
    Navigator.pop(context);
    Navigator.pushNamed(context, '/export', arguments: _config);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'CD Rippen',
      currentRoute: '/cd-ripper',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildFormatSelection(),
            const SizedBox(height: 24),
            _buildTrackSelection(),
            const SizedBox(height: 24),
            _buildOutputDirectory(),
            const SizedBox(height: 24),
            _buildFilenameTemplate(),
            const SizedBox(height: 24),
            if (_hasFormatOptions()) ...[
              _buildFormatOptions(),
              const SizedBox(height: 24),
            ],
            _buildAdditionalOptions(),
            const SizedBox(height: 32),
            _buildStartButton(),
            const SizedBox(height: 32),
          ],
        ),
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
              const Icon(Icons.audiotrack, color: Colors.blue),
              const SizedBox(width: 12),
              const Text(
                'Audio-Format',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: AudioFormat.values.map((format) {
              final isSelected = _config.format == format;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _config = _config.copyWith(
                      format: format,
                      formatOptions: FormatOptions.getDefaultOptions(format),
                    );
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          )
                        : null,
                    color: isSelected
                        ? null
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : Colors.white.withValues(alpha: 0.1),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        format.displayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      Text(
                        '.${format.extension}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
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

  Widget _buildTrackSelection() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.playlist_add_check, color: Colors.green),
              const SizedBox(width: 12),
              const Text(
                'Tracks auswählen',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selectedTracks.length == widget.cdInfo.tracks.length) {
                      _selectedTracks.clear();
                    } else {
                      _selectedTracks = Set.from(
                        List.generate(
                          widget.cdInfo.tracks.length,
                          (i) => i + 1,
                        ),
                      );
                    }
                    _config = _config.copyWith(
                      selectedTracks: _selectedTracks.toList(),
                    );
                  });
                },
                child: Text(
                  _selectedTracks.length == widget.cdInfo.tracks.length
                      ? 'Alle abwählen'
                      : 'Alle auswählen',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${_selectedTracks.length} von ${widget.cdInfo.tracks.length} Tracks ausgewählt',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          ...widget.cdInfo.tracks.map((track) {
            final isSelected = _selectedTracks.contains(track.number);
            return CheckboxListTile(
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedTracks.add(track.number);
                  } else {
                    _selectedTracks.remove(track.number);
                  }
                  _config = _config.copyWith(
                    selectedTracks: _selectedTracks.toList(),
                  );
                });
              },
              title: Text(
                track.metadata?.title ?? 'Track ${track.number}',
                style: const TextStyle(fontSize: 16),
              ),
              subtitle: Text(
                _formatDuration(track.duration),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              secondary: CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                child: Text('${track.number}'),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOutputDirectory() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_open, color: Colors.orange),
              const SizedBox(width: 12),
              const Text(
                'Ausgabe-Ordner',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _outputDirController,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'Ausgabe-Ordner wählen',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _selectOutputDirectory,
                icon: const Icon(Icons.folder),
                label: const Text('Wählen'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilenameTemplate() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.text_fields, color: Colors.purple),
              const SizedBox(width: 12),
              const Text(
                'Dateinamen-Vorlage',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _filenameTemplateController,
            onChanged: (value) {
              setState(() {
                _config = _config.copyWith(filenameTemplate: value);
              });
            },
            decoration: InputDecoration(
              hintText: 'z.B. %TrackNumber - %Title',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Vordefinierte Vorlagen:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: RippingConfig.predefinedTemplates.entries.map((entry) {
              return ActionChip(
                label: Text(entry.key),
                onPressed: () {
                  setState(() {
                    _filenameTemplateController.text = entry.value;
                    _config = _config.copyWith(filenameTemplate: entry.value);
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          ExpansionTile(
            title: const Text('Verfügbare Platzhalter'),
            children: [
              ...RippingConfig.availablePlaceholders.entries.map((entry) {
                return ListTile(
                  dense: true,
                  title: Text(
                    entry.key,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      final currentText = _filenameTemplateController.text;
                      _filenameTemplateController.text =
                          currentText + entry.key;
                      _config = _config.copyWith(
                        filenameTemplate: _filenameTemplateController.text,
                      );
                    },
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.preview, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text(
                      'Vorschau:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _getFilenamePreview(),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _hasFormatOptions() {
    // Nur Formate mit konfigurierbaren Optionen anzeigen
    return _config.format == AudioFormat.mp3 ||
        _config.format == AudioFormat.flac ||
        _config.format == AudioFormat.aac ||
        _config.format == AudioFormat.opus ||
        _config.format == AudioFormat.ogg;
  }

  Widget _buildFormatOptions() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, color: Colors.cyan),
              const SizedBox(width: 12),
              const Text(
                'Format-Optionen',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFormatSpecificOptions(),
        ],
      ),
    );
  }

  Widget _buildFormatSpecificOptions() {
    switch (_config.format) {
      case AudioFormat.mp3:
        return _buildMP3Options();
      case AudioFormat.flac:
        return _buildFLACOptions();
      case AudioFormat.aac:
        return _buildAACOptions();
      case AudioFormat.opus:
        return _buildOpusOptions();
      case AudioFormat.ogg:
        return _buildOGGOptions();
      default:
        return Text(
          'Keine zusätzlichen Optionen für ${_config.format.displayName}',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        );
    }
  }

  Widget _buildMP3Options() {
    final mode = _config.formatOptions[FormatOptions.mp3ModeKey] ?? 'vbr';
    final quality = _config.formatOptions[FormatOptions.mp3QualityKey] ?? 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Modus:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'vbr',
              label: Text('VBR'),
              icon: Icon(Icons.auto_awesome),
            ),
            ButtonSegment(
              value: 'cbr',
              label: Text('CBR'),
              icon: Icon(Icons.straighten),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (Set<String> newSelection) {
            setState(() {
              _config = _config.copyWith(
                formatOptions: {
                  ..._config.formatOptions,
                  FormatOptions.mp3ModeKey: newSelection.first,
                },
              );
            });
          },
        ),
        const SizedBox(height: 16),
        if (mode == 'vbr') ...[
          const Text(
            'Qualität:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Slider(
            value: quality.toDouble(),
            min: 0,
            max: 9,
            divisions: 9,
            label: 'V$quality (~${_getMP3VBRBitrate(quality)} kbps)',
            onChanged: (value) {
              setState(() {
                _config = _config.copyWith(
                  formatOptions: {
                    ..._config.formatOptions,
                    FormatOptions.mp3QualityKey: value.toInt(),
                  },
                );
              });
            },
          ),
          Text(
            'V$quality: ~${_getMP3VBRBitrate(quality)} kbps (höher = kleinere Datei)',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Empfehlungen:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPresetChip('Musik', 'V2 (~190 kbps)', () {
                setState(() {
                  _config = _config.copyWith(
                    formatOptions: {
                      ..._config.formatOptions,
                      FormatOptions.mp3QualityKey: 2,
                    },
                  );
                });
              }),
              _buildPresetChip('Hörspiel', 'V4 (~165 kbps)', () {
                setState(() {
                  _config = _config.copyWith(
                    formatOptions: {
                      ..._config.formatOptions,
                      FormatOptions.mp3QualityKey: 4,
                    },
                  );
                });
              }),
              _buildPresetChip('Hörbuch', 'V6 (~115 kbps)', () {
                setState(() {
                  _config = _config.copyWith(
                    formatOptions: {
                      ..._config.formatOptions,
                      FormatOptions.mp3QualityKey: 6,
                    },
                  );
                });
              }),
            ],
          ),
        ] else ...[
          const Text('Bitrate:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [128, 160, 192, 256, 320].map((br) {
              return ChoiceChip(
                label: Text('$br kbps'),
                selected: quality == br,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _config = _config.copyWith(
                        formatOptions: {
                          ..._config.formatOptions,
                          FormatOptions.mp3QualityKey: br,
                        },
                      );
                    });
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          const Text(
            'Empfehlungen:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPresetChip('Musik', '320 kbps', () {
                setState(() {
                  _config = _config.copyWith(
                    formatOptions: {
                      ..._config.formatOptions,
                      FormatOptions.mp3QualityKey: 320,
                    },
                  );
                });
              }),
              _buildPresetChip('Hörspiel', '192 kbps', () {
                setState(() {
                  _config = _config.copyWith(
                    formatOptions: {
                      ..._config.formatOptions,
                      FormatOptions.mp3QualityKey: 192,
                    },
                  );
                });
              }),
              _buildPresetChip('Hörbuch', '128 kbps', () {
                setState(() {
                  _config = _config.copyWith(
                    formatOptions: {
                      ..._config.formatOptions,
                      FormatOptions.mp3QualityKey: 128,
                    },
                  );
                });
              }),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFLACOptions() {
    final compression =
        _config.formatOptions[FormatOptions.flacCompressionKey] ?? 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kompression:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Slider(
          value: compression.toDouble(),
          min: 0,
          max: 8,
          divisions: 8,
          label: 'Level $compression',
          onChanged: (value) {
            setState(() {
              _config = _config.copyWith(
                formatOptions: {
                  ..._config.formatOptions,
                  FormatOptions.flacCompressionKey: value.toInt(),
                },
              );
            });
          },
        ),
        Text(
          'Level $compression (höher = kleinere Datei, längere Kodierung)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildAACOptions() {
    final bitrate = _config.formatOptions[FormatOptions.aacBitrateKey] ?? 192;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Bitrate:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [96, 128, 160, 192, 256, 320].map((br) {
            return ChoiceChip(
              label: Text('$br kbps'),
              selected: bitrate == br,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _config = _config.copyWith(
                      formatOptions: {
                        ..._config.formatOptions,
                        FormatOptions.aacBitrateKey: br,
                      },
                    );
                  });
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        const Text(
          'Empfehlungen:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildPresetChip('Musik', '256 kbps', () {
              setState(() {
                _config = _config.copyWith(
                  formatOptions: {
                    ..._config.formatOptions,
                    FormatOptions.aacBitrateKey: 256,
                  },
                );
              });
            }),
            _buildPresetChip('Hörspiel', '160 kbps', () {
              setState(() {
                _config = _config.copyWith(
                  formatOptions: {
                    ..._config.formatOptions,
                    FormatOptions.aacBitrateKey: 160,
                  },
                );
              });
            }),
            _buildPresetChip('Hörbuch', '96 kbps', () {
              setState(() {
                _config = _config.copyWith(
                  formatOptions: {
                    ..._config.formatOptions,
                    FormatOptions.aacBitrateKey: 96,
                  },
                );
              });
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildOpusOptions() {
    final bitrate = _config.formatOptions[FormatOptions.opusBitrateKey] ?? 128;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Bitrate:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [64, 96, 128, 160, 192, 256].map((br) {
            return ChoiceChip(
              label: Text('$br kbps'),
              selected: bitrate == br,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _config = _config.copyWith(
                      formatOptions: {
                        ..._config.formatOptions,
                        FormatOptions.opusBitrateKey: br,
                      },
                    );
                  });
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        const Text(
          'Empfehlungen:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildPresetChip('Musik', '192 kbps', () {
              setState(() {
                _config = _config.copyWith(
                  formatOptions: {
                    ..._config.formatOptions,
                    FormatOptions.opusBitrateKey: 192,
                  },
                );
              });
            }),
            _buildPresetChip('Hörspiel', '128 kbps', () {
              setState(() {
                _config = _config.copyWith(
                  formatOptions: {
                    ..._config.formatOptions,
                    FormatOptions.opusBitrateKey: 128,
                  },
                );
              });
            }),
            _buildPresetChip('Hörbuch', '64 kbps', () {
              setState(() {
                _config = _config.copyWith(
                  formatOptions: {
                    ..._config.formatOptions,
                    FormatOptions.opusBitrateKey: 64,
                  },
                );
              });
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildOGGOptions() {
    final quality = _config.formatOptions[FormatOptions.oggQualityKey] ?? 6;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Qualität:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Slider(
          value: quality.toDouble(),
          min: 0,
          max: 10,
          divisions: 10,
          label: 'Q$quality (~${_getOGGBitrate(quality)} kbps)',
          onChanged: (value) {
            setState(() {
              _config = _config.copyWith(
                formatOptions: {
                  ..._config.formatOptions,
                  FormatOptions.oggQualityKey: value.toInt(),
                },
              );
            });
          },
        ),
        Text(
          'Q$quality: ~${_getOGGBitrate(quality)} kbps',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Empfehlungen:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildPresetChip('Musik', 'Q8 (~256 kbps)', () {
              setState(() {
                _config = _config.copyWith(
                  formatOptions: {
                    ..._config.formatOptions,
                    FormatOptions.oggQualityKey: 8,
                  },
                );
              });
            }),
            _buildPresetChip('Hörspiel', 'Q6 (~192 kbps)', () {
              setState(() {
                _config = _config.copyWith(
                  formatOptions: {
                    ..._config.formatOptions,
                    FormatOptions.oggQualityKey: 6,
                  },
                );
              });
            }),
            _buildPresetChip('Hörbuch', 'Q4 (~128 kbps)', () {
              setState(() {
                _config = _config.copyWith(
                  formatOptions: {
                    ..._config.formatOptions,
                    FormatOptions.oggQualityKey: 4,
                  },
                );
              });
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildAdditionalOptions() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings, color: Colors.pink),
              const SizedBox(width: 12),
              const Text(
                'Zusätzliche Optionen',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: _config.embedCoverArt,
            onChanged: (value) {
              setState(() {
                _config = _config.copyWith(embedCoverArt: value);
              });
            },
            title: const Text('Cover-Art einbetten'),
            subtitle: const Text('Album-Cover in Audio-Dateien einbetten'),
            secondary: const Icon(Icons.image),
          ),
          SwitchListTile(
            value: _config.createPlaylist,
            onChanged: (value) {
              setState(() {
                _config = _config.copyWith(createPlaylist: value);
              });
            },
            title: const Text('Playlist erstellen'),
            subtitle: const Text('M3U-Playlist-Datei erstellen'),
            secondary: const Icon(Icons.playlist_play),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    final canStart =
        _selectedTracks.isNotEmpty && _config.outputDirectory.isNotEmpty;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: canStart ? _startRipping : null,
        icon: const Icon(Icons.play_arrow, size: 28),
        label: const Text(
          'Ripping starten',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: canStart ? Colors.green : Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _getFilenamePreview() {
    if (widget.cdInfo.tracks.isEmpty) return 'Keine Tracks verfügbar';

    final track = widget.cdInfo.tracks.first;
    final filename = _config.generateFilename(
      track,
      widget.cdInfo.metadata,
      track.number,
    );

    return '$filename.${_config.format.extension}';
  }

  int _getMP3VBRBitrate(int quality) {
    const bitrateMap = {
      0: 245,
      1: 225,
      2: 190,
      3: 175,
      4: 165,
      5: 130,
      6: 115,
      7: 100,
      8: 85,
      9: 65,
    };
    return bitrateMap[quality] ?? 190;
  }

  int _getOGGBitrate(int quality) {
    const bitrateMap = {
      0: 64,
      1: 80,
      2: 96,
      3: 112,
      4: 128,
      5: 160,
      6: 192,
      7: 224,
      8: 256,
      9: 320,
      10: 500,
    };
    return bitrateMap[quality] ?? 192;
  }

  Widget _buildPresetChip(
    String label,
    String description,
    VoidCallback onTap,
  ) {
    return ActionChip(
      avatar: const Icon(Icons.recommend, size: 16),
      label: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(
            description,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
      onPressed: onTap,
      backgroundColor: Colors.cyan.withValues(alpha: 0.2),
      side: BorderSide(color: Colors.cyan.withValues(alpha: 0.5)),
    );
  }
}
