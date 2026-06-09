import 'package:flutter/material.dart';

/// Shows a confirmation dialog before leaving a game table.
Future<bool> confirmExit(BuildContext context, {String? message}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF14213D),
      title: const Text('Leave table?',
          style: TextStyle(color: Colors.white)),
      content: Text(
        message ??
            'Are you sure you want to exit? '
                'Online players keep playing; your seat will show as Exited.',
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Stay'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
          child: const Text('Exit'),
        ),
      ],
    ),
  );
  return ok == true;
}
