import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

class Html5VideoWidget extends StatefulWidget {
  final double width;
  final double height;
  final String assetPath;

  const Html5VideoWidget({
    super.key,
    required this.width,
    required this.height,
    required this.assetPath,
  });

  @override
  State<Html5VideoWidget> createState() => _Html5VideoWidgetState();
}

class _Html5VideoWidgetState extends State<Html5VideoWidget> {
  web.HTMLVideoElement? _videoElement;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initializeVideo();
    }
  }

  void _initializeVideo() {
    try {
      _videoElement = web.HTMLVideoElement()
        ..src = widget.assetPath
        ..autoplay = true
        ..loop = true
        ..muted = true
        ..playsInline = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.borderRadius = '20px';

      _videoElement!.onLoadedData.listen((_) {
        print('Video loaded successfully');
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      });

      _videoElement!.onError.listen((event) {
        print('Video error: ${event.toString()}');
      });

      // Add video to DOM
      web.document.body?.append(_videoElement!);
      
      print('Video element created and added to DOM');
    } catch (e) {
      print('Error creating video element: $e');
    }
  }

  @override
  void dispose() {
    _videoElement?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.black,
        child: const Center(
          child: Text('Video not supported on this platform'),
        ),
      );
    }

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black,
      ),
      child: _isInitialized
          ? HtmlElementView(
              viewType: 'html5-video-${widget.hashCode}',
              onPlatformViewCreated: (int id) {
                // Video is already created and added to DOM
              },
            )
          : const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
    );
  }
}










