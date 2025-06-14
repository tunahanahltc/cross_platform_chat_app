import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'fullscreen_video_player.dart'; // Fullscreen için

class VideoMessageWidget extends StatefulWidget {
  final String localPath;
  final bool isMe;

  const VideoMessageWidget({
    Key? key,
    required this.localPath,
    required this.isMe,
  }) : super(key: key);

  @override
  State<VideoMessageWidget> createState() => _VideoMessageWidgetState();
}

class _VideoMessageWidgetState extends State<VideoMessageWidget> {
  late VideoPlayerController _controller;
  bool _showPlayButton = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.localPath))
      ..initialize().then((_) {
        setState(() {}); // İlk frame gelsin
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openFullscreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullscreenVideoPlayerPage(videoPath: widget.localPath),
      ),
    );
    // Geri dönünce tekrar Play butonu görünsün
    setState(() {
      _showPlayButton = true;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 250,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: widget.isMe ? Colors.amber : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_controller.value.isInitialized)
              Stack(
                children: [
                  SizedBox(
                    height: 260,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: VideoPlayer(_controller),
                    ),
                  ),
                  // Play butonu ortada
                  if (_showPlayButton)
                    Positioned.fill(
                      child: Center(
                        child: GestureDetector(
                          onTap: () {
                            _openFullscreen();
                            setState(() {
                              _showPlayButton = false;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(12),
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Süre sağ alt köşede
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatDuration(_controller.value.duration),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              const SizedBox(
                height: 260,
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
