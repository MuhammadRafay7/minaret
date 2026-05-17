import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_ur.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
    Locale('ar'),
    Locale('en'),
    Locale('fa'),
    Locale('nl'),
    Locale('ru'),
    Locale('ur'),
    Locale('zh')
  ];

  /// No description provided for @morningReflection.
  ///
  /// In en, this message translates to:
  /// **'Morning Reflection'**
  String get morningReflection;

  /// No description provided for @afternoonCongregation.
  ///
  /// In en, this message translates to:
  /// **'Afternoon Congregation'**
  String get afternoonCongregation;

  /// No description provided for @eveningDevotion.
  ///
  /// In en, this message translates to:
  /// **'Evening Devotion'**
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

  /// No description provided for @favourite.
  ///
  /// In en, this message translates to:
  /// **'FOLLOWING'**
  String get favourite;

  /// No description provided for @premiumAccess.
  ///
  /// In en, this message translates to:
  /// **'PREMIUM ACCESS'**
  String get premiumAccess;

  /// No description provided for @supportPlatformArchive.
  ///
  /// In en, this message translates to:
  /// **'Support Platform Archive'**
  String get supportPlatformArchive;

  /// No description provided for @archiveVacant.
  ///
  /// In en, this message translates to:
  /// **'Archive is Vacant'**
  String get archiveVacant;

  /// No description provided for @noRegistriesNearby.
  ///
  /// In en, this message translates to:
  /// **'No registries found within 20km'**
  String get noRegistriesNearby;

  /// No description provided for @establishNew.
  ///
  /// In en, this message translates to:
  /// **'+ ESTABLISH NEW'**
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
  /// **'Global'**
  String get globalHeader;

  /// No description provided for @congregationArchive.
  ///
  /// In en, this message translates to:
  /// **'Congregation Archive'**
  String get congregationArchive;

  /// No description provided for @searchGlobalHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, city, or country'**
  String get searchGlobalHint;

  /// No description provided for @noMatchesArchive.
  ///
  /// In en, this message translates to:
  /// **'No results found in archive'**
  String get noMatchesArchive;

  /// No description provided for @registryHeader.
  ///
  /// In en, this message translates to:
  /// **'Registry'**
  String get registryHeader;

  /// No description provided for @managementInterfaceSub.
  ///
  /// In en, this message translates to:
  /// **'Management Interface'**
  String get managementInterfaceSub;

  /// No description provided for @quranTitle.
  ///
  /// In en, this message translates to:
  /// **'The Holy Quran'**
  String get quranTitle;

  /// No description provided for @hadithTitle.
  ///
  /// In en, this message translates to:
  /// **'Prophetic Hadiths'**
  String get hadithTitle;

  /// No description provided for @collectionHeader.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get collectionHeader;

  /// No description provided for @indexingArchive.
  ///
  /// In en, this message translates to:
  /// **'Indexing Archive'**
  String get indexingArchive;

  /// No description provided for @backToCollection.
  ///
  /// In en, this message translates to:
  /// **'Back to Collection'**
  String get backToCollection;

  /// No description provided for @searchWithinBook.
  ///
  /// In en, this message translates to:
  /// **'Search Within'**
  String get searchWithinBook;

  /// No description provided for @copyRegistry.
  ///
  /// In en, this message translates to:
  /// **'Copy to Registry'**
  String get copyRegistry;

  /// No description provided for @extendArchive.
  ///
  /// In en, this message translates to:
  /// **'Extend Archive'**
  String get extendArchive;

  /// No description provided for @verseNumber.
  ///
  /// In en, this message translates to:
  /// **'Verse No.'**
  String get verseNumber;

  /// No description provided for @hadithNumber.
  ///
  /// In en, this message translates to:
  /// **'Hadith No.'**
  String get hadithNumber;

  /// No description provided for @temporalScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Temporal Schedule'**
  String get temporalScheduleTitle;

  /// No description provided for @congregationalEventsTitle.
  ///
  /// In en, this message translates to:
  /// **'Congregational Events'**
  String get congregationalEventsTitle;

  /// No description provided for @physicalSpecsTitle.
  ///
  /// In en, this message translates to:
  /// **'Physical Specifications'**
  String get physicalSpecsTitle;

  /// No description provided for @fieldEstablished.
  ///
  /// In en, this message translates to:
  /// **'Established Date'**
  String get fieldEstablished;

  /// No description provided for @fieldArea.
  ///
  /// In en, this message translates to:
  /// **'Area (Sq Ft)'**
  String get fieldArea;

  /// No description provided for @fieldImams.
  ///
  /// In en, this message translates to:
  /// **'Imams'**
  String get fieldImams;

  /// No description provided for @fieldStudents.
  ///
  /// In en, this message translates to:
  /// **'Students'**
  String get fieldStudents;

  /// No description provided for @fieldDescription.
  ///
  /// In en, this message translates to:
  /// **'History / Description'**
  String get fieldDescription;

  /// No description provided for @prayerFajr.
  ///
  /// In en, this message translates to:
  /// **'Fajr'**
  String get prayerFajr;

  /// No description provided for @prayerDhuhr.
  ///
  /// In en, this message translates to:
  /// **'Dhuhr'**
  String get prayerDhuhr;

  /// No description provided for @prayerAsr.
  ///
  /// In en, this message translates to:
  /// **'Asr'**
  String get prayerAsr;

  /// No description provided for @prayerMaghrib.
  ///
  /// In en, this message translates to:
  /// **'Maghrib'**
  String get prayerMaghrib;

  /// No description provided for @prayerIsha.
  ///
  /// In en, this message translates to:
  /// **'Isha'**
  String get prayerIsha;

  /// No description provided for @eventJummah.
  ///
  /// In en, this message translates to:
  /// **'Jummah Prayer'**
  String get eventJummah;

  /// No description provided for @eventEidFitr.
  ///
  /// In en, this message translates to:
  /// **'Eid al-Fitr'**
  String get eventEidFitr;

  /// No description provided for @eventEidAdha.
  ///
  /// In en, this message translates to:
  /// **'Eid al-Adha'**
  String get eventEidAdha;

  /// No description provided for @confirmListingButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm Listing'**
  String get confirmListingButton;

  /// No description provided for @deleteListingButton.
  ///
  /// In en, this message translates to:
  /// **'Delete Listing'**
  String get deleteListingButton;

  /// No description provided for @archiveRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive Record'**
  String get archiveRecordTitle;

  /// No description provided for @deleteConfirmationPrompt.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this congregation permanently?'**
  String get deleteConfirmationPrompt;

  /// No description provided for @cancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAction;

  /// No description provided for @deleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAction;

  /// No description provided for @synchronizedStatus.
  ///
  /// In en, this message translates to:
  /// **'Synchronized'**
  String get synchronizedStatus;

  /// No description provided for @recordUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Record updated successfully.'**
  String get recordUpdatedMessage;

  /// No description provided for @errorNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required.'**
  String get errorNameRequired;

  /// No description provided for @errorDeletionFailed.
  ///
  /// In en, this message translates to:
  /// **'Deletion failed.'**
  String get errorDeletionFailed;

  /// No description provided for @errorUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed.'**
  String get errorUpdateFailed;

  /// No description provided for @administrativeAccessLabel.
  ///
  /// In en, this message translates to:
  /// **'Admin Access'**
  String get administrativeAccessLabel;

  /// No description provided for @sanctuaryProfileLabel.
  ///
  /// In en, this message translates to:
  /// **'Sanctuary Profile'**
  String get sanctuaryProfileLabel;

  /// No description provided for @defaultMasjidName.
  ///
  /// In en, this message translates to:
  /// **'Masjid'**
  String get defaultMasjidName;

  /// No description provided for @dailyCongregationHeader.
  ///
  /// In en, this message translates to:
  /// **'Daily Congregation'**
  String get dailyCongregationHeader;

  /// No description provided for @weeklyAnnualHeader.
  ///
  /// In en, this message translates to:
  /// **'Weekly & Annual'**
  String get weeklyAnnualHeader;

  /// No description provided for @architecturalSpecsHeader.
  ///
  /// In en, this message translates to:
  /// **'Architectural Specs'**
  String get architecturalSpecsHeader;

  /// No description provided for @chronicleHeader.
  ///
  /// In en, this message translates to:
  /// **'History Chronicle'**
  String get chronicleHeader;

  /// No description provided for @getDirectionsButton.
  ///
  /// In en, this message translates to:
  /// **'Get Directions'**
  String get getDirectionsButton;

  /// No description provided for @archiveEntryButton.
  ///
  /// In en, this message translates to:
  /// **'Archive Entry'**
  String get archiveEntryButton;

  /// No description provided for @noDescriptionText.
  ///
  /// In en, this message translates to:
  /// **'No historical details available.'**
  String get noDescriptionText;

  /// No description provided for @unitSqFt.
  ///
  /// In en, this message translates to:
  /// **'sq ft'**
  String get unitSqFt;

  /// No description provided for @unitImams.
  ///
  /// In en, this message translates to:
  /// **'imams'**
  String get unitImams;

  /// No description provided for @unitStudents.
  ///
  /// In en, this message translates to:
  /// **'students'**
  String get unitStudents;

  /// No description provided for @statLeadership.
  ///
  /// In en, this message translates to:
  /// **'Leadership'**
  String get statLeadership;

  /// No description provided for @statAcademy.
  ///
  /// In en, this message translates to:
  /// **'Academy'**
  String get statAcademy;

  /// No description provided for @registrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get registrationTitle;

  /// No description provided for @registrationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a new congregation record'**
  String get registrationSubtitle;

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'Official Name'**
  String get fieldName;

  /// No description provided for @fieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Physical Address'**
  String get fieldAddress;

  /// No description provided for @fieldImageUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter Image URL here'**
  String get fieldImageUrl;

  /// No description provided for @sectionVisual.
  ///
  /// In en, this message translates to:
  /// **'Visual Identity'**
  String get sectionVisual;

  /// No description provided for @sectionSchedule.
  ///
  /// In en, this message translates to:
  /// **'Default Schedule Settings'**
  String get sectionSchedule;

  /// No description provided for @sectionCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Geographic Coordinates'**
  String get sectionCoordinates;

  /// No description provided for @locationStatusIdentifying.
  ///
  /// In en, this message translates to:
  /// **'Identifying...'**
  String get locationStatusIdentifying;

  /// No description provided for @locationStatusSecured.
  ///
  /// In en, this message translates to:
  /// **'Location Secured'**
  String get locationStatusSecured;

  /// No description provided for @locationActionPin.
  ///
  /// In en, this message translates to:
  /// **'Pin Current Location'**
  String get locationActionPin;

  /// No description provided for @establishRegistryAction.
  ///
  /// In en, this message translates to:
  /// **'Establish Registry'**
  String get establishRegistryAction;

  /// No description provided for @successRegistryTitle.
  ///
  /// In en, this message translates to:
  /// **'Registry Complete'**
  String get successRegistryTitle;

  /// No description provided for @successRegistryMessage.
  ///
  /// In en, this message translates to:
  /// **'Congregation record created successfully'**
  String get successRegistryMessage;

  /// No description provided for @errorLocationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied or timed out'**
  String get errorLocationDenied;

  /// No description provided for @errorRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Name and location are required'**
  String get errorRequiredFields;

  /// No description provided for @errorDatabaseSync.
  ///
  /// In en, this message translates to:
  /// **'Database sync failed'**
  String get errorDatabaseSync;

  /// No description provided for @authLoginGreeting.
  ///
  /// In en, this message translates to:
  /// **'Bismillah'**
  String get authLoginGreeting;

  /// No description provided for @authRegisterGreeting.
  ///
  /// In en, this message translates to:
  /// **'Join Us'**
  String get authRegisterGreeting;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Access the Portal'**
  String get authLoginSubtitle;

  /// No description provided for @authRegStep1.
  ///
  /// In en, this message translates to:
  /// **'Step 01: Beginning'**
  String get authRegStep1;

  /// No description provided for @authRegStep2.
  ///
  /// In en, this message translates to:
  /// **'Step 02: Designation'**
  String get authRegStep2;

  /// No description provided for @authActionSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get authActionSignIn;

  /// No description provided for @authActionProceed.
  ///
  /// In en, this message translates to:
  /// **'Proceed'**
  String get authActionProceed;

  /// No description provided for @authActionEstablish.
  ///
  /// In en, this message translates to:
  /// **'Establish Account'**
  String get authActionEstablish;

  /// No description provided for @authSwitchToRegister.
  ///
  /// In en, this message translates to:
  /// **'Request New Access'**
  String get authSwitchToRegister;

  /// No description provided for @authSwitchToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to Portal'**
  String get authSwitchToLogin;

  /// No description provided for @authActionReviseEmail.
  ///
  /// In en, this message translates to:
  /// **'Revise Email'**
  String get authActionReviseEmail;

  /// No description provided for @fieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get fieldEmail;

  /// No description provided for @fieldPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// No description provided for @fieldSetPassword.
  ///
  /// In en, this message translates to:
  /// **'Set Password'**
  String get fieldSetPassword;

  /// No description provided for @sectionDesignation.
  ///
  /// In en, this message translates to:
  /// **'Choose Designation'**
  String get sectionDesignation;

  /// No description provided for @roleCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get roleCommunity;

  /// No description provided for @roleImam.
  ///
  /// In en, this message translates to:
  /// **'Imam / Leader'**
  String get roleImam;

  /// No description provided for @profileHeader.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileHeader;

  /// No description provided for @profileSessionActive.
  ///
  /// In en, this message translates to:
  /// **'Believer Session Active'**
  String get profileSessionActive;

  /// No description provided for @profileIdentifiedAs.
  ///
  /// In en, this message translates to:
  /// **'Identified as'**
  String get profileIdentifiedAs;

  /// No description provided for @profileAnonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous'**
  String get profileAnonymous;

  /// No description provided for @profileEndSession.
  ///
  /// In en, this message translates to:
  /// **'End Session'**
  String get profileEndSession;

  /// No description provided for @authSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Permission Granted'**
  String get authSuccessTitle;

  /// No description provided for @authSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Profile established successfully'**
  String get authSuccessMessage;

  /// No description provided for @authErrorFillFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill all fields'**
  String get authErrorFillFields;

  /// No description provided for @authErrorPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get authErrorPasswordRequired;

  /// No description provided for @authErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Authentication Error'**
  String get authErrorGeneric;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get settingsTitle;

  /// No description provided for @sectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'APPEARANCE'**
  String get sectionAppearance;

  /// No description provided for @sectionLanguage.
  ///
  /// In en, this message translates to:
  /// **'LANGUAGE'**
  String get sectionLanguage;

  /// No description provided for @sectionNotifications.
  ///
  /// In en, this message translates to:
  /// **'NOTIFICATIONS'**
  String get sectionNotifications;

  /// No description provided for @sectionPrayerCalc.
  ///
  /// In en, this message translates to:
  /// **'PRAYER CALCULATION'**
  String get sectionPrayerCalc;

  /// No description provided for @sectionDangerZone.
  ///
  /// In en, this message translates to:
  /// **'DANGER ZONE'**
  String get sectionDangerZone;

  /// No description provided for @darkModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkModeLabel;

  /// No description provided for @darkModeSub.
  ///
  /// In en, this message translates to:
  /// **'Use the aged dome aesthetic'**
  String get darkModeSub;

  /// No description provided for @notifAdhanLabel.
  ///
  /// In en, this message translates to:
  /// **'Adhan Alerts'**
  String get notifAdhanLabel;

  /// No description provided for @notifAdhanSub.
  ///
  /// In en, this message translates to:
  /// **'Notification at exact prayer time'**
  String get notifAdhanSub;

  /// No description provided for @notifPrayerLabel.
  ///
  /// In en, this message translates to:
  /// **'Prayer Reminders'**
  String get notifPrayerLabel;

  /// No description provided for @notifPrayerSub.
  ///
  /// In en, this message translates to:
  /// **'5 minutes before congregation'**
  String get notifPrayerSub;

  /// No description provided for @notifJanazaLabel.
  ///
  /// In en, this message translates to:
  /// **'Janaza Alerts'**
  String get notifJanazaLabel;

  /// No description provided for @notifJanazaSub.
  ///
  /// In en, this message translates to:
  /// **'Urgent local funeral notifications'**
  String get notifJanazaSub;

  /// No description provided for @notifEidLabel.
  ///
  /// In en, this message translates to:
  /// **'Eid & Taraweeh'**
  String get notifEidLabel;

  /// No description provided for @notifEidSub.
  ///
  /// In en, this message translates to:
  /// **'Special prayer announcements'**
  String get notifEidSub;

  /// No description provided for @deleteAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountLabel;

  /// No description provided for @deleteAccountSub.
  ///
  /// In en, this message translates to:
  /// **'Permanently remove your identity and data'**
  String get deleteAccountSub;

  /// No description provided for @searchMosquesHint.
  ///
  /// In en, this message translates to:
  /// **'Search mosques...'**
  String get searchMosquesHint;

  /// No description provided for @noMosquesFound.
  ///
  /// In en, this message translates to:
  /// **'NO MOSQUES FOUND'**
  String get noMosquesFound;

  /// No description provided for @radiusLabel.
  ///
  /// In en, this message translates to:
  /// **'RADIUS'**
  String get radiusLabel;

  /// No description provided for @schoolOfThoughtLabel.
  ///
  /// In en, this message translates to:
  /// **'SCHOOL OF THOUGHT'**
  String get schoolOfThoughtLabel;

  /// No description provided for @offlineMode.
  ///
  /// In en, this message translates to:
  /// **'OFFLINE MODE — SOME FEATURES UNAVAILABLE'**
  String get offlineMode;

  /// No description provided for @adminLabel.
  ///
  /// In en, this message translates to:
  /// **'ADMIN'**
  String get adminLabel;

  /// No description provided for @pendingApproval.
  ///
  /// In en, this message translates to:
  /// **'PENDING APPROVAL — WILL BE LISTED AFTER ADMIN APPROVES'**
  String get pendingApproval;

  /// No description provided for @rejectedStatus.
  ///
  /// In en, this message translates to:
  /// **'REJECTED — UPDATE DETAILS AND RESUBMIT'**
  String get rejectedStatus;

  /// No description provided for @adhanPrefix.
  ///
  /// In en, this message translates to:
  /// **'A:'**
  String get adhanPrefix;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'NO DATA'**
  String get noData;

  /// No description provided for @inLabel.
  ///
  /// In en, this message translates to:
  /// **'IN'**
  String get inLabel;

  /// No description provided for @dailyPrayerTracker.
  ///
  /// In en, this message translates to:
  /// **'DAILY PRAYER TRACKER'**
  String get dailyPrayerTracker;

  /// No description provided for @streakLabel.
  ///
  /// In en, this message translates to:
  /// **'{streak} DAY STREAK'**
  String streakLabel(int streak);

  /// No description provided for @localCalculatedTimes.
  ///
  /// In en, this message translates to:
  /// **'LOCAL CALCULATED TIMES'**
  String get localCalculatedTimes;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'NOTIFICATIONS'**
  String get notificationsTitle;

  /// No description provided for @signInToViewNotifications.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to view notifications'**
  String get signInToViewNotifications;

  /// No description provided for @errorLoadingNotifications.
  ///
  /// In en, this message translates to:
  /// **'Error loading notifications'**
  String get errorLoadingNotifications;

  /// No description provided for @noNotificationsYet.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotificationsYet;

  /// No description provided for @mosqueAlertsHere.
  ///
  /// In en, this message translates to:
  /// **'You\'ll see mosque alerts here'**
  String get mosqueAlertsHere;

  /// No description provided for @mosqueNotificationsLabel.
  ///
  /// In en, this message translates to:
  /// **'Mosque Notifications'**
  String get mosqueNotificationsLabel;

  /// No description provided for @mosqueNotificationsSub.
  ///
  /// In en, this message translates to:
  /// **'View mosque alerts and reports'**
  String get mosqueNotificationsSub;

  /// No description provided for @unreadAlertsLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} unread alerts'**
  String unreadAlertsLabel(int count);

  /// No description provided for @prayerStatisticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Prayer Statistics'**
  String get prayerStatisticsLabel;

  /// No description provided for @prayerStatisticsSub.
  ///
  /// In en, this message translates to:
  /// **'View your prayer history and analytics'**
  String get prayerStatisticsSub;

  /// No description provided for @calculationMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get calculationMethodLabel;

  /// No description provided for @madhabAsrLabel.
  ///
  /// In en, this message translates to:
  /// **'Madhab (Asr)'**
  String get madhabAsrLabel;

  /// No description provided for @reAuthBeforeDelete.
  ///
  /// In en, this message translates to:
  /// **'Please re-authenticate before deleting account.'**
  String get reAuthBeforeDelete;

  /// No description provided for @prayerStatisticsTitle.
  ///
  /// In en, this message translates to:
  /// **'PRAYER STATISTICS'**
  String get prayerStatisticsTitle;

  /// No description provided for @signInForPrayerStats.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to view prayer statistics'**
  String get signInForPrayerStats;

  /// No description provided for @last7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get last7Days;

  /// No description provided for @last30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get last30Days;

  /// No description provided for @last90Days.
  ///
  /// In en, this message translates to:
  /// **'Last 90 days'**
  String get last90Days;

  /// No description provided for @noPrayerDataYet.
  ///
  /// In en, this message translates to:
  /// **'No prayer data available yet'**
  String get noPrayerDataYet;

  /// No description provided for @overviewSection.
  ///
  /// In en, this message translates to:
  /// **'OVERVIEW'**
  String get overviewSection;

  /// No description provided for @totalPrayersLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Prayers'**
  String get totalPrayersLabel;

  /// No description provided for @daysPrayedLabel.
  ///
  /// In en, this message translates to:
  /// **'Days Prayed'**
  String get daysPrayedLabel;

  /// No description provided for @completionRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Completion Rate'**
  String get completionRateLabel;

  /// No description provided for @lastPrayerLabel.
  ///
  /// In en, this message translates to:
  /// **'Last Prayer'**
  String get lastPrayerLabel;

  /// No description provided for @streaksSection.
  ///
  /// In en, this message translates to:
  /// **'STREAKS'**
  String get streaksSection;

  /// No description provided for @currentStreakLabel.
  ///
  /// In en, this message translates to:
  /// **'Current Streak'**
  String get currentStreakLabel;

  /// No description provided for @longestStreakLabel.
  ///
  /// In en, this message translates to:
  /// **'Longest Streak'**
  String get longestStreakLabel;

  /// No description provided for @daysUnit.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get daysUnit;

  /// No description provided for @prayerBreakdownSection.
  ///
  /// In en, this message translates to:
  /// **'PRAYER BREAKDOWN'**
  String get prayerBreakdownSection;

  /// No description provided for @prayersCountUnit.
  ///
  /// In en, this message translates to:
  /// **'{count} prayers'**
  String prayersCountUnit(int count);

  /// No description provided for @recentActivitySection.
  ///
  /// In en, this message translates to:
  /// **'RECENT ACTIVITY'**
  String get recentActivitySection;

  /// No description provided for @ofFivePrayers.
  ///
  /// In en, this message translates to:
  /// **'of 5 prayers'**
  String get ofFivePrayers;

  /// No description provided for @deleteRegistryTitle.
  ///
  /// In en, this message translates to:
  /// **'DELETE REGISTRY?'**
  String get deleteRegistryTitle;

  /// No description provided for @deletePermanentlyAction.
  ///
  /// In en, this message translates to:
  /// **'DELETE PERMANENTLY'**
  String get deletePermanentlyAction;

  /// No description provided for @registryDeletedMessage.
  ///
  /// In en, this message translates to:
  /// **'REGISTRY PERMANENTLY DELETED'**
  String get registryDeletedMessage;

  /// No description provided for @failedToDeleteRegistry.
  ///
  /// In en, this message translates to:
  /// **'FAILED TO DELETE REGISTRY'**
  String get failedToDeleteRegistry;

  /// No description provided for @saveChangesAction.
  ///
  /// In en, this message translates to:
  /// **'SAVE CHANGES'**
  String get saveChangesAction;

  /// No description provided for @deleteRegistryAction.
  ///
  /// In en, this message translates to:
  /// **'DELETE REGISTRY'**
  String get deleteRegistryAction;

  /// No description provided for @azanLabel.
  ///
  /// In en, this message translates to:
  /// **'AZAN'**
  String get azanLabel;

  /// No description provided for @iqamahLabel.
  ///
  /// In en, this message translates to:
  /// **'IQAMAH'**
  String get iqamahLabel;

  /// No description provided for @unableToLoadMosque.
  ///
  /// In en, this message translates to:
  /// **'UNABLE TO LOAD MOSQUE'**
  String get unableToLoadMosque;

  /// No description provided for @failedToSyncPrayer.
  ///
  /// In en, this message translates to:
  /// **'Failed to sync prayer. Check connection.'**
  String get failedToSyncPrayer;

  /// No description provided for @maintenanceTitle.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM MAINTENANCE'**
  String get maintenanceTitle;

  /// No description provided for @maintenanceBody.
  ///
  /// In en, this message translates to:
  /// **'We are currently performing scheduled improvements. Please check back shortly.'**
  String get maintenanceBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'ar',
        'en',
        'fa',
        'nl',
        'ru',
        'ur',
        'zh'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fa':
      return AppLocalizationsFa();
    case 'nl':
      return AppLocalizationsNl();
    case 'ru':
      return AppLocalizationsRu();
    case 'ur':
      return AppLocalizationsUr();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
