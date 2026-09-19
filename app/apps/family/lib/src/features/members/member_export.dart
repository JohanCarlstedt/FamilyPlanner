import 'dart:convert';
import 'dart:io';

import 'package:domain/domain.dart';
import 'package:family_data/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../chat/chat_providers.dart';
import '../../data/family_repository.dart';
import '../../data/store_providers.dart';

/// A member's data as they'd take it elsewhere (spec §9, GDPR): their
/// calendar as iCalendar for any calendar app, and everything about them
/// as JSON. Assembled on this phone from decrypted content; the server
/// holds nothing it could export.
class MemberExport {
  const MemberExport({required this.calendar, required this.data});

  final String calendar;
  final Map<String, Object?> data;

  /// Events concern [member] when they go, are responsible, or created it.
  static bool concerns(Member member, EventPayload e) =>
      e.participantIds.contains(member.id) ||
      e.responsibleMemberId == member.id ||
      e.payload.createdBy == member.id;

  static MemberExport build({
    required Member member,
    required List<(String, EventPayload)> payloads,
    required List<CalendarEvent> events,
    required List<ChatMessage> messages,
    required Map<String, String> deviceOwners,
    required DateTime now,
  }) {
    final ids = {
      for (final (id, e) in payloads)
        if (!e.isDeleted && concerns(member, e)) id,
    };
    String local(DateTime? t) => t?.toIso8601String().replaceAll('Z', '') ?? '';
    return MemberExport(
      calendar: ICalendar.write([
        for (final e in events)
          if (ids.contains(e.id)) e,
      ], name: member.displayName),
      data: {
        'exportedAt': now.toUtc().toIso8601String(),
        'format': 'family-planner-member-export/1',
        'member': {
          'id': member.id,
          'name': member.displayName,
          'role': member.role.name,
          'ageGroup': member.tier?.name,
          'colour': member.color,
        },
        'events': [
          for (final (id, e) in payloads)
            if (ids.contains(id))
              {
                'id': id,
                'title': e.title,
                'start': local(e.localStart),
                'minutes': e.duration.inMinutes,
                'timeZone': e.timeZone,
                'status': e.status.name,
                'location': e.location,
                'notes': e.notes,
                'going': e.participantIds.contains(member.id),
                'responsible': e.responsibleMemberId == member.id,
                'createdByThem': e.payload.createdBy == member.id,
              },
        ],
        // Chat is end-to-end encrypted: this is the history this phone
        // holds, not a server copy.
        'chatMessages': [
          for (final m in messages)
            if (deviceOwners[m.sender] == member.id)
              {'sentAt': m.sentAt.toUtc().toIso8601String(), 'text': m.text},
        ],
      },
    );
  }
}

/// This phone's chat history across its threads, if chat has started; an export
/// shouldn't wait on the chat to come up.
Future<List<ChatMessage>> _chatHistory(WidgetRef ref) async {
  try {
    final chat = await ref
        .read(familyChatProvider.future)
        .timeout(const Duration(seconds: 3));
    return [
      for (final c in await chat.conversations())
        ...await chat.watch(c.group).first,
    ];
  } on Object catch (e) {
    debugPrint('Export without chat: $e');
    return const [];
  }
}

/// Builds [member]'s export and hands it to the share sheet.
Future<void> shareMemberExport(
  BuildContext context,
  WidgetRef ref,
  Member member,
) async {
  final box = context.findRenderObject() as RenderBox?;
  final store = await ref.read(familyStoreProvider.future);
  final export = MemberExport.build(
    member: member,
    payloads: await store.watchEvents().first,
    events: await ref.read(eventsProvider.future),
    messages: await _chatHistory(ref),
    deviceOwners: await ref.read(deviceMembersProvider.future),
    now: DateTime.now(),
  );
  final dir = await getTemporaryDirectory();
  final base = member.displayName
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '-')
      .toLowerCase();
  final ics = File('${dir.path}/$base-calendar.ics')
    ..writeAsStringSync(export.calendar);
  final json = File(
    '${dir.path}/$base-data.json',
  )..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(export.data));
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile(ics.path, mimeType: 'text/calendar'),
        XFile(json.path, mimeType: 'application/json'),
      ],
      subject: member.displayName,
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    ),
  );
}
