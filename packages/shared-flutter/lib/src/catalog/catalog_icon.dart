import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Helpers for the icons the database serves.
///
/// `vehicle_types.icon_url` and `cargo_types.icon_url` hold the path of the
/// icon inside the public `catalog-icons` storage bucket (for example
/// `vehicle/pickup.svg`). Storing a path instead of an absolute URL keeps the
/// seed portable: the same row works on the local stack, on staging, and in
/// production, because the app resolves the path against its own Supabase
/// project URL.
///
/// An absolute `https://…` value is used as-is, so operators can point a row
/// at an asset hosted anywhere.
abstract final class CatalogIcons {
  /// Public bucket that holds the catalogue icons.
  static const String bucket = 'catalog-icons';

  /// Base URL of the public bucket for a Supabase project.
  static String storageBaseUrl(String supabaseUrl) {
    final base = supabaseUrl.endsWith('/')
        ? supabaseUrl.substring(0, supabaseUrl.length - 1)
        : supabaseUrl;
    return '$base/storage/v1/object/public/$bucket';
  }

  /// Turns a stored `icon_url` into an absolute URL.
  ///
  /// Returns null when there is nothing to load, so the caller can fall back
  /// to a Material icon.
  static String? resolve(String? iconUrl, String supabaseUrl) {
    final value = iconUrl?.trim();
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    final path = value.startsWith('/') ? value.substring(1) : value;
    return '${storageBaseUrl(supabaseUrl)}/$path';
  }

  /// True when the URL points at an SVG.
  static bool isSvg(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    return path.endsWith('.svg');
  }
}

/// Draws the icon a catalogue row points at.
///
/// SVG icons are tinted with [color]; raster icons keep their own colours.
/// When the row has no icon, or the icon fails to load, [fallbackIcon] is
/// drawn instead so the UI never shows an empty box.
class CatalogIcon extends StatelessWidget {
  const CatalogIcon({
    super.key,
    required this.iconUrl,
    required this.supabaseUrl,
    this.fallbackIcon = Icons.local_shipping_outlined,
    this.size = 24,
    this.color,
  });

  /// Raw `icon_url` value from the database.
  final String? iconUrl;

  /// Supabase project URL used to resolve bucket-relative paths.
  final String supabaseUrl;

  final IconData fallbackIcon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final url = CatalogIcons.resolve(iconUrl, supabaseUrl);
    if (url == null) return _fallback();
    if (CatalogIcons.isSvg(url)) {
      return SvgPicture.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: color == null
            ? null
            : ColorFilter.mode(color!, BlendMode.srcIn),
        placeholderBuilder: (_) => _fallback(),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: color,
      placeholder: (_, _) => _fallback(),
      errorWidget: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() => Icon(fallbackIcon, size: size, color: color);
}
