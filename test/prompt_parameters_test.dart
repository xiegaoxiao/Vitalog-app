import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitalog/data/controller.dart';
import 'package:vitalog/data/demo.dart';
import 'package:vitalog/data/models.dart';
import 'package:vitalog/data/storage.dart';
import 'package:vitalog/services/plan_import.dart';
import 'package:vitalog/services/prompt_parameters.dart';
import 'package:vitalog/services/prompts.dart';
import 'package:vitalog/services/reminders.dart';
import 'package:vitalog/ui/ai_center.dart';
import 'package:vitalog/ui/design.dart';

class PromptStore extends LocalStore {
  String? value;
  @override
  Future<void> save(String raw) async => value = raw;
}

Json promptContext(String text) =>
    jsonDecode(text.substring(text.indexOf('\n{') + 1, text.indexOf('\n\n要求：')))
        as Json;

void main() {
  test('old time drafts normalize without accepting invalid clock values', () {
    for (final p in promptParameters.where((p) => p.time)) {
      expect(p.parse('8:00'), '08:00');
      expect(p.parse(' 8：00 '), '08:00');
      expect(p.parse('0:00'), '00:00');
      expect(p.parse('23:59'), '23:59');
      expect(p.parse(''), null);
      for (final invalid in ['24:00', '8:60', '8:0', 'abc']) {
        expect(() => p.parse(invalid), throwsFormatException);
      }
    }
    final data = AppData(
      settings: {
        'promptParameters': {'breakfast': '8:00'},
      },
    );
    expect(initialPromptParameters(data)['breakfast'], '08:00');
  });
  test(
    'quantified targets replace draft profile values without editing records',
    () {
      final data = demoData(DateTime.now());
      final before = jsonEncode(data.toJson());
      final raw = initialPromptParameters(data)
        ..addAll({
          'weight': '65.5',
          'calories': '1900',
          'protein': '110',
          'mealMinutes': '25',
          'sessionsPerWeek': 'invalid',
          'importantLeadMinutes': '30',
        });
      final parsed = parsePromptParameters(raw, 'meal');
      final result = promptContext(
        buildPrompt(
          data,
          DateTime.now(),
          DateTime.now(),
          'meal',
          false,
          profileOverrides: parsed.profile,
          planningParameters: parsed.constraints,
        ),
      );
      expect(result['profile']['weight'], 65.5);
      expect(result['profile']['currentWeight'], 65.5);
      expect(result['planningParameters']['meal']['每日热量 · kcal'], 1900);
      expect(result['planningParameters']['meal']['每日蛋白质 · g'], 110);
      expect(
        result['planningParameters']['meal'].containsKey('每日脂肪 · g'),
        false,
      );
      expect(result['planningParameters'].containsKey('workout'), false);
      expect(result['planningParameters']['common']['重要事项提前提醒 · 分钟'], 30);
      expect(result.containsKey('lastWeek'), false);
      expect(jsonEncode(data.toJson()), before);
      for (final value in ['-1', 'NaN', 'Infinity', '1.5']) {
        expect(
          () => parsePromptParameters({...raw, 'mealsPerDay': value}, 'meal'),
          throwsFormatException,
        );
      }
      expect(
        () => parsePromptParameters({...raw, 'breakfast': '25:10'}, 'meal'),
        throwsFormatException,
      );
    },
  );

  test(
    'sleep overrides and selected history remain independent of stored records',
    () {
      final now = DateTime.now();
      final data = demoData(now);
      data.events.addAll([
        for (final kind in ['meal', 'workout'])
          PlanItem(
            id: 'completed-$kind',
            kind: kind,
            title: kind,
            start: now,
            end: now.add(const Duration(hours: 1)),
            completedAt: now,
          ),
      ]);
      final raw = initialPromptParameters(data)
        ..addAll({'sleepTime': '22:30', 'wakeTime': ''});
      final parsed = parsePromptParameters(raw, 'habit');
      final result = promptContext(
        buildPrompt(
          data,
          now,
          now,
          'habit',
          true,
          profileOverrides: parsed.profile,
          planningParameters: parsed.constraints,
          historySections: {'weights', 'executed', 'workout'},
        ),
      );
      expect(result['sleepPreferences'], {
        'sleepTime': '22:30',
        'wakeTime': null,
      });
      expect(result['lastWeek'].containsKey('sleep'), false);
      expect(result['lastWeek'].containsKey('habits'), false);
      expect(
        result['lastWeek']['executed'].every((e) => e['kind'] == 'workout'),
        true,
      );
      expect(data.settings['sleepTime'], '23:00');
      data.settings['promptParameters'] = {'calories': '1900', 'weight': '50'};
      final restored = validateBackup(jsonEncode(data.toJson()));
      final defaults = initialPromptParameters(restored);
      expect(defaults['calories'], '1900');
      expect(defaults['weight'], restored.currentWeight.toString());
    },
  );

  testWidgets(
    'parameter form validates, generates, saves and blocks stale copying on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = PromptStore();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(Reminders.channel, (_) async => null);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(Reminders.channel, null),
      );
      final c = AppController(store: store)..data = demoData(DateTime.now());
      final profileBefore = jsonEncode(c.data.profile);
      await tester.pumpWidget(
        MaterialApp(
          theme: V.theme(Brightness.light),
          home: AiCenter(c: c),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, '复制提示词'),
            )
            .onPressed,
        null,
      );
      final calories = find.byKey(const Key('parameter-calories'));
      final breakfast = find.byKey(const Key('parameter-breakfast'));
      await tester.ensureVisible(breakfast);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: breakfast, matching: find.byType(TextField)),
            )
            .readOnly,
        true,
      );
      await tester.tap(breakfast);
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TimePickerDialog),
          matching: find.byType(EditableText),
        ),
        findsNothing,
      );
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(breakfast).controller!.text, '08:00');
      await tester.tap(find.byTooltip('清空早餐时间'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(breakfast).controller!.text, '');
      await tester.tap(breakfast);
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(calories);
      await tester.enterText(calories, '-2');
      await tester.tap(find.widgetWithText(FilledButton, '生成提示词'));
      await tester.pumpAndSettle();
      expect(store.value, null);
      await tester.enterText(calories, '1900');
      await tester.tap(find.widgetWithText(FilledButton, '生成提示词'));
      await tester.pumpAndSettle();
      final preview = find.byKey(const Key('generated-prompt'));
      expect(store.value, isNotNull);
      await tester.scrollUntilVisible(
        preview,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(preview).controller!.text,
        contains('1900'),
      );
      expect(
        tester.widget<TextField>(preview).controller!.text,
        contains('08:00'),
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, '复制提示词'),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        validateBackup(store.value!).settings['promptParameters']['calories'],
        '1900',
      );
      expect(jsonEncode(c.data.profile), profileBefore);
      await tester.ensureVisible(calories);
      await tester.pumpAndSettle();
      await tester.enterText(calories, '2000');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, '复制提示词'),
            )
            .onPressed,
        null,
      );
      await tester.tap(find.widgetWithText(FilledButton, '重新生成'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(preview).controller!.text,
        contains('2000'),
      );
      expect(tester.takeException(), null);
      for (final label in ['训练', '习惯', '综合计划']) {
        tester.widget<ListView>(find.byType(ListView)).controller!.jumpTo(0);
        await tester.pumpAndSettle();
        final chip = find.widgetWithText(ChoiceChip, label);
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(tester.takeException(), null);
      }
    },
  );
}
