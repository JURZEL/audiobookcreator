import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/cd_info.dart';

class MusicBrainzService {
  static const String _baseUrl = 'https://musicbrainz.org/ws/2';
  static const String _coverArtUrl = 'https://coverartarchive.org';

  final Dio _dio;

  /// Erzeugt den Service. Optional kann eine Kontakt-E-Mail angegeben werden,
  /// die im User-Agent mitgesendet wird (erforderlich laut MusicBrainz-Richtlinien).
  MusicBrainzService({String? contactEmail})
    : _dio = Dio(
        BaseOptions(
          headers: {'User-Agent': _formatUserAgent(contactEmail)},
          receiveTimeout: const Duration(seconds: 10),
          connectTimeout: const Duration(seconds: 10),
        ),
      );

  static String _formatUserAgent(String? contactEmail) {
    final app = 'AudiobookCreator';
    final version = '1.0.0';
    final contactPart = (contactEmail != null && contactEmail.isNotEmpty)
        ? '; $contactEmail'
        : '';
    return '$app/$version (https://github.com/yourapp$contactPart)';
  }

  /// Sucht nach CD-Informationen anhand der Disc-ID
  Future<List<CDMetadata>> searchByDiscId(String discId) async {
    try {
      await Future.delayed(const Duration(seconds: 1)); // Rate limiting

      final url = '$_baseUrl/discid/$discId';
      final params = {
        'fmt': 'json',
        'inc': 'artist-credits+recordings+release-groups+labels',
      };
      
      _logDebug('MusicBrainz API Anfrage: $url');
      _logDebug('Parameter: $params');
      _logDebug('User-Agent: ${_dio.options.headers['User-Agent']}');

      final response = await _dio.get(
        url,
        queryParameters: params,
        options: Options(
          validateStatus: (status) {
            // 200 = OK, 404 = nicht gefunden (normal), andere = Fehler
            return status != null && (status == 200 || status == 404);
          },
        ),
      );

      _logDebug('MusicBrainz Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data;
        _logDebug('MusicBrainz Response Data: ${data.toString().substring(0, data.toString().length > 200 ? 200 : data.toString().length)}...');
        return _parseReleases(data);
      } else if (response.statusCode == 404) {
        _logDebug(
          'Disc-ID "$discId" wurde in MusicBrainz nicht gefunden (404). '
          'Die CD ist möglicherweise nicht in der Datenbank.',
        );
        return [];
      }

      return [];
    } catch (e) {
      _logDebug('Fehler bei MusicBrainz-Suche: $e');
      return [];
    }
  }

  /// Sucht nach CD-Informationen anhand von Artist und Album
  Future<List<CDMetadata>> searchByArtistAndAlbum(
    String artist,
    String album,
  ) async {
    try {
      await Future.delayed(const Duration(seconds: 1)); // Rate limiting

      final query = 'artist:"$artist" AND release:"$album"';
      final response = await _dio.get(
        '$_baseUrl/release',
        queryParameters: {'query': query, 'fmt': 'json', 'limit': 10},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return _parseSearchResults(data);
      }

      return [];
    } catch (e) {
      _logDebug('Fehler bei MusicBrainz-Suche: $e');
      return [];
    }
  }

