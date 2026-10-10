import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitalog/app.dart';
import 'package:vitalog/data/controller.dart';
import 'package:vitalog/data/demo.dart';
import 'package:vitalog/ui/design.dart';
import 'package:vitalog/ui/agenda.dart';

void main() {
  testWidgets(
    'switching styles preserves approved control and timeline geometry',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = demoData(DateTime(2026, 10, 10));
      Map<String, Size>? original;
      for (final cartoon in [false, true]) {
        for (final brightness in Brightness.values) {
          await tester.pumpWidget(
            MaterialApp(
              theme: V.theme(brightness, cartoon: cartoon),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(20),
                  child: ListView(
                    children: [
                      CardAction(
                        key: const Key('action'),
                        label: '查看安排',
                        onPressed: () {},
                      ),
                      NutritionRow(
                        data
                            .onDay(DateTime(2026, 10, 10))
                            .firstWhere((e) => e.kind == 'meal')
                            .nutrition,
                        key: const Key('nutrition'),
                      ),
                      AgendaTimeline(
                        key: const Key('timeline'),
                        events: data
                            .onDay(DateTime(2026, 10, 10))
                            .take(2)
                            .toList(),
                        onView: (_) {},
                        onComplete: (_) {},
                      ),
                      ChoiceChip(
                        key: const Key('filter'),
                        label: const Text('课程'),
                        selected: true,
                        onSelected: (_) {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), null);
          final sizes = {
            for (final key in ['action', 'nutrition', 'timeline', 'filter'])
              key: tester.getSize(find.byKey(Key(key))),
          };
          original ??= sizes;
          expect(sizes, original);
        }
      }
    },
  );
  testWidgets(
    'form labels stay inside their fill and above values in all states',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controllers = [
        TextEditingController(text: '番茄鸡蛋汤'),
        TextEditingController(),
        TextEditingController(text: '480'),
        TextEditingController(text: '土豆、鸡肉与蔬菜\n用小锅做饭'),
      ];
      addTearDown(() {
        for (final c in controllers) {
          c.dispose();
        }
      });
      for (final brightness in Brightness.values) {
        for (final scale in [1.0, 1.5]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: V.theme(brightness),
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(360, 1000),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        field(controllers[0], '实际餐食名称'),
                        field(controllers[1], '饮食禁忌（可选）'),
                        field(controllers[2], '热量 · kcal', numeric: true),
                        field(controllers[3], '做饭条件', lines: 3),
                        DropdownButtonFormField<String>(
                          initialValue: 'male',
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: '公式使用的性别',
                          ),
                          items: const [
                            DropdownMenuItem(value: 'male', child: Text('男')),
                          ],
                          onChanged: (_) {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          void checkLayout() {
            expect(tester.takeException(), null);
            for (final decorator in find.byType(InputDecorator).evaluate()) {
              final decoration = decorator.widget as InputDecorator;
              final label = find.descendant(
                of: find.byWidget(decoration),
                matching: find.text(decoration.decoration.labelText!),
              );
              final bounds = tester.getRect(find.byWidget(decoration));
              expect(
                tester.getTopLeft(label).dy,
                greaterThanOrEqualTo(bounds.top),
              );
              expect(
                tester.getBottomRight(label).dy,
                lessThanOrEqualTo(bounds.bottom),
              );
              final input = find.descendant(
                of: find.byWidget(decoration),
                matching: find.byType(EditableText),
              );
              if (!decoration.isEmpty && input.evaluate().isNotEmpty) {
                expect(
                  tester.getBottomRight(label).dy,
                  lessThanOrEqualTo(tester.getTopLeft(input).dy),
                );
              }
            }
          }

          checkLayout();
          // Empty labels must also remain within the surface after floating on focus.
          await tester.tap(find.byType(TextField).at(1));
          await tester.pumpAndSettle();
          checkLayout();
          await tester.tap(find.byType(TextField).at(3));
          await tester.pumpAndSettle();
          checkLayout();
        }
      }
    },
  );
  testWidgets(
    'mobile dashboard and module navigation render without overflow at 360px',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = AppController();
      c.data = demoData(DateTime.now());
      for (final appearance in ['classic', 'cartoon']) {
        for (final theme in ['light', 'dark']) {
          c.data.settings['appearance'] = appearance;
          c.data.settings['theme'] = theme;
          await tester.pumpWidget(VitalogApp(controller: c));
          await tester.pumpAndSettle();
          expect(tester.takeException(), null);
          expect(find.text('元气簿'), findsOneWidget);
          for (final label in ['饮食', '日程', '训练', '我的', '今日']) {
            await tester.tap(find.widgetWithText(NavigationDestination, label));
            await tester.pumpAndSettle();
            expect(tester.takeException(), null);
          }
        }
      }
    },
  );
  testWidgets(
    'empty installation presents onboarding, not fabricated health records',
    (tester) async {
      await tester.pumpWidget(VitalogApp(controller: AppController()));
      await tester.pumpAndSettle();
      expect(find.text('建立我的档案'), findsOneWidget);
      expect(tester.takeException(), null);
    },
  );
}
