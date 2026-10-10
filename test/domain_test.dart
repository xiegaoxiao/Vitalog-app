import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as timezone;
import 'package:vitalog/data/models.dart';
import 'package:vitalog/data/controller.dart';
import 'package:vitalog/data/storage.dart';
import 'package:vitalog/data/demo.dart';
import 'package:vitalog/services/plan_import.dart';
import 'package:vitalog/services/calendar_import.dart';
import 'package:vitalog/services/prompts.dart';

class MemoryStore extends LocalStore {
  String? value, old;
  bool fail = false;
  @override
  Future<String?> load() async => value;
  @override
  Future<void> save(String v) async {
    if (fail) {
      throw Exception('disk full');
    }
    old = value;
    value = v;
  }

  @override
  Future<String?> previous() async => old;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  timezone.initializeTimeZones();
  final today = DateTime(2026, 10, 10);
  test('style selection persists independently of brightness and accepts older backups', () async {
    final store = MemoryStore();
    final c = AppController(store: store);
    c.data = demoData(today);
    await c.mutate((d) {
      d.settings['appearance'] = 'cartoon';
      d.settings['theme'] = 'dark';
    });
    final reloaded = AppController(store: store);
    await reloaded.load();
    expect(reloaded.data.settings['appearance'], 'cartoon');
    expect(reloaded.data.settings['theme'], 'dark');
    final old = reloaded.data.toJson();
    (old['settings'] as Json).remove('appearance');
    expect(
      validateBackup(jsonEncode(old)).settings['appearance'] ?? 'classic',
      'classic',
    );
    (old['settings'] as Json)['appearance'] = 'unknown';
    expect(() => validateBackup(jsonEncode(old)), throwsFormatException);
  });
  test('missing nutrients stay unknown rather than pretending to be zero', () {
    expect(
      nutrientTotal([
        {'calories': 500},
        {'calories': null},
      ], 'calories'),
      null,
    );
    expect(
      nutrientTotal([
        {'calories': 0},
        {'calories': 500},
      ], 'calories'),
      500,
    );
    expect(nutrientTotal([], 'calories'), null);
  });
  test('BMI and energy estimates match the selected profile; underage estimates stay unset', () {
    final d = AppData(
      profile: {'height': 180.0, 'weight': 80.0, 'age': 30, 'sex': 'male'},
    );
    expect(d.bmi, closeTo(24.691358, .001));
    expect(d.bmr, closeTo(1780, .001));
    d.profile['sex'] = 'female';
    expect(d.bmr, 1614);
    d.profile['age'] = 17;
    expect(d.bmr, null);
  });
  test('weekly averages exclude stale and future readings', () {
    final d = AppData(
      weights: [
        {'date': '2026-10-03', 'value': 100},
        {'date': '2026-10-04', 'value': 90},
        {'date': '2026-10-10', 'value': 88},
        {'date': '2026-10-11', 'value': 80},
      ],
    );
    expect(d.weekAverage(today), 89);
  });
  test(
    'inventory converts units and combines repeated ingredients across lots',
    () {
      final d = AppData(
        inventory: [
          InventoryItem(id: 'a', name: '土豆', quantity: .5, unit: 'kg'),
          InventoryItem(id: 'b', name: '土豆', quantity: 1, unit: '斤'),
        ],
      );
      final result = prepareDeductions(d, [
        {'name': '土豆', 'quantity': 400, 'unit': 'g'},
        {'name': '土豆', 'quantity': 400, 'unit': 'g'},
      ]);
      expect(result['a'], .5);
      expect(result['b'], .6);
    },
  );
  test('meal completion is idempotent, actual corrections reconcile stock, undo restores stock', () async {
    final store = MemoryStore();
    final c = AppController(store: store);
    c.data = demoData(today);
    final meal = c.data.events.firstWhere((e) => e.id == 'demo-meal-0');
    final actual = {
      'nutrition': meal.nutrition,
      'ingredients': meal.ingredients,
    };
    await c.complete(meal.id, actual: actual, deduct: true);
    await c.complete(meal.id, actual: actual, deduct: true);
    expect(
      c.data.inventory.firstWhere((s) => s.id == 'stock-potato').quantity,
      1200,
    );
    final modified = cloneJson(actual);
    (modified['ingredients'] as List)[0]['quantity'] = 200;
    await c.reviseActual(meal.id, modified, true);
    expect(
      c.data.inventory.firstWhere((s) => s.id == 'stock-potato').quantity,
      1300,
    );
    await c.undoComplete(meal.id);
    expect(
      c.data.inventory.firstWhere((s) => s.id == 'stock-potato').quantity,
      1500,
    );
    expect(c.data.events.firstWhere((e) => e.id == meal.id).completed, false);
  });
  test('insufficient inventory and failed persistence roll back the complete transaction', () async {
    final store = MemoryStore();
    final c = AppController(store: store);
    c.data = demoData(today);
    final meal = c.data.events.firstWhere((e) => e.id == 'demo-meal-0');
    final snapshot = jsonEncode(c.data.toJson());
    await expectLater(
      c.complete(
        meal.id,
        actual: {
          'ingredients': [
            {'name': '土豆', 'quantity': 9999, 'unit': 'g'},
          ],
        },
        deduct: true,
      ),
      throwsFormatException,
    );
    expect(jsonEncode(c.data.toJson()), snapshot);
    store.fail = true;
    await expectLater(
      c.complete(
        meal.id,
        actual: {'ingredients': meal.ingredients},
        deduct: true,
      ),
      throwsException,
    );
    expect(jsonEncode(c.data.toJson()), snapshot);
    store.fail = false;
    await c.complete(meal.id);
    expect(c.data.events.firstWhere((e) => e.id == meal.id).completed, true);
  });
  test('replacement preserves completed meals and fixed courses, even with new AI IDs', () {
    final d = demoData(today);
    final meal = d.events.first;
    meal.completedAt = today;
    final j = planExample(today);
    final incoming = parsePlan(jsonEncode(j));
    final preview = incoming.preview(d, true);
    expect(preview.replacedIds.contains(meal.id), false);
    expect(preview.replacedIds.contains('demo-course'), false);
    expect(preview.skipped, 1);
    expect(preview.additions, isEmpty);
  });
  test(
    'duplicate, outside-range, negative and nonfinite input cannot be imported',
    () {
      final j = cloneJson(planExample(today));
      (j['events'] as List).add(cloneJson((j['events'] as List).first as Json));
      expect(() => parsePlan(jsonEncode(j)), throwsFormatException);
      final negative = planExample(today);
      ((negative['events'] as List).first
              as Json)['details']['ingredients'][0]['quantity'] =
          -1;
      expect(() => parsePlan(jsonEncode(negative)), throwsFormatException);
      final outside = planExample(today);
      ((outside['events'] as List).first as Json)['start'] =
          '2026-10-11T12:00:00+08:00';
      ((outside['events'] as List).first as Json)['end'] =
          '2026-10-11T13:00:00+08:00';
      expect(() => parsePlan(jsonEncode(outside)), throwsFormatException);
    },
  );
  test('ICS unfolds lines and expands weekly interval, exclusions and modified occurrences', () {
    const raw =
        'BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:class1\r\nDTSTART;TZID=Asia/Shanghai:20261005T083000\r\nDTEND;TZID=Asia/Shanghai:20261005T100000\r\nSUMMARY:软件需求\r\n 工程\r\nRRULE:FREQ=WEEKLY;INTERVAL=2;COUNT=4;BYDAY=MO\r\nEXDATE;TZID=Asia/Shanghai:20261019T083000\r\nEND:VEVENT\r\nBEGIN:VEVENT\r\nUID:class1\r\nRECURRENCE-ID;TZID=Asia/Shanghai:20261102T083000\r\nDTSTART;TZID=Asia/Shanghai:20261103T083000\r\nDTEND;TZID=Asia/Shanghai:20261103T100000\r\nSUMMARY:临时改课\r\nEND:VEVENT\r\nEND:VCALENDAR';
    final parsed = parseCalendar(raw);
    expect(parsed.events.length, 3);
    expect(parsed.events.where((e) => e.title == '软件需求工程').length, 2);
    expect(parsed.events.where((e) => e.title == '临时改课').length, 1);
    expect(parsed.events.every((e) => e.leadMinutes == 15), true);
    expect(
      parsed.preview(AppData(events: parsed.events), true).additions,
      isEmpty,
    );
  });
  test('unknown timezone and unbounded recurrence fail instead of silently corrupting a timetable', () {
    expect(
      () => parseCalendar(
        'BEGIN:VCALENDAR\nBEGIN:VEVENT\nDTSTART:20260230T083000\nSUMMARY:课\nEND:VEVENT\nEND:VCALENDAR',
      ),
      throwsFormatException,
    );
    final withAlarm = parseCalendar(
      'BEGIN:VCALENDAR\nBEGIN:VEVENT\nDTSTART:20261005T083000\nSUMMARY:课程\nBEGIN:VALARM\nDTSTART:20261005T080000\nSUMMARY:通知文字\nEND:VALARM\nEND:VEVENT\nEND:VCALENDAR',
    );
    expect(withAlarm.events.single.title, '课程');
    expect(withAlarm.events.single.start.minute, 30);
    expect(
      () => parseCalendar(
        'BEGIN:VCALENDAR\nBEGIN:VEVENT\nDTSTART;TZID=Unknown:20261005T083000\nSUMMARY:课\nEND:VEVENT\nEND:VCALENDAR',
      ),
      throwsFormatException,
    );
    expect(
      () => parseCalendar(
        'BEGIN:VCALENDAR\nBEGIN:VEVENT\nDTSTART:20261005T083000\nRRULE:FREQ=WEEKLY\nSUMMARY:课\nEND:VEVENT\nEND:VCALENDAR',
      ),
      throwsFormatException,
    );
  });
  test(
    'backup round trip retains consumption links and rejects malformed stock',
    () {
      final d = demoData(today);
      expect(
        validateBackup(jsonEncode(d.toJson())).events.length,
        d.events.length,
      );
      final j = d.toJson();
      (j['inventory'] as List).first['quantity'] = -1;
      expect(() => validateBackup(jsonEncode(j)), throwsFormatException);
    },
  );
  test('shopping requirements only include unfinished meals and subtract current stock', () {
    final d = demoData(today);
    final potato = shoppingList(
      d,
      today,
      today.add(const Duration(days: 6)),
    ).firstWhere((e) => e['name'] == '土豆');
    expect(potato['need'], 2100);
    expect(potato['missing'], 600);
    d.events.first.completedAt = today;
    final changed = shoppingList(
      d,
      today,
      today.add(const Duration(days: 6)),
    ).firstWhere((e) => e['name'] == '土豆');
    expect(changed['need'], 1800);
  });
  test('prompt includes selected context and history only when opted in', () {
    final d = demoData(today);
    expect(
      buildPrompt(d, today, today, 'meal', false),
      contains('fixedSchedule'),
    );
    expect(
      buildPrompt(d, today, today, 'meal', false),
      isNot(contains('"lastWeek"')),
    );
    expect(buildPrompt(d, today, today, 'meal', true), contains('"lastWeek"'));
  });
}
