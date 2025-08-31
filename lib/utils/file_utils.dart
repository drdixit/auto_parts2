import 'dart:io';

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Widget that safely loads a local file image and falls back to a placeholder
/// if the file does not exist or fails to load.
class SafeImageFile extends StatelessWidget {
  final String? path;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget? placeholder;

  const SafeImageFile({
    super.key,
    required this.path,
    this.width = 40,
    this.height = 40,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    if (path == null || path!.isEmpty) {
      return placeholder ??
          Container(
            color: AppColors.surfaceMuted,
            width: width,
            height: height,
          );
    }

    final file = File(path!);
    return FutureBuilder<bool>(
      future: file.exists(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return SizedBox(
            width: width,
            height: height,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          );
        }

        if (snap.hasData && snap.data == true) {
          return Image.file(
            file,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (c, e, st) => _placeholder(),
          );
        }

        return _placeholder();
      },
    );
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.surfaceMuted,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image, size: 28, color: AppColors.textSecondary),
            SizedBox(height: 6),
            Text(
              'No image',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
