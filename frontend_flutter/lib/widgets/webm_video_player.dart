import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;

class WebMVideoPlayer extends StatefulWidget {
  final double width;
  final double height;
  final String assetPath;

  const WebMVideoPlayer({
    super.key,
    required this.width,
    required this.height,
    required this.assetPath,
  });

  @override
  State<WebMVideoPlayer> createState() => _WebMVideoPlayerState();
}

class _WebMVideoPlayerState extends State<WebMVideoPlayer> {
  web.HTMLVideoElement? _videoElement;
  bool _isInitialized = false;
  String? _error;
  String? _viewType;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initializeVideo();
    }
  }

  void _initializeVideo() {
    try {
      print('Initializing WebM video: ${widget.assetPath}');
      
      _viewType = 'webm-player-${widget.hashCode}';
      
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
            ..style.backgroundColor = 'black'
            ..controls = false;

          // Set up event listeners using the correct web package approach
          _videoElement!.onLoadedData = (event) {
            print('Video loaded successfully');
            if (mounted) {
              setState(() {
                _isInitialized = true;
              });
            }
          };

          _videoElement!.onError = (event) {
            print('Video error: ${event.toString()}');
            if (mounted) {
              setState(() {
                _error = 'Video failed to load. Please check the file format.';
              });
            }
          };

          _videoElement!.onCanPlay = (event) {
            print('Video can play');
            _videoElement!.play();
          };

          return _videoElement!;
        },
      );
      
      print('Video element registered successfully');
    } catch (e) {
      print('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _error = 'Error initializing video: $e';
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
                        const SizedBox(height: 16),
                        const Text(
                          'Try converting your WebM file to MP4 format\nfor better browser compatibility',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
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
                          'Loading Your Video...',
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









