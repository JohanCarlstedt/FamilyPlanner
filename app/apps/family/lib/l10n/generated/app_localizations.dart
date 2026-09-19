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
  /// **'It disappears for the whole family. It can be restored for 30 days.'**
  String get deleteEventOnce;

  /// No description provided for @deleteEventSeries.
  ///
  /// In en, this message translates to:
  /// **'Every occurrence disappears for the whole family. It can be restored for 30 days.'**
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
  /// **'On a parent\'s phone, open Family Planner, go to More → Add a device, and scan this code.'**
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
  /// **'That isn\'t a Family Planner pairing code.'**
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
  /// **'On the new device, open Family Planner and choose \"Join my family\" to show its code.'**
  String get showCodeInstructions;

  /// No description provided for @scanCode.
  ///
  /// In en, this message translates to:
  /// **'Scan the code'**
  String get scanCode;

  /// No description provided for @cameraDenied.
  ///
  /// In en, this message translates to:
  /// **'Family Planner needs the camera to scan the code. Allow it in Settings, then come back.'**
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

  /// No description provided for @recentlyDeleted.
  ///
  /// In en, this message translates to:
  /// **'Recently deleted'**
  String get recentlyDeleted;

  /// No description provided for @recentlyDeletedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore events for 30 days'**
  String get recentlyDeletedSubtitle;

  /// No description provided for @recentlyDeletedEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing deleted in the last 30 days.'**
  String get recentlyDeletedEmpty;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @deletedOn.
  ///
  /// In en, this message translates to:
  /// **'Deleted {date}'**
  String deletedOn(String date);

  /// No description provided for @eventRemoved.
  ///
  /// In en, this message translates to:
  /// **'{title} was removed.'**
  String eventRemoved(String title);

  /// No description provided for @seriesEnded.
  ///
  /// In en, this message translates to:
  /// **'{title} now ends before {date}.'**
  String seriesEnded(String title, String date);

  /// No description provided for @places.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get places;

  /// No description provided for @placesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Home, the sports hall, grandma\'s'**
  String get placesSubtitle;

  /// No description provided for @placesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No places yet. Add the ones your family goes to every week.'**
  String get placesEmpty;

  /// No description provided for @newPlace.
  ///
  /// In en, this message translates to:
  /// **'New place'**
  String get newPlace;

  /// No description provided for @editPlace.
  ///
  /// In en, this message translates to:
  /// **'Edit place'**
  String get editPlace;

  /// No description provided for @placeName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get placeName;

  /// No description provided for @placeNameHint.
  ///
  /// In en, this message translates to:
  /// **'Sportshallen'**
  String get placeNameHint;

  /// No description provided for @placeAddress.
  ///
  /// In en, this message translates to:
  /// **'Address (optional)'**
  String get placeAddress;

  /// No description provided for @placeIsHome.
  ///
  /// In en, this message translates to:
  /// **'This is home'**
  String get placeIsHome;

  /// No description provided for @placeIsHomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Where trips start from'**
  String get placeIsHomeSubtitle;

  /// No description provided for @parkingBuffer.
  ///
  /// In en, this message translates to:
  /// **'Parking and walking in'**
  String get parkingBuffer;

  /// No description provided for @parkingNone.
  ///
  /// In en, this message translates to:
  /// **'No extra time'**
  String get parkingNone;

  /// No description provided for @parkingMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min extra'**
  String parkingMinutes(int minutes);

  /// No description provided for @fieldPlace.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get fieldPlace;

  /// No description provided for @noPlace.
  ///
  /// In en, this message translates to:
  /// **'No place'**
  String get noPlace;

  /// No description provided for @choosePlace.
  ///
  /// In en, this message translates to:
  /// **'Choose a place'**
  String get choosePlace;

  /// No description provided for @placeNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Give the place a name.'**
  String get placeNameRequired;

  /// No description provided for @reminderLeaveNow.
  ///
  /// In en, this message translates to:
  /// **'Time to leave · starts {time}'**
  String reminderLeaveNow(String time);

  /// No description provided for @reminderTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow at {time}'**
  String reminderTomorrow(String time);

  /// No description provided for @reminderUnassigned.
  ///
  /// In en, this message translates to:
  /// **'No one is responsible yet · {day} {time}'**
  String reminderUnassigned(String day, String time);

  /// No description provided for @remindersTogether.
  ///
  /// In en, this message translates to:
  /// **'{count} reminders'**
  String remindersTogether(int count);

  /// No description provided for @digestTitle.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get digestTitle;

  /// No description provided for @digestSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 thing today} other{{count} things today}}'**
  String digestSummary(int count);

  /// No description provided for @quietChannel.
  ///
  /// In en, this message translates to:
  /// **'Reminders during quiet hours'**
  String get quietChannel;

  /// No description provided for @familySettings.
  ///
  /// In en, this message translates to:
  /// **'Family settings'**
  String get familySettings;

  /// No description provided for @familySettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours, morning summary'**
  String get familySettingsSubtitle;

  /// No description provided for @quietHours.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours'**
  String get quietHours;

  /// No description provided for @quietHoursRange.
  ///
  /// In en, this message translates to:
  /// **'{from}–{to}'**
  String quietHoursRange(String from, String to);

  /// No description provided for @quietHoursHelp.
  ///
  /// In en, this message translates to:
  /// **'Reminders to get ready move to the evening before. Reminders to leave still arrive, without sound.'**
  String get quietHoursHelp;

  /// No description provided for @quietFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get quietFrom;

  /// No description provided for @quietTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get quietTo;

  /// No description provided for @morningDigest.
  ///
  /// In en, this message translates to:
  /// **'Morning summary'**
  String get morningDigest;

  /// No description provided for @morningDigestHelp.
  ///
  /// In en, this message translates to:
  /// **'One notification with the day\'s plans, instead of many.'**
  String get morningDigestHelp;

  /// No description provided for @gettingReady.
  ///
  /// In en, this message translates to:
  /// **'Getting ready'**
  String get gettingReady;

  /// No description provided for @gettingReadyHelp.
  ///
  /// In en, this message translates to:
  /// **'Added before it\'s time to leave: coats, shoes, finding the other shoe.'**
  String get gettingReadyHelp;

  /// No description provided for @changeAdded.
  ///
  /// In en, this message translates to:
  /// **'New · {when}'**
  String changeAdded(String when);

  /// No description provided for @changeCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get changeCancelled;

  /// No description provided for @changeCancelledOne.
  ///
  /// In en, this message translates to:
  /// **'Cancelled {day} · only that time'**
  String changeCancelledOne(String day);

  /// No description provided for @changeTime.
  ///
  /// In en, this message translates to:
  /// **'New time · {when}'**
  String changeTime(String when);

  /// No description provided for @changePlace.
  ///
  /// In en, this message translates to:
  /// **'New place · {when}'**
  String changePlace(String when);

  /// No description provided for @changeTimeAndPlace.
  ///
  /// In en, this message translates to:
  /// **'New time and place · {when}'**
  String changeTimeAndPlace(String when);

  /// No description provided for @changeMovedOne.
  ///
  /// In en, this message translates to:
  /// **'Moved {day} · only that time'**
  String changeMovedOne(String day);

  /// No description provided for @changeEveryTime.
  ///
  /// In en, this message translates to:
  /// **'{text} · every time'**
  String changeEveryTime(String text);

  /// No description provided for @changeYouAreIn.
  ///
  /// In en, this message translates to:
  /// **'You\'ve been added · {when}'**
  String changeYouAreIn(String when);

  /// No description provided for @changeYouAreOut.
  ///
  /// In en, this message translates to:
  /// **'You\'re no longer on it'**
  String get changeYouAreOut;

  /// No description provided for @changeYouDrive.
  ///
  /// In en, this message translates to:
  /// **'You\'re driving · {when}'**
  String changeYouDrive(String when);

  /// No description provided for @changeSomeoneElseDrives.
  ///
  /// In en, this message translates to:
  /// **'Someone else is driving · {when}'**
  String changeSomeoneElseDrives(String when);

  /// No description provided for @changesChannel.
  ///
  /// In en, this message translates to:
  /// **'Changes to plans'**
  String get changesChannel;

  /// No description provided for @changesChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'When something you\'re part of moves or is cancelled'**
  String get changesChannelDescription;

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get members;

  /// No description provided for @membersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Who\'s in the family, and children without a phone'**
  String get membersSubtitle;

  /// No description provided for @addChild.
  ///
  /// In en, this message translates to:
  /// **'Add a child'**
  String get addChild;

  /// No description provided for @editMember.
  ///
  /// In en, this message translates to:
  /// **'Edit member'**
  String get editMember;

  /// No description provided for @memberName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get memberName;

  /// No description provided for @tier.
  ///
  /// In en, this message translates to:
  /// **'Age group'**
  String get tier;

  /// No description provided for @tierLittle.
  ///
  /// In en, this message translates to:
  /// **'Little (under about 8)'**
  String get tierLittle;

  /// No description provided for @tierKid.
  ///
  /// In en, this message translates to:
  /// **'Kid (about 8–12)'**
  String get tierKid;

  /// No description provided for @tierTeen.
  ///
  /// In en, this message translates to:
  /// **'Teen (about 13+)'**
  String get tierTeen;

  /// No description provided for @roleParent.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get roleParent;

  /// No description provided for @roleChild.
  ///
  /// In en, this message translates to:
  /// **'Child'**
  String get roleChild;

  /// No description provided for @colour.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get colour;

  /// No description provided for @childNoPhoneNote.
  ///
  /// In en, this message translates to:
  /// **'A child without a phone is part of everything: their events and reminders go to whoever is responsible. When they get a device, add it to them under Add a device.'**
  String get childNoPhoneNote;

  /// No description provided for @forExisting.
  ///
  /// In en, this message translates to:
  /// **'Someone already in the family'**
  String get forExisting;

  /// No description provided for @forExistingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Their events and colour come along.'**
  String get forExistingSubtitle;

  /// No description provided for @chooseMember.
  ///
  /// In en, this message translates to:
  /// **'Who?'**
  String get chooseMember;

  /// No description provided for @memberRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose who the device is for.'**
  String get memberRequired;

  /// No description provided for @reminderForChild.
  ///
  /// In en, this message translates to:
  /// **'{name}: {title}'**
  String reminderForChild(String name, String title);

  /// No description provided for @thisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get thisDevice;

  /// No description provided for @deviceOf.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s device'**
  String deviceOf(String name);

  /// No description provided for @someDevice.
  ///
  /// In en, this message translates to:
  /// **'A device'**
  String get someDevice;

  /// No description provided for @removeDevice.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeDevice;

  /// No description provided for @removeDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {device}?'**
  String removeDeviceTitle(String device);

  /// No description provided for @removeDeviceBody.
  ///
  /// In en, this message translates to:
  /// **'It stops syncing at once and can\'t read anything new: the family\'s keys are changed. What\'s already on it stays there, and nothing can take that back.'**
  String get removeDeviceBody;

  /// No description provided for @deviceRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed. The family\'s keys have been changed.'**
  String get deviceRemoved;

  /// No description provided for @removeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove the device.\n{error}'**
  String removeFailed(String error);

  /// No description provided for @removeMember.
  ///
  /// In en, this message translates to:
  /// **'Remove from the family'**
  String get removeMember;

  /// No description provided for @removeMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from the family?'**
  String removeMemberTitle(String name);

  /// No description provided for @removeMemberBody.
  ///
  /// In en, this message translates to:
  /// **'Their devices stop syncing and the family\'s keys change. Events they made stay; events they were responsible for will need someone new. What\'s already on their devices stays there.'**
  String get removeMemberBody;

  /// No description provided for @memberRemoved.
  ///
  /// In en, this message translates to:
  /// **'{name} was removed from the family.'**
  String memberRemoved(String name);

  /// No description provided for @setupWhoTitle.
  ///
  /// In en, this message translates to:
  /// **'Who\'s in your family?'**
  String get setupWhoTitle;

  /// No description provided for @setupWhoBody.
  ///
  /// In en, this message translates to:
  /// **'Add the children first: everything else is organised around them. They don\'t need a phone.'**
  String get setupWhoBody;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @setupPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Only your family can read it'**
  String get setupPrivacyTitle;

  /// No description provided for @setupPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'Your family\'s calendar, messages, lists and photos are encrypted on your devices. Only people in your family can read them — we can\'t, and neither can anyone else.\n\nThat also means we can\'t recover your data if every family device is lost.'**
  String get setupPrivacyBody;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @oneDeviceWarning.
  ///
  /// In en, this message translates to:
  /// **'Only this phone holds your family\'s keys. Add a second device — the other parent\'s phone or a tablet — so a lost phone doesn\'t mean a lost calendar.'**
  String get oneDeviceWarning;

  /// No description provided for @roleHelper.
  ///
  /// In en, this message translates to:
  /// **'Helper'**
  String get roleHelper;

  /// No description provided for @forHelper.
  ///
  /// In en, this message translates to:
  /// **'A helper'**
  String get forHelper;

  /// No description provided for @forHelperSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A babysitter or grandparent: sees the children you choose, until you say.'**
  String get forHelperSubtitle;

  /// No description provided for @helpersName.
  ///
  /// In en, this message translates to:
  /// **'Helper\'s name'**
  String get helpersName;

  /// No description provided for @helperChildren.
  ///
  /// In en, this message translates to:
  /// **'Which children?'**
  String get helperChildren;

  /// No description provided for @helperUntil.
  ///
  /// In en, this message translates to:
  /// **'Until {when}'**
  String helperUntil(String when);

  /// No description provided for @helperChildrenRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one child.'**
  String get helperChildrenRequired;

  /// No description provided for @helperForwardOnly.
  ///
  /// In en, this message translates to:
  /// **'When the time is up their phone stops syncing. What it already showed them stays on it.'**
  String get helperForwardOnly;

  /// No description provided for @familyThread.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get familyThread;

  /// No description provided for @chatEmpty.
  ///
  /// In en, this message translates to:
  /// **'Say something to the family. Only your family\'s devices can read it.'**
  String get chatEmpty;

  /// No description provided for @chatWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a parent\'s phone to add this device to the family chat.'**
  String get chatWaiting;

  /// No description provided for @chatAlone.
  ///
  /// In en, this message translates to:
  /// **'The family chat starts when another device is added.'**
  String get chatAlone;

  /// No description provided for @chatHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get chatHint;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @sendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send. Check the connection and try again.'**
  String get sendFailed;

  /// No description provided for @chatChannel.
  ///
  /// In en, this message translates to:
  /// **'Family chat'**
  String get chatChannel;

  /// No description provided for @chatChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Messages from your family'**
  String get chatChannelDescription;

  /// No description provided for @recoveryKit.
  ///
  /// In en, this message translates to:
  /// **'Recovery words'**
  String get recoveryKit;

  /// No description provided for @recoveryKitSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Twelve words that bring your family back if every phone is lost'**
  String get recoveryKitSubtitle;

  /// No description provided for @recoveryIntro.
  ///
  /// In en, this message translates to:
  /// **'If every phone and tablet in the family is lost, these twelve words are the only way back. Write them on paper and keep it somewhere safe at home — not in a photo, not in an email.'**
  String get recoveryIntro;

  /// No description provided for @showWords.
  ///
  /// In en, this message translates to:
  /// **'Show my words'**
  String get showWords;

  /// No description provided for @wroteThemDown.
  ///
  /// In en, this message translates to:
  /// **'I\'ve written them down'**
  String get wroteThemDown;

  /// No description provided for @checkWords.
  ///
  /// In en, this message translates to:
  /// **'Check you have them'**
  String get checkWords;

  /// No description provided for @wordNumber.
  ///
  /// In en, this message translates to:
  /// **'Word {n}'**
  String wordNumber(int n);

  /// No description provided for @wordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'That\'s not what the words say. Check your paper and try again.'**
  String get wordsDontMatch;

  /// No description provided for @savingKit.
  ///
  /// In en, this message translates to:
  /// **'Saving your recovery words…'**
  String get savingKit;

  /// No description provided for @kitReady.
  ///
  /// In en, this message translates to:
  /// **'Your recovery words are ready. Any earlier words no longer work.'**
  String get kitReady;

  /// No description provided for @kitFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the recovery words.\n{error}'**
  String kitFailed(String error);

  /// No description provided for @recoverFamily.
  ///
  /// In en, this message translates to:
  /// **'Recover with my twelve words'**
  String get recoverFamily;

  /// No description provided for @recoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Recover your family'**
  String get recoverTitle;

  /// No description provided for @recoverHelp.
  ///
  /// In en, this message translates to:
  /// **'Type the twelve words from your paper, in order, with spaces between.'**
  String get recoverHelp;

  /// No description provided for @recover.
  ///
  /// In en, this message translates to:
  /// **'Recover'**
  String get recover;

  /// No description provided for @recovering.
  ///
  /// In en, this message translates to:
  /// **'Recovering… this takes a few seconds.'**
  String get recovering;

  /// No description provided for @recoverBadWords.
  ///
  /// In en, this message translates to:
  /// **'Those aren\'t twelve valid words. A single mistyped word is enough — check each one.'**
  String get recoverBadWords;

  /// No description provided for @recoverNotFound.
  ///
  /// In en, this message translates to:
  /// **'These words don\'t open a family. They may have been replaced by newer ones.'**
  String get recoverNotFound;

  /// No description provided for @recoverFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t recover.\n{error}'**
  String recoverFailed(String error);

  /// No description provided for @securing.
  ///
  /// In en, this message translates to:
  /// **'Securing your family\'s keys…'**
  String get securing;

  /// No description provided for @recoveredNewWords.
  ///
  /// In en, this message translates to:
  /// **'You\'re back. Your old words may have been seen, so they no longer work: make new ones now.'**
  String get recoveredNewWords;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @notificationsOff.
  ///
  /// In en, this message translates to:
  /// **'Reminders can\'t reach you: notifications are off for Family Planner. It sends only what\'s about your family\'s plans.'**
  String get notificationsOff;

  /// No description provided for @turnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get turnOn;

  /// No description provided for @testReminder.
  ///
  /// In en, this message translates to:
  /// **'Send me a test reminder'**
  String get testReminder;

  /// No description provided for @testReminderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Arrives in about a minute, the way real ones do'**
  String get testReminderSubtitle;

  /// No description provided for @testReminderSent.
  ///
  /// In en, this message translates to:
  /// **'On its way. Lock the phone and wait a minute.'**
  String get testReminderSent;

  /// No description provided for @testReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders work'**
  String get testReminderTitle;

  /// No description provided for @testReminderBody.
  ///
  /// In en, this message translates to:
  /// **'This came the same way your family\'s reminders will.'**
  String get testReminderBody;

  /// No description provided for @requestEvent.
  ///
  /// In en, this message translates to:
  /// **'Ask for an event'**
  String get requestEvent;

  /// No description provided for @waitingForParent.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a parent'**
  String get waitingForParent;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @requestSent.
  ///
  /// In en, this message translates to:
  /// **'Sent to a parent to approve.'**
  String get requestSent;

  /// No description provided for @requestFrom.
  ///
  /// In en, this message translates to:
  /// **'{name} asks for this'**
  String requestFrom(String name);

  /// No description provided for @linkedCalendars.
  ///
  /// In en, this message translates to:
  /// **'Linked calendars'**
  String get linkedCalendars;

  /// No description provided for @linkedCalendarsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Team and school schedules, fetched automatically'**
  String get linkedCalendarsSubtitle;

  /// No description provided for @linkCalendar.
  ///
  /// In en, this message translates to:
  /// **'Link a calendar'**
  String get linkCalendar;

  /// No description provided for @calendarLinkUrl.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get calendarLinkUrl;

  /// No description provided for @calendarLinkUrlHint.
  ///
  /// In en, this message translates to:
  /// **'A laget.se team page, webcal:// or .ics link'**
  String get calendarLinkUrlHint;

  /// No description provided for @calendarLinkName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get calendarLinkName;

  /// No description provided for @calendarLinkFor.
  ///
  /// In en, this message translates to:
  /// **'Whose calendar'**
  String get calendarLinkFor;

  /// No description provided for @calendarLinkInvalid.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t look like a calendar link'**
  String get calendarLinkInvalid;

  /// No description provided for @calendarFetched.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Up to date} =1{1 event updated} other{{count} events updated}}'**
  String calendarFetched(int count);

  /// No description provided for @calendarFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t fetch the calendar.\n{error}'**
  String calendarFetchFailed(String error);

  /// No description provided for @fetchNow.
  ///
  /// In en, this message translates to:
  /// **'Fetch now'**
  String get fetchNow;

  /// No description provided for @unlinkCalendar.
  ///
  /// In en, this message translates to:
  /// **'Remove link'**
  String get unlinkCalendar;

  /// No description provided for @unlinkCalendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String unlinkCalendarTitle(String name);

  /// No description provided for @unlinkCalendarBody.
  ///
  /// In en, this message translates to:
  /// **'Coming events from this calendar are removed. Past ones stay.'**
  String get unlinkCalendarBody;

  /// No description provided for @linkedCalendarsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No calendars linked yet. Link a team\'s calendar and its trainings and matches show up for the child, kept up to date.'**
  String get linkedCalendarsEmpty;

  /// No description provided for @calendarPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Fetched by this phone, not by the Family Planner server, so the server never learns which team.'**
  String get calendarPrivacyNote;

  /// No description provided for @meetAt.
  ///
  /// In en, this message translates to:
  /// **'Meet at {time}'**
  String meetAt(String time);

  /// No description provided for @fromLinkedCalendar.
  ///
  /// In en, this message translates to:
  /// **'From a linked calendar'**
  String get fromLinkedCalendar;

  /// No description provided for @fromLinkedCalendarNamed.
  ///
  /// In en, this message translates to:
  /// **'From {name}, updated automatically'**
  String fromLinkedCalendarNamed(String name);

  /// No description provided for @reminderLeaveToMeet.
  ///
  /// In en, this message translates to:
  /// **'Time to leave · meet at {time}'**
  String reminderLeaveToMeet(String time);

  /// No description provided for @calendarLinkResponsible.
  ///
  /// In en, this message translates to:
  /// **'Usually takes them'**
  String get calendarLinkResponsible;

  /// No description provided for @calendarLinkNoOne.
  ///
  /// In en, this message translates to:
  /// **'No one in particular'**
  String get calendarLinkNoOne;

  /// No description provided for @editCalendarLink.
  ///
  /// In en, this message translates to:
  /// **'Linked calendar'**
  String get editCalendarLink;
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
