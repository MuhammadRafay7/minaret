import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_ur.dart';

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
    Locale('ru'),
    Locale('ur'),
  ];

  /// No description provided for @morningReflection.
  ///
  /// In en, this message translates to:
  /// **'MORNING REFLECTION'**
  String get morningReflection;

  /// No description provided for @afternoonCongregation.
  ///
  /// In en, this message translates to:
  /// **'AFTERNOON CONGREGATION'**
  String get afternoonCongregation;

  /// No description provided for @eveningDevotion.
  ///
  /// In en, this message translates to:
  /// **'EVENING DEVOTION'**
  String get eveningDevotion;

  /// No description provided for @searchRegistry.
  ///
  /// In en, this message translates to:
  /// **'SEARCH REGISTRY'**
  String get searchRegistry;

  /// No description provided for @nearestProximity.
  ///
  /// In en, this message translates to:
  /// **'NEAREST PROXIMITY'**
  String get nearestProximity;

  /// No description provided for @temporalOrder.
  ///
  /// In en, this message translates to:
  /// **'TEMPORAL ORDER'**
  String get temporalOrder;

  /// No description provided for @premiumAccess.
  ///
  /// In en, this message translates to:
  /// **'PREMIUM ACCESS'**
  String get premiumAccess;

  /// No description provided for @supportPlatformArchive.
  ///
  /// In en, this message translates to:
  /// **'SUPPORT THE PLATFORM ARCHIVE'**
  String get supportPlatformArchive;

  /// No description provided for @archiveVacant.
  ///
  /// In en, this message translates to:
  /// **'ARCHIVE VACANT'**
  String get archiveVacant;

  /// No description provided for @noRegistriesNearby.
  ///
  /// In en, this message translates to:
  /// **'NO REGISTRIES WITHIN 20KM'**
  String get noRegistriesNearby;

  /// No description provided for @establishNew.
  ///
  /// In en, this message translates to:
  /// **'ESTABLISH NEW +'**
  String get establishNew;

  /// No description provided for @atelierTitle.
  ///
  /// In en, this message translates to:
  /// **'ATELIER'**
  String get atelierTitle;

  /// No description provided for @minaretTitle.
  ///
  /// In en, this message translates to:
  /// **'MINARET'**
  String get minaretTitle;

  /// No description provided for @globalHeader.
  ///
  /// In en, this message translates to:
  /// **'GLOBAL'**
  String get globalHeader;

  /// No description provided for @congregationArchive.
  ///
  /// In en, this message translates to:
  /// **'CONGREGATION ARCHIVE'**
  String get congregationArchive;

  /// No description provided for @searchGlobalHint.
  ///
  /// In en, this message translates to:
  /// **'SEARCH BY NAME, CITY, OR COUNTRY'**
  String get searchGlobalHint;

  /// No description provided for @noMatchesArchive.
  ///
  /// In en, this message translates to:
  /// **'NO MATCHES IN ARCHIVE'**
  String get noMatchesArchive;

  /// No description provided for @registryHeader.
  ///
  /// In en, this message translates to:
  /// **'REGISTRY'**
  String get registryHeader;

  /// No description provided for @managementInterfaceSub.
  ///
  /// In en, this message translates to:
  /// **'MANAGEMENT INTERFACE'**
  String get managementInterfaceSub;

  /// No description provided for @temporalScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'TEMPORAL SCHEDULE'**
  String get temporalScheduleTitle;

  /// No description provided for @congregationalEventsTitle.
  ///
  /// In en, this message translates to:
  /// **'CONGREGATIONAL EVENTS'**
  String get congregationalEventsTitle;

  /// No description provided for @physicalSpecsTitle.
  ///
  /// In en, this message translates to:
  /// **'PHYSICAL SPECIFICATIONS'**
  String get physicalSpecsTitle;

  /// No description provided for @fieldEstablished.
  ///
  /// In en, this message translates to:
  /// **'ESTABLISHED'**
  String get fieldEstablished;

  /// No description provided for @fieldArea.
  ///
  /// In en, this message translates to:
  /// **'AREA (SQ FT)'**
  String get fieldArea;

  /// No description provided for @fieldImams.
  ///
  /// In en, this message translates to:
  /// **'IMAMS'**
  String get fieldImams;

  /// No description provided for @fieldStudents.
  ///
  /// In en, this message translates to:
  /// **'STUDENTS'**
  String get fieldStudents;

  /// No description provided for @fieldDescription.
  ///
  /// In en, this message translates to:
  /// **'CHRONICLE / DESCRIPTION'**
  String get fieldDescription;

  /// No description provided for @prayerFajr.
  ///
  /// In en, this message translates to:
  /// **'FAJR'**
  String get prayerFajr;

  /// No description provided for @prayerDhuhr.
  ///
  /// In en, this message translates to:
  /// **'DHUHR'**
  String get prayerDhuhr;

  /// No description provided for @prayerAsr.
  ///
  /// In en, this message translates to:
  /// **'ASR'**
  String get prayerAsr;

  /// No description provided for @prayerMaghrib.
  ///
  /// In en, this message translates to:
  /// **'MAGHRIB'**
  String get prayerMaghrib;

  /// No description provided for @prayerIsha.
  ///
  /// In en, this message translates to:
  /// **'ISHA'**
  String get prayerIsha;

  /// No description provided for @eventJummah.
  ///
  /// In en, this message translates to:
  /// **'FRIDAY JUMMAH'**
  String get eventJummah;

  /// No description provided for @eventEidFitr.
  ///
  /// In en, this message translates to:
  /// **'EID-UL-FITR'**
  String get eventEidFitr;

  /// No description provided for @eventEidAdha.
  ///
  /// In en, this message translates to:
  /// **'EID-UL-ADHA'**
  String get eventEidAdha;

  /// No description provided for @confirmListingButton.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM LISTING'**
  String get confirmListingButton;

  /// No description provided for @deleteListingButton.
  ///
  /// In en, this message translates to:
  /// **'DELETE LISTING'**
  String get deleteListingButton;

  /// No description provided for @archiveRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'ARCHIVE RECORD'**
  String get archiveRecordTitle;

  /// No description provided for @deleteConfirmationPrompt.
  ///
  /// In en, this message translates to:
  /// **'ARE YOU CERTAIN YOU WISH TO PERMANENTLY REMOVE THIS CONGREGATION FROM THE REGISTRY?'**
  String get deleteConfirmationPrompt;

  /// No description provided for @cancelAction.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get cancelAction;

  /// No description provided for @deleteAction.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get deleteAction;

  /// No description provided for @synchronizedStatus.
  ///
  /// In en, this message translates to:
  /// **'SYNCHRONIZED'**
  String get synchronizedStatus;

  /// No description provided for @recordUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'The congregation record has been updated.'**
  String get recordUpdatedMessage;

  /// No description provided for @errorNameRequired.
  ///
  /// In en, this message translates to:
  /// **'NAME IS REQUIRED.'**
  String get errorNameRequired;

  /// No description provided for @errorDeletionFailed.
  ///
  /// In en, this message translates to:
  /// **'DELETION FAILED.'**
  String get errorDeletionFailed;

  /// No description provided for @errorUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'UPDATE FAILED.'**
  String get errorUpdateFailed;

  /// No description provided for @administrativeAccessLabel.
  ///
  /// In en, this message translates to:
  /// **'ADMINISTRATIVE ACCESS'**
  String get administrativeAccessLabel;

  /// No description provided for @sanctuaryProfileLabel.
  ///
  /// In en, this message translates to:
  /// **'SANCTUARY PROFILE'**
  String get sanctuaryProfileLabel;

  /// No description provided for @defaultMasjidName.
  ///
  /// In en, this message translates to:
  /// **'MASJID'**
  String get defaultMasjidName;

  /// No description provided for @dailyCongregationHeader.
  ///
  /// In en, this message translates to:
  /// **'DAILY CONGREGATION'**
  String get dailyCongregationHeader;

  /// No description provided for @weeklyAnnualHeader.
  ///
  /// In en, this message translates to:
  /// **'WEEKLY & ANNUAL'**
  String get weeklyAnnualHeader;

  /// No description provided for @architecturalSpecsHeader.
  ///
  /// In en, this message translates to:
  /// **'ARCHITECTURAL SPECS'**
  String get architecturalSpecsHeader;

  /// No description provided for @chronicleHeader.
  ///
  /// In en, this message translates to:
  /// **'CHRONICLE'**
  String get chronicleHeader;

  /// No description provided for @getDirectionsButton.
  ///
  /// In en, this message translates to:
  /// **'GET DIRECTIONS'**
  String get getDirectionsButton;

  /// No description provided for @archiveEntryButton.
  ///
  /// In en, this message translates to:
  /// **'ARCHIVE THIS ENTRY'**
  String get archiveEntryButton;

  /// No description provided for @noDescriptionText.
  ///
  /// In en, this message translates to:
  /// **'No historical details provided.'**
  String get noDescriptionText;

  /// No description provided for @unitSqFt.
  ///
  /// In en, this message translates to:
  /// **'SQFT'**
  String get unitSqFt;

  /// No description provided for @unitImams.
  ///
  /// In en, this message translates to:
  /// **'IMAMS'**
  String get unitImams;

  /// No description provided for @unitStudents.
  ///
  /// In en, this message translates to:
  /// **'STUDENTS'**
  String get unitStudents;

  /// No description provided for @statLeadership.
  ///
  /// In en, this message translates to:
  /// **'LEADERSHIP'**
  String get statLeadership;

  /// No description provided for @statAcademy.
  ///
  /// In en, this message translates to:
  /// **'ACADEMY'**
  String get statAcademy;

  /// No description provided for @registrationTitle.
  ///
  /// In en, this message translates to:
  /// **'REGISTRATION'**
  String get registrationTitle;

  /// No description provided for @registrationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ESTABLISH NEW CONGREGATION'**
  String get registrationSubtitle;

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'OFFICIAL NAME'**
  String get fieldName;

  /// No description provided for @fieldAddress.
  ///
  /// In en, this message translates to:
  /// **'PHYSICAL ADDRESS'**
  String get fieldAddress;

  /// No description provided for @fieldImageUrl.
  ///
  /// In en, this message translates to:
  /// **'PASTE IMAGE URL HERE'**
  String get fieldImageUrl;

  /// No description provided for @sectionVisual.
  ///
  /// In en, this message translates to:
  /// **'ARCHITECTURAL VISUAL'**
  String get sectionVisual;

  /// No description provided for @sectionSchedule.
  ///
  /// In en, this message translates to:
  /// **'SCHEDULE DEFAULTS'**
  String get sectionSchedule;

  /// No description provided for @sectionCoordinates.
  ///
  /// In en, this message translates to:
  /// **'GEOGRAPHIC COORDINATES'**
  String get sectionCoordinates;

  /// No description provided for @locationStatusIdentifying.
  ///
  /// In en, this message translates to:
  /// **'IDENTIFYING...'**
  String get locationStatusIdentifying;

  /// No description provided for @locationStatusSecured.
  ///
  /// In en, this message translates to:
  /// **'POSITION SECURED'**
  String get locationStatusSecured;

  /// No description provided for @locationActionPin.
  ///
  /// In en, this message translates to:
  /// **'PIN CURRENT LOCATION'**
  String get locationActionPin;

  /// No description provided for @establishRegistryAction.
  ///
  /// In en, this message translates to:
  /// **'ESTABLISH REGISTRY'**
  String get establishRegistryAction;

  /// No description provided for @successRegistryTitle.
  ///
  /// In en, this message translates to:
  /// **'REGISTRY COMPLETE'**
  String get successRegistryTitle;

  /// No description provided for @successRegistryMessage.
  ///
  /// In en, this message translates to:
  /// **'The congregation has been established'**
  String get successRegistryMessage;

  /// No description provided for @errorLocationDenied.
  ///
  /// In en, this message translates to:
  /// **'LOCATION PERMISSION DENIED OR TIMED OUT'**
  String get errorLocationDenied;

  /// No description provided for @errorRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'NAME AND GEOLOCATION REQUIRED'**
  String get errorRequiredFields;

  /// No description provided for @errorDatabaseSync.
  ///
  /// In en, this message translates to:
  /// **'DATABASE SYNC FAILED'**
  String get errorDatabaseSync;

  /// No description provided for @authLoginGreeting.
  ///
  /// In en, this message translates to:
  /// **'BISMILLAH'**
  String get authLoginGreeting;

  /// No description provided for @authRegisterGreeting.
  ///
  /// In en, this message translates to:
  /// **'JOIN US'**
  String get authRegisterGreeting;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ENTER THE PORTAL'**
  String get authLoginSubtitle;

  /// No description provided for @authRegStep1.
  ///
  /// In en, this message translates to:
  /// **'STEP 01: BEGINNING'**
  String get authRegStep1;

  /// No description provided for @authRegStep2.
  ///
  /// In en, this message translates to:
  /// **'STEP 02: DESIGNATION'**
  String get authRegStep2;

  /// No description provided for @authActionSignIn.
  ///
  /// In en, this message translates to:
  /// **'SIGN IN'**
  String get authActionSignIn;

  /// No description provided for @authActionProceed.
  ///
  /// In en, this message translates to:
  /// **'PROCEED'**
  String get authActionProceed;

  /// No description provided for @authActionEstablish.
  ///
  /// In en, this message translates to:
  /// **'ESTABLISH ACCOUNT'**
  String get authActionEstablish;

  /// No description provided for @authSwitchToRegister.
  ///
  /// In en, this message translates to:
  /// **'REQUEST NEW ACCESS'**
  String get authSwitchToRegister;

  /// No description provided for @authSwitchToLogin.
  ///
  /// In en, this message translates to:
  /// **'RETURN TO PORTAL'**
  String get authSwitchToLogin;

  /// No description provided for @authActionReviseEmail.
  ///
  /// In en, this message translates to:
  /// **'REVISE EMAIL'**
  String get authActionReviseEmail;

  /// No description provided for @fieldEmail.
  ///
  /// In en, this message translates to:
  /// **'EMAIL ADDRESS'**
  String get fieldEmail;

  /// No description provided for @fieldPassword.
  ///
  /// In en, this message translates to:
  /// **'SECURE PASSWORD'**
  String get fieldPassword;

  /// No description provided for @fieldSetPassword.
  ///
  /// In en, this message translates to:
  /// **'SET SECURE PASSWORD'**
  String get fieldSetPassword;

  /// No description provided for @sectionDesignation.
  ///
  /// In en, this message translates to:
  /// **'SELECT DESIGNATION'**
  String get sectionDesignation;

  /// No description provided for @roleCommunity.
  ///
  /// In en, this message translates to:
  /// **'COMMUNITY'**
  String get roleCommunity;

  /// No description provided for @roleImam.
  ///
  /// In en, this message translates to:
  /// **'IMAM / LEAD'**
  String get roleImam;

  /// No description provided for @profileHeader.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get profileHeader;

  /// No description provided for @profileSessionActive.
  ///
  /// In en, this message translates to:
  /// **'MOMINEEN SESSION ACTIVE'**
  String get profileSessionActive;

  /// No description provided for @profileIdentifiedAs.
  ///
  /// In en, this message translates to:
  /// **'IDENTIFIED AS'**
  String get profileIdentifiedAs;

  /// No description provided for @profileAnonymous.
  ///
  /// In en, this message translates to:
  /// **'ANONYMOUS'**
  String get profileAnonymous;

  /// No description provided for @profileEndSession.
  ///
  /// In en, this message translates to:
  /// **'END SESSION'**
  String get profileEndSession;

  /// No description provided for @authSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'ACCESS GRANTED'**
  String get authSuccessTitle;

  /// No description provided for @authSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Profile established successfully'**
  String get authSuccessMessage;

  /// No description provided for @authErrorFillFields.
  ///
  /// In en, this message translates to:
  /// **'PLEASE FILL ALL FIELDS'**
  String get authErrorFillFields;

  /// No description provided for @authErrorPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'PASSWORD REQUIRED'**
  String get authErrorPasswordRequired;

  /// No description provided for @authErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'AUTHENTICATION ERROR'**
  String get authErrorGeneric;
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
      <String>['en', 'ru', 'ur'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
