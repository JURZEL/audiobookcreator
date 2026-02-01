import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audiobook_project.dart';
import '../services/audiobook_service.dart';

final audiobookServiceProvider = Provider((ref) => AudiobookService());

final audiobookProjectProvider =
    NotifierProvider<AudiobookProjectNotifier, AudiobookProject?>(
      AudiobookProjectNotifier.new,
    );

class AudiobookProjectNotifier extends Notifier<AudiobookProject?> {
  late AudiobookService _service;

  @override
  AudiobookProject? build() {
    _service = ref.read(audiobookServiceProvider);
    return null;
  }

  Future<void> scanDirectory(String directoryPath) async {
    try {
      // Zeige Scanning-State
      state = AudiobookProject(
        sourceDirectory: directoryPath,
        files: [],
        metadata: AudiobookMetadata(),
        isProcessing: true,
        progress: 0.0,
        statusMessage: 'Scanne Verzeichnis...',
      );

      final files = await _service.scanDirectory(
        directoryPath,
        onProgress: (current, total) {
          if (state != null) {
            state = state!.copyWith(
              progress: current / total,
              statusMessage: 'Scanne Dateien: $current/$total',
            );
          }
        },
      );

      if (files.isEmpty) {
        state = null;
        throw Exception('Keine Audiodateien gefunden');
      }

      // Extrahiere gemeinsame Metadaten aus allen Dateien
      final metadata = _extractCommonMetadata(files);

      state = AudiobookProject(
        sourceDirectory: directoryPath,
        files: files,
        metadata: metadata,
        isProcessing: false,
        progress: 1.0,
        statusMessage: '',
      );
    } catch (e) {
      state = null;
      rethrow;
    }
  }

  void updateMetadata(AudiobookMetadata metadata) {
    if (state != null) {
      state = state!.copyWith(metadata: metadata);
    }
  }

  void setFormat(AudiobookFormat format) {
    if (state != null) {
      state = state!.copyWith(format: format);
    }
  }

  /// Extrahiert gemeinsame Metadaten aus allen Audiodateien
  AudiobookMetadata _extractCommonMetadata(List<AudioFile> files) {
    if (files.isEmpty) return AudiobookMetadata();

    // Sammle alle Werte für jedes Metadaten-Feld
    final albums = <String>{};
    final artists = <String>{};

    for (final file in files) {
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
      for (final file in files) {
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
      for (final file in files) {
        if (file.artist != null && file.artist!.isNotEmpty) {
          artistCounts[file.artist!] = (artistCounts[file.artist!] ?? 0) + 1;
        }
      }
      commonArtist = artistCounts.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    return AudiobookMetadata(
      title: commonAlbum,
      album: commonAlbum,
      author: commonArtist,
      artist: commonArtist,
      genre: 'Audiobook',
    );
  }

  void setOutputPath(String path) {
    if (state != null) {
      state = state!.copyWith(outputPath: path);
    }
  }

  Future<bool> createAudiobook() async {
    if (state == null || state!.outputPath == null) {
      return false;
    }

    // Setze State auf "processing"
    state = state!.copyWith(
      isProcessing: true,
      progress: 0.0,
      statusMessage: 'Start...',
    );

    // Starte den Service-Call in einem asynchronen Task mit Fehlerfang,
    // damit auch synchrone Ausnahmen nicht den Aufrufer blockieren/abbrechen.
    Future<void>(() async {
      try {
        final success = await _service.createAudiobook(
          files: state!.files,
          outputPath: state!.outputPath!,
          format: state!.format,
          metadata: state!.metadata,
          onProgress: (progress, status) {
            if (state != null) {
              state = state!.copyWith(
                progress: progress,
                statusMessage: status,
              );
            }
          },
        );

        if (state != null) {
          state = state!.copyWith(
            isProcessing: false,
            progress: success ? 1.0 : 0.0,
            statusMessage: success ? 'Fertig!' : 'Fehler',
          );
        }
      } catch (e) {
        if (state != null) {
          state = state!.copyWith(
            isProcessing: false,
            statusMessage: 'Fehler: $e',
          );
        }
      }
    });

    // Gib sofort true zurück (Prozess wurde gestartet)
    return true;
  }

  void reset() {
    state = null;
  }
}
