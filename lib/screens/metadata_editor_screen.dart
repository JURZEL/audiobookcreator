import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../models/cd_info.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/app_scaffold.dart';

class MetadataEditorScreen extends ConsumerStatefulWidget {
  const MetadataEditorScreen({super.key});

  @override
  ConsumerState<MetadataEditorScreen> createState() =>
      _MetadataEditorScreenState();
}

class _MetadataEditorScreenState extends ConsumerState<MetadataEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _artistController = TextEditingController();
  final _albumController = TextEditingController();
  final _yearController = TextEditingController();
  final _genreController = TextEditingController();
  final _labelController = TextEditingController();
  final _catalogController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _coverUrlController = TextEditingController();
  final _discNumberController = TextEditingController();
  final _authorController = TextEditingController();
  final _narratorController = TextEditingController();
  final _publisherController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _languageController = TextEditingController();
  final _copyrightController = TextEditingController();
  final _commentController = TextEditingController();
  final _seriesController = TextEditingController();
  final _seriesPartController = TextEditingController();

  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentMetadata();
    });
  }

  void _loadCurrentMetadata() {
    final cdInfoAsync = ref.read(cdInfoProvider);
    cdInfoAsync.whenData((cdInfo) {
      if (cdInfo?.metadata != null) {
        final metadata = cdInfo!.metadata!;
        _artistController.text = metadata.artist ?? '';
        _albumController.text = metadata.albumTitle ?? '';
        _yearController.text = metadata.year ?? '';
        _genreController.text = metadata.genre ?? '';
        _labelController.text = metadata.label ?? '';
        _catalogController.text = metadata.catalogNumber ?? '';
        _barcodeController.text = metadata.barcode ?? '';
        _coverUrlController.text = metadata.coverArtUrl ?? '';
        _discNumberController.text = metadata.discNumber?.toString() ?? '';
        _authorController.text = metadata.author ?? '';
        _narratorController.text = metadata.narrator ?? '';
        _publisherController.text = metadata.publisher ?? '';
        _descriptionController.text = metadata.description ?? '';
        _languageController.text = metadata.language ?? '';
        _copyrightController.text = metadata.copyright ?? '';
        _commentController.text = metadata.comment ?? '';
        _seriesController.text = metadata.series ?? '';
        _seriesPartController.text = metadata.seriesPart ?? '';
      }
    });
  }

  @override
  void dispose() {
    _artistController.dispose();
    _albumController.dispose();
    _yearController.dispose();
    _genreController.dispose();
    _labelController.dispose();
    _catalogController.dispose();
    _barcodeController.dispose();
    _coverUrlController.dispose();
    _discNumberController.dispose();
    _authorController.dispose();
    _narratorController.dispose();
    _publisherController.dispose();
    _descriptionController.dispose();
    _languageController.dispose();
    _copyrightController.dispose();
    _commentController.dispose();
    _seriesController.dispose();
    _seriesPartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final musicBrainzResults = ref.watch(musicBrainzSearchProvider);

    return AppScaffold(
      title: 'Metadaten bearbeiten',
      currentRoute: '/cd-ripper', // It is a sub-screen of CD Ripper
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ElevatedButton.icon(
            onPressed: _saveMetadata,
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Speichern'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              elevation: 0,
            ),
          ),
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSearchSection(),
            const SizedBox(height: 24),
            if (_isSearching)
              _buildSearchResults(musicBrainzResults)
            else
              _buildMetadataForm(),
            const SizedBox(height: 24),
            _buildTrackMetadataSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const GradientIcon(
                icon: Icons.search,
                size: 32,
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'MusicBrainz Suche',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              if (_isSearching)
                TextButton(
                  onPressed: () {
                    setState(() => _isSearching = false);
                    ref.read(musicBrainzSearchProvider.notifier).clear();
                  },
                  child: const Text('Abbrechen'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_isSearching) ...[
            ElevatedButton.icon(
              onPressed: _searchByDiscId,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Nach Disc-ID suchen'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _artistController,
                    decoration: const InputDecoration(
                      labelText: 'Künstler',
                      hintText: 'z.B. The Beatles',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _albumController,
                    decoration: const InputDecoration(
                      labelText: 'Album',
                      hintText: 'z.B. Abbey Road',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _searchByArtistAndAlbum,
              icon: const Icon(Icons.search),
              label: const Text('Nach Künstler & Album suchen'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchResults(AsyncValue<List<CDMetadata>> results) {
    return results.when(
      data: (metadataList) {
        if (metadataList.isEmpty) {
          return GlassCard(
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.search_off,
                    size: 48,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Keine Ergebnisse gefunden',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${metadataList.length} Ergebnis${metadataList.length > 1 ? 'se' : ''}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...metadataList.map(
                (metadata) => _MetadataResultTile(
                  metadata: metadata,
                  onSelected: _applyMetadata,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => GlassCard(
        child: Center(
          child: Column(
            children: [
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 16),
              Text(
                'Suche in MusicBrainz...',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      ),
      error: (error, stack) => GlassCard(
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Fehler: $error',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataForm() {
    return GlassCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Album-Informationen',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _artistController,
              decoration: const InputDecoration(
                labelText: 'Künstler',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _albumController,
              decoration: const InputDecoration(
                labelText: 'Album',
                prefixIcon: Icon(Icons.album),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _yearController,
                    decoration: const InputDecoration(
                      labelText: 'Jahr',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _genreController,
                    decoration: const InputDecoration(
                      labelText: 'Genre',
                      prefixIcon: Icon(Icons.music_note),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Label',
                prefixIcon: Icon(Icons.business),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _catalogController,
                    decoration: const InputDecoration(
                      labelText: 'Katalog-Nr.',
                      prefixIcon: Icon(Icons.tag),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _barcodeController,
                    decoration: const InputDecoration(
                      labelText: 'Barcode',
                      prefixIcon: Icon(Icons.qr_code),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _coverUrlController,
                  decoration: InputDecoration(
                    labelText: 'Cover-Art',
                    prefixIcon: const Icon(Icons.image),
                    helperText: 'URL oder lokaler Dateipfad zum Cover-Bild',
                    suffixIcon: _coverUrlController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.preview),
                            tooltip: 'Vorschau anzeigen',
                            onPressed: () => _showCoverPreview(),
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickLocalCoverImage,
                        icon: const Icon(Icons.folder_open, size: 20),
                        label: const Text('Lokale Datei wählen'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Colors.cyan.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _coverUrlController.text.isNotEmpty
                            ? () {
                                _coverUrlController.clear();
                                setState(() {});
                              }
                            : null,
                        icon: const Icon(Icons.clear, size: 20),
                        label: const Text('Löschen'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Colors.red.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _discNumberController,
              decoration: const InputDecoration(
                labelText: 'Disc-Nummer',
                prefixIcon: Icon(Icons.numbers),
                helperText: 'Bei Multi-Disc-Sets (z.B. 1, 2, 3...)',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            ExpansionTile(
              title: const Text(
                'Erweiterte Metadaten (Audiobooks/Hörspiele)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              children: [
                const SizedBox(height: 16),
                TextField(
                  controller: _authorController,
                  decoration: const InputDecoration(
                    labelText: 'Autor',
                    prefixIcon: Icon(Icons.edit),
                    helperText: 'Autor des Werks (bei Audiobooks)',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _narratorController,
                  decoration: const InputDecoration(
                    labelText: 'Sprecher/Erzähler',
                    prefixIcon: Icon(Icons.mic),
                    helperText: 'Vorleser oder Sprecher',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _publisherController,
                  decoration: const InputDecoration(
                    labelText: 'Verlag/Publisher',
                    prefixIcon: Icon(Icons.business),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _languageController,
                  decoration: const InputDecoration(
                    labelText: 'Sprache',
                    prefixIcon: Icon(Icons.language),
                    helperText: 'z.B. "de", "en", "fr"',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _seriesController,
                        decoration: const InputDecoration(
                          labelText: 'Reihe/Serie',
                          prefixIcon: Icon(Icons.library_books),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _seriesPartController,
                        decoration: const InputDecoration(
                          labelText: 'Teil',
                          prefixIcon: Icon(Icons.looks_one),
                          helperText: 'z.B. "1", "2"',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Beschreibung',
                    prefixIcon: Icon(Icons.description),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _copyrightController,
                  decoration: const InputDecoration(
                    labelText: 'Copyright',
                    prefixIcon: Icon(Icons.copyright),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    labelText: 'Kommentar',
                    prefixIcon: Icon(Icons.comment),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCoverPreview() {
    if (_coverUrlController.text.isEmpty) return;

    final coverPath = _coverUrlController.text;
    final isLocalFile =
        !coverPath.startsWith('http://') && !coverPath.startsWith('https://');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Cover-Vorschau'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: isLocalFile
                  ? Image.file(
                      File(coverPath),
                      errorBuilder: (context, error, stackTrace) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.error, size: 64, color: Colors.red),
                              SizedBox(height: 16),
                              Text('Cover konnte nicht geladen werden'),
                            ],
                          ),
                        );
                      },
                    )
                  : Image.network(
                      coverPath,
                      errorBuilder: (context, error, stackTrace) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.error, size: 64, color: Colors.red),
                              SizedBox(height: 16),
                              Text('Cover konnte nicht geladen werden'),
                            ],
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackMetadataSection() {
    final cdInfoAsync = ref.watch(cdInfoProvider);

    return cdInfoAsync.when(
      data: (cdInfo) {
        if (cdInfo == null) return const SizedBox.shrink();

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Track-Metadaten',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...cdInfo.tracks.map((track) => _TrackMetadataItem(track: track)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _fetchTrackMetadata(cdInfo),
                icon: const Icon(Icons.download),
                label: const Text('Track-Infos von MusicBrainz laden'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }



  Future<void> _searchByDiscId() async {
    final cdInfoAsync = ref.read(cdInfoProvider);
    cdInfoAsync.whenData((cdInfo) async {
      if (cdInfo != null) {
        setState(() => _isSearching = true);
        await ref
            .read(musicBrainzSearchProvider.notifier)
            .searchByDiscId(cdInfo.discId);
      }
    });
  }

  Future<void> _searchByArtistAndAlbum() async {
    final artist = _artistController.text.trim();
    final album = _albumController.text.trim();

    if (artist.isEmpty && album.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte geben Sie mindestens Künstler oder Album ein'),
        ),
      );
      return;
    }

    setState(() => _isSearching = true);

    if (artist.isNotEmpty && album.isNotEmpty) {
      await ref
          .read(musicBrainzSearchProvider.notifier)
          .searchByArtistAndAlbum(artist, album);
    } else {
      await ref
          .read(musicBrainzSearchProvider.notifier)
          .fuzzySearch('$artist $album');
    }
  }

  void _applyMetadata(CDMetadata metadata) async {
    setState(() => _isSearching = false);

    _artistController.text = metadata.artist ?? '';
    _albumController.text = metadata.albumTitle ?? '';
    _yearController.text = metadata.year ?? '';
    _genreController.text = metadata.genre ?? '';
    _labelController.text = metadata.label ?? '';
    _catalogController.text = metadata.catalogNumber ?? '';
    _barcodeController.text = metadata.barcode ?? '';
    _coverUrlController.text = metadata.coverArtUrl ?? '';

    ref.read(cdInfoProvider.notifier).updateMetadata(metadata);

    // Cover-Art laden falls noch nicht vorhanden
    if (metadata.coverArtUrl == null && metadata.musicBrainzReleaseId != null) {
      final musicBrainzService = ref.read(musicBrainzServiceProvider);
      try {
        final coverArt = await musicBrainzService.getCoverArt(
          metadata.musicBrainzReleaseId!,
        );

        if (coverArt != null) {
          final updatedMetadata = metadata.copyWith(coverArtUrl: coverArt);
          ref.read(cdInfoProvider.notifier).updateMetadata(updatedMetadata);
          
          if (mounted) {
            setState(() {
              _coverUrlController.text = coverArt;
            });
          }
        }
      } catch (_) {
        // Ignore errors
      }
    }

    ref.read(musicBrainzSearchProvider.notifier).clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Metadaten übernommen'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pickLocalCoverImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _coverUrlController.text = result.files.single.path!;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cover-Bild ausgewählt'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Auswählen der Datei: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchTrackMetadata(CDInfo cdInfo) async {
    if (cdInfo.metadata?.musicBrainzReleaseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte zuerst Album-Metadaten von MusicBrainz laden'),
        ),
      );
      return;
    }

    try {
      // Verwende die aktuell eingegebene Disc-Nummer aus dem Textfeld
      final discNumber = _discNumberController.text.isEmpty
          ? null
          : int.tryParse(_discNumberController.text);

      final musicBrainzService = ref.read(musicBrainzServiceProvider);
      final trackList = await musicBrainzService.getTrackList(
        cdInfo.metadata!.musicBrainzReleaseId!,
        discNumber: discNumber,
      );

      for (int i = 0; i < trackList.length && i < cdInfo.tracks.length; i++) {
        ref
            .read(cdInfoProvider.notifier)
            .updateTrackMetadata(i + 1, trackList[i]);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              discNumber != null
                  ? 'Track-Metadaten von CD $discNumber geladen'
                  : 'Track-Metadaten geladen',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Laden: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _saveMetadata() {
    final metadata = CDMetadata(
      artist: _artistController.text.isEmpty ? null : _artistController.text,
      albumTitle: _albumController.text.isEmpty ? null : _albumController.text,
      year: _yearController.text.isEmpty ? null : _yearController.text,
      genre: _genreController.text.isEmpty ? null : _genreController.text,
      label: _labelController.text.isEmpty ? null : _labelController.text,
      catalogNumber: _catalogController.text.isEmpty
          ? null
          : _catalogController.text,
      barcode: _barcodeController.text.isEmpty ? null : _barcodeController.text,
      coverArtUrl: _coverUrlController.text.isEmpty
          ? null
          : _coverUrlController.text,
      discNumber: _discNumberController.text.isEmpty
          ? null
          : int.tryParse(_discNumberController.text),
      author: _authorController.text.isEmpty ? null : _authorController.text,
      narrator: _narratorController.text.isEmpty
          ? null
          : _narratorController.text,
      publisher: _publisherController.text.isEmpty
          ? null
          : _publisherController.text,
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
      language: _languageController.text.isEmpty
          ? null
          : _languageController.text,
      copyright: _copyrightController.text.isEmpty
          ? null
          : _copyrightController.text,
      comment: _commentController.text.isEmpty ? null : _commentController.text,
      series: _seriesController.text.isEmpty ? null : _seriesController.text,
      seriesPart: _seriesPartController.text.isEmpty
          ? null
          : _seriesPartController.text,
    );

    ref.read(cdInfoProvider.notifier).updateMetadata(metadata);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Metadaten gespeichert'),
        duration: Duration(seconds: 2),
      ),
    );

    Navigator.pop(context);
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
              width: 60,
              height: 60,
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
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.album, size: 32),
                      ),
                    )
                  : _isLoadingCover
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.album, size: 32),
            ),
            const SizedBox(width: 16),
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

class _TrackMetadataItem extends ConsumerStatefulWidget {
  final Track track;

  const _TrackMetadataItem({
    required this.track,
  });

  @override
  ConsumerState<_TrackMetadataItem> createState() => _TrackMetadataItemState();
}

class _TrackMetadataItemState extends ConsumerState<_TrackMetadataItem> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.track.metadata?.title ?? '',
    );
  }

  @override
  void didUpdateWidget(_TrackMetadataItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newTitle = widget.track.metadata?.title ?? '';
    if (_controller.text != newTitle) {
      _controller.value = _controller.value.copyWith(
        text: newTitle,
        selection: TextSelection.collapsed(offset: newTitle.length),
        composing: TextRange.empty,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    widget.track.number.toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Titel',
                    isDense: true,
                  ),
                  controller: _controller,
                  onChanged: (value) {
                    final metadata =
                        widget.track.metadata?.copyWith(title: value) ??
                        TrackMetadata(title: value);
                    ref
                        .read(cdInfoProvider.notifier)
                        .updateTrackMetadata(widget.track.number, metadata);
                  },
                ),
              ),
            ],
          ),
          if (widget.track.metadata?.artist != null ||
              widget.track.metadata?.isrc != null) ...[
            const SizedBox(height: 8),
            Text(
              'Artist: ${widget.track.metadata?.artist ?? '-'} | ISRC: ${widget.track.metadata?.isrc ?? '-'}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
