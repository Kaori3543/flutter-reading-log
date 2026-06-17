/// 本を検索する画面。
///
/// W2 で導入（楽天 Books API 連携）。
/// W3 で「結果から本棚に追加する」フローを SnackBar の案内から本物の
/// 追加処理（hive に保存 → 本棚に反映）に置き換えた。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sample/list/BookListItem.dart';
import 'package:sample/models/book.dart';
import 'package:sample/providers/book_list_provider.dart';
import 'package:sample/services/rakuten_api.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  final _api = RakutenApi();

  /// 現在の検索 Future。null なら未検索状態（初期画面）。
  Future<List<Book>>? _searchFuture;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _runSearch() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searchFuture = _api.searchBooks(query);
    });
  }

  /// 検索結果の本を本棚に追加する（W3 で実装）。
  /// 重複チェック → 確認ダイアログ → hive に保存 → SnackBar で通知。
  Future<void> _addBook(Book book) async {
    final notifier = ref.read(bookListProvider.notifier);

    // 重複チェック
    if (notifier.exists(book.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${book.title}」は既に本棚に登録されています')),
      );
      return;
    }

    // 確認ダイアログ
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('本棚に追加'),
        content: Text('「${book.title}」を本棚に追加しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('追加'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // W9: 本棚追加日時を記録（積読放置リマインダー R5 で使う）。
    Book toSave = book.copyWith(addedAt: DateTime.now());

    // W7: ジャンル ID があれば API で名前を取得して Book.genre にセット。
    // 通信失敗や ID 解決失敗時は genre = null のまま登録（本登録は止めない）。
    final gid = toSave.genreId;
    if (gid != null && gid.isNotEmpty) {
      try {
        final name = await _api.getGenreName(gid);
        if (name != null) {
          toSave = toSave.copyWith(genre: name);
        }
      } catch (_) {
        // 例外は黙殺 — ジャンル名取れなくても本は登録できる
      }
    }

    // hive に保存（provider 経由）
    await notifier.add(toSave);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「${toSave.title}」を本棚に追加しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('本を検索'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // 検索バー
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'タイトル / 著者 / キーワード',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _runSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _runSearch,
                  child: const Text('検索'),
                ),
              ],
            ),
          ),
          // 結果表示
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_searchFuture == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '上の検索バーに本のタイトル・著者・キーワードを入力して\n「検索」を押してください',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    return FutureBuilder<List<Book>>(
      future: _searchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '検索に失敗しました\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        final books = snapshot.data ?? [];
        if (books.isEmpty) {
          return const Center(
            child: Text('該当する本が見つかりませんでした'),
          );
        }
        return ListView.builder(
          itemCount: books.length,
          itemBuilder: (context, index) {
            final book = books[index];
            return BookListItem(
              book: book,
              onPressed: () => _addBook(book),
            );
          },
        );
      },
    );
  }
}
