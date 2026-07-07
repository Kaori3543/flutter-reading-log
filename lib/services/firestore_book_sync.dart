/// Firestore と Hive の間で本棚データを双方向同期する (feature/sync-firebase)。
///
/// 設計:
///   - Hive はローカルキャッシュ (オフライン参照可能)
///   - Firestore の users/{uid}/books/{bookId} が「クラウド真実源」
///   - ログイン中はローカル書き込みを Firestore にも反映
///   - Firestore snapshot 変化があれば Hive を上書き、ChangeNotifier で
///     購読者 (BookListNotifier) に「取り直せ」と通知
///
/// この仕組みは、ログイン状態のときだけ有効。未ログイン時は BookRepository
/// (Hive のみ) がそのまま動く。BookListNotifier からは
/// [FirestoreBookSync] を optional で受け取り、あれば save/remove の後で
/// mirrorSave/mirrorRemove を呼ぶ。
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import 'book_repository.dart';

/// Firestore の users/{uid}/books コレクションを購読し、Hive と同期させる。
///
/// ChangeNotifier を継承しているのは、Firestore 側の変化で Hive を書き換えた
/// 後に BookListNotifier に「state を取り直せ」と通知するため。
class FirestoreBookSync extends ChangeNotifier {
  FirestoreBookSync({
    required this.uid,
    required this.repository,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final BookRepository repository;

  final FirebaseFirestore _firestore;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('users').doc(uid).collection('books');

  /// 初回スナップショットを Hive に取り込み + 継続 subscribe する。
  Future<void> start() async {
    final initial = await _col.get();
    await _applySnapshot(initial);
    notifyListeners();

    _sub = _col.snapshots().listen((snap) async {
      await _applySnapshot(snap);
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// スナップショットの内容で Hive を上書きする。
  /// 「Firestore に存在しないが Hive にはある本」も削除して両者を揃える。
  Future<void> _applySnapshot(QuerySnapshot<Map<String, dynamic>> snap) async {
    final remoteIds = <String>{};
    for (final doc in snap.docs) {
      final map = doc.data();
      remoteIds.add(doc.id);
      try {
        final book = Book.fromMap(Map<String, dynamic>.from(map));
        await repository.save(book);
      } catch (_) {
        // 破損データはスキップ
      }
    }
    final localBooks = repository.getAll();
    for (final b in localBooks) {
      if (!remoteIds.contains(b.id)) {
        await repository.remove(b.id);
      }
    }
  }

  /// BookListNotifier の save() から呼ぶ。Firestore にミラー書き込み。
  Future<void> mirrorSave(Book book) async {
    await _col.doc(book.id).set(book.toMap());
  }

  /// BookListNotifier の remove() から呼ぶ。Firestore から削除。
  Future<void> mirrorRemove(String id) async {
    await _col.doc(id).delete();
  }
}

/// 現在のログインユーザーに紐づく [FirestoreBookSync] を提供する provider。
/// 未ログインなら null。AuthGate 側でログイン時に作成 + start() 済みの
/// インスタンスを set し、ログアウト時に dispose して null に戻す。
final firestoreBookSyncProvider = StateProvider<FirestoreBookSync?>((ref) {
  return null;
});
