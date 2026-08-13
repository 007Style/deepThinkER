// CustomCharacterEditor — create / edit / delete custom character profiles.
import 'package:flutter/material.dart';

import '../../core/persona/custom_character.dart';
import '../widgets/app_theme.dart';

// ---------------------------------------------------------------------------
// CustomCharacterEditor
// ---------------------------------------------------------------------------

/// Screen for creating and managing custom AI characters.
class CustomCharacterEditor extends StatefulWidget {
  const CustomCharacterEditor({super.key});

  @override
  State<CustomCharacterEditor> createState() => _CustomCharacterEditorState();
}

class _CustomCharacterEditorState extends State<CustomCharacterEditor> {
  List<CustomCharacter> _characters = [];
  int? _editingIndex;

  // Form controllers
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _promptCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final chars = await CustomCharacter.loadAll();
    if (mounted) setState(() => _characters = chars);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _promptCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  void _startNew() {
    setState(() {
      _editingIndex = null;
      _nameCtrl.clear();
      _descCtrl.clear();
      _promptCtrl.clear();
      _modelCtrl.text = 'llama3.2:3b';
    });
    _showForm();
  }

  void _startEdit(int index) {
    final c = _characters[index];
    setState(() {
      _editingIndex = index;
      _nameCtrl.text = c.name;
      _descCtrl.text = c.personalityDescription;
      _promptCtrl.text = c.masterPrompt;
      _modelCtrl.text = c.modelId;
    });
    _showForm();
  }

  Future<void> _showForm() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _CharacterForm(
        editingIndex: _editingIndex,
        nameCtrl: _nameCtrl,
        descCtrl: _descCtrl,
        promptCtrl: _promptCtrl,
        modelCtrl: _modelCtrl,
        onSave: _save,
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final character = CustomCharacter(
      id: _editingIndex != null
          ? _characters[_editingIndex!].id
          : 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      personalityDescription: _descCtrl.text.trim(),
      masterPrompt: _promptCtrl.text.trim(),
      modelId: _modelCtrl.text.trim().isEmpty
          ? 'llama3.2:3b'
          : _modelCtrl.text.trim(),
    );
    final updated = List<CustomCharacter>.from(_characters);
    if (_editingIndex != null) {
      updated[_editingIndex!] = character;
    } else {
      updated.add(character);
    }
    await CustomCharacter.saveAll(updated);
    if (mounted) setState(() => _characters = updated);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete character?',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final updated = List<CustomCharacter>.from(_characters)..removeAt(index);
    await CustomCharacter.saveAll(updated);
    if (mounted) setState(() => _characters = updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Custom Characters',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _startNew,
              icon: const Icon(Icons.add, size: 16, color: AppColors.accent),
              label: const Text(
                'New Character',
                style: TextStyle(color: AppColors.accent, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: _characters.isEmpty
          ? const Center(
              child: Text(
                'No custom characters yet.\nTap "New Character" to create one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _characters.length,
              itemBuilder: (_, i) {
                final c = _characters[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (c.personalityDescription.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  c.personalityDescription,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Model: ${c.modelId}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            size: 16, color: AppColors.textSecondary),
                        tooltip: 'Edit',
                        onPressed: () => _startEdit(i),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 16, color: Colors.redAccent),
                        tooltip: 'Delete',
                        onPressed: () => _delete(i),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CharacterForm
// ---------------------------------------------------------------------------

class _CharacterForm extends StatelessWidget {
  final int? editingIndex;
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final TextEditingController promptCtrl;
  final TextEditingController modelCtrl;
  final VoidCallback onSave;

  const _CharacterForm({
    required this.editingIndex,
    required this.nameCtrl,
    required this.descCtrl,
    required this.promptCtrl,
    required this.modelCtrl,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      title: Text(
        editingIndex != null ? 'Edit Character' : 'New Character',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Name'),
              _field(nameCtrl, 'e.g. ORACLE'),
              const SizedBox(height: 10),
              _label('Personality description'),
              _field(descCtrl, 'Short description…'),
              const SizedBox(height: 10),
              _label('Master prompt'),
              _field(promptCtrl, 'System prompt…', maxLines: 6),
              const SizedBox(height: 10),
              _label('Model ID'),
              _field(modelCtrl, 'e.g. llama3.2:3b'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: onSave,
          child: const Text('Save',
              style: TextStyle(color: AppColors.accent)),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _field(TextEditingController ctrl, String hint,
      {int maxLines = 1}) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              color: AppColors.textSecondary, fontSize: 12),
          isDense: true,
        ),
      );
}
