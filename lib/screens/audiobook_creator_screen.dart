import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../providers/audiobook_providers.dart';
import '../models/audiobook_project.dart';
import '../widgets/app_scaffold.dart';
import '../theme/app_theme.dart';

class AudiobookCreatorScreen extends ConsumerWidget {
  const AudiobookCreatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(audiobookProjectProvider);

    // Überwache den Processing-Status und zeige Meldungen
    ref.listen<AudiobookProject?>(audiobookProjectProvider, (previous, next) {
      // Prüfe ob Verarbeitung gerade abgeschlossen wurde
      if (previous?.isProcessing == true && next?.isProcessing == false) {
        if (context.mounted && next != null) {
          final success = next.progress >= 1.0 && !next.statusMessage.contains('Fehler');
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? 'Audiobook erfolgreich erstellt!'
                    : 'Fehler beim Erstellen des Audiobooks',
              ),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );

          if (success && next.outputPath != null) {
            // Dialog mit Option zum Öffnen
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Erfolgreich!'),
                content: Text('Audiobook wurde erstellt:\n${next.outputPath}'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ref.read(audiobookProjectProvider.notifier).reset();
                    },
                    child: const Text('Schließen'),
                  ),
                  TextButton(
                    onPressed: () {
                      // Öffne Verzeichnis
                      final dir = File(next.outputPath!).parent.path;
                      Process.run('xdg-open', [dir]);
                      Navigator.pop(context);
                    },
                    child: const Text('Ordner öffnen'),
                  ),
                ],
              ),
            );
          }
        }
      }
    });

    return AppScaffold(
      title: 'Hörbuch erstellen',
      currentRoute: '/audiobook',
      body: project == null
          ? _buildInitialView(context, ref)
          : _buildProjectView(context, ref, project),
    );
  }

  Widget _buildInitialView(BuildContext context, WidgetRef ref) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book,
              size: 80,
              color: AppTheme.primaryColor.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 24),
            Text(
              'Audiobook Creator',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

          Text(
            'Erstelle ein Audiobook aus mehreren Audiodateien',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          ElevatedButton.icon(
            onPressed: () => _selectDirectory(context, ref),
            icon: const Icon(Icons.folder_open, size: 28),
            label: const Text(
              'Verzeichnis auswählen',
              style: TextStyle(fontSize: 18),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildProjectView(
    BuildContext context,
    WidgetRef ref,
    AudiobookProject project,
  ) {
    if (project.isProcessing) {
      return _buildProcessingView(project);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProjectInfo(project),
          const SizedBox(height: 24),
          _buildMetadataEditor(context, ref, project),
          const SizedBox(height: 24),
          _buildFormatSelector(ref, project),
          const SizedBox(height: 24),
          _buildFileList(project),
          const SizedBox(height: 24),
          _buildActionButtons(context, ref, project),
        ],
      ),
    );
  }

  Widget _buildProcessingView(AudiobookProject project) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: CircularProgressIndicator(
                      value: project.progress,
                      strokeWidth: 8,
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.deepPurple,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.audiotrack,
                        size: 48,
                        color: Colors.deepPurple.withValues(alpha: (0.7 * 255).roundToDouble()),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(project.progress * 100).toStringAsFixed(0)}%',
                        style: GoogleFonts.orbitron(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: (0.1 * 255).roundToDouble()),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.deepPurple.withValues(alpha: (0.3 * 255).roundToDouble()),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.deepPurple,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          project.statusMessage,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Bitte warten Sie, dieser Vorgang kann einige Minuten dauern.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectInfo(AudiobookProject project) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.folder, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    project.sourceDirectory,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoChip(
                  Icons.audiotrack,
                  '${project.totalTracks} Tracks',
                ),
                _buildInfoChip(Icons.access_time, project.formattedDuration),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      backgroundColor: Colors.deepPurple.withValues(alpha: (0.1 * 255).roundToDouble()),
    );
  }

  Widget _buildMetadataEditor(
    BuildContext context,
    WidgetRef ref,
    AudiobookProject project,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Metadaten',
                  style: GoogleFonts.orbitron(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _extractCommonMetadata(ref, project),
                  icon: const Icon(Icons.auto_fix_high, size: 18),
                  label: const Text('Gemeinsame Daten'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Titel',
              value: project.metadata.title,
              onChanged: (value) {
                ref
                    .read(audiobookProjectProvider.notifier)
                    .updateMetadata(project.metadata.copyWith(title: value));
              },
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Autor',
              value: project.metadata.author,
              onChanged: (value) {
                ref
                    .read(audiobookProjectProvider.notifier)
                    .updateMetadata(project.metadata.copyWith(author: value));
              },
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Sprecher',
              value: project.metadata.narrator,
              onChanged: (value) {
                ref
                    .read(audiobookProjectProvider.notifier)
                    .updateMetadata(project.metadata.copyWith(narrator: value));
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'Jahr',
                    value: project.metadata.year,
                    onChanged: (value) {
                      ref
                          .read(audiobookProjectProvider.notifier)
                          .updateMetadata(
                            project.metadata.copyWith(year: value),
                          );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    label: 'Genre',
                    value: project.metadata.genre,
                    onChanged: (value) {
                      ref
                          .read(audiobookProjectProvider.notifier)
                          .updateMetadata(
                            project.metadata.copyWith(genre: value),
                          );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Verlag',
              value: project.metadata.publisher,
              onChanged: (value) {
                ref
                    .read(audiobookProjectProvider.notifier)
                    .updateMetadata(
                      project.metadata.copyWith(publisher: value),
                    );
              },
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Beschreibung',
              value: project.metadata.description,
              maxLines: 3,
              onChanged: (value) {
                ref
                    .read(audiobookProjectProvider.notifier)
                    .updateMetadata(
                      project.metadata.copyWith(description: value),
                    );
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _selectCoverArt(context, ref, project),
              icon: const Icon(Icons.image),
              label: Text(
                project.metadata.coverArtPath == null
                    ? 'Cover-Bild auswählen'
                    : 'Cover: ${project.metadata.coverArtPath!.split('/').last}',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple.withValues(alpha: (0.1 * 255).roundToDouble()),
                foregroundColor: Colors.deepPurple,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    String? value,
    int maxLines = 1,
    required Function(String) onChanged,
  }) {
    return TextFormField(
      initialValue: value ?? '',
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      maxLines: maxLines,
      textDirection: TextDirection.ltr,
      onChanged: onChanged,
    );
  }

  Widget _buildFormatSelector(WidgetRef ref, AudiobookProject project) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ausgabeformat',
              style: GoogleFonts.orbitron(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...AudiobookFormat.values.map((format) {
              final selected = project.format == format;
              return ListTile(
                leading: Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: Colors.deepPurple,
                ),
                title: Text(format.displayName),
                subtitle: Text('.${format.extension}'),
                selected: selected,
                onTap: () {
                  if (!selected) {
                    ref.read(audiobookProjectProvider.notifier).setFormat(format);
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFileList(AudiobookProject project) {
    // Gruppiere Dateien nach displayGroup
    final groups = <String, List<AudioFile>>{};
    for (final file in project.files) {
      final group = file.displayGroup;
      groups.putIfAbsent(group, () => []).add(file);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dateien (${project.totalTracks})',
              style: GoogleFonts.orbitron(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...groups.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                  ...entry.value.map((file) {
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: Colors.deepPurple.withValues(alpha: (0.1 * 255).roundToDouble()),
                        child: Text(
                          '${file.trackNumber ?? "?"}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ),
                      title: Text(
                        file.displayTitle,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        file.fileName,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      trailing: Text(
                        _formatDuration(file.duration),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    );
                  }),
                  const Divider(),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    AudiobookProject project,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              ref.read(audiobookProjectProvider.notifier).reset();
            },
            icon: const Icon(Icons.cancel),
            label: const Text('Abbrechen'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Colors.red),
              foregroundColor: Colors.red,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _startCreation(context, ref, project),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Erstellen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDirectory(BuildContext context, WidgetRef ref) async {
    // Setze initialDirectory auf Home, um Fehler mit nicht mehr existierenden
    // "zuletzt verwendeten" Pfaden im Linux File Picker zu vermeiden.
    String? initialDir = Platform.environment['HOME'];
    if (initialDir != null) {
      // Optional: Versuche direkt den Musik-Ordner zu treffen
      final musicDir = Directory('$initialDir/Musik');
      if (await musicDir.exists()) {
        initialDir = musicDir.path;
      }
    }

    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Verzeichnis mit Audiodateien auswählen',
      initialDirectory: initialDir,
      lockParentWindow: true,
    );

    if (result != null) {
      try {
        await ref.read(audiobookProjectProvider.notifier).scanDirectory(result);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _selectCoverArt(
    BuildContext context,
    WidgetRef ref,
    AudiobookProject project,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      dialogTitle: 'Cover-Bild auswählen',
    );

    if (result != null && result.files.single.path != null) {
      ref
          .read(audiobookProjectProvider.notifier)
          .updateMetadata(
            project.metadata.copyWith(coverArtPath: result.files.single.path),
          );
    }
  }

  Future<void> _startCreation(
    BuildContext context,
    WidgetRef ref,
    AudiobookProject project,
  ) async {
    // Ausgabedatei auswählen
    final fileName =
        '${project.metadata.title ?? "audiobook"}.${project.format.extension}';
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Speichern unter',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [project.format.extension],
    );

    if (outputPath == null) return;

    ref.read(audiobookProjectProvider.notifier).setOutputPath(outputPath);

    // Starte die Erstellung - kehrt sofort zurück
    // Status-Updates kommen über den Provider
    ref.read(audiobookProjectProvider.notifier).createAudiobook();
  }

  void _extractCommonMetadata(WidgetRef ref, AudiobookProject project) {
    if (project.files.isEmpty) return;

    // Sammle alle Werte für jedes Metadaten-Feld
    final albums = <String>{};
    final artists = <String>{};

    for (final file in project.files) {
      if (file.album != null && file.album!.isNotEmpty) {
        albums.add(file.album!);
      }
      if (file.artist != null && file.artist!.isNotEmpty) {
        artists.add(file.artist!);
      }
    }

    // Verwende den häufigsten oder einzigen Wert
    String? commonAlbum;
    String? commonArtist;

    if (albums.length == 1) {
      commonAlbum = albums.first;
    } else if (albums.isNotEmpty) {
      // Verwende das häufigste Album
      final albumCounts = <String, int>{};
      for (final file in project.files) {
        if (file.album != null && file.album!.isNotEmpty) {
          albumCounts[file.album!] = (albumCounts[file.album!] ?? 0) + 1;
        }
      }
      commonAlbum = albumCounts.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    if (artists.length == 1) {
      commonArtist = artists.first;
    } else if (artists.isNotEmpty) {
      // Verwende den häufigsten Artist
      final artistCounts = <String, int>{};
      for (final file in project.files) {
        if (file.artist != null && file.artist!.isNotEmpty) {
          artistCounts[file.artist!] = (artistCounts[file.artist!] ?? 0) + 1;
        }
      }
      commonArtist = artistCounts.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    // Überschreibe ALLE Metadatenfelder mit den gemeinsamen Daten
    final updatedMetadata = AudiobookMetadata(
      title: commonAlbum,
      album: commonAlbum,
      author: commonArtist,
      artist: commonArtist,
      genre: 'Audiobook',
      // Behalte nur das Cover-Bild und den Ausgabepfad
      coverArtPath: project.metadata.coverArtPath,
    );

    ref.read(audiobookProjectProvider.notifier).updateMetadata(updatedMetadata);
  }
}
