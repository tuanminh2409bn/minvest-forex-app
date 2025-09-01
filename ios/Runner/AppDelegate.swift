import UIKit
import Flutter
import Firebase // Đảm bảo đã import Firebase

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Dòng này cần được thêm vào TRƯỚC GeneratedPluginRegistrant
    FirebaseApp.configure()

    GeneratedPluginRegistrant.register(with: self)

    // **Thêm đoạn mã này vào**
    // Đăng ký nhận thông báo đẩy
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // **Thêm hàm này vào**
  // Xử lý khi đăng ký thành công và nhận được device token
  override func application(_ application: UIApplication,
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
    print("APNS token retrieved: \(deviceToken)")
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // **Thêm hàm này vào**
  // Xử lý khi đăng ký thất bại
  override func application(_ application: UIApplication,
                            didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("Failed to register for remote notifications: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}