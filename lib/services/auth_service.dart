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
  /// Web は Firebase の redirect フローで、ネイティブは google_sign_in の
  /// 対話フローで認証する。Web で popup ではなく redirect を選ぶ理由:
  /// Chrome が Cross-Origin-Opener-Policy を厳しめにデフォルト適用するように
  /// なり、`signInWithPopup` が「window.closed をブロックされて promise
  /// が resolve しない」不具合を起こすため。redirect ならこの制限を受けない。
  ///
  /// redirect の場合、この関数は「リダイレクトを開始する」だけで返らずに
  /// ページが遷移する。戻ってきた時に `authStateChanges` が発火するので、
  /// LoginPage 側は特に await 結果を使わない前提。
  Future<User?> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      // signInWithPopup の COOP 問題を回避するため redirect を使う。
      // getRedirectResult は AuthGate が authStateChanges で拾うので不要。
      await _auth.signInWithRedirect(provider);
      return null; // redirect でこの関数は事実上返らない
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
