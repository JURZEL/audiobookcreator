<!-- markdownlint-disable MD022 MD032 MD031 MD026 MD040 MD029 MD009 -->
# Entwickler-Dokumentation

## Projektübersicht

CD Ripper Pro ist eine moderne Flutter-Desktop-Anwendung für Linux, die als elegantes Frontend für cdparanoia dient. Die App ermöglicht das Rippen von Audio-CDs mit automatischer Metadaten-Erkennung über MusicBrainz und Konvertierung in verschiedene Audioformate.

## Architektur

### State Management: Riverpod

Die App verwendet Riverpod für zentrales State Management:

```dart
// CD-Info wird zentral verwaltet
final cdInfoProvider = StateNotifierProvider<CDInfoNotifier, AsyncValue<CDInfo?>>

// Services als Provider
final cdServiceProvider = Provider<CDService>
final musicBrainzServiceProvider = Provider<MusicBrainzService>
final ffmpegServiceProvider = Provider<FFmpegService>
```

### Services

#### CDService ([cd_service.dart](lib/services/cd_service.dart))
Verwaltet die Interaktion mit cdparanoia:
- `scanCD()`: Scannt eingelegte CD und liest TOC (Table of Contents)
- `ripTrack()`: Rippt einzelnen Track als WAV
- `isCDPresent()`: Prüft ob CD eingelegt ist
- `ejectCD()`: Wirft CD aus

Wichtige Funktionen:
```dart
// CD scannen
final cdInfo = await cdService.scanCD();

// Track rippen mit Progress-Callback
await cdService.ripTrack(
  track: track,
  outputPath: '/path/to/output',
  onProgress: (progress) => print('$progress%'),
);
```

#### MusicBrainzService ([musicbrainz_service.dart](lib/services/musicbrainz_service.dart))
Kommuniziert mit der MusicBrainz API:
- `searchByDiscId()`: Suche nach Disc-ID
- `searchByArtistAndAlbum()`: Manuelle Suche
- `getReleaseDetails()`: Release-Informationen
- `getTrackList()`: Track-Liste mit Metadaten
- `getCoverArt()`: Cover-Art von coverartarchive.org

Rate Limiting: 1 Sekunde zwischen Anfragen eingebaut.

#### FFmpegService ([ffmpeg_service.dart](lib/services/ffmpeg_service.dart))
Konvertiert Audio-Dateien:
- `convertAudio()`: Einzelne Datei konvertieren
- `convertMultipleTracks()`: Batch-Konvertierung
- `createCueSheet()`: CUE-Sheet erstellen

Unterstützte Formate:
- FLAC (verlustfrei, Kompression 0-8)
- MP3 (VBR/CBR, verschiedene Qualitäten)
- AAC, Opus, OGG Vorbis
- WAV (unkomprimiert)
- ALAC, APE

### Datenmodelle ([cd_info.dart](lib/models/cd_info.dart))

```dart
class CDInfo {
  final String discId;           // MusicBrainz Disc-ID
  final String? freedbId;        // FreeDB-ID
  final int numberOfTracks;      // Anzahl Tracks
  final Duration totalDuration;  // Gesamtdauer
  final List<Track> tracks;      // Track-Liste
  final CDMetadata? metadata;    // Album-Metadaten
}

class Track {
  final int number;
  final Duration duration;
  final int startSector;         // CD-Sektor Start
  final int endSector;           // CD-Sektor Ende
  final TrackMetadata? metadata;
  final RipStatus ripStatus;     // notStarted, ripping, completed, error
  final double? ripProgress;     // 0.0 - 1.0
}

class CDMetadata {
  final String? artist;
  final String? albumTitle;
  final String? year;
  final String? genre;
  final String? label;
  final String? catalogNumber;
  final String? barcode;
  final String? coverArtUrl;
  final String? musicBrainzReleaseId;
}
```

### UI-Komponenten

#### Theme ([app_theme.dart](lib/theme/app_theme.dart))
Zentrales Design-System mit:
- Dunkles Theme mit Indigo/Purple/Pink Farbpalette
- Glassmorphismus-Dekorationen
- Gradient-Definitionen
- Material 3 Integration

#### Glass Widgets ([glass_widgets.dart](lib/widgets/glass_widgets.dart))
Wiederverwendbare UI-Komponenten:
- `GlassCard`: Glassmorphismus-Container mit Blur-Effekt
- `AnimatedGradientBackground`: Animierter Hintergrund
- `GradientIcon`: Icon mit Gradient
- `PulsingDot`: Pulsierende Status-Anzeige
- `AnimatedProgressBar`: Progress-Bar mit Gradient

#### Screens

**CDInfoScreen** ([cd_info_screen.dart](lib/screens/cd_info_screen.dart)):
- Haupt-UI mit CD-Informationen
- Track-Liste mit Auswahl
- Quick-Stats (Tracks, Dauer, Disc-ID)
- Navigation zu Metadaten-Editor und Export

