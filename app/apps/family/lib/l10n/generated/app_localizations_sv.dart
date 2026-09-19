// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class AppLocalizationsSv extends AppLocalizations {
  AppLocalizationsSv([String locale = 'sv']) : super(locale);

  @override
  String get tabToday => 'Idag';

  @override
  String get tabWeek => 'Vecka';

  @override
  String get tabChat => 'Chatt';

  @override
  String get tabShopping => 'Handla';

  @override
  String get tabMore => 'Mer';

  @override
  String weekNumber(int number) {
    return 'Vecka $number';
  }

  @override
  String get weekPrevious => 'Föregående vecka';

  @override
  String get weekThis => 'Den här veckan';

  @override
  String get weekNext => 'Nästa vecka';

  @override
  String weekLoadFailed(String error) {
    return 'Kunde inte ladda veckan.\n$error';
  }

  @override
  String get scopeMine => 'Mitt';

  @override
  String get scopeFamily => 'Familjen';

  @override
  String weekWarnings(String parts) {
    return 'Den här veckan: $parts';
  }

  @override
  String weekUnassigned(int count) {
    return '$count utan ansvarig vuxen';
  }

  @override
  String weekDoubleBooked(int count) {
    return '$count dubbelbokade';
  }

  @override
  String get today => 'Idag';

  @override
  String get nothingPlanned => 'Inget planerat';

  @override
  String get cancelled => 'Inställt';

  @override
  String driving(String name) {
    return 'Kör: $name';
  }

  @override
  String get noOneResponsible => 'Ingen ansvarig';

  @override
  String get doubleBookedShort => 'dubbelbokad';

  @override
  String get shoppingDescription =>
      'Den aktuella listan sorterad efter avdelning, med källan märkt på varje vara.';

  @override
  String get chatDescription =>
      'Trådarna, med familjens tråd fäst överst. Totalsträckskrypterat med MLS.';

  @override
  String get kitchenDisplay => 'Köksskärm';

  @override
  String get kitchenDescription =>
      'Veckan, dagens middag och inköpslistan på en surfplatta på väggen. En enhetssession: ingen medlemsinloggning och inga chattnycklar.';

  @override
  String get welcomeTagline =>
      'Familjens kalender, listor och chatt — krypterade så att bara ni kan läsa dem.';

  @override
  String get startFamily => 'Starta en ny familj';

  @override
  String get joinFamily => 'Gå med i min familj';

  @override
  String get newEvent => 'Ny händelse';

  @override
  String todayLoadFailed(String error) {
    return 'Kunde inte ladda dagen.\n$error';
  }

  @override
  String get nothingToday => 'Inget planerat idag.';

  @override
  String unassignedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ingen är ansvarig för $count händelser',
      one: 'Ingen är ansvarig för 1 händelse',
    );
    return '$_temp0';
  }

  @override
  String get doubleBooked => 'Dubbelbokat';

  @override
  String get someone => 'Någon';

  @override
  String overlaps(
    String first,
    String firstTime,
    String second,
    String secondTime,
  ) {
    return '$first $firstTime krockar med $second $secondTime';
  }

  @override
  String nextUp(String when) {
    return 'Härnäst · $when';
  }

  @override
  String get startingNow => 'börjar nu';

  @override
  String inMinutes(int minutes) {
    return 'om $minutes min';
  }

  @override
  String inHours(int hours) {
    return 'om $hours tim';
  }

  @override
  String inHoursMinutes(int hours, int minutes) {
    return 'om $hours tim $minutes min';
  }

  @override
  String get addDevice => 'Lägg till en enhet';

  @override
  String get addDeviceSubtitle =>
      'Ett barns surfplatta, den andra förälderns telefon';

  @override
  String get trustedDevices => 'Betrodda enheter';

  @override
  String trustedDevicesCount(int count) {
    return '$count i familjen, den här inräknad';
  }

  @override
  String get moreComingSoon =>
      'Planering, födelsedagar, måltider, att göra, karta och familjeinställningar hamnar här.';

  @override
  String deleteEventTitle(String title) {
    return 'Ta bort \"$title\"?';
  }

  @override
  String get deleteEventOnce =>
      'Den försvinner för hela familjen. Den kan återställas i 30 dagar.';

  @override
  String get deleteEventSeries =>
      'Alla tillfällen försvinner för hela familjen. De kan återställas i 30 dagar.';

  @override
  String get keep => 'Behåll';

  @override
  String get delete => 'Ta bort';

  @override
  String get edit => 'Redigera';

  @override
  String get parentsOnlyNote =>
      'Bara föräldrar: barnens enheter får ingen läsbar kopia';

  @override
  String get whosGoing => 'Vem ska med';

  @override
  String get wholeFamily => 'Hela familjen';

  @override
  String get responsible => 'Ansvarig';

  @override
  String get noOneYet => 'Ingen än';

  @override
  String get eventGone => 'Den här händelsen finns inte längre.';

  @override
  String repeatsWeeklyOn(String days) {
    return 'Varje vecka på $days';
  }

  @override
  String get repeatsDaily => 'Varje dag';

  @override
  String get repeatsWeekly => 'Varje vecka';

  @override
  String get repeatsMonthly => 'Varje månad';

  @override
  String get repeatsYearly => 'Varje år';

  @override
  String get titleRequired => 'Ge den en titel.';

  @override
  String saveEventFailed(String error) {
    return 'Kunde inte spara händelsen.\n$error';
  }

  @override
  String get editEvent => 'Redigera händelse';

  @override
  String get save => 'Spara';

  @override
  String get fieldTitle => 'Titel';

  @override
  String get fieldLength => 'Längd';

  @override
  String get fieldWhere => 'Var (valfritt)';

  @override
  String get fieldResponsible => 'Ansvarig / kör';

  @override
  String get repeatsEveryWeek => 'Upprepas varje vecka';

  @override
  String everyWeekday(String weekday) {
    return 'Varje $weekday';
  }

  @override
  String get parentsOnly => 'Bara föräldrar';

  @override
  String get parentsOnlySubtitle => 'Barnens enheter får ingen läsbar kopia.';

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHours(int hours) {
    return '$hours tim';
  }

  @override
  String get namesRequired => 'Fyll i familjens namn och ditt eget.';

  @override
  String createFailed(String error) {
    return 'Kunde inte skapa familjen. Kontrollera anslutningen och försök igen.\n$error';
  }

  @override
  String get familyName => 'Familjens namn';

  @override
  String get familyNameHint => 'Familjen Svensson';

  @override
  String get yourName => 'Ditt namn';

  @override
  String get serverCanReadFamilyName =>
      'Familjens namn är det enda vår server kan läsa. Ditt namn och allt annat du lägger till krypteras på den här telefonen.';

  @override
  String get createFamily => 'Skapa familj';

  @override
  String keysFailed(String error) {
    return 'Enheten kunde inte skapa sina nycklar.\n$error';
  }

  @override
  String get serverUnreachable => 'Når inte servern just nu. Försöker igen…';

  @override
  String get joinInstructions =>
      'Öppna Family på en förälders telefon, gå till Mer → Lägg till en enhet och skanna den här koden.';

  @override
  String get pairingCode => 'Parkopplingskod';

  @override
  String get waitingForScan => 'Väntar på att en förälder skannar…';

  @override
  String get codeWarning =>
      'Koden fungerar en gång, och bara medan den här skärmen är öppen. Dela inte en bild av den.';

  @override
  String get detailsUnreadable => 'Enhetens familjeuppgifter kunde inte läsas.';

  @override
  String get tryAgain => 'Försök igen';

  @override
  String get notAPairingCode => 'Det där är ingen parkopplingskod för Family.';

  @override
  String get codeUnreadable =>
      'Koden kunde inte läsas. Be om en ny och skanna igen.';

  @override
  String addDeviceFailed(String error) {
    return 'Kunde inte lägga till enheten. Kontrollera anslutningen och skanna igen.\n$error';
  }

  @override
  String get nameRequired => 'Fyll i namnet först.';

  @override
  String get whoIsDeviceFor => 'Vem är den nya enheten till?';

  @override
  String get forChild => 'Ett barn';

  @override
  String get forChildSubtitle =>
      'Ser familjens kalender och listor, men inte det som bara är för föräldrar.';

  @override
  String get forOtherParent => 'Den andra föräldern';

  @override
  String get forOtherParentSubtitle =>
      'Ser allt du ser och kan lägga till enheter.';

  @override
  String get forMyself => 'Jag, på en annan enhet';

  @override
  String get forMyselfSubtitle => 'En egen surfplatta eller en till telefon.';

  @override
  String get childsName => 'Barnets namn';

  @override
  String get otherParentsName => 'Den andra förälderns namn';

  @override
  String get showCodeInstructions =>
      'Öppna Family på den nya enheten och välj \"Gå med i min familj\" för att visa koden.';

  @override
  String get scanCode => 'Skanna koden';

  @override
  String get cameraDenied =>
      'Family behöver kameran för att skanna koden. Tillåt den i Inställningar och kom sedan tillbaka.';

  @override
  String cameraFailed(String reason) {
    return 'Kameran kunde inte starta: $reason';
  }

  @override
  String get pointCamera => 'Rikta kameran mot koden på den nya enheten.';

  @override
  String get deviceAdded => 'Enheten är tillagd';

  @override
  String get deviceAddedDetail =>
      'Den gör klart inställningarna själv om en stund.';

  @override
  String get done => 'Klar';

  @override
  String get changeWhich => 'Vilka vill du ändra?';

  @override
  String get removeWhich => 'Vilka vill du ta bort?';

  @override
  String get scopeThisOne => 'Bara den här';

  @override
  String get scopeThisAndAfter => 'Den här och alla efter';

  @override
  String get scopeAll => 'Alla';

  @override
  String get cancelThisOne => 'Ställ in bara den här';

  @override
  String get removeThisAndAfter => 'Ta bort den här och alla efter';

  @override
  String get removeAll => 'Ta bort alla';

  @override
  String occurrenceCancelled(String title, String date) {
    return '$title $date är inställd.';
  }

  @override
  String get undo => 'Ångra';

  @override
  String get editOccurrence => 'Ändra den här gången';

  @override
  String onlyThisOccurrence(String date) {
    return 'Ändrar bara $date. Vilka som ska med, platsen och upprepningen följer serien.';
  }

  @override
  String get changedThisTime => 'Ändrad den här gången';

  @override
  String movedFrom(String date) {
    return 'Flyttad från $date';
  }

  @override
  String get fieldReminder => 'Påminnelse';

  @override
  String get reminderNone => 'Ingen';

  @override
  String get reminderAtStart => 'När det börjar';

  @override
  String reminderMinutesBefore(int minutes) {
    return '$minutes min innan';
  }

  @override
  String reminderHoursBefore(int hours) {
    return '$hours tim innan';
  }

  @override
  String get reminderDayBefore => 'Dagen innan';

  @override
  String reminderStarts(String time) {
    return 'Börjar $time';
  }

  @override
  String get remindersChannel => 'Påminnelser';

  @override
  String get remindersChannelDescription => 'Inför händelser du är med i';

  @override
  String get recentlyDeleted => 'Nyligen borttagna';

  @override
  String get recentlyDeletedSubtitle => 'Återställ händelser i 30 dagar';

  @override
  String get recentlyDeletedEmpty => 'Inget borttaget de senaste 30 dagarna.';

  @override
  String get restore => 'Återställ';

  @override
  String deletedOn(String date) {
    return 'Borttagen $date';
  }

  @override
  String eventRemoved(String title) {
    return '$title togs bort.';
  }

  @override
  String seriesEnded(String title, String date) {
    return '$title slutar nu före $date.';
  }

  @override
  String get places => 'Platser';

  @override
  String get placesSubtitle => 'Hemma, idrottshallen, mormor';

  @override
  String get placesEmpty =>
      'Inga platser än. Lägg till dem familjen åker till varje vecka.';

  @override
  String get newPlace => 'Ny plats';

  @override
  String get editPlace => 'Ändra plats';

  @override
  String get placeName => 'Namn';

  @override
  String get placeNameHint => 'Sportshallen';

  @override
  String get placeAddress => 'Adress (valfri)';

  @override
  String get placeIsHome => 'Det här är hemma';

  @override
  String get placeIsHomeSubtitle => 'Där resorna börjar';

  @override
  String get parkingBuffer => 'Parkering och gå in';

  @override
  String get parkingNone => 'Ingen extra tid';

  @override
  String parkingMinutes(int minutes) {
    return '$minutes min extra';
  }

  @override
  String get fieldPlace => 'Plats';

  @override
  String get noPlace => 'Ingen plats';

  @override
  String get choosePlace => 'Välj en plats';

  @override
  String get placeNameRequired => 'Ge platsen ett namn.';

  @override
  String reminderLeaveNow(String time) {
    return 'Dags att åka · börjar $time';
  }

  @override
  String reminderTomorrow(String time) {
    return 'I morgon kl. $time';
  }

  @override
  String reminderUnassigned(String day, String time) {
    return 'Ingen är ansvarig än · $day $time';
  }

  @override
  String remindersTogether(int count) {
    return '$count påminnelser';
  }

  @override
  String get digestTitle => 'I dag';

  @override
  String digestSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saker i dag',
      one: '1 sak i dag',
    );
    return '$_temp0';
  }

  @override
  String get quietChannel => 'Påminnelser under tysta timmar';

  @override
  String get familySettings => 'Familjeinställningar';

  @override
  String get familySettingsSubtitle => 'Tysta timmar, morgonsammanfattning';

  @override
  String get quietHours => 'Tysta timmar';

  @override
  String quietHoursRange(String from, String to) {
    return '$from–$to';
  }

  @override
  String get quietHoursHelp =>
      'Påminnelser om att förbereda sig flyttas till kvällen innan. Påminnelser om att åka kommer ändå, utan ljud.';

  @override
  String get quietFrom => 'Från';

  @override
  String get quietTo => 'Till';

  @override
  String get morningDigest => 'Morgonsammanfattning';

  @override
  String get morningDigestHelp =>
      'En avisering med dagens planer, i stället för många.';

  @override
  String get gettingReady => 'Göra sig klar';

  @override
  String get gettingReadyHelp =>
      'Läggs till innan det är dags att åka: jackor, skor, leta efter den andra skon.';

  @override
  String changeAdded(String when) {
    return 'Nytt · $when';
  }

  @override
  String get changeCancelled => 'Inställt';

  @override
  String changeCancelledOne(String day) {
    return 'Inställt $day · bara den gången';
  }

  @override
  String changeTime(String when) {
    return 'Ny tid · $when';
  }

  @override
  String changePlace(String when) {
    return 'Ny plats · $when';
  }

  @override
  String changeTimeAndPlace(String when) {
    return 'Ny tid och plats · $when';
  }

  @override
  String changeMovedOne(String day) {
    return 'Flyttad $day · bara den gången';
  }

  @override
  String changeEveryTime(String text) {
    return '$text · alla gånger';
  }

  @override
  String changeYouAreIn(String when) {
    return 'Du har lagts till · $when';
  }

  @override
  String get changeYouAreOut => 'Du är inte längre med';

  @override
  String changeYouDrive(String when) {
    return 'Du kör · $when';
  }

  @override
  String changeSomeoneElseDrives(String when) {
    return 'Någon annan kör · $when';
  }

  @override
  String get changesChannel => 'Ändrade planer';

  @override
  String get changesChannelDescription =>
      'När något du är med i flyttas eller ställs in';
}
