import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cd_info.dart';
import '../services/cd_service.dart';
import '../services/musicbrainz_service.dart';
import '../services/ffmpeg_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Services
final cdServiceProvider = Provider<CDService>((ref) => CDService());
final musicBrainzServiceProvider = Provider<MusicBrainzService>((ref) {
  // Watch settings to automatically recreate service when email changes
  final emailAsync = ref.watch(settingsProvider);
  final email = emailAsync.when(
    data: (v) => v,
    loading: () => null,
    error: (_, stack) => null,
  );
  return MusicBrainzService(contactEmail: email);
});

/// Persistente Anwendungseinstellungen
final settingsProvider = AsyncNotifierProvider<SettingsNotifier, String?>(
  () => SettingsNotifier(),
);

class SettingsNotifier extends AsyncNotifier<String?> {
  static const _keyContactEmail = 'musicbrainz_contact_email';

  @override
  Future<String?> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyContactEmail);
  }

  Future<void> setContactEmail(String? email) async {
    final prefs = await SharedPreferences.getInstance();
    if (email == null || email.isEmpty) {
      await prefs.remove(_keyContactEmail);
      state = const AsyncValue.data(null);
    } else {
      await prefs.setString(_keyContactEmail, email);
      state = AsyncValue.data(email);
    }
  }
}

final ffmpegServiceProvider = Provider<FFmpegService>((ref) => FFmpegService());

// CD Info State - using AsyncNotifier instead of StateNotifier
final cdInfoProvider = AsyncNotifierProvider<CDInfoNotifier, CDInfo?>(
  () => CDInfoNotifier(),
);

class CDInfoNotifier extends AsyncNotifier<CDInfo?> {
  late CDService _cdService;

  @override
  Future<CDInfo?> build() async {
    _cdService = ref.read(cdServiceProvider);
    // Beim Start nicht automatisch CD prüfen - nur null zurückgeben
    // Benutzer kann manuell "CD prüfen" klicken
    return null;
  }

  Future<CDInfo?> checkForCD() async {
    state = const AsyncValue.loading();

    try {
      final isPresent = await _cdService.isCDPresent();
      if (isPresent) {
        final cdInfo = await _cdService.scanCD();
        state = AsyncValue.data(cdInfo);
        return cdInfo;
      } else {
        state = const AsyncValue.data(null);
        return null;
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  Future<void> refreshCD() async {
    await checkForCD();
  }

  Future<void> ejectCD() async {
    await _cdService.ejectCD();
    state = const AsyncValue.data(null);
  }

  void updateMetadata(CDMetadata metadata) {
    state.whenData((cdInfo) {
      if (cdInfo != null) {
        state = AsyncValue.data(cdInfo.copyWith(metadata: metadata));
      }
    });
  }

  void updateTrackMetadata(int trackNumber, TrackMetadata metadata) {
    state.whenData((cdInfo) {
      if (cdInfo != null) {
        final updatedTracks = cdInfo.tracks.map((track) {
          if (track.number == trackNumber) {
            return track.copyWith(metadata: metadata);
          }
          return track;
        }).toList();

        state = AsyncValue.data(cdInfo.copyWith(tracks: updatedTracks));
      }
    });
  }

  void updateTrackRipProgress(int trackNumber, double progress) {
    state.whenData((cdInfo) {
      if (cdInfo != null) {
        final updatedTracks = cdInfo.tracks.map((track) {
          if (track.number == trackNumber) {
            return track.copyWith(
              ripStatus: RipStatus.ripping,
              ripProgress: progress,
            );
          }
          return track;
        }).toList();

        state = AsyncValue.data(cdInfo.copyWith(tracks: updatedTracks));
      }
    });
  }

  void markTrackCompleted(int trackNumber) {
    state.whenData((cdInfo) {
      if (cdInfo != null) {
        final updatedTracks = cdInfo.tracks.map((track) {
          if (track.number == trackNumber) {
            return track.copyWith(
              ripStatus: RipStatus.completed,
              ripProgress: 1.0,
            );
          }
          return track;
        }).toList();

        state = AsyncValue.data(cdInfo.copyWith(tracks: updatedTracks));
      }
    });
  }

  void markTrackError(int trackNumber) {
    state.whenData((cdInfo) {
      if (cdInfo != null) {
        final updatedTracks = cdInfo.tracks.map((track) {
          if (track.number == trackNumber) {
            return track.copyWith(ripStatus: RipStatus.error);
          }
          return track;
        }).toList();

        state = AsyncValue.data(cdInfo.copyWith(tracks: updatedTracks));
      }
    });
  }
}

// MusicBrainz Search State - using AsyncNotifier
final musicBrainzSearchProvider =
    AsyncNotifierProvider<MusicBrainzSearchNotifier, List<CDMetadata>>(
      () => MusicBrainzSearchNotifier(),
    );

class MusicBrainzSearchNotifier extends AsyncNotifier<List<CDMetadata>> {
  late MusicBrainzService _service;

  @override
  Future<List<CDMetadata>> build() async {
    _service = ref.read(musicBrainzServiceProvider);
    return [];
  }

  Future<void> searchByDiscId(String discId) async {
    state = const AsyncValue.loading();

    try {
      final results = await _service.searchByDiscId(discId);
      state = AsyncValue.data(results);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> searchByArtistAndAlbum(String artist, String album) async {
    state = const AsyncValue.loading();

    try {
      final results = await _service.searchByArtistAndAlbum(artist, album);
      state = AsyncValue.data(results);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> fuzzySearch(String query) async {
    state = const AsyncValue.loading();

    try {
      final results = await _service.fuzzySearch(query);
      state = AsyncValue.data(results);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void clear() {
    state = const AsyncValue.data([]);
  }
}

// Selected Audio Format
final selectedAudioFormatProvider =
    NotifierProvider<AudioFormatNotifier, AudioFormat>(
      () => AudioFormatNotifier(),
    );

class AudioFormatNotifier extends Notifier<AudioFormat> {
  @override
  AudioFormat build() => AudioFormat.flac;

  void setFormat(AudioFormat format) {
    state = format;
  }
}

// Selected Output Directory
final outputDirectoryProvider =
    NotifierProvider<OutputDirectoryNotifier, String?>(
      () => OutputDirectoryNotifier(),
    );

class OutputDirectoryNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setDirectory(String? directory) {
    state = directory;
  }
}

// Ripping State
final isRippingProvider = NotifierProvider<IsRippingNotifier, bool>(
  () => IsRippingNotifier(),
);

class IsRippingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setRipping(bool ripping) {
    state = ripping;
  }
}

// Selected Tracks for Ripping
final selectedTracksProvider =
    NotifierProvider<SelectedTracksNotifier, Set<int>>(
      () => SelectedTracksNotifier(),
    );

class SelectedTracksNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => {};

  void toggleTrack(int trackNumber) {
    if (state.contains(trackNumber)) {
      state = {...state}..remove(trackNumber);
    } else {
      state = {...state, trackNumber};
    }
  }

  void selectAll(List<int> trackNumbers) {
    state = trackNumbers.toSet();
  }

  void clearAll() {
    state = {};
  }
}
