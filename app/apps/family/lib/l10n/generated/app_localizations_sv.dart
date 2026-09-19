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
      'Öppna Family Planner på en förälders telefon, gå till Mer → Lägg till en enhet och skanna den här koden.';

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
  String get notAPairingCode =>
      'Det där är ingen parkopplingskod för Family Planner.';

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
      'Öppna Family Planner på den nya enheten och välj \"Gå med i min familj\" för att visa koden.';

  @override
  String get scanCode => 'Skanna koden';

  @override
  String get cameraDenied =>
      'Family Planner behöver kameran för att skanna koden. Tillåt den i Inställningar och kom sedan tillbaka.';

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

  @override
  String get members => 'Medlemmar';

  @override
  String get membersSubtitle => 'Vilka som är med, och barn utan telefon';

  @override
  String get addChild => 'Lägg till ett barn';

  @override
  String get editMember => 'Ändra medlem';

  @override
  String get memberName => 'Namn';

  @override
  String get tier => 'Åldersgrupp';

  @override
  String get tierLittle => 'Liten (under ca 8)';

  @override
  String get tierKid => 'Barn (ca 8–12)';

  @override
  String get tierTeen => 'Tonåring (ca 13+)';

  @override
  String get roleParent => 'Förälder';

  @override
  String get roleChild => 'Barn';

  @override
  String get colour => 'Färg';

  @override
  String get childNoPhoneNote =>
      'Ett barn utan telefon är med i allt: deras händelser och påminnelser går till den som är ansvarig. När de får en enhet lägger du till den på dem under Lägg till en enhet.';

  @override
  String get forExisting => 'Någon som redan är med';

  @override
  String get forExistingSubtitle => 'Deras händelser och färg följer med.';

  @override
  String get chooseMember => 'Vem?';

  @override
  String get memberRequired => 'Välj vem enheten är till.';

  @override
  String reminderForChild(String name, String title) {
    return '$name: $title';
  }

  @override
  String get thisDevice => 'Den här enheten';

  @override
  String deviceOf(String name) {
    return '${name}s enhet';
  }

  @override
  String get someDevice => 'En enhet';

  @override
  String get removeDevice => 'Ta bort';

  @override
  String removeDeviceTitle(String device) {
    return 'Ta bort $device?';
  }

  @override
  String get removeDeviceBody =>
      'Den slutar synka direkt och kan inte läsa något nytt: familjens nycklar byts. Det som redan finns på den ligger kvar, och det går inte att ta tillbaka.';

  @override
  String get deviceRemoved => 'Borttagen. Familjens nycklar har bytts.';

  @override
  String removeFailed(String error) {
    return 'Kunde inte ta bort enheten.\n$error';
  }

  @override
  String get removeMember => 'Ta bort från familjen';

  @override
  String removeMemberTitle(String name) {
    return 'Ta bort $name från familjen?';
  }

  @override
  String get removeMemberBody =>
      'Deras enheter slutar synka och familjens nycklar byts. Händelser de skapat ligger kvar; händelser de var ansvariga för behöver någon ny. Det som redan finns på deras enheter ligger kvar där.';

  @override
  String memberRemoved(String name) {
    return '$name togs bort från familjen.';
  }

  @override
  String get setupWhoTitle => 'Vilka är med i familjen?';

  @override
  String get setupWhoBody =>
      'Lägg till barnen först: allt annat kretsar kring dem. De behöver ingen telefon.';

  @override
  String get next => 'Nästa';

  @override
  String get setupPrivacyTitle => 'Bara din familj kan läsa det';

  @override
  String get setupPrivacyBody =>
      'Familjens kalender, meddelanden, listor och bilder krypteras på era enheter. Bara ni i familjen kan läsa dem — inte vi, och inte någon annan.\n\nDet betyder också att vi inte kan återställa något om alla familjens enheter försvinner.';

  @override
  String get getStarted => 'Kom igång';

  @override
  String get oneDeviceWarning =>
      'Bara den här telefonen har familjens nycklar. Lägg till en enhet till — den andra förälderns telefon eller en surfplatta — så att en borttappad telefon inte betyder en förlorad kalender.';

  @override
  String get roleHelper => 'Hjälpare';

  @override
  String get forHelper => 'En hjälpare';

  @override
  String get forHelperSubtitle =>
      'En barnvakt eller mor- eller farförälder: ser barnen du väljer, så länge du säger.';

  @override
  String get helpersName => 'Hjälparens namn';

  @override
  String get helperChildren => 'Vilka barn?';

  @override
  String helperUntil(String when) {
    return 'Till $when';
  }

  @override
  String get helperChildrenRequired => 'Välj minst ett barn.';

  @override
  String get helperForwardOnly =>
      'När tiden är ute slutar deras telefon att synka. Det den redan visat ligger kvar på den.';

  @override
  String get familyThread => 'Familjen';

  @override
  String get chatEmpty =>
      'Skriv något till familjen. Bara familjens enheter kan läsa det.';

  @override
  String get chatWaiting =>
      'Väntar på att en förälders telefon lägger till den här enheten i familjechatten.';

  @override
  String get chatAlone =>
      'Familjechatten börjar när en enhet till har lagts till.';

  @override
  String get chatHint => 'Meddelande';

  @override
  String get send => 'Skicka';

  @override
  String get sendFailed =>
      'Kunde inte skicka. Kontrollera anslutningen och försök igen.';

  @override
  String get chatChannel => 'Familjechatt';

  @override
  String get chatChannelDescription => 'Meddelanden från familjen';

  @override
  String get recoveryKit => 'Återställningsord';

  @override
  String get recoveryKitSubtitle =>
      'Tolv ord som tar tillbaka familjen om alla telefoner försvinner';

  @override
  String get recoveryIntro =>
      'Om alla telefoner och surfplattor i familjen försvinner är de här tolv orden enda vägen tillbaka. Skriv dem på papper och förvara det säkert hemma — inte som foto, inte i ett mejl.';

  @override
  String get showWords => 'Visa mina ord';

  @override
  String get wroteThemDown => 'Jag har skrivit ner dem';

  @override
  String get checkWords => 'Kontrollera att du har dem';

  @override
  String wordNumber(int n) {
    return 'Ord $n';
  }

  @override
  String get wordsDontMatch =>
      'Det stämmer inte med orden. Titta på papperet och försök igen.';

  @override
  String get savingKit => 'Sparar dina återställningsord…';

  @override
  String get kitReady =>
      'Dina återställningsord är klara. Eventuella tidigare ord fungerar inte längre.';

  @override
  String kitFailed(String error) {
    return 'Kunde inte spara återställningsorden.\n$error';
  }

  @override
  String get recoverFamily => 'Återställ med mina tolv ord';

  @override
  String get recoverTitle => 'Återställ din familj';

  @override
  String get recoverHelp =>
      'Skriv de tolv orden från papperet, i ordning, med mellanslag emellan.';

  @override
  String get recover => 'Återställ';

  @override
  String get recovering => 'Återställer… det tar några sekunder.';

  @override
  String get recoverBadWords =>
      'Det är inte tolv giltiga ord. Ett enda felskrivet ord räcker — kontrollera vart och ett.';

  @override
  String get recoverNotFound =>
      'De här orden öppnar ingen familj. De kan ha ersatts av nyare.';

  @override
  String recoverFailed(String error) {
    return 'Kunde inte återställa.\n$error';
  }

  @override
  String get securing => 'Säkrar familjens nycklar…';

  @override
  String get recoveredNewWords =>
      'Du är tillbaka. De gamla orden kan ha setts, så de fungerar inte längre: gör nya nu.';

  @override
  String get continueLabel => 'Fortsätt';

  @override
  String get notificationsOff =>
      'Påminnelser når dig inte: aviseringar är avstängda för Family Planner. Den skickar bara det som gäller familjens planer.';

  @override
  String get turnOn => 'Slå på';

  @override
  String get testReminder => 'Skicka en testpåminnelse';

  @override
  String get testReminderSubtitle =>
      'Kommer om ungefär en minut, på samma sätt som riktiga';

  @override
  String get testReminderSent => 'På väg. Lås telefonen och vänta en minut.';

  @override
  String get testReminderTitle => 'Påminnelser fungerar';

  @override
  String get testReminderBody =>
      'Den här kom på samma sätt som familjens påminnelser kommer.';

  @override
  String get requestEvent => 'Be om en händelse';

  @override
  String get waitingForParent => 'Väntar på en förälder';

  @override
  String get approve => 'Godkänn';

  @override
  String get decline => 'Avböj';

  @override
  String get requestSent => 'Skickad till en förälder att godkänna.';

  @override
  String requestFrom(String name) {
    return '$name ber om det här';
  }

  @override
  String get linkedCalendars => 'Länkade kalendrar';

  @override
  String get linkedCalendarsSubtitle =>
      'Lagets och skolans scheman, hämtas automatiskt';

  @override
  String get linkCalendar => 'Länka en kalender';

  @override
  String get calendarLinkUrl => 'Länk';

  @override
  String get calendarLinkUrlHint =>
      'En lagsida på laget.se, webcal:// eller .ics-länk';

  @override
  String get calendarLinkName => 'Namn';

  @override
  String get calendarLinkFor => 'Vems kalender';

  @override
  String get calendarLinkInvalid => 'Det ser inte ut som en kalenderlänk';

  @override
  String calendarFetched(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count händelser uppdaterade',
      one: '1 händelse uppdaterad',
      zero: 'Redan uppdaterad',
    );
    return '$_temp0';
  }

  @override
  String calendarFetchFailed(String error) {
    return 'Kunde inte hämta kalendern.\n$error';
  }

  @override
  String get fetchNow => 'Hämta nu';

  @override
  String get unlinkCalendar => 'Ta bort länken';

  @override
  String unlinkCalendarTitle(String name) {
    return 'Ta bort $name?';
  }

  @override
  String get unlinkCalendarBody =>
      'Kommande händelser från kalendern tas bort. Tidigare ligger kvar.';

  @override
  String get linkedCalendarsEmpty =>
      'Inga kalendrar länkade än. Länka lagets kalender så dyker träningar och matcher upp för barnet, alltid uppdaterade.';

  @override
  String get calendarPrivacyNote =>
      'Hämtas av den här telefonen, inte av Family Planners server, så servern får aldrig veta vilket lag.';

  @override
  String meetAt(String time) {
    return 'Samling $time';
  }

  @override
  String get fromLinkedCalendar => 'Från en länkad kalender';

  @override
  String fromLinkedCalendarNamed(String name) {
    return 'Från $name, uppdateras automatiskt';
  }

  @override
  String reminderLeaveToMeet(String time) {
    return 'Dags att åka · samling $time';
  }

  @override
  String get calendarLinkResponsible => 'Brukar skjutsa';

  @override
  String get calendarLinkNoOne => 'Ingen särskild';

  @override
  String get editCalendarLink => 'Länkad kalender';

  @override
  String get calendarAlreadyLinked => 'Den här kalendern är redan länkad';

  @override
  String get setupWeekTitle => 'Er vanliga vecka';

  @override
  String get setupWeekBody =>
      'Några återkommande saker, så att kalendern från början ser ut som er vecka. Ändra eller ta bort dem när du vill.';

  @override
  String get seedSchool => 'Skola';

  @override
  String get seedPreschool => 'Förskola';

  @override
  String seedBlockFor(String name, String what) {
    return '$name: $what';
  }

  @override
  String seedWeekdays(String from, String to) {
    return 'Vardagar $from–$to';
  }

  @override
  String get seedDinner => 'Middag';

  @override
  String seedEveryDay(String from, String to) {
    return 'Varje dag $from–$to';
  }

  @override
  String get seedActivity => 'Lägg till en aktivitet';

  @override
  String get seedActivitySubtitle => 'Fotboll, simning, musik …';

  @override
  String exportMemberData(String name) {
    return 'Exportera ${name}s data';
  }

  @override
  String exportFailed(String error) {
    return 'Kunde inte exportera.\n$error';
  }

  @override
  String get formerMembers => 'Tidigare medlemmar';

  @override
  String eraseMemberData(String name) {
    return 'Radera ${name}s data';
  }

  @override
  String eraseMemberTitle(String name) {
    return 'Radera ${name}s data?';
  }

  @override
  String get eraseMemberBody =>
      'Namn, färg och åldersgrupp tas bort, och händelser som bara gäller hen raderas. Gemensamma händelser och hens chattmeddelanden ligger kvar, från en tidigare medlem. Exportera först om hen vill ha en kopia. Det går inte att ångra.';

  @override
  String get erase => 'Radera';

  @override
  String memberErased(String name) {
    return '${name}s data är raderad';
  }

  @override
  String get weeklyReview => 'Veckogenomgång';

  @override
  String get weeklyReviewSubtitle =>
      'Veckan som kommer: vem skjutsar, vad krockar';

  @override
  String reviewEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count händelser',
      one: '1 händelse',
      zero: 'Inget planerat',
    );
    return '$_temp0';
  }

  @override
  String get reviewToDecide => 'Att bestämma';

  @override
  String get reviewAllCovered =>
      'Inget att bestämma: alla barnens händelser har någon, och ingen behöver vara på två ställen samtidigt.';

  @override
  String reviewNoOne(String when) {
    return '$when · ingen ansvarig';
  }

  @override
  String reviewClash(String name, String first, String second) {
    return '$name har $first och $second samtidigt';
  }

  @override
  String get reviewResponsible => 'Vem som ansvarar';

  @override
  String get reviewTheWeek => 'Veckan';

  @override
  String reviewPlanCard(int week) {
    return 'Planera vecka $week';
  }

  @override
  String reviewPlanCardBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saker att bestämma.',
      one: '1 sak att bestämma.',
      zero: 'Allt är täckt. Titta igenom tillsammans.',
    );
    return '$_temp0';
  }

  @override
  String get reviewNudgeBody =>
      'Några minuter tillsammans planerar veckan som kommer.';

  @override
  String get shoppingAddHint => 'Lägg till … t.ex. 2 dl grädde';

  @override
  String get shoppingEmpty =>
      'Inget på listan. Lägg till här ovanför, eller ett recepts ingredienser från Recept.';

  @override
  String shoppingBought(int count) {
    return 'Köpt ($count)';
  }

  @override
  String get shoppingClearBought => 'Rensa köpta';

  @override
  String get shoppingNewList => 'Ny lista';

  @override
  String get shoppingListName => 'Listans namn';

  @override
  String get shoppingDefaultList => 'Handla';

  @override
  String get recipes => 'Recept';

  @override
  String shoppingFor(String sources) {
    return 'Till $sources';
  }

  @override
  String get removeItem => 'Ta bort';

  @override
  String get aisleProduce => 'Frukt & grönt';

  @override
  String get aisleBakery => 'Bröd';

  @override
  String get aisleDairy => 'Mejeri & ägg';

  @override
  String get aisleMeat => 'Kött & fisk';

  @override
  String get aisleFrozen => 'Fryst';

  @override
  String get aislePantry => 'Skafferi';

  @override
  String get aisleHousehold => 'Hushåll';

  @override
  String get aisleOther => 'Övrigt';

  @override
  String get recipesEmpty =>
      'Inga recept än. Importera från ICA eller en annan receptsajt, eller skriv ett eget.';

  @override
  String get importRecipe => 'Importera recept';

  @override
  String get newRecipe => 'Nytt recept';

  @override
  String get recipeLink => 'Länk till receptet';

  @override
  String get recipeLinkHint => 'ica.se, koket.se, arla.se …';

  @override
  String recipeFetchFailed(String error) {
    return 'Kunde inte läsa något recept där.\n$error';
  }

  @override
  String get reviewRecipe => 'Kontrollera receptet';

  @override
  String get recipeTitle => 'Namn';

  @override
  String get recipeServings => 'Portioner';

  @override
  String get recipeIngredients => 'Ingredienser, en per rad';

  @override
  String get recipeNotes => 'Egna anteckningar';

  @override
  String get recipeReviewNote =>
      'Kontrollera mängderna innan du sparar: en felaktig hamnar på varje lista som görs av receptet.';

  @override
  String recipeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String addToList(String list) {
    return 'Lägg på $list';
  }

  @override
  String addedToList(String list) {
    return 'Tillagt på $list';
  }

  @override
  String removeFromList(String list) {
    return 'Ta bort från $list';
  }

  @override
  String removedFromList(String list) {
    return 'Borttaget från $list';
  }

  @override
  String get openRecipeSite => 'Öppna receptet';

  @override
  String get deleteRecipe => 'Radera recept';

  @override
  String portionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count portioner',
      one: '1 portion',
    );
    return '$_temp0';
  }

  @override
  String get notOnCatalogue => 'Okänd vara: står kvar som den skrevs';
}
