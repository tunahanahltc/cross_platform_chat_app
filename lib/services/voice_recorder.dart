import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:uuid/uuid.dart';

class VoiceRecorderService {
  static final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  static bool _isInited = false;
  static String? _currentAacPath;
  static String? _convertedMp3Path;

  static Future<void> _init() async {
    if (_isInited) return;
    await Permission.microphone.request();
    await _recorder.openRecorder();
    _isInited = true;
  }

  static Future<void> startRecording() async {
    await _init();
    final dir = await getTemporaryDirectory();
    final uniqueId = const Uuid().v4();
    final filePath = '${dir.path}/voice_$uniqueId.aac';
    _currentAacPath = filePath;
    _convertedMp3Path = null;

    await _recorder.startRecorder(
      toFile: filePath,
      codec: Codec.aacADTS,
    );
  }

  static Future<String?> stopRecording() async {
    await _recorder.stopRecorder();
    if (_currentAacPath == null) return null;

    final mp3Path = await _convertAacToMp3(_currentAacPath!);
    _convertedMp3Path = mp3Path;

    return mp3Path;
  }

  static Future<String?> _convertAacToMp3(String inputPath) async {
    final mp3Path = inputPath.replaceAll('.aac', '.mp3');

    final session = await FFmpegKit.execute(
      '-i "$inputPath" -acodec libmp3lame "$mp3Path"',
    );

    final returnCode = await session.getReturnCode();
    if (returnCode?.isValueSuccess() ?? false) {
      return mp3Path;
    } else {
      print('FFmpeg Hatası: ${await session.getAllLogsAsString()}');
      return null;
    }
  }

  static String? get aacPath => _currentAacPath;
  static String? get mp3Path => _convertedMp3Path;
}
