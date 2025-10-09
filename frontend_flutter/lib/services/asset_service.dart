import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

class AssetService {
  // Local asset paths cache
  static List<String> _localAssetPaths = [];
  
  /// Initialize asset service - load local assets
  static Future<void> initialize() async {
    try {
      final String manifestJson = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = jsonDecode(manifestJson) as Map<String, dynamic>;
      const String stockDir = 'assets/images/Individual Icon Asset Collections & Variations/';
      
      _localAssetPaths = manifestMap.keys
          .where((String key) => key.startsWith(stockDir))
          .where((String key) => key.endsWith('.png') || key.endsWith('.jpg') || key.endsWith('.jpeg'))
          .toList()
        ..sort();
    } catch (e) {
      print('Failed to load local assets: $e');
    }
  }
  
  /// Build image widget from local assets
  static Widget buildImageWidget(
    String assetPath, {
    double? width,
    double? height,
    BoxFit? fit,
    Widget? errorWidget,
  }) {
    // If it's already a URL, use network image
    if (assetPath.startsWith('http')) {
      return Image.network(
        assetPath,
        width: width,
        height: height,
        fit: fit ?? BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ?? const Icon(Icons.broken_image, size: 24, color: Colors.grey);
        },
      );
    }
    
    // Use local asset
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit ?? BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ?? const Icon(Icons.broken_image, size: 24, color: Colors.grey);
      },
    );
  }
  
  /// Get all available local asset paths
  static List<String> getLocalAssetPaths() {
    return List.from(_localAssetPaths);
  }
  
  /// Get gallery images from local assets
  static List<Map<String, String>> getGalleryImages() {
    return _localAssetPaths.map((assetPath) {
      return {
        'url': assetPath,
        'localPath': assetPath,
        'caption': assetPath.split('/').last,
      };
    }).toList();
  }
  
  /// Preload critical icons for better performance
  static Future<void> preloadCriticalIcons(BuildContext context) async {
    final criticalIcons = [
      'assets/images/Time Allocation_Approval_Blue.png',
      'assets/images/Dahboard.png',
      'assets/images/content_library.png',
      // Add more critical icons here
    ];
    
    for (String iconPath in criticalIcons) {
      try {
        await precacheImage(AssetImage(iconPath), context);
      } catch (e) {
        print('Failed to preload icon: $iconPath');
      }
    }
  }
}