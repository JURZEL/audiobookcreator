import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../models/audiobook_project.dart';
import '../providers/audiobook_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_widgets.dart'; // Still used for GlassCard (now flat)
import '../widgets/app_scaffold.dart';

class TagEditorScreen extends ConsumerStatefulWidget {
  const TagEditorScreen({super.key});

  @override
  ConsumerState<TagEditorScreen> createState() => _TagEditorScreenState();
}

class _TagEditorScreenState extends ConsumerState<TagEditorScreen> {
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _albumController = TextEditingController();
  final _albumArtistController = TextEditingController();
  final _authorController = TextEditingController();
  final _narratorController = TextEditingController();
  final _genreController = TextEditingController();
  final _yearController = TextEditingController();
  final _trackController = TextEditingController();
  final _discController = TextEditingController();
  final _commentController = TextEditingController();

  String? _selectedPath;
  AudioFile? _loadedFile;
  String? _coverPath;
  bool _removeCover = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _albumArtistController.dispose();
    _authorController.dispose();
    _narratorController.dispose();
    _genreController.dispose();
    _yearController.dispose();
    _trackController.dispose();
    _discController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'mp3',
        'm4a',
        'm4b',
        'aac',
        'flac',
        'ogg',
        'opus',
        'wav',
        'wma',
        'ape',
        'alac',
        'mkv',
        'mp4',
      ],
    );

    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    final service = ref.read(audiobookServiceProvider);
    final audioFile = await service.readMetadataFromFile(path);

    if (audioFile == null) {
      if (mounted) {
        _showSnack('Metadaten konnten nicht gelesen werden.', Colors.red);
      }
      return;
    }

    if (!mounted) return;

    setState(() {
      _selectedPath = path;
      _loadedFile = audioFile;
      _coverPath = audioFile.coverArtPath;
      _removeCover = false;
    });
    _prefillControllers(audioFile);
    _showSnack('Metadaten geladen. Bearbeiten und speichern moglich.', Colors.green);
  }

  void _prefillControllers(AudioFile file) {
    _titleController.text = file.title ?? '';
    _artistController.text = file.artist ?? '';
    _albumController.text = file.album ?? '';
    _albumArtistController.text = file.albumArtist ?? file.artist ?? '';
    _authorController.text = file.author ?? file.artist ?? '';
    _narratorController.text = file.narrator ?? '';
    _genreController.text = file.genre ?? '';
    _yearController.text = file.year ?? '';
    _commentController.text = file.comment ?? '';
    _trackController.text = file.trackNumber?.toString() ?? '';
    _discController.text = file.discNumber?.toString() ?? '';
    _coverPath = file.coverArtPath;
    _removeCover = false;
  }

  int? _parseInt(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  String? _nonEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _saveTags() async {
    if (_selectedPath == null) {
      _showSnack('Bitte zuerst eine Datei laden.', Colors.orange);
      return;
    }

    setState(() => _isSaving = true);

    final service = ref.read(audiobookServiceProvider);
    final updated = await service.writeMetadataToFile(
      filePath: _selectedPath!,
      title: _nonEmpty(_titleController.text),
      artist: _nonEmpty(_artistController.text),
      album: _nonEmpty(_albumController.text),
      albumArtist: _nonEmpty(_albumArtistController.text),
      author: _nonEmpty(_authorController.text),
      narrator: _nonEmpty(_narratorController.text),
      genre: _nonEmpty(_genreController.text),
      year: _nonEmpty(_yearController.text),
      comment: _nonEmpty(_commentController.text),
      coverArtPath: _coverPath,
      removeCover: _removeCover && _coverPath == null,
      trackNumber: _parseInt(_trackController.text),
      discNumber: _parseInt(_discController.text),
    );

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (updated != null) {
      setState(() {
        _loadedFile = updated;
      });
      _prefillControllers(updated);
      _showSnack('Metadaten gespeichert.', Colors.green);
    } else {
      _showSnack('Metadaten konnten nicht geschrieben werden.', Colors.red);
    }
  }

  Future<void> _pickCover() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
    );

    if (result == null || result.files.single.path == null) return;

    setState(() {
      _coverPath = result.files.single.path!;
      _removeCover = false;
    });
  }

  void _clearCover() {
    setState(() {
      _coverPath = null;
      _removeCover = true;
    });
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Tag-Editor',
      currentRoute: '/tag-editor',
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveTags,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save, size: 18),
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
            _buildFileSelector(),
            const SizedBox(height: 20),
            _buildCoverEditor(),
            const SizedBox(height: 20),
            _buildForm(),
          ],
        ),
      ),
    );
  }


  Widget _buildFileSelector() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const GradientIcon(
                icon: Icons.folder_open,
                size: 28,
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Audiodatei laden',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _pickFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Datei wahlen'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_selectedPath != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.basename(_selectedPath!)),
                const SizedBox(height: 4),
                Text(
                  _selectedPath!,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                ),
                if (_loadedFile != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        if (_loadedFile!.duration.inSeconds > 0)
                          _buildInfoChip(
                            Icons.schedule,
                            _formatDuration(_loadedFile!.duration),
                          ),
                        if (_loadedFile!.trackNumber != null)
                          _buildInfoChip(
                            Icons.confirmation_number,
                            'Track ${_loadedFile!.trackNumber}',
                          ),
                        if (_loadedFile!.discNumber != null)
                          _buildInfoChip(
                            Icons.album,
                            'Disc ${_loadedFile!.discNumber}',
                          ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

    Widget _buildCoverEditor() {
      return GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const GradientIcon(
                  icon: Icons.image,
                  size: 28,
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.accentColor],
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Cover bearbeiten',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _pickCover,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Cover wahlen'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _clearCover,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Cover entfernen'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_coverPath != null && File(_coverPath!).existsSync())
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_coverPath!),
                  height: 220,
                  fit: BoxFit.cover,
                ),
              )
            else if (!_removeCover && _loadedFile?.coverArtPath != null && File(_loadedFile!.coverArtPath!).existsSync())
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_loadedFile!.coverArtPath!),
                  height: 220,
                  fit: BoxFit.cover,
                ),
              )
            else
              Text(
                _removeCover
                    ? 'Cover wird entfernt. Du kannst ein neues Bild hinzufugen.'
                    : 'Kein Cover gefunden. Du kannst ein neues Bild hinzufugen.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
          ],
        ),
      );
    }

  Widget _buildForm() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const GradientIcon(
                icon: Icons.edit,
                size: 28,
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Metadaten bearbeiten',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(controller: _titleController, label: 'Titel', icon: Icons.music_note),
          const SizedBox(height: 12),
          _buildTextField(controller: _artistController, label: 'Artist', icon: Icons.person),
          const SizedBox(height: 12),
          _buildTextField(controller: _albumController, label: 'Album', icon: Icons.album),
          const SizedBox(height: 12),
          _buildTextField(controller: _albumArtistController, label: 'Album-Artist / Autor', icon: Icons.group),
          const SizedBox(height: 12),
          _buildTextField(controller: _authorController, label: 'Autor', icon: Icons.edit_note),
          const SizedBox(height: 12),
          _buildTextField(controller: _narratorController, label: 'Sprecher/Narrator', icon: Icons.record_voice_over),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _trackController,
                  label: 'Track-Nummer',
                  icon: Icons.confirmation_number,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _discController,
                  label: 'Disc-Nummer',
                  icon: Icons.album_outlined,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _genreController,
                  label: 'Genre',
                  icon: Icons.category,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _yearController,
                  label: 'Jahr',
                  icon: Icons.calendar_today,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _commentController,
            label: 'Kommentar/Beschreibung',
            icon: Icons.notes,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveTags,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Speichern...' : 'Metadaten speichern'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      final mins = minutes.remainder(60).toString().padLeft(2, '0');
      return '$hours:$mins:$seconds';
    }
    return '$minutes:$seconds';
  }
}
