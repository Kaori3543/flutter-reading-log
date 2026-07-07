/// Firebase Auth + Google Sign-In のラッパー。
///
/// Web/モバイル間で本棚を同期させるためのアカウント基盤 (feature/sync-firebase)。
/// Web は `signInWithPopup`、ネイティブ (Android/iOS/macOS) は google_sign_in
/// パッケージ経由で認証する。Windows デスクトップは firebase_auth が非対応の
/// ためログイン UI を出さない (ローカル運用のみ)。
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// FirebaseAuth インスタンス (テストで差し替えできるように provider 化)。
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// 現在のユーザーの認証状態を stream で流す。
/// null = ログアウト中、User != null = ログイン済み。
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Google Sign-In 経由でログイン / ログアウトするサービス。
class AuthService {
  AuthService(this._auth);
  final FirebaseAuth _auth;

  /// Google アカウントでサインインする。
  ///
  /// Web は popup を使う。過去に COOP エラーで redirect に切り替えた時期も
  /// あったが、redirect 後の authStateChanges 復元がうまく動かないケースを
  /// 踏んだため popup に戻した。COOP エラーは Chrome の警告に留まり実挙動は
  /// 通ることが多い (Firebase Auth SDK 内でハンドリングされる)。
  /// ネイティブは google_sign_in の対話フローで認証する。
  Future<User?> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      final result = await _auth.signInWithPopup(provider);
      return result.user;
    }

    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null; // ユーザーキャンセル
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    return result.user;
  }

  /// ログアウトする (Firebase 側 + Google 側の両方)。
  Future<void> signOut() async {
    if (!kIsWeb) {
      // ネイティブは google_sign_in のセッションも切る
      try {
        await GoogleSignIn().signOut();
      } catch (_) {
        // 既にサインアウト済み等
      }
    }
    await _auth.signOut();
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(firebaseAuthProvider));
});
