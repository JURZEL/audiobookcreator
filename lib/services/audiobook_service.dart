import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../models/audiobook_project.dart';

class AudiobookService {
  static const _audioExtensions = {
    '.mp3',
    '.m4a',
    '.m4b',
    '.flac',
    '.wav',
    '.ogg',
    '.aac',
    '.mka',
    '.mkv',
  };

  /// Scannt ein Verzeichnis rekursiv nach unterstützten Audiodateien.
  Future<List<AudioFile>> scanDirectory(
    String directoryPath, {
    void Function(int current, int total)? onProgress,
  }) async {
    final dir = Directory(directoryPath);
    if (!dir.existsSync()) {
      throw Exception('Verzeichnis existiert nicht: $directoryPath');
    }

    final files = <AudioFile>[];
    final entities = await dir
        .list(recursive: true, followLinks: false)
        .where((entity) => entity is File)
        .toList();

    final audioEntities = entities.where((entity) {
      final ext = path.extension(entity.path).toLowerCase();
      return _audioExtensions.contains(ext);
    }).toList();

    var processed = 0;
    for (final entity in audioEntities) {
      final audio = await readMetadataFromFile(entity.path);
      if (audio != null) {
        files.add(audio);
      }
      processed += 1;
      onProgress?.call(processed, audioEntities.length);
    }

    files.sort((a, b) {
      final discA = a.discNumber ?? 0;
      final discB = b.discNumber ?? 0;
      if (discA != discB) return discA.compareTo(discB);
      final trackA = a.trackNumber ?? 0;
      final trackB = b.trackNumber ?? 0;
      return trackA.compareTo(trackB);
    });

    return files;
  }

  Future<AudioFile?> readMetadataFromFile(String filePath) async {
    final baseDir = path.dirname(filePath);
    return _parseAudioFile(filePath, baseDir);
  }

  /// Schreibt ausgewählte Metadaten verlustfrei in eine Audiodatei.
  Future<AudioFile?> writeMetadataToFile({
    required String filePath,
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    String? author,
    String? narrator,
    String? genre,
    String? year,
    String? comment,
    String? coverArtPath,
    bool removeCover = false,
    int? trackNumber,
    int? discNumber,
  }) async {
    final ext = path.extension(filePath);
    final tempPath = '${path.withoutExtension(filePath)}_tagedit$ext';

    final args = <String>['-y', '-i', filePath];
    if (coverArtPath != null) {
      args.addAll(['-i', coverArtPath]);
    }

    // Mapping: bei neuem Cover nur Audio + neues Bild, bei Remove nur Audio, sonst alles kopieren
    if (coverArtPath != null) {
      args.addAll([
        '-map',
        '0:a?',
        '-map',
        '1',
        '-map_metadata',
        '0',
        '-c',
        'copy',
        '-disposition:v:0',
        'attached_pic',
      ]);
    } else if (removeCover) {
      args.addAll(['-map', '0:a?', '-map_metadata', '0', '-c', 'copy']);
    } else {
      args.addAll(['-map_metadata', '0', '-c', 'copy']);
    }

    void addTag(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        args.addAll(['-metadata', '$key=${value.trim()}']);
      }
    }

    if (trackNumber != null) addTag('track', trackNumber.toString());
    if (discNumber != null) addTag('disc', discNumber.toString());
    addTag('title', title);
    addTag('artist', artist);
    addTag('album', album);
    addTag('album_artist', albumArtist ?? author);
    addTag('author', author);
    addTag('composer', narrator); // narrator wird häufig als Composer/Performer gespeichert
    addTag('genre', genre);
    addTag('date', year);
    addTag('comment', comment);

    args.add(tempPath);

