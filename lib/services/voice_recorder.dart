import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

class VoiceRecorderService {
  static final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  static bool _isInited = false;
  static String? _currentFilePath;

  static Future<void> _init() async {
    if (_isInited) return;
    await Permission.microphone.request();
    await _recorder.openRecorder();
    _isInited = true;
  }

  static Future<void> startRecording() async {
    await _init();
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${dir.path}/voice_$timestamp.aac';
    _currentFilePath = filePath;

    await _recorder.startRecorder(
      toFile: filePath,
      codec: Codec.aacADTS,
    );
  }

  static Future<String?> stopRecording() async {
    await _recorder.stopRecorder();
    return _currentFilePath;
  }
}
