class AudioFile {
  final String filePath;
  final String fileName;
  final String directory;
  final int? trackNumber;
  final int? discNumber;
  final String? title;
  final String? artist;
  final String? albumArtist;
  final String? author;
  final String? narrator;
  final String? genre;
  final String? year;
  final String? comment;
  final String? album;
  final String? coverArtPath;
  final Duration duration;

  AudioFile({
    required this.filePath,
    required this.fileName,
    required this.directory,
    this.trackNumber,
    this.discNumber,
    this.title,
    this.artist,
    this.albumArtist,
    this.author,
    this.narrator,
    this.genre,
    this.year,
    this.comment,
    this.album,
    required this.duration,
    this.coverArtPath,
  });

  String get displayTitle {
    if (title != null && title!.isNotEmpty) return title!;
    return fileName;
  }

  String get displayGroup {
    if (discNumber != null) return 'Disc $discNumber';
    if (directory.isNotEmpty && directory != '.') return directory;
    return 'Andere';
  }
}

enum AudiobookFormat {
  m4b,
  mkv;

  String get extension {
    switch (this) {
      case AudiobookFormat.m4b:
        return 'm4b';
      case AudiobookFormat.mkv:
        return 'mkv';
    }
  }

  String get displayName {
    switch (this) {
      case AudiobookFormat.m4b:
        return 'M4B (iTunes/Apple Books)';
      case AudiobookFormat.mkv:
        return 'MKV (Matroska)';
    }
  }
}

class AudiobookMetadata {
  String? title;
  String? artist;
  String? album;
  String? author;
  String? narrator;
  String? year;
  String? genre;
  String? description;
  String? publisher;
  String? coverArtPath;

  AudiobookMetadata({
    this.title,
    this.artist,
    this.album,
    this.author,
    this.narrator,
    this.year,
    this.genre,
    this.description,
    this.publisher,
    this.coverArtPath,
  });

  factory AudiobookMetadata.fromAudioFile(AudioFile file) {
    return AudiobookMetadata(
      title: file.album,
      artist: file.artist,
      album: file.album,
      author: file.artist,
      genre: 'Audiobook',
    );
  }

  AudiobookMetadata copyWith({
    String? title,
    String? artist,
    String? album,
    String? author,
    String? narrator,
    String? year,
    String? genre,
    String? description,
    String? publisher,
    String? coverArtPath,
  }) {
    return AudiobookMetadata(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      author: author ?? this.author,
      narrator: narrator ?? this.narrator,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      description: description ?? this.description,
      publisher: publisher ?? this.publisher,
      coverArtPath: coverArtPath ?? this.coverArtPath,
    );
  }
}

class AudiobookProject {
  final String sourceDirectory;
  final List<AudioFile> files;
  AudiobookMetadata metadata;
  AudiobookFormat format;
  String? outputPath;
  bool isProcessing;
  double progress;
  String statusMessage;

  AudiobookProject({
    required this.sourceDirectory,
    required this.files,
    required this.metadata,
    this.format = AudiobookFormat.m4b,
    this.outputPath,
    this.isProcessing = false,
    this.progress = 0.0,
    this.statusMessage = '',
  });

  int get totalTracks => files.length;

  Duration get totalDuration {
    return files.fold(Duration.zero, (sum, file) => sum + file.duration);
  }

  String get formattedDuration {
    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes.remainder(60);
    final seconds = totalDuration.inSeconds.remainder(60);
    return '${hours}h ${minutes}m ${seconds}s';
  }

  AudiobookProject copyWith({
    String? sourceDirectory,
    List<AudioFile>? files,
    AudiobookMetadata? metadata,
    AudiobookFormat? format,
    String? outputPath,
    bool? isProcessing,
    double? progress,
    String? statusMessage,
  }) {
    return AudiobookProject(
      sourceDirectory: sourceDirectory ?? this.sourceDirectory,
      files: files ?? this.files,
      metadata: metadata ?? this.metadata,
      format: format ?? this.format,
      outputPath: outputPath ?? this.outputPath,
      isProcessing: isProcessing ?? this.isProcessing,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}
