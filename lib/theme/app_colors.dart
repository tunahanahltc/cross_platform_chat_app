// lib/theme/app_colors.dart

import 'package:flutter/material.dart';

class AppColors {
  // a renk seti (primary vb.)
  static const Color _aLight = Color(0xFFFFFFFE);   // açık mod primary
  static const Color _aDark  = Color(0xFF1E1E1E);   // koyu mod primary

  // b renk seti (text vb.)
  static const Color _bLight = Color(0xFF333333);   // açık mod metin
  static const Color _bDark  = Color(0xFFEEEEEE);   // koyu mod metin

    static const Color _cLight = Color(0xFFE0E0E0);   // açık mod metin
  static const Color _cDark  = Color(0xFF424242);   // koyu mod metin

  /// Güncel tema moduna bakarak aLight veya aDark döner
  static Color primaryy(Brightness brightness) =>
      brightness == Brightness.dark ? _aDark : _aLight;

  /// Güncel tema moduna bakarak bLight veya bDark döner
  static Color text(Brightness brightness) =>
      brightness == Brightness.dark ? _bDark : _bLight;

  static Color secondary(Brightness brightness) =>
      brightness == Brightness.dark ? _cDark : _cLight;
}

// style: TextStyle(fontSize: 12, color: Colors.grey[600]),
// style: const TextStyle(color: Colors.black, fontSize: 16)),
// style: const TextStyle(color: Colors.black54, fontSize: 11)),
// color: isMe ? Colors.amber : Colors.grey.shade300,
// color: _isRecording ? Colors.redAccent : Colors.amber, // 🔥
// olor: Colors.red,
// style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),