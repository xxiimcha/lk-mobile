import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  VideoPlayerWidget({required this.videoUrl});

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    print("🎥 Initializing Video Player for URL: ${widget.videoUrl}");
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.network(widget.videoUrl);
      await _controller.initialize();
      setState(() {
        isInitialized = true;
      });
      print("✅ Video Player initialized successfully");
    } catch (e) {
      print("❌ Error initializing video player: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return isInitialized
        ? Column(
            children: [
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.play_arrow, color: Colors.green),
                    onPressed: () => _controller.play(),
                  ),
                  IconButton(
                    icon: Icon(Icons.pause, color: Colors.red),
                    onPressed: () => _controller.pause(),
                  ),
                ],
              ),
            ],
          )
        : Center(child: CircularProgressIndicator());
  }
}
