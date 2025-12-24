import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class EditCategoryDialog extends StatefulWidget {
  final String? initialName;
  final Function(String) onSave;

  const EditCategoryDialog({super.key, this.initialName, required this.onSave});

  @override
  State<EditCategoryDialog> createState() => _EditCategoryDialogState();
}

class _EditCategoryDialogState extends State<EditCategoryDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get isEditing => widget.initialName != null;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Kategori' : 'Buat Kategori Baru'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nama kategori',
            prefixIcon: Icon(
              Icons.category_outlined,
              color: AppTheme.primaryColor,
            ),
          ),
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Nama kategori tidak boleh kosong';
            }
            if (value.trim().length < 2) {
              return 'Nama kategori minimal 2 karakter';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Batal',
            style: TextStyle(
              color: isDarkMode
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _onSave,
          child: Text(isEditing ? 'Simpan' : 'Buat'),
        ),
      ],
    );
  }

  void _onSave() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSave(_controller.text.trim());
      Navigator.pop(context);
    }
  }
}
