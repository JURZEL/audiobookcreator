import 'cd_info.dart';

/// Konfiguration für das CD-Ripping
class RippingConfig {
  final AudioFormat format;
  final String outputDirectory;
  final String filenameTemplate;
  final Map<String, dynamic> formatOptions;
  final List<int> selectedTracks;
  final bool embedCoverArt;
  final bool createPlaylist;
  
  RippingConfig({
    required this.format,
    required this.outputDirectory,
    this.filenameTemplate = '%TrackNumber - %Title',
    this.formatOptions = const {},
    this.selectedTracks = const [],
    this.embedCoverArt = true,
    this.createPlaylist = false,
  });

  RippingConfig copyWith({
    AudioFormat? format,
    String? outputDirectory,
    String? filenameTemplate,
    Map<String, dynamic>? formatOptions,
    List<int>? selectedTracks,
    bool? embedCoverArt,
    bool? createPlaylist,
  }) {
    return RippingConfig(
      format: format ?? this.format,
      outputDirectory: outputDirectory ?? this.outputDirectory,
      filenameTemplate: filenameTemplate ?? this.filenameTemplate,
      formatOptions: formatOptions ?? this.formatOptions,
      selectedTracks: selectedTracks ?? this.selectedTracks,
      embedCoverArt: embedCoverArt ?? this.embedCoverArt,
      createPlaylist: createPlaylist ?? this.createPlaylist,
    );
  }

  /// Verfügbare Platzhalter für Dateinamen
  static const Map<String, String> availablePlaceholders = {
    '%TrackNumber': 'Track-Nummer (01, 02, ...)',
    '%Title': 'Track-Titel',
    '%Artist': 'Künstler',
    '%Album': 'Album-Titel',
    '%AlbumArtist': 'Album-Künstler',
    '%Year': 'Jahr',
    '%Genre': 'Genre',
    '%CD': 'Disc-Nummer',
    '%Author': 'Autor (für Audiobooks)',
    '%Narrator': 'Sprecher (für Audiobooks)',
    '%Series': 'Reihe',
    '%SeriesPart': 'Teil der Reihe',
  };

  /// Ersetzt Platzhalter im Dateinamen-Template
  String generateFilename(Track track, CDMetadata? metadata, int trackNumber) {
    String filename = filenameTemplate;
    
    // Track-Nummer mit führenden Nullen
    filename = filename.replaceAll('%TrackNumber', trackNumber.toString().padLeft(2, '0'));
    
    // Track-Metadaten
    filename = filename.replaceAll('%Title', track.metadata?.title ?? 'Track $trackNumber');
    filename = filename.replaceAll('%Artist', track.metadata?.artist ?? metadata?.artist ?? 'Unknown Artist');
    
    // Album-Metadaten
    filename = filename.replaceAll('%Album', metadata?.albumTitle ?? 'Unknown Album');
    filename = filename.replaceAll('%AlbumArtist', metadata?.artist ?? 'Unknown Artist');
    filename = filename.replaceAll('%Year', metadata?.year ?? '');
    filename = filename.replaceAll('%Genre', metadata?.genre ?? '');
    
    // Disc-Nummer
    filename = filename.replaceAll('%CD', metadata?.discNumber?.toString() ?? '1');
    
    // Audiobook-spezifisch
    filename = filename.replaceAll('%Author', metadata?.author ?? metadata?.artist ?? '');
    filename = filename.replaceAll('%Narrator', metadata?.narrator ?? '');
    filename = filename.replaceAll('%Series', metadata?.series ?? '');
    filename = filename.replaceAll('%SeriesPart', metadata?.seriesPart ?? '');
    
    // Ungültige Dateinamen-Zeichen entfernen
    filename = filename.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    
    // Mehrfache Leerzeichen entfernen
    filename = filename.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return filename;
  }

  /// Vordefinierte Templates
  static const Map<String, String> predefinedTemplates = {
    'Standard': '%TrackNumber - %Title',
    'Musik Standard': '%TrackNumber - %Artist - %Title',
    'Album-Ordner': '%Album/%TrackNumber - %Title',
    'Künstler-Album': '%Artist - %Album/%TrackNumber - %Title',
    'Audiobook Standard': '%TrackNumber - %Title',
    'Audiobook mit Autor': '%Author - %Album/%TrackNumber - %Title',
    'Audiobook mit Sprecher': '%Narrator - %Album/%TrackNumber - %Title',
    'Hörbuch Reihe': '%Author/%Series %SeriesPart - %Album/%TrackNumber - %Title',
    'Multi-Disc': 'CD%CD/%TrackNumber - %Title',
  };
}

/// Format-spezifische Optionen
class FormatOptions {
  // MP3
  static const String mp3BitrateKey = 'bitrate';
  static const String mp3ModeKey = 'mode'; // 'vbr' oder 'cbr'
  static const String mp3QualityKey = 'quality'; // 0-9 für VBR
  
  // FLAC
  static const String flacCompressionKey = 'compression'; // 0-8
  
  // AAC
  static const String aacBitrateKey = 'bitrate';
  
  // Opus
  static const String opusBitrateKey = 'bitrate';
  
  // OGG Vorbis
  static const String oggQualityKey = 'quality'; // 0-10
  
  /// Standard-Optionen für jedes Format
  static Map<String, dynamic> getDefaultOptions(AudioFormat format) {
    switch (format) {
      case AudioFormat.mp3:
        return {
          mp3ModeKey: 'vbr',
          mp3QualityKey: 2, // V2 = ~190 kbps
        };
      case AudioFormat.flac:
        return {
          flacCompressionKey: 5, // Standard-Kompression
        };
      case AudioFormat.aac:
        return {
          aacBitrateKey: 192,
        };
      case AudioFormat.opus:
        return {
          opusBitrateKey: 128,
        };
      case AudioFormat.ogg:
        return {
          oggQualityKey: 6, // ~192 kbps
        };
      case AudioFormat.wav:
        return {}; // Keine Optionen
      case AudioFormat.alac:
        return {}; // Keine Optionen
      case AudioFormat.ape:
        return {}; // Keine Optionen
    }
  }
}
