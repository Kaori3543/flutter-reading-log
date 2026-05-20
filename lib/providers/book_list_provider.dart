/// 本棚の本のリストを保持する Riverpod provider。
///
/// W1 ではダミーの 7 冊を初期データとして持つ。
/// W3 で hive Repository に置き換え、永続化されたデータを返すようにする予定。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';

/// 本のリストを管理する StateNotifier。
///
/// StateNotifierProvider を採用した理由：
/// - codegen 不要で導入が軽量
/// - 学習リソース・サンプルコードが豊富で、つまずいた時の情報収集がしやすい
/// - 不変オブジェクト（`List<Book>`）を state として扱い、変更時は新しい List を生成する
///   Flutter のリアクティブな再描画の仕組みと自然に噛み合う
class BookListNotifier extends StateNotifier<List<Book>> {
  BookListNotifier() : super(_initialBooks);

  /// W1 用のダミーデータ。
  /// 実在の本 7 冊で、ステータスをばらつかせて本棚らしい見た目にしている。
  /// W3 で楽天 Books API 由来の実データに置き換わる予定。
  static final List<Book> _initialBooks = [
    Book(
      id: '1',
      title: 'Search Inside Yourself',
      author: 'Chade-Meng Tan',
      publisher: '英治出版',
      totalPages: 320,
      currentPage: 320,
      status: BookStatus.finished,
      rating: 4.0,
      startedAt: DateTime(2025, 10, 1),
      finishedAt: DateTime(2025, 11, 10),
    ),
    Book(
      id: '2',
      title: 'DIE WITH ZERO',
      author: 'Bill Perkins',
      publisher: 'ダイヤモンド社',
      totalPages: 280,
      currentPage: 280,
      status: BookStatus.finished,
      rating: 5.0,
      startedAt: DateTime(2025, 11, 12),
      finishedAt: DateTime(2025, 12, 5),
    ),
    Book(
      id: '3',
      title: 'The Psychology of Money',
      author: 'Morgan Housel',
      publisher: 'ダイヤモンド社',
      totalPages: 250,
      currentPage: 250,
      status: BookStatus.finished,
      rating: 4.0,
      startedAt: DateTime(2025, 12, 8),
      finishedAt: DateTime(2026, 1, 15),
    ),
    Book(
      id: '4',
      title: 'YOUR TIME',
      author: '鈴木祐',
      publisher: '河出書房新社',
      totalPages: 320,
      currentPage: 120,
      status: BookStatus.reading,
      startedAt: DateTime(2026, 3, 1),
    ),
    Book(
      id: '5',
      title: "CAN'T HURT ME",
      author: 'David Goggins',
      publisher: 'パンローリング',
      totalPages: 280,
      currentPage: 50,
      status: BookStatus.reading,
      startedAt: DateTime(2026, 4, 20),
    ),
    Book(
      id: '6',
      title: 'Effectuation',
      author: 'Saras Sarasvathy',
      publisher: '碩学舎',
      totalPages: 380,
      status: BookStatus.wantToRead,
    ),
    Book(
      id: '7',
      title: 'Dark Horse',
      author: 'Todd Rose & Ogi Ogas',
      publisher: '三笠書房',
      totalPages: 304,
      status: BookStatus.wantToRead,
    ),
  ];
}

/// 本棚の本のリストを公開する provider。
/// ConsumerWidget から `ref.watch(bookListProvider)` で参照する。
final bookListProvider =
    StateNotifierProvider<BookListNotifier, List<Book>>(
  (ref) => BookListNotifier(),
);

/// 詳細モーダルに表示する「選択中の本」を保持する provider。
///
/// - null なら詳細モーダルは閉じている状態
/// - Book を入れると MainPageWidget がそれを検知してモーダルを表示する
///
/// StateProvider（軽量、単一値の状態管理）を採用。
/// 旧 MainPageWidget の `bool _isSelectedItem` を「どの本を選んだか」も含めて表現できるよう
/// Book? に拡張した形。
final selectedBookProvider = StateProvider<Book?>((ref) => null);
