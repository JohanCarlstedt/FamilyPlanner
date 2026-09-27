import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// What someone says to the shopping list, as the items they meant.
void main() {
  test('commas and "and" / "och" separate items', () {
    expect(spokenItems('mjölk, ägg och bröd'), ['mjölk', 'ägg', 'bröd']);
    expect(spokenItems('milk, eggs and bread'), ['milk', 'eggs', 'bread']);
    expect(spokenItems('milk and eggs, and bread'), ['milk', 'eggs', 'bread']);
  });

  test('"samt", "plus" and "också" too', () {
    expect(spokenItems('smör samt ost plus skinka'), ['smör', 'ost', 'skinka']);
  });

  test('amounts stay with their item', () {
    expect(
        spokenItems('2 liter mjölk och 12 ägg'), ['2 liter mjölk', '12 ägg']);
  });

  test('a lead-in is dropped', () {
    expect(spokenItems('lägg till mjölk och ägg'), ['mjölk', 'ägg']);
    expect(spokenItems('Add milk and eggs to the list'), ['milk', 'eggs']);
    expect(spokenItems('köp bananer på listan'), ['bananer']);
  });

  test('a word that only looks like "and" stays whole', () {
    expect(spokenItems('sandwich bread'), ['sandwich bread']);
    expect(spokenItems('ochre paint'), ['ochre paint']);
  });

  test('nothing said, nothing added', () {
    expect(spokenItems(''), isEmpty);
    expect(spokenItems('  och , '), isEmpty);
  });
}
