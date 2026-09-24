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
  String get sharingOngoing => 'Delar var du är med din familj';

  @override
  String hwResponsible(String name) {
    return '$name ser till det';
  }

  @override
  String get hwNobodyResponsible => 'Ingen ser till det';

  @override
  String get hwSetResponsible => 'Vem ser till det?';

  @override
  String pollClosingTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count frågor stänger snart',
      one: 'En fråga stänger snart',
    );
    return '$_temp0';
  }

  @override
  String pollClosingBody(String title, String time) {
    return '$title · stänger $time';
  }

  @override
  String get repeatFrom => 'Upprepas från';

  @override
  String get repeatForever => 'Inget slutdatum';

  @override
  String get repeatForeverHelp => 'Fortsätter tills någon stoppar den';

  @override
  String get repeatUntil => 'Upprepas till';

  @override
  String get repeatEndsBeforeStart =>
      'Slutet ligger före starten, så det här skulle aldrig hända.';

  @override
  String get rewards => 'Belöningar';

  @override
  String get rewardsOn => 'Familjeburk och egna världar';

  @override
  String get rewardsOnHelp =>
      'Klara sysslor och läxor fyller en gemensam burk varje vecka och får varje barns egen värld att växa. Ingen rangordnas.';

  @override
  String get jarSize => 'En full burk är';

  @override
  String jarThings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saker',
      one: '1 sak',
    );
    return '$_temp0';
  }

  @override
  String get jarFor => 'Vad en full burk betyder';

  @override
  String get jarForHint => 'Pizzakväll, vi väljer film…';

  @override
  String get jarTitle => 'Familjeburken';

  @override
  String jarProgress(int filled, int size) {
    return '$filled av $size den här veckan';
  }

  @override
  String get jarFull => 'Burken är full!';

  @override
  String get cityHome => 'Hem';

  @override
  String get cityShop => 'Affär';

  @override
  String get cityPark => 'Park';

  @override
  String get cityRoad => 'Gata';

  @override
  String get cityBuild => 'Vad ska du bygga här?';

  @override
  String get cityShopNeedsSchool => 'Affärer öppnar när staden har en skola';

  @override
  String get cityBuilding => 'Byggs i dag. Du kan fortfarande ändra.';

  @override
  String get cityTakeBack => 'Ångra bygget';

  @override
  String get cityTapToBuild => 'Tryck på en tom tomt för att bygga';

  @override
  String get cityClosed => 'Den här stadsdelen öppnar när du gör mer';

  @override
  String cityWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saker att bygga',
      one: '1 sak att bygga',
    );
    return '$_temp0';
  }

  @override
  String cityStatus(String name, int level) {
    return '$name · stadsdel $level';
  }

  @override
  String get cityHamlet => 'Liten by';

  @override
  String get cityVillage => 'By';

  @override
  String get citySmallTown => 'Småstad';

  @override
  String get cityTown => 'Stad';

  @override
  String get cityCity => 'Storstad';

  @override
  String get cityBigCity => 'Metropol';

  @override
  String get guideCityTitle => 'Så växer din stad';

  @override
  String get guideCityEarn =>
      'Varje syssla du gör klar ger dig något att bygga. Läxor räknas också, när en vuxen har sett att de är klara.';

  @override
  String get guideCityBuild =>
      'Tryck på en tom tomt och välj hem, affär, park eller gata.';

  @override
  String get guideCityToday =>
      'Det du bygger i dag är en byggarbetsplats. Du kan ändra dig fram till i morgon, sedan står det kvar.';

  @override
  String get guideCityGrow =>
      'Hem och parker växer när du fortsätter. Ett hem bredvid en park eller affär kan bli ett höghus, och en park med hem runt sig växer snabbare.';

  @override
  String get guideCityLearn =>
      'Läxor bygger stadens skola, bibliotek, observatorium och universitet. När det finns en skola kan du bygga affärer.';

  @override
  String get guideCityDistricts =>
      'Gör du mer öppnar nya stadsdelar runt kanten. Varje stad har en egen sjö någonstans: bygg runt den.';

  @override
  String get guideCityJar =>
      'När familjeburken är full blir det fyrverkerier över torget, och en fontän dyker upp.';

  @override
  String get guideCityKeep =>
      'Inget du bygger försvinner, inte ens en vecka när du gör mindre.';

  @override
  String get guideGotIt => 'Jag fattar';

  @override
  String get guideHowItWorks => 'Så fungerar det';

  @override
  String get guideParentTitle => 'Familjeburk och egna städer';

  @override
  String get guideParentIntro =>
      'Ett gemensamt mål för veckan, och en stad varje barn bygger själv. Ingen rangordnas eller jämförs.';

  @override
  String get guideParentJar =>
      'Familjeburken: allt som någon gör klart den här veckan fyller den, oavsett vem. Ni väljer hur full den ska vara och vad en full burk betyder. Den töms varje måndag.';

  @override
  String get guideParentCity =>
      'Varje barns stad: varje syssla de gör klar, och varje läxa ni sett att den är klar, ger dem något att bygga. Ni kan titta på ett barns stad, men bara barnet kan bygga i den.';

  @override
  String get guideParentApproval =>
      'En syssla som kräver ert godkännande räknas när ni godkänt den.';

  @override
  String get guideParentSeen =>
      'Läxor räknas för burken så fort de är klara, men får barnets stad att växa först när ni markerat \"Sett att den är klar\" i läxlistan. Så blir det inte ett sätt att vinna att bara kryssa i.';

  @override
  String get guideParentKeep =>
      'Inget ett barn bygger tas någonsin bort, och en lugn vecka kostar ingenting.';

  @override
  String get guideJarBody =>
      'Allt som någon i familjen gör klart den här veckan fyller burken. När den är full blir det det ni bestämt — och fest i varje barns stad. Den börjar om tom varje måndag.';

  @override
  String get guideChildrensCities =>
      'Varje barn bygger sin egen stad av det de gör klart. Här kan ni titta på dem, en i taget.';

  @override
  String get myWorld => 'Min stad';

  @override
  String get myWorldSubtitle => 'Bygg den med det du gör';

  @override
  String get childrensWorlds => 'Barnens städer';

  @override
  String get worldLevelUp => 'Full! Här är en större.';

  @override
  String get worldNothingYet =>
      'Inget att bygga än. Varje syssla och läxa du gör klar ger dig något att bygga.';

  @override
  String worldOf(String name) {
    return '${name}s stad';
  }

  @override
  String get hwSeenIt => 'Sett att den är klar';

  @override
  String hwSeenBy(String name) {
    return 'Sedd av $name';
  }

  @override
  String pollsAwaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count frågor väntar på dig',
      one: '1 fråga väntar på dig',
    );
    return '$_temp0';
  }

  @override
  String get hwDueThatDay => 'Läxor till den dagen';

  @override
  String get summaryTitle => 'Din dag';

  @override
  String get summaryQuiet => 'Inget inplanerat i dag.';

  @override
  String summaryNextAt(String time) {
    return 'nästa $time';
  }

  @override
  String summaryConflicts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count krockar',
      one: '1 krock',
    );
    return '$_temp0';
  }

  @override
  String summaryAway(String names) {
    return '$names borta';
  }

  @override
  String get summaryEveryoneAway => 'Alla är borta';

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

  @override
  String get menu => 'Matsedel';

  @override
  String get addDinner => 'Lägg till middag';

  @override
  String get somethingElse => 'Något annat …';

  @override
  String get mealTitleHint => 'Tacos, rester, pizza ute';

  @override
  String menuToList(String list) {
    return 'Lägg veckan på $list';
  }

  @override
  String menuOnList(String list) {
    return 'Veckans matsedel ligger på $list';
  }

  @override
  String get addSide => 'Lägg till tillbehör';

  @override
  String get whoCooks => 'Vem lagar';

  @override
  String get removeMeal => 'Ta bort från matsedeln';

  @override
  String get searchRecipes => 'Sök recept';

  @override
  String mealCookedBy(String name) {
    return '$name lagar';
  }

  @override
  String get nobodyYet => 'Inte bestämt';

  @override
  String get dinnerTonight => 'Middag ikväll';

  @override
  String get staples => 'Basvaror';

  @override
  String get staplesHint =>
      'Mjölk, bröd, kaffe … det som ska med på varje lista';

  @override
  String get addStaples => 'Lägg till basvaror';

  @override
  String get startWithStaples => 'Börja med basvarorna';

  @override
  String get staplesAdded => 'Basvaror tillagda';

  @override
  String pickOf(String name) {
    return '${name}s val';
  }

  @override
  String picksLeft(String names) {
    return 'Kvar att välja: $names';
  }

  @override
  String get allPicked => 'Alla barn har valt en middag den här veckan';

  @override
  String get yourPickHint =>
      'Välj en middag den här veckan: tryck på en ledig dag';

  @override
  String get whosePick => 'Vems val';

  @override
  String get ideas => 'Idéer & omröstningar';

  @override
  String get suggestMeal => 'Föreslå en rätt';

  @override
  String get suggestions => 'Förslag';

  @override
  String get noSuggestions =>
      'Inga förslag än. Alla kan föreslå en rätt, när som helst.';

  @override
  String suggestedBy(String name) {
    return 'Föreslagen av $name';
  }

  @override
  String get putOnMenu => 'Lägg på matsedeln';

  @override
  String get startPoll => 'Starta en omröstning';

  @override
  String get pollFor => 'Vilken middag';

  @override
  String get pollOptions => 'Välj 2 till 5 alternativ';

  @override
  String pollCloses(String when) {
    return 'Röstningen stänger $when';
  }

  @override
  String pollVoted(String names) {
    return 'Har röstat: $names';
  }

  @override
  String get pollNobodyVoted => 'Ingen har röstat än';

  @override
  String get pollTickHint => 'Kryssa i alla rätter du gärna äter';

  @override
  String get closeNow => 'Stäng nu';

  @override
  String get chooseInstead => 'Välj något annat';

  @override
  String pollWon(String option) {
    return 'Vann: $option';
  }

  @override
  String pollOverridden(String name, String option) {
    return '$name valde detta; omröstningen sa $option';
  }

  @override
  String get pollNoVotes => 'Stängd utan röster';

  @override
  String get polls => 'Omröstningar';

  @override
  String pollChat(String title) {
    return 'Rösta om $title: under Handla › Matsedel › Idéer & omröstningar';
  }

  @override
  String get pickDay => 'Vilken dag';

  @override
  String get dietTitle => 'Mat & allergier';

  @override
  String get dietAllergy => 'Allergi';

  @override
  String get dietIntolerance => 'Intolerans';

  @override
  String get dietDislike => 'Tycker inte om';

  @override
  String get dietDiet => 'Kost';

  @override
  String get dietWhat => 'Vad';

  @override
  String get dietWhatHint => 'nötter, laktos, koriander …';

  @override
  String get dietStrict => 'Strikt: aldrig i en omröstning';

  @override
  String get dietEmpty => 'Inget noterat.';

  @override
  String get dietAdd => 'Lägg till';

  @override
  String dietConflict(String name, String type, String line) {
    return '$name: $type · $line';
  }

  @override
  String dietLeftOut(String meal, String name, String type) {
    return 'Utelämnad: $meal ($name: $type)';
  }

  @override
  String foodAndAllergies(int count) {
    return 'Mat & allergier ($count)';
  }

  @override
  String get cookAgain => 'Laga den här igen';

  @override
  String get todos => 'Att göra';

  @override
  String get todosSubtitle =>
      'Sysslor, förberedelser och ärenden, rättvist fördelade';

  @override
  String get todoMine => 'Mina';

  @override
  String get todoFamily => 'Familjen';

  @override
  String get todoInbox => 'Inkorg';

  @override
  String get newTodo => 'Ny uppgift';

  @override
  String get todoTitle => 'Vad behöver göras';

  @override
  String get todoDue => 'Klart senast';

  @override
  String get todoNoDue => 'Inget datum';

  @override
  String get todoWho => 'Vem';

  @override
  String get todoPool => 'Vem som helst (familjens pool)';

  @override
  String get todoApproval => 'En förälder bekräftar att det är gjort';

  @override
  String get todoBlocking => 'Behövs för att händelsen ska bli av';

  @override
  String get todoDone => 'Klart';

  @override
  String get todoClaim => 'Jag tar den';

  @override
  String get todoUnclaim => 'Lämna tillbaka';

  @override
  String get todoAskSomeone => 'Be någon annan';

  @override
  String get todoSkip => 'Hoppa över den här gången';

  @override
  String get todoAssign => 'Ge till';

  @override
  String get todoApprove => 'Godkänn';

  @override
  String get todoReopen => 'Inte klart än';

  @override
  String get todoAccept => 'Ta den';

  @override
  String get todoDecline => 'Avböj';

  @override
  String get todoNote => 'Kommentar (valfri)';

  @override
  String todoAskedBy(String name) {
    return '$name ber dig ta den här';
  }

  @override
  String todoAwaiting(String name) {
    return 'Gjort av $name, väntar på godkännande';
  }

  @override
  String get todoEmptyMine => 'Inget på din lista.';

  @override
  String get todoEmptyFamily => 'Inget väntar i familjens pool.';

  @override
  String get todoEmptyInbox => 'Inget väntar på dig.';

  @override
  String get todoOverdue => 'Försenad';

  @override
  String todoDueAt(String when) {
    return 'Senast $when';
  }

  @override
  String get todoHistory => 'Vad som hänt';

  @override
  String get histCreated => 'skapade';

  @override
  String get histClaimed => 'tog den';

  @override
  String get histUnclaimed => 'lämnade tillbaka';

  @override
  String histAssigned(String name) {
    return 'gav den till $name';
  }

  @override
  String histDelegated(String name) {
    return 'bad $name';
  }

  @override
  String get histAccepted => 'tog den';

  @override
  String histDeclined(String name) {
    return 'avböjde, tillbaka till $name';
  }

  @override
  String get histDone => 'gjorde den';

  @override
  String get histApproved => 'godkände';

  @override
  String get histReopened => 'öppnade igen';

  @override
  String get histSkipped => 'hoppade över';

  @override
  String get histMoved => 'flyttades med händelsen';

  @override
  String get histCancelled => 'ställdes in med händelsen';

  @override
  String get recurring => 'Återkommande';

  @override
  String get recurringSubtitle => 'Sysslor på schema, med turordning';

  @override
  String get newChore => 'Ny återkommande syssla';

  @override
  String get choreDays => 'Vilka dagar';

  @override
  String get choreTime => 'Klockan';

  @override
  String get choreEvery => 'Varje';

  @override
  String get choreWeekly => 'vecka';

  @override
  String get choreBiweekly => 'varannan vecka';

  @override
  String get choreTurns => 'Vem turas om';

  @override
  String get choreTurnsHint =>
      'Välj en som alltid gör den, eller flera som turas om; ingen lämnar den till vem som helst';

  @override
  String get chorePaused => 'Pausad';

  @override
  String get prep => 'Förberedelser';

  @override
  String get addPrep => 'Lägg till förberedelse';

  @override
  String get prepWhen => 'När';

  @override
  String get prepSameTime => 'Vid starten';

  @override
  String prepHoursBefore(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours timmar före',
      one: '1 timme före',
    );
    return '$_temp0';
  }

  @override
  String prepDaysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dagar före',
      one: 'Dagen före',
    );
    return '$_temp0';
  }

  @override
  String todayTodos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saker att göra',
      one: '1 sak att göra',
    );
    return '$_temp0';
  }

  @override
  String get todayTodosSubtitle => 'Senast i dag eller försenade';

  @override
  String reviewDinnersOpen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count middagar inte planerade',
      one: '1 middag inte planerad',
    );
    return '$_temp0';
  }

  @override
  String reviewUnclaimed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uppgifter som ingen har tagit',
      one: '1 uppgift som ingen har tagit',
    );
    return '$_temp0';
  }

  @override
  String get quickCaptureHint => 'Snabbt: fotboll tisdagar 17:30 på hallen';

  @override
  String get quickCaptureFill => 'Fyll i';

  @override
  String repeatsUntil(String rule, String date) {
    return '$rule, till och med $date';
  }

  @override
  String get celebrations => 'Födelsedagar & högtider';

  @override
  String get celebrationsSubtitle =>
      'Födelsedagar och andra dagar, med presentpåminnelser';

  @override
  String celebrationTurns(String name, int age) {
    return '$name fyller $age';
  }

  @override
  String inDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Om $days dagar',
      one: 'I morgon',
      zero: 'I dag',
    );
    return '$_temp0';
  }

  @override
  String get personName => 'Namn';

  @override
  String get personLabel => 'Vad ni kallar hen';

  @override
  String get personLabelHint => 'Farmor, bonuspappa, Majas kompis';

  @override
  String get personDay => 'Dagen';

  @override
  String get personYearUnknown => 'Året är okänt';

  @override
  String get personType => 'Vilken dag';

  @override
  String get typeBirthday => 'Födelsedag';

  @override
  String get typeNameday => 'Namnsdag';

  @override
  String get typeAnniversary => 'Årsdag';

  @override
  String get typeOther => 'Annat';

  @override
  String get personLead => 'Påminn de vuxna';

  @override
  String personLeadDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dagar före',
      one: '1 dag före',
      zero: 'På dagen',
    );
    return '$_temp0';
  }

  @override
  String get personNotes => 'Presentidéer, storlekar';

  @override
  String get personIsMember => 'I familjen';

  @override
  String get addPerson => 'Lägg till någon';

  @override
  String get noCelebrations => 'Inga dagar att fira än.';

  @override
  String get removePerson => 'Ta bort';

  @override
  String get memberBirthday => 'Födelsedag';

  @override
  String get wishlist => 'Önskelista';

  @override
  String wishlistFor(String name) {
    return '${name}s önskningar';
  }

  @override
  String get wishlistEmpty => 'Inget önskat än.';

  @override
  String get addWish => 'Lägg till en önskan';

  @override
  String get wishTitle => 'Vad';

  @override
  String get wishLink => 'Länk';

  @override
  String get wishNote => 'Anteckning, storlek, färg';

  @override
  String get wishClaim => 'Jag köper den';

  @override
  String get wishUnclaim => 'Jag köper den inte ändå';

  @override
  String wishClaimedBy(String name) {
    return '$name köper den';
  }

  @override
  String get wishReceived => 'Fått';

  @override
  String get newWishlist => 'Börja en ny lista';

  @override
  String get newWishlistBody =>
      'Önskningar som inte blivit av flyttar till den nya listan; den gamla sparas.';

  @override
  String wishlistName(String name, int year) {
    return '$name $year';
  }

  @override
  String get homework => 'Läxor';

  @override
  String get homeworkSubtitle => 'När de ska vara klara, och tid att göra dem';

  @override
  String get homeworkEmpty => 'Inga läxor.';

  @override
  String get addHomework => 'Lägg till läxa';

  @override
  String get hwWho => 'Vems';

  @override
  String get hwSubject => 'Ämne';

  @override
  String get hwNewSubject => 'Nytt ämne …';

  @override
  String get hwSubjectName => 'Ämnets namn';

  @override
  String get hwTitle => 'Vad';

  @override
  String get hwTitleHint => 'Matte s. 42–44';

  @override
  String get hwType => 'Typ';

  @override
  String get hwAssignment => 'Uppgift';

  @override
  String get hwReading => 'Läsning';

  @override
  String get hwTest => 'Prov';

  @override
  String get hwProject => 'Projekt';

  @override
  String get hwHandIn => 'Inlämning';

  @override
  String hwDue(String when) {
    return 'Klar $when';
  }

  @override
  String get hwEveryWeek => 'Varje vecka';

  @override
  String get hwEveryWeekHelp => 'En läxa, en inlämning.';

  @override
  String hwEveryWeekOn(String day) {
    return 'En ny varje $day, som bockas av var för sig.';
  }

  @override
  String get calendarBusy => 'Upptagen';

  @override
  String get phoneCalendars => 'Den här telefonens kalendrar';

  @override
  String get phoneCalendarsSubtitle =>
      'Visa din Google-, Outlook- eller jobbkalender i familjens';

  @override
  String get phoneCalendarsHelp =>
      'Kalendrar som telefonen redan synkar. Inget skickas till Google eller Microsoft: appen läser det som finns på enheten.';

  @override
  String get phoneCalendarsPrivacy =>
      'Bara det du slår på delas, och bara med familjen. Servern kan inte läsa något av det.';

  @override
  String get phoneCalendarsDenied =>
      'Appen har inte tillåtelse att läsa telefonens kalendrar. Ge den det i Inställningar och kom tillbaka.';

  @override
  String get phoneCalendarsNone => 'Inga kalendrar på den här telefonen.';

  @override
  String get phoneCalendarBusy => 'Bara upptagen';

  @override
  String get phoneCalendarFull => 'Alla detaljer';

  @override
  String get dictationStart => 'Säg det högt';

  @override
  String get dictationStop => 'Sluta lyssna';

  @override
  String get dictationUnavailable =>
      'Telefonen kan inte lyssna. Kolla mikrofonrättigheten i Inställningar.';

  @override
  String get weekLetter => 'Veckobrev';

  @override
  String get weekLetterHelp =>
      'Dela lärarens brev till appen, eller klistra in det här. Inget sparas förrän du säger till.';

  @override
  String get weekLetterPaste => 'Klistra in brevets text';

  @override
  String get weekLetterRead => 'Hitta läxorna';

  @override
  String get weekLetterNothing =>
      'Inget här ser ut som en läxa. Lägg in den för hand om den borde finnas.';

  @override
  String get weekLetterNoDate => 'Inget datum angivet';

  @override
  String get weekLetterUnreadable =>
      'Filen gick inte att läsa. Öppna den och klistra in texten i stället.';

  @override
  String get hwWhose => 'Vems läxa';

  @override
  String weekLetterSave(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Spara $count',
      one: 'Spara 1',
    );
    return '$_temp0';
  }

  @override
  String get weekLetterPhoto => 'Fotografera';

  @override
  String get importRecipeFromPlanning =>
      'Klistra in en länk så hamnar den direkt på den här måltiden';

  @override
  String noRecipesFound(String query) {
    return 'Inget sparat recept matchar ”$query”.';
  }

  @override
  String get sendToShop => 'Skicka listan';

  @override
  String get unbindThisDevice => 'Ta bort den här enheten';

  @override
  String get unbindThisDeviceExplain =>
      'Telefonen lämnar familjen: nycklarna glöms och allt som sparats här raderas. Familjen behåller allt. För att använda den igen får du parkoppla den från en enhet som fortfarande är med. Det som skrivits här och inte hunnit synkas försvinner.';

  @override
  String get unbindConfirm => 'Lämna familjen';

  @override
  String get clearList => 'Töm listan';

  @override
  String get clearTicked => 'Rensa det som är bockat';

  @override
  String get clearEverything => 'Rensa allt';

  @override
  String get clearEverythingExplain =>
      'Allt tas bort från listan, bockat eller inte. Själva listan blir kvar, och det som rensats kan hämtas tillbaka från Nyligen borttaget.';

  @override
  String clearedItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saker rensade',
      one: '1 sak rensad',
    );
    return '$_temp0';
  }

  @override
  String get weekLetterLinkShared => 'Länken kräver skolinloggning';

  @override
  String get weekLetterLinkSharedHelp =>
      'Appen kan inte öppna en länk till SharePoint eller Google Dokument. Öppna dokumentet i Word, Teams eller OneDrive och dela själva dokumentet — eller kopiera in texten i rutan nedan.';

  @override
  String get whichClass => 'Vilken klass';

  @override
  String get weekPlanRemember => 'Spara till nästa vecka';

  @override
  String get weekPlanRemembered => 'Sparad — hämta den från Läxor varje vecka';

  @override
  String get weekPlanCheck => 'Veckans skolplanering';

  @override
  String get weekPlanNone =>
      'Ingen skolplanering sparad. Dela en från Word eller Teams, klistra in texten, eller fotografera tavlan.';

  @override
  String get weekLetterPasteOrLink =>
      'Klistra in brevets text, eller en länk till det';

  @override
  String get schoolPlans => 'Skolans veckoplanering';

  @override
  String get schoolPlansSubtitle => 'Läxor från skolans egna veckodokument';

  @override
  String get schoolPlansHelp =>
      'Ställ in en gång per barn: adressen till skolans veckoplanering och vilken klass som är deras. Sedan kommer läxorna in med allt annat. Dokumentet hämtas av den här telefonen — servern ser aldrig skolans adress.';

  @override
  String get schoolPlansEmpty =>
      'Ingen skolplanering än. Lägg till en om skolan publicerar ett veckodokument; annars kan läxor fortfarande delas, klistras in eller fotograferas in i appen.';

  @override
  String get schoolPlanAdd => 'Lägg till skolplanering';

  @override
  String get schoolPlanUrl => 'Länk till veckoplaneringen';

  @override
  String get schoolPlanUrlHint =>
      'Klistra in adressen från Teams, Word eller skolans sida';

  @override
  String get schoolPlanNoClass => 'Ingen klass vald ännu — inget hämtas';

  @override
  String get schoolPlanFetchNow => 'Hämta nu';

  @override
  String get schoolPlanUnreadable =>
      'Dokumentet gick inte att läsa. Kolla att länken öppnas för dig i en webbläsare.';

  @override
  String schoolPlanAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nya läxor',
      one: '1 ny läxa',
      zero: 'Inget nytt',
    );
    return '$_temp0';
  }

  @override
  String get hwEstimate => 'Ungefär hur länge';

  @override
  String hwMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get hwOverdue => 'Försenad';

  @override
  String get hwStarted => 'Påbörjad';

  @override
  String get hwDone => 'Klar';

  @override
  String get hwHandedIn => 'Inlämnad';

  @override
  String get hwNotStarted => 'Inte påbörjad';

  @override
  String get hwPlan => 'Hitta en tid';

  @override
  String get hwPlanHint =>
      'Lediga tider innan den ska vara klar, runt allt annat. Välj en, eller hoppa över.';

  @override
  String get hwNoSlots => 'Ingen ledig tid innan den ska vara klar.';

  @override
  String hwSessions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pass planerade',
      one: '1 pass planerat',
    );
    return '$_temp0';
  }

  @override
  String get hwSkip => 'Inte nu';

  @override
  String hwStrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Läxor: $count snart',
      one: 'Läxor: 1 snart',
    );
    return '$_temp0';
  }

  @override
  String get away => 'Borta & lov';

  @override
  String get awaySubtitle => 'Semester, resor och lov pausar det de gäller';

  @override
  String get addAway => 'Lägg till bortatid';

  @override
  String get addBreak => 'Lägg till ett lov';

  @override
  String get awayTitle => 'Vad';

  @override
  String get awayTitleHint => 'Höstlov, Fjällen, Farmor';

  @override
  String get awayDates => 'Vilka dagar';

  @override
  String get awayWho => 'Vem är borta';

  @override
  String get awayWhoHint => 'Ingen vald är hela familjen';

  @override
  String get awayPauses => 'Pausar';

  @override
  String get kindActivities => 'Aktiviteter';

  @override
  String get kindRoutines => 'Rutiner (skola, middag)';

  @override
  String get kindHomework => 'Läxor';

  @override
  String get kindAppointments => 'Bokade tider';

  @override
  String get awaySilence => 'Inga påminnelser till de som är borta';

  @override
  String get awayEmpty => 'Inget inplanerat.';

  @override
  String awayBand(String title, String who) {
    return '$title · $who';
  }

  @override
  String get awayEveryone => 'alla';

  @override
  String awayRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get search => 'Sök';

  @override
  String get searchHint => 'Händelser, recept, uppgifter, personer …';

  @override
  String get searchNothing => 'Inget hittades.';

  @override
  String get searchEvents => 'Kalender';

  @override
  String get searchTodos => 'Att göra';

  @override
  String get searchHomework => 'Läxor';

  @override
  String get searchPeople => 'Personer';

  @override
  String get kit => 'Att ta med';

  @override
  String get addKit => 'Lägg till packlista';

  @override
  String get newKit => 'Ny packlista';

  @override
  String get kitName => 'Namn';

  @override
  String get kitNameHint => 'Fotbollsväska, Simpåse';

  @override
  String get kitItems => 'Saker, en per rad';

  @override
  String get kitNeedsReplacing => 'Behöver bytas';

  @override
  String kitToShopping(String item, String list) {
    return '$item ligger på $list';
  }

  @override
  String bring(String items) {
    return 'Ta med: $items';
  }

  @override
  String get canI => 'Får jag …?';

  @override
  String get canIHint => 'Får jag sova över hos Elsa på fredag?';

  @override
  String get askParents => 'Fråga';

  @override
  String asks(String name) {
    return '$name frågar';
  }

  @override
  String get yes => 'Ja';

  @override
  String get no => 'Nej';

  @override
  String get answerNote => 'Några ord (valfritt)';

  @override
  String get waitingForAnswer => 'Väntar på svar';

  @override
  String answeredYes(String name) {
    return 'Ja från $name';
  }

  @override
  String answeredNo(String name) {
    return 'Nej från $name';
  }

  @override
  String pollOpened(String title) {
    return 'Ny omröstning: $title';
  }

  @override
  String pollAnswerBy(String time) {
    return 'Svara senast $time';
  }

  @override
  String get pollAnswerSoon => 'Ditt svar behövs';

  @override
  String get pollOpenedBody => 'Kryssa i alla middagar du gärna äter';

  @override
  String get addPhoto => 'Lägg till foto';

  @override
  String get takePhoto => 'Ta ett foto';

  @override
  String get choosePhoto => 'Välj ett foto';

  @override
  String get photos => 'Foton';

  @override
  String get removePhoto => 'Ta bort foto';

  @override
  String get forCoParent => 'En förälder i det andra hemmet';

  @override
  String get forCoParentSubtitle =>
      'Ser och ändrar bara de barn ni delar, och deras växelvisa boende';

  @override
  String get coParentsName => 'Namn';

  @override
  String get coParentChildren => 'Vilka barn ni delar';

  @override
  String get roleCoParent => 'Förälder i andra hemmet';

  @override
  String get custody => 'Två hem';

  @override
  String get custodySubtitle => 'Växelvis boende och byten';

  @override
  String custodyFor(String name) {
    return '${name}s två hem';
  }

  @override
  String get custodyNone => 'Inget schema för växelvis boende.';

  @override
  String get custodyAdd => 'Lägg till schema';

  @override
  String get custodyPattern => 'Hur det växlar';

  @override
  String get custodyWeeks => 'Varannan vecka';

  @override
  String get custodyWeekends => 'Varannan helg';

  @override
  String get custodyChangeover => 'Ett byte';

  @override
  String custodyChangeoverWeeksHint(String name) {
    return 'När $name kommer hit';
  }

  @override
  String custodyChangeoverWeekendsHint(String name) {
    return 'När $name åker till andra hemmet en fredag';
  }

  @override
  String get custodyCoParent => 'Det andra hemmet';

  @override
  String get custodyNoCoParent => 'Använder inte appen';

  @override
  String custodyToUs(String name) {
    return '$name till oss';
  }

  @override
  String custodyToThem(String name, String other) {
    return '$name till $other';
  }

  @override
  String get custodyOtherHome => 'andra hemmet';

  @override
  String get custodySwap => 'Lägg till ett byte av dagar';

  @override
  String get custodySwapHere => 'Hos oss';

  @override
  String get custodySwapThere => 'I andra hemmet';

  @override
  String custodyAway(String name, String other) {
    return '$name är hos $other';
  }

  @override
  String custodyBackAt(String when) {
    return 'tillbaka $when';
  }

  @override
  String get removeCustody => 'Ta bort schemat';

  @override
  String nameList(String rest, String last) {
    return '$rest och $last';
  }

  @override
  String get newConversation => 'Nytt meddelande';

  @override
  String get you => 'Du';

  @override
  String get noMessagesYet => 'Inga meddelanden än';

  @override
  String get readersChanged => 'Vem som kan läsa ändrades';

  @override
  String get nobodyReachable =>
      'Ingen där går att nå än: deras enhet har inte varit uppkopplad sedan den lades till.';

  @override
  String get noDevice => 'Ingen egen enhet';

  @override
  String get groupName => 'Gruppnamn (valfritt)';

  @override
  String get startConversation => 'Starta';

  @override
  String alsoReadBy(String names) {
    return '$names kan också läsa det här, eftersom familjens inställningar gör att barnens meddelanden kan läsas av föräldrarna.';
  }

  @override
  String get onlyParticipants => 'Bara de som är med i samtalet kan läsa det.';

  @override
  String get chatJoining =>
      'Samtalet förbereds. Det öppnas när din enhet har lagts till.';

  @override
  String get chatEmptyPrivate =>
      'Säg något. Krypterat hela vägen: inte ens servern kan läsa det.';

  @override
  String get readersNowOnly =>
      'Från och med nu kan bara de som är med i samtalet läsa nya meddelanden.';

  @override
  String readersNowAlso(String names) {
    return 'Från och med nu kan även $names läsa nya meddelanden. Inget från tidigare.';
  }

  @override
  String get messageSupervision => 'Barnens meddelanden';

  @override
  String get supervisionOff => 'Privata';

  @override
  String get supervisionLittle => 'Föräldrar läser de minstas';

  @override
  String get supervisionKid => 'Föräldrar läser upp till 12 år';

  @override
  String get supervisionAll => 'Föräldrar läser alla barns';

  @override
  String get supervisionChange =>
      'Föräldrarna läggs till i eller tas bort från de berörda samtalen, och varje samtal visar det. Det gäller bara meddelanden från ändringen och framåt; ingen får tillbaka det som kom före, och det som redan lästs förblir läst.';

  @override
  String get messageSupervisionHelp =>
      'Barn som omfattas har privata samtal och gruppsamtal som föräldrarna kan läsa, och det står i samtalet. Familjetråden är alltid allas.';

  @override
  String get familyMap => 'Familjekarta';

  @override
  String get familyMapSubtitle => 'Vem som är var, om de delar det';

  @override
  String get checkInHere => 'Jag är här';

  @override
  String get checkInPickUp => 'Kom och hämta mig';

  @override
  String get checkInSent => 'Skickat i familjetråden';

  @override
  String get stoppedSharing => 'Slutade dela';

  @override
  String get notSharing => 'Delar inte';

  @override
  String get noPositionYet => 'Delar, ingen position än';

  @override
  String get sharingPaused => 'Pausad';

  @override
  String pausedUntil(String time) {
    return 'Pausad till $time';
  }

  @override
  String atPlaceSince(String place, String time) {
    return 'På $place sedan $time';
  }

  @override
  String get notAtAPlace => 'Inte på en känd plats';

  @override
  String get roughlyHere => 'Ungefär här';

  @override
  String get seenNow => 'nu';

  @override
  String seenAt(String time) {
    return 'sedd $time';
  }

  @override
  String get yourSharing => 'Din position';

  @override
  String get mapPrivacy =>
      'Positioner krypteras på telefonen som delar dem; servern kan inte läsa dem och sparar bara den senaste, inga spår.';

  @override
  String get shareWhileUsing => 'Dela medan jag använder appen';

  @override
  String get shareWhileUsingHelp => 'Av: ingen ser var du är.';

  @override
  String get parentAskedToShare =>
      'En förälder har bett dig dela medan du använder appen.';

  @override
  String get nobodySeesYou => 'Ingen ser dig än.';

  @override
  String whoSeesYou(String names) {
    return '$names kan se dig.';
  }

  @override
  String get locationDenied =>
      'Platsen är inte tillgänglig: tillåt den för Family Planner i telefonens inställningar.';

  @override
  String get shareWithParents => 'Föräldrar';

  @override
  String get shareWithFamily => 'Hela familjen';

  @override
  String get precisionExact => 'Exakt';

  @override
  String get precisionApproximate => 'Ungefär 1 km';

  @override
  String get precisionPlace => 'Bara plats';

  @override
  String get resumeSharing => 'Dela igen';

  @override
  String get pauseHour => 'Pausa en timme';

  @override
  String get pauseVisible => 'De som ser dig ser att det är pausat.';

  @override
  String get askToShare => 'Be om delning medan appen används';

  @override
  String get stopAskingToShare => 'Sluta be om delning';

  @override
  String get placeSpotUnset => 'Markera var det är: tryck när du är där';

  @override
  String get placeSpotSet => 'Markerat var det är';

  @override
  String get placeSpotHelp => 'För \"på skolan sedan 08:12\" på kartan.';

  @override
  String get clear => 'Rensa';

  @override
  String get placeRadius => 'Räknas som där inom';

  @override
  String metres(int count) {
    return '$count m';
  }

  @override
  String get forKitchen => 'En köksskärm';

  @override
  String get forKitchenSubtitle =>
      'En platta på väggen: veckan, kvällens middag och inköpslistan. Ingen chatt, inga påminnelser.';

  @override
  String get kitchenToday => 'Idag';

  @override
  String get kitchenDinner => 'Middag';

  @override
  String get kitchenNothingOn => 'Inget inplanerat idag.';

  @override
  String get kitchenNoDinner => 'Ingen middag planerad';

  @override
  String get kitchenListEmpty => 'Inget på listan.';

  @override
  String get emoji => 'Emoji';

  @override
  String get mapEveryone => 'Alla';

  @override
  String get mapTilesGoogle =>
      'Kartbilderna kommer från Google Maps, som ser ungefär vilket område du tittar på.';

  @override
  String get mapTilesOsm =>
      'Kartbilderna kommer från OpenStreetMap, som ser ungefär vilket område du tittar på.';

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
      'Prognosen där den här telefonen är, på ungefär en kilometer när';

  @override
  String get passwords => 'Lösenord';

  @override
  String get passwordAdd => 'Lägg till lösenord';

  @override
  String get passwordsEmpty =>
      'Inget sparat än. Wifit, ett strömningskonto, bibliotekskortet — det familjen behöver leta reda på igen.';

  @override
  String get passwordsFamily => 'Familjens';

  @override
  String get passwordsMine => 'Mina';

  @override
  String get passwordsHelp =>
      'Varje lösenord krypteras för dem det gäller: familjens når allas egna enheter, dina bara dina. Köksskärmen har inga av dem.';

  @override
  String get passwordHidden => 'Dolt';

  @override
  String get passwordShow => 'Visa';

  @override
  String get passwordHide => 'Dölj';

  @override
  String get passwordCopy => 'Kopiera';

  @override
  String get passwordCopied => 'Kopierat. Urklipp töms strax.';

  @override
  String get passwordUnlockReason =>
      'Bekräfta att det är du innan ett lösenord visas';

  @override
  String get passwordKeysFailed =>
      'Den här enheten har inte nyckeln än. Försök igen när den har synkat.';

  @override
  String get passwordTitle => 'Vad det gäller';

  @override
  String get passwordUsername => 'Användarnamn (valfritt)';

  @override
  String get passwordSecret => 'Lösenord';

  @override
  String get passwordUrl => 'Länk (valfritt)';

  @override
  String get passwordNote => 'Anteckning (valfritt)';

  @override
  String get passwordGenerate => 'Hitta på ett';

  @override
  String get passwordNeedsBoth => 'Det behöver ett namn och ett lösenord.';

  @override
  String get passwordScopeFamily => 'Alla i familjen kan se det här.';

  @override
  String get passwordScopeMine => 'Bara dina egna enheter kan öppna det här.';

  @override
  String get passwordsSubtitle => 'Wifit, konton, det som behöver letas fram';

  @override
  String get openLink => 'Öppna';

  @override
  String get passwordSaveFailed =>
      'Kunde inte spara. Det ligger kvar på den här enheten tills det synkar.';

  @override
  String get serverOwn => 'Använd en egen server';

  @override
  String get serverTitle => 'Er egen server';

  @override
  String get serverHelp =>
      'Appen pratar med en server, som bara har krypterad data den inte kan läsa. Om familjen kör en egen: skriv adressen här, innan ni startar eller går med i en familj — en enhet hör ihop med servern den parades mot.';

  @override
  String get serverAddress => 'Adress';

  @override
  String get serverAddressHint => 'familj.exempel.se';

  @override
  String get serverCheck => 'Kontrollera och använd';

  @override
  String get serverStandard => 'Använd standardservern';

  @override
  String get serverBadAddress =>
      'Det kan inte vara en serveradress. Den behöver ett värdnamn, och https om den inte finns i ert eget nätverk.';

  @override
  String serverNoAnswer(String host) {
    return 'Inget svarade på $host.';
  }

  @override
  String serverUsing(String host) {
    return 'Server: $host';
  }

  @override
  String get premium => 'Premium';

  @override
  String get premiumSubtitle => 'Vad familjens prenumeration ger';

  @override
  String get premiumHeadline => 'Låt appen springa ärendena';

  @override
  String get premiumFreeStays =>
      'Den gemensamma kalendern, påminnelser, inköpslistor, uppgifter och chatt är gratis, för alla i familjen, på alla enheter.';

  @override
  String get premiumIntegrations =>
      'Veckobrev från skolan, kalenderflöden och läxor lästa ur ett brev eller ett foto av tavlan — hämtas av sig själva.';

  @override
  String get premiumMap => 'Familjekartan, och att dela var du är.';

  @override
  String get premiumFood =>
      'Recept, veckans meny, middagsomröstningar och varningar för kost.';

  @override
  String get premiumPasswords =>
      'Sparade lösenord, för familjen eller bara för dig.';

  @override
  String get premiumKitchen => 'Kökstavlan för en surfplatta på väggen.';

  @override
  String get premiumTwoHomes =>
      'Två hem: konto för medförälder, växelveckor och tillfällig åtkomst för barnvakten.';

  @override
  String get premiumPhotos => 'Plats för foton — 2 GB i stället för 200 MB.';

  @override
  String get premiumRenews =>
      'Betalningen sker via App Store eller Google Play. Prenumerationen förnyas automatiskt varje period tills du säger upp den, vilket du gör i ditt butikskonto. En prenumeration gäller hela familjen.';

  @override
  String get premiumRestore => 'Återställ ett köp';

  @override
  String get premiumManage => 'Hantera prenumeration';

  @override
  String get premiumActive => 'Premium är på';

  @override
  String premiumUntil(String date) {
    return 'Gäller till $date.';
  }

  @override
  String get premiumGranted => 'Given, inte köpt — ingen betalar för den här.';

  @override
  String get premiumThanks => 'Tack. Premium gäller för hela familjen.';

  @override
  String get premiumOnItsWay =>
      'Betalt. Det kan ta en stund innan det når era enheter — inget mer att göra.';

  @override
  String get premiumNothingToRestore =>
      'Hittade ingen prenumeration på det butikskontot.';

  @override
  String get premiumUnavailable => 'Det går inte att köpa i den här versionen.';

  @override
  String get premiumNoOffers =>
      'Inget att köpa just nu. Försök igen om en stund.';

  @override
  String get premiumFailed => 'Det gick inte igenom. Inget har debiterats.';

  @override
  String get privacyPolicy => 'Integritetspolicy';

  @override
  String get termsOfUse => 'Användarvillkor';

  @override
  String premiumBillingId(String id) {
    return 'Konto $id';
  }

  @override
  String get premiumPerMonth => 'per månad';

  @override
  String get premiumPerYear => 'per år';

  @override
  String get premiumPerWeek => 'per vecka';

  @override
  String get premiumFreeFirst => 'Gratis att prova först';

  @override
  String get icaTitle => 'Skicka till ICA';

  @override
  String get icaSubtitle => 'Lägg listan i ICA:s egen, för handscannern';

  @override
  String get icaHelp =>
      'ICA:s inköpslista synkas med handscannerna i butiken. Det här skickar det som fortfarande behövs på familjens lista till en av dina, så att den finns där när du tar en scanner.';

  @override
  String get icaCaveats =>
      'Ställs in bara på den här telefonen — att logga in här når ingen annans enhet, och de kan göra samma sak med sitt eget konto. Den lägger bara till i ICA:s lista och bockar av det ni har köpt; det du själv skrivit in i ICA:s app lämnas i fred. Den slutar fungera utanför Sverige, och ICA kan ändra eller stänga det här utan förvarning. ”Skicka listan” fungerar ändå.';

  @override
  String get icaConnect => 'Logga in på ICA';

  @override
  String get icaSignIn => 'ICA';

  @override
  String get icaSignInNote =>
      'Det här är ICA:s egen inloggningssida. Det du skriver går till ICA, inte till den här appen — den ser aldrig ditt personnummer eller lösenord, bara tillåtelse att använda din inköpslista.';

  @override
  String get icaSignInFailed => 'Inloggningen blev inte klar. Inget sparades.';

  @override
  String get icaUnavailable => 'Den här versionen kan inte ansluta till ICA.';

  @override
  String get icaWhichList => 'Vilken ICA-lista';

  @override
  String get icaNoLists =>
      'Inga listor på det kontot än. Skapa en i ICA:s app först.';

  @override
  String icaRowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count varor',
      one: '1 vara',
      zero: 'tom',
    );
    return '$_temp0';
  }

  @override
  String get icaSend => 'Skicka det som behövs';

  @override
  String icaSent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ändringar skickade',
      one: '1 ändring skickad',
      zero: 'Redan aktuell',
    );
    return '$_temp0';
  }

  @override
  String get icaSendFailed => 'Kunde inte nå ICA. Inget ändrades.';

  @override
  String get icaDisconnect => 'Koppla från';

  @override
  String get icaDisconnectNote =>
      'Den här telefonen glömmer din ICA-inloggning. Din ICA-lista står kvar som den är och inget tas bort. Vill du dra tillbaka åtkomsten helt gör du det i ditt ICA-konto.';

  @override
  String get editChore => 'Ändra syssla';

  @override
  String get guideSkip => 'Hoppa över';

  @override
  String get guideStart => 'Börja använda appen';

  @override
  String get guideLater => 'Senare';

  @override
  String get guideWeekTitle => 'Allas vecka, på ett ställe';

  @override
  String get guideWeekBody =>
      'Idag visar det som händer nu. Veckan visar allas — vem som ska vart, vem som kör, vad som ska packas. Lägg till med +-knappen; den det gäller ser det på sin egen telefon.';

  @override
  String get guideTalkTitle => 'Fråga, bestäm, få gjort';

  @override
  String get guideTalkBodyParent =>
      'Familjetråden är för alla, och du kan skriva till en person. Barnen kan fråga om lov med ”Får jag…?” och du får det som en notis. Inköpslistor, mat och sysslor har egna flikar.';

  @override
  String get guideTalkBodyChild =>
      'Du kan skriva till hela familjen eller till en person. Vill du fråga om något — sova över, gå hem till en kompis — använd ”Får jag…?” på Idag, så får en vuxen det direkt. Du kan säga det högt i stället för att skriva.';

  @override
  String get guidePrivacyTitle => 'Bara din familj kan läsa det';

  @override
  String get guidePrivacyBody =>
      'Allt låses på den här telefonen innan det skickas, och låses upp bara på familjens telefoner. Servern som bär det kan inte läsa något av det — varken kalendern, meddelandena eller var någon är.';

  @override
  String get guideKeyTitle => 'Tolv ord, på ett säkert ställe';

  @override
  String get guideKeyBody =>
      'Eftersom ingen annan kan läsa familjens data kan ingen annan hämta tillbaka den heller. Tolv ord är enda vägen in om alla telefoner försvinner samtidigt. Det tar en minut, och är det enda som är värt att inte skjuta upp.';

  @override
  String get guideKeyAction => 'Hämta mina tolv ord';

  @override
  String get guideReadyTitle => 'Det var allt';

  @override
  String get guideReadyBody =>
      'Titta dig omkring. Det du lägger till dyker upp hos resten av familjen av sig självt.';

  @override
  String hwStripMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count till',
      one: '1 till',
    );
    return '$_temp0';
  }

  @override
  String get shareAlways => 'Även när appen är stängd';

  @override
  String get shareAlwaysHelp =>
      'Just nu ser familjen var du är bara när appen är öppen.';

  @override
  String get shareAlwaysOn =>
      'Familjen kan se var du är även när appen är stängd. Telefonen visar det hela tiden det pågår.';

  @override
  String get shareAlwaysParentSet =>
      'En förälder har satt på det här, så familjen kan se var du är även när appen är stängd. Du kan inte stänga av det här.';

  @override
  String get shareAlwaysDenied =>
      'Telefonen tillät det inte. Leta efter ”Alltid” under Plats för den här appen i Inställningar.';

  @override
  String get tomorrow => 'I morgon';

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dagar',
      one: '1 dag',
    );
    return '$_temp0';
  }

  @override
  String fieldEndsLabel(String length) {
    return 'Slutar · $length';
  }

  @override
  String removeManyTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ta bort $count händelser?',
      one: 'Ta bort 1 händelse?',
    );
    return '$_temp0';
  }

  @override
  String get removeManyBody =>
      'De hamnar i Nyligen borttagna, där du kan lägga tillbaka dem.';

  @override
  String removeManyBodyRepeating(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count av dem upprepas: bara dagarna du valde tas bort, inte hela serien.',
      one:
          'En av dem upprepas: bara dagen du valde tas bort, inte hela serien.',
    );
    return '$_temp0';
  }

  @override
  String removedMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count händelser borttagna',
      one: '1 händelse borttagen',
    );
    return '$_temp0';
  }

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valda',
      one: '1 vald',
    );
    return '$_temp0';
  }

  @override
  String removeManyNotYours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count var inte dina att ta bort',
      one: '1 var inte din att ta bort',
    );
    return '$_temp0';
  }

  @override
  String get moreGroupWeek => 'Veckan';

  @override
  String get moreGroupPeople => 'Personer';

  @override
  String get moreGroupPlaces => 'Platser';

  @override
  String get moreGroupIntegrations => 'Hämtat någon annanstans ifrån';

  @override
  String get moreGroupDevices => 'Enheter';

  @override
  String get moreGroupSettings => 'Inställningar';

  @override
  String get wishlists => 'Önskelistor';

  @override
  String get wishlistsSubtitle =>
      'Vad var och en önskar sig, och vem som fixar det';

  @override
  String get wishlistsHelp =>
      'Var och en har sin egen lista. När du öppnar någon annans kan du säga att du tar en sak, och hen ser aldrig att den är tagen — så listan förblir en överraskning medan ni andra reder ut vem som köper vad.';

  @override
  String wishlistMine(String name) {
    return '$name · din';
  }

  @override
  String get wishlistMineHint =>
      'Lägg till det du önskar dig. Du ser inte vem som tagit något.';

  @override
  String get wishlistTheirsHint =>
      'Se vad hen önskar sig, och säg om du fixar det';

  @override
  String pollClosed(String title) {
    return 'Resultat: $title';
  }

  @override
  String get pollClosedNoWinner => 'Ingen röstade, så inget valdes.';

  @override
  String get todoForYou => 'En syssla till dig';

  @override
  String todoDueBy(String date) {
    return 'till $date';
  }

  @override
  String get pollsSubtitle => 'Fråga alla och låt svaren avgöra';

  @override
  String get pollsHelp =>
      'Fråga familjen vad som helst och ge dem alternativen. Alla bockar för allt de kan tänka sig, inte bara ett — så svaret blir det flest kan leva med. När den stänger får alla resultatet.';

  @override
  String get pollsEmpty => 'Inget som ska avgöras just nu.';

  @override
  String get pollAsk => 'Fråga familjen';

  @override
  String get pollAskIt => 'Fråga';

  @override
  String get pollQuestion => 'Vad vill du fråga?';

  @override
  String get pollQuestionHint => 'Vilken helg åker vi till stugan?';

  @override
  String pollOptionNumber(int number) {
    return 'Alternativ $number';
  }

  @override
  String get pollAddOption => 'Ett alternativ till';

  @override
  String get pollIsClosed => 'Stängd';

  @override
  String pollVotedSoFar(int voted, int total) {
    return '$voted av $total har svarat';
  }

  @override
  String get withdrawMessage => 'Ta tillbaka';

  @override
  String get withdrawExplain =>
      'Orden försvinner från allas telefoner, och tråden säger att ett meddelande togs tillbaka. Den som redan läst det har redan läst det.';

  @override
  String get withdrawIt => 'Ta tillbaka';

  @override
  String get withdrawnHere => 'Meddelande borttaget';

  @override
  String inboxHomeworkDone(String name, String title) {
    return '$name är klar med $title';
  }

  @override
  String inboxChoreDone(String name, String title) {
    return '$name har gjort $title';
  }

  @override
  String inboxApproval(String name, String title) {
    return '$name har gjort $title: godkänn?';
  }

  @override
  String inboxAsked(String name, String title) {
    return '$name ber dig: $title';
  }

  @override
  String inboxPoll(String title) {
    return 'Svara: $title';
  }

  @override
  String inboxChat(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count olästa meddelanden',
      one: '1 oläst meddelande',
    );
    return '$_temp0';
  }

  @override
  String get inboxSeen => 'Sett';

  @override
  String inboxSeeAll(int count) {
    return 'Visa alla ($count)';
  }

  @override
  String get inboxNothing => 'Inget väntar på dig.';

  @override
  String get histSeen => 'såg att den var klar';

  @override
  String get showOnMap => 'Visa på kartan';

  @override
  String get cityMarket => 'Handelshus';

  @override
  String get cityMarketLocked => 'Öppnar med nästa stadsdel';

  @override
  String cityMarketMakes(String good) {
    return 'Ditt handelshus gör $good';
  }

  @override
  String get cityLandmarks => 'Specialbyggnader';

  @override
  String get landmarkHarbour => 'Hamn';

  @override
  String get landmarkCastle => 'Slott';

  @override
  String get landmarkZoo => 'Djurpark';

  @override
  String get landmarkStadium => 'Arena';

  @override
  String get landmarkBakery => 'Bageri';

  @override
  String get landmarkBuilt => 'Finns redan i din stad';

  @override
  String get landmarkShore => 'Måste stå vid sjön';

  @override
  String landmarkNeeds(String cost) {
    return 'Kräver $cost';
  }

  @override
  String get goodFish => 'fisk';

  @override
  String get goodWood => 'trä';

  @override
  String get goodStone => 'sten';

  @override
  String get goodWool => 'ull';

  @override
  String get goodHoney => 'honung';

  @override
  String get trade => 'Byt';

  @override
  String get tradeYourGoods => 'Dina varor';

  @override
  String get tradeNoGoods =>
      'Inget än: ditt handelshus gör en vara för varannan sak du gör.';

  @override
  String get tradeOffersToYou => 'Erbjudanden till dig';

  @override
  String tradeOfferLine(String name, String give, String get) {
    return '$name erbjuder $give för dina $get';
  }

  @override
  String get tradeYourOffers => 'Dina erbjudanden';

  @override
  String tradeYourOfferLine(String name, String give, String get) {
    return 'Du erbjöd $name $give för $get';
  }

  @override
  String get tradeAccept => 'Byt';

  @override
  String get tradeDecline => 'Nej tack';

  @override
  String get tradeWithdraw => 'Ta tillbaka';

  @override
  String get tradeNew => 'Nytt byte';

  @override
  String get tradeWith => 'Byt med';

  @override
  String get tradeGive => 'Du ger';

  @override
  String get tradeGet => 'Du får';

  @override
  String get tradeEven => 'Alltid lika många åt båda hållen.';

  @override
  String get tradeSend => 'Skicka erbjudande';

  @override
  String get tradeNobody => 'Inget av dina syskon har ett handelshus än.';

  @override
  String get tradeNotEnough => 'Du har inte tillräckligt för det här än.';

  @override
  String tradeTheyHave(String name, String count) {
    return '$name har $count';
  }

  @override
  String get tradeSent => 'Erbjudandet skickat';

  @override
  String inboxTrade(String name, String give, String get) {
    return '$name vill byta $give mot dina $get';
  }

  @override
  String get guideCityTrade =>
      'Bygg ett handelshus och byt varor med dina syskon, alltid en mot en. Specialbyggnader kräver varor från mer än en stad.';

  @override
  String get shoppingEditItem => 'Ändra vara';

  @override
  String get shoppingItemText => 'Vad som ska köpas';

  @override
  String get shoppingItemHint => 't.ex. 2 l mjölk';

  @override
  String get shoppingAisle => 'Avdelning';

  @override
  String get shoppingNote => 'Anteckning';

  @override
  String get shoppingRenameList => 'Byt namn på listan';

  @override
  String get shoppingDeleteList => 'Ta bort listan';

  @override
  String shoppingDeleteListExplain(String name) {
    return 'Tar bort $name och allt på den. Du kan ta tillbaka den från Nyligen borttaget ett tag.';
  }

  @override
  String get shoppingSelect => 'Välj';

  @override
  String shoppingSelected(int count) {
    return '$count valda';
  }

  @override
  String get shoppingSelectAll => 'Välj alla';

  @override
  String get shoppingRemoveSelected => 'Ta bort';

  @override
  String shoppingRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tog bort $count varor',
      one: 'Tog bort 1 vara',
    );
    return '$_temp0';
  }
}
