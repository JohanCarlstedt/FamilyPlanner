import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_sv.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('sv'),
  ];

  /// No description provided for @tabToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tabToday;

  /// No description provided for @tabWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get tabWeek;

  /// No description provided for @tabChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get tabChat;

  /// No description provided for @tabShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get tabShopping;

  /// No description provided for @tabMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get tabMore;

  /// No description provided for @weekNumber.
  ///
  /// In en, this message translates to:
  /// **'Week {number}'**
  String weekNumber(int number);

  /// No description provided for @weekPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous week'**
  String get weekPrevious;

  /// No description provided for @weekThis.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get weekThis;

  /// No description provided for @weekNext.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get weekNext;

  /// No description provided for @weekLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the week.\n{error}'**
  String weekLoadFailed(String error);

  /// No description provided for @scopeMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get scopeMine;

  /// No description provided for @scopeFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get scopeFamily;

  /// No description provided for @weekWarnings.
  ///
  /// In en, this message translates to:
  /// **'This week: {parts}'**
  String weekWarnings(String parts);

  /// No description provided for @weekUnassigned.
  ///
  /// In en, this message translates to:
  /// **'{count} with no one responsible'**
  String weekUnassigned(int count);

  /// No description provided for @weekDoubleBooked.
  ///
  /// In en, this message translates to:
  /// **'{count} double-booked'**
  String weekDoubleBooked(int count);

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @nothingPlanned.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned'**
  String get nothingPlanned;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @driving.
  ///
  /// In en, this message translates to:
  /// **'Driving: {name}'**
  String driving(String name);

  /// No description provided for @noOneResponsible.
  ///
  /// In en, this message translates to:
  /// **'No one responsible'**
  String get noOneResponsible;

  /// No description provided for @doubleBookedShort.
  ///
  /// In en, this message translates to:
  /// **'double-booked'**
  String get doubleBookedShort;

  /// No description provided for @shoppingDescription.
  ///
  /// In en, this message translates to:
  /// **'The active list grouped by aisle, with source chips on each item.'**
  String get shoppingDescription;

  /// No description provided for @chatDescription.
  ///
  /// In en, this message translates to:
  /// **'The thread list, with the family thread pinned at the top. End-to-end encrypted with MLS.'**
  String get chatDescription;

  /// No description provided for @kitchenDisplay.
  ///
  /// In en, this message translates to:
  /// **'Kitchen display'**
  String get kitchenDisplay;

  /// No description provided for @kitchenDescription.
  ///
  /// In en, this message translates to:
  /// **'The week, today\'s meal and the shopping list on a wall-mounted tablet. A device session: no member login and no chat keys.'**
  String get kitchenDescription;

  /// No description provided for @welcomeTagline.
  ///
  /// In en, this message translates to:
  /// **'Your family\'s calendar, lists and chat — encrypted so only your family can read them.'**
  String get welcomeTagline;

  /// No description provided for @startFamily.
  ///
  /// In en, this message translates to:
  /// **'Start a new family'**
  String get startFamily;

  /// No description provided for @joinFamily.
  ///
  /// In en, this message translates to:
  /// **'Join my family'**
  String get joinFamily;

  /// No description provided for @newEvent.
  ///
  /// In en, this message translates to:
  /// **'New event'**
  String get newEvent;

  /// No description provided for @todayLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load today.\n{error}'**
  String todayLoadFailed(String error);

  /// No description provided for @nothingToday.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned today.'**
  String get nothingToday;

  /// No description provided for @unassignedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{No one is responsible for 1 event} other{No one is responsible for {count} events}}'**
  String unassignedCount(int count);

  /// No description provided for @doubleBooked.
  ///
  /// In en, this message translates to:
  /// **'Double-booked'**
  String get doubleBooked;

  /// No description provided for @someone.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get someone;

  /// No description provided for @overlaps.
  ///
  /// In en, this message translates to:
  /// **'{first} {firstTime} overlaps {second} {secondTime}'**
  String overlaps(
    String first,
    String firstTime,
    String second,
    String secondTime,
  );

  /// No description provided for @nextUp.
  ///
  /// In en, this message translates to:
  /// **'Next up · {when}'**
  String nextUp(String when);

  /// No description provided for @startingNow.
  ///
  /// In en, this message translates to:
  /// **'starting now'**
  String get startingNow;

  /// No description provided for @inMinutes.
  ///
  /// In en, this message translates to:
  /// **'in {minutes} min'**
  String inMinutes(int minutes);

  /// No description provided for @inHours.
  ///
  /// In en, this message translates to:
  /// **'in {hours} h'**
  String inHours(int hours);

  /// No description provided for @inHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'in {hours} h {minutes} min'**
  String inHoursMinutes(int hours, int minutes);

  /// No description provided for @addDevice.
  ///
  /// In en, this message translates to:
  /// **'Add a device'**
  String get addDevice;

  /// No description provided for @addDeviceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A child\'s tablet, the other parent\'s phone'**
  String get addDeviceSubtitle;

  /// No description provided for @trustedDevices.
  ///
  /// In en, this message translates to:
  /// **'Trusted devices'**
  String get trustedDevices;

  /// No description provided for @trustedDevicesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} in this family, this one included'**
  String trustedDevicesCount(int count);

  /// No description provided for @moreComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Planner, celebrations, meals, actions, map and family settings will live here.'**
  String get moreComingSoon;

  /// No description provided for @deleteEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"?'**
  String deleteEventTitle(String title);

  /// No description provided for @deleteEventOnce.
  ///
  /// In en, this message translates to:
  /// **'It disappears for the whole family.'**
  String get deleteEventOnce;

  /// No description provided for @deleteEventSeries.
  ///
  /// In en, this message translates to:
  /// **'Every occurrence disappears for the whole family.'**
  String get deleteEventSeries;

  /// No description provided for @keep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keep;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @parentsOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Parents only: children\'s devices get no readable copy'**
  String get parentsOnlyNote;

  /// No description provided for @whosGoing.
  ///
  /// In en, this message translates to:
  /// **'Who\'s going'**
  String get whosGoing;

  /// No description provided for @wholeFamily.
  ///
  /// In en, this message translates to:
  /// **'The whole family'**
  String get wholeFamily;

  /// No description provided for @responsible.
  ///
  /// In en, this message translates to:
  /// **'Responsible'**
  String get responsible;

  /// No description provided for @noOneYet.
  ///
  /// In en, this message translates to:
  /// **'No one yet'**
  String get noOneYet;

  /// No description provided for @eventGone.
  ///
  /// In en, this message translates to:
  /// **'This event is no longer here.'**
  String get eventGone;

  /// No description provided for @repeatsWeeklyOn.
  ///
  /// In en, this message translates to:
  /// **'Every week on {days}'**
  String repeatsWeeklyOn(String days);

  /// No description provided for @repeatsDaily.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get repeatsDaily;

  /// No description provided for @repeatsWeekly.
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get repeatsWeekly;

  /// No description provided for @repeatsMonthly.
  ///
  /// In en, this message translates to:
  /// **'Every month'**
  String get repeatsMonthly;

  /// No description provided for @repeatsYearly.
  ///
  /// In en, this message translates to:
  /// **'Every year'**
  String get repeatsYearly;

  /// No description provided for @titleRequired.
  ///
  /// In en, this message translates to:
  /// **'Give it a title.'**
  String get titleRequired;

  /// No description provided for @saveEventFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the event.\n{error}'**
  String saveEventFailed(String error);

  /// No description provided for @editEvent.
  ///
  /// In en, this message translates to:
  /// **'Edit event'**
  String get editEvent;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @fieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get fieldTitle;

  /// No description provided for @fieldLength.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get fieldLength;

  /// No description provided for @fieldWhere.
  ///
  /// In en, this message translates to:
  /// **'Where (optional)'**
  String get fieldWhere;

  /// No description provided for @fieldResponsible.
  ///
  /// In en, this message translates to:
  /// **'Responsible / driving'**
  String get fieldResponsible;

  /// No description provided for @repeatsEveryWeek.
  ///
  /// In en, this message translates to:
  /// **'Repeats every week'**
  String get repeatsEveryWeek;

  /// No description provided for @everyWeekday.
  ///
  /// In en, this message translates to:
  /// **'Every {weekday}'**
  String everyWeekday(String weekday);

  /// No description provided for @parentsOnly.
  ///
  /// In en, this message translates to:
  /// **'Parents only'**
  String get parentsOnly;

  /// No description provided for @parentsOnlySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Children\'s devices get no readable copy.'**
  String get parentsOnlySubtitle;

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// No description provided for @durationHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String durationHours(int hours);

  /// No description provided for @namesRequired.
  ///
  /// In en, this message translates to:
  /// **'Add the family name and yours.'**
  String get namesRequired;

  /// No description provided for @createFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the family. Check the connection and try again.\n{error}'**
  String createFailed(String error);

  /// No description provided for @familyName.
  ///
  /// In en, this message translates to:
  /// **'Family name'**
  String get familyName;

  /// No description provided for @familyNameHint.
  ///
  /// In en, this message translates to:
  /// **'The Svenssons'**
  String get familyNameHint;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// No description provided for @serverCanReadFamilyName.
  ///
  /// In en, this message translates to:
  /// **'The family name is the one thing our server can read. Your name, and everything else you add, is encrypted on this phone.'**
  String get serverCanReadFamilyName;

  /// No description provided for @createFamily.
  ///
  /// In en, this message translates to:
  /// **'Create family'**
  String get createFamily;

  /// No description provided for @keysFailed.
  ///
  /// In en, this message translates to:
  /// **'This device couldn\'t set up its keys.\n{error}'**
  String keysFailed(String error);

  /// No description provided for @serverUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server right now. Still trying…'**
  String get serverUnreachable;

  /// No description provided for @joinInstructions.
  ///
  /// In en, this message translates to:
  /// **'On a parent\'s phone, open Family, go to More → Add a device, and scan this code.'**
  String get joinInstructions;

  /// No description provided for @pairingCode.
  ///
  /// In en, this message translates to:
  /// **'Pairing code'**
  String get pairingCode;

  /// No description provided for @waitingForScan.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a parent to scan…'**
  String get waitingForScan;

  /// No description provided for @codeWarning.
  ///
  /// In en, this message translates to:
  /// **'The code works once, and only while this screen is open. Don\'t share a photo of it.'**
  String get codeWarning;

  /// No description provided for @detailsUnreadable.
  ///
  /// In en, this message translates to:
  /// **'This device\'s family details couldn\'t be read.'**
  String get detailsUnreadable;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @notAPairingCode.
  ///
  /// In en, this message translates to:
  /// **'That isn\'t a Family pairing code.'**
  String get notAPairingCode;

  /// No description provided for @codeUnreadable.
  ///
  /// In en, this message translates to:
  /// **'That code couldn\'t be read. Ask for a fresh one and scan again.'**
  String get codeUnreadable;

  /// No description provided for @addDeviceFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add the device. Check the connection and scan again.\n{error}'**
  String addDeviceFailed(String error);

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Add their name first.'**
  String get nameRequired;

  /// No description provided for @whoIsDeviceFor.
  ///
  /// In en, this message translates to:
  /// **'Who is the new device for?'**
  String get whoIsDeviceFor;

  /// No description provided for @forChild.
  ///
  /// In en, this message translates to:
  /// **'A child'**
  String get forChild;

  /// No description provided for @forChildSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sees the family calendar and lists, not parents-only things.'**
  String get forChildSubtitle;

  /// No description provided for @forOtherParent.
  ///
  /// In en, this message translates to:
  /// **'The other parent'**
  String get forOtherParent;

  /// No description provided for @forOtherParentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sees everything you see, and can add devices.'**
  String get forOtherParentSubtitle;

  /// No description provided for @forMyself.
  ///
  /// In en, this message translates to:
  /// **'Me, on another device'**
  String get forMyself;

  /// No description provided for @forMyselfSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A tablet or second phone of your own.'**
  String get forMyselfSubtitle;

  /// No description provided for @childsName.
  ///
  /// In en, this message translates to:
  /// **'Child\'s name'**
  String get childsName;

  /// No description provided for @otherParentsName.
  ///
  /// In en, this message translates to:
  /// **'Other parent\'s name'**
  String get otherParentsName;

  /// No description provided for @showCodeInstructions.
  ///
  /// In en, this message translates to:
  /// **'On the new device, open Family and choose \"Join my family\" to show its code.'**
  String get showCodeInstructions;

  /// No description provided for @scanCode.
  ///
  /// In en, this message translates to:
  /// **'Scan the code'**
  String get scanCode;

  /// No description provided for @cameraDenied.
  ///
  /// In en, this message translates to:
  /// **'Family needs the camera to scan the code. Allow it in Settings, then come back.'**
  String get cameraDenied;

  /// No description provided for @cameraFailed.
  ///
  /// In en, this message translates to:
  /// **'The camera couldn\'t start: {reason}'**
  String cameraFailed(String reason);

  /// No description provided for @pointCamera.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the code on the new device.'**
  String get pointCamera;

  /// No description provided for @deviceAdded.
  ///
  /// In en, this message translates to:
  /// **'Device added'**
  String get deviceAdded;

  /// No description provided for @deviceAddedDetail.
  ///
  /// In en, this message translates to:
  /// **'It will finish setting up on its own in a moment.'**
  String get deviceAddedDetail;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @changeWhich.
  ///
  /// In en, this message translates to:
  /// **'Change which?'**
  String get changeWhich;

  /// No description provided for @removeWhich.
  ///
  /// In en, this message translates to:
  /// **'Remove which?'**
  String get removeWhich;

  /// No description provided for @scopeThisOne.
  ///
  /// In en, this message translates to:
  /// **'Only this one'**
  String get scopeThisOne;

  /// No description provided for @scopeThisAndAfter.
  ///
  /// In en, this message translates to:
  /// **'This one and all after it'**
  String get scopeThisAndAfter;

  /// No description provided for @scopeAll.
  ///
  /// In en, this message translates to:
  /// **'All of them'**
  String get scopeAll;

  /// No description provided for @cancelThisOne.
  ///
  /// In en, this message translates to:
  /// **'Cancel only this one'**
  String get cancelThisOne;

  /// No description provided for @removeThisAndAfter.
  ///
  /// In en, this message translates to:
  /// **'Remove this one and all after it'**
  String get removeThisAndAfter;

  /// No description provided for @removeAll.
  ///
  /// In en, this message translates to:
  /// **'Remove all of them'**
  String get removeAll;

  /// No description provided for @occurrenceCancelled.
  ///
  /// In en, this message translates to:
  /// **'{title} on {date} is cancelled.'**
  String occurrenceCancelled(String title, String date);

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @editOccurrence.
  ///
  /// In en, this message translates to:
  /// **'Edit this time'**
  String get editOccurrence;

  /// No description provided for @onlyThisOccurrence.
  ///
  /// In en, this message translates to:
  /// **'Changes only {date}. Who\'s going, the place and the repeat follow the series.'**
  String onlyThisOccurrence(String date);

  /// No description provided for @changedThisTime.
  ///
  /// In en, this message translates to:
  /// **'Changed this time'**
  String get changedThisTime;

  /// No description provided for @movedFrom.
  ///
  /// In en, this message translates to:
  /// **'Moved from {date}'**
  String movedFrom(String date);

  /// No description provided for @fieldReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get fieldReminder;

  /// No description provided for @reminderNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get reminderNone;

  /// No description provided for @reminderAtStart.
  ///
  /// In en, this message translates to:
  /// **'When it starts'**
  String get reminderAtStart;

  /// No description provided for @reminderMinutesBefore.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min before'**
  String reminderMinutesBefore(int minutes);

  /// No description provided for @reminderHoursBefore.
  ///
  /// In en, this message translates to:
  /// **'{hours} h before'**
  String reminderHoursBefore(int hours);

  /// No description provided for @reminderDayBefore.
  ///
  /// In en, this message translates to:
  /// **'The day before'**
  String get reminderDayBefore;

  /// No description provided for @reminderStarts.
  ///
  /// In en, this message translates to:
  /// **'Starts {time}'**
  String reminderStarts(String time);

  /// No description provided for @remindersChannel.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get remindersChannel;

  /// No description provided for @remindersChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Before events you\'re part of'**
  String get remindersChannelDescription;
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
      <String>['en', 'sv'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'sv':
      return AppLocalizationsSv();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
