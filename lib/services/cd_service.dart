import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:process_run/shell.dart';
import '../models/cd_info.dart';

class CDService {
  String? _cdDevice;
  final Shell _shell = Shell();

  CDService();

  /// Findet das erste verfügbare CD/DVD-Laufwerk
  Future<String?> _findCDDevice() async {
    if (_cdDevice != null) return _cdDevice;

    // Liste möglicher CD-Device-Pfade in Prioritätsreihenfolge
    final possibleDevices = [
      '/dev/sr0',
      '/dev/sr1',
      '/dev/sr2',
      '/dev/cdrom',
      '/dev/dvd',
    ];

    for (final device in possibleDevices) {
      try {
        // Prüfe ob das Device existiert
        final file = File(device);
        if (await file.exists()) {
          // Versuche das Device mit cdparanoia zu lesen
          try {
            final result = await _shell.run('cdparanoia -d $device -Q 2>&1');
            final output = result.first.stdout.toString();

            // Wenn kein kritischer Fehler, ist das Device verwendbar
            if (!output.contains('Unable to open disc') &&
                !output.contains('Cannot find') &&
                !output.contains('No such file')) {
              _logDebug('CD-Device gefunden: $device');
              _cdDevice = device;
              return device;
            }
          } catch (_) {
            // Fehler beim Ausführen von cdparanoia, nächstes Device versuchen
            continue;
          }
        }
      } catch (e) {
        // Device nicht verfügbar, nächstes versuchen
        continue;
      }
    }

    _logDebug('WARNUNG: Kein CD-Device gefunden');
    return null;
  }

  String get cdDevice => _cdDevice ?? '/dev/sr0';

  /// Scannt die CD und gibt alle verfügbaren Informationen zurück
  Future<CDInfo?> scanCD() async {
    try {
      _logDebug('=== Scanning CD ===');

      // Finde verfügbares CD-Device
      final device = await _findCDDevice();
      if (device == null) {
        _logDebug('ERROR: Kein CD-Device gefunden');
        return null;
      }

      _logDebug('Verwende CD-Device: $device');

      // CD-TOC (Table of Contents) auslesen
      final tocInfo = await _readTOC();
      if (tocInfo == null) {
        _logDebug('ERROR: tocInfo is null');
        return null;
      }

      _logDebug('TOC Info: $tocInfo');

      // Disc-ID berechnen
      final discId = await _calculateDiscId(tocInfo);
      _logDebug('=== Berechnete Disc ID: $discId ===');
      _logDebug('TOC Details: firstTrack=${tocInfo['firstTrack']}, lastTrack=${tocInfo['lastTrack']}, leadOut=${tocInfo['leadOut']}, leadOutRaw=${tocInfo['leadOutRaw']}');
      if (tocInfo['rawOffsets'] != null) {
        _logDebug('Raw Offsets: ${tocInfo['rawOffsets']}');
      }

      // Tracks erstellen
      final tracks = _parseTracks(tocInfo);
      _logDebug('Number of tracks: ${tracks.length}');

      // Gesamtdauer berechnen
      final totalDuration = tracks.fold<Duration>(
        Duration.zero,
        (sum, track) => sum + track.duration,
      );

      _logDebug(
        'Total duration: ${totalDuration.inMinutes}:${(totalDuration.inSeconds % 60).toString().padLeft(2, '0')}',
      );

      return CDInfo(
        discId: discId,
        freedbId: await _calculateFreeDBId(tocInfo),
        numberOfTracks: tracks.length,
        totalDuration: totalDuration,
        tracks: tracks,
        scannedAt: DateTime.now(),
        devicePath: cdDevice,
      );
    } catch (e) {
      _logDebug('Fehler beim Scannen der CD: $e');
      return null;
    }
  }

  /// Liest die Table of Contents (TOC) der CD
  Future<Map<String, dynamic>?> _readTOC() async {
    try {
      final device = await _findCDDevice();
      if (device == null) return null;

      // Priorität 1: Python libdiscid (beste Quelle, ignoriert Data-Tracks korrekt)
      try {
        // Versuche beide Import-Varianten (native discid oder libdiscid.compat)
        final result = await _shell.run(
          'python3 -c \'try:\n    import discid\nexcept ImportError:\n    from libdiscid.compat import discid\ndisc = discid.read("$device"); print(disc.toc_string)\'',
        );
        if (result.isNotEmpty) {
          final output = result.first.stdout.toString().trim();
          _logDebug('libdiscid TOC: $output');
          return _parseCdDiscIdOutput(output);
        }
      } catch (e) {
        _logDebug('libdiscid nicht verfügbar: $e');
      }

      // Priorität 2: cdparanoia (zeigt nur Audio-Tracks)
      return await _readTOCWithCdparanoia();
    } catch (e) {
      _logDebug('Fehler beim Lesen der TOC: $e');
      return await _readTOCWithCdparanoia();
    }
  }

