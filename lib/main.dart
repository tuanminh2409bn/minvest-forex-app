import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:minvest_forex_app/app/auth_gate.dart';
import 'package:minvest_forex_app/core/providers/language_provider.dart';
import 'package:minvest_forex_app/core/providers/user_provider.dart';
import 'package:minvest_forex_app/core/services/purchase_service.dart';
import 'package:minvest_forex_app/features/auth/bloc/auth_bloc.dart';
import 'package:minvest_forex_app/features/auth/services/auth_service.dart';
import 'package:minvest_forex_app/features/notifications/providers/notification_provider.dart';
import 'package:minvest_forex_app/features/signals/screens/signal_detail_screen.dart';
import 'package:minvest_forex_app/features/signals/services/signal_service.dart';
import 'package:minvest_forex_app/firebase_options.dart';
import 'package:minvest_forex_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:minvest_forex_app/services/session_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (message.data['action'] == 'FORCE_LOGOUT') {
  }
}


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<SessionService>(create: (_) => SessionService()),
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc(
            authService: context.read<AuthService>(),
            sessionService: context.read<SessionService>(),
          ),
        ),
        ChangeNotifierProvider(create: (context) => LanguageProvider()),
        ChangeNotifierProvider(
          create: (context) => UserProvider(
            authService: context.read<AuthService>(),
          ),
        ),
        ChangeNotifierProvider(create: (context) => NotificationProvider()),
        // --- THAY ĐỔI 2: ĐƯA PURCHASE_SERVICE LÊN TẦNG CAO NHẤT ---
        ChangeNotifierProvider(create: (context) => PurchaseService()),
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
  StreamSubscription<String>? _forceLogoutSubscription;
  bool _isLogoutDialogShowing = false;

  @override
  void initState() {
    super.initState();
    // Đổi tên hàm để bao quát hơn
    _initializeCoreServices();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      print("[DEBUG_LOGOUT] initState: Bắt đầu đăng ký listener...");
      if (mounted) {
        final authService = context.read<AuthService>();
        _forceLogoutSubscription = authService.forceLogoutStream.listen((reason) {
          print("[DEBUG_LOGOUT] LISTENER: Đã nhận được tín hiệu logout! Lý do: $reason");

          if (mounted && !_isLogoutDialogShowing) {
            print("[DEBUG_LOGOUT] LISTENER: Điều kiện hợp lệ. Chuẩn bị hiển thị dialog.");
            setState(() {
              _isLogoutDialogShowing = true;
            });
            _showLogoutDialog(reason);
          } else {
            print("[DEBUG_LOGOUT] LISTENER: Bỏ qua vì không hợp lệ (mounted: $mounted, isShowing: $_isLogoutDialogShowing)");
          }
        });
        print("[DEBUG_LOGOUT] initState: Đã đăng ký listener thành công.");
      } else {
        print("[DEBUG_LOGOUT] initState: Hủy đăng ký vì widget unmounted.");
      }
    });
  }

  @override
  void dispose() {
    print("[DEBUG_LOGOUT] dispose: Hủy đăng ký listener.");
    _forceLogoutSubscription?.cancel();
    super.dispose();
  }

  // --- THAY ĐỔI 3: KHỞI TẠO PURCHASE_SERVICE NGAY KHI APP CHẠY ---
  Future<void> _initializeCoreServices() async {
    // Khởi tạo PurchaseService ngay lập tức để bắt đầu lắng nghe
    context.read<PurchaseService>().initialize();
    debugPrint("✅ Đã gọi initialize() cho PurchaseService từ MyApp.");

    // Logic cũ của bạn vẫn được giữ nguyên
    if (!kIsWeb) {
      const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {
          if (notificationResponse.payload != null) {
            print('Local notification tapped with payload: ${notificationResponse.payload}');
            _handleNotificationNavigation({'signalId': notificationResponse.payload});
          }
        },
      );

      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    await _setupNotificationListeners();
  }

  Future<void> _setupNotificationListeners() async {
    await FirebaseMessaging.instance.requestPermission();
    if (kIsWeb) {
      final fcmToken = await FirebaseMessaging.instance.getToken(
        vapidKey: "BF1kL9v7A-1bOSz642aCWoZEKvFpjKvkMQuTPd_GXBLxNakYt6apNf9Aa25hGk1QJP0VFrCVRx4B9mO8h5gBUA8",
      );
      print("FCM Token for Web: $fcmToken");
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message received: ${message.data}');
      if (message.data['action'] == 'FORCE_LOGOUT') {
        _showLogoutDialog(message.data['reason']);
        return;
      }
      final title = message.data['title'];
      final body = message.data['body'];
      if (title != null && body != null && !kIsWeb) {
        _showLocalNotification(title, body, message.data);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Message opened from background: ${message.data}');
      _handleNotificationNavigation(message.data);
    });

    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('Message opened from terminated: ${message.data}');
        _handleNotificationNavigation(message.data);
      }
    });
  }

  Future<void> _handleNotificationNavigation(Map<String, dynamic> data) async {
    final String? signalId = data['signalId'];
    if (signalId == null) return;
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      final signal = await SignalService().getSignalById(signalId);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userTier = userProvider.userTier ?? 'free';
      if (signal != null) {
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
    flutterLocalNotificationsPlugin.show(0, title, body, platformChannelSpecifics,
        payload: payload['signalId']);
  }

  void _showLogoutDialog(String? reason) {
    print("[DEBUG_LOGOUT] SHOW_DIALOG: Bắt đầu thực thi.");
    final context = navigatorKey.currentContext;
    print("[DEBUG_LOGOUT] SHOW_DIALOG: navigatorKey.currentContext có giá trị là: ${context != null ? 'HỢP LỆ' : 'NULL'}");

    if (context == null) {
      if (mounted) setState(() => _isLogoutDialogShowing = false);
      return;
    }

    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.logoutDialogTitle),
          content: Text(reason ?? l10n.logoutDialogDefaultReason),
          actions: <Widget>[
            TextButton(
              child: Text(l10n.ok),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await this.context.read<AuthService>().signOut();
              },
            ),
          ],
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _isLogoutDialogShowing = false;
        });
      }
    });
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