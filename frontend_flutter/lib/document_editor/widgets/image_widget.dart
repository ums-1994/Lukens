import 'package:flutter/material.dart';
import '../models/inline_image.dart';

class ImageWidget extends StatelessWidget {
  final InlineImage image;
  final VoidCallback onRemove;

  const ImageWidget({
    super.key,
    required this.image,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: image.width,
      height: image.height,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF00BCD4), width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              image.url,
              width: image.width,
              height: image.height,
              fit: BoxFit.cover,
            ),
          ),
          // Delete button
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