  /// Liest TOC mit cdparanoia
  Future<Map<String, dynamic>?> _readTOCWithCdparanoia() async {
    try {
      final device = await _findCDDevice();
      if (device == null) return null;

      final result = await _shell.run('cdparanoia -d $device -Q 2>&1');
      final output = result.first.stdout.toString();

      return _parseCdparanoiaOutput(output);
    } catch (e) {
      _logDebug('Fehler beim Lesen mit cdparanoia: $e');
      return null;
    }
  }

  /// Parst die Ausgabe von cdparanoia -Q
  Map<String, dynamic> _parseCdparanoiaOutput(String output) {
    final tracks = <Map<String, dynamic>>[];
    final lines = output.split('\n');

    _logDebug('=== cdparanoia Output ===');
    _logDebug(output);
    _logDebug('=========================');

    for (final line in lines) {
      // Beispiel: "  1.    0 [00:00.00]     4500 [01:00.00]  audio"
      // Regex angepasst für Robustheit:
      // Group 1: Track Nr
      // Group 2: Start Sektor
      // Group 3: Sektor Länge (wird als Gruppe 6 im alten Regex erwartet, hier angepasst)
      
      // Wir suchen primär nach Track, Start, Länge
      final basicMatch = RegExp(
        r'^\s*(\d+)\.\s+(\d+)\s+\[.*?\]\s+(\d+)',
      ).firstMatch(line);

      if (basicMatch != null) {
        final trackNum = int.parse(basicMatch.group(1)!);
        final startSector = int.parse(basicMatch.group(2)!);
        final sectorLength = int.parse(basicMatch.group(3)!);
        final endSector = startSector + sectorLength;
        
        // Versuche Duration zu parsen (optional)
        double durationSeconds = 0.0;
        // Suche nach zweiten Zeitangabe [MM:SS.FF]
        final timeMatches = RegExp(r'\[(\d+):(\d+)\.(\d+)\]').allMatches(line);
        if (timeMatches.length >= 2) {
          final lenMatch = timeMatches.last; // Die zweite Zeitangabe ist die Länge
           final lengthMinutes = int.parse(lenMatch.group(1)!);
           final lengthSeconds = int.parse(lenMatch.group(2)!);
           final lengthFrames = int.parse(lenMatch.group(3)!);
           durationSeconds = lengthMinutes * 60 + lengthSeconds + lengthFrames / 75.0;
        } else {
           // Fallback aus Sektoren
           durationSeconds = sectorLength / 75.0;
        }

        _logDebug(
          'Track $trackNum: Start=$startSector, End=$endSector (Len: $sectorLength), Duration=${durationSeconds}s',
        );

        tracks.add({
          'number': trackNum,
          'startSector': startSector,
          'endSector': endSector,
          'durationSeconds': durationSeconds,
        });
      }
    }

    _logDebug('Parsed ${tracks.length} tracks from cdparanoia');
    
    // Berechne Lead-Out basierend auf letztem Track
    if (tracks.isNotEmpty) {
      final lastTrack = tracks.last;
      final leadOutBase = (lastTrack['endSector'] as int) + 150; // cdparanoia gibt relative Sektoren
      _logDebug('Berechnetes Lead-Out: $leadOutBase');
      return {
        'tracks': tracks,
        'numTracks': tracks.length,
        'firstTrack': 1,
        'lastTrack': tracks.length,
        'leadOut': leadOutBase,
      };
    }
    
    return {'tracks': tracks, 'numTracks': tracks.length};
  }

