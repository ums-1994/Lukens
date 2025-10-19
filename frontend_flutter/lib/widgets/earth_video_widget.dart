import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

class EarthVideoWidget extends StatefulWidget {
  final double width;
  final double height;
  final String assetPath;

  const EarthVideoWidget({
    super.key,
    required this.width,
    required this.height,
    required this.assetPath,
  });

  @override
  State<EarthVideoWidget> createState() => _EarthVideoWidgetState();
}

class _EarthVideoWidgetState extends State<EarthVideoWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      print('Initializing video: ${widget.assetPath}');
      
      // Try to resolve the asset path
      String assetPath = await _resolveAssetPath(widget.assetPath);
      print('Resolved asset path: $assetPath');
      
      _controller = VideoPlayerController.asset(assetPath);
      
      await _controller!.initialize();
      print('Video initialized successfully');
      print('Video size: ${_controller!.value.size}');
      print('Video duration: ${_controller!.value.duration}');
      
      _controller!.setLooping(true);
      _controller!.setVolume(0.0);
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _controller!.play();
        print('Video started playing');
      }
    } catch (e) {
      print('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  Future<String> _resolveAssetPath(String requestedPath) async {
    try {
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest = json.decode(manifestJson);
      
      // Try exact match first
      if (manifest.containsKey(requestedPath)) {
        return requestedPath;
      }
      
      // Try to find a matching key
      for (final key in manifest.keys) {
        if (key.toLowerCase().contains('3d earth') && key.toLowerCase().contains('webm')) {
          print('Found matching asset: $key');
          return key;
        }
      }
      
      // Fallback to requested path
      return requestedPath;
    } catch (e) {
      print('Error resolving asset path: $e');
      return requestedPath;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: _isInitialized && _controller != null
            ? FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
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