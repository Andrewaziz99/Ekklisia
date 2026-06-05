import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  const UserModel({
    required this.uid,
    required this.email,
    this.displayName = '',
    this.photoUrl = '',
    this.isAdmin = false,
    this.isAnonymous = false,
    this.isActive = true,
    this.fcmToken = '',
    this.signInMethod = 'email',
    this.createdAt,
    this.lastSeenAt,
  });

  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final bool isAdmin;
  final bool isAnonymous;
  /// False = account deactivated by admin (soft-disabled).
  final bool isActive;
  final String fcmToken;
  final String signInMethod;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;

  String get initials {
    if (displayName.isNotEmpty) {
      final parts = displayName.trim().split(' ');
      if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      return displayName[0].toUpperCase();
    }
    if (email.isNotEmpty) return email[0].toUpperCase();
    return 'A';
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid:         doc.id,
      email:       d['email']        ?? '',
      displayName: d['display_name'] ?? '',
      photoUrl:    d['photo_url']    ?? '',
      isAdmin:     d['is_admin']     ?? false,
      isAnonymous: d['is_anonymous'] ?? false,
      isActive:    d['is_active']    ?? true,
      fcmToken:    d['fcm_token']    ?? '',
      signInMethod: d['sign_in_method'] ?? 'email',
      createdAt:   (d['created_at']   as Timestamp?)?.toDate(),
      lastSeenAt:  (d['last_seen_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'email':        email,
    'display_name': displayName,
    'photo_url':    photoUrl,
    'is_admin':     isAdmin,
    'is_anonymous': isAnonymous,
    'is_active':    isActive,
    'fcm_token':    fcmToken,
    'sign_in_method': signInMethod,
    'created_at':   createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    'last_seen_at': FieldValue.serverTimestamp(),
  };

  UserModel copyWith({
    String? uid, String? email, String? displayName,
    String? photoUrl, bool? isAdmin, bool? isAnonymous, bool? isActive,
    String? fcmToken, String? signInMethod, DateTime? createdAt, DateTime? lastSeenAt,
  }) => UserModel(
    uid:         uid         ?? this.uid,
    email:       email       ?? this.email,
    displayName: displayName ?? this.displayName,
    photoUrl:    photoUrl    ?? this.photoUrl,
    isAdmin:     isAdmin     ?? this.isAdmin,
    isAnonymous: isAnonymous ?? this.isAnonymous,
    isActive:    isActive    ?? this.isActive,
    fcmToken:    fcmToken    ?? this.fcmToken,
    signInMethod: signInMethod ?? this.signInMethod,
    createdAt:   createdAt   ?? this.createdAt,
    lastSeenAt:  lastSeenAt  ?? this.lastSeenAt,
  );

  @override
  List<Object?> get props => [uid, email, isAdmin, isAnonymous, signInMethod];
}