import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:minvest_forex_app/app/auth_gate.dart';
import 'package:minvest_forex_app/core/providers/language_provider.dart';
import 'package:minvest_forex_app/core/providers/user_provider.dart';
import 'package:minvest_forex_app/features/auth/services/auth_service.dart';
import 'package:minvest_forex_app/features/signals/models/signal_model.dart';
import 'package:minvest_forex_app/features/signals/services/signal_service.dart';
import 'package:minvest_forex_app/features/signals/screens/signal_detail_screen.dart';
import 'package:minvest_forex_app/features/notifications/providers/notification_provider.dart';
import 'package:minvest_forex_app/firebase_options.dart';
import 'package:minvest_forex_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:minvest_forex_app/features/auth/bloc/auth_bloc.dart';
import 'package:flutter/foundation.dart';

// --- HÀM XỬ LÝ NỀN (GIỮ NGUYÊN) ---
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (message.data['action'] == 'FORCE_LOGOUT') {
    await AuthService().signOut();
  }
}

// --- KHAI BÁO CÁC BIẾN TOÀN CỤC ---
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await FirebaseMessaging.instance.requestPermission();

  if (kIsWeb) {
    final fcmToken = await FirebaseMessaging.instance.getToken(
      vapidKey: "BF1kL9v7A-1bOSz642aCWoZEKvFpjKvkMQuTPd_GXBLxNakYt6apNf9Aa25hGk1QJP0VFrCVRx4B9mO8h5gBUA8",
    );
    print("FCM Token for Web: $fcmToken");
  }

  // Khởi tạo plugin thông báo local
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(
    MultiProvider(
      providers: [
        // Các provider cũ của bạn
        Provider<AuthService>(create: (_) => AuthService()),
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc(
            authService: context.read<AuthService>(),
          ),
        ),
        ChangeNotifierProvider(create: (context) => LanguageProvider()),
        ChangeNotifierProvider(create: (context) => UserProvider()),
        ChangeNotifierProvider(create: (context) => NotificationProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // ▼▼▼ BƯỚC 1: THIẾT LẬP TOÀN BỘ CÁC TRÌNH LẮNG NGHE THÔNG BÁO ▼▼▼
    _setupNotificationListeners();
  }

  void _setupNotificationListeners() {
    // 1. Lắng nghe khi app đang mở (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message received: ${message.data}');

      if (message.data['action'] == 'FORCE_LOGOUT') {
        _showLogoutDialog(message.data['reason']);
        return;
      }

      // Hiển thị thông báo local khi có tín hiệu mới hoặc cập nhật
      final title = message.data['title'];
      final body = message.data['body'];
      if (title != null && body != null) {
        _showLocalNotification(title, body, message.data);
      }
    });

    // 2. Lắng nghe khi người dùng NHẤN vào thông báo (từ trạng thái background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Message opened from background: ${message.data}');
      _handleNotificationNavigation(message.data);
    });

    // 3. Xử lý nếu app được mở từ trạng thái terminated bằng cách nhấn vào thông báo
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('Message opened from terminated: ${message.data}');
        _handleNotificationNavigation(message.data);
      }
    });
  }

  // ▼▼▼ BƯỚC 2: HÀM ĐIỀU HƯỚNG TỰ ĐỘNG (DEEP-LINKING) ▼▼▼
  Future<void> _handleNotificationNavigation(Map<String, dynamic> data) async {
    final String? signalId = data['signalId'];
    if (signalId == null) return;

    // Đợi một chút để đảm bảo widget tree đã được build xong
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final signal = await SignalService().getSignalById(signalId);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userTier = userProvider.userTier ?? 'free';

      if (signal != null) {
        // Sử dụng navigatorKey để điều hướng
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => SignalDetailScreen(
              signal: signal,
              userTier: userTier,
            ),
          ),
        );
      }
    } catch (e) {
      print('Lỗi khi điều hướng từ thông báo: $e');
    }
  }

  void _showLocalNotification(String title, String body, Map<String, dynamic> payload) {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails('minvest_channel_id', 'Minvest Notifications',
        channelDescription: 'Channel for signal notifications',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: false);
    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);
    flutterLocalNotificationsPlugin.show(
        0, title, body, platformChannelSpecifics,
        payload: payload['signalId']
    );
  }

  void _showLogoutDialog(String? reason) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Phiên đăng nhập hết hạn'),
            content: Text(reason ?? 'Tài khoản của bạn đã được đăng nhập trên một thiết bị khác.'),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await AuthService().signOut();
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'Minvest Forex App',
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF121212),
            appBarTheme: const AppBarTheme(
              elevation: 0,
              centerTitle: true,
              backgroundColor: Color(0xFF1F1F1F),
            ),
          ),
          locale: languageProvider.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AuthGate(),
        );
      },
    );
  }
}