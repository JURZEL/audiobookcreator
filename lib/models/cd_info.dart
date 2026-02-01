class CDInfo {
  final String discId;
  final String? freedbId;
  final int numberOfTracks;
  final Duration totalDuration;
  final List<Track> tracks;
  final CDMetadata? metadata;
  final DateTime scannedAt;
  final String? devicePath;

  CDInfo({
    required this.discId,
    this.freedbId,
    required this.numberOfTracks,
    required this.totalDuration,
    required this.tracks,
    this.metadata,
    required this.scannedAt,
    this.devicePath,
  });

  CDInfo copyWith({
    String? discId,
    String? freedbId,
    int? numberOfTracks,
    Duration? totalDuration,
    List<Track>? tracks,
    CDMetadata? metadata,
    DateTime? scannedAt,
    String? devicePath,
  }) {
    return CDInfo(
      discId: discId ?? this.discId,
      freedbId: freedbId ?? this.freedbId,
      numberOfTracks: numberOfTracks ?? this.numberOfTracks,
      totalDuration: totalDuration ?? this.totalDuration,
      tracks: tracks ?? this.tracks,
      metadata: metadata ?? this.metadata,
      scannedAt: scannedAt ?? this.scannedAt,
      devicePath: devicePath ?? this.devicePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'discId': discId,
      'freedbId': freedbId,
      'numberOfTracks': numberOfTracks,
      'totalDuration': totalDuration.inSeconds,
      'tracks': tracks.map((t) => t.toJson()).toList(),
      'metadata': metadata?.toJson(),
      'scannedAt': scannedAt.toIso8601String(),
      'devicePath': devicePath,
    };
  }
}

class Track {
  final int number;
  final Duration duration;
  final int startSector;
  final int endSector;
  final TrackMetadata? metadata;
  final RipStatus ripStatus;
  final double? ripProgress;

  Track({
    required this.number,
    required this.duration,
    required this.startSector,
    required this.endSector,
    this.metadata,
    this.ripStatus = RipStatus.notStarted,
    this.ripProgress,
  });

  Track copyWith({
    int? number,
    Duration? duration,
    int? startSector,
    int? endSector,
    TrackMetadata? metadata,
    RipStatus? ripStatus,
    double? ripProgress,
  }) {
    return Track(
      number: number ?? this.number,
      duration: duration ?? this.duration,
      startSector: startSector ?? this.startSector,
      endSector: endSector ?? this.endSector,
      metadata: metadata ?? this.metadata,
      ripStatus: ripStatus ?? this.ripStatus,
      ripProgress: ripProgress ?? this.ripProgress,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'duration': duration.inSeconds,
      'startSector': startSector,
      'endSector': endSector,
      'metadata': metadata?.toJson(),
      'ripStatus': ripStatus.name,
      'ripProgress': ripProgress,
    };
  }
}

enum RipStatus {
  notStarted,
  ripping,
  completed,
  error,
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
  final int? mediaCount;
  // Erweiterte Metadaten für Audiobooks/Hörspiele
  final String? author;          // Autor (bei Audiobooks)
  final String? narrator;        // Sprecher/Erzähler
  final String? publisher;       // Verlag
  final String? description;     // Beschreibung
  final String? language;        // Sprache (z.B. "de", "en")
  final String? copyright;       // Copyright
  final String? comment;         // Kommentar
  final String? series;          // Reihe/Serie
  final String? seriesPart;      // Teil der Reihe
  final int? discNumber;         // Disc-Nummer bei Multi-Disc-Sets

  CDMetadata({
    this.artist,
    this.albumTitle,
    this.year,
    this.genre,
    this.label,
    this.catalogNumber,
    this.barcode,
    this.coverArtUrl,
    this.musicBrainzReleaseId,
    this.mediaCount,
    this.author,
    this.narrator,
    this.publisher,
    this.description,
    this.language,
    this.copyright,
    this.comment,
    this.series,
    this.seriesPart,
    this.discNumber,
  });

