import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

// Web-only imports
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: deprecated_member_use_from_same_package
import 'dart:ui_web' as ui_web;

class BgVideo extends StatefulWidget {
  const BgVideo({super.key});

  @override
  State<BgVideo> createState() => _BgVideoState();
}

class _BgVideoState extends State<BgVideo> {
  // Native web video element pathway
  static const String _assetPath = 'assets/images/3D earth(webm).webm';
  static const double _targetSize = 350;

  // HtmlElementView state (web)
  static bool _webViewRegistered = false;
  late final String _viewTypeId;
  html.VideoElement? _videoElement;
  bool _isReady = false;
  bool _hadError = false;

  // Fallback controller (mobile/desktop)
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      _initWebVideo();
    } else {
      _initNativeController();
    }
  }

  void _initNativeController() {
    _controller = VideoPlayerController.asset(_assetPath)
      ..setVolume(0)
      ..initialize().then((_) {
        _controller.setLooping(true);
        _controller.play();
        if (mounted) setState(() {});
      });
  }

  void _initWebVideo() {
    _viewTypeId = 'bg-video-web-${DateTime.now().microsecondsSinceEpoch}';

    // Register view factory once per instance id
    if (!_webViewRegistered) {
      _webViewRegistered = true; // Mark as registered; individual IDs still passed below
    }

    ui_web.platformViewRegistry.registerViewFactory(_viewTypeId, (int _) {
      _videoElement = html.VideoElement()
        ..width = _targetSize.toInt()
        ..height = _targetSize.toInt()
        ..muted = true // Required for autoplay on many browsers
        ..loop = true
        ..autoplay = true
        ..controls = false
        ..preload = 'auto'
        ..style.objectFit = 'cover'
        ..style.width = '${_targetSize}px'
        ..style.height = '${_targetSize}px'
        ..attributes.addAll({'playsinline': 'true', 'webkit-playsinline': 'true'})
        ..crossOrigin = 'anonymous'
        ..src = _assetPath;

      // Events
      _videoElement!.addEventListener('canplay', (event) {
        _safeSetReady(true);
        _videoElement!.play().catchError((_) {});
      });
      _videoElement!.addEventListener('loadeddata', (event) {
        _safeSetReady(true);
      });
      _videoElement!.addEventListener('error', (event) {
        _hadError = true;
        _safeSetReady(false);
      });

      // Kickstart load
      _videoElement!.load();

      // Safety timeout: if not ready in 4s, still show spinner / allow retry
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && !_isReady && !_hadError) {
          setState(() {});
        }
      });

      return _videoElement!;
    });
  }

  void _safeSetReady(bool ready) {
    if (!mounted) return;
    setState(() {
      _isReady = ready;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return SizedBox(
        width: _targetSize,
        height: _targetSize,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video
            HtmlElementView(viewType: _viewTypeId),
            // Loading overlay
            if (!_isReady)
              const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
              ),
          ],
        ),
      );
    }

    // Non-web platforms use video_player
    return _controller.value.isInitialized
        ? SizedBox(
            width: _targetSize,
            height: _targetSize,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
          )
        : const SizedBox(
            width: _targetSize,
            height: _targetSize,
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
          );
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      _controller.dispose();
    }
    super.dispose();
  }
}
