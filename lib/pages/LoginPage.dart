/// ログイン画面 (feature/sync-firebase)。
///
/// Google Sign-In だけの最小構成。ログイン成功後は AuthGate 側で
/// MainPageWidget に自動で遷移する (この画面が dispose される)。
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _isSigningIn = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _isSigningIn = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
      // 成功時は AuthGate が state 変化を検知して自動遷移するので、
      // ここでは何もしなくて良い。
    } catch (e) {
      if (mounted) {
        setState(() => _error = _humanize(e));
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  String _humanize(Object e) {
    final msg = e.toString();
    if (msg.contains('popup_closed') || msg.contains('canceled')) {
      return 'ログインがキャンセルされました';
    }
    if (msg.contains('network')) {
      return 'ネットワークエラーです。接続を確認してください';
    }
    return 'ログインに失敗しました: $msg';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // アプリロゴ代わりのアイコン
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.menu_book_outlined,
                      size: 48,
                      color: AppColors.fg,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    '読書記録',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.fg,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ログインすると Web とスマホで\n本棚を同期できます',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.mutedFg,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 44),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSigningIn ? null : _signIn,
                      icon: _isSigningIn
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryFg,
                              ),
                            )
                          : const Icon(Icons.login, size: 18),
                      label: Text(
                          _isSigningIn ? 'ログイン中...' : 'Google でログイン'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.primaryFg,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    kIsWeb
                        ? 'Web 版はブラウザのポップアップが開きます'
                        : 'Google アカウント選択画面が表示されます',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedFg,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
