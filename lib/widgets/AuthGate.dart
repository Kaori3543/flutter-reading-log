/// 認証状態に応じて LoginPage / MainPageWidget を出し分ける gate。
///
/// 加えて「ログイン成功時に FirestoreBookSync を start()」「ログアウト時に
/// dispose して null に戻す」ライフサイクル管理も担う。これで
/// bookListProvider は firestoreBookSyncProvider を watch するだけで
/// 自動的に Hive / Firestore モードを切り替えられる。
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../MainPageWidget.dart';
import '../pages/LoginPage.dart';
import '../providers/book_list_provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_book_sync.dart';
import '../theme/app_theme.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  /// 現在アクティブな sync (start 済み)。ユーザー切り替えで作り直すために保持。
  FirestoreBookSync? _activeSync;
  String? _activeUid;

  @override
  void dispose() {
    _activeSync?.dispose();
    super.dispose();
  }

  Future<void> _handleAuthChange(User? user) async {
    // 同じ uid ならスキップ (状態の再通知で無駄な再構築を避ける)
    if (user?.uid == _activeUid) return;

    // 既存 sync があれば止めて捨てる
    final old = _activeSync;
    if (old != null) {
      old.dispose();
      _activeSync = null;
      _activeUid = null;
      // provider も null に戻す
      ref.read(firestoreBookSyncProvider.notifier).state = null;
    }

    if (user == null) return; // ログアウト完了

    // 新しいユーザー向けに sync を作成 + start
    final repo = ref.read(bookRepositoryProvider);
    final sync = FirestoreBookSync(uid: user.uid, repository: repo);
    try {
      await sync.start();
    } catch (e) {
      // 開始失敗 (通信エラー等) の場合は sync を捨ててローカル運用のまま
      sync.dispose();
      return;
    }
    if (!mounted) {
      sync.dispose();
      return;
    }
    _activeSync = sync;
    _activeUid = user.uid;
    ref.read(firestoreBookSyncProvider.notifier).state = sync;
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);

    // 認証状態の変化を検知して sync を張り替える。
    // ref.listen は build 中に副作用を安全に扱う Riverpod のイディオム。
    ref.listen<AsyncValue<User?>>(authStateProvider, (prev, next) {
      final user = next.value;
      _handleAuthChange(user);
    });

    return authAsync.when(
      data: (user) {
        if (user == null) return const LoginPage();
        // 未同期状態 (sync がまだ start していない) は簡易ローディングを見せる
        final sync = ref.watch(firestoreBookSyncProvider);
        if (sync == null) {
          return const _SyncBootstrapScreen();
        }
        return const MainPageWidget();
      },
      loading: () => const _SyncBootstrapScreen(),
      error: (_, __) => const LoginPage(),
    );
  }
}

/// Firebase 認証状態の初期化 or Firestore 初回プル中に見せる薄い画面。
class _SyncBootstrapScreen extends StatelessWidget {
  const _SyncBootstrapScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              '本棚を同期しています…',
              style: TextStyle(color: AppColors.mutedFg, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
