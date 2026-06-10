// lib/data/models/game_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// Game question models for the interactive Games feature.
//
// Firestore collection: game_questions
// Document shape:
//   {
//     type:                string,   // 'guessWho' | 'mcq'
//     question_ar:         string,
//     question_el:         string,
//     image_url:           string,   // required for guessWho, optional for mcq
//     cloudinary_image_id: string,
//     choices:             List<Map>, // 4 choices [{text_ar, text_el}, ...]
//     correct_index:       int,       // 0-3
//     category:            string,   // optional
//     is_visible:          bool,
//     sort_order:          int,
//     created_at:          Timestamp,
//   }
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

// ── GameType ──────────────────────────────────────────────────────────────────

enum GameType { guessWho, mcq }

extension GameTypeX on GameType {
  String get labelAr => switch (this) {
        GameType.guessWho => 'من هو؟',
        GameType.mcq      => 'اختبار',
      };

  String get labelEl => switch (this) {
        GameType.guessWho => 'Ποιος είναι;',
        GameType.mcq      => 'Κουίζ',
      };

  static GameType fromSlug(String s) => GameType.values.firstWhere(
        (t) => t.name == s,
        orElse: () => GameType.mcq,
      );
}

// ── GameChoice ────────────────────────────────────────────────────────────────

class GameChoice extends Equatable {
  const GameChoice({required this.textAr, required this.textEl});

  final String textAr;
  final String textEl;

  factory GameChoice.fromMap(Map<String, dynamic> m) => GameChoice(
        textAr: m['text_ar'] as String? ?? '',
        textEl: m['text_el'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {'text_ar': textAr, 'text_el': textEl};

  GameChoice copyWith({String? textAr, String? textEl}) => GameChoice(
        textAr: textAr ?? this.textAr,
        textEl: textEl ?? this.textEl,
      );

  @override
  List<Object?> get props => [textAr, textEl];
}

// ── GameQuestion ──────────────────────────────────────────────────────────────

class GameQuestion extends Equatable {
  const GameQuestion({
    required this.id,
    required this.type,
    required this.questionAr,
    required this.questionEl,
    required this.imageUrl,
    required this.cloudinaryImageId,
    required this.choices,
    required this.correctIndex,
    required this.category,
    required this.isVisible,
    required this.sortOrder,
    required this.createdAt,
  });

  final String          id;
  final GameType        type;
  final String          questionAr;
  final String          questionEl;
  final String          imageUrl;
  final String          cloudinaryImageId;
  final List<GameChoice> choices;   // always 4 items
  final int             correctIndex; // 0-3
  final String          category;
  final bool            isVisible;
  final int             sortOrder;
  final DateTime        createdAt;

  GameChoice? get correctChoice =>
      correctIndex >= 0 && correctIndex < choices.length
          ? choices[correctIndex]
          : null;

  // ── From Firestore ─────────────────────────────────────────────────────────

  factory GameQuestion.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final rawChoices = d['choices'];
    final choices = rawChoices is List
        ? rawChoices
            .whereType<Map<String, dynamic>>()
            .map(GameChoice.fromMap)
            .toList()
        : const <GameChoice>[];
    return GameQuestion(
      id:                doc.id,
      type:              GameTypeX.fromSlug(d['type'] as String? ?? 'mcq'),
      questionAr:        d['question_ar']         as String? ?? '',
      questionEl:        d['question_el']         as String? ?? '',
      imageUrl:          d['image_url']           as String? ?? '',
      cloudinaryImageId: d['cloudinary_image_id'] as String? ?? '',
      choices:           choices,
      correctIndex:      d['correct_index']       as int? ?? 0,
      category:          d['category']            as String? ?? '',
      isVisible:         d['is_visible']          as bool? ?? true,
      sortOrder:         d['sort_order']          as int? ?? 0,
      createdAt: (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // ── To Firestore ───────────────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() => {
        'type':                type.name,
        'question_ar':         questionAr,
        'question_el':         questionEl,
        'image_url':           imageUrl,
        'cloudinary_image_id': cloudinaryImageId,
        'choices':             choices.map((c) => c.toMap()).toList(),
        'correct_index':       correctIndex,
        'category':            category,
        'is_visible':          isVisible,
        'sort_order':          sortOrder,
        'created_at':          FieldValue.serverTimestamp(),
      };

  // ── CopyWith ───────────────────────────────────────────────────────────────

  GameQuestion copyWith({
    String?           questionAr,
    String?           questionEl,
    String?           imageUrl,
    String?           cloudinaryImageId,
    List<GameChoice>? choices,
    int?              correctIndex,
    String?           category,
    bool?             isVisible,
    int?              sortOrder,
  }) =>
      GameQuestion(
        id:                id,
        type:              type,
        questionAr:        questionAr        ?? this.questionAr,
        questionEl:        questionEl        ?? this.questionEl,
        imageUrl:          imageUrl          ?? this.imageUrl,
        cloudinaryImageId: cloudinaryImageId ?? this.cloudinaryImageId,
        choices:           choices           ?? this.choices,
        correctIndex:      correctIndex      ?? this.correctIndex,
        category:          category          ?? this.category,
        isVisible:         isVisible         ?? this.isVisible,
        sortOrder:         sortOrder         ?? this.sortOrder,
        createdAt:         createdAt,
      );

  @override
  List<Object?> get props => [
        id, type, questionAr, questionEl, imageUrl,
        cloudinaryImageId, choices, correctIndex,
        category, isVisible, sortOrder, createdAt,
      ];
}