  /// Parst die Ausgabe von cd-discid
  Map<String, dynamic> _parseCdDiscIdOutput(String output) {
    // Regex Split für beliebige Whitespaces (Space, Tab, Newline)
    final parts = output.trim().split(RegExp(r'\s+'));
    if (parts.length < 3) return {'tracks': []};

    // cd-discid --musicbrainz Format:
    // firstTrack lastTrack leadout offset1 offset2 ... offsetN
    final firstTrack = int.tryParse(parts[0]) ?? 1;
    final lastTrack = int.tryParse(parts[1]) ?? 0;
    final leadOutRaw = int.tryParse(parts[2]) ?? 0;

    final numTracks = lastTrack - firstTrack + 1;
    final tracks = <Map<String, dynamic>>[];
    final offsets = <int>[];
    final rawOffsets = <int>[]; // Rohe Offsets MIT +150 für MusicBrainz DiscID

    // Offsets ab Token 3
    for (int i = 0; i < numTracks && (3 + i) < parts.length; i++) {
      final rawOffset = int.tryParse(parts[3 + i]) ?? 0;
      rawOffsets.add(rawOffset); // Mit +150 für DiscID
      offsets.add(rawOffset - 150); // Ohne 150 für interne Berechnungen
    }

    // Lead-Out: Roh für DiscID, normalisiert für interne Berechnungen
    final leadOut = leadOutRaw - 150;
    final discEndSector = leadOut;

    for (int i = 0; i < offsets.length; i++) {
      final startSector = offsets[i];
      final endSector = i < offsets.length - 1 ? offsets[i + 1] : discEndSector;

      final durationSeconds = (endSector - startSector) / 75.0;

      tracks.add({
        'number': i + 1,
        'startSector': startSector,
        'endSector': endSector,
        'durationSeconds': durationSeconds,
      });
    }

    return {
      'firstTrack': firstTrack,
      'lastTrack': lastTrack,
      'leadOut': leadOut,
      'leadOutRaw': leadOutRaw, // MIT +150 für DiscID
      'rawOffsets': rawOffsets, // MIT +150 für DiscID
      'numTracks': numTracks,
      'tracks': tracks,
    };
  }

  /// Erstellt Track-Objekte aus TOC-Informationen
  List<Track> _parseTracks(Map<String, dynamic> tocInfo) {
    final tracksList = tocInfo['tracks'] as List<dynamic>? ?? [];
    final tracks = <Track>[];

    _logDebug('_parseTracks: Processing ${tracksList.length} tracks');

    for (int i = 0; i < tracksList.length; i++) {
      final trackData = tracksList[i] as Map<String, dynamic>;
      final startSector = trackData['startSector'] as int? ?? 0;

      // Versuche endSector zu bekommen, falls nicht vorhanden berechne ihn
      int endSector;
      if (trackData.containsKey('endSector')) {
        endSector = trackData['endSector'] as int? ?? startSector + 1;
      } else if (i < tracksList.length - 1) {
        // Nächster Track's Start ist unser Ende
        endSector =
            (tracksList[i + 1] as Map<String, dynamic>)['startSector']
                as int? ??
            startSector + 1;
      } else {
        // Letzter Track - verwende eine Standard-Länge wenn nicht bekannt
        endSector = startSector + 22500; // ~5 Minuten Standard
      }

      // Versuche Dauer direkt zu bekommen oder berechne sie
      double durationSeconds;
      if (trackData.containsKey('durationSeconds')) {
        durationSeconds =
            (trackData['durationSeconds'] as num?)?.toDouble() ?? 0.0;
      } else {
        durationSeconds = (endSector - startSector) / 75.0;
      }

      final duration = Duration(milliseconds: (durationSeconds * 1000).round());

      _logDebug(
        'Track ${i + 1}: Duration=${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
      );

      tracks.add(
        Track(
          number: trackData['number'] as int? ?? (i + 1),
          duration: duration,
          startSector: startSector,
          endSector: endSector,
        ),
      );
    }

    _logDebug('Returning ${tracks.length} parsed tracks');
    return tracks;
  }

