import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:process_run/shell.dart';
import '../models/cd_info.dart';
import '../models/ripping_config.dart';

class FFmpegService {
  final Shell _shell = Shell();
  final Dio _dio = Dio();

  Future<int> _runFfmpegWithProgress({
    required List<String> args,
    required int totalDurationSeconds,
    Function(double progress)? onProgress,
  }) async {
    final process = await Process.start('ffmpeg', args);

    final stderrCompleter = Completer<void>();
    final stdoutCompleter = Completer<void>();
    final errorOutput = StringBuffer();

    process.stderr.transform(utf8.decoder).listen(
      errorOutput.write,
      onDone: () {
        if (!stderrCompleter.isCompleted) stderrCompleter.complete();
      },
      onError: (error) {
        if (!stderrCompleter.isCompleted) stderrCompleter.completeError(error);
      },
    );

    StringBuffer lineBuffer = StringBuffer();
    process.stdout.transform(utf8.decoder).listen(
      (data) {
        lineBuffer.write(data);
        while (true) {
          final idx = lineBuffer.toString().indexOf('\n');
          if (idx == -1) break;

          final line = lineBuffer.toString().substring(0, idx).trim();
          lineBuffer = StringBuffer(lineBuffer.toString().substring(idx + 1));

          if (line.isEmpty) continue;

          if (line.startsWith('out_time_ms=')) {
            final val = int.tryParse(line.substring('out_time_ms='.length)) ?? 0;
            if (val <= 0 || totalDurationSeconds <= 0) continue;
            final currentSeconds = val / 1000000.0;
            if (onProgress != null) {
              final progress = (currentSeconds / totalDurationSeconds).clamp(0.0, 1.0);
              if (progress.isFinite) {
                onProgress(progress);
              }
            }
          }

          if (line.startsWith('progress=')) {
            if (line.substring('progress='.length) == 'end' && onProgress != null) {
              onProgress(1.0);
            }
          }
        }
      },
      onDone: () {
        if (!stdoutCompleter.isCompleted) stdoutCompleter.complete();
      },
      onError: (error) {
        if (!stdoutCompleter.isCompleted) stdoutCompleter.completeError(error);
      },
    );

    final exitCode = await process.exitCode;
    await stdoutCompleter.future;
    await stderrCompleter.future;

    if (exitCode != 0) {
      _logDebug('FFmpeg failed with code $exitCode');
      _logDebug(errorOutput.toString());
    }

    return exitCode;
  }

  /// Konvertiert eine WAV-Datei in das gewünschte Format (mit RippingConfig)
  Future<bool> convertAudio({
    required String inputPath,
    required String outputPath,
    required AudioFormat format,
    required Map<String, dynamic> formatOptions,
    required Track track,
    CDMetadata? cdMetadata,
    Function(double progress)? onProgress,
  }) async {
    try {
      String? coverPath;
      final coverArtUrl = cdMetadata?.coverArtUrl;
      if (coverArtUrl != null && coverArtUrl.isNotEmpty) {
        coverPath = await _prepareCoverArt(coverArtUrl, inputPath);
      }

      final args = ['-i', inputPath];
      if (coverPath != null) {
        args.addAll(['-i', coverPath]);
      }

      args.add('-y');
      args.addAll(_getFormatArgsFromConfig(format, formatOptions));
      if (coverPath != null) {
        args.addAll(_getCoverArtArgs(format));
      }
      args.addAll(_getMetadataArgs(track, cdMetadata, track.metadata));

      args.addAll(['-progress', 'pipe:1', '-nostats']);
      args.add(outputPath);

      final exitCode = await _runFfmpegWithProgress(
        args: args,
        totalDurationSeconds: track.duration.inSeconds,
        onProgress: onProgress,
      );

      return exitCode == 0;
    } catch (e) {
      _logDebug('Fehler bei der Konvertierung: $e');
      return false;
    }
  }

