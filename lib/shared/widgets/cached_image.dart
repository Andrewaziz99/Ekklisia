// lib/shared/widgets/cached_image.dart
// ─────────────────────────────────────────────────────────────────────────────
// Drop-in replacement for Image.network() that caches images locally for
// offline access and shows consistent loading/error states.
//
// Usage:
//   CachedImage(url: item.imageUrl, width: 80, height: 80, fit: BoxFit.cover)
//   CachedImage.round(url: item.imageUrl, size: 48)   // circular avatar
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';

class CachedImage extends StatelessWidget {
  const CachedImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.color,
    this.colorBlendMode,
  });

  /// Convenience constructor for a circular (avatar-style) image.
  factory CachedImage.round({
    Key? key,
    required String url,
    required double size,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return CachedImage(
      key: key,
      url: url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(size / 2),
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Color? color;
  final BlendMode? colorBlendMode;

  @override
  Widget build(BuildContext context) {
    // Guard against empty URLs
    if (url.isEmpty) {
      return placeholder ?? _DefaultPlaceholder(width: width, height: height);
    }

    Widget image = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      color: color,
      colorBlendMode: colorBlendMode,
      placeholder: (context, url) =>
          placeholder ??
          _DefaultPlaceholder(width: width, height: height),
      errorWidget: (context, url, error) =>
          errorWidget ??
          _DefaultErrorWidget(width: width, height: height),
      fadeInDuration: const Duration(milliseconds: 200),
      memCacheWidth: (width != null && width!.isFinite) ? (width! * 2).toInt() : null,
      memCacheHeight: (height != null && height!.isFinite) ? (height! * 2).toInt() : null,
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }
}

// ── Default placeholder ────────────────────────────────────────────────────

class _DefaultPlaceholder extends StatelessWidget {
  const _DefaultPlaceholder({this.width, this.height});
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: EkklisiaColors.bgElevated,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(EkklisiaColors.gold),
          ),
        ),
      ),
    );
  }
}

// ── Default error widget ───────────────────────────────────────────────────

class _DefaultErrorWidget extends StatelessWidget {
  const _DefaultErrorWidget({this.width, this.height});
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: EkklisiaColors.bgElevated,
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: EkklisiaColors.textSecondary,
          size: 24,
        ),
      ),
    );
  }
}
