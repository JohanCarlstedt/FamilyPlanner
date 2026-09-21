import 'package:family/src/features/homework/week_letter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a school document link is recognised, not treated as a recipe', () {
    // The real one, from Härryda kommun's SharePoint.
    expect(
      WeekLetter.looksLikeDocument(
        'https://harrydakommun-my.sharepoint.com/:w:/g/personal/'
        'linus_rydberg_harryda_se/IQAs-7VY9xh3SZyOF3FgX831AQ',
      ),
      isTrue,
    );
    expect(
      WeekLetter.looksLikeDocument('https://docs.google.com/document/d/abc'),
      isTrue,
    );
    expect(WeekLetter.looksLikeDocument('https://1drv.ms/w/s!Abc'), isTrue);
  });

  test('a recipe link still goes to the recipe importer', () {
    expect(WeekLetter.looksLikeDocument('https://www.ica.se/recept/pasta/'), isFalse);
    expect(WeekLetter.looksLikeDocument('https://arla.se/recept/pannkakor'), isFalse);
  });

  test('a host merely containing the words is not one of them', () {
    // sharepoint.com.example.com is not SharePoint.
    expect(
      WeekLetter.looksLikeDocument('https://sharepoint.com.evil.example/x'),
      isFalse,
    );
    expect(WeekLetter.looksLikeDocument('not a url at all'), isFalse);
  });
}
