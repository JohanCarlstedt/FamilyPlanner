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
}
