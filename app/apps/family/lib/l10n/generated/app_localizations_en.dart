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
    return 'Couldn\'t remove the device.\n$error';
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
      'Coming events from this calendar are removed. Past ones stay.';

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
}