  /// Konvertiert eine WAV-Datei in das gewünschte Format (Legacy-Methode)
  Future<String?> convertAudioLegacy({
    required String inputPath,
    required String outputDir,
    required AudioFormat format,
    required Track track,
    CDMetadata? cdMetadata,
    TrackMetadata? trackMetadata,
    int? quality,
    int? bitrate,
    Function(double progress)? onProgress,
  }) async {
    try {
      final filename = _generateFilename(track, trackMetadata, format);
      final outputPath = path.join(outputDir, filename);

      String? coverPath;
      final coverArtUrl = cdMetadata?.coverArtUrl;
      if (coverArtUrl != null && coverArtUrl.isNotEmpty) {
        coverPath = await _prepareCoverArt(coverArtUrl, inputPath);
      }

      final args = ['-i', inputPath];
      if (coverPath != null) {
        args.addAll(['-i', coverPath]);
      }

      args.add('-y');
      args.addAll(_getFormatArgs(format, quality, bitrate));
      if (coverPath != null) {
        args.addAll(_getCoverArtArgs(format));
      }
      args.addAll(_getMetadataArgs(track, cdMetadata, trackMetadata));

      args.addAll(['-progress', 'pipe:1', '-nostats']);
      args.add(outputPath);

      final exitCode = await _runFfmpegWithProgress(
        args: args,
        totalDurationSeconds: track.duration.inSeconds,
        onProgress: onProgress,
      );

      return exitCode == 0 ? outputPath : null;
    } catch (e) {
      _logDebug('Fehler bei der Konvertierung: $e');
      return null;
    }
  }

  /// Konvertiert mehrere Tracks parallel
  Future<Map<int, String>> convertMultipleTracks({
    required List<String> inputPaths,
    required String outputDir,
    required AudioFormat format,
    required List<Track> tracks,
    CDMetadata? cdMetadata,
    int? quality,
    int? bitrate,
    Function(int trackNumber, double progress)? onProgress,
  }) async {
    final results = <int, String>{};
    final futures = <Future>[];

    for (int i = 0; i < inputPaths.length; i++) {
      final future = convertAudioLegacy(
        inputPath: inputPaths[i],
        outputDir: outputDir,
        format: format,
        track: tracks[i],
        cdMetadata: cdMetadata,
        trackMetadata: tracks[i].metadata,
        quality: quality,
        bitrate: bitrate,
        onProgress: (progress) {
          if (onProgress != null) {
            onProgress(tracks[i].number, progress);
          }
        },
      ).then((outputPath) {
        if (outputPath != null) {
          results[tracks[i].number] = outputPath;
        }
      });

      futures.add(future);
    }

    await Future.wait(futures);
    return results;
  }

  /// Format-Argumente aus RippingConfig generieren
  List<String> _getFormatArgsFromConfig(
    AudioFormat format,
    Map<String, dynamic> formatOptions,
  ) {
    switch (format) {
      case AudioFormat.flac:
        final compression =
            formatOptions[FormatOptions.flacCompressionKey] ?? 5;
        return ['-c:a', 'flac', '-compression_level', compression.toString()];

      case AudioFormat.mp3:
        final mode = formatOptions[FormatOptions.mp3ModeKey] ?? 'vbr';
        if (mode == 'cbr') {
          final bitrate = formatOptions[FormatOptions.mp3BitrateKey] ?? 320;
          return ['-c:a', 'libmp3lame', '-b:a', '${bitrate}k'];
        } else {
          final quality = formatOptions[FormatOptions.mp3QualityKey] ?? 2;
          return ['-c:a', 'libmp3lame', '-q:a', quality.toString()];
        }

      case AudioFormat.aac:
        final bitrate = formatOptions[FormatOptions.aacBitrateKey] ?? 192;
        return ['-c:a', 'aac', '-b:a', '${bitrate}k'];

      case AudioFormat.opus:
        final bitrate = formatOptions[FormatOptions.opusBitrateKey] ?? 128;
        return ['-c:a', 'libopus', '-b:a', '${bitrate}k'];

      case AudioFormat.ogg:
        final quality = formatOptions[FormatOptions.oggQualityKey] ?? 6;
        return ['-c:a', 'libvorbis', '-q:a', quality.toString()];

      case AudioFormat.wav:
        return ['-c:a', 'pcm_s16le'];

      case AudioFormat.alac:
        return ['-c:a', 'alac'];

      case AudioFormat.ape:
        final compression = formatOptions['compression'] ?? 2000;
        return ['-c:a', 'ape', '-compression_level', compression.toString()];
    }
  }

