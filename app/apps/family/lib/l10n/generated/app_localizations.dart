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

  /// No description provided for @sharingOngoing.
  ///
  /// In en, this message translates to:
  /// **'Sharing where you are with your family'**
  String get sharingOngoing;

  /// No description provided for @hwResponsible.
  ///
  /// In en, this message translates to:
  /// **'{name} is on it'**
  String hwResponsible(String name);

  /// No description provided for @hwNobodyResponsible.
  ///
  /// In en, this message translates to:
  /// **'Nobody on it'**
  String get hwNobodyResponsible;

  /// No description provided for @hwSetResponsible.
  ///
  /// In en, this message translates to:
  /// **'Who is on it?'**
  String get hwSetResponsible;

  /// No description provided for @pollClosingTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{A question closes soon} other{{count} questions close soon}}'**
  String pollClosingTitle(int count);

  /// No description provided for @pollClosingBody.
  ///
  /// In en, this message translates to:
  /// **'{title} · closes {time}'**
  String pollClosingBody(String title, String time);

  /// No description provided for @repeatFrom.
  ///
  /// In en, this message translates to:
  /// **'Repeats from'**
  String get repeatFrom;

  /// No description provided for @repeatForever.
  ///
  /// In en, this message translates to:
  /// **'No end date'**
  String get repeatForever;

  /// No description provided for @repeatForeverHelp.
  ///
  /// In en, this message translates to:
  /// **'Keeps going until someone stops it'**
  String get repeatForeverHelp;

  /// No description provided for @repeatUntil.
  ///
  /// In en, this message translates to:
  /// **'Repeats until'**
  String get repeatUntil;

  /// No description provided for @repeatEndsBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'That end is before the start, so this would never happen.'**
  String get repeatEndsBeforeStart;

  /// No description provided for @rewards.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get rewards;

  /// No description provided for @rewardsOn.
  ///
  /// In en, this message translates to:
  /// **'Family jar and own worlds'**
  String get rewardsOn;

  /// No description provided for @rewardsOnHelp.
  ///
  /// In en, this message translates to:
  /// **'Finished chores and homework fill a shared jar each week, and grow each child\'s own world. Nobody is ranked.'**
  String get rewardsOnHelp;

  /// No description provided for @jarSize.
  ///
  /// In en, this message translates to:
  /// **'A full jar is'**
  String get jarSize;

  /// No description provided for @jarThings.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 thing} other{{count} things}}'**
  String jarThings(int count);

  /// No description provided for @jarFor.
  ///
  /// In en, this message translates to:
  /// **'What a full jar means'**
  String get jarFor;

  /// No description provided for @jarForHint.
  ///
  /// In en, this message translates to:
  /// **'Pizza night, we choose the film…'**
  String get jarForHint;

  /// No description provided for @jarTitle.
  ///
  /// In en, this message translates to:
  /// **'Family jar'**
  String get jarTitle;

  /// No description provided for @jarProgress.
  ///
  /// In en, this message translates to:
  /// **'{filled} of {size} this week'**
  String jarProgress(int filled, int size);

  /// No description provided for @jarFull.
  ///
  /// In en, this message translates to:
  /// **'The jar is full!'**
  String get jarFull;

  /// No description provided for @cityHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get cityHome;

  /// No description provided for @cityShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get cityShop;

  /// No description provided for @cityPark.
  ///
  /// In en, this message translates to:
  /// **'Park'**
  String get cityPark;

  /// No description provided for @cityRoad.
  ///
  /// In en, this message translates to:
  /// **'Street'**
  String get cityRoad;

  /// No description provided for @cityBuild.
  ///
  /// In en, this message translates to:
  /// **'What will you build here?'**
  String get cityBuild;

  /// No description provided for @cityShopNeedsSchool.
  ///
  /// In en, this message translates to:
  /// **'Shops open once your town has a school'**
  String get cityShopNeedsSchool;

  /// No description provided for @cityBuilding.
  ///
  /// In en, this message translates to:
  /// **'Being built today. You can still change it.'**
  String get cityBuilding;

  /// No description provided for @cityTakeBack.
  ///
  /// In en, this message translates to:
  /// **'Take it back'**
  String get cityTakeBack;

  /// No description provided for @cityTapToBuild.
  ///
  /// In en, this message translates to:
  /// **'Tap an empty plot to build'**
  String get cityTapToBuild;

  /// No description provided for @cityClosed.
  ///
  /// In en, this message translates to:
  /// **'This district opens as you do more'**
  String get cityClosed;

  /// No description provided for @cityWaiting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 thing to build} other{{count} things to build}}'**
  String cityWaiting(int count);

  /// No description provided for @cityStatus.
  ///
  /// In en, this message translates to:
  /// **'{name} · district {level}'**
  String cityStatus(String name, int level);

  /// No description provided for @cityHamlet.
  ///
  /// In en, this message translates to:
  /// **'Hamlet'**
  String get cityHamlet;

  /// No description provided for @cityVillage.
  ///
  /// In en, this message translates to:
  /// **'Village'**
  String get cityVillage;

  /// No description provided for @citySmallTown.
  ///
  /// In en, this message translates to:
  /// **'Small town'**
  String get citySmallTown;

  /// No description provided for @cityTown.
  ///
  /// In en, this message translates to:
  /// **'Town'**
  String get cityTown;

  /// No description provided for @cityCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get cityCity;

  /// No description provided for @cityBigCity.
  ///
  /// In en, this message translates to:
  /// **'Big city'**
  String get cityBigCity;

  /// No description provided for @guideCityTitle.
  ///
  /// In en, this message translates to:
  /// **'How your city grows'**
  String get guideCityTitle;

  /// No description provided for @guideCityEarn.
  ///
  /// In en, this message translates to:
  /// **'Every chore you finish gives you something to build. Homework counts too, once a grown-up has seen it done.'**
  String get guideCityEarn;

  /// No description provided for @guideCityBuild.
  ///
  /// In en, this message translates to:
  /// **'Tap an empty plot and choose a home, a shop, a park or a street.'**
  String get guideCityBuild;

  /// No description provided for @guideCityToday.
  ///
  /// In en, this message translates to:
  /// **'What you build today is a building site. You can change your mind until tomorrow, then it stays.'**
  String get guideCityToday;

  /// No description provided for @guideCityGrow.
  ///
  /// In en, this message translates to:
  /// **'Homes and parks grow as you keep going. A home next to a park or a shop can become a tower, and a park with homes around it grows faster.'**
  String get guideCityGrow;

  /// No description provided for @guideCityLearn.
  ///
  /// In en, this message translates to:
  /// **'Homework builds the town\'s school, library, observatory and university. Once there is a school, you can build shops.'**
  String get guideCityLearn;

  /// No description provided for @guideCityDistricts.
  ///
  /// In en, this message translates to:
  /// **'Do more, and new districts open around the edge. Every city has its own lake somewhere: build around it.'**
  String get guideCityDistricts;

  /// No description provided for @guideCityJar.
  ///
  /// In en, this message translates to:
  /// **'When the family jar is full, there are fireworks over the square, and a fountain appears.'**
  String get guideCityJar;

  /// No description provided for @guideCityKeep.
  ///
  /// In en, this message translates to:
  /// **'Nothing you build ever disappears, even if you have a quiet week.'**
  String get guideCityKeep;

  /// No description provided for @guideGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get guideGotIt;

  /// No description provided for @guideHowItWorks.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get guideHowItWorks;

  /// No description provided for @guideParentTitle.
  ///
  /// In en, this message translates to:
  /// **'Family jar and own cities'**
  String get guideParentTitle;

  /// No description provided for @guideParentIntro.
  ///
  /// In en, this message translates to:
  /// **'A shared goal for the week, and a city each child builds for themselves. Nobody is ranked or compared.'**
  String get guideParentIntro;

  /// No description provided for @guideParentJar.
  ///
  /// In en, this message translates to:
  /// **'The family jar: everything anyone finishes this week fills it, whoever did it. You choose how full it has to be and what a full jar means. It empties every Monday.'**
  String get guideParentJar;

  /// No description provided for @guideParentCity.
  ///
  /// In en, this message translates to:
  /// **'Each child\'s city: every chore they finish, and every homework you have seen done, gives them something to build. You can look at a child\'s city, but only they can build in it.'**
  String get guideParentCity;

  /// No description provided for @guideParentApproval.
  ///
  /// In en, this message translates to:
  /// **'A chore that asks for your approval counts once you approve it.'**
  String get guideParentApproval;

  /// No description provided for @guideParentSeen.
  ///
  /// In en, this message translates to:
  /// **'Homework counts for the jar as soon as it\'s done, but only grows a child\'s city after you mark it \"Seen it done\" in the homework list. That keeps ticking the box from being the way to win.'**
  String get guideParentSeen;

  /// No description provided for @guideParentKeep.
  ///
  /// In en, this message translates to:
  /// **'Nothing a child builds is ever taken away, and a quiet week costs nothing.'**
  String get guideParentKeep;

  /// No description provided for @guideJarBody.
  ///
  /// In en, this message translates to:
  /// **'Everything anyone in the family finishes this week fills the jar. When it is full, you get what the family decided — and every child\'s city has a festival. It starts empty again every Monday.'**
  String get guideJarBody;

  /// No description provided for @guideChildrensCities.
  ///
  /// In en, this message translates to:
  /// **'Each child builds their own city from what they finish. Here you can look at them, one at a time.'**
  String get guideChildrensCities;

  /// No description provided for @myWorld.
  ///
  /// In en, this message translates to:
  /// **'My city'**
  String get myWorld;

  /// No description provided for @myWorldSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Build it with what you do'**
  String get myWorldSubtitle;

  /// No description provided for @childrensWorlds.
  ///
  /// In en, this message translates to:
  /// **'The children\'s cities'**
  String get childrensWorlds;

  /// No description provided for @worldLevelUp.
  ///
  /// In en, this message translates to:
  /// **'Full! Here is a bigger one.'**
  String get worldLevelUp;

  /// No description provided for @worldNothingYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing to build yet. Every chore and homework you finish gives you something to build.'**
  String get worldNothingYet;

  /// No description provided for @worldOf.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s city'**
  String worldOf(String name);

  /// No description provided for @hwSeenIt.
  ///
  /// In en, this message translates to:
  /// **'Seen it done'**
  String get hwSeenIt;

  /// No description provided for @hwSeenBy.
  ///
  /// In en, this message translates to:
  /// **'Seen by {name}'**
  String hwSeenBy(String name);

  /// No description provided for @pollsAwaiting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 question waiting for you} other{{count} questions waiting for you}}'**
  String pollsAwaiting(int count);

  /// No description provided for @hwDueThatDay.
  ///
  /// In en, this message translates to:
  /// **'Homework due that day'**
  String get hwDueThatDay;

  /// No description provided for @summaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Your day'**
  String get summaryTitle;

  /// No description provided for @summaryQuiet.
  ///
  /// In en, this message translates to:
  /// **'Nothing on today.'**
  String get summaryQuiet;

  /// No description provided for @summaryNextAt.
  ///
  /// In en, this message translates to:
  /// **'next at {time}'**
  String summaryNextAt(String time);

  /// No description provided for @summaryConflicts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 clash} other{{count} clashes}}'**
  String summaryConflicts(int count);

  /// No description provided for @summaryAway.
  ///
  /// In en, this message translates to:
  /// **'{names} away'**
  String summaryAway(String names);

  /// No description provided for @summaryEveryoneAway.
  ///
  /// In en, this message translates to:
  /// **'Everyone is away'**
  String get summaryEveryoneAway;

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
  /// **'Every event from this calendar is removed, past ones too. They can be brought back from Recently deleted for a while.'**
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

  /// No description provided for @calendarAlreadyLinked.
  ///
  /// In en, this message translates to:
  /// **'This calendar is already linked'**
  String get calendarAlreadyLinked;

  /// No description provided for @setupWeekTitle.
  ///
  /// In en, this message translates to:
  /// **'Your usual week'**
  String get setupWeekTitle;

  /// No description provided for @setupWeekBody.
  ///
  /// In en, this message translates to:
  /// **'A few regular things, so the calendar starts out looking like your week. Change or remove them any time.'**
  String get setupWeekBody;

  /// No description provided for @seedSchool.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get seedSchool;

  /// No description provided for @seedPreschool.
  ///
  /// In en, this message translates to:
  /// **'Preschool'**
  String get seedPreschool;

  /// No description provided for @seedBlockFor.
  ///
  /// In en, this message translates to:
  /// **'{name}: {what}'**
  String seedBlockFor(String name, String what);

  /// No description provided for @seedWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays {from}–{to}'**
  String seedWeekdays(String from, String to);

  /// No description provided for @seedDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get seedDinner;

  /// No description provided for @seedEveryDay.
  ///
  /// In en, this message translates to:
  /// **'Every day {from}–{to}'**
  String seedEveryDay(String from, String to);

  /// No description provided for @seedActivity.
  ///
  /// In en, this message translates to:
  /// **'Add an activity'**
  String get seedActivity;

  /// No description provided for @seedActivitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Football, swimming, music…'**
  String get seedActivitySubtitle;

  /// No description provided for @exportMemberData.
  ///
  /// In en, this message translates to:
  /// **'Export {name}\'s data'**
  String exportMemberData(String name);

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t export.\n{error}'**
  String exportFailed(String error);

  /// No description provided for @formerMembers.
  ///
  /// In en, this message translates to:
  /// **'Former members'**
  String get formerMembers;

  /// No description provided for @eraseMemberData.
  ///
  /// In en, this message translates to:
  /// **'Erase {name}\'s data'**
  String eraseMemberData(String name);

  /// No description provided for @eraseMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Erase {name}\'s data?'**
  String eraseMemberTitle(String name);

  /// No description provided for @eraseMemberBody.
  ///
  /// In en, this message translates to:
  /// **'Their name, colour and age group are removed, and events only about them are deleted. Shared events and their chat messages stay, shown as from a former member. Export first if they want a copy. This can\'t be undone.'**
  String get eraseMemberBody;

  /// No description provided for @erase.
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get erase;

  /// No description provided for @memberErased.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s data is erased'**
  String memberErased(String name);

  /// No description provided for @weeklyReview.
  ///
  /// In en, this message translates to:
  /// **'Weekly review'**
  String get weeklyReview;

  /// No description provided for @weeklyReviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The week ahead: who drives, what clashes'**
  String get weeklyReviewSubtitle;

  /// No description provided for @reviewEvents.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing planned} =1{1 event} other{{count} events}}'**
  String reviewEvents(int count);

  /// No description provided for @reviewToDecide.
  ///
  /// In en, this message translates to:
  /// **'To decide'**
  String get reviewToDecide;

  /// No description provided for @reviewAllCovered.
  ///
  /// In en, this message translates to:
  /// **'Nothing to decide: every child\'s event has someone, and nobody is in two places at once.'**
  String get reviewAllCovered;

  /// No description provided for @reviewNoOne.
  ///
  /// In en, this message translates to:
  /// **'{when} · no one responsible'**
  String reviewNoOne(String when);

  /// No description provided for @reviewClash.
  ///
  /// In en, this message translates to:
  /// **'{name} has {first} and {second} at once'**
  String reviewClash(String name, String first, String second);

  /// No description provided for @reviewResponsible.
  ///
  /// In en, this message translates to:
  /// **'Who\'s responsible'**
  String get reviewResponsible;

  /// No description provided for @reviewTheWeek.
  ///
  /// In en, this message translates to:
  /// **'The week'**
  String get reviewTheWeek;

  /// No description provided for @reviewPlanCard.
  ///
  /// In en, this message translates to:
  /// **'Plan week {week}'**
  String reviewPlanCard(int week);

  /// No description provided for @reviewPlanCardBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Everything\'s covered. Take a look together.} =1{1 thing to decide.} other{{count} things to decide.}}'**
  String reviewPlanCardBody(int count);

  /// No description provided for @reviewNudgeBody.
  ///
  /// In en, this message translates to:
  /// **'A few minutes together plans the week ahead.'**
  String get reviewNudgeBody;

  /// No description provided for @shoppingAddHint.
  ///
  /// In en, this message translates to:
  /// **'Add… e.g. 2 dl grädde'**
  String get shoppingAddHint;

  /// No description provided for @shoppingEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing on the list. Add things above, or a recipe\'s ingredients from Recipes.'**
  String get shoppingEmpty;

  /// No description provided for @shoppingBought.
  ///
  /// In en, this message translates to:
  /// **'Bought ({count})'**
  String shoppingBought(int count);

  /// No description provided for @shoppingClearBought.
  ///
  /// In en, this message translates to:
  /// **'Clear bought'**
  String get shoppingClearBought;

  /// No description provided for @shoppingNewList.
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get shoppingNewList;

  /// No description provided for @shoppingListName.
  ///
  /// In en, this message translates to:
  /// **'List name'**
  String get shoppingListName;

  /// No description provided for @shoppingDefaultList.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get shoppingDefaultList;

  /// No description provided for @recipes.
  ///
  /// In en, this message translates to:
  /// **'Recipes'**
  String get recipes;

  /// No description provided for @shoppingFor.
  ///
  /// In en, this message translates to:
  /// **'For {sources}'**
  String shoppingFor(String sources);

  /// No description provided for @removeItem.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeItem;

  /// No description provided for @aisleProduce.
  ///
  /// In en, this message translates to:
  /// **'Fruit & veg'**
  String get aisleProduce;

  /// No description provided for @aisleBakery.
  ///
  /// In en, this message translates to:
  /// **'Bread'**
  String get aisleBakery;

  /// No description provided for @aisleDairy.
  ///
  /// In en, this message translates to:
  /// **'Dairy & eggs'**
  String get aisleDairy;

  /// No description provided for @aisleMeat.
  ///
  /// In en, this message translates to:
  /// **'Meat & fish'**
  String get aisleMeat;

  /// No description provided for @aisleFrozen.
  ///
  /// In en, this message translates to:
  /// **'Frozen'**
  String get aisleFrozen;

  /// No description provided for @aislePantry.
  ///
  /// In en, this message translates to:
  /// **'Pantry'**
  String get aislePantry;

  /// No description provided for @aisleHousehold.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get aisleHousehold;

  /// No description provided for @aisleOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get aisleOther;

  /// No description provided for @recipesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recipes yet. Import one from ICA or another recipe site, or write your own.'**
  String get recipesEmpty;

  /// No description provided for @importRecipe.
  ///
  /// In en, this message translates to:
  /// **'Import recipe'**
  String get importRecipe;

  /// No description provided for @newRecipe.
  ///
  /// In en, this message translates to:
  /// **'New recipe'**
  String get newRecipe;

  /// No description provided for @recipeLink.
  ///
  /// In en, this message translates to:
  /// **'Link to the recipe'**
  String get recipeLink;

  /// No description provided for @recipeLinkHint.
  ///
  /// In en, this message translates to:
  /// **'ica.se, koket.se, arla.se …'**
  String get recipeLinkHint;

  /// No description provided for @recipeFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read a recipe there.\n{error}'**
  String recipeFetchFailed(String error);

  /// No description provided for @reviewRecipe.
  ///
  /// In en, this message translates to:
  /// **'Check the recipe'**
  String get reviewRecipe;

  /// No description provided for @recipeTitle.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get recipeTitle;

  /// No description provided for @recipeServings.
  ///
  /// In en, this message translates to:
  /// **'Portions'**
  String get recipeServings;

  /// No description provided for @recipeIngredients.
  ///
  /// In en, this message translates to:
  /// **'Ingredients, one per line'**
  String get recipeIngredients;

  /// No description provided for @recipeNotes.
  ///
  /// In en, this message translates to:
  /// **'Your notes'**
  String get recipeNotes;

  /// No description provided for @recipeReviewNote.
  ///
  /// In en, this message translates to:
  /// **'Check the amounts before saving: a wrong one ends up on every list made from it.'**
  String get recipeReviewNote;

  /// No description provided for @recipeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String recipeMinutes(int minutes);

  /// No description provided for @addToList.
  ///
  /// In en, this message translates to:
  /// **'Add to {list}'**
  String addToList(String list);

  /// No description provided for @addedToList.
  ///
  /// In en, this message translates to:
  /// **'Added to {list}'**
  String addedToList(String list);

  /// No description provided for @removeFromList.
  ///
  /// In en, this message translates to:
  /// **'Take off {list}'**
  String removeFromList(String list);

  /// No description provided for @removedFromList.
  ///
  /// In en, this message translates to:
  /// **'Taken off {list}'**
  String removedFromList(String list);

  /// No description provided for @openRecipeSite.
  ///
  /// In en, this message translates to:
  /// **'Open the recipe'**
  String get openRecipeSite;

  /// No description provided for @deleteRecipe.
  ///
  /// In en, this message translates to:
  /// **'Delete recipe'**
  String get deleteRecipe;

  /// No description provided for @portionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 portion} other{{count} portions}}'**
  String portionsCount(int count);

  /// No description provided for @notOnCatalogue.
  ///
  /// In en, this message translates to:
  /// **'Not recognised: stays as written'**
  String get notOnCatalogue;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @addDinner.
  ///
  /// In en, this message translates to:
  /// **'Add dinner'**
  String get addDinner;

  /// No description provided for @somethingElse.
  ///
  /// In en, this message translates to:
  /// **'Something else…'**
  String get somethingElse;

  /// No description provided for @mealTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Tacos, leftovers, pizza out'**
  String get mealTitleHint;

  /// No description provided for @menuToList.
  ///
  /// In en, this message translates to:
  /// **'Put the week on {list}'**
  String menuToList(String list);

  /// No description provided for @menuOnList.
  ///
  /// In en, this message translates to:
  /// **'The week\'s menu is on {list}'**
  String menuOnList(String list);

  /// No description provided for @addSide.
  ///
  /// In en, this message translates to:
  /// **'Add a side'**
  String get addSide;

  /// No description provided for @whoCooks.
  ///
  /// In en, this message translates to:
  /// **'Who\'s cooking'**
  String get whoCooks;

  /// No description provided for @removeMeal.
  ///
  /// In en, this message translates to:
  /// **'Take off the menu'**
  String get removeMeal;

  /// No description provided for @searchRecipes.
  ///
  /// In en, this message translates to:
  /// **'Search recipes'**
  String get searchRecipes;

  /// No description provided for @mealCookedBy.
  ///
  /// In en, this message translates to:
  /// **'{name} cooks'**
  String mealCookedBy(String name);

  /// No description provided for @nobodyYet.
  ///
  /// In en, this message translates to:
  /// **'Not decided'**
  String get nobodyYet;

  /// No description provided for @dinnerTonight.
  ///
  /// In en, this message translates to:
  /// **'Dinner tonight'**
  String get dinnerTonight;

  /// No description provided for @staples.
  ///
  /// In en, this message translates to:
  /// **'Staples'**
  String get staples;

  /// No description provided for @staplesHint.
  ///
  /// In en, this message translates to:
  /// **'Milk, bread, coffee… what goes on every list'**
  String get staplesHint;

  /// No description provided for @addStaples.
  ///
  /// In en, this message translates to:
  /// **'Add staples'**
  String get addStaples;

  /// No description provided for @startWithStaples.
  ///
  /// In en, this message translates to:
  /// **'Start with the staples'**
  String get startWithStaples;

  /// No description provided for @staplesAdded.
  ///
  /// In en, this message translates to:
  /// **'Staples added'**
  String get staplesAdded;

  /// No description provided for @pickOf.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s pick'**
  String pickOf(String name);

  /// No description provided for @picksLeft.
  ///
  /// In en, this message translates to:
  /// **'Still to pick: {names}'**
  String picksLeft(String names);

  /// No description provided for @allPicked.
  ///
  /// In en, this message translates to:
  /// **'Every child has had their pick this week'**
  String get allPicked;

  /// No description provided for @yourPickHint.
  ///
  /// In en, this message translates to:
  /// **'Choose one dinner this week: tap a free day'**
  String get yourPickHint;

  /// No description provided for @whosePick.
  ///
  /// In en, this message translates to:
  /// **'Whose pick'**
  String get whosePick;

  /// No description provided for @ideas.
  ///
  /// In en, this message translates to:
  /// **'Ideas & polls'**
  String get ideas;

  /// No description provided for @suggestMeal.
  ///
  /// In en, this message translates to:
  /// **'Suggest a meal'**
  String get suggestMeal;

  /// No description provided for @suggestions.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get suggestions;

  /// No description provided for @noSuggestions.
  ///
  /// In en, this message translates to:
  /// **'No suggestions yet. Anyone can suggest a meal, any time.'**
  String get noSuggestions;

  /// No description provided for @suggestedBy.
  ///
  /// In en, this message translates to:
  /// **'Suggested by {name}'**
  String suggestedBy(String name);

  /// No description provided for @putOnMenu.
  ///
  /// In en, this message translates to:
  /// **'Put on the menu'**
  String get putOnMenu;

  /// No description provided for @startPoll.
  ///
  /// In en, this message translates to:
  /// **'Start a poll'**
  String get startPoll;

  /// No description provided for @pollFor.
  ///
  /// In en, this message translates to:
  /// **'Which dinner'**
  String get pollFor;

  /// No description provided for @pollOptions.
  ///
  /// In en, this message translates to:
  /// **'Choose 2 to 5 options'**
  String get pollOptions;

  /// No description provided for @pollCloses.
  ///
  /// In en, this message translates to:
  /// **'Voting closes {when}'**
  String pollCloses(String when);

  /// No description provided for @pollVoted.
  ///
  /// In en, this message translates to:
  /// **'Voted: {names}'**
  String pollVoted(String names);

  /// No description provided for @pollNobodyVoted.
  ///
  /// In en, this message translates to:
  /// **'Nobody has voted yet'**
  String get pollNobodyVoted;

  /// No description provided for @pollTickHint.
  ///
  /// In en, this message translates to:
  /// **'Tick every meal you\'d be happy to eat'**
  String get pollTickHint;

  /// No description provided for @closeNow.
  ///
  /// In en, this message translates to:
  /// **'Close now'**
  String get closeNow;

  /// No description provided for @chooseInstead.
  ///
  /// In en, this message translates to:
  /// **'Choose instead'**
  String get chooseInstead;

  /// No description provided for @pollWon.
  ///
  /// In en, this message translates to:
  /// **'Won: {option}'**
  String pollWon(String option);

  /// No description provided for @pollOverridden.
  ///
  /// In en, this message translates to:
  /// **'{name} chose this; the vote said {option}'**
  String pollOverridden(String name, String option);

  /// No description provided for @pollNoVotes.
  ///
  /// In en, this message translates to:
  /// **'Closed without votes'**
  String get pollNoVotes;

  /// No description provided for @polls.
  ///
  /// In en, this message translates to:
  /// **'Polls'**
  String get polls;

  /// No description provided for @pollChat.
  ///
  /// In en, this message translates to:
  /// **'Vote on {title}: under Shopping › Menu › Ideas & polls'**
  String pollChat(String title);

  /// No description provided for @pickDay.
  ///
  /// In en, this message translates to:
  /// **'Which day'**
  String get pickDay;

  /// No description provided for @dietTitle.
  ///
  /// In en, this message translates to:
  /// **'Food & allergies'**
  String get dietTitle;

  /// No description provided for @dietAllergy.
  ///
  /// In en, this message translates to:
  /// **'Allergy'**
  String get dietAllergy;

  /// No description provided for @dietIntolerance.
  ///
  /// In en, this message translates to:
  /// **'Intolerance'**
  String get dietIntolerance;

  /// No description provided for @dietDislike.
  ///
  /// In en, this message translates to:
  /// **'Doesn\'t like'**
  String get dietDislike;

  /// No description provided for @dietDiet.
  ///
  /// In en, this message translates to:
  /// **'Diet'**
  String get dietDiet;

  /// No description provided for @dietWhat.
  ///
  /// In en, this message translates to:
  /// **'What'**
  String get dietWhat;

  /// No description provided for @dietWhatHint.
  ///
  /// In en, this message translates to:
  /// **'nuts, lactose, coriander…'**
  String get dietWhatHint;

  /// No description provided for @dietStrict.
  ///
  /// In en, this message translates to:
  /// **'Strict: never in a poll'**
  String get dietStrict;

  /// No description provided for @dietEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing noted.'**
  String get dietEmpty;

  /// No description provided for @dietAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a note'**
  String get dietAdd;

  /// No description provided for @dietConflict.
  ///
  /// In en, this message translates to:
  /// **'{name}: {type} · {line}'**
  String dietConflict(String name, String type, String line);

  /// No description provided for @dietLeftOut.
  ///
  /// In en, this message translates to:
  /// **'Left out: {meal} ({name}: {type})'**
  String dietLeftOut(String meal, String name, String type);

  /// No description provided for @foodAndAllergies.
  ///
  /// In en, this message translates to:
  /// **'Food & allergies ({count})'**
  String foodAndAllergies(int count);

  /// No description provided for @cookAgain.
  ///
  /// In en, this message translates to:
  /// **'Cook this again'**
  String get cookAgain;

  /// No description provided for @todos.
  ///
  /// In en, this message translates to:
  /// **'To-dos'**
  String get todos;

  /// No description provided for @todosSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Chores, prep and errands, shared fairly'**
  String get todosSubtitle;

  /// No description provided for @todoMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get todoMine;

  /// No description provided for @todoFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get todoFamily;

  /// No description provided for @todoInbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get todoInbox;

  /// No description provided for @newTodo.
  ///
  /// In en, this message translates to:
  /// **'New to-do'**
  String get newTodo;

  /// No description provided for @todoTitle.
  ///
  /// In en, this message translates to:
  /// **'What needs doing'**
  String get todoTitle;

  /// No description provided for @todoDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get todoDue;

  /// No description provided for @todoNoDue.
  ///
  /// In en, this message translates to:
  /// **'No due date'**
  String get todoNoDue;

  /// No description provided for @todoWho.
  ///
  /// In en, this message translates to:
  /// **'Who'**
  String get todoWho;

  /// No description provided for @todoPool.
  ///
  /// In en, this message translates to:
  /// **'Anyone (family pool)'**
  String get todoPool;

  /// No description provided for @todoApproval.
  ///
  /// In en, this message translates to:
  /// **'A parent confirms it\'s done'**
  String get todoApproval;

  /// No description provided for @todoBlocking.
  ///
  /// In en, this message translates to:
  /// **'Needed for the event to happen'**
  String get todoBlocking;

  /// No description provided for @todoDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get todoDone;

  /// No description provided for @todoClaim.
  ///
  /// In en, this message translates to:
  /// **'I\'ll do it'**
  String get todoClaim;

  /// No description provided for @todoUnclaim.
  ///
  /// In en, this message translates to:
  /// **'Give it back'**
  String get todoUnclaim;

  /// No description provided for @todoAskSomeone.
  ///
  /// In en, this message translates to:
  /// **'Ask someone else'**
  String get todoAskSomeone;

  /// No description provided for @todoSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip this time'**
  String get todoSkip;

  /// No description provided for @todoAssign.
  ///
  /// In en, this message translates to:
  /// **'Give to'**
  String get todoAssign;

  /// No description provided for @todoApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get todoApprove;

  /// No description provided for @todoReopen.
  ///
  /// In en, this message translates to:
  /// **'Not done yet'**
  String get todoReopen;

  /// No description provided for @todoAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get todoAccept;

  /// No description provided for @todoDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get todoDecline;

  /// No description provided for @todoNote.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get todoNote;

  /// No description provided for @todoAskedBy.
  ///
  /// In en, this message translates to:
  /// **'{name} asks you to take this'**
  String todoAskedBy(String name);

  /// No description provided for @todoAwaiting.
  ///
  /// In en, this message translates to:
  /// **'Done by {name}, waiting for approval'**
  String todoAwaiting(String name);

  /// No description provided for @todoEmptyMine.
  ///
  /// In en, this message translates to:
  /// **'Nothing on your list.'**
  String get todoEmptyMine;

  /// No description provided for @todoEmptyFamily.
  ///
  /// In en, this message translates to:
  /// **'Nothing waiting in the family pool.'**
  String get todoEmptyFamily;

  /// No description provided for @todoEmptyInbox.
  ///
  /// In en, this message translates to:
  /// **'Nothing waiting for you.'**
  String get todoEmptyInbox;

  /// No description provided for @todoOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get todoOverdue;

  /// No description provided for @todoDueAt.
  ///
  /// In en, this message translates to:
  /// **'Due {when}'**
  String todoDueAt(String when);

  /// No description provided for @todoHistory.
  ///
  /// In en, this message translates to:
  /// **'What happened'**
  String get todoHistory;

  /// No description provided for @histCreated.
  ///
  /// In en, this message translates to:
  /// **'created'**
  String get histCreated;

  /// No description provided for @histClaimed.
  ///
  /// In en, this message translates to:
  /// **'took it'**
  String get histClaimed;

  /// No description provided for @histUnclaimed.
  ///
  /// In en, this message translates to:
  /// **'gave it back'**
  String get histUnclaimed;

  /// No description provided for @histAssigned.
  ///
  /// In en, this message translates to:
  /// **'gave it to {name}'**
  String histAssigned(String name);

  /// No description provided for @histDelegated.
  ///
  /// In en, this message translates to:
  /// **'asked {name}'**
  String histDelegated(String name);

  /// No description provided for @histAccepted.
  ///
  /// In en, this message translates to:
  /// **'accepted'**
  String get histAccepted;

  /// No description provided for @histDeclined.
  ///
  /// In en, this message translates to:
  /// **'declined, back to {name}'**
  String histDeclined(String name);

  /// No description provided for @histDone.
  ///
  /// In en, this message translates to:
  /// **'did it'**
  String get histDone;

  /// No description provided for @histApproved.
  ///
  /// In en, this message translates to:
  /// **'approved'**
  String get histApproved;

  /// No description provided for @histReopened.
  ///
  /// In en, this message translates to:
  /// **'reopened'**
  String get histReopened;

  /// No description provided for @histSkipped.
  ///
  /// In en, this message translates to:
  /// **'skipped'**
  String get histSkipped;

  /// No description provided for @histMoved.
  ///
  /// In en, this message translates to:
  /// **'moved with the event'**
  String get histMoved;

  /// No description provided for @histCancelled.
  ///
  /// In en, this message translates to:
  /// **'cancelled with the event'**
  String get histCancelled;

  /// No description provided for @recurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get recurring;

  /// No description provided for @recurringSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Chores on a schedule, turns shared'**
  String get recurringSubtitle;

  /// No description provided for @newChore.
  ///
  /// In en, this message translates to:
  /// **'New recurring chore'**
  String get newChore;

  /// No description provided for @choreDays.
  ///
  /// In en, this message translates to:
  /// **'Which days'**
  String get choreDays;

  /// No description provided for @choreTime.
  ///
  /// In en, this message translates to:
  /// **'At'**
  String get choreTime;

  /// No description provided for @choreEvery.
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get choreEvery;

  /// No description provided for @choreWeekly.
  ///
  /// In en, this message translates to:
  /// **'week'**
  String get choreWeekly;

  /// No description provided for @choreBiweekly.
  ///
  /// In en, this message translates to:
  /// **'other week'**
  String get choreBiweekly;

  /// No description provided for @choreTurns.
  ///
  /// In en, this message translates to:
  /// **'Who takes turns'**
  String get choreTurns;

  /// No description provided for @choreTurnsHint.
  ///
  /// In en, this message translates to:
  /// **'Pick one to always do it, or several to take turns; none leaves it to anyone'**
  String get choreTurnsHint;

  /// No description provided for @chorePaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get chorePaused;

  /// No description provided for @prep.
  ///
  /// In en, this message translates to:
  /// **'Prep'**
  String get prep;

  /// No description provided for @addPrep.
  ///
  /// In en, this message translates to:
  /// **'Add prep'**
  String get addPrep;

  /// No description provided for @prepWhen.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get prepWhen;

  /// No description provided for @prepSameTime.
  ///
  /// In en, this message translates to:
  /// **'At the start'**
  String get prepSameTime;

  /// No description provided for @prepHoursBefore.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, =1{1 hour before} other{{hours} hours before}}'**
  String prepHoursBefore(int hours);

  /// No description provided for @prepDaysBefore.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{The day before} other{{days} days before}}'**
  String prepDaysBefore(int days);

  /// No description provided for @todayTodos.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 thing to do} other{{count} things to do}}'**
  String todayTodos(int count);

  /// No description provided for @todayTodosSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Due today or overdue'**
  String get todayTodosSubtitle;

  /// No description provided for @reviewDinnersOpen.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 dinner not planned} other{{count} dinners not planned}}'**
  String reviewDinnersOpen(int count);

  /// No description provided for @reviewUnclaimed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 to-do nobody has taken} other{{count} to-dos nobody has taken}}'**
  String reviewUnclaimed(int count);

  /// No description provided for @quickCaptureHint.
  ///
  /// In en, this message translates to:
  /// **'Quick: football tuesdays 17:30 at the hall'**
  String get quickCaptureHint;

  /// No description provided for @quickCaptureFill.
  ///
  /// In en, this message translates to:
  /// **'Fill in'**
  String get quickCaptureFill;

  /// No description provided for @repeatsUntil.
  ///
  /// In en, this message translates to:
  /// **'{rule}, until {date}'**
  String repeatsUntil(String rule, String date);

  /// No description provided for @celebrations.
  ///
  /// In en, this message translates to:
  /// **'Celebrations'**
  String get celebrations;

  /// No description provided for @celebrationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Birthdays and other days, with gift reminders'**
  String get celebrationsSubtitle;

  /// No description provided for @celebrationTurns.
  ///
  /// In en, this message translates to:
  /// **'{name} turns {age}'**
  String celebrationTurns(String name, int age);

  /// No description provided for @inDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Today} =1{Tomorrow} other{In {days} days}}'**
  String inDays(int days);

  /// No description provided for @personName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get personName;

  /// No description provided for @personLabel.
  ///
  /// In en, this message translates to:
  /// **'What you call them'**
  String get personLabel;

  /// No description provided for @personLabelHint.
  ///
  /// In en, this message translates to:
  /// **'Farmor, bonuspappa, Majas kompis'**
  String get personLabelHint;

  /// No description provided for @personDay.
  ///
  /// In en, this message translates to:
  /// **'The day'**
  String get personDay;

  /// No description provided for @personYearUnknown.
  ///
  /// In en, this message translates to:
  /// **'Year not known'**
  String get personYearUnknown;

  /// No description provided for @personType.
  ///
  /// In en, this message translates to:
  /// **'What day'**
  String get personType;

  /// No description provided for @typeBirthday.
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get typeBirthday;

  /// No description provided for @typeNameday.
  ///
  /// In en, this message translates to:
  /// **'Name day'**
  String get typeNameday;

  /// No description provided for @typeAnniversary.
  ///
  /// In en, this message translates to:
  /// **'Anniversary'**
  String get typeAnniversary;

  /// No description provided for @typeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get typeOther;

  /// No description provided for @personLead.
  ///
  /// In en, this message translates to:
  /// **'Remind the adults'**
  String get personLead;

  /// No description provided for @personLeadDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{On the day} =1{1 day before} other{{days} days before}}'**
  String personLeadDays(int days);

  /// No description provided for @personNotes.
  ///
  /// In en, this message translates to:
  /// **'Gift ideas, sizes'**
  String get personNotes;

  /// No description provided for @personIsMember.
  ///
  /// In en, this message translates to:
  /// **'In the family'**
  String get personIsMember;

  /// No description provided for @addPerson.
  ///
  /// In en, this message translates to:
  /// **'Add someone'**
  String get addPerson;

  /// No description provided for @noCelebrations.
  ///
  /// In en, this message translates to:
  /// **'No days to celebrate yet.'**
  String get noCelebrations;

  /// No description provided for @removePerson.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removePerson;

  /// No description provided for @memberBirthday.
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get memberBirthday;

  /// No description provided for @wishlist.
  ///
  /// In en, this message translates to:
  /// **'Wishlist'**
  String get wishlist;

  /// No description provided for @wishlistFor.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s wishes'**
  String wishlistFor(String name);

  /// No description provided for @wishlistEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing wished for yet.'**
  String get wishlistEmpty;

  /// No description provided for @addWish.
  ///
  /// In en, this message translates to:
  /// **'Add a wish'**
  String get addWish;

  /// No description provided for @wishTitle.
  ///
  /// In en, this message translates to:
  /// **'What'**
  String get wishTitle;

  /// No description provided for @wishLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get wishLink;

  /// No description provided for @wishNote.
  ///
  /// In en, this message translates to:
  /// **'Note, size, colour'**
  String get wishNote;

  /// No description provided for @wishClaim.
  ///
  /// In en, this message translates to:
  /// **'I\'ll buy this'**
  String get wishClaim;

  /// No description provided for @wishUnclaim.
  ///
  /// In en, this message translates to:
  /// **'I won\'t buy it after all'**
  String get wishUnclaim;

  /// No description provided for @wishClaimedBy.
  ///
  /// In en, this message translates to:
  /// **'{name} buys this'**
  String wishClaimedBy(String name);

  /// No description provided for @wishReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get wishReceived;

  /// No description provided for @newWishlist.
  ///
  /// In en, this message translates to:
  /// **'Start a new list'**
  String get newWishlist;

  /// No description provided for @newWishlistBody.
  ///
  /// In en, this message translates to:
  /// **'Wishes not received move to the new list; the old one is kept.'**
  String get newWishlistBody;

  /// No description provided for @wishlistName.
  ///
  /// In en, this message translates to:
  /// **'{name} {year}'**
  String wishlistName(String name, int year);

  /// No description provided for @homework.
  ///
  /// In en, this message translates to:
  /// **'Homework'**
  String get homework;

  /// No description provided for @homeworkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Due dates, and time to do it'**
  String get homeworkSubtitle;

  /// No description provided for @homeworkEmpty.
  ///
  /// In en, this message translates to:
  /// **'No homework.'**
  String get homeworkEmpty;

  /// No description provided for @addHomework.
  ///
  /// In en, this message translates to:
  /// **'Add homework'**
  String get addHomework;

  /// No description provided for @hwWho.
  ///
  /// In en, this message translates to:
  /// **'Whose'**
  String get hwWho;

  /// No description provided for @hwSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get hwSubject;

  /// No description provided for @hwNewSubject.
  ///
  /// In en, this message translates to:
  /// **'New subject…'**
  String get hwNewSubject;

  /// No description provided for @hwSubjectName.
  ///
  /// In en, this message translates to:
  /// **'Subject name'**
  String get hwSubjectName;

  /// No description provided for @hwTitle.
  ///
  /// In en, this message translates to:
  /// **'What'**
  String get hwTitle;

  /// No description provided for @hwTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Maths p. 42–44'**
  String get hwTitleHint;

  /// No description provided for @hwType.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get hwType;

  /// No description provided for @hwAssignment.
  ///
  /// In en, this message translates to:
  /// **'Assignment'**
  String get hwAssignment;

  /// No description provided for @hwReading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get hwReading;

  /// No description provided for @hwTest.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get hwTest;

  /// No description provided for @hwProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get hwProject;

  /// No description provided for @hwHandIn.
  ///
  /// In en, this message translates to:
  /// **'Hand-in'**
  String get hwHandIn;

  /// No description provided for @hwDue.
  ///
  /// In en, this message translates to:
  /// **'Due {when}'**
  String hwDue(String when);

  /// No description provided for @hwEveryWeek.
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get hwEveryWeek;

  /// No description provided for @hwEveryWeekHelp.
  ///
  /// In en, this message translates to:
  /// **'One piece of homework, due once.'**
  String get hwEveryWeekHelp;

  /// No description provided for @hwEveryWeekOn.
  ///
  /// In en, this message translates to:
  /// **'A new one every {day}, each ticked off on its own.'**
  String hwEveryWeekOn(String day);

  /// No description provided for @calendarBusy.
  ///
  /// In en, this message translates to:
  /// **'Busy'**
  String get calendarBusy;

  /// No description provided for @phoneCalendars.
  ///
  /// In en, this message translates to:
  /// **'This phone’s calendars'**
  String get phoneCalendars;

  /// No description provided for @phoneCalendarsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show your Google, Outlook or work calendar in the family’s'**
  String get phoneCalendarsSubtitle;

  /// No description provided for @phoneCalendarsHelp.
  ///
  /// In en, this message translates to:
  /// **'Calendars this phone already syncs. Nothing is sent to Google or Microsoft: the app reads what is on the device.'**
  String get phoneCalendarsHelp;

  /// No description provided for @phoneCalendarsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Only what you switch on is shared, and only with your family. The server cannot read any of it.'**
  String get phoneCalendarsPrivacy;

  /// No description provided for @phoneCalendarsDenied.
  ///
  /// In en, this message translates to:
  /// **'The app has no access to this phone’s calendars. Grant it in Settings and come back.'**
  String get phoneCalendarsDenied;

  /// No description provided for @phoneCalendarsNone.
  ///
  /// In en, this message translates to:
  /// **'No calendars on this phone.'**
  String get phoneCalendarsNone;

  /// No description provided for @phoneCalendarBusy.
  ///
  /// In en, this message translates to:
  /// **'Busy only'**
  String get phoneCalendarBusy;

  /// No description provided for @phoneCalendarFull.
  ///
  /// In en, this message translates to:
  /// **'Full details'**
  String get phoneCalendarFull;

  /// No description provided for @dictationStart.
  ///
  /// In en, this message translates to:
  /// **'Say it out loud'**
  String get dictationStart;

  /// No description provided for @dictationStop.
  ///
  /// In en, this message translates to:
  /// **'Stop listening'**
  String get dictationStop;

  /// No description provided for @dictationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This phone cannot listen. Check the microphone permission in Settings.'**
  String get dictationUnavailable;

  /// No description provided for @weekLetter.
  ///
  /// In en, this message translates to:
  /// **'Week letter'**
  String get weekLetter;

  /// No description provided for @weekLetterHelp.
  ///
  /// In en, this message translates to:
  /// **'Share the teacher’s letter into the app, or paste it here. Nothing is saved until you say so.'**
  String get weekLetterHelp;

  /// No description provided for @weekLetterPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste the letter’s text'**
  String get weekLetterPaste;

  /// No description provided for @weekLetterRead.
  ///
  /// In en, this message translates to:
  /// **'Find the homework'**
  String get weekLetterRead;

  /// No description provided for @weekLetterNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this looks like homework. Add it by hand if it should be there.'**
  String get weekLetterNothing;

  /// No description provided for @weekLetterNoDate.
  ///
  /// In en, this message translates to:
  /// **'No date given'**
  String get weekLetterNoDate;

  /// No description provided for @weekLetterUnreadable.
  ///
  /// In en, this message translates to:
  /// **'That file could not be read. Open it and paste the text instead.'**
  String get weekLetterUnreadable;

  /// No description provided for @hwWhose.
  ///
  /// In en, this message translates to:
  /// **'Whose homework'**
  String get hwWhose;

  /// No description provided for @weekLetterSave.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Save 1} other{Save {count}}}'**
  String weekLetterSave(int count);

  /// No description provided for @weekLetterPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photograph it'**
  String get weekLetterPhoto;

  /// No description provided for @importRecipeFromPlanning.
  ///
  /// In en, this message translates to:
  /// **'Paste a link and it goes straight on this meal'**
  String get importRecipeFromPlanning;

  /// No description provided for @noRecipesFound.
  ///
  /// In en, this message translates to:
  /// **'No saved recipe matches “{query}”.'**
  String noRecipesFound(String query);

  /// No description provided for @sendToShop.
  ///
  /// In en, this message translates to:
  /// **'Send the list'**
  String get sendToShop;

  /// No description provided for @unbindThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Remove this device'**
  String get unbindThisDevice;

  /// No description provided for @unbindThisDeviceExplain.
  ///
  /// In en, this message translates to:
  /// **'This phone leaves the family: its keys are forgotten and everything stored on it is deleted. The family keeps everything. To use it again, pair it from a device that is still in the family. Anything written here and not yet synced is lost.'**
  String get unbindThisDeviceExplain;

  /// No description provided for @unbindConfirm.
  ///
  /// In en, this message translates to:
  /// **'Leave the family'**
  String get unbindConfirm;

  /// No description provided for @clearList.
  ///
  /// In en, this message translates to:
  /// **'Clear the list'**
  String get clearList;

  /// No description provided for @clearTicked.
  ///
  /// In en, this message translates to:
  /// **'Clear what is ticked'**
  String get clearTicked;

  /// No description provided for @clearEverything.
  ///
  /// In en, this message translates to:
  /// **'Clear everything'**
  String get clearEverything;

  /// No description provided for @clearEverythingExplain.
  ///
  /// In en, this message translates to:
  /// **'Every item comes off this list, ticked or not. The list itself stays, and anything cleared can be brought back from Recently deleted.'**
  String get clearEverythingExplain;

  /// No description provided for @clearedItems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item cleared} other{{count} items cleared}}'**
  String clearedItems(int count);

  /// No description provided for @weekLetterLinkShared.
  ///
  /// In en, this message translates to:
  /// **'That link needs a school login'**
  String get weekLetterLinkShared;

  /// No description provided for @weekLetterLinkSharedHelp.
  ///
  /// In en, this message translates to:
  /// **'The app cannot open a SharePoint or Google Docs link. Open the document in Word, Teams or OneDrive and share the document itself — or copy its text into the box below.'**
  String get weekLetterLinkSharedHelp;

  /// No description provided for @whichClass.
  ///
  /// In en, this message translates to:
  /// **'Which class'**
  String get whichClass;

  /// No description provided for @weekPlanRemember.
  ///
  /// In en, this message translates to:
  /// **'Keep this for next week'**
  String get weekPlanRemember;

  /// No description provided for @weekPlanRemembered.
  ///
  /// In en, this message translates to:
  /// **'Saved — check it from Homework each week'**
  String get weekPlanRemembered;

  /// No description provided for @weekPlanCheck.
  ///
  /// In en, this message translates to:
  /// **'This week’s school plan'**
  String get weekPlanCheck;

  /// No description provided for @weekPlanNone.
  ///
  /// In en, this message translates to:
  /// **'No school plan saved. Share one from Word or Teams, paste its text, or photograph the whiteboard.'**
  String get weekPlanNone;

  /// No description provided for @weekLetterPasteOrLink.
  ///
  /// In en, this message translates to:
  /// **'Paste the letter’s text, or a link to it'**
  String get weekLetterPasteOrLink;

  /// No description provided for @schoolPlans.
  ///
  /// In en, this message translates to:
  /// **'School week plans'**
  String get schoolPlans;

  /// No description provided for @schoolPlansSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Homework from the school’s own weekly document'**
  String get schoolPlansSubtitle;

  /// No description provided for @schoolPlansHelp.
  ///
  /// In en, this message translates to:
  /// **'Set up once per child: the address of the school’s week plan and which class is theirs. Their homework then arrives with everything else. The document is fetched by this phone — the server never sees the school’s address.'**
  String get schoolPlansHelp;

  /// No description provided for @schoolPlansEmpty.
  ///
  /// In en, this message translates to:
  /// **'No school plans yet. Add one if your school publishes a weekly document; if it doesn’t, homework can still be shared, pasted or photographed into the app.'**
  String get schoolPlansEmpty;

  /// No description provided for @schoolPlanAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a school plan'**
  String get schoolPlanAdd;

  /// No description provided for @schoolPlanUrl.
  ///
  /// In en, this message translates to:
  /// **'Link to the week plan'**
  String get schoolPlanUrl;

  /// No description provided for @schoolPlanUrlHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the address from Teams, Word or the school’s site'**
  String get schoolPlanUrlHint;

  /// No description provided for @schoolPlanNoClass.
  ///
  /// In en, this message translates to:
  /// **'No class chosen yet — nothing will be imported'**
  String get schoolPlanNoClass;

  /// No description provided for @schoolPlanFetchNow.
  ///
  /// In en, this message translates to:
  /// **'Fetch now'**
  String get schoolPlanFetchNow;

  /// No description provided for @schoolPlanUnreadable.
  ///
  /// In en, this message translates to:
  /// **'That document could not be read. Check the link opens for you in a browser.'**
  String get schoolPlanUnreadable;

  /// No description provided for @schoolPlanAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing new} =1{1 new piece of homework} other{{count} new pieces of homework}}'**
  String schoolPlanAdded(int count);

  /// No description provided for @hwEstimate.
  ///
  /// In en, this message translates to:
  /// **'About how long'**
  String get hwEstimate;

  /// No description provided for @hwMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String hwMinutes(int minutes);

  /// No description provided for @hwOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get hwOverdue;

  /// No description provided for @hwStarted.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get hwStarted;

  /// No description provided for @hwDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get hwDone;

  /// No description provided for @hwHandedIn.
  ///
  /// In en, this message translates to:
  /// **'Handed in'**
  String get hwHandedIn;

  /// No description provided for @hwNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get hwNotStarted;

  /// No description provided for @hwPlan.
  ///
  /// In en, this message translates to:
  /// **'Find a time'**
  String get hwPlan;

  /// No description provided for @hwPlanHint.
  ///
  /// In en, this message translates to:
  /// **'Free times before it\'s due, around everything else. Pick one, or skip.'**
  String get hwPlanHint;

  /// No description provided for @hwNoSlots.
  ///
  /// In en, this message translates to:
  /// **'No free time before it\'s due.'**
  String get hwNoSlots;

  /// No description provided for @hwSessions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 session planned} other{{count} sessions planned}}'**
  String hwSessions(int count);

  /// No description provided for @hwSkip.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get hwSkip;

  /// No description provided for @hwStrip.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Homework: 1 due soon} other{Homework: {count} due soon}}'**
  String hwStrip(int count);

  /// No description provided for @away.
  ///
  /// In en, this message translates to:
  /// **'Away & school breaks'**
  String get away;

  /// No description provided for @awaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Holidays, trips and lov pause what they cover'**
  String get awaySubtitle;

  /// No description provided for @addAway.
  ///
  /// In en, this message translates to:
  /// **'Add away time'**
  String get addAway;

  /// No description provided for @addBreak.
  ///
  /// In en, this message translates to:
  /// **'Add a school break'**
  String get addBreak;

  /// No description provided for @awayTitle.
  ///
  /// In en, this message translates to:
  /// **'What'**
  String get awayTitle;

  /// No description provided for @awayTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Höstlov, Fjällen, Farmor'**
  String get awayTitleHint;

  /// No description provided for @awayDates.
  ///
  /// In en, this message translates to:
  /// **'Which days'**
  String get awayDates;

  /// No description provided for @awayWho.
  ///
  /// In en, this message translates to:
  /// **'Who\'s away'**
  String get awayWho;

  /// No description provided for @awayWhoHint.
  ///
  /// In en, this message translates to:
  /// **'Nobody chosen is the whole family'**
  String get awayWhoHint;

  /// No description provided for @awayPauses.
  ///
  /// In en, this message translates to:
  /// **'Pauses'**
  String get awayPauses;

  /// No description provided for @kindActivities.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get kindActivities;

  /// No description provided for @kindRoutines.
  ///
  /// In en, this message translates to:
  /// **'Routines (school, dinner)'**
  String get kindRoutines;

  /// No description provided for @kindHomework.
  ///
  /// In en, this message translates to:
  /// **'Homework'**
  String get kindHomework;

  /// No description provided for @kindAppointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get kindAppointments;

  /// No description provided for @awaySilence.
  ///
  /// In en, this message translates to:
  /// **'No reminders for those away'**
  String get awaySilence;

  /// No description provided for @awayEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned.'**
  String get awayEmpty;

  /// No description provided for @awayBand.
  ///
  /// In en, this message translates to:
  /// **'{title} · {who}'**
  String awayBand(String title, String who);

  /// No description provided for @awayEveryone.
  ///
  /// In en, this message translates to:
  /// **'everyone'**
  String get awayEveryone;

  /// No description provided for @awayRange.
  ///
  /// In en, this message translates to:
  /// **'{from} – {to}'**
  String awayRange(String from, String to);

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Events, recipes, to-dos, people…'**
  String get searchHint;

  /// No description provided for @searchNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing found.'**
  String get searchNothing;

  /// No description provided for @searchEvents.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get searchEvents;

  /// No description provided for @searchTodos.
  ///
  /// In en, this message translates to:
  /// **'To-dos'**
  String get searchTodos;

  /// No description provided for @searchHomework.
  ///
  /// In en, this message translates to:
  /// **'Homework'**
  String get searchHomework;

  /// No description provided for @searchPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get searchPeople;

  /// No description provided for @kit.
  ///
  /// In en, this message translates to:
  /// **'What to bring'**
  String get kit;

  /// No description provided for @addKit.
  ///
  /// In en, this message translates to:
  /// **'Add a kit list'**
  String get addKit;

  /// No description provided for @newKit.
  ///
  /// In en, this message translates to:
  /// **'New kit list'**
  String get newKit;

  /// No description provided for @kitName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get kitName;

  /// No description provided for @kitNameHint.
  ///
  /// In en, this message translates to:
  /// **'Fotbollsväska, Simpåse'**
  String get kitNameHint;

  /// No description provided for @kitItems.
  ///
  /// In en, this message translates to:
  /// **'Things, one per line'**
  String get kitItems;

  /// No description provided for @kitNeedsReplacing.
  ///
  /// In en, this message translates to:
  /// **'Needs replacing'**
  String get kitNeedsReplacing;

  /// No description provided for @kitToShopping.
  ///
  /// In en, this message translates to:
  /// **'{item} is on {list}'**
  String kitToShopping(String item, String list);

  /// No description provided for @bring.
  ///
  /// In en, this message translates to:
  /// **'Bring: {items}'**
  String bring(String items);

  /// No description provided for @canI.
  ///
  /// In en, this message translates to:
  /// **'Can I…?'**
  String get canI;

  /// No description provided for @canIHint.
  ///
  /// In en, this message translates to:
  /// **'Can I sleep over at Elsa\'s on Friday?'**
  String get canIHint;

  /// No description provided for @askParents.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get askParents;

  /// No description provided for @asks.
  ///
  /// In en, this message translates to:
  /// **'{name} asks'**
  String asks(String name);

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @answerNote.
  ///
  /// In en, this message translates to:
  /// **'A few words (optional)'**
  String get answerNote;

  /// No description provided for @waitingForAnswer.
  ///
  /// In en, this message translates to:
  /// **'Waiting for an answer'**
  String get waitingForAnswer;

  /// No description provided for @answeredYes.
  ///
  /// In en, this message translates to:
  /// **'Yes from {name}'**
  String answeredYes(String name);

  /// No description provided for @answeredNo.
  ///
  /// In en, this message translates to:
  /// **'No from {name}'**
  String answeredNo(String name);

  /// No description provided for @pollOpened.
  ///
  /// In en, this message translates to:
  /// **'New poll: {title}'**
  String pollOpened(String title);

  /// No description provided for @pollAnswerBy.
  ///
  /// In en, this message translates to:
  /// **'Answer by {time}'**
  String pollAnswerBy(String time);

  /// No description provided for @pollAnswerSoon.
  ///
  /// In en, this message translates to:
  /// **'Your answer is wanted'**
  String get pollAnswerSoon;

  /// No description provided for @pollOpenedBody.
  ///
  /// In en, this message translates to:
  /// **'Tick every dinner you\'d happily eat'**
  String get pollOpenedBody;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get addPhoto;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get takePhoto;

  /// No description provided for @choosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo'**
  String get choosePhoto;

  /// No description provided for @photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// No description provided for @forCoParent.
  ///
  /// In en, this message translates to:
  /// **'A parent from the other home'**
  String get forCoParent;

  /// No description provided for @forCoParentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sees and edits only the children you share, and their custody schedule'**
  String get forCoParentSubtitle;

  /// No description provided for @coParentsName.
  ///
  /// In en, this message translates to:
  /// **'Their name'**
  String get coParentsName;

  /// No description provided for @coParentChildren.
  ///
  /// In en, this message translates to:
  /// **'Which children you share'**
  String get coParentChildren;

  /// No description provided for @roleCoParent.
  ///
  /// In en, this message translates to:
  /// **'Parent in the other home'**
  String get roleCoParent;

  /// No description provided for @custody.
  ///
  /// In en, this message translates to:
  /// **'Two homes'**
  String get custody;

  /// No description provided for @custodySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Custody schedule and changeovers'**
  String get custodySubtitle;

  /// No description provided for @custodyFor.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s two homes'**
  String custodyFor(String name);

  /// No description provided for @custodyNone.
  ///
  /// In en, this message translates to:
  /// **'No custody schedule.'**
  String get custodyNone;

  /// No description provided for @custodyAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a schedule'**
  String get custodyAdd;

  /// No description provided for @custodyPattern.
  ///
  /// In en, this message translates to:
  /// **'How it alternates'**
  String get custodyPattern;

  /// No description provided for @custodyWeeks.
  ///
  /// In en, this message translates to:
  /// **'Every other week'**
  String get custodyWeeks;

  /// No description provided for @custodyWeekends.
  ///
  /// In en, this message translates to:
  /// **'Every other weekend'**
  String get custodyWeekends;

  /// No description provided for @custodyChangeover.
  ///
  /// In en, this message translates to:
  /// **'A changeover'**
  String get custodyChangeover;

  /// No description provided for @custodyChangeoverWeeksHint.
  ///
  /// In en, this message translates to:
  /// **'When {name} comes here'**
  String custodyChangeoverWeeksHint(String name);

  /// No description provided for @custodyChangeoverWeekendsHint.
  ///
  /// In en, this message translates to:
  /// **'When {name} goes to the other home on a Friday'**
  String custodyChangeoverWeekendsHint(String name);

  /// No description provided for @custodyCoParent.
  ///
  /// In en, this message translates to:
  /// **'The other home'**
  String get custodyCoParent;

  /// No description provided for @custodyNoCoParent.
  ///
  /// In en, this message translates to:
  /// **'Doesn\'t use the app'**
  String get custodyNoCoParent;

  /// No description provided for @custodyToUs.
  ///
  /// In en, this message translates to:
  /// **'{name} to us'**
  String custodyToUs(String name);

  /// No description provided for @custodyToThem.
  ///
  /// In en, this message translates to:
  /// **'{name} to {other}'**
  String custodyToThem(String name, String other);

  /// No description provided for @custodyOtherHome.
  ///
  /// In en, this message translates to:
  /// **'the other home'**
  String get custodyOtherHome;

  /// No description provided for @custodySwap.
  ///
  /// In en, this message translates to:
  /// **'Add a swap'**
  String get custodySwap;

  /// No description provided for @custodySwapHere.
  ///
  /// In en, this message translates to:
  /// **'With us'**
  String get custodySwapHere;

  /// No description provided for @custodySwapThere.
  ///
  /// In en, this message translates to:
  /// **'At the other home'**
  String get custodySwapThere;

  /// No description provided for @custodyAway.
  ///
  /// In en, this message translates to:
  /// **'{name} is with {other}'**
  String custodyAway(String name, String other);

  /// No description provided for @custodyBackAt.
  ///
  /// In en, this message translates to:
  /// **'back {when}'**
  String custodyBackAt(String when);

  /// No description provided for @removeCustody.
  ///
  /// In en, this message translates to:
  /// **'Remove schedule'**
  String get removeCustody;

  /// No description provided for @nameList.
  ///
  /// In en, this message translates to:
  /// **'{rest} and {last}'**
  String nameList(String rest, String last);

  /// No description provided for @newConversation.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get newConversation;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @readersChanged.
  ///
  /// In en, this message translates to:
  /// **'Who can read this changed'**
  String get readersChanged;

  /// No description provided for @nobodyReachable.
  ///
  /// In en, this message translates to:
  /// **'Nobody there can be reached yet: their device hasn\'t been online since it was added.'**
  String get nobodyReachable;

  /// No description provided for @noDevice.
  ///
  /// In en, this message translates to:
  /// **'No device of their own'**
  String get noDevice;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group name (optional)'**
  String get groupName;

  /// No description provided for @startConversation.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startConversation;

  /// No description provided for @alsoReadBy.
  ///
  /// In en, this message translates to:
  /// **'{names} can also read this, because the family\'s settings supervise children\'s messages.'**
  String alsoReadBy(String names);

  /// No description provided for @onlyParticipants.
  ///
  /// In en, this message translates to:
  /// **'Only the people in this conversation can read it.'**
  String get onlyParticipants;

  /// No description provided for @chatJoining.
  ///
  /// In en, this message translates to:
  /// **'Setting up the conversation. It opens once your device has been added.'**
  String get chatJoining;

  /// No description provided for @chatEmptyPrivate.
  ///
  /// In en, this message translates to:
  /// **'Say something. End-to-end encrypted: not even the server can read it.'**
  String get chatEmptyPrivate;

  /// No description provided for @readersNowOnly.
  ///
  /// In en, this message translates to:
  /// **'From now on, only the people in this conversation can read new messages.'**
  String get readersNowOnly;

  /// No description provided for @readersNowAlso.
  ///
  /// In en, this message translates to:
  /// **'From now on, {names} can also read new messages. Nothing from before.'**
  String readersNowAlso(String names);

  /// No description provided for @messageSupervision.
  ///
  /// In en, this message translates to:
  /// **'Children\'s messages'**
  String get messageSupervision;

  /// No description provided for @supervisionOff.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get supervisionOff;

  /// No description provided for @supervisionLittle.
  ///
  /// In en, this message translates to:
  /// **'Supervise the youngest'**
  String get supervisionLittle;

  /// No description provided for @supervisionKid.
  ///
  /// In en, this message translates to:
  /// **'Supervise up to 12'**
  String get supervisionKid;

  /// No description provided for @supervisionAll.
  ///
  /// In en, this message translates to:
  /// **'Supervise all children'**
  String get supervisionAll;

  /// No description provided for @supervisionChange.
  ///
  /// In en, this message translates to:
  /// **'Parents are added to or taken out of the affected conversations, and each one shows it. Supervision only ever covers messages from the change onwards; nobody gets back what came before, and what was read stays read.'**
  String get supervisionChange;

  /// No description provided for @messageSupervisionHelp.
  ///
  /// In en, this message translates to:
  /// **'Supervised children\'s private and group conversations are readable by the parents, and say so in the conversation. The family thread is always everyone\'s.'**
  String get messageSupervisionHelp;

  /// No description provided for @familyMap.
  ///
  /// In en, this message translates to:
  /// **'Family map'**
  String get familyMap;

  /// No description provided for @familyMapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Who\'s where, if they share it'**
  String get familyMapSubtitle;

  /// No description provided for @checkInHere.
  ///
  /// In en, this message translates to:
  /// **'I\'m here'**
  String get checkInHere;

  /// No description provided for @checkInPickUp.
  ///
  /// In en, this message translates to:
  /// **'Come get me'**
  String get checkInPickUp;

  /// No description provided for @checkInSent.
  ///
  /// In en, this message translates to:
  /// **'Sent to the family thread'**
  String get checkInSent;

  /// No description provided for @stoppedSharing.
  ///
  /// In en, this message translates to:
  /// **'Stopped sharing'**
  String get stoppedSharing;

  /// No description provided for @notSharing.
  ///
  /// In en, this message translates to:
  /// **'Not sharing'**
  String get notSharing;

  /// No description provided for @noPositionYet.
  ///
  /// In en, this message translates to:
  /// **'Sharing, no position yet'**
  String get noPositionYet;

  /// No description provided for @sharingPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get sharingPaused;

  /// No description provided for @pausedUntil.
  ///
  /// In en, this message translates to:
  /// **'Paused until {time}'**
  String pausedUntil(String time);

  /// No description provided for @atPlaceSince.
  ///
  /// In en, this message translates to:
  /// **'At {place} since {time}'**
  String atPlaceSince(String place, String time);

  /// No description provided for @notAtAPlace.
  ///
  /// In en, this message translates to:
  /// **'Not at a known place'**
  String get notAtAPlace;

  /// No description provided for @roughlyHere.
  ///
  /// In en, this message translates to:
  /// **'Roughly here'**
  String get roughlyHere;

  /// No description provided for @seenNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get seenNow;

  /// No description provided for @seenAt.
  ///
  /// In en, this message translates to:
  /// **'seen {time}'**
  String seenAt(String time);

  /// No description provided for @yourSharing.
  ///
  /// In en, this message translates to:
  /// **'Your location'**
  String get yourSharing;

  /// No description provided for @mapPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Positions are encrypted on the sharer\'s phone; the server can\'t read them and keeps only the latest, with no trail.'**
  String get mapPrivacy;

  /// No description provided for @shareWhileUsing.
  ///
  /// In en, this message translates to:
  /// **'Share while I use the app'**
  String get shareWhileUsing;

  /// No description provided for @shareWhileUsingHelp.
  ///
  /// In en, this message translates to:
  /// **'Off: nobody sees where you are.'**
  String get shareWhileUsingHelp;

  /// No description provided for @parentAskedToShare.
  ///
  /// In en, this message translates to:
  /// **'A parent has asked you to share while you use the app.'**
  String get parentAskedToShare;

  /// No description provided for @nobodySeesYou.
  ///
  /// In en, this message translates to:
  /// **'Nobody sees you yet.'**
  String get nobodySeesYou;

  /// No description provided for @whoSeesYou.
  ///
  /// In en, this message translates to:
  /// **'{names} can see you.'**
  String whoSeesYou(String names);

  /// No description provided for @locationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location isn\'t available: allow it for Family Planner in the phone\'s settings.'**
  String get locationDenied;

  /// No description provided for @shareWithParents.
  ///
  /// In en, this message translates to:
  /// **'Parents'**
  String get shareWithParents;

  /// No description provided for @shareWithFamily.
  ///
  /// In en, this message translates to:
  /// **'Whole family'**
  String get shareWithFamily;

  /// No description provided for @precisionExact.
  ///
  /// In en, this message translates to:
  /// **'Exact'**
  String get precisionExact;

  /// No description provided for @precisionApproximate.
  ///
  /// In en, this message translates to:
  /// **'About 1 km'**
  String get precisionApproximate;

  /// No description provided for @precisionPlace.
  ///
  /// In en, this message translates to:
  /// **'Place only'**
  String get precisionPlace;

  /// No description provided for @resumeSharing.
  ///
  /// In en, this message translates to:
  /// **'Resume sharing'**
  String get resumeSharing;

  /// No description provided for @pauseHour.
  ///
  /// In en, this message translates to:
  /// **'Pause for an hour'**
  String get pauseHour;

  /// No description provided for @pauseVisible.
  ///
  /// In en, this message translates to:
  /// **'Those who see you see that it\'s paused.'**
  String get pauseVisible;

  /// No description provided for @askToShare.
  ///
  /// In en, this message translates to:
  /// **'Ask to share while using the app'**
  String get askToShare;

  /// No description provided for @stopAskingToShare.
  ///
  /// In en, this message translates to:
  /// **'Stop asking to share'**
  String get stopAskingToShare;

  /// No description provided for @placeSpotUnset.
  ///
  /// In en, this message translates to:
  /// **'Mark where it is: tap while you\'re there'**
  String get placeSpotUnset;

  /// No description provided for @placeSpotSet.
  ///
  /// In en, this message translates to:
  /// **'Marked where it is'**
  String get placeSpotSet;

  /// No description provided for @placeSpotHelp.
  ///
  /// In en, this message translates to:
  /// **'For \"at school since 08:12\" on the map.'**
  String get placeSpotHelp;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @placeRadius.
  ///
  /// In en, this message translates to:
  /// **'Counts as there within'**
  String get placeRadius;

  /// No description provided for @metres.
  ///
  /// In en, this message translates to:
  /// **'{count} m'**
  String metres(int count);

  /// No description provided for @forKitchen.
  ///
  /// In en, this message translates to:
  /// **'A kitchen display'**
  String get forKitchen;

  /// No description provided for @forKitchenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A tablet on the wall: the week, tonight\'s dinner and the shopping list. No chat, no reminders.'**
  String get forKitchenSubtitle;

  /// No description provided for @kitchenToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get kitchenToday;

  /// No description provided for @kitchenDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get kitchenDinner;

  /// No description provided for @kitchenNothingOn.
  ///
  /// In en, this message translates to:
  /// **'Nothing on today.'**
  String get kitchenNothingOn;

  /// No description provided for @kitchenNoDinner.
  ///
  /// In en, this message translates to:
  /// **'No dinner planned'**
  String get kitchenNoDinner;

  /// No description provided for @kitchenListEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing on the list.'**
  String get kitchenListEmpty;

  /// No description provided for @emoji.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get emoji;

  /// No description provided for @mapEveryone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get mapEveryone;

  /// No description provided for @mapTilesGoogle.
  ///
  /// In en, this message translates to:
  /// **'Map pictures come from Google Maps, which sees roughly which area you\'re looking at.'**
  String get mapTilesGoogle;

  /// No description provided for @mapTilesOsm.
  ///
  /// In en, this message translates to:
  /// **'Map pictures come from OpenStreetMap, which sees roughly which area you\'re looking at.'**
  String get mapTilesOsm;

  /// No description provided for @weatherDegrees.
  ///
  /// In en, this message translates to:
  /// **'{high}° / {low}°'**
  String weatherDegrees(int high, int low);

  /// No description provided for @weatherMillimetres.
  ///
  /// In en, this message translates to:
  /// **'{mm} mm'**
  String weatherMillimetres(int mm);

  /// No description provided for @weatherNearby.
  ///
  /// In en, this message translates to:
  /// **'The forecast where this phone is, to about a kilometre'**
  String get weatherNearby;

  /// No description provided for @passwords.
  ///
  /// In en, this message translates to:
  /// **'Passwords'**
  String get passwords;

  /// No description provided for @passwordAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a password'**
  String get passwordAdd;

  /// No description provided for @passwordsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing saved yet. The wifi, a streaming account, the library card — whatever the family keeps looking up.'**
  String get passwordsEmpty;

  /// No description provided for @passwordsFamily.
  ///
  /// In en, this message translates to:
  /// **'The family\'s'**
  String get passwordsFamily;

  /// No description provided for @passwordsMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get passwordsMine;

  /// No description provided for @passwordsHelp.
  ///
  /// In en, this message translates to:
  /// **'Each password is encrypted for the people it\'s for: the family\'s reach everyone\'s own device, yours reach only yours. The kitchen display holds none of them.'**
  String get passwordsHelp;

  /// No description provided for @passwordHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get passwordHidden;

  /// No description provided for @passwordShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get passwordShow;

  /// No description provided for @passwordHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get passwordHide;

  /// No description provided for @passwordCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get passwordCopy;

  /// No description provided for @passwordCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied. The clipboard clears itself shortly.'**
  String get passwordCopied;

  /// No description provided for @passwordUnlockReason.
  ///
  /// In en, this message translates to:
  /// **'Confirm it\'s you before a password is shown'**
  String get passwordUnlockReason;

  /// No description provided for @passwordKeysFailed.
  ///
  /// In en, this message translates to:
  /// **'This device doesn\'t have the key for that yet. Try again once it has synced.'**
  String get passwordKeysFailed;

  /// No description provided for @passwordTitle.
  ///
  /// In en, this message translates to:
  /// **'What it\'s for'**
  String get passwordTitle;

  /// No description provided for @passwordUsername.
  ///
  /// In en, this message translates to:
  /// **'Username (optional)'**
  String get passwordUsername;

  /// No description provided for @passwordSecret.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordSecret;

  /// No description provided for @passwordUrl.
  ///
  /// In en, this message translates to:
  /// **'Link (optional)'**
  String get passwordUrl;

  /// No description provided for @passwordNote.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get passwordNote;

  /// No description provided for @passwordGenerate.
  ///
  /// In en, this message translates to:
  /// **'Make one up'**
  String get passwordGenerate;

  /// No description provided for @passwordNeedsBoth.
  ///
  /// In en, this message translates to:
  /// **'It needs a name and a password.'**
  String get passwordNeedsBoth;

  /// No description provided for @passwordScopeFamily.
  ///
  /// In en, this message translates to:
  /// **'Everyone in the family can see this one.'**
  String get passwordScopeFamily;

  /// No description provided for @passwordScopeMine.
  ///
  /// In en, this message translates to:
  /// **'Only your own devices can open this one.'**
  String get passwordScopeMine;

  /// No description provided for @passwordsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The wifi, accounts, whatever gets looked up'**
  String get passwordsSubtitle;

  /// No description provided for @openLink.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openLink;

  /// No description provided for @passwordSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save that. It stays on this device until it syncs.'**
  String get passwordSaveFailed;

  /// No description provided for @serverOwn.
  ///
  /// In en, this message translates to:
  /// **'Use your own server'**
  String get serverOwn;

  /// No description provided for @serverTitle.
  ///
  /// In en, this message translates to:
  /// **'Your own server'**
  String get serverTitle;

  /// No description provided for @serverHelp.
  ///
  /// In en, this message translates to:
  /// **'This app talks to one server, which holds only encrypted data it cannot read. If your family runs its own, put its address here — before you start or join a family, because a device is tied to the server it paired with.'**
  String get serverHelp;

  /// No description provided for @serverAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get serverAddress;

  /// No description provided for @serverAddressHint.
  ///
  /// In en, this message translates to:
  /// **'family.example.com'**
  String get serverAddressHint;

  /// No description provided for @serverCheck.
  ///
  /// In en, this message translates to:
  /// **'Check and use'**
  String get serverCheck;

  /// No description provided for @serverStandard.
  ///
  /// In en, this message translates to:
  /// **'Use the standard server'**
  String get serverStandard;

  /// No description provided for @serverBadAddress.
  ///
  /// In en, this message translates to:
  /// **'That can\'t be a server address. It needs a host name, and https unless it\'s on your own network.'**
  String get serverBadAddress;

  /// No description provided for @serverNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'Nothing answered at {host}.'**
  String serverNoAnswer(String host);

  /// No description provided for @serverUsing.
  ///
  /// In en, this message translates to:
  /// **'Server: {host}'**
  String serverUsing(String host);

  /// No description provided for @premium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premium;

  /// No description provided for @premiumSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What the family subscription covers'**
  String get premiumSubtitle;

  /// No description provided for @premiumHeadline.
  ///
  /// In en, this message translates to:
  /// **'Let the app do the running around'**
  String get premiumHeadline;

  /// No description provided for @premiumFreeStays.
  ///
  /// In en, this message translates to:
  /// **'The shared calendar, reminders, shopping lists, to-dos and chat stay free, for everyone in the family, on every device.'**
  String get premiumFreeStays;

  /// No description provided for @premiumIntegrations.
  ///
  /// In en, this message translates to:
  /// **'School week plans, calendar feeds and homework read off a letter or a photo of the board — fetched on their own.'**
  String get premiumIntegrations;

  /// No description provided for @premiumMap.
  ///
  /// In en, this message translates to:
  /// **'The family map, and sharing where you are.'**
  String get premiumMap;

  /// No description provided for @premiumFood.
  ///
  /// In en, this message translates to:
  /// **'Recipes, the weekly menu, dinner votes and dietary warnings.'**
  String get premiumFood;

  /// No description provided for @premiumPasswords.
  ///
  /// In en, this message translates to:
  /// **'Saved passwords, for the family or just for you.'**
  String get premiumPasswords;

  /// No description provided for @premiumKitchen.
  ///
  /// In en, this message translates to:
  /// **'The kitchen display for a wall tablet.'**
  String get premiumKitchen;

  /// No description provided for @premiumTwoHomes.
  ///
  /// In en, this message translates to:
  /// **'Two homes: a co-parent\'s account, custody schedules and a babysitter\'s temporary access.'**
  String get premiumTwoHomes;

  /// No description provided for @premiumPhotos.
  ///
  /// In en, this message translates to:
  /// **'Room for photos — 2 GB instead of 200 MB.'**
  String get premiumPhotos;

  /// No description provided for @premiumRenews.
  ///
  /// In en, this message translates to:
  /// **'Payment is taken by the App Store or Google Play. The subscription renews by itself each period until you cancel it, which you do in your store account. One subscription covers the whole family.'**
  String get premiumRenews;

  /// No description provided for @premiumRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore a purchase'**
  String get premiumRestore;

  /// No description provided for @premiumManage.
  ///
  /// In en, this message translates to:
  /// **'Manage subscription'**
  String get premiumManage;

  /// No description provided for @premiumActive.
  ///
  /// In en, this message translates to:
  /// **'Premium is on'**
  String get premiumActive;

  /// No description provided for @premiumUntil.
  ///
  /// In en, this message translates to:
  /// **'Runs until {date}.'**
  String premiumUntil(String date);

  /// No description provided for @premiumGranted.
  ///
  /// In en, this message translates to:
  /// **'Given rather than bought — nobody is paying for this.'**
  String get premiumGranted;

  /// No description provided for @premiumThanks.
  ///
  /// In en, this message translates to:
  /// **'Thank you. Premium is on for the whole family.'**
  String get premiumThanks;

  /// No description provided for @premiumOnItsWay.
  ///
  /// In en, this message translates to:
  /// **'Paid. It can take a moment to reach your devices — nothing more to do.'**
  String get premiumOnItsWay;

  /// No description provided for @premiumNothingToRestore.
  ///
  /// In en, this message translates to:
  /// **'No subscription found on this store account.'**
  String get premiumNothingToRestore;

  /// No description provided for @premiumUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Buying isn\'t available in this version.'**
  String get premiumUnavailable;

  /// No description provided for @premiumNoOffers.
  ///
  /// In en, this message translates to:
  /// **'Nothing to buy just yet. Try again in a moment.'**
  String get premiumNoOffers;

  /// No description provided for @premiumFailed.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t go through. Nothing has been charged.'**
  String get premiumFailed;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get termsOfUse;

  /// No description provided for @premiumBillingId.
  ///
  /// In en, this message translates to:
  /// **'Account {id}'**
  String premiumBillingId(String id);

  /// No description provided for @premiumPerMonth.
  ///
  /// In en, this message translates to:
  /// **'per month'**
  String get premiumPerMonth;

  /// No description provided for @premiumPerYear.
  ///
  /// In en, this message translates to:
  /// **'per year'**
  String get premiumPerYear;

  /// No description provided for @premiumPerWeek.
  ///
  /// In en, this message translates to:
  /// **'per week'**
  String get premiumPerWeek;

  /// No description provided for @premiumFreeFirst.
  ///
  /// In en, this message translates to:
  /// **'Free to try first'**
  String get premiumFreeFirst;

  /// No description provided for @icaTitle.
  ///
  /// In en, this message translates to:
  /// **'Send to ICA'**
  String get icaTitle;

  /// No description provided for @icaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Push the list to ICA\'s own, for the hand scanner'**
  String get icaSubtitle;

  /// No description provided for @icaHelp.
  ///
  /// In en, this message translates to:
  /// **'ICA\'s shopping list syncs to the hand scanners in the shop. This sends what\'s still needed on the family\'s list to one of yours, so it\'s there when you pick up a scanner.'**
  String get icaHelp;

  /// No description provided for @icaCaveats.
  ///
  /// In en, this message translates to:
  /// **'Set up on this phone only — signing in here doesn\'t reach anyone else\'s device, and they can do the same with their own account. It only ever adds to ICA\'s list and ticks off what you\'ve bought; anything you typed into ICA\'s own app is left alone. It stops working outside Sweden, and ICA may change or close this without warning. \"Send the list\" keeps working either way.'**
  String get icaCaveats;

  /// No description provided for @icaConnect.
  ///
  /// In en, this message translates to:
  /// **'Sign in to ICA'**
  String get icaConnect;

  /// No description provided for @icaSignIn.
  ///
  /// In en, this message translates to:
  /// **'ICA'**
  String get icaSignIn;

  /// No description provided for @icaSignInNote.
  ///
  /// In en, this message translates to:
  /// **'This is ICA\'s own sign-in page. What you type goes to ICA, not to this app — it never sees your personnummer or password, only permission to use your shopping list.'**
  String get icaSignInNote;

  /// No description provided for @icaSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'That sign-in didn\'t complete. Nothing was saved.'**
  String get icaSignInFailed;

  /// No description provided for @icaUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This version can\'t connect to ICA.'**
  String get icaUnavailable;

  /// No description provided for @icaWhichList.
  ///
  /// In en, this message translates to:
  /// **'Which ICA list'**
  String get icaWhichList;

  /// No description provided for @icaNoLists.
  ///
  /// In en, this message translates to:
  /// **'No lists on that account yet. Make one in ICA\'s app first.'**
  String get icaNoLists;

  /// No description provided for @icaRowCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{empty} =1{1 item} other{{count} items}}'**
  String icaRowCount(int count);

  /// No description provided for @icaSend.
  ///
  /// In en, this message translates to:
  /// **'Send what\'s needed'**
  String get icaSend;

  /// No description provided for @icaSent.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Already up to date} =1{1 change sent} other{{count} changes sent}}'**
  String icaSent(int count);

  /// No description provided for @icaSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach ICA. Nothing changed.'**
  String get icaSendFailed;

  /// No description provided for @icaDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get icaDisconnect;

  /// No description provided for @icaDisconnectNote.
  ///
  /// In en, this message translates to:
  /// **'This phone forgets your ICA sign-in. Your ICA list stays as it is, and nothing is removed from it. To withdraw access properly, do it in your ICA account.'**
  String get icaDisconnectNote;

  /// No description provided for @editChore.
  ///
  /// In en, this message translates to:
  /// **'Change chore'**
  String get editChore;

  /// No description provided for @guideSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get guideSkip;

  /// No description provided for @guideStart.
  ///
  /// In en, this message translates to:
  /// **'Start using it'**
  String get guideStart;

  /// No description provided for @guideLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get guideLater;

  /// No description provided for @guideWeekTitle.
  ///
  /// In en, this message translates to:
  /// **'Everyone\'s week, in one place'**
  String get guideWeekTitle;

  /// No description provided for @guideWeekBody.
  ///
  /// In en, this message translates to:
  /// **'Today shows what\'s happening now. The week shows everyone\'s — who\'s going where, who\'s driving, what needs packing. Add something with the + button; whoever it concerns sees it on their own phone.'**
  String get guideWeekBody;

  /// No description provided for @guideTalkTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask, decide, get it done'**
  String get guideTalkTitle;

  /// No description provided for @guideTalkBodyParent.
  ///
  /// In en, this message translates to:
  /// **'The family thread is for everyone, and you can message one person. Children can ask permission with \"Can I…?\" and you\'ll get it as a notification. Shopping lists, meals and chores live under their own tabs.'**
  String get guideTalkBodyParent;

  /// No description provided for @guideTalkBodyChild.
  ///
  /// In en, this message translates to:
  /// **'You can write to the whole family or to one person. If you want to ask for something — a sleepover, going to a friend\'s — use \"Can I…?\" on Today, and a grown-up gets it straight away. You can say it out loud instead of typing.'**
  String get guideTalkBodyChild;

  /// No description provided for @guidePrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Only your family can read it'**
  String get guidePrivacyTitle;

  /// No description provided for @guidePrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'Everything is locked on this phone before it\'s sent, and unlocked only on your family\'s phones. The server that carries it cannot read any of it — not the calendar, not the messages, not where anyone is.'**
  String get guidePrivacyBody;

  /// No description provided for @guideKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Twelve words, kept somewhere safe'**
  String get guideKeyTitle;

  /// No description provided for @guideKeyBody.
  ///
  /// In en, this message translates to:
  /// **'Because nobody else can read your family\'s data, nobody else can get it back for you either. Twelve words are the only way in if every phone is lost at once. It takes a minute, and it\'s the one thing worth not putting off.'**
  String get guideKeyBody;

  /// No description provided for @guideKeyAction.
  ///
  /// In en, this message translates to:
  /// **'Get my twelve words'**
  String get guideKeyAction;

  /// No description provided for @guideReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'That\'s it'**
  String get guideReadyTitle;

  /// No description provided for @guideReadyBody.
  ///
  /// In en, this message translates to:
  /// **'Have a look around. Anything you add shows up on the rest of the family\'s phones on its own.'**
  String get guideReadyBody;

  /// No description provided for @hwStripMore.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more} other{{count} more}}'**
  String hwStripMore(int count);

  /// No description provided for @shareAlways.
  ///
  /// In en, this message translates to:
  /// **'Also when the app is closed'**
  String get shareAlways;

  /// No description provided for @shareAlwaysHelp.
  ///
  /// In en, this message translates to:
  /// **'Right now your family only sees where you are while the app is open.'**
  String get shareAlwaysHelp;

  /// No description provided for @shareAlwaysOn.
  ///
  /// In en, this message translates to:
  /// **'Your family can see where you are even when the app is closed. Your phone shows this the whole time it\'s on.'**
  String get shareAlwaysOn;

  /// No description provided for @shareAlwaysParentSet.
  ///
  /// In en, this message translates to:
  /// **'A parent has turned this on, so your family can see where you are even when the app is closed. You can\'t switch it off here.'**
  String get shareAlwaysParentSet;

  /// No description provided for @shareAlwaysDenied.
  ///
  /// In en, this message translates to:
  /// **'Your phone didn\'t allow it. Look for \"Always\" under Location for this app in Settings.'**
  String get shareAlwaysDenied;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @durationDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String durationDays(int count);

  /// No description provided for @fieldEndsLabel.
  ///
  /// In en, this message translates to:
  /// **'Ends · {length}'**
  String fieldEndsLabel(String length);

  /// No description provided for @removeManyTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Remove 1 event?} other{Remove {count} events?}}'**
  String removeManyTitle(int count);

  /// No description provided for @removeManyBody.
  ///
  /// In en, this message translates to:
  /// **'They go to Recently deleted, where you can put them back.'**
  String get removeManyBody;

  /// No description provided for @removeManyBodyRepeating.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One of these repeats: only the day you picked is removed, not the whole series.} other{{count} of these repeat: only the days you picked are removed, not the whole series.}}'**
  String removeManyBodyRepeating(int count);

  /// No description provided for @removedMany.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 event removed} other{{count} events removed}}'**
  String removedMany(int count);

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 selected} other{{count} selected}}'**
  String selectedCount(int count);

  /// No description provided for @removeManyNotYours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 wasn\'t yours to remove} other{{count} weren\'t yours to remove}}'**
  String removeManyNotYours(int count);

  /// No description provided for @moreGroupWeek.
  ///
  /// In en, this message translates to:
  /// **'The week'**
  String get moreGroupWeek;

  /// No description provided for @moreGroupPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get moreGroupPeople;

  /// No description provided for @moreGroupPlaces.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get moreGroupPlaces;

  /// No description provided for @moreGroupIntegrations.
  ///
  /// In en, this message translates to:
  /// **'Brought in from elsewhere'**
  String get moreGroupIntegrations;

  /// No description provided for @moreGroupDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get moreGroupDevices;

  /// No description provided for @moreGroupSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get moreGroupSettings;

  /// No description provided for @wishlists.
  ///
  /// In en, this message translates to:
  /// **'Gift lists'**
  String get wishlists;

  /// No description provided for @wishlistsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What everyone would like, and who\'s getting it'**
  String get wishlistsSubtitle;

  /// No description provided for @wishlistsHelp.
  ///
  /// In en, this message translates to:
  /// **'Everyone keeps their own list. When you open someone else\'s you can claim something, and they never see that it\'s taken — so the list stays a surprise while the rest of you sort out who\'s buying what.'**
  String get wishlistsHelp;

  /// No description provided for @wishlistMine.
  ///
  /// In en, this message translates to:
  /// **'{name} · yours'**
  String wishlistMine(String name);

  /// No description provided for @wishlistMineHint.
  ///
  /// In en, this message translates to:
  /// **'Add what you\'d like. You won\'t see who has claimed anything.'**
  String get wishlistMineHint;

  /// No description provided for @wishlistTheirsHint.
  ///
  /// In en, this message translates to:
  /// **'See what they\'d like, and say if you\'re getting it'**
  String get wishlistTheirsHint;

  /// No description provided for @pollClosed.
  ///
  /// In en, this message translates to:
  /// **'Result: {title}'**
  String pollClosed(String title);

  /// No description provided for @pollClosedNoWinner.
  ///
  /// In en, this message translates to:
  /// **'Nobody voted, so nothing was chosen.'**
  String get pollClosedNoWinner;

  /// No description provided for @todoForYou.
  ///
  /// In en, this message translates to:
  /// **'A job for you'**
  String get todoForYou;

  /// No description provided for @todoDueBy.
  ///
  /// In en, this message translates to:
  /// **'by {date}'**
  String todoDueBy(String date);

  /// No description provided for @pollsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask everyone, and let the answers decide'**
  String get pollsSubtitle;

  /// No description provided for @pollsHelp.
  ///
  /// In en, this message translates to:
  /// **'Ask the family anything and give them the options. Everyone ticks all the ones they\'d be happy with, not just one — so the answer is what most people can live with. When it closes, everyone gets the result.'**
  String get pollsHelp;

  /// No description provided for @pollsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing being decided at the moment.'**
  String get pollsEmpty;

  /// No description provided for @pollAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask the family'**
  String get pollAsk;

  /// No description provided for @pollAskIt.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get pollAskIt;

  /// No description provided for @pollQuestion.
  ///
  /// In en, this message translates to:
  /// **'What are you asking?'**
  String get pollQuestion;

  /// No description provided for @pollQuestionHint.
  ///
  /// In en, this message translates to:
  /// **'Which weekend do we go to the cabin?'**
  String get pollQuestionHint;

  /// No description provided for @pollOptionNumber.
  ///
  /// In en, this message translates to:
  /// **'Option {number}'**
  String pollOptionNumber(int number);

  /// No description provided for @pollAddOption.
  ///
  /// In en, this message translates to:
  /// **'Another option'**
  String get pollAddOption;

  /// No description provided for @pollIsClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get pollIsClosed;

  /// No description provided for @pollVotedSoFar.
  ///
  /// In en, this message translates to:
  /// **'{voted} of {total} have answered'**
  String pollVotedSoFar(int voted, int total);

  /// No description provided for @withdrawMessage.
  ///
  /// In en, this message translates to:
  /// **'Take it back'**
  String get withdrawMessage;

  /// No description provided for @withdrawExplain.
  ///
  /// In en, this message translates to:
  /// **'The words go from everyone\'s phone, and the thread will say a message was taken back. Anyone who already read it has already read it.'**
  String get withdrawExplain;

  /// No description provided for @withdrawIt.
  ///
  /// In en, this message translates to:
  /// **'Take it back'**
  String get withdrawIt;

  /// No description provided for @withdrawnHere.
  ///
  /// In en, this message translates to:
  /// **'Message taken back'**
  String get withdrawnHere;

  /// No description provided for @inboxHomeworkDone.
  ///
  /// In en, this message translates to:
  /// **'{name} finished {title}'**
  String inboxHomeworkDone(String name, String title);

  /// No description provided for @inboxChoreDone.
  ///
  /// In en, this message translates to:
  /// **'{name} did {title}'**
  String inboxChoreDone(String name, String title);

  /// No description provided for @inboxApproval.
  ///
  /// In en, this message translates to:
  /// **'{name} did {title}: approve?'**
  String inboxApproval(String name, String title);

  /// No description provided for @inboxAsked.
  ///
  /// In en, this message translates to:
  /// **'{name} asks you: {title}'**
  String inboxAsked(String name, String title);

  /// No description provided for @inboxPoll.
  ///
  /// In en, this message translates to:
  /// **'Answer: {title}'**
  String inboxPoll(String title);

  /// No description provided for @inboxChat.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unread message} other{{count} unread messages}}'**
  String inboxChat(int count);

  /// No description provided for @inboxSeen.
  ///
  /// In en, this message translates to:
  /// **'Seen'**
  String get inboxSeen;

  /// No description provided for @inboxSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all ({count})'**
  String inboxSeeAll(int count);

  /// No description provided for @inboxNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing waiting for you.'**
  String get inboxNothing;

  /// No description provided for @histSeen.
  ///
  /// In en, this message translates to:
  /// **'saw it done'**
  String get histSeen;

  /// No description provided for @showOnMap.
  ///
  /// In en, this message translates to:
  /// **'Show on map'**
  String get showOnMap;

  /// No description provided for @cityMarket.
  ///
  /// In en, this message translates to:
  /// **'Trading house'**
  String get cityMarket;

  /// No description provided for @cityMarketLocked.
  ///
  /// In en, this message translates to:
  /// **'Opens with the next district'**
  String get cityMarketLocked;

  /// No description provided for @cityMarketMakes.
  ///
  /// In en, this message translates to:
  /// **'Your trading house makes {good}'**
  String cityMarketMakes(String good);

  /// No description provided for @cityLandmarks.
  ///
  /// In en, this message translates to:
  /// **'Special buildings'**
  String get cityLandmarks;

  /// No description provided for @landmarkHarbour.
  ///
  /// In en, this message translates to:
  /// **'Harbour'**
  String get landmarkHarbour;

  /// No description provided for @landmarkCastle.
  ///
  /// In en, this message translates to:
  /// **'Castle'**
  String get landmarkCastle;

  /// No description provided for @landmarkZoo.
  ///
  /// In en, this message translates to:
  /// **'Zoo'**
  String get landmarkZoo;

  /// No description provided for @landmarkStadium.
  ///
  /// In en, this message translates to:
  /// **'Stadium'**
  String get landmarkStadium;

  /// No description provided for @landmarkBakery.
  ///
  /// In en, this message translates to:
  /// **'Bakery'**
  String get landmarkBakery;

  /// No description provided for @landmarkBuilt.
  ///
  /// In en, this message translates to:
  /// **'Already in your city'**
  String get landmarkBuilt;

  /// No description provided for @landmarkShore.
  ///
  /// In en, this message translates to:
  /// **'Must stand by the lake'**
  String get landmarkShore;

  /// No description provided for @landmarkNeeds.
  ///
  /// In en, this message translates to:
  /// **'Needs {cost}'**
  String landmarkNeeds(String cost);

  /// No description provided for @goodFish.
  ///
  /// In en, this message translates to:
  /// **'fish'**
  String get goodFish;

  /// No description provided for @goodWood.
  ///
  /// In en, this message translates to:
  /// **'wood'**
  String get goodWood;

  /// No description provided for @goodStone.
  ///
  /// In en, this message translates to:
  /// **'stone'**
  String get goodStone;

  /// No description provided for @goodWool.
  ///
  /// In en, this message translates to:
  /// **'wool'**
  String get goodWool;

  /// No description provided for @goodHoney.
  ///
  /// In en, this message translates to:
  /// **'honey'**
  String get goodHoney;

  /// No description provided for @trade.
  ///
  /// In en, this message translates to:
  /// **'Trade'**
  String get trade;

  /// No description provided for @tradeYourGoods.
  ///
  /// In en, this message translates to:
  /// **'Your goods'**
  String get tradeYourGoods;

  /// No description provided for @tradeNoGoods.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet: your trading house makes one for every two things you do.'**
  String get tradeNoGoods;

  /// No description provided for @tradeOffersToYou.
  ///
  /// In en, this message translates to:
  /// **'Offers to you'**
  String get tradeOffersToYou;

  /// No description provided for @tradeOfferLine.
  ///
  /// In en, this message translates to:
  /// **'{name} offers {give} for your {get}'**
  String tradeOfferLine(String name, String give, String get);

  /// No description provided for @tradeYourOffers.
  ///
  /// In en, this message translates to:
  /// **'Your offers'**
  String get tradeYourOffers;

  /// No description provided for @tradeYourOfferLine.
  ///
  /// In en, this message translates to:
  /// **'You offered {name} {give} for {get}'**
  String tradeYourOfferLine(String name, String give, String get);

  /// No description provided for @tradeAccept.
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get tradeAccept;

  /// No description provided for @tradeDecline.
  ///
  /// In en, this message translates to:
  /// **'No thanks'**
  String get tradeDecline;

  /// No description provided for @tradeWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Take back'**
  String get tradeWithdraw;

  /// No description provided for @tradeNew.
  ///
  /// In en, this message translates to:
  /// **'New trade'**
  String get tradeNew;

  /// No description provided for @tradeWith.
  ///
  /// In en, this message translates to:
  /// **'Trade with'**
  String get tradeWith;

  /// No description provided for @tradeGive.
  ///
  /// In en, this message translates to:
  /// **'You give'**
  String get tradeGive;

  /// No description provided for @tradeGet.
  ///
  /// In en, this message translates to:
  /// **'You get'**
  String get tradeGet;

  /// No description provided for @tradeEven.
  ///
  /// In en, this message translates to:
  /// **'Always the same number both ways.'**
  String get tradeEven;

  /// No description provided for @tradeSend.
  ///
  /// In en, this message translates to:
  /// **'Send offer'**
  String get tradeSend;

  /// No description provided for @tradeNobody.
  ///
  /// In en, this message translates to:
  /// **'Nobody else in the family has a trading house yet.'**
  String get tradeNobody;

  /// No description provided for @tradeNotEnough.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have enough for this one yet.'**
  String get tradeNotEnough;

  /// No description provided for @tradeTheyHave.
  ///
  /// In en, this message translates to:
  /// **'{name} has {count}'**
  String tradeTheyHave(String name, String count);

  /// No description provided for @tradeSent.
  ///
  /// In en, this message translates to:
  /// **'Offer sent'**
  String get tradeSent;

  /// No description provided for @inboxTrade.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to trade {give} for your {get}'**
  String inboxTrade(String name, String give, String get);

  /// No description provided for @guideCityTrade.
  ///
  /// In en, this message translates to:
  /// **'Build a trading house and swap goods with your brothers and sisters, always one for one. Every trade earns you both coins, and you can sell goods to the town. Special buildings need goods from more than one city.'**
  String get guideCityTrade;

  /// No description provided for @shoppingEditItem.
  ///
  /// In en, this message translates to:
  /// **'Change item'**
  String get shoppingEditItem;

  /// No description provided for @shoppingItemText.
  ///
  /// In en, this message translates to:
  /// **'What to buy'**
  String get shoppingItemText;

  /// No description provided for @shoppingItemHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 2 l milk'**
  String get shoppingItemHint;

  /// No description provided for @shoppingAisle.
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get shoppingAisle;

  /// No description provided for @shoppingNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get shoppingNote;

  /// No description provided for @shoppingRenameList.
  ///
  /// In en, this message translates to:
  /// **'Rename list'**
  String get shoppingRenameList;

  /// No description provided for @shoppingDeleteList.
  ///
  /// In en, this message translates to:
  /// **'Delete list'**
  String get shoppingDeleteList;

  /// No description provided for @shoppingDeleteListExplain.
  ///
  /// In en, this message translates to:
  /// **'Removes {name} and everything on it. You can bring it back from Recently deleted for a while.'**
  String shoppingDeleteListExplain(String name);

  /// No description provided for @shoppingSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get shoppingSelect;

  /// No description provided for @shoppingSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String shoppingSelected(int count);

  /// No description provided for @shoppingSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get shoppingSelectAll;

  /// No description provided for @shoppingRemoveSelected.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get shoppingRemoveSelected;

  /// No description provided for @shoppingRemoved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Removed 1 item} other{Removed {count} items}}'**
  String shoppingRemoved(int count);

  /// No description provided for @phoneCalendarMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get phoneCalendarMine;

  /// No description provided for @custodyGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'How two homes works'**
  String get custodyGuideTitle;

  /// No description provided for @custodyGuideIntro.
  ///
  /// In en, this message translates to:
  /// **'For a child who lives in two homes. Set it up once and the calendar knows where they are.'**
  String get custodyGuideIntro;

  /// No description provided for @custodyGuideSchedule.
  ///
  /// In en, this message translates to:
  /// **'A schedule per child: every other week or every other weekend, counted from one changeover you pick.'**
  String get custodyGuideSchedule;

  /// No description provided for @custodyGuideChangeover.
  ///
  /// In en, this message translates to:
  /// **'Each changeover becomes an event in the calendar, like \"Maja to us\", so you can set who drives.'**
  String get custodyGuideChangeover;

  /// No description provided for @custodyGuideToday.
  ///
  /// In en, this message translates to:
  /// **'Today shows when a child is at the other home, and when they are back.'**
  String get custodyGuideToday;

  /// No description provided for @custodyGuideSwaps.
  ///
  /// In en, this message translates to:
  /// **'Swaps and holidays move single periods, with you or at the other home, without changing the schedule.'**
  String get custodyGuideSwaps;

  /// No description provided for @custodyGuideReminders.
  ///
  /// In en, this message translates to:
  /// **'While a child is at the other home, their activities are that home\'s to arrange: you are not asked who drives.'**
  String get custodyGuideReminders;

  /// No description provided for @custodyGuideOtherHome.
  ///
  /// In en, this message translates to:
  /// **'The other home\'s parent can have their own limited account: More → Add a device → A parent from the other home. They see and edit only the children you share and their schedule, never your chat, meals, map or anything else. If they don\'t use the app, choose \"Doesn\'t use the app\".'**
  String get custodyGuideOtherHome;

  /// No description provided for @custodyGuideHelp.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get custodyGuideHelp;

  /// No description provided for @electricityShow.
  ///
  /// In en, this message translates to:
  /// **'Electricity price in the calendar'**
  String get electricityShow;

  /// No description provided for @electricityShowHelp.
  ///
  /// In en, this message translates to:
  /// **'The day\'s spot price for your price area, next to the weather. Tap it for the price hour by hour. Fetched by the phone from elprisetjustnu.se, which only learns the price area.'**
  String get electricityShowHelp;

  /// No description provided for @electricityOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get electricityOff;

  /// No description provided for @electricityOre.
  ///
  /// In en, this message translates to:
  /// **'{ore} öre'**
  String electricityOre(int ore);

  /// No description provided for @electricityTitle.
  ///
  /// In en, this message translates to:
  /// **'Electricity price, {day}'**
  String electricityTitle(String day);

  /// No description provided for @electricityAverage.
  ///
  /// In en, this message translates to:
  /// **'Average {ore} öre/kWh'**
  String electricityAverage(int ore);

  /// No description provided for @electricityCheapest.
  ///
  /// In en, this message translates to:
  /// **'Cheapest {from}: {ore} öre'**
  String electricityCheapest(String from, int ore);

  /// No description provided for @electricityDearest.
  ///
  /// In en, this message translates to:
  /// **'Dearest {from}: {ore} öre'**
  String electricityDearest(String from, int ore);

  /// No description provided for @electricityHour.
  ///
  /// In en, this message translates to:
  /// **'{hour}: {ore} öre/kWh'**
  String electricityHour(String hour, int ore);

  /// No description provided for @electricityTapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a bar for its price'**
  String get electricityTapHint;

  /// No description provided for @electricitySource.
  ///
  /// In en, this message translates to:
  /// **'Spot price excl. VAT, grid fee and surcharges, from elprisetjustnu.se.'**
  String get electricitySource;

  /// No description provided for @electricityCheapLabel.
  ///
  /// In en, this message translates to:
  /// **'Cheapest'**
  String get electricityCheapLabel;

  /// No description provided for @electricityDearLabel.
  ///
  /// In en, this message translates to:
  /// **'Dearest'**
  String get electricityDearLabel;

  /// No description provided for @weatherTitle.
  ///
  /// In en, this message translates to:
  /// **'Weather, {day}'**
  String weatherTitle(String day);

  /// No description provided for @weatherTemp.
  ///
  /// In en, this message translates to:
  /// **'{degrees}°'**
  String weatherTemp(int degrees);

  /// No description provided for @weatherWind.
  ///
  /// In en, this message translates to:
  /// **'{speed} m/s'**
  String weatherWind(int speed);

  /// No description provided for @weatherSixHours.
  ///
  /// In en, this message translates to:
  /// **'This far ahead the forecast comes six hours at a time.'**
  String get weatherSixHours;

  /// No description provided for @weatherSource.
  ///
  /// In en, this message translates to:
  /// **'Forecast from MET Norway (yr.no), for about a kilometre around where this phone last was, or home.'**
  String get weatherSource;

  /// No description provided for @searchPlaces.
  ///
  /// In en, this message translates to:
  /// **'Settings and screens'**
  String get searchPlaces;

  /// No description provided for @searchWordsSettings.
  ///
  /// In en, this message translates to:
  /// **'settings, notifications, reminders, quiet, silent, electricity, power, spot price, kWh, rewards, jar, supervision'**
  String get searchWordsSettings;

  /// No description provided for @searchWordsCalendars.
  ///
  /// In en, this message translates to:
  /// **'calendar, Google, Outlook, iCloud, shared, sync'**
  String get searchWordsCalendars;

  /// No description provided for @searchWordsMap.
  ///
  /// In en, this message translates to:
  /// **'location, position, where, sharing'**
  String get searchWordsMap;

  /// No description provided for @searchWordsDevices.
  ///
  /// In en, this message translates to:
  /// **'phone, tablet, iPad, pair, QR'**
  String get searchWordsDevices;

  /// No description provided for @searchWordsPasswords.
  ///
  /// In en, this message translates to:
  /// **'password, login, wifi, code'**
  String get searchWordsPasswords;

  /// No description provided for @searchWordsCustody.
  ///
  /// In en, this message translates to:
  /// **'custody, other home, co-parent, changeover'**
  String get searchWordsCustody;

  /// No description provided for @electricityNone.
  ///
  /// In en, this message translates to:
  /// **'No price for this day yet. Tomorrow\'s is published around 13:00.'**
  String get electricityNone;

  /// No description provided for @weatherNone.
  ///
  /// In en, this message translates to:
  /// **'No forecast for this day.'**
  String get weatherNone;

  /// No description provided for @calendarsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Fetch all now'**
  String get calendarsRefresh;

  /// No description provided for @servicePower.
  ///
  /// In en, this message translates to:
  /// **'Wind turbine'**
  String get servicePower;

  /// No description provided for @serviceWater.
  ///
  /// In en, this message translates to:
  /// **'Water tower'**
  String get serviceWater;

  /// No description provided for @serviceFire.
  ///
  /// In en, this message translates to:
  /// **'Fire station'**
  String get serviceFire;

  /// No description provided for @serviceClinic.
  ///
  /// In en, this message translates to:
  /// **'Clinic'**
  String get serviceClinic;

  /// No description provided for @serviceBus.
  ///
  /// In en, this message translates to:
  /// **'Bus stop'**
  String get serviceBus;

  /// No description provided for @serviceWhyPower.
  ///
  /// In en, this message translates to:
  /// **'Apartments and towers need power nearby.'**
  String get serviceWhyPower;

  /// No description provided for @serviceWhyWater.
  ///
  /// In en, this message translates to:
  /// **'Apartments, towers and big parks need water nearby.'**
  String get serviceWhyWater;

  /// No description provided for @serviceWhyFire.
  ///
  /// In en, this message translates to:
  /// **'Towers need a fire station nearby.'**
  String get serviceWhyFire;

  /// No description provided for @serviceWhyClinic.
  ///
  /// In en, this message translates to:
  /// **'Towers need a clinic nearby, and more people move in near one.'**
  String get serviceWhyClinic;

  /// No description provided for @serviceWhyBus.
  ///
  /// In en, this message translates to:
  /// **'Big stores need a bus stop, and more people move in near one.'**
  String get serviceWhyBus;

  /// No description provided for @cityServices.
  ///
  /// In en, this message translates to:
  /// **'Services · paid with coins'**
  String get cityServices;

  /// No description provided for @serviceCost.
  ///
  /// In en, this message translates to:
  /// **'{coins} coins'**
  String serviceCost(int coins);

  /// No description provided for @serviceCostGoods.
  ///
  /// In en, this message translates to:
  /// **'{coins} coins + {count} goods'**
  String serviceCostGoods(int coins, int count);

  /// No description provided for @serviceByStreet.
  ///
  /// In en, this message translates to:
  /// **'Has to stand next to a street'**
  String get serviceByStreet;

  /// No description provided for @serviceReach.
  ///
  /// In en, this message translates to:
  /// **'Reaches {count} plots in every direction.'**
  String serviceReach(int count);

  /// No description provided for @cityCoinsLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 coin} other{{count} coins}}'**
  String cityCoinsLabel(int count);

  /// No description provided for @cityPopulationLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 resident} other{{count} residents}}'**
  String cityPopulationLabel(int count);

  /// No description provided for @happeningMarketDay.
  ///
  /// In en, this message translates to:
  /// **'Market day'**
  String get happeningMarketDay;

  /// No description provided for @happeningMarketDayBody.
  ///
  /// In en, this message translates to:
  /// **'Your trading house makes twice as much today.'**
  String get happeningMarketDayBody;

  /// No description provided for @happeningFestival.
  ///
  /// In en, this message translates to:
  /// **'Festival in the park'**
  String get happeningFestival;

  /// No description provided for @happeningFestivalBody.
  ///
  /// In en, this message translates to:
  /// **'A coin extra for everything you do today, and fireworks tonight.'**
  String get happeningFestivalBody;

  /// No description provided for @happeningTouristBus.
  ///
  /// In en, this message translates to:
  /// **'Tourists are visiting'**
  String get happeningTouristBus;

  /// No description provided for @happeningTouristBusBody.
  ///
  /// In en, this message translates to:
  /// **'Two coins extra for everything you do today.'**
  String get happeningTouristBusBody;

  /// No description provided for @happeningBalloonRace.
  ///
  /// In en, this message translates to:
  /// **'Balloon race'**
  String get happeningBalloonRace;

  /// No description provided for @happeningWhale.
  ///
  /// In en, this message translates to:
  /// **'A whale in the lake!'**
  String get happeningWhale;

  /// No description provided for @happeningMeteorShower.
  ///
  /// In en, this message translates to:
  /// **'Shooting stars tonight'**
  String get happeningMeteorShower;

  /// No description provided for @happeningSeenBody.
  ///
  /// In en, this message translates to:
  /// **'Do something today and it goes in your book.'**
  String get happeningSeenBody;

  /// No description provided for @requestParkNear.
  ///
  /// In en, this message translates to:
  /// **'{name} would like a park near their home'**
  String requestParkNear(String name);

  /// No description provided for @requestShopNear.
  ///
  /// In en, this message translates to:
  /// **'{name} would like a shop near their home'**
  String requestShopNear(String name);

  /// No description provided for @requestHome.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to move in: build a home'**
  String requestHome(String name);

  /// No description provided for @requestService.
  ///
  /// In en, this message translates to:
  /// **'{name} wishes for: {service}'**
  String requestService(String name, String service);

  /// No description provided for @requestReward.
  ///
  /// In en, this message translates to:
  /// **'{coins} coins if it\'s built this week'**
  String requestReward(int coins);

  /// No description provided for @requestThanks.
  ///
  /// In en, this message translates to:
  /// **'{name} says thank you! +{coins} coins'**
  String requestThanks(String name, int coins);

  /// No description provided for @nextUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Next up'**
  String get nextUpTitle;

  /// No description provided for @nextHomeGrows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more thing done and a home grows} other{{count} more things done and a home grows}}'**
  String nextHomeGrows(int count);

  /// No description provided for @nextParkGrows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more thing done and a park grows} other{{count} more things done and a park grows}}'**
  String nextParkGrows(int count);

  /// No description provided for @nextWaitsHome.
  ///
  /// In en, this message translates to:
  /// **'A home is waiting for: {services}'**
  String nextWaitsHome(String services);

  /// No description provided for @nextWaitsShop.
  ///
  /// In en, this message translates to:
  /// **'A shop is waiting for: {services}'**
  String nextWaitsShop(String services);

  /// No description provided for @nextWaitsPark.
  ///
  /// In en, this message translates to:
  /// **'A park is waiting for: {services}'**
  String nextWaitsPark(String services);

  /// No description provided for @nextLevel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more thing done and district {level} opens} other{{count} more things done and district {level} opens}}'**
  String nextLevel(int count, int level);

  /// No description provided for @nextLearning.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more homework seen and your town gets: {building}} other{{count} more homework seen and your town gets: {building}}}'**
  String nextLearning(int count, String building);

  /// No description provided for @civicHall.
  ///
  /// In en, this message translates to:
  /// **'Town hall'**
  String get civicHall;

  /// No description provided for @civicSchool.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get civicSchool;

  /// No description provided for @civicLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get civicLibrary;

  /// No description provided for @civicObservatory.
  ///
  /// In en, this message translates to:
  /// **'Observatory'**
  String get civicObservatory;

  /// No description provided for @civicUniversity.
  ///
  /// In en, this message translates to:
  /// **'University'**
  String get civicUniversity;

  /// No description provided for @civicFountain.
  ///
  /// In en, this message translates to:
  /// **'Fountain'**
  String get civicFountain;

  /// No description provided for @townTitle.
  ///
  /// In en, this message translates to:
  /// **'The town'**
  String get townTitle;

  /// No description provided for @townPeopleHow.
  ///
  /// In en, this message translates to:
  /// **'Homes fill up with a park and a shop nearby, a bus stop and a clinic.'**
  String get townPeopleHow;

  /// No description provided for @townNextMilestone.
  ///
  /// In en, this message translates to:
  /// **'{count} more residents: +{coins} coins'**
  String townNextMilestone(int count, int coins);

  /// No description provided for @townCoinsHow.
  ///
  /// In en, this message translates to:
  /// **'Everything you do earns coins. Shops and the trading house earn more, and so do trades, selling goods and residents\' wishes.'**
  String get townCoinsHow;

  /// No description provided for @townGoal.
  ///
  /// In en, this message translates to:
  /// **'Saving for'**
  String get townGoal;

  /// No description provided for @townGoalNone.
  ///
  /// In en, this message translates to:
  /// **'Choose something to save for'**
  String get townGoalNone;

  /// No description provided for @townGoalNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing for now'**
  String get townGoalNothing;

  /// No description provided for @townGoalReady.
  ///
  /// In en, this message translates to:
  /// **'You can build it now!'**
  String get townGoalReady;

  /// No description provided for @townSell.
  ///
  /// In en, this message translates to:
  /// **'Sell goods'**
  String get townSell;

  /// No description provided for @townSellHow.
  ///
  /// In en, this message translates to:
  /// **'The town pays {coins} coins for each good.'**
  String townSellHow(int coins);

  /// No description provided for @townSellOne.
  ///
  /// In en, this message translates to:
  /// **'Sell 1'**
  String get townSellOne;

  /// No description provided for @projectTitle.
  ///
  /// In en, this message translates to:
  /// **'Family project'**
  String get projectTitle;

  /// No description provided for @projectStatue.
  ///
  /// In en, this message translates to:
  /// **'Statue'**
  String get projectStatue;

  /// No description provided for @projectClockTower.
  ///
  /// In en, this message translates to:
  /// **'Clock tower'**
  String get projectClockTower;

  /// No description provided for @projectFerrisWheel.
  ///
  /// In en, this message translates to:
  /// **'Ferris wheel'**
  String get projectFerrisWheel;

  /// No description provided for @projectProgress.
  ///
  /// In en, this message translates to:
  /// **'{name}: {given} of {need} goods'**
  String projectProgress(String name, int given, int need);

  /// No description provided for @projectHow.
  ///
  /// In en, this message translates to:
  /// **'Everyone gives goods. When it\'s finished, it stands in every city.'**
  String get projectHow;

  /// No description provided for @projectGiveOne.
  ///
  /// In en, this message translates to:
  /// **'Give 1'**
  String get projectGiveOne;

  /// No description provided for @projectAllDone.
  ///
  /// In en, this message translates to:
  /// **'Everything is built. Thank you, everyone!'**
  String get projectAllDone;

  /// No description provided for @bookTitle.
  ///
  /// In en, this message translates to:
  /// **'My book'**
  String get bookTitle;

  /// No description provided for @bookOf.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s book'**
  String bookOf(String name);

  /// No description provided for @bookCount.
  ///
  /// In en, this message translates to:
  /// **'{have} of {all} found'**
  String bookCount(int have, int all);

  /// No description provided for @bookBuildings.
  ///
  /// In en, this message translates to:
  /// **'Buildings'**
  String get bookBuildings;

  /// No description provided for @bookSeen.
  ///
  /// In en, this message translates to:
  /// **'Seen in the town'**
  String get bookSeen;

  /// No description provided for @sizeCottage.
  ///
  /// In en, this message translates to:
  /// **'Cottage'**
  String get sizeCottage;

  /// No description provided for @sizeHouse.
  ///
  /// In en, this message translates to:
  /// **'House'**
  String get sizeHouse;

  /// No description provided for @sizeApartments.
  ///
  /// In en, this message translates to:
  /// **'Apartments'**
  String get sizeApartments;

  /// No description provided for @sizeTower.
  ///
  /// In en, this message translates to:
  /// **'Tower'**
  String get sizeTower;

  /// No description provided for @sizeLawn.
  ///
  /// In en, this message translates to:
  /// **'Lawn'**
  String get sizeLawn;

  /// No description provided for @sizeTrees.
  ///
  /// In en, this message translates to:
  /// **'Trees and a bench'**
  String get sizeTrees;

  /// No description provided for @sizePond.
  ///
  /// In en, this message translates to:
  /// **'Pond or playground'**
  String get sizePond;

  /// No description provided for @sizeBigPark.
  ///
  /// In en, this message translates to:
  /// **'Big park'**
  String get sizeBigPark;

  /// No description provided for @sizeKiosk.
  ///
  /// In en, this message translates to:
  /// **'Corner shop'**
  String get sizeKiosk;

  /// No description provided for @sizeShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get sizeShop;

  /// No description provided for @sizeStore.
  ///
  /// In en, this message translates to:
  /// **'Big store'**
  String get sizeStore;

  /// No description provided for @choreWorth.
  ///
  /// In en, this message translates to:
  /// **'Big job: counts as more in the child\'s city'**
  String get choreWorth;

  /// No description provided for @guideCityServices.
  ///
  /// In en, this message translates to:
  /// **'From apartments up, homes need services nearby to grow: power, water, and for towers a fire station and a clinic. Build them with coins, which everything you do earns.'**
  String get guideCityServices;

  /// No description provided for @guideCityLife.
  ///
  /// In en, this message translates to:
  /// **'Things happen in your town: market days, festivals, balloon races. Every week someone who lives there wishes for something, and granting it pays coins.'**
  String get guideCityLife;

  /// No description provided for @guideParentWorth.
  ///
  /// In en, this message translates to:
  /// **'A big chore can count as two or three things in the child\'s city: choose it when you create the chore.'**
  String get guideParentWorth;

  /// No description provided for @cityNoSeedsLeft.
  ///
  /// In en, this message translates to:
  /// **'Do something more to build this'**
  String get cityNoSeedsLeft;

  /// No description provided for @myOwnCity.
  ///
  /// In en, this message translates to:
  /// **'My own city'**
  String get myOwnCity;

  /// No description provided for @myOwnCitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your own chores build it, with the same rules as the children\'s.'**
  String get myOwnCitySubtitle;

  /// No description provided for @presentGive.
  ///
  /// In en, this message translates to:
  /// **'Give a present'**
  String get presentGive;

  /// No description provided for @presentHow.
  ///
  /// In en, this message translates to:
  /// **'Coins or goods for something worth noticing. Nothing is ever taken away.'**
  String get presentHow;

  /// No description provided for @presentCoins.
  ///
  /// In en, this message translates to:
  /// **'Coins'**
  String get presentCoins;

  /// No description provided for @presentGoods.
  ///
  /// In en, this message translates to:
  /// **'Goods'**
  String get presentGoods;

  /// No description provided for @presentNote.
  ///
  /// In en, this message translates to:
  /// **'What is it for? (optional)'**
  String get presentNote;

  /// No description provided for @presentSend.
  ///
  /// In en, this message translates to:
  /// **'Give'**
  String get presentSend;

  /// No description provided for @presentSent.
  ///
  /// In en, this message translates to:
  /// **'Present given'**
  String get presentSent;

  /// No description provided for @presentToProject.
  ///
  /// In en, this message translates to:
  /// **'Goods for the family project'**
  String get presentToProject;

  /// No description provided for @presentFrom.
  ///
  /// In en, this message translates to:
  /// **'{name} gave you {what}'**
  String presentFrom(String name, String what);

  /// No description provided for @guideParentOwnCity.
  ///
  /// In en, this message translates to:
  /// **'You can build a city of your own too, from your own chores, and give the children presents of coins or goods from their city\'s page.'**
  String get guideParentOwnCity;
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
