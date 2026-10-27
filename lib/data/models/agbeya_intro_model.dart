// lib/data/models/agbeya_intro_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// The single shared Agbeya intro — one Arabic audio file and one Greek audio
// file, uploaded once by the admin, that plays automatically before whichever
// track the user picks for any hour (see track_picker_sheet.dart). Stored as
// a singleton doc — see AgbeyaIntroRepository.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class AgbeyaIntroModel extends Equatable {
  const AgbeyaIntroModel({
    this.urlAr = '',
    this.durationArSeconds = 0,
    this.urlEl = '',
    this.durationElSeconds = 0,
  });

  final String urlAr;
  final int    durationArSeconds;
  final String urlEl;
  final int    durationElSeconds;

  static const empty = AgbeyaIntroModel();

  String urlFor(String langCode) => langCode == 'el' ? urlEl : urlAr;

  int durationFor(String langCode) =>
      langCode == 'el' ? durationElSeconds : durationArSeconds;

  factory AgbeyaIntroModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? const {};
    return AgbeyaIntroModel(
      urlAr: d['url_ar'] as String? ?? '',
      durationArSeconds: (d['duration_ar_seconds'] as num?)?.toInt() ?? 0,
      urlEl: d['url_el'] as String? ?? '',
      durationElSeconds: (d['duration_el_seconds'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'url_ar': urlAr,
        'duration_ar_seconds': durationArSeconds,
        'url_el': urlEl,
        'duration_el_seconds': durationElSeconds,
      };

  AgbeyaIntroModel copyWith({
    String? urlAr,
    int? durationArSeconds,
    String? urlEl,
    int? durationElSeconds,
  }) =>
      AgbeyaIntroModel(
        urlAr: urlAr ?? this.urlAr,
        durationArSeconds: durationArSeconds ?? this.durationArSeconds,
        urlEl: urlEl ?? this.urlEl,
        durationElSeconds: durationElSeconds ?? this.durationElSeconds,
      );

  @override
  List<Object?> get props =>
      [urlAr, durationArSeconds, urlEl, durationElSeconds];
}
