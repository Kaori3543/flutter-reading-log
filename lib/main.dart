import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'providers/book_list_provider.dart';
import 'providers/reading_goal_provider.dart';
import 'providers/review_list_provider.dart';
import 'services/book_repository.dart';
import 'services/review_repository.dart';
import 'services/settings_repository.dart';
import 'theme/app_theme.dart';
import 'widgets/AuthGate.dart';


/*
import 'package:sample/HomePage.dart';
import 'FirstPage.dart';
import 'SecondPage.dart';
import 'ThirdPage.dart';
*/

Future<void> main() async {
  // async main を使うため Flutter engine を明示的に初期化
  WidgetsFlutterBinding.ensureInitialized();

  // feature/sync-firebase: Firebase 初期化。Windows は firebase_auth 非対応の
  // ため kIsWeb || Android/iOS/macOS 以外は init を試みても意味が薄いが、
  // firebase_core 自体は Windows でも動くので落ちない範囲でスキップする。
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Windows など未対応プラットフォームでは fallback (ローカル運用のみ)
  }

  // W3: hive を初期化。アプリのドキュメントディレクトリに hive ファイルが
  // 置かれ、アプリを閉じても本棚データが永続化される。
  await Hive.initFlutter();

  // W3: BookRepository を初期化（本棚データ用の box を開く）。
  // W5: ReviewRepository も初期化（レビューデータ用の別 box）。
  // main で先に init を済ませることで、UI ウィジェット側は常に「init 済み」を
  // 前提にできる（毎回ローディング判定をする必要がない）。
  final bookRepo = BookRepository();
  await bookRepo.init();

  final reviewRepo = ReviewRepository();
  await reviewRepo.init();

  // W9: 読書目標などのアプリ設定を保存する settings box を開く。
  await SettingsRepository.init();

  // ProviderScope で全ウィジェットツリーをラップ。
  // 各 Repository の provider を override で実 Repository に差し替える。
  runApp(
    ProviderScope(
      overrides: [
        bookRepositoryProvider.overrideWithValue(bookRepo),
        reviewRepositoryProvider.overrideWithValue(reviewRepo),
        settingsRepositoryProvider
            .overrideWithValue(SettingsRepository.instance),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// メインカラー（本詳細画面 Figma 準拠に統一）。
  static const Color _seedColor = AppColors.primary;

  /// 本文系テキストの基本色。
  static const Color _bodyColor = AppColors.fg;

  /// 補足系テキスト（サブタイトル等）の色。
  static const Color _subtleColor = AppColors.mutedFg;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // 「上品・大人っぽい」雰囲気のために以下を組み合わせる:
    //   - 見出し系（display/headline/title）: 明朝（Noto Serif JP）
    //     本の組版に近づけて文学的な印象を出す
    //   - 本文系（body/label）: ゴシック（Noto Sans JP）
    //     長文（レビュー等）の可読性を保つ
    //   - 文字色は #1A1A1A（濃グレー）でコントラストを少し抑え柔らかく
    final headlineFont = GoogleFonts.notoSerifJpTextTheme();
    final bodyFont = GoogleFonts.notoSansJpTextTheme();
    final textTheme = TextTheme(
      displayLarge: headlineFont.displayLarge?.copyWith(color: _bodyColor),
      displayMedium: headlineFont.displayMedium?.copyWith(color: _bodyColor),
      displaySmall: headlineFont.displaySmall?.copyWith(color: _bodyColor),
      headlineLarge: headlineFont.headlineLarge?.copyWith(color: _bodyColor),
      headlineMedium:
          headlineFont.headlineMedium?.copyWith(color: _bodyColor),
      headlineSmall: headlineFont.headlineSmall?.copyWith(color: _bodyColor),
      titleLarge: headlineFont.titleLarge?.copyWith(
        color: _bodyColor,
        fontWeight: FontWeight.w500,
      ),
      titleMedium: headlineFont.titleMedium?.copyWith(color: _bodyColor),
      titleSmall: headlineFont.titleSmall?.copyWith(color: _bodyColor),
      bodyLarge: bodyFont.bodyLarge?.copyWith(color: _bodyColor, height: 1.6),
      bodyMedium: bodyFont.bodyMedium?.copyWith(color: _bodyColor, height: 1.6),
      bodySmall: bodyFont.bodySmall?.copyWith(color: _subtleColor, height: 1.5),
      labelLarge: bodyFont.labelLarge?.copyWith(color: _bodyColor),
      labelMedium: bodyFont.labelMedium?.copyWith(color: _bodyColor),
      labelSmall: bodyFont.labelSmall?.copyWith(color: _subtleColor),
    );

    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          primary: AppColors.primary,
          onPrimary: AppColors.primaryFg,
          secondary: AppColors.secondary,
          onSecondary: AppColors.secondaryFg,
          surface: AppColors.bg,
          onSurface: AppColors.fg,
        ),
        scaffoldBackgroundColor: AppColors.bg,
        textTheme: textTheme,
        // AppBar は本詳細のヘッダーと揃えたダーク茶 (#3A2A1E) + 白文字。
        // タイトル・アイコンは Noto Sans JP / w500 / 白 60% で統一 (本詳細と同じ)。
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.headerBg,
          foregroundColor: Colors.white.withValues(alpha: 0.7),
          iconTheme: IconThemeData(
            color: Colors.white.withValues(alpha: 0.7),
            size: 20,
          ),
          actionsIconTheme: IconThemeData(
            color: Colors.white.withValues(alpha: 0.7),
            size: 20,
          ),
          centerTitle: true,
          titleTextStyle: GoogleFonts.notoSansJp(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.2,
          ),
        ),
        // カードのシャドウを控えめに（elevation 1）+ 角丸を 8 で統一
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        // 区切り線を細く・薄く
        dividerTheme: const DividerThemeData(
          thickness: 0.5,
          space: 24,
        ),
        // ListTile の文字色を明示
        listTileTheme: const ListTileThemeData(
          textColor: _bodyColor,
          iconColor: _subtleColor,
        ),
      ),
      //home: const MyHomePage(title: 'Flutter Demo Home Page'),
      //home: HomePage(),
      // （1） 最初のページ名
/*      initialRoute: '/home',
      // （2） ページ名とウィジェットの関係
      routes: {
        //'/home' : (context) => HomePage(),
        //'/first' : (context) => FirstPage(),
        //'/second' : (context) => SecondPage(),
        //'/Third' : (context) => ThirdPage(),
      }
*/
      //Listの導入テスト
      //home:CouponListView(dummyDetail),
      // feature/sync-firebase: AuthGate が認証状態で LoginPage or MainPage を出し分ける。
      home: const AuthGate(),
      // Web (Chrome/Edge) でマウスドラッグでも横スクロールできるようにする。
      // デフォルトは touch のみで、マウスは wheel だけしか横スクロールできない。
      scrollBehavior: const _AppScrollBehavior(),
    );

  }

}

/// Web (Chrome/Edge) 用: 横スクロール可能な ListView をマウスドラッグでも
/// スライドできるようにする。デフォルトの MaterialScrollBehavior は
/// dragDevices を touch のみに絞っているため、マウス操作だと横スクロールが
/// 効かず、Wheel でしか動かせない。
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}


