// lib/data/models/social_links_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// Admin-editable social media links shown as icon buttons at the bottom of
// the home screen drawer. Single singleton doc — see SocialLinksRepository.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class SocialLinksModel extends Equatable {
  const SocialLinksModel({
    this.facebookUrl = '',
    this.youtubeUrl = '',
    this.viberUrl = '',
  });

  final String facebookUrl;
  final String youtubeUrl;
  final String viberUrl;

  static const empty = SocialLinksModel();

  factory SocialLinksModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? const {};
    return SocialLinksModel(
      facebookUrl: d['facebook_url'] as String? ?? '',
      youtubeUrl:  d['youtube_url']  as String? ?? '',
      viberUrl:    d['viber_url']    as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'facebook_url': facebookUrl,
        'youtube_url':  youtubeUrl,
        'viber_url':    viberUrl,
      };

  SocialLinksModel copyWith({
    String? facebookUrl,
    String? youtubeUrl,
    String? viberUrl,
  }) =>
      SocialLinksModel(
        facebookUrl: facebookUrl ?? this.facebookUrl,
        youtubeUrl:  youtubeUrl  ?? this.youtubeUrl,
        viberUrl:    viberUrl    ?? this.viberUrl,
      );

  @override
  List<Object?> get props => [facebookUrl, youtubeUrl, viberUrl];
}