  /// Berechnet die MusicBrainz Disc ID
  Future<String> _calculateDiscId(Map<String, dynamic> tocInfo) async {
    final tracksList = tocInfo['tracks'] as List<dynamic>? ?? [];
    if (tracksList.isEmpty) {
      return '';
    }

    // MusicBrainz-DiscID gemäß libdiscid-Spezifikation berechnen
    try {
      final firstTrack = tocInfo['firstTrack'] as int? ?? 1;
      final lastTrack = tocInfo['lastTrack'] as int? ?? tracksList.length;
      
      // Für MusicBrainz DiscID: Verwende RAW-Werte (MIT +150 Lead-In)
      final leadOutRaw = tocInfo['leadOutRaw'] as int?;
      final rawOffsets = tocInfo['rawOffsets'] as List<dynamic>?;
      
      if (leadOutRaw != null && rawOffsets != null) {
        // Verwende rohe Werte direkt von cd-discid
        final offsets = rawOffsets.cast<int>();
        final computedDiscId = _calculateMusicBrainzDiscIdFromToc(
          firstTrack,
          lastTrack,
          leadOutRaw,
          offsets,
        );
        
        if (computedDiscId.isNotEmpty) {
          return computedDiscId;
        }
      } else {
        // Fallback: TOC ausgelesen (cdparanoia), Offsets berechnen
        // cdparanoia gibt relative Sektoren (Start bei 0) aus.
        // MusicBrainz benötigt absolute Sektoren (mit +150 Lead-in).
        final offsetCorrection = 150;

        final leadOutBase = tocInfo['leadOut'] as int? ?? 
            ((tracksList.last as Map<String, dynamic>)['endSector'] as int? ?? 0);
        
        // Lead-Out muss auch +150 haben, es sei denn tocInfo['leadOut'] ist bereits absolut
        final leadOut = leadOutBase >= 150 ? leadOutBase : leadOutBase + offsetCorrection;

        final offsets = <int>[];
        for (final track in tracksList) {
          final offset = (track as Map<String, dynamic>)['startSector'] as int? ?? 0;
          // cdparanoia startet bei 0, also immer +150 addieren
          offsets.add(offset + offsetCorrection);
        }

        _logDebug('Fallback Berechnung: Lead-Out=$leadOut, Offsets=${offsets.take(3).join(", ")}...');

        final computedDiscId = _calculateMusicBrainzDiscIdFromToc(
          firstTrack,
          lastTrack,
          leadOut,
          offsets,
        );

        if (computedDiscId.isNotEmpty) {
          return computedDiscId;
        }
      }
    } catch (e) {
      _logDebug('Fehler bei DiscID-Berechnung: $e');
    }

    // Fallback: Hash über TOC
    final buffer = StringBuffer();
    for (final track in tracksList) {
      buffer.write('${track['startSector']}-${track['endSector']}');
    }
    final bytes = utf8.encode(buffer.toString());
    final digest = sha1.convert(bytes);
    return digest.toString().substring(0, 28);
  }

  /// Berechnet die MusicBrainz DiscID (Base64 URL-safe, ohne Padding) aus TOC-Daten
  /// Gemäß libdiscid-Spezifikation: https://musicbrainz.org/doc/Disc_ID_Calculation
  String _calculateMusicBrainzDiscIdFromToc(
    int firstTrack,
    int lastTrack,
    int leadOut,
    List<int> offsets,
  ) {
    if (offsets.isEmpty || leadOut <= 0) return '';

    _logDebug('=== MusicBrainz DiscID Berechnung ===');
    _logDebug('First Track: $firstTrack');
    _logDebug('Last Track: $lastTrack');
    _logDebug('Lead-Out: $leadOut');
    _logDebug('Offsets (${offsets.length}): ${offsets.join(", ")}');

    // libdiscid verwendet einen HEX-String für die SHA-1 Berechnung!
    // Format: "%02X%02X" für first, last, dann "%08X" für 100 Track-Offsets
    // WICHTIG: Das offset-Array in libdiscid ist [leadOut, track1, track2, ...]
    final buffer = StringBuffer();
    buffer.write(firstTrack.toRadixString(16).toUpperCase().padLeft(2, '0'));
    buffer.write(lastTrack.toRadixString(16).toUpperCase().padLeft(2, '0'));
    
    // 100 Offsets: Zuerst Lead-Out, dann die Track-Offsets
    // Index 0: Lead-Out
    // Index 1-99: Track-Offsets (oder 0 wenn nicht vorhanden)
    buffer.write(leadOut.toRadixString(16).toUpperCase().padLeft(8, '0'));
    for (var i = 0; i < 99; i++) {
      final offset = i < offsets.length ? offsets[i] : 0;
      buffer.write(offset.toRadixString(16).toUpperCase().padLeft(8, '0'));
    }

    final hexString = buffer.toString();
    _logDebug('Hex String (first 100 chars): ${hexString.substring(0, hexString.length > 100 ? 100 : hexString.length)}');
    _logDebug('Hex String FULL: $hexString'); // Full debug for verification
    
    // SHA-1 Hash berechnen
    final bytes = utf8.encode(hexString);
    final sha = sha1.convert(bytes);
    
    // MusicBrainz verwendet ein eigenes Base64-Schema (NICHT base64url!):
    // Standard Base64, dann: + → . (Punkt), / → _ (Unterstrich), = → - (Bindestrich)
    // Siehe: https://musicbrainz.org/doc/Disc_ID_Calculation
    final discId = base64.encode(sha.bytes)
        .replaceAll('+', '.')
        .replaceAll('/', '_')
        .replaceAll('=', '-');
    
    _logDebug('Berechnete DiscID: $discId');
    _logDebug('=====================================');
    
    return discId;
  }