    try {
      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();

      final process = await Process.start('ffmpeg', args);
      final stdoutFuture = process.stdout.transform(utf8.decoder).forEach(stdoutBuffer.write);
      final stderrFuture = process.stderr.transform(utf8.decoder).forEach(stderrBuffer.write);

      final exitCode = await process.exitCode;
      await Future.wait([stdoutFuture, stderrFuture]);

      if (exitCode != 0) {
        _logDebug('FFmpeg Tag-Update fehlgeschlagen ($exitCode): ${stderrBuffer.toString()}');
        if (File(tempPath).existsSync()) {
          await File(tempPath).delete();
        }
        return null;
      }

      final tempFile = File(tempPath);
      if (!tempFile.existsSync()) {
        _logDebug('Temp-Datei für Tag-Update fehlt: $tempPath');
        return null;
      }

      final originalFile = File(filePath);
      final backupPath = '$filePath.bak';

      try {
        if (await File(backupPath).exists()) {
          await File(backupPath).delete();
        }
        await originalFile.rename(backupPath);
        await tempFile.rename(filePath);
        await File(backupPath).delete();
      } catch (e) {
        _logDebug('Fehler beim Ersetzen der Originaldatei: $e');
        if (!await originalFile.exists() && await File(backupPath).exists()) {
          await File(backupPath).rename(filePath);
        }
        return null;
      }

      return await readMetadataFromFile(filePath);
    } catch (e) {
      try {
        if (File(tempPath).existsSync()) {
          await File(tempPath).delete();
        }
      } catch (_) {}
      return null;
    }
  }

  /// Erstellt ein Audiobook (M4B oder MKV) aus mehreren Dateien.
  Future<bool> createAudiobook({
    required List<AudioFile> files,
    required String outputPath,
    required AudiobookFormat format,
    required AudiobookMetadata metadata,
    Function(double progress, String status)? onProgress,
  }) async {
    if (files.isEmpty) {
      throw Exception('Keine Audiodateien zum Verarbeiten');
    }

    try {
      onProgress?.call(0.0, 'Vorbereitung: Erstelle temporäre Dateien...');

      final orderedFiles = _orderFilesForConcat(files);
      final tempDir = await Directory.systemTemp.createTemp('audiobookcreator_');

      // Concat-Datei erstellen
      final concatListFile = File(path.join(tempDir.path, 'input.txt'));
      final buffer = StringBuffer();
      for (final file in orderedFiles) {
        buffer.writeln("file '${file.filePath.replaceAll("'", "'\\''")}'");
      }
      await concatListFile.writeAsString(buffer.toString());

      // Chapters-Datei
      final chaptersFile = await _createChaptersFile(orderedFiles, tempDir.path);

      // Dauer für Progress-Berechnung
      final cumulativeStarts = <double>[];
      double totalDurationSeconds = 0;
      for (final file in orderedFiles) {
        cumulativeStarts.add(totalDurationSeconds);
        totalDurationSeconds += file.duration.inSeconds.toDouble();
      }
      final estimatedMinutes = (totalDurationSeconds / 60).ceil();

      final hasCover = metadata.coverArtPath != null && metadata.coverArtPath!.isNotEmpty;

      // FFmpeg-Args
      final args = <String>['-y', '-f', 'concat', '-safe', '0', '-i', concatListFile.path];
      if (hasCover) {
        args.addAll(['-i', metadata.coverArtPath!]);
      }
      if (chaptersFile != null) {
        args.addAll(['-i', chaptersFile]);
      }

      if (format == AudiobookFormat.m4b) {
        args.addAll(['-c:a', 'aac', '-b:a', '128k']);
        if (hasCover) {
          args.addAll([
            '-map',
            '0:a',
            '-map',
            '1:v',
            '-disposition:v:0',
            'attached_pic',
          ]);
        }
      } else {
        args.addAll(['-c:a', 'copy', '-f', 'matroska']);
        if (hasCover) {
          args.addAll([
            '-map',
            '0:a',
            '-map',
            '1:v',
            '-disposition:v:0',
            'attached_pic',
          ]);
        }
      }

      args.addAll(_getMetadataArgs(metadata));

      if (chaptersFile != null) {
        final chaptersInputIndex = hasCover ? 2 : 1;
        args.addAll(['-map_chapters', chaptersInputIndex.toString()]);
      }

      args.addAll(['-progress', 'pipe:1', '-nostats']);
      args.addAll(['-y', outputPath]);

      onProgress?.call(
        0.2,
        'FFmpeg wird gestartet... (geschätzte Dauer: ~$estimatedMinutes Min.)',
      );

      final process = await Process.start('ffmpeg', args);

      final errorOutput = StringBuffer();
      int lastReportedPercent = 0;

      final stderrCompleter = Completer<void>();
      process.stderr.transform(const SystemEncoding().decoder).listen(
        errorOutput.write,
        onDone: () => stderrCompleter.complete(),
        onError: (error) => stderrCompleter.completeError(error),
      );

      final stdoutCompleter = Completer<void>();
      if (totalDurationSeconds > 0) {
        onProgress?.call(
          0.2,
          'Kodierung läuft... (Gesamt: ${(totalDurationSeconds / 60).ceil()} Min. Audio)',
        );
      }

      StringBuffer lineBuffer = StringBuffer();
      process.stdout.transform(const SystemEncoding().decoder).listen(
        (data) {
          lineBuffer.write(data);
          while (true) {
            final newlineIndex = lineBuffer.toString().indexOf('\n');
            if (newlineIndex == -1) break;

            final line = lineBuffer.toString().substring(0, newlineIndex).trim();
            lineBuffer = StringBuffer(lineBuffer.toString().substring(newlineIndex + 1));
            if (line.isEmpty) continue;

            if (line.startsWith('out_time_ms=')) {
              final value = line.substring('out_time_ms='.length);
              final currentMicroSeconds = int.tryParse(value) ?? 0;
              if (currentMicroSeconds <= 0 || totalDurationSeconds <= 0) continue;

              final currentSeconds = currentMicroSeconds / 1000000.0;
              final progress = 0.2 + (currentSeconds / totalDurationSeconds * 0.8);
              if (!progress.isFinite) continue;

              final percent = (progress * 100).toInt();
              if (percent >= lastReportedPercent + 2 || percent == 100) {
                lastReportedPercent = percent;
                final remainingSeconds = (totalDurationSeconds - currentSeconds).clamp(0, double.infinity);
                final remainingMinutes = (remainingSeconds / 60).ceil();
                final processedMinutes = (currentSeconds / 60).floor();

                int currentFileIndex = 0;
                for (var i = 0; i < cumulativeStarts.length; i++) {
                  if (currentSeconds >= cumulativeStarts[i]) {
                    currentFileIndex = i;
                  } else {
                    break;
                  }
                }
                currentFileIndex = currentFileIndex.clamp(0, orderedFiles.length - 1);
                final currentFile = orderedFiles[currentFileIndex];
                final currentFileName = (currentFile.title?.isNotEmpty ?? false)
                    ? currentFile.title!
                    : path.basename(currentFile.filePath);
                final trackLabel = 'Track ${currentFileIndex + 1}/${orderedFiles.length}: $currentFileName';

                String statusMsg;
                if (percent < 30) {
                  statusMsg = 'Audiodaten werden analysiert und kodiert... ($percent%) - $trackLabel';
                } else if (percent < 60) {
                  statusMsg = 'Kodierung läuft: $processedMinutes Min. von ${(totalDurationSeconds / 60).floor()} Min. verarbeitet - $trackLabel';
                } else if (percent < 90) {
                  statusMsg = 'Fast fertig... (noch ca. $remainingMinutes Min.) - $trackLabel';
                } else {
                  statusMsg = 'Finalisierung: Metadaten und Kapitel werden eingebettet...';
                }

                onProgress?.call(progress.clamp(0.0, 1.0), statusMsg);
              }
            }

            if (line.startsWith('progress=')) {
              final state = line.substring('progress='.length);
              if (state == 'end') {
                onProgress?.call(1.0, 'Finalisierung abgeschlossen.');
              }
            }
          }
        },
        onDone: () => stdoutCompleter.complete(),
        onError: (error) => stdoutCompleter.completeError(error),
      );

      final exitCode = await process.exitCode;
      await stdoutCompleter.future;
      await stderrCompleter.future;

      try {
        await tempDir.delete(recursive: true);
      } catch (e) {
        _logDebug('Fehler beim Löschen des Temp-Verzeichnisses: $e');
      }

      if (exitCode == 0) {
        onProgress?.call(1.0, 'Fertig!');
        return true;
      } else {
        _logDebug('FFmpeg fehlgeschlagen mit Exit-Code: $exitCode');
        _logDebug('FFmpeg-Fehlerausgabe:');
        _logDebug(errorOutput.toString());
      }

      return false;
    } catch (e) {
      _logDebug('Fehler beim Erstellen des Audiobooks: $e');
      return false;
    }
  }

  List<AudioFile> _orderFilesForConcat(List<AudioFile> files) {
    final ordered = [...files];
    ordered.sort((a, b) {
      final discA = a.discNumber ?? 0;
      final discB = b.discNumber ?? 0;
      if (discA != discB) return discA.compareTo(discB);
      final trackA = a.trackNumber ?? 0;
      final trackB = b.trackNumber ?? 0;
      return trackA.compareTo(trackB);
    });
    return ordered;
  }

  Future<AudioFile?> _parseAudioFile(String filePath, String baseDir) async {
    try {
      final result = await Process.run(
        'ffprobe',
        [
          '-v',
          'quiet',
          '-print_format',
          'json',
          '-show_format',
          '-show_streams',
          filePath,
        ],
      );

      if (result.exitCode != 0) {
        _logDebug('ffprobe Fehler: ${result.stderr}');
        return null;
      }

      final data = _parseFFprobeJson(result.stdout as String);

      final fileName = path.basename(filePath);
      final directory = path.relative(path.dirname(filePath), from: baseDir);

      Map<String, dynamic>? tags;
      final merged = <String, dynamic>{};

      final streams = data['streams'] as List<dynamic>?;
      if (streams != null && streams.isNotEmpty) {
        for (final stream in streams) {
          if (stream is Map<String, dynamic>) {
            final streamTags = stream['tags'] as Map<String, dynamic>?;
            if (streamTags != null && streamTags.isNotEmpty) {
              merged.addAll(streamTags);
            }
          }
        }
      }

      final formatTags = data['format']?['tags'] as Map<String, dynamic>?;
      if (formatTags != null && formatTags.isNotEmpty) {
        merged.addAll(formatTags);
      }

      if (merged.isNotEmpty) {
        tags = merged;
      }

      String? coverArtPath;
      if (streams != null && streams.isNotEmpty) {
        coverArtPath = await _extractCoverArt(filePath, streams);
      }

      int? trackNumber;
      int? discNumber;
      String? title;
      String? artist;
      String? albumArtist;
      String? author;
      String? narrator;
      String? genre;
      String? year;
      String? comment;
      String? album;

      if (tags != null) {
        final tagsLower = <String, dynamic>{};
        tags.forEach((key, value) {
          tagsLower[key.toLowerCase()] = value;
        });

        int? parseNumber(dynamic value) {
          if (value == null) return null;
          if (value is int) return value;
          final text = value.toString();
          final parts = text.split('/');
          return int.tryParse(parts.first.trim());
        }

        trackNumber = parseNumber(tagsLower['track'] ?? tagsLower['tracknumber'] ?? tagsLower['track_number'] ?? tagsLower['trkn'] ?? tags['track'] ?? tags['TRACKNUMBER'] ?? tags['trkn']);

        discNumber = parseNumber(tagsLower['disc'] ?? tagsLower['discnumber'] ?? tagsLower['disc_number'] ?? tagsLower['disk'] ?? tags['disc'] ?? tags['DISCNUMBER'] ?? tags['disk']);

        title = tagsLower['title'] ?? tags['title'] ?? tags['TITLE'] ?? tags['©nam'] ?? tagsLower['\u0000a9nam'];

        artist = tagsLower['artist'] ?? tags['artist'] ?? tags['ARTIST'] ?? tags['©art'] ?? tagsLower['\u0000a9art'];

        albumArtist = tagsLower['album_artist'] ?? tags['album_artist'] ?? tags['ALBUM_ARTIST'] ?? tags['aart'] ?? tags['AART'];

        genre = tagsLower['genre'] ?? tags['genre'] ?? tags['GENRE'] ?? tags['©gen'] ?? tagsLower['\u0000a9gen'];

        year = tagsLower['date'] ?? tags['date'] ?? tags['DATE'] ?? tagsLower['year'] ?? tags['year'] ?? tags['©day'] ?? tagsLower['\u0000a9day'];

        comment = tagsLower['comment'] ?? tags['comment'] ?? tags['COMMENT'] ?? tagsLower['description'] ?? tags['description'] ?? tags['©cmt'] ?? tagsLower['\u0000a9cmt'];

        author = tagsLower['author'] ?? tags['author'] ?? tags['AUTHOR'] ?? tags['©wrt'] ?? tagsLower['\u0000a9wrt'] ?? tags['----:com.apple.itunes:author'] ?? albumArtist;

        narrator = tagsLower['narrator'] ?? tags['narrator'] ?? tags['NARRATOR'] ?? tagsLower['composer'] ?? tags['composer'] ?? tags['COMPOSER'] ?? tags['----:com.apple.itunes:narrator'];

        album = tagsLower['album'] ?? tags['album'] ?? tags['ALBUM'] ?? tags['©alb'] ?? tagsLower['\u0000a9alb'];
      }

      if (trackNumber == null) {
        final match = RegExp(r'^(\d+)').firstMatch(fileName);
        if (match != null) {
          trackNumber = int.tryParse(match.group(1)!);
        }
      }

      final duration = data['format']?['duration'];
      final durationSeconds = duration != null ? double.tryParse(duration.toString()) ?? 0.0 : 0.0;

      return AudioFile(
        filePath: filePath,
        fileName: fileName,
        directory: directory,
        trackNumber: trackNumber,
        discNumber: discNumber,
        title: title,
        artist: artist ?? albumArtist ?? author,
        albumArtist: albumArtist,
        author: author,
        narrator: narrator,
        genre: genre,
        year: year,
        comment: comment,
        album: album,
        coverArtPath: coverArtPath,
        duration: Duration(seconds: durationSeconds.round()),
      );
    } catch (e) {
      _logDebug('Fehler beim Lesen von $filePath: $e');
      return null;
    }
  }

  Map<String, dynamic> _parseFFprobeJson(String jsonText) {
    try {
      return jsonDecode(jsonText) as Map<String, dynamic>;
    } catch (e) {
      _logDebug('Fehler beim JSON-Parsen: $e');
      return {};
    }
  }

  Future<String?> _extractCoverArt(String filePath, List<dynamic> streams) async {
    int? coverIndex;
    String extension = 'jpg';

    for (int i = 0; i < streams.length; i++) {
      final stream = streams[i];
      if (stream is Map<String, dynamic>) {
        final disposition = stream['disposition'] as Map<String, dynamic>?;
        final isAttached = disposition != null && disposition['attached_pic'] == 1;
        final codecType = stream['codec_type'];
        if (isAttached || codecType == 'video') {
          coverIndex = i;
          final codec = stream['codec_name'] as String?;
          if (codec != null && codec.toLowerCase().contains('png')) {
            extension = 'png';
          }
          break;
        }
      }
    }

    if (coverIndex == null) return null;

    final tempPath = '${Directory.systemTemp.path}/cover_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final result = await Process.run(
      'ffmpeg',
      ['-y', '-i', filePath, '-map', '0:$coverIndex', '-c', 'copy', tempPath],
    );

    if (result.exitCode == 0 && File(tempPath).existsSync()) {
      return tempPath;
    }

    try {
      if (File(tempPath).existsSync()) {
        await File(tempPath).delete();
      }
    } catch (_) {}

    return null;
  }

  Future<String?> _createChaptersFile(List<AudioFile> files, String tempDir) async {
    try {
      final chaptersFile = File('$tempDir/chapters.txt');
      final buffer = StringBuffer();
      buffer.writeln(';FFMETADATA1');

      var currentTime = 0;
      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        final startTime = currentTime;
        final endTime = currentTime + file.duration.inMilliseconds;

        String chapterTitle;
        if (file.title != null && file.title!.isNotEmpty) {
          chapterTitle = file.title!;
        } else {
          chapterTitle = file.fileName;
        }

        buffer.writeln('[CHAPTER]');
        buffer.writeln('TIMEBASE=1/1000');
        buffer.writeln('START=$startTime');
        buffer.writeln('END=$endTime');
        buffer.writeln('title=$chapterTitle');

        currentTime = endTime;
      }

      await chaptersFile.writeAsString(buffer.toString());
      return chaptersFile.path;
    } catch (e) {
      _logDebug('Fehler beim Erstellen der Chapters-Datei: $e');
      return null;
    }
  }

  List<String> _getMetadataArgs(AudiobookMetadata metadata) {
    final args = <String>[];

    if (metadata.title != null) {
      args.addAll(['-metadata', 'title=${metadata.title}']);
    }
    if (metadata.artist != null) {
      args.addAll(['-metadata', 'artist=${metadata.artist}']);
    }
    if (metadata.album != null) {
      args.addAll(['-metadata', 'album=${metadata.album}']);
    }
    if (metadata.author != null) {
      args.addAll(['-metadata', 'author=${metadata.author}']);
      args.addAll(['-metadata', 'album_artist=${metadata.author}']);
    }
    if (metadata.narrator != null) {
      args.addAll(['-metadata', 'composer=${metadata.narrator}']);
    }
    if (metadata.year != null) {
      args.addAll(['-metadata', 'date=${metadata.year}']);
    }
    if (metadata.genre != null) {
      args.addAll(['-metadata', 'genre=${metadata.genre}']);
    }
    if (metadata.description != null) {
      args.addAll(['-metadata', 'description=${metadata.description}']);
      args.addAll(['-metadata', 'comment=${metadata.description}']);
    }
    if (metadata.publisher != null) {
      args.addAll(['-metadata', 'publisher=${metadata.publisher}']);
    }

    return args;
  }

  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }
}
