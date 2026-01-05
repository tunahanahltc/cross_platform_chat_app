import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';

class AudioMessageBubble extends StatefulWidget {
  final String localPath;
  final bool isMe;

  const AudioMessageBubble({
    Key? key,
    required this.localPath,
    required this.isMe,
  }) : super(key: key);

  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<Duration>? _positionSub;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    await _player.setFilePath(widget.localPath);
    _stateSub = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state.playing);
    });
    _durationSub = _player.durationStream.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d ?? Duration.zero);
    });
    _positionSub = _player.positionStream.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _stateSub?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    _isPlaying ? await _player.pause() : await _player.play();
  }

  String _format(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: widget.isMe ? const EdgeInsets.only(left:50, right: 1, bottom: 2, top: 2)
            : const EdgeInsets.only(left: 1, right:50, bottom: 2, top: 2),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: widget.isMe ? Colors.amber : Colors.grey.shade300,
          borderRadius: BorderRadius.only(
            topLeft:  Radius.circular(widget.isMe ? 16 : 40),
            topRight:  Radius.circular(widget.isMe ? 40 : 16),
            bottomLeft: Radius.circular(widget.isMe ? 16 : 5),
            bottomRight: Radius.circular(widget.isMe ? 5 : 16),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
          widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: _togglePlayPause,
                ),
                Expanded(
                  child: Slider(
                    activeColor: Colors.grey,
                    inactiveColor: Colors.white,

                    thumbColor: Colors.white,
                    min: 0,
                    max: _duration.inMilliseconds.toDouble(),
                    value: _position.inMilliseconds.clamp(
                        0, _duration.inMilliseconds).toDouble(),
                    onChanged: (value) => _player
                        .seek(Duration(milliseconds: value.toInt())),
                  ),
                ),
              ],
            ),
            Text(
              '${_format(_position)} / ${_format(_duration)}',
              style: TextStyle(
                  color: widget.isMe ? Colors.black87 : Colors.black87,
                  fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
