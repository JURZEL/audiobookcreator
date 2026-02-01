import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/cd_info.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_widgets.dart'; // Keeping this for now if used elsewhere but ideally replace
import '../widgets/app_scaffold.dart';

class MusicBrainzSearchScreen extends ConsumerStatefulWidget {
  const MusicBrainzSearchScreen({super.key});

  @override
  ConsumerState<MusicBrainzSearchScreen> createState() =>
      _MusicBrainzSearchScreenState();
}

class _MusicBrainzSearchScreenState
    extends ConsumerState<MusicBrainzSearchScreen> {
  final _artistController = TextEditingController();
  final _albumController = TextEditingController();
  final _discIdController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _artistController.dispose();
    _albumController.dispose();
    _discIdController.dispose();
    super.dispose();
  }

  void _searchByArtistAndAlbum() async {
    if (_artistController.text.isEmpty || _albumController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte Artist und Album eingeben'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSearching = true);
    await ref
        .read(musicBrainzSearchProvider.notifier)
        .searchByArtistAndAlbum(_artistController.text, _albumController.text);
    setState(() => _isSearching = false);
  }

  void _searchByDiscId() async {
    if (_discIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte Disc-ID eingeben'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSearching = true);
    await ref
        .read(musicBrainzSearchProvider.notifier)
        .searchByDiscId(_discIdController.text);
    setState(() => _isSearching = false);
  }

  void _applyMetadata(CDMetadata metadata) async {
    // Metadaten auf die aktuelle CD anwenden
    ref.read(cdInfoProvider.notifier).updateMetadata(metadata);

    // Cover-Art laden
    if (metadata.musicBrainzReleaseId != null) {
      debugPrint('=== Lade Cover-Art für Release: ${metadata.musicBrainzReleaseId} ===');
      final musicBrainzService = ref.read(musicBrainzServiceProvider);
      
      // Versuche Cover für das ausgewählte Release zu laden
      String? coverArt = await musicBrainzService.getCoverArt(
        metadata.musicBrainzReleaseId!,
      );
      debugPrint('Cover-Art URL erhalten: $coverArt');
      
      // Fallback: Wenn kein Cover gefunden, prüfe alle Releases mit dieser Disc-ID
      if (coverArt == null) {
        debugPrint('Kein Cover für primäres Release gefunden, prüfe andere Releases...');
        final searchResults = ref.read(musicBrainzSearchProvider);
        await searchResults.when(
          data: (releases) async {
            for (final release in releases) {
              if (release.musicBrainzReleaseId != null &&
                  release.musicBrainzReleaseId != metadata.musicBrainzReleaseId) {
                debugPrint('Prüfe Cover für Release: ${release.musicBrainzReleaseId}');
                final altCover = await musicBrainzService.getCoverArt(
                  release.musicBrainzReleaseId!,
                );
                if (altCover != null) {
                  debugPrint('Cover in alternativem Release gefunden!');
                  coverArt = altCover;
                  break;
                }
              }
            }
          },
          loading: () {},
          error: (_, stack) {},
        );
      }
      
      if (coverArt != null && mounted) {
        debugPrint('Aktualisiere Metadaten mit Cover-Art');
        ref
            .read(cdInfoProvider.notifier)
            .updateMetadata(metadata.copyWith(coverArtUrl: coverArt));
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Metadaten und Cover erfolgreich übernommen'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        debugPrint('Kein Cover-Art verfügbar oder Widget nicht mehr mounted');
        
        if (mounted) {
          // Dialog anzeigen statt SnackBar
          _showNoCoverDialog(metadata);
        }
      }

      // Track-Metadaten laden
      final trackList = await musicBrainzService.getTrackList(
        metadata.musicBrainzReleaseId!,
        discNumber: metadata.discNumber,
      );

      if (mounted) {
        final cdInfoAsync = ref.read(cdInfoProvider);
        cdInfoAsync.whenData((cdInfo) {
          if (cdInfo != null) {
            for (
              int i = 0;
              i < trackList.length && i < cdInfo.tracks.length;
              i++
            ) {
              ref
                  .read(cdInfoProvider.notifier)
                  .updateTrackMetadata(i + 1, trackList[i]);
            }
          }
        });
      }
    }

    // Navigation zurück zur CD-Info-Seite (SnackBar wird bereits oben angezeigt)
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _showNoCoverDialog(CDMetadata metadata) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  GradientIcon(
                    icon: Icons.image_not_supported,
                    size: 32,
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.accentColor],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Kein Cover verfügbar',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Dieses Release hat kein Cover im MusicBrainz Cover Art Archive.\n\n'
                'Möchten Sie bei Google Bilder nach dem Cover suchen?',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Nein'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _openGoogleSearchAndShowUrlDialog(metadata);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                    ),
                    child: const Text('Ja'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openGoogleSearchAndShowUrlDialog(CDMetadata metadata) async {
    // Google Bildersuche öffnen
    final searchQuery = '${metadata.artist ?? ''} ${metadata.albumTitle ?? ''} album cover'
        .trim()
        .replaceAll(' ', '+');
    final googleUrl = 'https://www.google.com/search?tbm=isch&q=$searchQuery';
    
    debugPrint('Öffne Google Bildersuche: $googleUrl');
    
    // Versuche URL zu öffnen
    try {
      final uri = Uri.parse(googleUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Fehler beim Öffnen der URL: $e');
    }

    // Dialog für URL-Eingabe anzeigen
    if (mounted) {
      final controller = TextEditingController();
      final result = await showDialog<String>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      GradientIcon(
                        icon: Icons.link,
                        size: 32,
                        gradient: LinearGradient(
                          colors: [AppTheme.primaryColor, AppTheme.accentColor],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Cover-URL eingeben',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Rechtsklicken Sie auf das gewünschte Bild in Google und wählen Sie "Bildadresse kopieren".\n\n'
                    'Fügen Sie die URL hier ein:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Cover-URL',
                      hintText: 'https://...',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                    maxLines: 3,
                    autofocus: true,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(null),
                        child: const Text('Abbrechen'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          final url = controller.text.trim();
                          Navigator.of(context).pop(url.isEmpty ? null : url);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                        ),
                        child: const Text('Übernehmen'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Wenn URL eingegeben wurde, Metadaten aktualisieren
      if (result != null && result.isNotEmpty && mounted) {
        debugPrint('Cover-URL vom Benutzer eingegeben: $result');
        ref
            .read(cdInfoProvider.notifier)
            .updateMetadata(metadata.copyWith(coverArtUrl: result));
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cover-URL erfolgreich übernommen'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(musicBrainzSearchProvider);

    return AppScaffold(
      title: 'MusicBrainz Suche',
      currentRoute: '/search',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSearchByArtistAlbum(),
            const SizedBox(height: 24),
            _buildSearchByDiscId(),
            const SizedBox(height: 32),
            if (_isSearching) _buildLoadingIndicator(),
            if (!_isSearching) _buildResults(searchResults),
          ],
        ),
      ),
    );
  }


  Widget _buildSearchByArtistAlbum() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const GradientIcon(
                icon: Icons.search,
                size: 28,
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Suche nach Artist & Album',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _artistController,
            decoration: InputDecoration(
              labelText: 'Artist',
              hintText: 'z.B. Pink Floyd',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (_) => _searchByArtistAndAlbum(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _albumController,
            decoration: InputDecoration(
              labelText: 'Album',
              hintText: 'z.B. The Dark Side of the Moon',
              prefixIcon: const Icon(Icons.album),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (_) => _searchByArtistAndAlbum(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSearching ? null : _searchByArtistAndAlbum,
              icon: const Icon(Icons.search),
              label: const Text('Suchen'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchByDiscId() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const GradientIcon(
                icon: Icons.fingerprint,
                size: 28,
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Suche nach Disc-ID',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _discIdController,
            decoration: InputDecoration(
              labelText: 'Disc-ID',
              hintText: 'z.B. d30e6ad401778e06c3b0b8b51425',
              prefixIcon: const Icon(Icons.tag),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (_) => _searchByDiscId(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSearching ? null : _searchByDiscId,
              icon: const Icon(Icons.search),
              label: const Text('Suchen'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        children: [
          SizedBox(height: 32),
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Suche läuft...'),
        ],
      ),
    );
  }

  Widget _buildResults(AsyncValue<List<CDMetadata>> resultsAsync) {
    return resultsAsync.when(
      data: (results) {
        if (results.isEmpty) {
          return GlassCard(
            child: Column(
              children: [
                const Icon(Icons.search_off, size: 64, color: Colors.white54),
                const SizedBox(height: 16),
                Text(
                  'Keine Ergebnisse gefunden',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Die CD wurde nicht in der MusicBrainz-Datenbank gefunden.\n'
                  'Versuchen Sie es mit Artist/Album-Suche oder tragen Sie\n'
                  'die Metadaten manuell ein.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${results.length} Ergebnis${results.length != 1 ? 'se' : ''} gefunden',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...results.map((metadata) => _buildResultItem(metadata)),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => GlassCard(
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Fehler bei der Suche',
              style: TextStyle(
                fontSize: 18,
                color: Colors.red.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultItem(CDMetadata metadata) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showMetadataDetails(metadata),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              if (metadata.coverArtUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    metadata.coverArtUrl!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildPlaceholderCover(),
                  ),
                )
              else
                _buildPlaceholderCover(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metadata.albumTitle ?? 'Unbekanntes Album',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      metadata.artist ?? 'Unbekannter Artist',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    if (metadata.year != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        metadata.year.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderCover() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.album, size: 40, color: Colors.white54),
    );
  }

  void _showMetadataDetails(CDMetadata metadata) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.backgroundColor.withValues(alpha: 0.95),
              AppTheme.surfaceColor.withValues(alpha: 0.95),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (metadata.coverArtUrl != null)
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            metadata.coverArtUrl!,
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    _buildDetailRow('Album', metadata.albumTitle ?? 'N/A'),
                    _buildDetailRow('Artist', metadata.artist ?? 'N/A'),
                    if (metadata.year != null)
                      _buildDetailRow('Jahr', metadata.year.toString()),
                    if (metadata.genre != null)
                      _buildDetailRow('Genre', metadata.genre!),
                    if (metadata.label != null)
                      _buildDetailRow('Label', metadata.label!),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _applyMetadata(metadata);
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Metadaten übernehmen'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