  CDMetadata copyWith({
    String? artist,
    String? albumTitle,
    String? year,
    String? genre,
    String? label,
    String? catalogNumber,
    String? barcode,
    String? coverArtUrl,
    String? musicBrainzReleaseId,
    int? mediaCount,
    String? author,
    String? narrator,
    String? publisher,
    String? description,
    String? language,
    String? copyright,
    String? comment,
    String? series,
    String? seriesPart,
    int? discNumber,
  }) {
    return CDMetadata(
      artist: artist ?? this.artist,
      albumTitle: albumTitle ?? this.albumTitle,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      label: label ?? this.label,
      catalogNumber: catalogNumber ?? this.catalogNumber,
      barcode: barcode ?? this.barcode,
      coverArtUrl: coverArtUrl ?? this.coverArtUrl,
      musicBrainzReleaseId: musicBrainzReleaseId ?? this.musicBrainzReleaseId,
      mediaCount: mediaCount ?? this.mediaCount,
      author: author ?? this.author,
      narrator: narrator ?? this.narrator,
      publisher: publisher ?? this.publisher,
      description: description ?? this.description,
      language: language ?? this.language,
      copyright: copyright ?? this.copyright,
      comment: comment ?? this.comment,
      series: series ?? this.series,
      seriesPart: seriesPart ?? this.seriesPart,
      discNumber: discNumber ?? this.discNumber,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'artist': artist,
      'albumTitle': albumTitle,
      'year': year,
      'genre': genre,
      'label': label,
      'catalogNumber': catalogNumber,
      'barcode': barcode,
      'coverArtUrl': coverArtUrl,
      'musicBrainzReleaseId': musicBrainzReleaseId,
      'mediaCount': mediaCount,
      'author': author,
      'narrator': narrator,
      'publisher': publisher,
      'description': description,
      'language': language,
      'copyright': copyright,
      'comment': comment,
      'series': series,
      'seriesPart': seriesPart,
      'discNumber': discNumber,
    };
  }

  factory CDMetadata.fromJson(Map<String, dynamic> json) {
    return CDMetadata(
      artist: json['artist'],
      albumTitle: json['albumTitle'],
      year: json['year'],
      genre: json['genre'],
      label: json['label'],
      catalogNumber: json['catalogNumber'],
      barcode: json['barcode'],
      coverArtUrl: json['coverArtUrl'],
      musicBrainzReleaseId: json['musicBrainzReleaseId'],
      mediaCount: json['mediaCount'],
      author: json['author'],
      narrator: json['narrator'],
      publisher: json['publisher'],
      description: json['description'],
      language: json['language'],
      copyright: json['copyright'],
      comment: json['comment'],
      series: json['series'],
      seriesPart: json['seriesPart'],
      discNumber: json['discNumber'],
    );
  }
}

class TrackMetadata {
  final String? title;
  final String? artist;
  final String? isrc;

  TrackMetadata({
    this.title,
    this.artist,
    this.isrc,
  });

  TrackMetadata copyWith({
    String? title,
    String? artist,
    String? isrc,
  }) {
    return TrackMetadata(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      isrc: isrc ?? this.isrc,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'artist': artist,
      'isrc': isrc,
    };
  }

  factory TrackMetadata.fromJson(Map<String, dynamic> json) {
    return TrackMetadata(
      title: json['title'],
      artist: json['artist'],
      isrc: json['isrc'],
    );
  }
}

enum AudioFormat {
  flac,
  mp3,
  aac,
  opus,
  ogg,
  wav,
  alac,
  ape,
}

extension AudioFormatExtension on AudioFormat {
  String get displayName {
    switch (this) {
      case AudioFormat.flac:
        return 'FLAC (Lossless)';
      case AudioFormat.mp3:
        return 'MP3';
      case AudioFormat.aac:
        return 'AAC';
      case AudioFormat.opus:
        return 'Opus';
      case AudioFormat.ogg:
        return 'OGG Vorbis';
      case AudioFormat.wav:
        return 'WAV (Uncompressed)';
      case AudioFormat.alac:
        return 'ALAC (Apple Lossless)';
      case AudioFormat.ape:
        return 'Monkey\'s Audio';
    }
  }

  String get extension {
    return name;
  }

  String get ffmpegCodec {
    switch (this) {
      case AudioFormat.flac:
        return 'flac';
      case AudioFormat.mp3:
        return 'libmp3lame';
      case AudioFormat.aac:
        return 'aac';
      case AudioFormat.opus:
        return 'libopus';
      case AudioFormat.ogg:
        return 'libvorbis';
      case AudioFormat.wav:
        return 'pcm_s16le';
      case AudioFormat.alac:
        return 'alac';
      case AudioFormat.ape:
        return 'ape';
    }
  }
}
