import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../profile/profile_store.dart';

/// A circular avatar that shows the player's chosen photo (or a default icon).
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.radius = 22, this.path});

  final double radius;

  /// Explicit path (used for the table's own seat). When null, falls back to
  /// the local [ProfileStore] image.
  final String? path;

  @override
  Widget build(BuildContext context) {
    final p = path ?? ProfileStore.imagePath.value;
    if (p != null && File(p).existsSync()) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF3A66C4),
        backgroundImage: FileImage(File(p)),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF3A66C4),
      child: Icon(Icons.person, color: Colors.white, size: radius),
    );
  }
}

/// A tappable profile header for the main menu: avatar + name, opens the editor.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () => showProfileEditor(context),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: ValueListenableBuilder<String?>(
          valueListenable: ProfileStore.imagePath,
          builder: (context, _, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  const ProfileAvatar(radius: 34),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFB300),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, size: 13, color: Colors.black),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ValueListenableBuilder<String>(
                valueListenable: ProfileStore.name,
                builder: (context, name, _) => Text(name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showProfileEditor(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF14213D),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => const _ProfileEditor(),
  );
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor();

  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: ProfileStore.name.value);
  final _picker = ImagePicker();
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (file != null) await ProfileStore.setImageFrom(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not pick image: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<String?>(
            valueListenable: ProfileStore.imagePath,
            builder: (context, _, _) => const ProfileAvatar(radius: 46),
          ),
          const SizedBox(height: 8),
          const Text('No login needed — saved on this device only',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Display name',
              labelStyle: TextStyle(color: Colors.white70),
            ),
            onChanged: ProfileStore.setName,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    await ProfileStore.clearImage();
                    if (mounted) setState(() {});
                  },
            icon: const Icon(Icons.delete_outline, color: Colors.white54),
            label: const Text('Remove photo',
                style: TextStyle(color: Colors.white54)),
          ),
          const SizedBox(height: 4),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A1B9A),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 46)),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
