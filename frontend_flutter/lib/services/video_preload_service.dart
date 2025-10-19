import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:video_player/video_player.dart';

class VideoPreloadService {
  static VideoPlayerController? controller;
  static String? resolvedAssetKey;

  static Future<void> init(String assetPath) async {
    if (controller != null) return; // already initialized
    try {
      print('VideoPreloadService: Starting preload for $assetPath');
      final key = await _resolveAssetKey(assetPath);
      print('VideoPreloadService: Resolved asset key: $key');
      resolvedAssetKey = key;
      final c = VideoPlayerController.asset(
        key,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      )
        ..setLooping(true)
        ..setVolume(0.0);
      await c.initialize();
      print('VideoPreloadService: Controller initialized successfully');
      controller = c;
      await controller!.play();
      print('VideoPreloadService: Video playing');
    } catch (e) {
      print('VideoPreloadService: Error: $e');
      // swallow; widget will fallback to its own init
    }
  }

  static Future<String> _resolveAssetKey(String requestedPath) async {
    final manifestJson = await rootBundle.loadString('AssetManifest.json');
    if (manifestJson.isEmpty) return requestedPath;
    final Map<String, dynamic> manifest =
        Map<String, dynamic>.from(jsonDecode(manifestJson));
    final parts = requestedPath
        .split('/')
        .where((s) => s.trim().isNotEmpty)
        .toList(growable: false);
    final targetName = parts.isEmpty ? requestedPath : parts.last;
    final lowerTarget = targetName.toLowerCase();
    for (final key in manifest.keys) {
      if (key.toLowerCase().endsWith(lowerTarget)) {
        return key;
      }
    }
    return requestedPath;
  }
}