  /// Berechnet die FreeDB Disc ID
  Future<String?> _calculateFreeDBId(Map<String, dynamic> tocInfo) async {
    try {
      final tracksList = tocInfo['tracks'] as List<dynamic>? ?? [];
      if (tracksList.isEmpty) return null;

      int sum = 0;
      for (final track in tracksList) {
        final offset = track['startSector'] as int? ?? 0;
        final seconds = offset ~/ 75;
        sum += _sumDigits(seconds);
      }

      final firstTrack = tracksList.first;
      final lastTrack = tracksList.last;
      final totalSeconds =
          ((lastTrack['endSector'] as int? ?? 0) -
              (firstTrack['startSector'] as int? ?? 0)) ~/
          75;

      final discId =
          ((sum % 0xFF) << 24) | (totalSeconds << 8) | tracksList.length;

      return discId.toRadixString(16).padLeft(8, '0');
    } catch (e) {
      return null;
    }
  }

  int _sumDigits(int n) {
    int sum = 0;
    while (n > 0) {
      sum += n % 10;
      n ~/= 10;
    }
    return sum;
  }

  /// Rippt einen einzelnen Track mit cdparanoia
  Future<String?> ripTrack({
    required Track track,
    required String outputPath,
    Function(double progress)? onProgress,
  }) async {
    try {
      final device = await _findCDDevice();
      if (device == null) {
        _logDebug('Fehler: Kein CD-Device gefunden');
        return null;
      }

      final outputFile =
          '$outputPath/track_${track.number.toString().padLeft(2, '0')}.wav';

      // cdparanoia verwendet Syntax: trackNumber[startSector-endSector]
      final trackSpec = '${track.number}';

      final process = await Process.start('cdparanoia', [
        '-d',
        device,
        '-w',
        trackSpec,
        outputFile,
      ]);

      // Progress-Tracking - cdparanoia gibt mehrere Formate auf stderr aus:
      // Format 1: "##: -2 [wrote] @ 23456" (während des Lesens)
      // Format 2: "outputting to track_01.wav" (Start)
      // Format 3: Prozentanzeige am Ende manchmal
      double lastProgress = 0.0;

      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            _logDebug('cdparanoia stderr: $line');

            // Versuche verschiedene Progress-Formate zu parsen
            // Format: "##: -2 [wrote] @ 12345" - zeigt geschriebene Sektoren
            final sectorMatch = RegExp(
              r'\[wrote\]\s+@\s+(\d+)',
            ).firstMatch(line);
            if (sectorMatch != null && onProgress != null) {
              final currentSector = int.parse(sectorMatch.group(1)!);
              // Berechne Progress basierend auf Sektoren
              final totalSectors = track.endSector - track.startSector;
              if (totalSectors > 0) {
                final progress =
                    (currentSector - track.startSector) / totalSectors;
                if (progress > lastProgress && progress <= 1.0) {
                  lastProgress = progress.clamp(0.0, 1.0);
                  onProgress(lastProgress);
                }
              }
            }

            // Alternative: Direkte Prozentanzeige
            final percentMatch = RegExp(r'(\d+)%').firstMatch(line);
            if (percentMatch != null && onProgress != null) {
              final progress = double.parse(percentMatch.group(1)!) / 100.0;
              if (progress > lastProgress) {
                lastProgress = progress;
                onProgress(progress);
              }
            }
          });

      // Auch stdout überwachen (manche Versionen nutzen stdout)
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            _logDebug('cdparanoia stdout: $line');
          });

      final exitCode = await process.exitCode;

      // Bei Erfolg: Stelle sicher dass 100% erreicht wurde
      if (exitCode == 0) {
        if (lastProgress < 1.0 && onProgress != null) {
          onProgress(1.0);
        }
        return outputFile;
      }

      return null;
    } catch (e) {
      _logDebug('Fehler beim Rippen von Track ${track.number}: $e');
      return null;
    }
  }

  /// Überprüft, ob eine CD eingelegt ist
  Future<bool> isCDPresent() async {
    try {
      final device = await _findCDDevice();
      if (device == null) return false;

      final result = await _shell.run('cdparanoia -d $device -Q 2>&1');
      final output = result.first.stdout.toString();
      return !output.contains('Unable to open') &&
          !output.contains('No medium found');
    } catch (e) {
      return false;
    }
  }

  /// Wirft die CD aus
  Future<bool> ejectCD() async {
    try {
      final device = await _findCDDevice();
      if (device == null) return false;

      await _shell.run('eject $device');
      return true;
    } catch (e) {
      _logDebug('Fehler beim Auswerfen: $e');
      return false;
    }
  }

  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }
}
