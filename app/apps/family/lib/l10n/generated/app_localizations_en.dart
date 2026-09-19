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
      'On a parent\'s phone, open Family, go to More → Add a device, and scan this code.';

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
  String get notAPairingCode => 'That isn\'t a Family pairing code.';

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
      'On the new device, open Family and choose \"Join my family\" to show its code.';

  @override
  String get scanCode => 'Scan the code';

  @override
  String get cameraDenied =>
      'Family needs the camera to scan the code. Allow it in Settings, then come back.';

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
}