  /// Holt detaillierte Release-Informationen
  Future<CDMetadata?> getReleaseDetails(String releaseId) async {
    try {
      await Future.delayed(const Duration(seconds: 1)); // Rate limiting

      final response = await _dio.get(
        '$_baseUrl/release/$releaseId',
        queryParameters: {
          'fmt': 'json',
          'inc': 'artist-credits+recordings+release-groups+labels+discids',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return _parseRelease(data);
      }

      return null;
    } catch (e) {
      _logDebug('Fehler beim Abrufen der Release-Details: $e');
      return null;
    }
  }

  /// Holt die Track-Liste für ein Release
  Future<List<TrackMetadata>> getTrackList(
    String releaseId, {
    int? discNumber,
  }) async {
    try {
      await Future.delayed(const Duration(seconds: 1)); // Rate limiting

      final response = await _dio.get(
        '$_baseUrl/release/$releaseId',
        queryParameters: {
          'fmt': 'json',
          'inc': 'recordings+artist-credits+isrcs',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return _parseTrackList(data, discNumber: discNumber);
      }

      return [];
    } catch (e) {
      _logDebug('Fehler beim Abrufen der Track-Liste: $e');
      return [];
    }
  }

  /// Holt Cover-Art für ein Release
  Future<String?> getCoverArt(String releaseId) async {
    try {
      _logDebug('Lade Cover-Art für Release: $releaseId');
      
      final response = await _dio.get(
        '$_coverArtUrl/release/$releaseId',
        queryParameters: {'fmt': 'json'},
        options: Options(
          validateStatus: (status) {
            // 200 = OK, 404 = kein Cover vorhanden (normal)
            return status != null && (status == 200 || status == 404);
          },
        ),
      );

      _logDebug('Cover-Art Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data;
        final images = data['images'] as List?;
        _logDebug('Cover-Art Images gefunden: ${images?.length ?? 0}');
        
        if (images != null && images.isNotEmpty) {
          // Suche nach Front-Cover
          Map<String, dynamic>? frontImage;

          // 1. Suche nach Bild mit type 'Front'
          for (final image in images) {
            final types = image['types'] as List?;
            if (types != null && types.contains('Front')) {
              frontImage = image;
              _logDebug('Front-Cover gefunden');
              break;
            }
          }

          // 2. Fallback: Nimm das erste Bild, wenn kein Front-Cover definiert
          frontImage ??= images.first;
          _logDebug('Verwende Cover-Bild: ${frontImage != null}');

          if (frontImage != null) {
            final thumbnails =
                frontImage['thumbnails'] as Map<String, dynamic>?;

            // Bevorzuge Large (500px) oder Small (250px) für schnellere Ladezeiten
            // und bessere Zuverlässigkeit als das riesige Originalbild
            if (thumbnails != null) {
              if (thumbnails.containsKey('large')) {
                _logDebug('Cover-Art URL (large): ${thumbnails['large']}');
                return thumbnails['large'] as String;
              }
              if (thumbnails.containsKey('500')) {
                _logDebug('Cover-Art URL (500): ${thumbnails['500']}');
                return thumbnails['500'] as String;
              }
              if (thumbnails.containsKey('small')) {
                _logDebug('Cover-Art URL (small): ${thumbnails['small']}');
                return thumbnails['small'] as String;
              }
              if (thumbnails.containsKey('250')) {
                _logDebug('Cover-Art URL (250): ${thumbnails['250']}');
                return thumbnails['250'] as String;
              }
            }

            final imageUrl = frontImage['image'] as String?;
            _logDebug('Cover-Art URL (original): $imageUrl');
            return imageUrl;
          }
        }
      } else if (response.statusCode == 404) {
        _logDebug('Kein Cover-Art für Release $releaseId verfügbar (404)');
      }

      return null;
    } catch (e) {
      _logDebug('Fehler beim Abrufen des Cover-Arts: $e');
      return null;
    }
  }

  List<CDMetadata> _parseReleases(Map<String, dynamic> data) {
    final results = <CDMetadata>[];
    final releases = data['releases'] as List?;

    if (releases == null) return results;

    _logDebug('Anzahl gefundener Releases: ${releases.length}');
    for (final release in releases) {
      final parsed = _parseRelease(release);
      _logDebug('Release: ${parsed.albumTitle} (ID: ${parsed.musicBrainzReleaseId})');
      results.add(parsed);
    }

    return results;
  }

  List<CDMetadata> _parseSearchResults(Map<String, dynamic> data) {
    final results = <CDMetadata>[];
    final releases = data['releases'] as List?;

    if (releases == null) return results;

    for (final release in releases) {
      results.add(_parseRelease(release));
    }

    return results;
  }

  CDMetadata _parseRelease(Map<String, dynamic> release) {
    // Artist extrahieren
    String? artist;
    final artistCredit = release['artist-credit'] as List?;
    if (artistCredit != null && artistCredit.isNotEmpty) {
      artist = artistCredit.map((a) => a['artist']?['name'] ?? '').join(', ');
    }

    // Jahr extrahieren
    String? year;
    final date = release['date'] as String?;
    if (date != null && date.length >= 4) {
      year = date.substring(0, 4);
    }

    // Label extrahieren
    String? label;
    final labelInfo = release['label-info'] as List?;
    if (labelInfo != null && labelInfo.isNotEmpty) {
      label = labelInfo.first['label']?['name'];
    }

    // Barcode extrahieren
    final barcode = release['barcode'] as String?;

    // Catalog-Number extrahieren
    String? catalogNumber;
    if (labelInfo != null && labelInfo.isNotEmpty) {
      catalogNumber = labelInfo.first['catalog-number'];
    }

    // Anzahl der Medien (CDs) extrahieren
    int? mediaCount;
    final media = release['media'] as List?;
    if (media != null) {
      mediaCount = media.length;
    } else {
      final mediumCount = release['medium-count'] as int?;
      if (mediumCount != null) {
        mediaCount = mediumCount;
      }
    }

    return CDMetadata(
      artist: artist,
      albumTitle: release['title'] as String?,
      year: year,
      genre: null, // MusicBrainz gibt Genres anders zurück
      label: label,
      catalogNumber: catalogNumber,
      barcode: barcode,
      musicBrainzReleaseId: release['id'] as String?,
      mediaCount: mediaCount,
      author: null, // Muss manuell gesetzt werden
      narrator: null, // Muss manuell gesetzt werden
      publisher: label, // Verwende Label als Publisher
      description: null,
      language: null,
      copyright: null,
      comment: null,
      series: null,
      seriesPart: null,
      discNumber: null,
    );
  }

  List<TrackMetadata> _parseTrackList(
    Map<String, dynamic> data, {
    int? discNumber,
  }) {
    final tracks = <TrackMetadata>[];
    final media = data['media'] as List?;

    if (media == null || media.isEmpty) return tracks;

    // Wähle das richtige Medium basierend auf der Disc-Nummer
    Map<String, dynamic>? selectedMedium;

    if (discNumber != null && discNumber > 0 && discNumber <= media.length) {
      // Disc-Nummer ist 1-basiert, media ist 0-basiert
      selectedMedium = media[discNumber - 1] as Map<String, dynamic>?;
      _logDebug('Using disc $discNumber from ${media.length} available discs');
    } else {
      // Fallback: Nimm das erste Medium
      selectedMedium = media.first as Map<String, dynamic>?;
      _logDebug('Using first disc (no disc number specified or invalid)');
    }

    if (selectedMedium == null) return tracks;

    final trackList = selectedMedium['tracks'] as List?;

    if (trackList == null) return tracks;

    _logDebug('Found ${trackList.length} tracks on selected disc');

    for (final track in trackList) {
      final recording = track['recording'] as Map<String, dynamic>?;
      if (recording == null) continue;

      // Artist extrahieren
      String? artist;
      final artistCredit = recording['artist-credit'] as List?;
      if (artistCredit != null && artistCredit.isNotEmpty) {
        artist = artistCredit.map((a) => a['artist']?['name'] ?? '').join(', ');
      }

      // ISRC extrahieren
      String? isrc;
      final isrcs = recording['isrcs'] as List?;
      if (isrcs != null && isrcs.isNotEmpty) {
        isrc = isrcs.first as String?;
      }

      tracks.add(
        TrackMetadata(
          title: track['title'] as String?,
          artist: artist,
          isrc: isrc,
        ),
      );
    }

    return tracks;
  }

  /// Sucht nach ähnlichen Releases basierend auf Titel und Artist
  Future<List<CDMetadata>> fuzzySearch(String query) async {
    try {
      await Future.delayed(const Duration(seconds: 1)); // Rate limiting

      final response = await _dio.get(
        '$_baseUrl/release',
        queryParameters: {'query': query, 'fmt': 'json', 'limit': 20},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return _parseSearchResults(data);
      }

      return [];
    } catch (e) {
      _logDebug('Fehler bei Fuzzy-Suche: $e');
      return [];
    }
  }

  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }
}