  /// Generiert FFmpeg-Argumente für das gewählte Format
  List<String> _getFormatArgs(AudioFormat format, int? quality, int? bitrate) {
    switch (format) {
      case AudioFormat.flac:
        return [
          '-c:a',
          'flac',
          '-compression_level',
          (quality ?? 8).toString(),
        ];

      case AudioFormat.mp3:
        if (bitrate != null) {
          return ['-c:a', 'libmp3lame', '-b:a', '${bitrate}k'];
        }
        return [
          '-c:a', 'libmp3lame',
          '-q:a', (quality ?? 2).toString(), // 0=best, 9=worst
        ];

      case AudioFormat.aac:
        return ['-c:a', 'aac', '-b:a', '${bitrate ?? 256}k'];

      case AudioFormat.opus:
        return ['-c:a', 'libopus', '-b:a', '${bitrate ?? 128}k'];

      case AudioFormat.ogg:
        return [
          '-c:a', 'libvorbis',
          '-q:a', (quality ?? 6).toString(), // -1 to 10
        ];

      case AudioFormat.wav:
        return ['-c:a', 'pcm_s16le'];

      case AudioFormat.alac:
        return ['-c:a', 'alac'];

      case AudioFormat.ape:
        return [
          '-c:a',
          'ape',
          '-compression_level',
          (quality ?? 2000).toString(),
        ];
    }
  }

  /// Generiert FFmpeg-Metadaten-Argumente
  List<String> _getMetadataArgs(
    Track track,
    CDMetadata? cdMetadata,
    TrackMetadata? trackMetadata,
  ) {
    final args = <String>[];

    // Track-Nummer
    args.addAll(['-metadata', 'track=${track.number}']);

    // Track-Titel
    if (trackMetadata?.title != null) {
      args.addAll(['-metadata', 'title=${trackMetadata!.title}']);
    }

    // Artist
    final artist = trackMetadata?.artist ?? cdMetadata?.artist;
    if (artist != null) {
      args.addAll(['-metadata', 'artist=$artist']);
    }

    // Album
    if (cdMetadata?.albumTitle != null) {
      args.addAll(['-metadata', 'album=${cdMetadata!.albumTitle}']);
    }

    // Album-Artist
    if (cdMetadata?.artist != null) {
      args.addAll(['-metadata', 'album_artist=${cdMetadata!.artist}']);
    }

    // Jahr
    if (cdMetadata?.year != null) {
      args.addAll(['-metadata', 'date=${cdMetadata!.year}']);
    }

    // Genre
    if (cdMetadata?.genre != null) {
      args.addAll(['-metadata', 'genre=${cdMetadata!.genre}']);
    }

    // Label
    if (cdMetadata?.label != null) {
      args.addAll(['-metadata', 'publisher=${cdMetadata!.label}']);
    }

    // ISRC
    if (trackMetadata?.isrc != null) {
      args.addAll(['-metadata', 'isrc=${trackMetadata!.isrc}']);
    }

    return args;
  }

  /// Generiert einen Dateinamen basierend auf Track und Metadaten
  String _generateFilename(
    Track track,
    TrackMetadata? metadata,
    AudioFormat format,
  ) {
    final trackNum = track.number.toString().padLeft(2, '0');

    if (metadata?.title != null) {
      final cleanTitle = _sanitizeFilename(metadata!.title!);
      return '$trackNum - $cleanTitle.${format.extension}';
    }

    return 'Track_$trackNum.${format.extension}';
  }

