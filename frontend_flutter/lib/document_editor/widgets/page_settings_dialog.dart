import 'package:flutter/material.dart';

/// Dialog widget for adjusting page style settings (orientation, margins,
/// background color/image) for the currently selected section/page.
class PageSettingsDialog {
  const PageSettingsDialog._();

  /// Shows the page style settings dialog.
  ///
  /// The parent provides:
  /// - [selectedPageIndex]: current page index (0-based)
  /// - [colorOptionsBuilder]: builds the color option widgets (uses parent
  ///   state, e.g. _buildColorOption)
  /// - [hasBackgroundImage]: whether the current page has a background image
  /// - [onSelectBackgroundImage]: callback to open the background image
  ///   picker (e.g. _selectBackgroundImageFromLibrary)
  /// - [onRemoveBackground]: optional callback to clear the background image
  static void show({
    required BuildContext context,
    required int selectedPageIndex,
    required List<Widget> Function() colorOptionsBuilder,
    required bool hasBackgroundImage,
    required VoidCallback onSelectBackgroundImage,
    VoidCallback? onRemoveBackground,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: SizedBox(
            width: 400,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Page Style Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00BCD4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Page ${selectedPageIndex + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Orientation',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Orientation changed to Portrait'),
                                backgroundColor: Color(0xFF27AE60),
                              ),
                            );
                          },
                          icon: const Icon(Icons.portrait),
                          label: const Text('Portrait'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00BCD4),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Orientation changed to Landscape'),
                                backgroundColor: Color(0xFF27AE60),
                              ),
                            );
                          },
                          icon: const Icon(Icons.landscape),
                          label: const Text('Landscape'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[400],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Margins',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Enter margin size (in cm)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Background Color',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: colorOptionsBuilder(),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Background Image',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onSelectBackgroundImage,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(6),
                          color: hasBackgroundImage
                              ? Colors.blue[50]
                              : Colors.grey[50],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              hasBackgroundImage
                                  ? Icons.image
                                  : Icons.add_photo_alternate,
                              color: const Color(0xFF00BCD4),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                hasBackgroundImage
                                    ? 'Background image selected'
                                    : 'Select from Content Library',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (hasBackgroundImage &&
                                onRemoveBackground != null)
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                tooltip: 'Remove background',
                                onPressed: onRemoveBackground,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Template settings saved'),
                              backgroundColor: Color(0xFF27AE60),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF27AE60),
                        ),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