**MetadataEditorScreen** ([metadata_editor_screen.dart](lib/screens/metadata_editor_screen.dart)):
- MusicBrainz-Suche integriert
- Bearbeitung von Album- und Track-Metadaten
- Cover-Art Download
- Automatische Track-Info-Übernahme

**ExportScreen** ([export_screen.dart](lib/screens/export_screen.dart)):
- Format-Auswahl
- Qualitäts-Einstellungen
- Output-Verzeichnis-Auswahl
- Progress-Tracking während Export

## Workflow

### Typischer Ablauf:

1. **CD wird eingelegt**
   - `CDService.isCDPresent()` prüft automatisch
   - `CDService.scanCD()` liest CD-Informationen

2. **Metadaten abrufen**
   - User navigiert zu Metadaten-Editor
   - Suche per Disc-ID bei MusicBrainz
   - Metadaten werden in State übernommen

3. **Tracks auswählen**
   - User wählt gewünschte Tracks
   - State wird in `selectedTracksProvider` gespeichert

4. **Export starten**
   - User wählt Format und Qualität
   - Für jeden Track:
     - Rippen mit cdparanoia → WAV
     - Konvertieren mit FFmpeg → Zielformat
     - Metadaten einbetten
     - Progress-Updates

## Erweiterungsmöglichkeiten

### Neue Audio-Formate hinzufügen

1. Format zu `AudioFormat` enum hinzufügen:
```dart
enum AudioFormat {
  flac,
  mp3,
  newFormat, // <-- Neu
}
```

2. FFmpeg-Argumente definieren:
```dart
case AudioFormat.newFormat:
  return ['-c:a', 'codec_name', '-option', 'value'];
```

### MusicBrainz-Features erweitern

```dart
// Neuer Service-Call
Future<List<Similar>> getSimilarReleases(String releaseId) async {
  final response = await _dio.get(
    '$_baseUrl/release/$releaseId/similar',
    queryParameters: {'fmt': 'json'},
  );
  // Parse und return
}
```

### UI-Anpassungen

Das Theme kann einfach in [app_theme.dart](lib/theme/app_theme.dart) angepasst werden:
```dart
static const primaryColor = Color(0xFF6366F1); // Ändern für andere Farbe
```

## Testing

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter test integration_test/
```

### Manuelle Tests
```bash
# App starten
./run.sh

# Oder direkt
flutter run -d linux
```

## Debugging

### CD-Service debuggen
```dart
// In cd_service.dart logging aktivieren
print('TOC Info: $tocInfo');
```

### MusicBrainz API
Alle API-Calls loggen bereits Fehler:
```dart
catch (e) {
  print('Fehler bei MusicBrainz-Suche: $e');
}
```

### FFmpeg-Kommandos
FFmpeg gibt detaillierte Logs auf stderr:
```dart
process.stderr.transform(utf8.decoder).listen((data) {
  print('FFmpeg: $data');
});
```

## Performance-Tipps

1. **Paralleles Rippen**: Mehrere Tracks gleichzeitig rippen (CPU-intensiv)
2. **Caching**: MusicBrainz-Ergebnisse cachen
3. **Temp-Dateien**: WAV-Dateien nach Konvertierung sofort löschen
4. **Progress-Updates**: Nicht zu häufig UI updaten (max. 10x/Sekunde)

## Bekannte Probleme & Lösungen

### Problem: "Unable to open disc"
**Lösung**: 
- CD-Laufwerk prüfen: `ls -l /dev/cdrom`
- Berechtigungen: `sudo chmod 666 /dev/cdrom`
- Device-Path anpassen in `CDService`

### Problem: MusicBrainz 503 Error
**Lösung**: Rate Limit überschritten, 1 Minute warten

### Problem: FFmpeg codec not found
**Lösung**: FFmpeg mit allen Codecs neu kompilieren oder aus Repo installieren

## Best Practices

1. **Immer mit ref.watch() State beobachten**
```dart
final cdInfo = ref.watch(cdInfoProvider);
```

2. **AsyncValue korrekt behandeln**
```dart
cdInfo.when(
  data: (data) => buildUI(data),
  loading: () => CircularProgressIndicator(),
  error: (err, stack) => Text('Error: $err'),
);
```

3. **Dispose Controllers**
```dart
@override
void dispose() {
  _controller.dispose();
  super.dispose();
}
```

4. **Error Handling**
```dart
try {
  await riskyOperation();
} catch (e) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

## Deployment

### Linux Desktop Build
```bash
flutter build linux --release
```

Die ausführbare Datei liegt in:
```
build/linux/x64/release/bundle/
```

### Distribution
Für Distribution sollte ein Installer erstellt werden:
- AppImage
- Snap
- Flatpak
- .deb/.rpm Pakete

## Weiterführende Ressourcen

- [Flutter Desktop Docs](https://docs.flutter.dev/desktop)
- [Riverpod Docs](https://riverpod.dev)
- [MusicBrainz API](https://musicbrainz.org/doc/MusicBrainz_API)
- [FFmpeg Docs](https://ffmpeg.org/documentation.html)
- [cdparanoia Manual](https://linux.die.net/man/1/cdparanoia)
