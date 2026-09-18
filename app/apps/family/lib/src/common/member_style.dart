import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

/// Colour and initials for a member: the two redundant encodings spec §5
/// requires, since colour alone fails for colour-blind readers and in sunlight.
class MemberStyle {
  /// Okabe–Ito: distinguishable under deuteranopia (spec §5). New members
  /// take the next one; the same list backs members without a colour.
  static const palette = [
    '#0072B2',
    '#E69F00',
    '#009E73',
    '#CC79A7',
    '#56B4E9',
    '#D55E00',
  ];

  static const _fallback = [
    Color(0xFF0072B2),
    Color(0xFFE69F00),
    Color(0xFF009E73),
    Color(0xFFCC79A7),
    Color(0xFF56B4E9),
    Color(0xFFD55E00),
  ];

  static Color colorOf(Member member, int index) {
    final hex = member.color;
    if (hex != null && hex.length == 7 && hex.startsWith('#')) {
      final value = int.tryParse(hex.substring(1), radix: 16);
      if (value != null) return Color(0xFF000000 | value);
    }
    return _fallback[index % _fallback.length];
  }

  /// One letter per member, which stays legible in a stacked cluster. Members
  /// sharing a first letter get two, so Maja and Max stay apart.
  static Map<String, String> initialsFor(List<Member> members) {
    String first(Member m) => m.displayName.trim().characters.first;
    final counts = <String, int>{};
    for (final m in members) {
      final key = first(m).toUpperCase();
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return {
      for (final m in members)
        m.id: counts[first(m).toUpperCase()]! > 1
            ? m.displayName.trim().characters.take(2).toString().toUpperCase()
            : first(m).toUpperCase(),
    };
  }

  /// Black or white, whichever reads better on [background].
  static Color onColor(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : Colors.black;
}

/// Overlapping initials badges, one per member. A single member gets one badge.
class MemberAvatars extends StatelessWidget {
  const MemberAvatars({
    super.key,
    required this.members,
    required this.colors,
    required this.initials,
    this.size = 24,
  });

  final List<Member> members;
  final Map<String, Color> colors;
  final Map<String, String> initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox.shrink();
    final overlap = size * 0.3;
    final surface = Theme.of(context).colorScheme.surface;

    return SizedBox(
      height: size,
      width: size + (members.length - 1) * (size - overlap),
      child: Stack(
        children: [
          for (final (i, member) in members.indexed)
            Positioned(
              left: i * (size - overlap),
              child: Tooltip(
                message: member.displayName,
                child: Container(
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors[member.id],
                    shape: BoxShape.circle,
                    border: Border.all(color: surface, width: 1.5),
                  ),
                  child: Text(
                    initials[member.id] ?? '?',
                    style: TextStyle(
                      fontSize: size * 0.45,
                      fontWeight: FontWeight.w600,
                      color: MemberStyle.onColor(
                        colors[member.id] ?? Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
