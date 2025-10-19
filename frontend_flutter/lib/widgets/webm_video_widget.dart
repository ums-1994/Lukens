import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;

class WebMVideoWidget extends StatefulWidget {
  final double width;
  final double height;
  final String assetPath;

  const WebMVideoWidget({
    super.key,
    required this.width,
    required this.height,
    required this.assetPath,
  });

  @override
  State<WebMVideoWidget> createState() => _WebMVideoWidgetState();
}

class _WebMVideoWidgetState extends State<WebMVideoWidget> {
  web.HTMLVideoElement? _videoElement;
  bool _isInitialized = false;
  String? _error;
  String? _viewType;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initializeVideo();
      // Set a timeout for loading
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted && !_isInitialized && _isLoading) {
          setState(() {
            _error = 'Video loading timeout. Please check your connection.';
            _isLoading = false;
          });
        }
      });
    }
  }

  void _initializeVideo() {
    try {
      print('Creating HTML5 video element for: ${widget.assetPath}');
      
      _viewType = 'webm-video-${widget.hashCode}';
      
      // Register the view factory
      ui_web.platformViewRegistry.registerViewFactory(
        _viewType!,
        (int viewId) {
          _videoElement = web.HTMLVideoElement()
            ..src = widget.assetPath
            ..autoplay = true
            ..loop = true
            ..muted = true
            ..playsInline = true
            ..preload = 'auto'
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.objectFit = 'cover'
            ..style.borderRadius = '20px'
            ..style.backgroundColor = 'black';

          // Simple approach - just set up the video and let it play
          print('Video element created, attempting to play');
          
          // Try to play immediately - just call play() without promise handling
          try {
            _videoElement!.play();
            print('Video play() called successfully');
            
            // Set a timer to check if video is playing
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted && _videoElement != null) {
                if (_videoElement!.readyState >= 2) { // HAVE_CURRENT_DATA
                  print('Video is ready and playing');
                  setState(() {
                    _isInitialized = true;
                    _isLoading = false;
                  });
                } else {
                  print('Video not ready yet, still loading...');
                }
              }
            });
          } catch (e) {
            print('Video play error: $e');
            if (mounted) {
              setState(() {
                _error = 'Video failed to play: $e';
                _isLoading = false;
              });
            }
          }

          return _videoElement!;
        },
      );
      
      print('Video element created and registered');
    } catch (e) {
      print('Error creating video element: $e');
      if (mounted) {
        setState(() {
          _error = 'Error creating video: $e';
        });
      }
    }
  }

  @override
  void dispose() {
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: _isInitialized && _viewType != null
            ? HtmlElementView(
                viewType: _viewType!,
                onPlatformViewCreated: (int id) {
                  // Video is already created and registered
                },
              )
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Video Error',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _error = null;
                              _isInitialized = false;
                            });
                            _initializeVideo();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Colors.white,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Loading Video...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
