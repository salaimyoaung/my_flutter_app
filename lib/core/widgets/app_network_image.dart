import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Drop-in replacement for [Image.network].
///
/// On **web**: uses `WebHtmlElementStrategy.prefer` so Flutter renders images
/// via an HTML `<img>` element instead of XHR — bypasses Firebase Storage
/// CORS restriction without any server-side configuration.
///
/// On **mobile/desktop**: identical to [Image.network].
class AppNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final Widget Function(BuildContext, Widget, ImageChunkEvent?)? loadingBuilder;
  final Color? color;
  final BlendMode? colorBlendMode;

  /// If provided, wraps the image in a GestureDetector.
  /// Pass [VoidCallback] directly, or use [AppNetworkImage.tappable] factory
  /// to auto-open [FullScreenImagePage].
  final VoidCallback? onTap;

  const AppNetworkImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.errorBuilder,
    this.loadingBuilder,
    this.color,
    this.colorBlendMode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return errorBuilder?.call(context, 'empty url', null) ??
          const SizedBox.shrink();
    }

    final img = Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      color: color,
      colorBlendMode: colorBlendMode,
      errorBuilder: errorBuilder ?? (ctx, err, stack) {
        if (kDebugMode) {
          print('AppNetworkImage Error: $url -> $err');
        }
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image_outlined,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                size: (height != null && height! < 100) ? 20 : 32,
              ),
              if (height == null || height! >= 100) ...[
                const SizedBox(height: 4),
                Text(
                  'Image failed to load',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    fontSize: 8,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loadingBuilder: loadingBuilder ?? (ctx, child, progress) {
        if (progress == null) return child;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          // Removing CircularProgressIndicator for better UI
          child: const SizedBox.shrink(),
        );
      },
      // ✅ Fade-in animation when image loads
      opacity: const AlwaysStoppedAnimation(1.0),
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          child: child,
        );
      },
      // ✅ web: HTML <img> element — XHR ကို bypass လုပ်၍ CORS မလိုဘူး
      // mobile/desktop: ဒီ parameter ကို ignore လုပ်တယ် (effect မရှိ)
      webHtmlElementStrategy: kIsWeb
          ? WebHtmlElementStrategy.prefer
          : WebHtmlElementStrategy.never,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: img);
    }
    return img;
  }
}
