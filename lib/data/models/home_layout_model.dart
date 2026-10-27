// lib/data/models/home_layout_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// Admin-editable overrides for the home screen: Content Library tile names +
// cover images, the header banner image, and every section / menu title
// (home section headers, side-drawer entries, bottom-nav labels).
//
// Stored as a single singleton doc — config/home_layout (see
// HomeLayoutRepository). Every field is optional: a blank label or image URL
// means "use the compiled-in default" (see home_layout_defaults.dart), so an
// empty / missing doc renders the app exactly as before.
//
// Doc shape:
//   {
//     banner_url: "https://…",
//     tiles:    { agbeya: { label_ar, label_el, image_url }, … },
//     sections: { content_library: { label_ar, label_el }, … }
//   }
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// One overridable item — a tile or a section title.
class HomeItemOverride extends Equatable {
  const HomeItemOverride({
    this.labelAr = '',
    this.labelEl = '',
    this.imageUrl = '',
  });

  final String labelAr;
  final String labelEl;
  final String imageUrl;

  static const empty = HomeItemOverride();

  bool get isEmpty =>
      labelAr.trim().isEmpty && labelEl.trim().isEmpty && imageUrl.isEmpty;

  /// Override for the requested language, or [fallback] when blank.
  String label({required bool isAr, required String fallback}) {
    final v = (isAr ? labelAr : labelEl).trim();
    return v.isEmpty ? fallback : v;
  }

  factory HomeItemOverride.fromMap(Object? raw) {
    final m = raw is Map ? raw : const {};
    return HomeItemOverride(
      labelAr:  m['label_ar'] as String? ?? '',
      labelEl:  m['label_el'] as String? ?? '',
      imageUrl: m['image_url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'label_ar':  labelAr.trim(),
        'label_el':  labelEl.trim(),
        'image_url': imageUrl,
      };

  HomeItemOverride copyWith({
    String? labelAr,
    String? labelEl,
    String? imageUrl,
  }) =>
      HomeItemOverride(
        labelAr:  labelAr  ?? this.labelAr,
        labelEl:  labelEl  ?? this.labelEl,
        imageUrl: imageUrl ?? this.imageUrl,
      );

  @override
  List<Object?> get props => [labelAr, labelEl, imageUrl];
}

class HomeLayoutModel extends Equatable {
  const HomeLayoutModel({
    this.bannerUrl = '',
    this.tiles = const {},
    this.sections = const {},
  });

  /// Replaces assets/images/Banner.png in the home header when non-empty.
  final String bannerUrl;

  /// Keyed by HomeTileKeys.*
  final Map<String, HomeItemOverride> tiles;

  /// Keyed by HomeSectionKeys.*
  final Map<String, HomeItemOverride> sections;

  static const empty = HomeLayoutModel();

  HomeItemOverride tile(String key) => tiles[key] ?? HomeItemOverride.empty;
  HomeItemOverride section(String key) =>
      sections[key] ?? HomeItemOverride.empty;

  String tileLabel(String key, {required bool isAr, required String fallback}) =>
      tile(key).label(isAr: isAr, fallback: fallback);

  String sectionLabel(String key,
          {required bool isAr, required String fallback}) =>
      section(key).label(isAr: isAr, fallback: fallback);

  factory HomeLayoutModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? const {};
    Map<String, HomeItemOverride> readMap(Object? raw) {
      if (raw is! Map) return const {};
      return {
        for (final e in raw.entries)
          e.key.toString(): HomeItemOverride.fromMap(e.value),
      };
    }

    return HomeLayoutModel(
      bannerUrl: d['banner_url'] as String? ?? '',
      tiles:     readMap(d['tiles']),
      sections:  readMap(d['sections']),
    );
  }

  Map<String, dynamic> toFirestore() {
    Map<String, dynamic> writeMap(Map<String, HomeItemOverride> m) => {
          for (final e in m.entries)
            if (!e.value.isEmpty) e.key: e.value.toMap(),
        };
    return {
      'banner_url': bannerUrl,
      'tiles':      writeMap(tiles),
      'sections':   writeMap(sections),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  HomeLayoutModel copyWith({
    String? bannerUrl,
    Map<String, HomeItemOverride>? tiles,
    Map<String, HomeItemOverride>? sections,
  }) =>
      HomeLayoutModel(
        bannerUrl: bannerUrl ?? this.bannerUrl,
        tiles:     tiles     ?? this.tiles,
        sections:  sections  ?? this.sections,
      );

  @override
  List<Object?> get props => [bannerUrl, tiles, sections];
}
