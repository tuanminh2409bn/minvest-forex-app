import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi')
  ];

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// No description provided for @loginToContinue.
  ///
  /// In en, this message translates to:
  /// **'Login to continue'**
  String get loginToContinue;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginButton;

  /// No description provided for @loginWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get loginWithGoogle;

  /// No description provided for @entry.
  ///
  /// In en, this message translates to:
  /// **'Entry'**
  String get entry;

  /// No description provided for @stopLoss.
  ///
  /// In en, this message translates to:
  /// **'Stop Loss'**
  String get stopLoss;

  /// No description provided for @takeProfit1.
  ///
  /// In en, this message translates to:
  /// **'TP1'**
  String get takeProfit1;

  /// No description provided for @takeProfit2.
  ///
  /// In en, this message translates to:
  /// **'TP2'**
  String get takeProfit2;

  /// No description provided for @takeProfit3.
  ///
  /// In en, this message translates to:
  /// **'TP3'**
  String get takeProfit3;

  /// No description provided for @signalTypeBuy.
  ///
  /// In en, this message translates to:
  /// **'BUY'**
  String get signalTypeBuy;

  /// No description provided for @signalTypeSell.
  ///
  /// In en, this message translates to:
  /// **'SELL'**
  String get signalTypeSell;

  /// No description provided for @tabRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get tabRunning;

  /// No description provided for @tabHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get tabHistory;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @upgradeAccount.
  ///
  /// In en, this message translates to:
  /// **'Upgrade Account'**
  String get upgradeAccount;

  /// No description provided for @upgradeAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Submit a new screenshot to upgrade your tier.'**
  String get upgradeAccountSubtitle;

  /// No description provided for @upgradeScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrade Account Tier'**
  String get upgradeScreenTitle;

  /// No description provided for @compareTiers.
  ///
  /// In en, this message translates to:
  /// **'Compare Tiers'**
  String get compareTiers;

  /// No description provided for @feature.
  ///
  /// In en, this message translates to:
  /// **'Feature'**
  String get feature;

  /// No description provided for @tierDemo.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get tierDemo;

  /// No description provided for @tierVIP.
  ///
  /// In en, this message translates to:
  /// **'VIP'**
  String get tierVIP;

  /// No description provided for @tierElite.
  ///
  /// In en, this message translates to:
  /// **'Elite'**
  String get tierElite;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @signalTime.
  ///
  /// In en, this message translates to:
  /// **'Signal Time'**
  String get signalTime;

  /// No description provided for @signalQty.
  ///
  /// In en, this message translates to:
  /// **'Signal Qty'**
  String get signalQty;

  /// No description provided for @analysis.
  ///
  /// In en, this message translates to:
  /// **'Analysis'**
  String get analysis;

  /// No description provided for @mobileWebApp.
  ///
  /// In en, this message translates to:
  /// **'Mobile & Web App'**
  String get mobileWebApp;

  /// No description provided for @uploadPrompt.
  ///
  /// In en, this message translates to:
  /// **'Upload a screenshot of your Exness account with a new balance.'**
  String get uploadPrompt;

  /// No description provided for @statusImageSelected.
  ///
  /// In en, this message translates to:
  /// **'Image selected. Press \'Submit\' to verify.'**
  String get statusImageSelected;

  /// No description provided for @statusUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading, please wait...'**
  String get statusUploading;

  /// No description provided for @statusUploadSuccess.
  ///
  /// In en, this message translates to:
  /// **'Upload successful! Please wait a few hours for admin review.'**
  String get statusUploadSuccess;

  /// No description provided for @statusUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Please try again.'**
  String get statusUploadFailed;

  /// No description provided for @buttonSelectScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Select New Screenshot'**
  String get buttonSelectScreenshot;

  /// No description provided for @buttonSubmitReview.
  ///
  /// In en, this message translates to:
  /// **'Submit for Review'**
  String get buttonSubmitReview;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @signUpButton.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUpButton;

  /// No description provided for @tabSignal.
  ///
  /// In en, this message translates to:
  /// **'Signal'**
  String get tabSignal;

  /// No description provided for @tabChart.
  ///
  /// In en, this message translates to:
  /// **'Chart'**
  String get tabChart;

  /// No description provided for @tabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
