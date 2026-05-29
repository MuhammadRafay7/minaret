import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_id.dart';
import 'app_localizations_ms.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_tr.dart';
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
    Locale('de'),
    Locale('en'),
    Locale('fa'),
    Locale('fr'),
    Locale('id'),
    Locale('ms'),
    Locale('nl'),
    Locale('ru'),
    Locale('tr'),
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

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @notifPrefUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update notification preference. Please try again.'**
  String get notifPrefUpdateFailed;

  /// No description provided for @profileUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get profileUpdatedSuccess;

  /// No description provided for @errorSavingProfile.
  ///
  /// In en, this message translates to:
  /// **'Error saving profile: {error}'**
  String errorSavingProfile(String error);

  /// No description provided for @announcementPosted.
  ///
  /// In en, this message translates to:
  /// **'Announcement posted successfully.'**
  String get announcementPosted;

  /// No description provided for @errorPostingAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Error posting announcement: {error}'**
  String errorPostingAnnouncement(String error);

  /// No description provided for @reportIssue.
  ///
  /// In en, this message translates to:
  /// **'REPORT ISSUE'**
  String get reportIssue;

  /// No description provided for @submitReport.
  ///
  /// In en, this message translates to:
  /// **'SUBMIT REPORT'**
  String get submitReport;

  /// No description provided for @detailsOptional.
  ///
  /// In en, this message translates to:
  /// **'DETAILS (OPTIONAL)'**
  String get detailsOptional;

  /// No description provided for @donationNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Donation information not available for this mosque.'**
  String get donationNotAvailable;

  /// No description provided for @donationDetails.
  ///
  /// In en, this message translates to:
  /// **'DONATION DETAILS'**
  String get donationDetails;

  /// No description provided for @accountDetailsCopied.
  ///
  /// In en, this message translates to:
  /// **'Account details copied to clipboard'**
  String get accountDetailsCopied;

  /// No description provided for @copyDetails.
  ///
  /// In en, this message translates to:
  /// **'COPY DETAILS'**
  String get copyDetails;

  /// No description provided for @closeAction.
  ///
  /// In en, this message translates to:
  /// **'CLOSE'**
  String get closeAction;

  /// No description provided for @locationNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Location coordinates not available for this mosque.'**
  String get locationNotAvailable;

  /// No description provided for @couldNotLaunchMaps.
  ///
  /// In en, this message translates to:
  /// **'Could not launch Google Maps.'**
  String get couldNotLaunchMaps;

  /// No description provided for @errorLaunchingDirections.
  ///
  /// In en, this message translates to:
  /// **'Error launching directions: {error}'**
  String errorLaunchingDirections(String error);

  /// No description provided for @testPermissions.
  ///
  /// In en, this message translates to:
  /// **'Test Permissions'**
  String get testPermissions;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found.'**
  String get noResultsFound;

  /// No description provided for @shareYourStreak.
  ///
  /// In en, this message translates to:
  /// **'Share Your Streak'**
  String get shareYourStreak;

  /// No description provided for @dayLabel.
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get dayLabel;

  /// No description provided for @bestShortLabel.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get bestShortLabel;

  /// No description provided for @totalShortLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalShortLabel;

  /// No description provided for @rateShortLabel.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get rateShortLabel;

  /// No description provided for @allPrayersComplete.
  ///
  /// In en, this message translates to:
  /// **'All prayers complete'**
  String get allPrayersComplete;

  /// No description provided for @allPrayersCompleted.
  ///
  /// In en, this message translates to:
  /// **'All 5 prayers completed'**
  String get allPrayersCompleted;

  /// No description provided for @saveLabel.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveLabel;

  /// No description provided for @shareLabel.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareLabel;

  /// No description provided for @savedToGallery.
  ///
  /// In en, this message translates to:
  /// **'Saved to gallery!'**
  String get savedToGallery;

  /// No description provided for @couldNotSaveToGallery.
  ///
  /// In en, this message translates to:
  /// **'Could not save to gallery.'**
  String get couldNotSaveToGallery;

  /// No description provided for @dayStreakLabel.
  ///
  /// In en, this message translates to:
  /// **'DAY STREAK'**
  String get dayStreakLabel;

  /// No description provided for @overallLabel.
  ///
  /// In en, this message translates to:
  /// **'overall'**
  String get overallLabel;

  /// No description provided for @trackPrayerHabits.
  ///
  /// In en, this message translates to:
  /// **'Track your prayer habits and streaks'**
  String get trackPrayerHabits;

  /// No description provided for @ofTotalCompleted.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total} completed'**
  String ofTotalCompleted(int completed, int total);

  /// No description provided for @selectLocation.
  ///
  /// In en, this message translates to:
  /// **'SELECT LOCATION'**
  String get selectLocation;

  /// No description provided for @searchCityHint.
  ///
  /// In en, this message translates to:
  /// **'Search city (e.g. Lahore, Pakistan)'**
  String get searchCityHint;

  /// No description provided for @useCurrentLocationGps.
  ///
  /// In en, this message translates to:
  /// **'Use Current Location (GPS)'**
  String get useCurrentLocationGps;

  /// No description provided for @confirmWithPasswordPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to confirm deletion'**
  String get confirmWithPasswordPrompt;

  /// No description provided for @reAuthFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Re-authentication failed. Please try again.'**
  String get reAuthFailedMessage;

  /// No description provided for @initializationError.
  ///
  /// In en, this message translates to:
  /// **'Initialization Error'**
  String get initializationError;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @reloadApp.
  ///
  /// In en, this message translates to:
  /// **'Reload app'**
  String get reloadApp;

  /// No description provided for @prayerTimesDetected.
  ///
  /// In en, this message translates to:
  /// **'PRAYER TIMES DETECTED'**
  String get prayerTimesDetected;

  /// No description provided for @iqamahBoard.
  ///
  /// In en, this message translates to:
  /// **'IQAMAH BOARD'**
  String get iqamahBoard;

  /// No description provided for @azanBoard.
  ///
  /// In en, this message translates to:
  /// **'AZAN BOARD'**
  String get azanBoard;

  /// No description provided for @prayerBoard.
  ///
  /// In en, this message translates to:
  /// **'PRAYER BOARD'**
  String get prayerBoard;

  /// No description provided for @confidencePercent.
  ///
  /// In en, this message translates to:
  /// **'{confidence}% CONFIDENCE'**
  String confidencePercent(int confidence);

  /// No description provided for @retakeAction.
  ///
  /// In en, this message translates to:
  /// **'RETAKE'**
  String get retakeAction;

  /// No description provided for @applyAllAction.
  ///
  /// In en, this message translates to:
  /// **'APPLY ALL'**
  String get applyAllAction;

  /// No description provided for @estimatedAbbr.
  ///
  /// In en, this message translates to:
  /// **'est.'**
  String get estimatedAbbr;

  /// No description provided for @azanEstimateNote.
  ///
  /// In en, this message translates to:
  /// **'Azan times estimated: Fajr −15m · Dhuhr −10m · Asr −10m · Maghrib −5m · Isha −10m'**
  String get azanEstimateNote;

  /// No description provided for @iqamahEstimateNote.
  ///
  /// In en, this message translates to:
  /// **'Iqamah times estimated: Fajr +20m · Dhuhr +15m · Asr +15m · Maghrib +10m · Isha +20m'**
  String get iqamahEstimateNote;

  /// No description provided for @analogBoardError.
  ///
  /// In en, this message translates to:
  /// **'ANALOG CLOCK BOARDS CANNOT BE SCANNED — PHOTOGRAPH A DIGITAL PRAYER TIME DISPLAY'**
  String get analogBoardError;

  /// No description provided for @noTimesFoundError.
  ///
  /// In en, this message translates to:
  /// **'NO PRAYER TIMES FOUND — TRY A CLEARER PHOTO'**
  String get noTimesFoundError;

  /// No description provided for @couldNotReadTimesError.
  ///
  /// In en, this message translates to:
  /// **'COULD NOT READ PRAYER TIMES — TRY A CLEARER PHOTO'**
  String get couldNotReadTimesError;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'TAKE PHOTO'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE FROM GALLERY'**
  String get chooseFromGallery;

  /// No description provided for @registryManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'REGISTRY MANAGEMENT'**
  String get registryManagementTitle;

  /// No description provided for @officialNameLabel.
  ///
  /// In en, this message translates to:
  /// **'OFFICIAL NAME'**
  String get officialNameLabel;

  /// No description provided for @donationSettingsHeader.
  ///
  /// In en, this message translates to:
  /// **'DONATION SETTINGS'**
  String get donationSettingsHeader;

  /// No description provided for @donationBankDetailsHeader.
  ///
  /// In en, this message translates to:
  /// **'DONATION BANK DETAILS'**
  String get donationBankDetailsHeader;

  /// No description provided for @bankNameLabel.
  ///
  /// In en, this message translates to:
  /// **'BANK NAME'**
  String get bankNameLabel;

  /// No description provided for @accountHolderLabel.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT HOLDER'**
  String get accountHolderLabel;

  /// No description provided for @accountHolderNameLabel.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT HOLDER NAME'**
  String get accountHolderNameLabel;

  /// No description provided for @accountNumberIbanLabel.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT NUMBER / IBAN'**
  String get accountNumberIbanLabel;

  /// No description provided for @schoolOfThoughtFiqhHeader.
  ///
  /// In en, this message translates to:
  /// **'SCHOOL OF THOUGHT (FIQH)'**
  String get schoolOfThoughtFiqhHeader;

  /// No description provided for @schoolOfThoughtHeader.
  ///
  /// In en, this message translates to:
  /// **'SCHOOL OF THOUGHT'**
  String get schoolOfThoughtHeader;

  /// No description provided for @azanIqamahTimesHeader.
  ///
  /// In en, this message translates to:
  /// **'AZAN & IQAMAH TIMES'**
  String get azanIqamahTimesHeader;

  /// No description provided for @scanPrayerBoardAction.
  ///
  /// In en, this message translates to:
  /// **'SCAN PRAYER BOARD'**
  String get scanPrayerBoardAction;

  /// No description provided for @readingPrayerBoardAction.
  ///
  /// In en, this message translates to:
  /// **'READING PRAYER BOARD...'**
  String get readingPrayerBoardAction;

  /// No description provided for @specialPrayersHeader.
  ///
  /// In en, this message translates to:
  /// **'SPECIAL PRAYERS'**
  String get specialPrayersHeader;

  /// No description provided for @eidPrayersHeader.
  ///
  /// In en, this message translates to:
  /// **'EID PRAYERS'**
  String get eidPrayersHeader;

  /// No description provided for @eidUlFitrLabel.
  ///
  /// In en, this message translates to:
  /// **'EID UL FITR'**
  String get eidUlFitrLabel;

  /// No description provided for @eidUlAdhaLabel.
  ///
  /// In en, this message translates to:
  /// **'EID UL ADHA'**
  String get eidUlAdhaLabel;

  /// No description provided for @timeLabel.
  ///
  /// In en, this message translates to:
  /// **'TIME'**
  String get timeLabel;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'DATE'**
  String get dateLabel;

  /// No description provided for @registryUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Registry updated successfully'**
  String get registryUpdatedMessage;

  /// No description provided for @deletePermanentDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This action is permanent and cannot be undone. All data associated with this sanctuary will be removed from the global registry.'**
  String get deletePermanentDialogBody;

  /// No description provided for @mosqueNameLabel.
  ///
  /// In en, this message translates to:
  /// **'MOSQUE NAME'**
  String get mosqueNameLabel;

  /// No description provided for @imamOfficialContactHeader.
  ///
  /// In en, this message translates to:
  /// **'IMAM / OFFICIAL CONTACT'**
  String get imamOfficialContactHeader;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'FULL NAME'**
  String get fullNameLabel;

  /// No description provided for @phoneNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'PHONE NUMBER'**
  String get phoneNumberLabel;

  /// No description provided for @mosqueFacilitiesHeader.
  ///
  /// In en, this message translates to:
  /// **'MOSQUE FACILITIES'**
  String get mosqueFacilitiesHeader;

  /// No description provided for @janazaTitle.
  ///
  /// In en, this message translates to:
  /// **'JANAZA'**
  String get janazaTitle;

  /// No description provided for @postFuneralAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'POST A FUNERAL ANNOUNCEMENT'**
  String get postFuneralAnnouncement;

  /// No description provided for @nameOfDeceasedLabel.
  ///
  /// In en, this message translates to:
  /// **'NAME OF DECEASED'**
  String get nameOfDeceasedLabel;

  /// No description provided for @genderLabel.
  ///
  /// In en, this message translates to:
  /// **'GENDER'**
  String get genderLabel;

  /// No description provided for @ageOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'AGE (OPTIONAL)'**
  String get ageOptionalLabel;

  /// No description provided for @locationNoteOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'LOCATION NOTE (OPTIONAL)'**
  String get locationNoteOptionalLabel;

  /// No description provided for @janazaDateTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'JANAZA DATE & TIME'**
  String get janazaDateTimeLabel;

  /// No description provided for @familyDetailsOptional.
  ///
  /// In en, this message translates to:
  /// **'FAMILY DETAILS (OPTIONAL)'**
  String get familyDetailsOptional;

  /// No description provided for @postAnnouncementAction.
  ///
  /// In en, this message translates to:
  /// **'POST ANNOUNCEMENT'**
  String get postAnnouncementAction;

  /// No description provided for @announcementWillExpire.
  ///
  /// In en, this message translates to:
  /// **'ANNOUNCEMENT WILL AUTOMATICALLY EXPIRE AFTER THE JANAZA TIME PASSES.'**
  String get announcementWillExpire;

  /// No description provided for @maleLabel.
  ///
  /// In en, this message translates to:
  /// **'MALE'**
  String get maleLabel;

  /// No description provided for @femaleLabel.
  ///
  /// In en, this message translates to:
  /// **'FEMALE'**
  String get femaleLabel;

  /// No description provided for @notSpecifiedLabel.
  ///
  /// In en, this message translates to:
  /// **'NOT SPECIFIED'**
  String get notSpecifiedLabel;

  /// No description provided for @fathersNameLabel.
  ///
  /// In en, this message translates to:
  /// **'FATHER\'S NAME'**
  String get fathersNameLabel;

  /// No description provided for @mothersNameLabel.
  ///
  /// In en, this message translates to:
  /// **'MOTHER\'S NAME'**
  String get mothersNameLabel;

  /// No description provided for @husbandsNameLabel.
  ///
  /// In en, this message translates to:
  /// **'HUSBAND\'S NAME'**
  String get husbandsNameLabel;

  /// No description provided for @wifesNameLabel.
  ///
  /// In en, this message translates to:
  /// **'WIFE\'S NAME'**
  String get wifesNameLabel;

  /// No description provided for @brothersNameLabel.
  ///
  /// In en, this message translates to:
  /// **'BROTHER\'S NAME'**
  String get brothersNameLabel;

  /// No description provided for @sistersNameLabel.
  ///
  /// In en, this message translates to:
  /// **'SISTER\'S NAME'**
  String get sistersNameLabel;

  /// No description provided for @optionalHint.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optionalHint;

  /// No description provided for @ageHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 65'**
  String get ageHint;

  /// No description provided for @locationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Main Prayer Hall, Gate 2'**
  String get locationHint;

  /// No description provided for @selectDateLabel.
  ///
  /// In en, this message translates to:
  /// **'SELECT DATE'**
  String get selectDateLabel;

  /// No description provided for @selectTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'SELECT TIME'**
  String get selectTimeLabel;

  /// No description provided for @announcementPostedTitle.
  ///
  /// In en, this message translates to:
  /// **'ANNOUNCEMENT POSTED'**
  String get announcementPostedTitle;

  /// No description provided for @announcementPostedMessage.
  ///
  /// In en, this message translates to:
  /// **'May Allah grant them Jannah. الفاتحة'**
  String get announcementPostedMessage;

  /// No description provided for @errorEnterDeceasedName.
  ///
  /// In en, this message translates to:
  /// **'ENTER THE NAME OF THE DECEASED.'**
  String get errorEnterDeceasedName;

  /// No description provided for @errorNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'NAME IS TOO LONG. MAX 100 CHARACTERS.'**
  String get errorNameTooLong;

  /// No description provided for @errorSelectDateAndTimeJanaza.
  ///
  /// In en, this message translates to:
  /// **'SELECT BOTH DATE AND TIME FOR THE JANAZA.'**
  String get errorSelectDateAndTimeJanaza;

  /// No description provided for @errorJanazaInPast.
  ///
  /// In en, this message translates to:
  /// **'JANAZA TIME CANNOT BE IN THE PAST.'**
  String get errorJanazaInPast;

  /// No description provided for @errorMustBeSignedIn.
  ///
  /// In en, this message translates to:
  /// **'YOU MUST BE SIGNED IN.'**
  String get errorMustBeSignedIn;

  /// No description provided for @errorNotAuthorizedMosque.
  ///
  /// In en, this message translates to:
  /// **'YOU DO NOT MANAGE THIS MOSQUE.'**
  String get errorNotAuthorizedMosque;

  /// No description provided for @errorInvalidNameLength.
  ///
  /// In en, this message translates to:
  /// **'INVALID NAME. CHECK LENGTH (MAX 100).'**
  String get errorInvalidNameLength;

  /// No description provided for @errorSomethingWentWrongTryAgain.
  ///
  /// In en, this message translates to:
  /// **'SOMETHING WENT WRONG. TRY AGAIN.'**
  String get errorSomethingWentWrongTryAgain;

  /// No description provided for @editJanazaTitle.
  ///
  /// In en, this message translates to:
  /// **'EDIT JANAZA'**
  String get editJanazaTitle;

  /// No description provided for @updateAnnouncementDetails.
  ///
  /// In en, this message translates to:
  /// **'UPDATE ANNOUNCEMENT DETAILS'**
  String get updateAnnouncementDetails;

  /// No description provided for @announcementUpdatedTitle.
  ///
  /// In en, this message translates to:
  /// **'ANNOUNCEMENT UPDATED'**
  String get announcementUpdatedTitle;

  /// No description provided for @changesSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Changes saved successfully.'**
  String get changesSavedMessage;

  /// No description provided for @couldNotUpdateError.
  ///
  /// In en, this message translates to:
  /// **'COULD NOT UPDATE. TRY AGAIN.'**
  String get couldNotUpdateError;

  /// No description provided for @selectBothDateTime.
  ///
  /// In en, this message translates to:
  /// **'SELECT BOTH DATE AND TIME.'**
  String get selectBothDateTime;

  /// No description provided for @qadaPrayersTitle.
  ///
  /// In en, this message translates to:
  /// **'QADA PRAYERS'**
  String get qadaPrayersTitle;

  /// No description provided for @signInForQada.
  ///
  /// In en, this message translates to:
  /// **'Sign in to track Qada prayers.'**
  String get signInForQada;

  /// No description provided for @failedToLoadQada.
  ///
  /// In en, this message translates to:
  /// **'Failed to load Qada data.'**
  String get failedToLoadQada;

  /// No description provided for @addQadaDebtTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Qada Debt'**
  String get addQadaDebtTitle;

  /// No description provided for @addQadaDebtQuestion.
  ///
  /// In en, this message translates to:
  /// **'How many {prayer} prayers do you still need to make up?'**
  String addQadaDebtQuestion(String prayer);

  /// No description provided for @qadaInfoBanner.
  ///
  /// In en, this message translates to:
  /// **'Completing Qada prayers here does not affect your daily streak. Streaks only count on-time daily prayers.'**
  String get qadaInfoBanner;

  /// No description provided for @totalPendingLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Pending'**
  String get totalPendingLabel;

  /// No description provided for @madeUpLabel.
  ///
  /// In en, this message translates to:
  /// **'Made Up'**
  String get madeUpLabel;

  /// No description provided for @pendingCountBadge.
  ///
  /// In en, this message translates to:
  /// **'{count} pending'**
  String pendingCountBadge(int count);

  /// No description provided for @madeUpCountBadge.
  ///
  /// In en, this message translates to:
  /// **'{count} made up'**
  String madeUpCountBadge(int count);

  /// No description provided for @markAsMadeUp.
  ///
  /// In en, this message translates to:
  /// **'Mark as Made Up'**
  String get markAsMadeUp;

  /// No description provided for @allCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get allCaughtUp;

  /// No description provided for @addQadaDebtTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add Qada debt'**
  String get addQadaDebtTooltip;
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
        'de',
        'en',
        'fa',
        'fr',
        'id',
        'ms',
        'nl',
        'ru',
        'tr',
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
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'fa':
      return AppLocalizationsFa();
    case 'fr':
      return AppLocalizationsFr();
    case 'id':
      return AppLocalizationsId();
    case 'ms':
      return AppLocalizationsMs();
    case 'nl':
      return AppLocalizationsNl();
    case 'ru':
      return AppLocalizationsRu();
    case 'tr':
      return AppLocalizationsTr();
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