  /// Bereinigt einen String für Dateinamen
  String _sanitizeFilename(String filename) {
    return filename
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Überprüft, ob FFmpeg verfügbar ist
  Future<bool> isFFmpegAvailable() async {
    try {
      final result = await _shell.run('ffmpeg -version');
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Gibt FFmpeg-Version zurück
  Future<String?> getFFmpegVersion() async {
    try {
      final result = await _shell.run('ffmpeg -version');
      if (result.isNotEmpty) {
        final output = result.first.stdout.toString();
        final match = RegExp(r'ffmpeg version ([^\s]+)').firstMatch(output);
        return match?.group(1);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Erstellt ein Cue-Sheet für die CD
  Future<String?> createCueSheet({
    required CDInfo cdInfo,
    required String outputPath,
  }) async {
    final buffer = StringBuffer();

    // Header
    if (cdInfo.metadata?.artist != null) {
      buffer.writeln('PERFORMER "${cdInfo.metadata!.artist}"');
    }
    if (cdInfo.metadata?.albumTitle != null) {
      buffer.writeln('TITLE "${cdInfo.metadata!.albumTitle}"');
    }
    buffer.writeln('FILE "audio.wav" WAVE');

    // Tracks
    for (final track in cdInfo.tracks) {
      buffer.writeln(
        '  TRACK ${track.number.toString().padLeft(2, '0')} AUDIO',
      );

      if (track.metadata?.title != null) {
        buffer.writeln('    TITLE "${track.metadata!.title}"');
      }
      if (track.metadata?.artist != null) {
        buffer.writeln('    PERFORMER "${track.metadata!.artist}"');
      }
      if (track.metadata?.isrc != null) {
        buffer.writeln('    ISRC ${track.metadata!.isrc}');
      }

      // Index in MM:SS:FF Format
      final frames = track.startSector;
      final minutes = frames ~/ 75 ~/ 60;
      final seconds = (frames ~/ 75) % 60;
      final remainingFrames = frames % 75;

      buffer.writeln(
        '    INDEX 01 ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}:${remainingFrames.toString().padLeft(2, '0')}',
      );
    }

    try {
      final file = File(outputPath);
      await file.writeAsString(buffer.toString());
      return outputPath;
    } catch (e) {
      _logDebug('Fehler beim Erstellen des Cue-Sheets: $e');
      return null;
    }
  }

  /// Bereitet das Cover-Art vor (Download oder lokale Datei)
  Future<String?> _prepareCoverArt(
    String coverArtUrl,
    String audioFilePath,
  ) async {
    try {
      final tempDir = Directory.systemTemp.createTempSync('cover_');
      final coverPath = '${tempDir.path}/cover.jpg';

      // Prüfe ob URL oder lokaler Pfad
      if (coverArtUrl.startsWith('http://') ||
          coverArtUrl.startsWith('https://')) {
        // Download von URL
        await _dio.download(coverArtUrl, coverPath);
        _logDebug('Cover heruntergeladen: $coverPath');
      } else {
        // Lokale Datei kopieren
        final sourceFile = File(coverArtUrl);
        if (await sourceFile.exists()) {
          await sourceFile.copy(coverPath);
          _logDebug('Cover kopiert: $coverPath');
        } else {
          _logDebug('Cover-Datei nicht gefunden: $coverArtUrl');
          return null;
        }
      }

      return coverPath;
    } catch (e) {
      _logDebug('Fehler beim Vorbereiten des Covers: $e');
      return null;
    }
  }

  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  /// Gibt format-spezifische FFmpeg-Argumente für Cover-Art zurück
  List<String> _getCoverArtArgs(AudioFormat format) {
    switch (format) {
      case AudioFormat.mp3:
        // MP3 verwendet APIC frame (ID3v2)
        return [
          '-map', '0:a', // Audio vom ersten Input
          '-map', '1:v', // Video (Cover) vom zweiten Input
          '-c:v', 'mjpeg', // JPEG codec für Cover
          '-id3v2_version', '3',
          '-metadata:s:v', 'title=Album cover',
          '-metadata:s:v', 'comment=Cover (front)',
        ];

      case AudioFormat.flac:
      case AudioFormat.ogg:
        // FLAC und OGG Vorbis unterstützen embedded pictures
        return [
          '-map', '0:a', // Audio vom ersten Input
          '-map', '1:v', // Video (Cover) vom zweiten Input
          '-disposition:v', 'attached_pic',
          '-metadata:s:v', 'title=Album cover',
          '-metadata:s:v', 'comment=Cover (front)',
        ];

      case AudioFormat.aac:
      case AudioFormat.opus:
        // AAC und Opus in MP4/M4A Container
        return [
          '-map',
          '0:a',
          '-map',
          '1:v',
          '-c:v',
          'mjpeg',
          '-disposition:v',
          'attached_pic',
        ];

      case AudioFormat.wav:
      case AudioFormat.alac:
      case AudioFormat.ape:
        // Diese Formate unterstützen normalerweise keine embedded covers
        // Aber wir versuchen es trotzdem für ALAC (im M4A Container)
        if (format == AudioFormat.alac) {
          return [
            '-map',
            '0:a',
            '-map',
            '1:v',
            '-c:v',
            'mjpeg',
            '-disposition:v',
            'attached_pic',
          ];
        }
        return [];
    }
  }
}
