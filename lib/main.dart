import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:minvest_forex_app/app/auth_gate.dart';
import 'package:minvest_forex_app/core/providers/language_provider.dart';
import 'package:minvest_forex_app/firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:minvest_forex_app/l10n/app_localizations.dart';
import 'package:minvest_forex_app/core/providers/user_provider.dart';

// ▼▼▼ THÊM IMPORT NÀY ▼▼▼
import 'package:firebase_messaging/firebase_messaging.dart';

// ▼▼▼ THÊM HÀM NÀY BÊN NGOÀI main() ▼▼▼
// Xử lý thông báo khi app đang ở trạng thái terminated (bị tắt hoàn toàn)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Bạn cần đảm bảo Firebase đã được khởi tạo
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
  // Tại đây bạn có thể xử lý logic sâu hơn nếu cần
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ▼▼▼ THÊM DÒNG NÀY ▼▼▼
  // Đăng ký hàm xử lý thông báo nền
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    MultiProvider( // Dùng MultiProvider
      providers: [
        ChangeNotifierProvider(create: (context) => LanguageProvider()),
        ChangeNotifierProvider(create: (context) => UserProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        // Trả về MaterialApp với locale được cập nhật từ provider
        return MaterialApp(
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
          // Sử dụng locale từ provider
          locale: languageProvider.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AuthGate(),
        );
      },
    );
  }
}