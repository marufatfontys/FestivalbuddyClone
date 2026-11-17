import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Robust universal widget for displaying festival banner images.
/// Safely handles:
/// - Base64 Data URIs (`data:image/...;base64,...` and `data:application/octet-stream;base64,...`)
/// - Remote HTTP/HTTPS URLs
/// - Local File system paths (iOS / Android)
/// Includes error handling on all decoders to prevent crashes or blank cards.
Widget buildFestivalBannerImage(
  String? bannerPath, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  Widget? fallbackWidget,
}) {
  if (bannerPath == null || bannerPath.trim().isEmpty) {
    return fallbackWidget ?? const SizedBox.shrink();
  }

  final cleanPath = bannerPath.trim();

  // 1. Data URI (Base64) - matches data:image/..., data:application/octet-stream, etc.
  if (cleanPath.startsWith('data:')) {
    try {
      final base64String =
          cleanPath.contains(',') ? cleanPath.split(',').last : cleanPath;
      final bytes = base64Decode(base64String);
      return Image.memory(
        bytes,
        fit: fit,
        width: width,
        height: height,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          return fallbackWidget ?? const SizedBox.shrink();
        },
      );
    } catch (_) {
      return fallbackWidget ?? const SizedBox.shrink();
    }
  }

  // 2. Remote Network URL
  if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
    return Image.network(
      cleanPath,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) {
        return fallbackWidget ?? const SizedBox.shrink();
      },
    );
  }

  // 3. Local File Path (Mobile / Desktop)
  if (!kIsWeb) {
    try {
      final file = File(cleanPath);
      return Image.file(
        file,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) {
          return fallbackWidget ?? const SizedBox.shrink();
        },
      );
    } catch (_) {
      return fallbackWidget ?? const SizedBox.shrink();
    }
  }

  return fallbackWidget ?? const SizedBox.shrink();
}
