import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/community/post_detail_screen.dart';
import 'services/notification_service.dart';

// TODO: 테스트용 플래그 - 배포 전 false로 변경 후 제거
const bool _kAlwaysShowOnboarding = false;

// 백그라운드/종료 상태에서 FCM data-only 메시지 수신 처리
// 별도 isolate에서 실행되므로 Firebase와 플러그인을 독립적으로 초기화해야 함
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  final title = message.data['title'];
  final body = message.data['body'];
  if (title == null || body == null) return;

  await plugin.show(
    message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'high_importance_channel',
        '이제댕냥 알림',
        channelDescription: '반려동물 건강 관리 알림',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
    payload: jsonEncode(message.data),
  );
}

final _navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);
  final keyHash = await kakao.KakaoSdk.origin;
  print('카카오 키 해시: $keyHash');
  kakao.KakaoSdk.init(nativeAppKey: 'c429d12217bc74a6b6fcb47d98cffa19');
  await NotificationService().init(_navigatorKey);
  await NotificationService().requestPermission();
  runApp(MyApp(navigatorKey: _navigatorKey));
}

Future<bool> _shouldShowOnboarding() async {
  // TODO: 테스트용 플래그 - 배포 전 제거
  if (_kAlwaysShowOnboarding) return true;
  final prefs = await SharedPreferences.getInstance();
  return !(prefs.getBool('onboarding_done') ?? false);
}

class MyApp extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  const MyApp({super.key, required this.navigatorKey});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    final appLinks = AppLinks();

    // 앱 종료 상태에서 딥링크로 진입: 첫 프레임 후 약간의 딜레이를 두어
    // 인증 상태가 확정된 뒤 화면을 push
    final initial = await appLinks.getInitialLink();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(
          const Duration(milliseconds: 500),
          () => _handleLink(initial),
        );
      });
    }

    // 앱 실행 중 딥링크 수신 (백그라운드 → 포그라운드)
    _linkSub = appLinks.uriLinkStream.listen(_handleLink);
  }

  void _handleLink(Uri uri) {
    String? type;
    String? postId;

    if (uri.scheme == 'https' && uri.host == 'daengnyang-c80e5.web.app') {
      // Firebase Hosting: https://daengnyang-c80e5.web.app/post/{id} 또는 /trade/{id}
      final segments = uri.pathSegments;
      if (segments.length >= 2) {
        type = segments[0];
        postId = segments[1];
      }
    } else if (uri.host == 'kakaolink') {
      // 카카오링크: kakaoc429d12217bc74a6b6fcb47d98cffa19://kakaolink?postId=xxx&type=post
      postId = uri.queryParameters['postId'];
      type = uri.queryParameters['type'];
    }

    if (postId != null && (type == 'post' || type == 'trade')) {
      // pushAndRemoveUntil: 스택에서 isFirst(HomeScreen) 위의 모든 라우트를 제거하고
      // PostDetailScreen을 새로 push → 중복 쌓임 방지
      widget.navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => PostDetailScreen(postId: postId!),
        ),
        (route) => route.isFirst,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: widget.navigatorKey,
      title: '이제댕냥',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR')],
      locale: const Locale('ko', 'KR'),
      home: FutureBuilder<bool>(
        future: _shouldShowOnboarding(),
        builder: (context, onboardingSnapshot) {
          if (!onboardingSnapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (onboardingSnapshot.data!) {
            return const OnboardingScreen();
          }
          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            initialData: FirebaseAuth.instance.currentUser,
            builder: (context, authSnapshot) {
              if (authSnapshot.hasData) return const HomeScreen();
              return const LoginScreen();
            },
          );
        },
      ),
    );
  }
}
