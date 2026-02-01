import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/cd_info.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/app_scaffold.dart';
import 'metadata_editor_screen.dart';
import 'export_screen.dart';
import 'settings_screen.dart';
import 'ripping_config_screen.dart';

class CDInfoScreen extends ConsumerStatefulWidget {
  const CDInfoScreen({super.key});

  @override
  ConsumerState<CDInfoScreen> createState() => _CDInfoScreenState();
}

class _CDInfoScreenState extends ConsumerState<CDInfoScreen> {
  @override
  void initState() {
    super.initState();
    // Automatisch nach CD suchen beim Laden des Screens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cdInfoProvider.notifier).checkForCD();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cdInfoAsync = ref.watch(cdInfoProvider);

    return AppScaffold(
      title: 'CD-Ripper',
      currentRoute: '/cd-ripper',
      body: cdInfoAsync.when(
        data: (cdInfo) {
          if (cdInfo == null) {
            return _buildNoCDView(context, ref);
          }
          return _buildCDInfoView(context, ref, cdInfo);
        },
        loading: () => _buildLoadingView(),
        error: (error, stack) => _buildErrorView(context, ref, error),
      ),
    );
  }

  Widget _buildNoCDView(BuildContext context, WidgetRef ref) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.album_outlined,
              size: 80,
              color: AppTheme.primaryColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            const Text(
              'Keine CD gefunden',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Legen Sie eine Audio-CD ein, um zu beginnen',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => ref.read(cdInfoProvider.notifier).refreshCD(),
              icon: const Icon(Icons.refresh),
              label: const Text('CD prüfen'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {

    return Center(
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Scanne CD...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: GlassCard(
        margin: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Fehler beim Scannen',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              error.toString(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.read(cdInfoProvider.notifier).refreshCD(),
              icon: const Icon(Icons.refresh),
              label: const Text('Erneut versuchen'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCDInfoView(BuildContext context, WidgetRef ref, CDInfo cdInfo) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(context, ref),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildCDHeader(context, ref, cdInfo),
              const SizedBox(height: 24),
              _buildCDStats(context, cdInfo),
              const SizedBox(height: 24),
              _buildMetadataSection(context, ref, cdInfo),
              const SizedBox(height: 24),
              _buildTracksList(context, ref, cdInfo),
              const SizedBox(height: 24),
              _buildActionButtons(context, ref, cdInfo),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context, WidgetRef ref) {
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.transparent,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
          tooltip: 'Menü öffnen',
        ),
      ),
      title: const Text(
        'CD Ripper',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.read(cdInfoProvider.notifier).refreshCD(),
          tooltip: 'CD neu scannen',
        ),
        IconButton(
          icon: const Icon(Icons.eject),
          onPressed: () => ref.read(cdInfoProvider.notifier).ejectCD(),
          tooltip: 'CD auswerfen',
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
          tooltip: 'Einstellungen',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildCDHeader(BuildContext context, WidgetRef ref, CDInfo cdInfo) {
    final hasMetadata =
        cdInfo.metadata != null && cdInfo.metadata?.albumTitle != null;

    return GlassCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: AppTheme.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: cdInfo.metadata?.coverArtUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          cdInfo.metadata!.coverArtUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildDefaultCoverArt(),
                        ),
                      )
                    : _buildDefaultCoverArt(),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cdInfo.metadata?.albumTitle ?? 'Unbekanntes Album',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      cdInfo.metadata?.artist ?? 'Unbekannter Künstler',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (cdInfo.metadata?.year != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            cdInfo.metadata!.year!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (!hasMetadata) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _fetchMusicBrainzMetadata(context, ref, cdInfo),
                    icon: const Icon(Icons.cloud_download, size: 20),
                    label: const Text('Metadaten abrufen'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MetadataEditorScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit, size: 20),
                  label: const Text('Bearbeiten'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _fetchMusicBrainzMetadata(
    BuildContext context,
    WidgetRef ref,
    CDInfo cdInfo,
  ) async {
    // Zeige Loading-Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Material(
          type: MaterialType.transparency,
          child: GlassCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              const GradientIcon(
                icon: Icons.cloud_sync,
                size: 80,
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Suche bei MusicBrainz...',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Metadaten werden geladen',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );

    try {
      final musicBrainzService = ref.read(musicBrainzServiceProvider);

      // Suche nach Disc-ID
      final results = await musicBrainzService.searchByDiscId(cdInfo.discId);

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine Ergebnisse gefunden. Bitte manuell suchen.'),
            duration: Duration(seconds: 3),
          ),
        );
        // Öffne Metadaten-Editor für manuelle Suche
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MetadataEditorScreen()),
        );
      } else if (results.length == 1) {
        // Automatisch übernehmen wenn nur ein Ergebnis
        final metadata = results.first;
        ref.read(cdInfoProvider.notifier).updateMetadata(metadata);

        // Lade Cover-Art
        if (metadata.musicBrainzReleaseId != null) {
          final coverArt = await musicBrainzService.getCoverArt(
            metadata.musicBrainzReleaseId!,
          );
          if (coverArt != null) {
            ref
                .read(cdInfoProvider.notifier)
                .updateMetadata(metadata.copyWith(coverArtUrl: coverArt));
          } else {
            // Versuche Google-Suche als Fallback
            if (context.mounted) {
              _searchCoverOnGoogle(context, metadata);
            }
          }
        }

        // Lade Track-Metadaten
        if (metadata.musicBrainzReleaseId != null) {
          final trackList = await musicBrainzService.getTrackList(
            metadata.musicBrainzReleaseId!,
            discNumber: metadata.discNumber,
          );
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

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Metadaten erfolgreich geladen!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Mehrere Ergebnisse - öffne Auswahl-Dialog
        _showMetadataSelectionDialog(context, ref, results, cdInfo);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showMetadataSelectionDialog(
    BuildContext context,
    WidgetRef ref,
    List<CDMetadata> results,
    CDInfo cdInfo,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Album auswählen',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 500,
                height: 400,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final metadata = results[index];
                    return _MetadataResultTile(
                      metadata: metadata,
                      onSelected: (updatedMetadata) async {
                        Navigator.pop(context);
                        ref
                            .read(cdInfoProvider.notifier)
                            .updateMetadata(updatedMetadata);

                        // Lade Tracks
                        final musicBrainzService = ref.read(
                          musicBrainzServiceProvider,
                        );

                        // Wenn Cover noch nicht geladen wurde (oder fehlschlug), versuche es hier nochmal
                        if (updatedMetadata.coverArtUrl == null &&
                            updatedMetadata.musicBrainzReleaseId != null) {
                          try {
                            final coverArt = await musicBrainzService.getCoverArt(
                              updatedMetadata.musicBrainzReleaseId!,
                            );
                            if (coverArt != null) {
                              ref
                                  .read(cdInfoProvider.notifier)
                                  .updateMetadata(
                                    updatedMetadata.copyWith(
                                      coverArtUrl: coverArt,
                                    ),
                                  );
                            }
                          } catch (_) {
                            // Ignore
                          }
                        }

                        if (updatedMetadata.musicBrainzReleaseId != null) {
                          try {
                            final trackList = await musicBrainzService
                                .getTrackList(
                                  updatedMetadata.musicBrainzReleaseId!,
                                  discNumber: updatedMetadata.discNumber,
                                );
                            for (
                              int i = 0;
                              i < trackList.length && i < cdInfo.tracks.length;
                              i++
                            ) {
                              ref
                                  .read(cdInfoProvider.notifier)
                                  .updateTrackMetadata(i + 1, trackList[i]);
                            }
                          } catch (_) {
                            // Ignore
                          }
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Metadaten übernommen!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Abbrechen'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _searchCoverOnGoogle(BuildContext context, CDMetadata metadata) async {
    if (metadata.artist == null || metadata.albumTitle == null) return;

    final query = '${metadata.artist} ${metadata.albumTitle} album cover';
    final uri = Uri.https('www.google.com', '/search', {
      'tbm': 'isch',
      'q': query,
    });

    // Dialog anzeigen statt SnackBar
    final shouldSearch = await showDialog<bool>(
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
                'Kein Cover im MusicBrainz Archive gefunden.\n\n'
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
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Nein'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
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

    if (shouldSearch == true && context.mounted) {
      // Google Bildersuche öffnen
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        debugPrint('Fehler beim Öffnen der Google-Suche: $e');
      }

      // URL-Eingabedialog anzeigen
      if (context.mounted) {
        final controller = TextEditingController();
        final coverUrl = await showDialog<String>(
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

        // Cover-URL übernehmen
        if (coverUrl != null && coverUrl.isNotEmpty && context.mounted) {
          ref
              .read(cdInfoProvider.notifier)
              .updateMetadata(metadata.copyWith(coverArtUrl: coverUrl));

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
  }

  Widget _buildDefaultCoverArt() {
    return const Center(
      child: Icon(Icons.album, size: 60, color: Colors.white),
    );
  }

  Widget _buildCDStats(BuildContext context, CDInfo cdInfo) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.library_music,
            label: 'Tracks',
            value: '${cdInfo.tracks.length}',
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            icon: Icons.access_time,
            label: 'Dauer',
            value: _formatDuration(cdInfo.totalDuration),
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Tooltip(
            message: 'Klicken zum Kopieren: ${cdInfo.discId}',
            child: _buildStatCard(
              icon: Icons.fingerprint,
              label: 'Disc ID',
              value: cdInfo.discId.length > 28 
                  ? '${cdInfo.discId.substring(0, 12)}...' 
                  : cdInfo.discId,
              gradient: const LinearGradient(
                colors: [Color(0xFFA855F7), Color(0xFFEC4899)],
              ),
              onTap: () {
                Clipboard.setData(ClipboardData(text: cdInfo.discId));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Disc ID in die Zwischenablage kopiert'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Gradient gradient,
    VoidCallback? onTap,
  }) {
    final card = GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: card,
        ),
      );
    }

    return card;
  }

  Widget _buildMetadataSection(
    BuildContext context,
    WidgetRef ref,
    CDInfo cdInfo,
  ) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Metadaten',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MetadataEditorScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (cdInfo.metadata?.genre != null)
            _buildMetadataRow('Genre', cdInfo.metadata!.genre!),
          if (cdInfo.metadata?.label != null)
            _buildMetadataRow('Label', cdInfo.metadata!.label!),
          if (cdInfo.metadata?.catalogNumber != null)
            _buildMetadataRow('Katalog-Nr.', cdInfo.metadata!.catalogNumber!),
          if (cdInfo.metadata?.barcode != null)
            _buildMetadataRow('Barcode', cdInfo.metadata!.barcode!),
          _buildMetadataRow(
            'Disc ID', 
            cdInfo.discId,
            onTap: () {
              Clipboard.setData(ClipboardData(text: cdInfo.discId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Disc ID in die Zwischenablage kopiert'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          if (cdInfo.freedbId != null)
            _buildMetadataRow('FreeDB ID', cdInfo.freedbId!),
          if (cdInfo.devicePath != null)
            _buildMetadataRow('Gerät', cdInfo.devicePath!),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value, {VoidCallback? onTap}) {
    Widget row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onTap != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.copy,
                size: 14,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
        ],
      ),
    );

    if (onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: row,
        ),
      );
    }

    return row;
  }

  Widget _buildTracksList(BuildContext context, WidgetRef ref, CDInfo cdInfo) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tracks',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...cdInfo.tracks.map((track) => _buildTrackItem(context, ref, track)),
        ],
      ),
    );
  }

  Widget _buildTrackItem(BuildContext context, WidgetRef ref, Track track) {
    final selectedTracks = ref.watch(selectedTracksProvider);
    final isSelected = selectedTracks.contains(track.number);

    return InkWell(
      onTap: () {
        final notifier = ref.read(selectedTracksProvider.notifier);
        notifier.toggleTrack(track.number);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: isSelected ? AppTheme.primaryGradient : null,
                color: isSelected ? null : AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  track.number.toString(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.metadata?.title ?? 'Track ${track.number}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (track.metadata?.artist != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      track.metadata!.artist!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatDuration(track.duration),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (track.ripStatus != RipStatus.notStarted) ...[
                  const SizedBox(height: 4),
                  _buildRipStatusIndicator(track),
                ],
              ],
            ),
            if (track.ripStatus == RipStatus.ripping &&
                track.ripProgress != null) ...[
              const SizedBox(width: 12),
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  value: track.ripProgress,
                  strokeWidth: 3,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRipStatusIndicator(Track track) {
    switch (track.ripStatus) {
      case RipStatus.ripping:
        return const Row(
          children: [
            PulsingDot(color: AppTheme.primaryColor, size: 8),
            SizedBox(width: 4),
            Text('Wird gerippt...', style: TextStyle(fontSize: 12)),
          ],
        );
      case RipStatus.completed:
        return Row(
          children: [
            Icon(Icons.check_circle, size: 16, color: Colors.green[400]),
            const SizedBox(width: 4),
            const Text('Fertig', style: TextStyle(fontSize: 12)),
          ],
        );
      case RipStatus.error:
        return Row(
          children: [
            Icon(Icons.error, size: 16, color: Colors.red[400]),
            const SizedBox(width: 4),
            const Text('Fehler', style: TextStyle(fontSize: 12)),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    CDInfo cdInfo,
  ) {
    final selectedTracks = ref.watch(selectedTracksProvider);
    final isRipping = ref.watch(isRippingProvider);

    return Column(
      children: [
        // Ripping-Button (Hauptaktion)
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RippingConfigScreen(cdInfo: cdInfo),
                ),
              );
            },
            icon: const Icon(Icons.album, size: 28),
            label: const Text(
              'CD rippen',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Legacy Export-Button
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: selectedTracks.isEmpty
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ExportScreen(),
                          ),
                        );
                      },
                icon: const Icon(Icons.download),
                label: Text(
                  selectedTracks.isEmpty
                      ? 'Wähle Tracks'
                      : '${selectedTracks.length} Track${selectedTracks.length > 1 ? 's' : ''} exportieren (Alt)',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
              ),
            ),
            if (selectedTracks.isEmpty) ...[
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: isRipping
                    ? null
                    : () {
                        final notifier = ref.read(
                          selectedTracksProvider.notifier,
                        );
                        notifier.selectAll(
                          cdInfo.tracks.map((t) => t.number).toList(),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                ),
                child: const Text('Alle auswählen'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _MetadataResultTile extends ConsumerStatefulWidget {
  final CDMetadata metadata;
  final Function(CDMetadata) onSelected;

  const _MetadataResultTile({
    required this.metadata,
    required this.onSelected,
  });

  @override
  ConsumerState<_MetadataResultTile> createState() => _MetadataResultTileState();
}

class _MetadataResultTileState extends ConsumerState<_MetadataResultTile> {
  String? _coverArtUrl;
  bool _isLoadingCover = false;

  @override
  void initState() {
    super.initState();
    _loadCoverArt();
  }

  Future<void> _loadCoverArt() async {
    if (widget.metadata.coverArtUrl != null) {
      if (mounted) setState(() => _coverArtUrl = widget.metadata.coverArtUrl);
      return;
    }

    if (widget.metadata.musicBrainzReleaseId == null) return;

    if (mounted) setState(() => _isLoadingCover = true);

    try {
      final url = await ref.read(musicBrainzServiceProvider).getCoverArt(
            widget.metadata.musicBrainzReleaseId!,
          );
      if (mounted && url != null) {
        setState(() => _coverArtUrl = url);
      }
    } catch (_) {
      // Ignore errors
    } finally {
      if (mounted) setState(() => _isLoadingCover = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        final updatedMetadata = widget.metadata.copyWith(
          coverArtUrl: _coverArtUrl,
        );
        widget.onSelected(updatedMetadata);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _coverArtUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _coverArtUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.album),
                      ),
                    )
                  : _isLoadingCover
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.album),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.metadata.albumTitle ?? 'Unbekanntes Album',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.metadata.artist ?? 'Unbekannter Künstler',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.metadata.year != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${widget.metadata.year} • ${widget.metadata.label ?? ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
