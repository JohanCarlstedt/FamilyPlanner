// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tabToday => 'Today';

  @override
  String get tabWeek => 'Week';

  @override
  String get tabChat => 'Chat';

  @override
  String get tabShopping => 'Shopping';

  @override
  String get tabMore => 'More';

  @override
  String weekNumber(int number) {
    return 'Week $number';
  }

  @override
  String get weekPrevious => 'Previous week';

  @override
  String get weekThis => 'This week';

  @override
  String get weekNext => 'Next week';

  @override
  String weekLoadFailed(String error) {
    return 'Couldn\'t load the week.\n$error';
  }

  @override
  String get scopeMine => 'Mine';

  @override
  String get scopeFamily => 'Family';

  @override
  String weekWarnings(String parts) {
    return 'This week: $parts';
  }

  @override
  String weekUnassigned(int count) {
    return '$count with no one responsible';
  }

  @override
  String weekDoubleBooked(int count) {
    return '$count double-booked';
  }

  @override
  String get today => 'Today';

  @override
  String get nothingPlanned => 'Nothing planned';

  @override
  String get cancelled => 'Cancelled';

  @override
  String driving(String name) {
    return 'Driving: $name';
  }

  @override
  String get noOneResponsible => 'No one responsible';

  @override
  String get doubleBookedShort => 'double-booked';

  @override
  String get shoppingDescription =>
      'The active list grouped by aisle, with source chips on each item.';

  @override
  String get chatDescription =>
      'The thread list, with the family thread pinned at the top. End-to-end encrypted with MLS.';

  @override
  String get kitchenDisplay => 'Kitchen display';

  @override
  String get kitchenDescription =>
      'The week, today\'s meal and the shopping list on a wall-mounted tablet. A device session: no member login and no chat keys.';

  @override
  String get welcomeTagline =>
      'Your family\'s calendar, lists and chat — encrypted so only your family can read them.';

  @override
  String get startFamily => 'Start a new family';

  @override
  String get joinFamily => 'Join my family';

  @override
  String get newEvent => 'New event';

  @override
  String todayLoadFailed(String error) {
    return 'Couldn\'t load today.\n$error';
  }

  @override
  String get sharingOngoing => 'Sharing where you are with your family';

  @override
  String hwResponsible(String name) {
    return '$name is on it';
  }

  @override
  String get hwNobodyResponsible => 'Nobody on it';

  @override
  String get hwSetResponsible => 'Who is on it?';

  @override
  String pollClosingTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions close soon',
      one: 'A question closes soon',
    );
    return '$_temp0';
  }

  @override
  String pollClosingBody(String title, String time) {
    return '$title · closes $time';
  }

  @override
  String get repeatFrom => 'Repeats from';

  @override
  String get repeatForever => 'No end date';

  @override
  String get repeatForeverHelp => 'Keeps going until someone stops it';

  @override
  String get repeatUntil => 'Repeats until';

  @override
  String get repeatEndsBeforeStart =>
      'That end is before the start, so this would never happen.';

  @override
  String get rewards => 'Rewards';

  @override
  String get rewardsOn => 'Family jar and own worlds';

  @override
  String get rewardsOnHelp =>
      'Finished chores and homework fill a shared jar each week, and grow each child\'s own world. Nobody is ranked.';

  @override
  String get jarSize => 'A full jar is';

  @override
  String jarThings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count things',
      one: '1 thing',
    );
    return '$_temp0';
  }

  @override
  String get jarFor => 'What a full jar means';

  @override
  String get jarForHint => 'Pizza night, we choose the film…';

  @override
  String get jarTitle => 'Family jar';

  @override
  String jarProgress(int filled, int size) {
    return '$filled of $size this week';
  }

  @override
  String get jarFull => 'The jar is full!';

  @override
  String get cityHome => 'Home';

  @override
  String get cityShop => 'Shop';

  @override
  String get cityPark => 'Park';

  @override
  String get cityRoad => 'Street';

  @override
  String get cityBuild => 'What will you build here?';

  @override
  String get cityShopNeedsSchool => 'Shops open once your town has a school';

  @override
  String get cityBuilding => 'Being built today. You can still change it.';

  @override
  String get cityTakeBack => 'Take it back';

  @override
  String get cityTapToBuild => 'Tap an empty plot to build';

  @override
  String get cityClosed => 'This district opens as you do more';

  @override
  String cityWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count things to build',
      one: '1 thing to build',
    );
    return '$_temp0';
  }

  @override
  String cityStatus(String name, int level) {
    return '$name · district $level';
  }

  @override
  String get cityHamlet => 'Hamlet';

  @override
  String get cityVillage => 'Village';

  @override
  String get citySmallTown => 'Small town';

  @override
  String get cityTown => 'Town';

  @override
  String get cityCity => 'City';

  @override
  String get cityBigCity => 'Big city';

  @override
  String get guideCityTitle => 'How your city grows';

  @override
  String get guideCityEarn =>
      'Every chore you finish gives you something to build. Homework counts too, once a grown-up has seen it done.';

  @override
  String get guideCityBuild =>
      'Tap an empty plot and choose a home, a shop, a park or a street. Streets are free.';

  @override
  String get guideCityToday =>
      'What you build today is a building site. You can change your mind until tomorrow, then it stays.';

  @override
  String get guideCityGrow =>
      'Homes, shops and parks are ready to grow as you keep going: a ⬆️ appears, tap it and choose how. A home next to a park or a shop can become a tower, and a park with homes around it grows faster.';

  @override
  String get guideCityLearn =>
      'Homework builds the town\'s school, library, observatory and university. Once there is a school, you can build shops.';

  @override
  String get guideCityDistricts =>
      'Do more, and new districts open around the edge. Every city has its own lake somewhere: build around it.';

  @override
  String get guideCityJar =>
      'When the family jar is full, there are fireworks over the square, and a fountain appears.';

  @override
  String get guideCityKeep =>
      'Nothing you build ever disappears, even if you have a quiet week.';

  @override
  String get guideGotIt => 'Got it';

  @override
  String get guideHowItWorks => 'How it works';

  @override
  String get guideParentTitle => 'Family jar and own cities';

  @override
  String get guideParentIntro =>
      'A shared goal for the week, and a city each child builds for themselves. Nobody is ranked or compared.';

  @override
  String get guideParentJar =>
      'The family jar: everything anyone finishes this week fills it, whoever did it. You choose how full it has to be and what a full jar means. It empties every Monday.';

  @override
  String get guideParentCity =>
      'Each child\'s city: every chore they finish, and every homework you have seen done, gives them something to build. You can look at a child\'s city, but only they can build in it.';

  @override
  String get guideParentApproval =>
      'A chore that asks for your approval counts once you approve it.';

  @override
  String get guideParentSeen =>
      'Homework counts for the jar as soon as it\'s done, but only grows a child\'s city after you mark it \"Seen it done\" in the homework list. That keeps ticking the box from being the way to win.';

  @override
  String get guideParentKeep =>
      'Nothing a child builds is ever taken away, and a quiet week costs nothing.';

  @override
  String get guideJarBody =>
      'Everything anyone in the family finishes this week fills the jar. When it is full, you get what the family decided — and every child\'s city has a festival. It starts empty again every Monday.';

  @override
  String get guideChildrensCities =>
      'Each child builds their own city from what they finish. Here you can look at them, one at a time.';

  @override
  String get myWorld => 'My city';

  @override
  String get myWorldSubtitle => 'Build it with what you do';

  @override
  String get childrensWorlds => 'The children\'s cities';

  @override
  String get worldLevelUp => 'Full! Here is a bigger one.';

  @override
  String get worldNothingYet =>
      'Nothing to build yet. Every chore and homework you finish gives you something to build.';

  @override
  String worldOf(String name) {
    return '$name\'s city';
  }

  @override
  String get hwSeenIt => 'Seen it done';

  @override
  String hwSeenBy(String name) {
    return 'Seen by $name';
  }

  @override
  String pollsAwaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions waiting for you',
      one: '1 question waiting for you',
    );
    return '$_temp0';
  }

  @override
  String get hwDueThatDay => 'Homework due that day';

  @override
  String get summaryTitle => 'Your day';

  @override
  String get summaryQuiet => 'Nothing on today.';

  @override
  String summaryNextAt(String time) {
    return 'next at $time';
  }

  @override
  String summaryConflicts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clashes',
      one: '1 clash',
    );
    return '$_temp0';
  }

  @override
  String summaryAway(String names) {
    return '$names away';
  }

  @override
  String get summaryEveryoneAway => 'Everyone is away';

  @override
  String get nothingToday => 'Nothing planned today.';

  @override
  String unassignedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'No one is responsible for $count events',
      one: 'No one is responsible for 1 event',
    );
    return '$_temp0';
  }

  @override
  String get doubleBooked => 'Double-booked';

  @override
  String get someone => 'Someone';

  @override
  String overlaps(
    String first,
    String firstTime,
    String second,
    String secondTime,
  ) {
    return '$first $firstTime overlaps $second $secondTime';
  }

  @override
  String nextUp(String when) {
    return 'Next up · $when';
  }

  @override
  String get startingNow => 'starting now';

  @override
  String inMinutes(int minutes) {
    return 'in $minutes min';
  }

  @override
  String inHours(int hours) {
    return 'in $hours h';
  }

  @override
  String inHoursMinutes(int hours, int minutes) {
    return 'in $hours h $minutes min';
  }

  @override
  String get addDevice => 'Add a device';

  @override
  String get addDeviceSubtitle =>
      'A child\'s tablet, the other parent\'s phone';

  @override
  String get trustedDevices => 'Trusted devices';

  @override
  String trustedDevicesCount(int count) {
    return '$count in this family, this one included';
  }

  @override
  String get moreComingSoon =>
      'Planner, celebrations, meals, actions, map and family settings will live here.';

  @override
  String deleteEventTitle(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String get deleteEventOnce =>
      'It disappears for the whole family. It can be restored for 30 days.';

  @override
  String get deleteEventSeries =>
      'Every occurrence disappears for the whole family. It can be restored for 30 days.';

  @override
  String get keep => 'Keep';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get parentsOnlyNote =>
      'Parents only: children\'s devices get no readable copy';

  @override
  String get whosGoing => 'Who\'s going';

  @override
  String get wholeFamily => 'The whole family';

  @override
  String get responsible => 'Responsible';

  @override
  String get noOneYet => 'No one yet';

  @override
  String get eventGone => 'This event is no longer here.';

  @override
  String repeatsWeeklyOn(String days) {
    return 'Every week on $days';
  }

  @override
  String get repeatsDaily => 'Every day';

  @override
  String get repeatsWeekly => 'Every week';

  @override
  String get repeatsMonthly => 'Every month';

  @override
  String get repeatsYearly => 'Every year';

  @override
  String get titleRequired => 'Give it a title.';

  @override
  String saveEventFailed(String error) {
    return 'Couldn\'t save the event.\n$error';
  }

  @override
  String get editEvent => 'Edit event';

  @override
  String get save => 'Save';

  @override
  String get fieldTitle => 'Title';

  @override
  String get fieldLength => 'Length';

  @override
  String get fieldWhere => 'Where (optional)';

  @override
  String get fieldResponsible => 'Responsible / driving';

  @override
  String get repeatsEveryWeek => 'Repeats every week';

  @override
  String everyWeekday(String weekday) {
    return 'Every $weekday';
  }

  @override
  String get parentsOnly => 'Parents only';

  @override
  String get parentsOnlySubtitle => 'Children\'s devices get no readable copy.';

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHours(int hours) {
    return '$hours h';
  }

  @override
  String get namesRequired => 'Add the family name and yours.';

  @override
  String createFailed(String error) {
    return 'Couldn\'t create the family. Check the connection and try again.\n$error';
  }

  @override
  String get familyName => 'Family name';

  @override
  String get familyNameHint => 'The Svenssons';

  @override
  String get yourName => 'Your name';

  @override
  String get serverCanReadFamilyName =>
      'The family name is the one thing our server can read. Your name, and everything else you add, is encrypted on this phone.';

  @override
  String get createFamily => 'Create family';

  @override
  String keysFailed(String error) {
    return 'This device couldn\'t set up its keys.\n$error';
  }

  @override
  String get serverUnreachable =>
      'Can\'t reach the server right now. Still trying…';

  @override
  String get joinInstructions =>
      'On a parent\'s phone, open Family Planner, go to More → Add a device, and scan this code.';

  @override
  String get pairingCode => 'Pairing code';

  @override
  String get waitingForScan => 'Waiting for a parent to scan…';

  @override
  String get codeWarning =>
      'The code works once, and only while this screen is open. Don\'t share a photo of it.';

  @override
  String get detailsUnreadable =>
      'This device\'s family details couldn\'t be read.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get notAPairingCode => 'That isn\'t a Family Planner pairing code.';

  @override
  String get codeUnreadable =>
      'That code couldn\'t be read. Ask for a fresh one and scan again.';

  @override
  String addDeviceFailed(String error) {
    return 'Couldn\'t add the device. Check the connection and scan again.\n$error';
  }

  @override
  String get nameRequired => 'Add their name first.';

  @override
  String get whoIsDeviceFor => 'Who is the new device for?';

  @override
  String get forChild => 'A child';

  @override
  String get forChildSubtitle =>
      'Sees the family calendar and lists, not parents-only things.';

  @override
  String get forOtherParent => 'The other parent';

  @override
  String get forOtherParentSubtitle =>
      'Sees everything you see, and can add devices.';

  @override
  String get forMyself => 'Me, on another device';

  @override
  String get forMyselfSubtitle => 'A tablet or second phone of your own.';

  @override
  String get childsName => 'Child\'s name';

  @override
  String get otherParentsName => 'Other parent\'s name';

  @override
  String get showCodeInstructions =>
      'On the new device, open Family Planner and choose \"Join my family\" to show its code.';

  @override
  String get scanCode => 'Scan the code';

  @override
  String get cameraDenied =>
      'Family Planner needs the camera to scan the code. Allow it in Settings, then come back.';

  @override
  String cameraFailed(String reason) {
    return 'The camera couldn\'t start: $reason';
  }

  @override
  String get pointCamera => 'Point the camera at the code on the new device.';

  @override
  String get deviceAdded => 'Device added';

  @override
  String get deviceAddedDetail =>
      'It will finish setting up on its own in a moment.';

  @override
  String get done => 'Done';

  @override
  String get changeWhich => 'Change which?';

  @override
  String get removeWhich => 'Remove which?';

  @override
  String get scopeThisOne => 'Only this one';

  @override
  String get scopeThisAndAfter => 'This one and all after it';

  @override
  String get scopeAll => 'All of them';

  @override
  String get cancelThisOne => 'Cancel only this one';

  @override
  String get removeThisAndAfter => 'Remove this one and all after it';

  @override
  String get removeAll => 'Remove all of them';

  @override
  String occurrenceCancelled(String title, String date) {
    return '$title on $date is cancelled.';
  }

  @override
  String get undo => 'Undo';

  @override
  String get editOccurrence => 'Edit this time';

  @override
  String onlyThisOccurrence(String date) {
    return 'Changes only $date. Who\'s going, the place and the repeat follow the series.';
  }

  @override
  String get changedThisTime => 'Changed this time';

  @override
  String movedFrom(String date) {
    return 'Moved from $date';
  }

  @override
  String get fieldReminder => 'Reminder';

  @override
  String get reminderNone => 'None';

  @override
  String get reminderAtStart => 'When it starts';

  @override
  String reminderMinutesBefore(int minutes) {
    return '$minutes min before';
  }

  @override
  String reminderHoursBefore(int hours) {
    return '$hours h before';
  }

  @override
  String get reminderDayBefore => 'The day before';

  @override
  String reminderStarts(String time) {
    return 'Starts $time';
  }

  @override
  String get remindersChannel => 'Reminders';

  @override
  String get remindersChannelDescription => 'Before events you\'re part of';

  @override
  String get recentlyDeleted => 'Recently deleted';

  @override
  String get recentlyDeletedSubtitle => 'Restore events for 30 days';

  @override
  String get recentlyDeletedEmpty => 'Nothing deleted in the last 30 days.';

  @override
  String get restore => 'Restore';

  @override
  String deletedOn(String date) {
    return 'Deleted $date';
  }

  @override
  String eventRemoved(String title) {
    return '$title was removed.';
  }

  @override
  String seriesEnded(String title, String date) {
    return '$title now ends before $date.';
  }

  @override
  String get places => 'Places';

  @override
  String get placesSubtitle => 'Home, the sports hall, grandma\'s';

  @override
  String get placesEmpty =>
      'No places yet. Add the ones your family goes to every week.';

  @override
  String get newPlace => 'New place';

  @override
  String get editPlace => 'Edit place';

  @override
  String get placeName => 'Name';

  @override
  String get placeNameHint => 'Sportshallen';

  @override
  String get placeAddress => 'Address (optional)';

  @override
  String get placeIsHome => 'This is home';

  @override
  String get placeIsHomeSubtitle => 'Where trips start from';

  @override
  String get parkingBuffer => 'Parking and walking in';

  @override
  String get parkingNone => 'No extra time';

  @override
  String parkingMinutes(int minutes) {
    return '$minutes min extra';
  }

  @override
  String get fieldPlace => 'Place';

  @override
  String get noPlace => 'No place';

  @override
  String get choosePlace => 'Choose a place';

  @override
  String get placeNameRequired => 'Give the place a name.';

  @override
  String reminderLeaveNow(String time) {
    return 'Time to leave · starts $time';
  }

  @override
  String reminderTomorrow(String time) {
    return 'Tomorrow at $time';
  }

  @override
  String reminderUnassigned(String day, String time) {
    return 'No one is responsible yet · $day $time';
  }

  @override
  String remindersTogether(int count) {
    return '$count reminders';
  }

  @override
  String get digestTitle => 'Today';

  @override
  String digestSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count things today',
      one: '1 thing today',
    );
    return '$_temp0';
  }

  @override
  String get quietChannel => 'Reminders during quiet hours';

  @override
  String get familySettings => 'Family settings';

  @override
  String get familySettingsSubtitle => 'Quiet hours, morning summary';

  @override
  String get quietHours => 'Quiet hours';

  @override
  String quietHoursRange(String from, String to) {
    return '$from–$to';
  }

  @override
  String get quietHoursHelp =>
      'Reminders to get ready move to the evening before. Reminders to leave still arrive, without sound.';

  @override
  String get quietFrom => 'From';

  @override
  String get quietTo => 'To';

  @override
  String get morningDigest => 'Morning summary';

  @override
  String get morningDigestHelp =>
      'One notification with the day\'s plans, instead of many.';

  @override
  String get gettingReady => 'Getting ready';

  @override
  String get gettingReadyHelp =>
      'Added before it\'s time to leave: coats, shoes, finding the other shoe.';

  @override
  String changeAdded(String when) {
    return 'New · $when';
  }

  @override
  String get changeCancelled => 'Cancelled';

  @override
  String changeCancelledOne(String day) {
    return 'Cancelled $day · only that time';
  }

  @override
  String changeTime(String when) {
    return 'New time · $when';
  }

  @override
  String changePlace(String when) {
    return 'New place · $when';
  }

  @override
  String changeTimeAndPlace(String when) {
    return 'New time and place · $when';
  }

  @override
  String changeMovedOne(String day) {
    return 'Moved $day · only that time';
  }

  @override
  String changeEveryTime(String text) {
    return '$text · every time';
  }

  @override
  String changeYouAreIn(String when) {
    return 'You\'ve been added · $when';
  }

  @override
  String get changeYouAreOut => 'You\'re no longer on it';

  @override
  String changeYouDrive(String when) {
    return 'You\'re driving · $when';
  }

  @override
  String changeSomeoneElseDrives(String when) {
    return 'Someone else is driving · $when';
  }

  @override
  String get changesChannel => 'Changes to plans';

  @override
  String get changesChannelDescription =>
      'When something you\'re part of moves or is cancelled';

  @override
  String get members => 'Members';

  @override
  String get membersSubtitle =>
      'Who\'s in the family, and children without a phone';

  @override
  String get addChild => 'Add a child';

  @override
  String get editMember => 'Edit member';

  @override
  String get memberName => 'Name';

  @override
  String get tier => 'Age group';

  @override
  String get tierLittle => 'Little (under about 8)';

  @override
  String get tierKid => 'Kid (about 8–12)';

  @override
  String get tierTeen => 'Teen (about 13+)';

  @override
  String get roleParent => 'Parent';

  @override
  String get roleChild => 'Child';

  @override
  String get colour => 'Colour';

  @override
  String get childNoPhoneNote =>
      'A child without a phone is part of everything: their events and reminders go to whoever is responsible. When they get a device, add it to them under Add a device.';

  @override
  String get forExisting => 'Someone already in the family';

  @override
  String get forExistingSubtitle => 'Their events and colour come along.';

  @override
  String get chooseMember => 'Who?';

  @override
  String get memberRequired => 'Choose who the device is for.';

  @override
  String reminderForChild(String name, String title) {
    return '$name: $title';
  }

  @override
  String get thisDevice => 'This device';

  @override
  String deviceOf(String name) {
    return '$name\'s device';
  }

  @override
  String get someDevice => 'A device';

  @override
  String get removeDevice => 'Remove';

  @override
  String removeDeviceTitle(String device) {
    return 'Remove $device?';
  }

  @override
  String get removeDeviceBody =>
      'It stops syncing at once and can\'t read anything new: the family\'s keys are changed. What\'s already on it stays there, and nothing can take that back.';

  @override
  String get deviceRemoved => 'Removed. The family\'s keys have been changed.';

  @override
  String removeFailed(String error) {
    return 'Could not remove it: $error';
  }

  @override
  String get removeMember => 'Remove from the family';

  @override
  String removeMemberTitle(String name) {
    return 'Remove $name from the family?';
  }

  @override
  String get removeMemberBody =>
      'Their devices stop syncing and the family\'s keys change. Events they made stay; events they were responsible for will need someone new. What\'s already on their devices stays there.';

  @override
  String memberRemoved(String name) {
    return '$name was removed from the family.';
  }

  @override
  String get setupWhoTitle => 'Who\'s in your family?';

  @override
  String get setupWhoBody =>
      'Add the children first: everything else is organised around them. They don\'t need a phone.';

  @override
  String get next => 'Next';

  @override
  String get setupPrivacyTitle => 'Only your family can read it';

  @override
  String get setupPrivacyBody =>
      'Your family\'s calendar, messages, lists and photos are encrypted on your devices. Only people in your family can read them — we can\'t, and neither can anyone else.\n\nThat also means we can\'t recover your data if every family device is lost.';

  @override
  String get getStarted => 'Get started';

  @override
  String get oneDeviceWarning =>
      'Only this phone holds your family\'s keys. Add a second device — the other parent\'s phone or a tablet — so a lost phone doesn\'t mean a lost calendar.';

  @override
  String get roleHelper => 'Helper';

  @override
  String get forHelper => 'A helper';

  @override
  String get forHelperSubtitle =>
      'A babysitter or grandparent: sees the children you choose, until you say.';

  @override
  String get helpersName => 'Helper\'s name';

  @override
  String get helperChildren => 'Which children?';

  @override
  String helperUntil(String when) {
    return 'Until $when';
  }

  @override
  String get helperChildrenRequired => 'Choose at least one child.';

  @override
  String get helperForwardOnly =>
      'When the time is up their phone stops syncing. What it already showed them stays on it.';

  @override
  String get familyThread => 'Family';

  @override
  String get chatEmpty =>
      'Say something to the family. Only your family\'s devices can read it.';

  @override
  String get chatWaiting =>
      'Waiting for a parent\'s phone to add this device to the family chat.';

  @override
  String get chatAlone =>
      'The family chat starts when another device is added.';

  @override
  String get chatHint => 'Message';

  @override
  String get send => 'Send';

  @override
  String get sendFailed =>
      'Couldn\'t send. Check the connection and try again.';

  @override
  String get chatChannel => 'Family chat';

  @override
  String get chatChannelDescription => 'Messages from your family';

  @override
  String get recoveryKit => 'Recovery words';

  @override
  String get recoveryKitSubtitle =>
      'Twelve words that bring your family back if every phone is lost';

  @override
  String get recoveryIntro =>
      'If every phone and tablet in the family is lost, these twelve words are the only way back. Write them on paper and keep it somewhere safe at home — not in a photo, not in an email.';

  @override
  String get showWords => 'Show my words';

  @override
  String get wroteThemDown => 'I\'ve written them down';

  @override
  String get checkWords => 'Check you have them';

  @override
  String wordNumber(int n) {
    return 'Word $n';
  }

  @override
  String get wordsDontMatch =>
      'That\'s not what the words say. Check your paper and try again.';

  @override
  String get savingKit => 'Saving your recovery words…';

  @override
  String get kitReady =>
      'Your recovery words are ready. Any earlier words no longer work.';

  @override
  String kitFailed(String error) {
    return 'Couldn\'t save the recovery words.\n$error';
  }

  @override
  String get recoverFamily => 'Recover with my twelve words';

  @override
  String get recoverTitle => 'Recover your family';

  @override
  String get recoverHelp =>
      'Type the twelve words from your paper, in order, with spaces between.';

  @override
  String get recover => 'Recover';

  @override
  String get recovering => 'Recovering… this takes a few seconds.';

  @override
  String get recoverBadWords =>
      'Those aren\'t twelve valid words. A single mistyped word is enough — check each one.';

  @override
  String get recoverNotFound =>
      'These words don\'t open a family. They may have been replaced by newer ones.';

  @override
  String recoverFailed(String error) {
    return 'Couldn\'t recover.\n$error';
  }

  @override
  String get securing => 'Securing your family\'s keys…';

  @override
  String get recoveredNewWords =>
      'You\'re back. Your old words may have been seen, so they no longer work: make new ones now.';

  @override
  String get continueLabel => 'Continue';

  @override
  String get notificationsOff =>
      'Reminders can\'t reach you: notifications are off for Family Planner. It sends only what\'s about your family\'s plans.';

  @override
  String get turnOn => 'Turn on';

  @override
  String get testReminder => 'Send me a test reminder';

  @override
  String get testReminderSubtitle =>
      'Arrives in about a minute, the way real ones do';

  @override
  String get testReminderSent =>
      'On its way. Lock the phone and wait a minute.';

  @override
  String get testReminderTitle => 'Reminders work';

  @override
  String get testReminderBody =>
      'This came the same way your family\'s reminders will.';

  @override
  String get requestEvent => 'Ask for an event';

  @override
  String get waitingForParent => 'Waiting for a parent';

  @override
  String get approve => 'Approve';

  @override
  String get decline => 'Decline';

  @override
  String get requestSent => 'Sent to a parent to approve.';

  @override
  String requestFrom(String name) {
    return '$name asks for this';
  }

  @override
  String get linkedCalendars => 'Linked calendars';

  @override
  String get linkedCalendarsSubtitle =>
      'Team and school schedules, fetched automatically';

  @override
  String get linkCalendar => 'Link a calendar';

  @override
  String get calendarLinkUrl => 'Link';

  @override
  String get calendarLinkUrlHint =>
      'A laget.se team page, webcal:// or .ics link';

  @override
  String get calendarLinkName => 'Name';

  @override
  String get calendarLinkFor => 'Whose calendar';

  @override
  String get calendarLinkInvalid => 'That doesn\'t look like a calendar link';

  @override
  String calendarFetched(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events updated',
      one: '1 event updated',
      zero: 'Up to date',
    );
    return '$_temp0';
  }

  @override
  String calendarFetchFailed(String error) {
    return 'Couldn\'t fetch the calendar.\n$error';
  }

  @override
  String get fetchNow => 'Fetch now';

  @override
  String get unlinkCalendar => 'Remove link';

  @override
  String unlinkCalendarTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get unlinkCalendarBody =>
      'Every event from this calendar is removed, past ones too. They can be brought back from Recently deleted for a while.';

  @override
  String get linkedCalendarsEmpty =>
      'No calendars linked yet. Link a team\'s calendar and its trainings and matches show up for the child, kept up to date.';

  @override
  String get calendarPrivacyNote =>
      'Fetched by this phone, not by the Family Planner server, so the server never learns which team.';

  @override
  String meetAt(String time) {
    return 'Meet at $time';
  }

  @override
  String get fromLinkedCalendar => 'From a linked calendar';

  @override
  String fromLinkedCalendarNamed(String name) {
    return 'From $name, updated automatically';
  }

  @override
  String reminderLeaveToMeet(String time) {
    return 'Time to leave · meet at $time';
  }

  @override
  String get calendarLinkResponsible => 'Usually takes them';

  @override
  String get calendarLinkNoOne => 'No one in particular';

  @override
  String get editCalendarLink => 'Linked calendar';

  @override
  String get calendarAlreadyLinked => 'This calendar is already linked';

  @override
  String get setupWeekTitle => 'Your usual week';

  @override
  String get setupWeekBody =>
      'A few regular things, so the calendar starts out looking like your week. Change or remove them any time.';

  @override
  String get seedSchool => 'School';

  @override
  String get seedPreschool => 'Preschool';

  @override
  String seedBlockFor(String name, String what) {
    return '$name: $what';
  }

  @override
  String seedWeekdays(String from, String to) {
    return 'Weekdays $from–$to';
  }

  @override
  String get seedDinner => 'Dinner';

  @override
  String seedEveryDay(String from, String to) {
    return 'Every day $from–$to';
  }

  @override
  String get seedActivity => 'Add an activity';

  @override
  String get seedActivitySubtitle => 'Football, swimming, music…';

  @override
  String exportMemberData(String name) {
    return 'Export $name\'s data';
  }

  @override
  String exportFailed(String error) {
    return 'Couldn\'t export.\n$error';
  }

  @override
  String get formerMembers => 'Former members';

  @override
  String eraseMemberData(String name) {
    return 'Erase $name\'s data';
  }

  @override
  String eraseMemberTitle(String name) {
    return 'Erase $name\'s data?';
  }

  @override
  String get eraseMemberBody =>
      'Their name, colour and age group are removed, and events only about them are deleted. Shared events and their chat messages stay, shown as from a former member. Export first if they want a copy. This can\'t be undone.';

  @override
  String get erase => 'Erase';

  @override
  String memberErased(String name) {
    return '$name\'s data is erased';
  }

  @override
  String get weeklyReview => 'Weekly review';

  @override
  String get weeklyReviewSubtitle => 'The week ahead: who drives, what clashes';

  @override
  String reviewEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
      zero: 'Nothing planned',
    );
    return '$_temp0';
  }

  @override
  String get reviewToDecide => 'To decide';

  @override
  String get reviewAllCovered =>
      'Nothing to decide: every child\'s event has someone, and nobody is in two places at once.';

  @override
  String reviewNoOne(String when) {
    return '$when · no one responsible';
  }

  @override
  String reviewClash(String name, String first, String second) {
    return '$name has $first and $second at once';
  }

  @override
  String get reviewResponsible => 'Who\'s responsible';

  @override
  String get reviewTheWeek => 'The week';

  @override
  String reviewPlanCard(int week) {
    return 'Plan week $week';
  }

  @override
  String reviewPlanCardBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count things to decide.',
      one: '1 thing to decide.',
      zero: 'Everything\'s covered. Take a look together.',
    );
    return '$_temp0';
  }

  @override
  String get reviewNudgeBody => 'A few minutes together plans the week ahead.';

  @override
  String get shoppingAddHint => 'Add… e.g. 2 dl grädde';

  @override
  String get shoppingEmpty =>
      'Nothing on the list. Add things above, or a recipe\'s ingredients from Recipes.';

  @override
  String shoppingBought(int count) {
    return 'Bought ($count)';
  }

  @override
  String get shoppingClearBought => 'Clear bought';

  @override
  String get shoppingNewList => 'New list';

  @override
  String get shoppingListName => 'List name';

  @override
  String get shoppingDefaultList => 'Shopping';

  @override
  String get recipes => 'Recipes';

  @override
  String shoppingFor(String sources) {
    return 'For $sources';
  }

  @override
  String get removeItem => 'Remove';

  @override
  String get aisleProduce => 'Fruit & veg';

  @override
  String get aisleBakery => 'Bread';

  @override
  String get aisleDairy => 'Dairy & eggs';

  @override
  String get aisleMeat => 'Meat & fish';

  @override
  String get aisleFrozen => 'Frozen';

  @override
  String get aislePantry => 'Pantry';

  @override
  String get aisleHousehold => 'Household';

  @override
  String get aisleOther => 'Other';

  @override
  String get recipesEmpty =>
      'No recipes yet. Import one from ICA or another recipe site, or write your own.';

  @override
  String get importRecipe => 'Import recipe';

  @override
  String get newRecipe => 'New recipe';

  @override
  String get recipeLink => 'Link to the recipe';

  @override
  String get recipeLinkHint => 'ica.se, koket.se, arla.se …';

  @override
  String recipeFetchFailed(String error) {
    return 'Couldn\'t read a recipe there.\n$error';
  }

  @override
  String get reviewRecipe => 'Check the recipe';

  @override
  String get recipeTitle => 'Name';

  @override
  String get recipeServings => 'Portions';

  @override
  String get recipeIngredients => 'Ingredients, one per line';

  @override
  String get recipeNotes => 'Your notes';

  @override
  String get recipeReviewNote =>
      'Check the amounts before saving: a wrong one ends up on every list made from it.';

  @override
  String recipeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String addToList(String list) {
    return 'Add to $list';
  }

  @override
  String addedToList(String list) {
    return 'Added to $list';
  }

  @override
  String removeFromList(String list) {
    return 'Take off $list';
  }

  @override
  String removedFromList(String list) {
    return 'Taken off $list';
  }

  @override
  String get openRecipeSite => 'Open the recipe';

  @override
  String get deleteRecipe => 'Delete recipe';

  @override
  String portionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count portions',
      one: '1 portion',
    );
    return '$_temp0';
  }

  @override
  String get notOnCatalogue => 'Not recognised: stays as written';

  @override
  String get menu => 'Menu';

  @override
  String get addDinner => 'Add dinner';

  @override
  String get somethingElse => 'Something else…';

  @override
  String get mealTitleHint => 'Tacos, leftovers, pizza out';

  @override
  String menuToList(String list) {
    return 'Put the week on $list';
  }

  @override
  String menuOnList(String list) {
    return 'The week\'s menu is on $list';
  }

  @override
  String get addSide => 'Add a side';

  @override
  String get whoCooks => 'Who\'s cooking';

  @override
  String get removeMeal => 'Take off the menu';

  @override
  String get searchRecipes => 'Search recipes';

  @override
  String mealCookedBy(String name) {
    return '$name cooks';
  }

  @override
  String get nobodyYet => 'Not decided';

  @override
  String get dinnerTonight => 'Dinner tonight';

  @override
  String get staples => 'Staples';

  @override
  String get staplesHint => 'Milk, bread, coffee… what goes on every list';

  @override
  String get addStaples => 'Add staples';

  @override
  String get startWithStaples => 'Start with the staples';

  @override
  String get staplesAdded => 'Staples added';

  @override
  String pickOf(String name) {
    return '$name\'s pick';
  }

  @override
  String picksLeft(String names) {
    return 'Still to pick: $names';
  }

  @override
  String get allPicked => 'Every child has had their pick this week';

  @override
  String get yourPickHint => 'Choose one dinner this week: tap a free day';

  @override
  String get whosePick => 'Whose pick';

  @override
  String get ideas => 'Ideas & polls';

  @override
  String get suggestMeal => 'Suggest a meal';

  @override
  String get suggestions => 'Suggestions';

  @override
  String get noSuggestions =>
      'No suggestions yet. Anyone can suggest a meal, any time.';

  @override
  String suggestedBy(String name) {
    return 'Suggested by $name';
  }

  @override
  String get putOnMenu => 'Put on the menu';

  @override
  String get startPoll => 'Start a poll';

  @override
  String get pollFor => 'Which dinner';

  @override
  String get pollOptions => 'Choose 2 to 5 options';

  @override
  String pollCloses(String when) {
    return 'Voting closes $when';
  }

  @override
  String pollVoted(String names) {
    return 'Voted: $names';
  }

  @override
  String get pollNobodyVoted => 'Nobody has voted yet';

  @override
  String get pollTickHint => 'Tick every meal you\'d be happy to eat';

  @override
  String get closeNow => 'Close now';

  @override
  String get chooseInstead => 'Choose instead';

  @override
  String pollWon(String option) {
    return 'Won: $option';
  }

  @override
  String pollOverridden(String name, String option) {
    return '$name chose this; the vote said $option';
  }

  @override
  String get pollNoVotes => 'Closed without votes';

  @override
  String get polls => 'Polls';

  @override
  String pollChat(String title) {
    return 'Vote on $title: under Shopping › Menu › Ideas & polls';
  }

  @override
  String get pickDay => 'Which day';

  @override
  String get dietTitle => 'Food & allergies';

  @override
  String get dietAllergy => 'Allergy';

  @override
  String get dietIntolerance => 'Intolerance';

  @override
  String get dietDislike => 'Doesn\'t like';

  @override
  String get dietDiet => 'Diet';

  @override
  String get dietWhat => 'What';

  @override
  String get dietWhatHint => 'nuts, lactose, coriander…';

  @override
  String get dietStrict => 'Strict: never in a poll';

  @override
  String get dietEmpty => 'Nothing noted.';

  @override
  String get dietAdd => 'Add a note';

  @override
  String dietConflict(String name, String type, String line) {
    return '$name: $type · $line';
  }

  @override
  String dietLeftOut(String meal, String name, String type) {
    return 'Left out: $meal ($name: $type)';
  }

  @override
  String foodAndAllergies(int count) {
    return 'Food & allergies ($count)';
  }

  @override
  String get cookAgain => 'Cook this again';

  @override
  String get todos => 'To-dos';

  @override
  String get todosSubtitle => 'Chores, prep and errands, shared fairly';

  @override
  String get todoMine => 'Mine';

  @override
  String get todoFamily => 'Family';

  @override
  String get todoInbox => 'Inbox';

  @override
  String get newTodo => 'New to-do';

  @override
  String get todoTitle => 'What needs doing';

  @override
  String get todoDue => 'Due';

  @override
  String get todoNoDue => 'No due date';

  @override
  String get todoWho => 'Who';

  @override
  String get todoPool => 'Anyone (family pool)';

  @override
  String get todoApproval => 'A parent confirms it\'s done';

  @override
  String get todoBlocking => 'Needed for the event to happen';

  @override
  String get todoDone => 'Done';

  @override
  String get todoClaim => 'I\'ll do it';

  @override
  String get todoUnclaim => 'Give it back';

  @override
  String get todoAskSomeone => 'Ask someone else';

  @override
  String get todoSkip => 'Skip this time';

  @override
  String get todoAssign => 'Give to';

  @override
  String get todoApprove => 'Approve';

  @override
  String get todoReopen => 'Not done yet';

  @override
  String get todoAccept => 'Accept';

  @override
  String get todoDecline => 'Decline';

  @override
  String get todoNote => 'Note (optional)';

  @override
  String todoAskedBy(String name) {
    return '$name asks you to take this';
  }

  @override
  String todoAwaiting(String name) {
    return 'Done by $name, waiting for approval';
  }

  @override
  String get todoEmptyMine => 'Nothing on your list.';

  @override
  String get todoEmptyFamily => 'Nothing waiting in the family pool.';

  @override
  String get todoEmptyInbox => 'Nothing waiting for you.';

  @override
  String get todoOverdue => 'Overdue';

  @override
  String todoDueAt(String when) {
    return 'Due $when';
  }

  @override
  String get todoHistory => 'What happened';

  @override
  String get histCreated => 'created';

  @override
  String get histClaimed => 'took it';

  @override
  String get histUnclaimed => 'gave it back';

  @override
  String histAssigned(String name) {
    return 'gave it to $name';
  }

  @override
  String histDelegated(String name) {
    return 'asked $name';
  }

  @override
  String get histAccepted => 'accepted';

  @override
  String histDeclined(String name) {
    return 'declined, back to $name';
  }

  @override
  String get histDone => 'did it';

  @override
  String get histApproved => 'approved';

  @override
  String get histReopened => 'reopened';

  @override
  String get histSkipped => 'skipped';

  @override
  String get histMoved => 'moved with the event';

  @override
  String get histCancelled => 'cancelled with the event';

  @override
  String get recurring => 'Recurring';

  @override
  String get recurringSubtitle => 'Chores on a schedule, turns shared';

  @override
  String get newChore => 'New recurring chore';

  @override
  String get choreDays => 'Which days';

  @override
  String get choreTime => 'At';

  @override
  String get choreEvery => 'Every';

  @override
  String get choreWeekly => 'week';

  @override
  String get choreBiweekly => 'other week';

  @override
  String get choreTurns => 'Who takes turns';

  @override
  String get choreTurnsHint =>
      'Pick one to always do it, or several to take turns; none leaves it to anyone';

  @override
  String get chorePaused => 'Paused';

  @override
  String get prep => 'Prep';

  @override
  String get addPrep => 'Add prep';

  @override
  String get prepWhen => 'When';

  @override
  String get prepSameTime => 'At the start';

  @override
  String prepHoursBefore(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours before',
      one: '1 hour before',
    );
    return '$_temp0';
  }

  @override
  String prepDaysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days before',
      one: 'The day before',
    );
    return '$_temp0';
  }

  @override
  String todayTodos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count things to do',
      one: '1 thing to do',
    );
    return '$_temp0';
  }

  @override
  String get todayTodosSubtitle => 'Due today or overdue';

  @override
  String reviewDinnersOpen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dinners not planned',
      one: '1 dinner not planned',
    );
    return '$_temp0';
  }

  @override
  String reviewUnclaimed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count to-dos nobody has taken',
      one: '1 to-do nobody has taken',
    );
    return '$_temp0';
  }

  @override
  String get quickCaptureHint => 'Quick: football tuesdays 17:30 at the hall';

  @override
  String get quickCaptureFill => 'Fill in';

  @override
  String repeatsUntil(String rule, String date) {
    return '$rule, until $date';
  }

  @override
  String get celebrations => 'Celebrations';

  @override
  String get celebrationsSubtitle =>
      'Birthdays and other days, with gift reminders';

  @override
  String celebrationTurns(String name, int age) {
    return '$name turns $age';
  }

  @override
  String inDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'In $days days',
      one: 'Tomorrow',
      zero: 'Today',
    );
    return '$_temp0';
  }

  @override
  String get personName => 'Name';

  @override
  String get personLabel => 'What you call them';

  @override
  String get personLabelHint => 'Farmor, bonuspappa, Majas kompis';

  @override
  String get personDay => 'The day';

  @override
  String get personYearUnknown => 'Year not known';

  @override
  String get personType => 'What day';

  @override
  String get typeBirthday => 'Birthday';

  @override
  String get typeNameday => 'Name day';

  @override
  String get typeAnniversary => 'Anniversary';

  @override
  String get typeOther => 'Other';

  @override
  String get personLead => 'Remind the adults';

  @override
  String personLeadDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days before',
      one: '1 day before',
      zero: 'On the day',
    );
    return '$_temp0';
  }

  @override
  String get personNotes => 'Gift ideas, sizes';

  @override
  String get personIsMember => 'In the family';

  @override
  String get addPerson => 'Add someone';

  @override
  String get noCelebrations => 'No days to celebrate yet.';

  @override
  String get removePerson => 'Remove';

  @override
  String get memberBirthday => 'Birthday';

  @override
  String get wishlist => 'Wishlist';

  @override
  String wishlistFor(String name) {
    return '$name\'s wishes';
  }

  @override
  String get wishlistEmpty => 'Nothing wished for yet.';

  @override
  String get addWish => 'Add a wish';

  @override
  String get wishTitle => 'What';

  @override
  String get wishLink => 'Link';

  @override
  String get wishNote => 'Note, size, colour';

  @override
  String get wishClaim => 'I\'ll buy this';

  @override
  String get wishUnclaim => 'I won\'t buy it after all';

  @override
  String wishClaimedBy(String name) {
    return '$name buys this';
  }

  @override
  String get wishReceived => 'Received';

  @override
  String get newWishlist => 'Start a new list';

  @override
  String get newWishlistBody =>
      'Wishes not received move to the new list; the old one is kept.';

  @override
  String wishlistName(String name, int year) {
    return '$name $year';
  }

  @override
  String get homework => 'Homework';

  @override
  String get homeworkSubtitle => 'Due dates, and time to do it';

  @override
  String get homeworkEmpty => 'No homework.';

  @override
  String get addHomework => 'Add homework';

  @override
  String get hwWho => 'Whose';

  @override
  String get hwSubject => 'Subject';

  @override
  String get hwNewSubject => 'New subject…';

  @override
  String get hwSubjectName => 'Subject name';

  @override
  String get hwTitle => 'What';

  @override
  String get hwTitleHint => 'Maths p. 42–44';

  @override
  String get hwType => 'Kind';

  @override
  String get hwAssignment => 'Assignment';

  @override
  String get hwReading => 'Reading';

  @override
  String get hwTest => 'Test';

  @override
  String get hwProject => 'Project';

  @override
  String get hwHandIn => 'Hand-in';

  @override
  String hwDue(String when) {
    return 'Due $when';
  }

  @override
  String get hwEveryWeek => 'Every week';

  @override
  String get hwEveryWeekHelp => 'One piece of homework, due once.';

  @override
  String hwEveryWeekOn(String day) {
    return 'A new one every $day, each ticked off on its own.';
  }

  @override
  String get calendarBusy => 'Busy';

  @override
  String get phoneCalendars => 'This phone’s calendars';

  @override
  String get phoneCalendarsSubtitle =>
      'Show your Google, Outlook or work calendar in the family’s';

  @override
  String get phoneCalendarsHelp =>
      'Calendars this phone already syncs. Nothing is sent to Google or Microsoft: the app reads what is on the device.';

  @override
  String get phoneCalendarsPrivacy =>
      'Only what you switch on is shared, and only with your family. The server cannot read any of it.';

  @override
  String get phoneCalendarsDenied =>
      'The app has no access to this phone’s calendars. Grant it in Settings and come back.';

  @override
  String get phoneCalendarsNone => 'No calendars on this phone.';

  @override
  String get phoneCalendarBusy => 'Busy only';

  @override
  String get phoneCalendarFull => 'Full details';

  @override
  String get dictationStart => 'Say it out loud';

  @override
  String get dictationStop => 'Stop listening';

  @override
  String get dictationUnavailable =>
      'This phone cannot listen. Check the microphone permission in Settings.';

  @override
  String get weekLetter => 'Week letter';

  @override
  String get weekLetterHelp =>
      'Share the teacher’s letter into the app, or paste it here. Nothing is saved until you say so.';

  @override
  String get weekLetterPaste => 'Paste the letter’s text';

  @override
  String get weekLetterRead => 'Find the homework';

  @override
  String get weekLetterNothing =>
      'Nothing in this looks like homework. Add it by hand if it should be there.';

  @override
  String get weekLetterNoDate => 'No date given';

  @override
  String get weekLetterUnreadable =>
      'That file could not be read. Open it and paste the text instead.';

  @override
  String get hwWhose => 'Whose homework';

  @override
  String weekLetterSave(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Save $count',
      one: 'Save 1',
    );
    return '$_temp0';
  }

  @override
  String get weekLetterPhoto => 'Photograph it';

  @override
  String get importRecipeFromPlanning =>
      'Paste a link and it goes straight on this meal';

  @override
  String noRecipesFound(String query) {
    return 'No saved recipe matches “$query”.';
  }

  @override
  String get sendToShop => 'Send the list';

  @override
  String get unbindThisDevice => 'Remove this device';

  @override
  String get unbindThisDeviceExplain =>
      'This phone leaves the family: its keys are forgotten and everything stored on it is deleted. The family keeps everything. To use it again, pair it from a device that is still in the family. Anything written here and not yet synced is lost.';

  @override
  String get unbindConfirm => 'Leave the family';

  @override
  String get clearList => 'Clear the list';

  @override
  String get clearTicked => 'Clear what is ticked';

  @override
  String get clearEverything => 'Clear everything';

  @override
  String get clearEverythingExplain =>
      'Every item comes off this list, ticked or not. The list itself stays, and anything cleared can be brought back from Recently deleted.';

  @override
  String clearedItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items cleared',
      one: '1 item cleared',
    );
    return '$_temp0';
  }

  @override
  String get weekLetterLinkShared => 'That link needs a school login';

  @override
  String get weekLetterLinkSharedHelp =>
      'The app cannot open a SharePoint or Google Docs link. Open the document in Word, Teams or OneDrive and share the document itself — or copy its text into the box below.';

  @override
  String get whichClass => 'Which class';

  @override
  String get weekPlanRemember => 'Keep this for next week';

  @override
  String get weekPlanRemembered => 'Saved — check it from Homework each week';

  @override
  String get weekPlanCheck => 'This week’s school plan';

  @override
  String get weekPlanNone =>
      'No school plan saved. Share one from Word or Teams, paste its text, or photograph the whiteboard.';

  @override
  String get weekLetterPasteOrLink =>
      'Paste the letter’s text, or a link to it';

  @override
  String get schoolPlans => 'School week plans';

  @override
  String get schoolPlansSubtitle =>
      'Homework from the school’s own weekly document';

  @override
  String get schoolPlansHelp =>
      'Set up once per child: the address of the school’s week plan and which class is theirs. Their homework then arrives with everything else. The document is fetched by this phone — the server never sees the school’s address.';

  @override
  String get schoolPlansEmpty =>
      'No school plans yet. Add one if your school publishes a weekly document; if it doesn’t, homework can still be shared, pasted or photographed into the app.';

  @override
  String get schoolPlanAdd => 'Add a school plan';

  @override
  String get schoolPlanUrl => 'Link to the week plan';

  @override
  String get schoolPlanUrlHint =>
      'Paste the address from Teams, Word or the school’s site';

  @override
  String get schoolPlanNoClass =>
      'No class chosen yet — nothing will be imported';

  @override
  String get schoolPlanFetchNow => 'Fetch now';

  @override
  String get schoolPlanUnreadable =>
      'That document could not be read. Check the link opens for you in a browser.';

  @override
  String schoolPlanAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new pieces of homework',
      one: '1 new piece of homework',
      zero: 'Nothing new',
    );
    return '$_temp0';
  }

  @override
  String get hwEstimate => 'About how long';

  @override
  String hwMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get hwOverdue => 'Overdue';

  @override
  String get hwStarted => 'Started';

  @override
  String get hwDone => 'Done';

  @override
  String get hwHandedIn => 'Handed in';

  @override
  String get hwNotStarted => 'Not started';

  @override
  String get hwPlan => 'Find a time';

  @override
  String get hwPlanHint =>
      'Free times before it\'s due, around everything else. Pick one, or skip.';

  @override
  String get hwNoSlots => 'No free time before it\'s due.';

  @override
  String hwSessions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions planned',
      one: '1 session planned',
    );
    return '$_temp0';
  }

  @override
  String get hwSkip => 'Not now';

  @override
  String hwStrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Homework: $count due soon',
      one: 'Homework: 1 due soon',
    );
    return '$_temp0';
  }

  @override
  String get away => 'Away & school breaks';

  @override
  String get awaySubtitle => 'Holidays, trips and lov pause what they cover';

  @override
  String get addAway => 'Add away time';

  @override
  String get addBreak => 'Add a school break';

  @override
  String get awayTitle => 'What';

  @override
  String get awayTitleHint => 'Höstlov, Fjällen, Farmor';

  @override
  String get awayDates => 'Which days';

  @override
  String get awayWho => 'Who\'s away';

  @override
  String get awayWhoHint => 'Nobody chosen is the whole family';

  @override
  String get awayPauses => 'Pauses';

  @override
  String get kindActivities => 'Activities';

  @override
  String get kindRoutines => 'Routines (school, dinner)';

  @override
  String get kindHomework => 'Homework';

  @override
  String get kindAppointments => 'Appointments';

  @override
  String get awaySilence => 'No reminders for those away';

  @override
  String get awayEmpty => 'Nothing planned.';

  @override
  String awayBand(String title, String who) {
    return '$title · $who';
  }

  @override
  String get awayEveryone => 'everyone';

  @override
  String awayRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get search => 'Search';

  @override
  String get searchHint => 'Events, recipes, to-dos, people…';

  @override
  String get searchNothing => 'Nothing found.';

  @override
  String get searchEvents => 'Calendar';

  @override
  String get searchTodos => 'To-dos';

  @override
  String get searchHomework => 'Homework';

  @override
  String get searchPeople => 'People';

  @override
  String get kit => 'What to bring';

  @override
  String get addKit => 'Add a kit list';

  @override
  String get newKit => 'New kit list';

  @override
  String get kitName => 'Name';

  @override
  String get kitNameHint => 'Fotbollsväska, Simpåse';

  @override
  String get kitItems => 'Things, one per line';

  @override
  String get kitNeedsReplacing => 'Needs replacing';

  @override
  String kitToShopping(String item, String list) {
    return '$item is on $list';
  }

  @override
  String bring(String items) {
    return 'Bring: $items';
  }

  @override
  String get canI => 'Can I…?';

  @override
  String get canIHint => 'Can I sleep over at Elsa\'s on Friday?';

  @override
  String get askParents => 'Ask';

  @override
  String asks(String name) {
    return '$name asks';
  }

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get answerNote => 'A few words (optional)';

  @override
  String get waitingForAnswer => 'Waiting for an answer';

  @override
  String answeredYes(String name) {
    return 'Yes from $name';
  }

  @override
  String answeredNo(String name) {
    return 'No from $name';
  }

  @override
  String pollOpened(String title) {
    return 'New poll: $title';
  }

  @override
  String pollAnswerBy(String time) {
    return 'Answer by $time';
  }

  @override
  String get pollAnswerSoon => 'Your answer is wanted';

  @override
  String get pollOpenedBody => 'Tick every dinner you\'d happily eat';

  @override
  String get addPhoto => 'Add a photo';

  @override
  String get takePhoto => 'Take a photo';

  @override
  String get choosePhoto => 'Choose a photo';

  @override
  String get photos => 'Photos';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get forCoParent => 'A parent from the other home';

  @override
  String get forCoParentSubtitle =>
      'Sees and edits only the children you share, and their custody schedule';

  @override
  String get coParentsName => 'Their name';

  @override
  String get coParentChildren => 'Which children you share';

  @override
  String get roleCoParent => 'Parent in the other home';

  @override
  String get custody => 'Two homes';

  @override
  String get custodySubtitle => 'Custody schedule and changeovers';

  @override
  String custodyFor(String name) {
    return '$name\'s two homes';
  }

  @override
  String get custodyNone => 'No custody schedule.';

  @override
  String get custodyAdd => 'Add a schedule';

  @override
  String get custodyPattern => 'How it alternates';

  @override
  String get custodyWeeks => 'Every other week';

  @override
  String get custodyWeekends => 'Every other weekend';

  @override
  String get custodyChangeover => 'A changeover';

  @override
  String custodyChangeoverWeeksHint(String name) {
    return 'When $name comes here';
  }

  @override
  String custodyChangeoverWeekendsHint(String name) {
    return 'When $name goes to the other home on a Friday';
  }

  @override
  String get custodyCoParent => 'The other home';

  @override
  String get custodyNoCoParent => 'Doesn\'t use the app';

  @override
  String custodyToUs(String name) {
    return '$name to us';
  }

  @override
  String custodyToThem(String name, String other) {
    return '$name to $other';
  }

  @override
  String get custodyOtherHome => 'the other home';

  @override
  String get custodySwap => 'Add a swap';

  @override
  String get custodySwapHere => 'With us';

  @override
  String get custodySwapThere => 'At the other home';

  @override
  String custodyAway(String name, String other) {
    return '$name is with $other';
  }

  @override
  String custodyBackAt(String when) {
    return 'back $when';
  }

  @override
  String get removeCustody => 'Remove schedule';

  @override
  String nameList(String rest, String last) {
    return '$rest and $last';
  }

  @override
  String get newConversation => 'New message';

  @override
  String get you => 'You';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get readersChanged => 'Who can read this changed';

  @override
  String get nobodyReachable =>
      'Nobody there can be reached yet: their device hasn\'t been online since it was added.';

  @override
  String get noDevice => 'No device of their own';

  @override
  String get groupName => 'Group name (optional)';

  @override
  String get startConversation => 'Start';

  @override
  String alsoReadBy(String names) {
    return '$names can also read this, because the family\'s settings supervise children\'s messages.';
  }

  @override
  String get onlyParticipants =>
      'Only the people in this conversation can read it.';

  @override
  String get chatJoining =>
      'Setting up the conversation. It opens once your device has been added.';

  @override
  String get chatEmptyPrivate =>
      'Say something. End-to-end encrypted: not even the server can read it.';

  @override
  String get readersNowOnly =>
      'From now on, only the people in this conversation can read new messages.';

  @override
  String readersNowAlso(String names) {
    return 'From now on, $names can also read new messages. Nothing from before.';
  }

  @override
  String get messageSupervision => 'Children\'s messages';

  @override
  String get supervisionOff => 'Private';

  @override
  String get supervisionLittle => 'Supervise the youngest';

  @override
  String get supervisionKid => 'Supervise up to 12';

  @override
  String get supervisionAll => 'Supervise all children';

  @override
  String get supervisionChange =>
      'Parents are added to or taken out of the affected conversations, and each one shows it. Supervision only ever covers messages from the change onwards; nobody gets back what came before, and what was read stays read.';

  @override
  String get messageSupervisionHelp =>
      'Supervised children\'s private and group conversations are readable by the parents, and say so in the conversation. The family thread is always everyone\'s.';

  @override
  String get familyMap => 'Family map';

  @override
  String get familyMapSubtitle => 'Who\'s where, if they share it';

  @override
  String get checkInHere => 'I\'m here';

  @override
  String get checkInPickUp => 'Come get me';

  @override
  String get checkInSent => 'Sent to the family thread';

  @override
  String get stoppedSharing => 'Stopped sharing';

  @override
  String get notSharing => 'Not sharing';

  @override
  String get noPositionYet => 'Sharing, no position yet';

  @override
  String get sharingPaused => 'Paused';

  @override
  String pausedUntil(String time) {
    return 'Paused until $time';
  }

  @override
  String atPlaceSince(String place, String time) {
    return 'At $place since $time';
  }

  @override
  String get notAtAPlace => 'Not at a known place';

  @override
  String get roughlyHere => 'Roughly here';

  @override
  String get seenNow => 'now';

  @override
  String seenAt(String time) {
    return 'seen $time';
  }

  @override
  String get yourSharing => 'Your location';

  @override
  String get mapPrivacy =>
      'Positions are encrypted on the sharer\'s phone; the server can\'t read them and keeps only the latest, with no trail.';

  @override
  String get shareWhileUsing => 'Share while I use the app';

  @override
  String get shareWhileUsingHelp => 'Off: nobody sees where you are.';

  @override
  String get parentAskedToShare =>
      'A parent has asked you to share while you use the app.';

  @override
  String get nobodySeesYou => 'Nobody sees you yet.';

  @override
  String whoSeesYou(String names) {
    return '$names can see you.';
  }

  @override
  String get locationDenied =>
      'Location isn\'t available: allow it for Family Planner in the phone\'s settings.';

  @override
  String get shareWithParents => 'Parents';

  @override
  String get shareWithFamily => 'Whole family';

  @override
  String get precisionExact => 'Exact';

  @override
  String get precisionApproximate => 'About 1 km';

  @override
  String get precisionPlace => 'Place only';

  @override
  String get resumeSharing => 'Resume sharing';

  @override
  String get pauseHour => 'Pause for an hour';

  @override
  String get pauseVisible => 'Those who see you see that it\'s paused.';

  @override
  String get askToShare => 'Ask to share while using the app';

  @override
  String get stopAskingToShare => 'Stop asking to share';

  @override
  String get placeSpotUnset => 'Mark where it is: tap while you\'re there';

  @override
  String get placeSpotSet => 'Marked where it is';

  @override
  String get placeSpotHelp => 'For \"at school since 08:12\" on the map.';

  @override
  String get clear => 'Clear';

  @override
  String get placeRadius => 'Counts as there within';

  @override
  String metres(int count) {
    return '$count m';
  }

  @override
  String get forKitchen => 'A kitchen display';

  @override
  String get forKitchenSubtitle =>
      'A tablet on the wall: the week, tonight\'s dinner and the shopping list. No chat, no reminders.';

  @override
  String get kitchenToday => 'Today';

  @override
  String get kitchenDinner => 'Dinner';

  @override
  String get kitchenNothingOn => 'Nothing on today.';

  @override
  String get kitchenNoDinner => 'No dinner planned';

  @override
  String get kitchenListEmpty => 'Nothing on the list.';

  @override
  String get emoji => 'Emoji';

  @override
  String get mapEveryone => 'Everyone';

  @override
  String get mapTilesGoogle =>
      'Map pictures come from Google Maps, which sees roughly which area you\'re looking at.';

  @override
  String get mapTilesOsm =>
      'Map pictures come from OpenStreetMap, which sees roughly which area you\'re looking at.';

  @override
  String weatherDegrees(int high, int low) {
    return '$high° / $low°';
  }

  @override
  String weatherMillimetres(int mm) {
    return '$mm mm';
  }

  @override
  String get weatherNearby =>
      'The forecast where this phone is, to about a kilometre';

  @override
  String get passwords => 'Passwords';

  @override
  String get passwordAdd => 'Add a password';

  @override
  String get passwordsEmpty =>
      'Nothing saved yet. The wifi, a streaming account, the library card — whatever the family keeps looking up.';

  @override
  String get passwordsFamily => 'The family\'s';

  @override
  String get passwordsMine => 'Mine';

  @override
  String get passwordsHelp =>
      'Each password is encrypted for the people it\'s for: the family\'s reach everyone\'s own device, yours reach only yours. The kitchen display holds none of them.';

  @override
  String get passwordHidden => 'Hidden';

  @override
  String get passwordShow => 'Show';

  @override
  String get passwordHide => 'Hide';

  @override
  String get passwordCopy => 'Copy';

  @override
  String get passwordCopied => 'Copied. The clipboard clears itself shortly.';

  @override
  String get passwordUnlockReason =>
      'Confirm it\'s you before a password is shown';

  @override
  String get passwordKeysFailed =>
      'This device doesn\'t have the key for that yet. Try again once it has synced.';

  @override
  String get passwordTitle => 'What it\'s for';

  @override
  String get passwordUsername => 'Username (optional)';

  @override
  String get passwordSecret => 'Password';

  @override
  String get passwordUrl => 'Link (optional)';

  @override
  String get passwordNote => 'Note (optional)';

  @override
  String get passwordGenerate => 'Make one up';

  @override
  String get passwordNeedsBoth => 'It needs a name and a password.';

  @override
  String get passwordScopeFamily => 'Everyone in the family can see this one.';

  @override
  String get passwordScopeMine => 'Only your own devices can open this one.';

  @override
  String get passwordsSubtitle => 'The wifi, accounts, whatever gets looked up';

  @override
  String get openLink => 'Open';

  @override
  String get passwordSaveFailed =>
      'Couldn\'t save that. It stays on this device until it syncs.';

  @override
  String get serverOwn => 'Use your own server';

  @override
  String get serverTitle => 'Your own server';

  @override
  String get serverHelp =>
      'This app talks to one server, which holds only encrypted data it cannot read. If your family runs its own, put its address here — before you start or join a family, because a device is tied to the server it paired with.';

  @override
  String get serverAddress => 'Address';

  @override
  String get serverAddressHint => 'family.example.com';

  @override
  String get serverCheck => 'Check and use';

  @override
  String get serverStandard => 'Use the standard server';

  @override
  String get serverBadAddress =>
      'That can\'t be a server address. It needs a host name, and https unless it\'s on your own network.';

  @override
  String serverNoAnswer(String host) {
    return 'Nothing answered at $host.';
  }

  @override
  String serverUsing(String host) {
    return 'Server: $host';
  }

  @override
  String get premium => 'Premium';

  @override
  String get premiumSubtitle => 'What the family subscription covers';

  @override
  String get premiumHeadline => 'Let the app do the running around';

  @override
  String get premiumFreeStays =>
      'The shared calendar, reminders, shopping lists, to-dos and chat stay free, for everyone in the family, on every device.';

  @override
  String get premiumIntegrations =>
      'School week plans, calendar feeds and homework read off a letter or a photo of the board — fetched on their own.';

  @override
  String get premiumMap => 'The family map, and sharing where you are.';

  @override
  String get premiumFood =>
      'Recipes, the weekly menu, dinner votes and dietary warnings.';

  @override
  String get premiumPasswords =>
      'Saved passwords, for the family or just for you.';

  @override
  String get premiumKitchen => 'The kitchen display for a wall tablet.';

  @override
  String get premiumTwoHomes =>
      'Two homes: a co-parent\'s account, custody schedules and a babysitter\'s temporary access.';

  @override
  String get premiumPhotos => 'Room for photos — 2 GB instead of 200 MB.';

  @override
  String get premiumRenews =>
      'Payment is taken by the App Store or Google Play. The subscription renews by itself each period until you cancel it, which you do in your store account. One subscription covers the whole family.';

  @override
  String get premiumRestore => 'Restore a purchase';

  @override
  String get premiumManage => 'Manage subscription';

  @override
  String get premiumActive => 'Premium is on';

  @override
  String premiumUntil(String date) {
    return 'Runs until $date.';
  }

  @override
  String get premiumGranted =>
      'Given rather than bought — nobody is paying for this.';

  @override
  String get premiumThanks => 'Thank you. Premium is on for the whole family.';

  @override
  String get premiumOnItsWay =>
      'Paid. It can take a moment to reach your devices — nothing more to do.';

  @override
  String get premiumNothingToRestore =>
      'No subscription found on this store account.';

  @override
  String get premiumUnavailable => 'Buying isn\'t available in this version.';

  @override
  String get premiumNoOffers =>
      'Nothing to buy just yet. Try again in a moment.';

  @override
  String get premiumFailed =>
      'That didn\'t go through. Nothing has been charged.';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get termsOfUse => 'Terms of use';

  @override
  String premiumBillingId(String id) {
    return 'Account $id';
  }

  @override
  String get premiumPerMonth => 'per month';

  @override
  String get premiumPerYear => 'per year';

  @override
  String get premiumPerWeek => 'per week';

  @override
  String get premiumFreeFirst => 'Free to try first';

  @override
  String get icaTitle => 'Send to ICA';

  @override
  String get icaSubtitle => 'Push the list to ICA\'s own, for the hand scanner';

  @override
  String get icaHelp =>
      'ICA\'s shopping list syncs to the hand scanners in the shop. This sends what\'s still needed on the family\'s list to one of yours, so it\'s there when you pick up a scanner.';

  @override
  String get icaCaveats =>
      'Set up on this phone only — signing in here doesn\'t reach anyone else\'s device, and they can do the same with their own account. It only ever adds to ICA\'s list and ticks off what you\'ve bought; anything you typed into ICA\'s own app is left alone. It stops working outside Sweden, and ICA may change or close this without warning. \"Send the list\" keeps working either way.';

  @override
  String get icaConnect => 'Sign in to ICA';

  @override
  String get icaSignIn => 'ICA';

  @override
  String get icaSignInNote =>
      'This is ICA\'s own sign-in page. What you type goes to ICA, not to this app — it never sees your personnummer or password, only permission to use your shopping list.';

  @override
  String get icaSignInFailed =>
      'That sign-in didn\'t complete. Nothing was saved.';

  @override
  String get icaUnavailable => 'This version can\'t connect to ICA.';

  @override
  String get icaWhichList => 'Which ICA list';

  @override
  String get icaNoLists =>
      'No lists on that account yet. Make one in ICA\'s app first.';

  @override
  String icaRowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'empty',
    );
    return '$_temp0';
  }

  @override
  String get icaSend => 'Send what\'s needed';

  @override
  String icaSent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes sent',
      one: '1 change sent',
      zero: 'Already up to date',
    );
    return '$_temp0';
  }

  @override
  String get icaSendFailed => 'Couldn\'t reach ICA. Nothing changed.';

  @override
  String get icaDisconnect => 'Disconnect';

  @override
  String get icaDisconnectNote =>
      'This phone forgets your ICA sign-in. Your ICA list stays as it is, and nothing is removed from it. To withdraw access properly, do it in your ICA account.';

  @override
  String get editChore => 'Change chore';

  @override
  String get guideSkip => 'Skip';

  @override
  String get guideStart => 'Start using it';

  @override
  String get guideLater => 'Later';

  @override
  String get guideWeekTitle => 'Everyone\'s week, in one place';

  @override
  String get guideWeekBody =>
      'Today shows what\'s happening now. The week shows everyone\'s — who\'s going where, who\'s driving, what needs packing. Add something with the + button; whoever it concerns sees it on their own phone.';

  @override
  String get guideTalkTitle => 'Ask, decide, get it done';

  @override
  String get guideTalkBodyParent =>
      'The family thread is for everyone, and you can message one person. Children can ask permission with \"Can I…?\" and you\'ll get it as a notification. Shopping lists, meals and chores live under their own tabs.';

  @override
  String get guideTalkBodyChild =>
      'You can write to the whole family or to one person. If you want to ask for something — a sleepover, going to a friend\'s — use \"Can I…?\" on Today, and a grown-up gets it straight away. You can say it out loud instead of typing.';

  @override
  String get guidePrivacyTitle => 'Only your family can read it';

  @override
  String get guidePrivacyBody =>
      'Everything is locked on this phone before it\'s sent, and unlocked only on your family\'s phones. The server that carries it cannot read any of it — not the calendar, not the messages, not where anyone is.';

  @override
  String get guideKeyTitle => 'Twelve words, kept somewhere safe';

  @override
  String get guideKeyBody =>
      'Because nobody else can read your family\'s data, nobody else can get it back for you either. Twelve words are the only way in if every phone is lost at once. It takes a minute, and it\'s the one thing worth not putting off.';

  @override
  String get guideKeyAction => 'Get my twelve words';

  @override
  String get guideReadyTitle => 'That\'s it';

  @override
  String get guideReadyBody =>
      'Have a look around. Anything you add shows up on the rest of the family\'s phones on its own.';

  @override
  String hwStripMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more',
      one: '1 more',
    );
    return '$_temp0';
  }

  @override
  String get shareAlways => 'Also when the app is closed';

  @override
  String get shareAlwaysHelp =>
      'Right now your family only sees where you are while the app is open.';

  @override
  String get shareAlwaysOn =>
      'Your family can see where you are even when the app is closed. Your phone shows this the whole time it\'s on.';

  @override
  String get shareAlwaysParentSet =>
      'A parent has turned this on, so your family can see where you are even when the app is closed. You can\'t switch it off here.';

  @override
  String get shareAlwaysDenied =>
      'Your phone didn\'t allow it. Look for \"Always\" under Location for this app in Settings.';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String fieldEndsLabel(String length) {
    return 'Ends · $length';
  }

  @override
  String removeManyTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Remove $count events?',
      one: 'Remove 1 event?',
    );
    return '$_temp0';
  }

  @override
  String get removeManyBody =>
      'They go to Recently deleted, where you can put them back.';

  @override
  String removeManyBodyRepeating(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count of these repeat: only the days you picked are removed, not the whole series.',
      one: 'One of these repeats: only the day you picked is removed, not the whole series.',
    );
    return '$_temp0';
  }

  @override
  String removedMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events removed',
      one: '1 event removed',
    );
    return '$_temp0';
  }

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String removeManyNotYours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weren\'t yours to remove',
      one: '1 wasn\'t yours to remove',
    );
    return '$_temp0';
  }

  @override
  String get moreGroupWeek => 'The week';

  @override
  String get moreGroupPeople => 'People';

  @override
  String get moreGroupPlaces => 'Places';

  @override
  String get moreGroupIntegrations => 'Brought in from elsewhere';

  @override
  String get moreGroupDevices => 'Devices';

  @override
  String get moreGroupSettings => 'Settings';

  @override
  String get wishlists => 'Gift lists';

  @override
  String get wishlistsSubtitle =>
      'What everyone would like, and who\'s getting it';

  @override
  String get wishlistsHelp =>
      'Everyone keeps their own list. When you open someone else\'s you can claim something, and they never see that it\'s taken — so the list stays a surprise while the rest of you sort out who\'s buying what.';

  @override
  String wishlistMine(String name) {
    return '$name · yours';
  }

  @override
  String get wishlistMineHint =>
      'Add what you\'d like. You won\'t see who has claimed anything.';

  @override
  String get wishlistTheirsHint =>
      'See what they\'d like, and say if you\'re getting it';

  @override
  String pollClosed(String title) {
    return 'Result: $title';
  }

  @override
  String get pollClosedNoWinner => 'Nobody voted, so nothing was chosen.';

  @override
  String get todoForYou => 'A job for you';

  @override
  String todoDueBy(String date) {
    return 'by $date';
  }

  @override
  String get pollsSubtitle => 'Ask everyone, and let the answers decide';

  @override
  String get pollsHelp =>
      'Ask the family anything and give them the options. Everyone ticks all the ones they\'d be happy with, not just one — so the answer is what most people can live with. When it closes, everyone gets the result.';

  @override
  String get pollsEmpty => 'Nothing being decided at the moment.';

  @override
  String get pollAsk => 'Ask the family';

  @override
  String get pollAskIt => 'Ask';

  @override
  String get pollQuestion => 'What are you asking?';

  @override
  String get pollQuestionHint => 'Which weekend do we go to the cabin?';

  @override
  String pollOptionNumber(int number) {
    return 'Option $number';
  }

  @override
  String get pollAddOption => 'Another option';

  @override
  String get pollIsClosed => 'Closed';

  @override
  String pollVotedSoFar(int voted, int total) {
    return '$voted of $total have answered';
  }

  @override
  String get withdrawMessage => 'Take it back';

  @override
  String get withdrawExplain =>
      'The words go from everyone\'s phone, and the thread will say a message was taken back. Anyone who already read it has already read it.';

  @override
  String get withdrawIt => 'Take it back';

  @override
  String get withdrawnHere => 'Message taken back';

  @override
  String inboxHomeworkDone(String name, String title) {
    return '$name finished $title';
  }

  @override
  String inboxChoreDone(String name, String title) {
    return '$name did $title';
  }

  @override
  String inboxApproval(String name, String title) {
    return '$name did $title: approve?';
  }

  @override
  String inboxAsked(String name, String title) {
    return '$name asks you: $title';
  }

  @override
  String inboxPoll(String title) {
    return 'Answer: $title';
  }

  @override
  String inboxChat(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread messages',
      one: '1 unread message',
    );
    return '$_temp0';
  }

  @override
  String get inboxSeen => 'Seen';

  @override
  String inboxSeeAll(int count) {
    return 'See all ($count)';
  }

  @override
  String get inboxNothing => 'Nothing waiting for you.';

  @override
  String get histSeen => 'saw it done';

  @override
  String get showOnMap => 'Show on map';

  @override
  String get cityMarket => 'Trading house';

  @override
  String get cityMarketLocked => 'Opens with the next district';

  @override
  String cityMarketMakes(String good) {
    return 'Your trading house makes $good';
  }

  @override
  String get cityLandmarks => 'Special buildings';

  @override
  String get landmarkHarbour => 'Harbour';

  @override
  String get landmarkCastle => 'Castle';

  @override
  String get landmarkZoo => 'Zoo';

  @override
  String get landmarkStadium => 'Stadium';

  @override
  String get landmarkBakery => 'Bakery';

  @override
  String get landmarkBuilt => 'Already in your city';

  @override
  String get landmarkShore => 'Must stand by the lake';

  @override
  String landmarkNeeds(String cost) {
    return 'Needs $cost';
  }

  @override
  String get goodFish => 'fish';

  @override
  String get goodWood => 'wood';

  @override
  String get goodStone => 'stone';

  @override
  String get goodWool => 'wool';

  @override
  String get goodHoney => 'honey';

  @override
  String get trade => 'Trade';

  @override
  String get tradeYourGoods => 'Your goods';

  @override
  String get tradeNoGoods =>
      'Nothing yet: your trading house makes one for every two things you do.';

  @override
  String get tradeOffersToYou => 'Offers to you';

  @override
  String tradeOfferLine(String name, String give, String get) {
    return '$name offers $give for your $get';
  }

  @override
  String get tradeYourOffers => 'Your offers';

  @override
  String tradeYourOfferLine(String name, String give, String get) {
    return 'You offered $name $give for $get';
  }

  @override
  String get tradeAccept => 'Swap';

  @override
  String get tradeDecline => 'No thanks';

  @override
  String get tradeWithdraw => 'Take back';

  @override
  String get tradeNew => 'New trade';

  @override
  String get tradeWith => 'Trade with';

  @override
  String get tradeGive => 'You give';

  @override
  String get tradeGet => 'You get';

  @override
  String get tradeEven => 'Always the same number both ways.';

  @override
  String get tradeSend => 'Send offer';

  @override
  String get tradeNobody =>
      'Nobody else in the family has a trading house yet.';

  @override
  String get tradeNotEnough => 'You don\'t have enough for this one yet.';

  @override
  String tradeTheyHave(String name, String count) {
    return '$name has $count';
  }

  @override
  String get tradeSent => 'Offer sent';

  @override
  String inboxTrade(String name, String give, String get) {
    return '$name wants to trade $give for your $get';
  }

  @override
  String get guideCityTrade =>
      'Build a trading house and swap goods with your brothers and sisters, always one for one. Every trade earns you both coins, and you can sell goods to the town. Special buildings need goods from more than one city.';

  @override
  String get shoppingEditItem => 'Change item';

  @override
  String get shoppingItemText => 'What to buy';

  @override
  String get shoppingItemHint => 'e.g. 2 l milk';

  @override
  String get shoppingAisle => 'Section';

  @override
  String get shoppingNote => 'Note';

  @override
  String get shoppingRenameList => 'Rename list';

  @override
  String get shoppingDeleteList => 'Delete list';

  @override
  String shoppingDeleteListExplain(String name) {
    return 'Removes $name and everything on it. You can bring it back from Recently deleted for a while.';
  }

  @override
  String get shoppingSelect => 'Select';

  @override
  String shoppingSelected(int count) {
    return '$count selected';
  }

  @override
  String get shoppingSelectAll => 'Select all';

  @override
  String get shoppingRemoveSelected => 'Remove';

  @override
  String shoppingRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Removed $count items',
      one: 'Removed 1 item',
    );
    return '$_temp0';
  }

  @override
  String get phoneCalendarMine => 'Mine';

  @override
  String get custodyGuideTitle => 'How two homes works';

  @override
  String get custodyGuideIntro =>
      'For a child who lives in two homes. Set it up once and the calendar knows where they are.';

  @override
  String get custodyGuideSchedule =>
      'A schedule per child: every other week or every other weekend, counted from one changeover you pick.';

  @override
  String get custodyGuideChangeover =>
      'Each changeover becomes an event in the calendar, like \"Maja to us\", so you can set who drives.';

  @override
  String get custodyGuideToday =>
      'Today shows when a child is at the other home, and when they are back.';

  @override
  String get custodyGuideSwaps =>
      'Swaps and holidays move single periods, with you or at the other home, without changing the schedule.';

  @override
  String get custodyGuideReminders =>
      'While a child is at the other home, their activities are that home\'s to arrange: you are not asked who drives.';

  @override
  String get custodyGuideOtherHome =>
      'The other home\'s parent can have their own limited account: More → Add a device → A parent from the other home. They see and edit only the children you share and their schedule, never your chat, meals, map or anything else. If they don\'t use the app, choose \"Doesn\'t use the app\".';

  @override
  String get custodyGuideHelp => 'How it works';

  @override
  String get electricityShow => 'Electricity price in the calendar';

  @override
  String get electricityShowHelp =>
      'The day\'s spot price for your price area, next to the weather. Tap it for the price hour by hour. Fetched by the phone from elprisetjustnu.se, which only learns the price area.';

  @override
  String get electricityOff => 'Off';

  @override
  String electricityOre(int ore) {
    return '$ore öre';
  }

  @override
  String electricityTitle(String day) {
    return 'Electricity price, $day';
  }

  @override
  String electricityAverage(int ore) {
    return 'Average $ore öre/kWh';
  }

  @override
  String electricityCheapest(String from, int ore) {
    return 'Cheapest $from: $ore öre';
  }

  @override
  String electricityDearest(String from, int ore) {
    return 'Dearest $from: $ore öre';
  }

  @override
  String electricityHour(String hour, int ore) {
    return '$hour: $ore öre/kWh';
  }

  @override
  String get electricityTapHint => 'Tap a bar for its price';

  @override
  String get electricitySource =>
      'Spot price excl. VAT, grid fee and surcharges, from elprisetjustnu.se.';

  @override
  String get electricityCheapLabel => 'Cheapest';

  @override
  String get electricityDearLabel => 'Dearest';

  @override
  String weatherTitle(String day) {
    return 'Weather, $day';
  }

  @override
  String weatherTemp(int degrees) {
    return '$degrees°';
  }

  @override
  String weatherWind(int speed) {
    return '$speed m/s';
  }

  @override
  String get weatherSixHours =>
      'This far ahead the forecast comes six hours at a time.';

  @override
  String get weatherSource =>
      'Forecast from MET Norway (yr.no), for about a kilometre around where this phone last was, or home.';

  @override
  String get searchPlaces => 'Settings and screens';

  @override
  String get searchWordsSettings =>
      'settings, notifications, reminders, quiet, silent, electricity, power, spot price, kWh, rewards, jar, supervision';

  @override
  String get searchWordsCalendars =>
      'calendar, Google, Outlook, iCloud, shared, sync';

  @override
  String get searchWordsMap => 'location, position, where, sharing';

  @override
  String get searchWordsDevices => 'phone, tablet, iPad, pair, QR';

  @override
  String get searchWordsPasswords => 'password, login, wifi, code';

  @override
  String get searchWordsCustody => 'custody, other home, co-parent, changeover';

  @override
  String get electricityNone =>
      'No price for this day yet. Tomorrow\'s is published around 13:00.';

  @override
  String get weatherNone => 'No forecast for this day.';

  @override
  String get calendarsRefresh => 'Fetch all now';

  @override
  String get servicePower => 'Wind turbine';

  @override
  String get serviceWater => 'Water tower';

  @override
  String get serviceFire => 'Fire station';

  @override
  String get serviceClinic => 'Clinic';

  @override
  String get serviceBus => 'Bus stop';

  @override
  String get serviceWhyPower => 'Apartments and towers need power nearby.';

  @override
  String get serviceWhyWater =>
      'Apartments, towers and big parks need water nearby.';

  @override
  String get serviceWhyFire => 'Towers need a fire station nearby.';

  @override
  String get serviceWhyClinic =>
      'Towers need a clinic nearby, and more people move in near one.';

  @override
  String get serviceWhyBus =>
      'Big stores need a bus stop, and more people move in near one.';

  @override
  String get cityServices => 'Services · paid with coins';

  @override
  String serviceCost(int coins) {
    return '$coins coins';
  }

  @override
  String serviceCostGoods(int coins, int count) {
    return '$coins coins + $count goods';
  }

  @override
  String get serviceByStreet => 'Has to stand next to a street';

  @override
  String serviceReach(int count) {
    return 'Reaches $count plots in every direction.';
  }

  @override
  String cityCoinsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count coins',
      one: '1 coin',
    );
    return '$_temp0';
  }

  @override
  String cityPopulationLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count residents',
      one: '1 resident',
    );
    return '$_temp0';
  }

  @override
  String get happeningMarketDay => 'Market day';

  @override
  String get happeningMarketDayBody =>
      'Your trading house makes twice as much today.';

  @override
  String get happeningFestival => 'Festival in the park';

  @override
  String get happeningFestivalBody =>
      'A coin extra for everything you do today, and fireworks tonight.';

  @override
  String get happeningTouristBus => 'Tourists are visiting';

  @override
  String get happeningTouristBusBody =>
      'Two coins extra for everything you do today.';

  @override
  String get happeningBalloonRace => 'Balloon race';

  @override
  String get happeningWhale => 'A whale in the lake!';

  @override
  String get happeningMeteorShower => 'Shooting stars tonight';

  @override
  String get happeningSeenBody =>
      'Do something today and it goes in your book.';

  @override
  String requestParkNear(String name) {
    return '$name would like a park near their home';
  }

  @override
  String requestShopNear(String name) {
    return '$name would like a shop near their home';
  }

  @override
  String requestHome(String name) {
    return '$name wants to move in: build a home';
  }

  @override
  String requestService(String name, String service) {
    return '$name wishes for: $service';
  }

  @override
  String requestReward(int coins) {
    return '$coins coins if it\'s built this week';
  }

  @override
  String requestThanks(String name, int coins) {
    return '$name says thank you! +$coins coins';
  }

  @override
  String get nextUpTitle => 'Next up';

  @override
  String nextHomeGrows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more things done and a home grows',
      one: '1 more thing done and a home grows',
    );
    return '$_temp0';
  }

  @override
  String nextParkGrows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more things done and a park grows',
      one: '1 more thing done and a park grows',
    );
    return '$_temp0';
  }

  @override
  String nextWaitsHome(String services) {
    return 'A home is waiting for: $services';
  }

  @override
  String nextWaitsShop(String services) {
    return 'A shop is waiting for: $services';
  }

  @override
  String nextWaitsPark(String services) {
    return 'A park is waiting for: $services';
  }

  @override
  String nextLevel(int count, int level) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more things done and district $level opens',
      one: '1 more thing done and district $level opens',
    );
    return '$_temp0';
  }

  @override
  String nextLearning(int count, String building) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more homework seen and your town gets: $building',
      one: '1 more homework seen and your town gets: $building',
    );
    return '$_temp0';
  }

  @override
  String get civicHall => 'Town hall';

  @override
  String get civicSchool => 'School';

  @override
  String get civicLibrary => 'Library';

  @override
  String get civicObservatory => 'Observatory';

  @override
  String get civicUniversity => 'University';

  @override
  String get civicFountain => 'Fountain';

  @override
  String get townTitle => 'The town';

  @override
  String get townPeopleHow =>
      'Homes fill up with a park and a shop nearby, a bus stop and a clinic.';

  @override
  String townNextMilestone(int count, int coins) {
    return '$count more residents: +$coins coins';
  }

  @override
  String get townCoinsHow =>
      'Everything you do earns coins. Shops and the trading house earn more, and so do trades, selling goods and residents\' wishes.';

  @override
  String get townGoal => 'Saving for';

  @override
  String get townGoalNone => 'Choose something to save for';

  @override
  String get townGoalNothing => 'Nothing for now';

  @override
  String get townGoalReady => 'You can build it now!';

  @override
  String get townSell => 'Sell goods';

  @override
  String townSellHow(int coins) {
    return 'The town pays $coins coins for each good.';
  }

  @override
  String get townSellOne => 'Sell 1';

  @override
  String get projectTitle => 'Family project';

  @override
  String get projectStatue => 'Statue';

  @override
  String get projectClockTower => 'Clock tower';

  @override
  String get projectFerrisWheel => 'Ferris wheel';

  @override
  String projectProgress(String name, int given, int need) {
    return '$name: $given of $need goods';
  }

  @override
  String get projectHow =>
      'Everyone gives goods. When it\'s finished, it stands in every city.';

  @override
  String get projectGiveOne => 'Give 1';

  @override
  String get projectAllDone => 'Everything is built. Thank you, everyone!';

  @override
  String get bookTitle => 'My book';

  @override
  String bookOf(String name) {
    return '$name\'s book';
  }

  @override
  String bookCount(int have, int all) {
    return '$have of $all found';
  }

  @override
  String get bookBuildings => 'Buildings';

  @override
  String get bookSeen => 'Seen in the town';

  @override
  String get sizeCottage => 'Cottage';

  @override
  String get sizeHouse => 'House';

  @override
  String get sizeApartments => 'Apartments';

  @override
  String get sizeTower => 'Tower';

  @override
  String get sizeLawn => 'Lawn';

  @override
  String get sizeTrees => 'Trees and a bench';

  @override
  String get sizePond => 'Pond or playground';

  @override
  String get sizeBigPark => 'Big park';

  @override
  String get sizeKiosk => 'Corner shop';

  @override
  String get sizeShop => 'Shop';

  @override
  String get sizeStore => 'Big store';

  @override
  String get choreWorth => 'Big job: counts as more in the child\'s city';

  @override
  String get guideCityServices =>
      'From apartments up, homes need services nearby to grow: power, water, and for towers a fire station and a clinic. Build them with coins, which everything you do earns.';

  @override
  String get guideCityLife =>
      'Things happen in your town: market days, festivals, balloon races. Every week someone who lives there wishes for something, and granting it pays coins.';

  @override
  String get guideParentWorth =>
      'A big chore can count as two or three things in the child\'s city: choose it when you create the chore.';

  @override
  String get cityNoSeedsLeft => 'Do something more to build this';

  @override
  String get myOwnCity => 'My own city';

  @override
  String get myOwnCitySubtitle =>
      'Your own chores build it, with the same rules as the children\'s.';

  @override
  String get presentGive => 'Give a present';

  @override
  String get presentHow =>
      'Coins or goods for something worth noticing. Nothing is ever taken away.';

  @override
  String get presentCoins => 'Coins';

  @override
  String get presentGoods => 'Goods';

  @override
  String get presentNote => 'What is it for? (optional)';

  @override
  String get presentSend => 'Give';

  @override
  String get presentSent => 'Present given';

  @override
  String get presentToProject => 'Goods for the family project';

  @override
  String presentFrom(String name, String what) {
    return '$name gave you $what';
  }

  @override
  String get guideParentOwnCity =>
      'You can build a city of your own too, from your own chores, and give the children presents of coins or goods from their city\'s page.';

  @override
  String get servicePolice => 'Police station';

  @override
  String get serviceWhyPolice =>
      'Keeps thieves away from the homes it reaches.';

  @override
  String get troubleFire => 'Fire! A building is burning.';

  @override
  String get troubleFireBody =>
      'Do something and the firefighters come. A fire station nearby keeps fires away.';

  @override
  String troubleThief(int count) {
    return 'A thief! He has hidden $count of your coins and is laughing at you.';
  }

  @override
  String get troubleThiefLooking =>
      'A thief is sneaking around town, looking for coins!';

  @override
  String get troubleThiefBody =>
      'Do something to catch him, and you get everything back. A police station keeps thieves away.';

  @override
  String get troubleFireOut => 'Put out a fire';

  @override
  String get troubleThiefCaught => 'Caught a thief';

  @override
  String get guideCityTrouble =>
      'Now and then a fire breaks out or a thief comes to town. Nothing is ever lost: do something and the firefighters or the police sort it out, with a coin as thanks. A fire station and a police station keep them away.';

  @override
  String get cityFree => 'free';

  @override
  String get whatsNewTitle => 'What\'s new';

  @override
  String whatsNewBuild(int build) {
    return 'Version $build';
  }

  @override
  String get whatsNewOk => 'Nice!';

  @override
  String get todoTogether =>
      'Together: everyone chosen does it, and it counts for all of them';

  @override
  String get todoForMany =>
      'Choose one or more; nobody chosen puts it in the family pool.';

  @override
  String get cityShowPlots => 'Show the plots';

  @override
  String get cityShowTown => 'Show the town';

  @override
  String recognisedApproved(String name, String title) {
    return '$name approved: $title';
  }

  @override
  String recognisedSeen(String name, String title) {
    return '$name saw it done: $title';
  }

  @override
  String recognisedHomework(String name, String title) {
    return '$name saw your homework: $title';
  }

  @override
  String get recognisedWellDone => 'Well done!';

  @override
  String recognisedGrows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Well done! Your city grows by $count.',
      one: 'Well done! Your city grows by 1.',
    );
    return '$_temp0';
  }

  @override
  String get upgradeTitle => 'Ready to grow';

  @override
  String get upgradeChoose => 'Choose how it grows';

  @override
  String get pathMoreFlats => 'More flats';

  @override
  String get pathMoreFlatsWhy => 'A quarter more people can live here.';

  @override
  String get pathGarden => 'Garden';

  @override
  String get pathGardenWhy =>
      'Works like a park for this home and the homes next door.';

  @override
  String get pathShopDownstairs => 'Shop downstairs';

  @override
  String get pathShopDownstairsWhy =>
      'Works like a shop: more coins, and the neighbours can grow taller.';

  @override
  String get pathCafe => 'Café';

  @override
  String get pathCafeWhy => 'Earns coins like two shops.';

  @override
  String get pathToyShop => 'Toy shop';

  @override
  String get pathToyShopWhy => 'Homes nearby fill up with more people.';

  @override
  String get pathPlayground => 'Playground';

  @override
  String get pathPlaygroundWhy => 'Homes nearby fill up with more people.';

  @override
  String get pathWoodland => 'Woodland';

  @override
  String get pathWoodlandWhy =>
      'Helps homes up to two plots away grow, not only next door.';

  @override
  String get nextReady => 'Something is ready to grow: tap the ⬆️ on it!';

  @override
  String get sportPitch => 'Football pitch';

  @override
  String get sportPool => 'Swimming pool';

  @override
  String get sportHall => 'Sports hall';

  @override
  String get citySports => 'Sports · free, unlocked by being active';

  @override
  String sportLocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Be active $count more times',
      one: 'Be active 1 more time',
    );
    return '$_temp0';
  }

  @override
  String get sportWhy => 'Homes nearby get more residents.';

  @override
  String get activityWent => 'I went';

  @override
  String activityDidYouGo(String title) {
    return 'Did you go to $title?';
  }

  @override
  String get activityCounted => 'Counted. Well done!';

  @override
  String get activityWho => 'Who went?';

  @override
  String get activityLog => 'I was active';

  @override
  String get activityLogTitle => 'What did you do?';

  @override
  String activityMinutes(int count) {
    return '$count min';
  }

  @override
  String get activityOutside => 'Played outside';

  @override
  String get activityCycling => 'Cycling';

  @override
  String get activityWalk => 'A walk';

  @override
  String get activityFootball => 'Football';

  @override
  String get activitySwim => 'Swimming';

  @override
  String get activityDance => 'Dance';

  @override
  String get activityOther => 'Something else';

  @override
  String get activitySentForApproval => 'Sent to a grown-up to approve';

  @override
  String get guideCityActive =>
      'Being active counts too: tick \"I went\" after football or dance, or log time outside. It unlocks a football pitch, a swimming pool and a sports hall for your city.';

  @override
  String get cityNotifyReady => '⬆️ Something in your city is ready to grow!';

  @override
  String get cityNotifyReadyBody => 'Tap it and choose how it grows.';

  @override
  String get cityCardTitle => 'My city';

  @override
  String cityCardReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ready to grow',
      one: '1 ready to grow',
    );
    return '$_temp0';
  }

  @override
  String get decorFlowers => 'Flower bed';

  @override
  String get decorBench => 'Bench';

  @override
  String get decorLamp => 'Lamp post';

  @override
  String get decorBigTree => 'Big tree';

  @override
  String get decorFlag => 'Flag';

  @override
  String get decorStatue => 'Statue';

  @override
  String get decorFountain => 'Fountain';

  @override
  String get cityDecor => 'Decorations · coins';

  @override
  String get decorWhy => 'Homes right next to it get a few more residents.';

  @override
  String get guideCityDecor =>
      'Make the town your own: flower beds, benches, lamp posts, trees, flags, statues and fountains cost a few coins and go on any free plot.';

  @override
  String get forRelative => 'A relative';

  @override
  String get forRelativeSubtitle =>
      'Grandma, grandpa or someone else close: sees the gift lists and can take a gift to buy, nothing else.';

  @override
  String get relativesName => 'Their name';

  @override
  String get roleRelative => 'Relative';

  @override
  String get scanFromPhoto => 'Scan from a photo';

  @override
  String get scanFromPhotoHelp =>
      'Far away? They open the app, take a screenshot of their code and send it to you. Only scan a picture that really came from them.';

  @override
  String get scanFromPhotoNone => 'No code found in that picture';

  @override
  String get editWish => 'Edit the wish';

  @override
  String get giftChannel => 'Gifts';

  @override
  String get giftChannelDescription =>
      'New wishes and gifts someone has taken. Never about your own list.';

  @override
  String giftNewWish(String person, String title) {
    return '$person wishes for: $title';
  }

  @override
  String giftTaken(String who, String person, String title) {
    return '$who will give $person: $title';
  }

  @override
  String get giftSecret => 'A secret about a gift';

  @override
  String get giftTapToSee => 'Open the gift lists to see.';

  @override
  String get aboutTitle => 'About the app';

  @override
  String aboutVersion(String version, int build) {
    return 'Version $version (build $build)';
  }

  @override
  String get aboutReleaseNotes => 'What\'s new';

  @override
  String get aboutFeedback => 'Ideas and bug reports';

  @override
  String get aboutFeedbackSubtitle =>
      'Tell the developer what\'s wrong or what you\'d like, and vote on others\' posts.';

  @override
  String get feedbackTitle => 'Ideas and bug reports';

  @override
  String get feedbackNew => 'New post';

  @override
  String get feedbackBug => 'Bug';

  @override
  String get feedbackIdea => 'Idea';

  @override
  String get feedbackOther => 'Other';

  @override
  String get feedbackPostTitle => 'In a few words';

  @override
  String get feedbackPostBody =>
      'Tell more: what you did, what happened, what you\'d like';

  @override
  String get feedbackAnonymous => 'Post anonymously';

  @override
  String get feedbackAnonymousHelp =>
      'Your name is not shown. You can still remove your own post.';

  @override
  String get feedbackNotice =>
      'Posts go to the developer and are visible to everyone who uses the app. Unlike your family\'s things, they are not end-to-end encrypted, so don\'t write anything private.';

  @override
  String get feedbackSend => 'Send';

  @override
  String get feedbackSent => 'Thank you!';

  @override
  String get feedbackEmpty => 'Nothing yet. Be the first!';

  @override
  String get feedbackAnonymousName => 'Anonymous';

  @override
  String get feedbackFailed =>
      'Couldn\'t reach the server. Try again in a while.';

  @override
  String get feedbackStatusPlanned => 'Planned';

  @override
  String get feedbackStatusDone => 'Done';

  @override
  String get feedbackStatusDeclined => 'Not planned';

  @override
  String feedbackReply(String reply) {
    return 'The developer: $reply';
  }

  @override
  String get feedbackRemove => 'Remove my post';
}
