import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'storage.dart';
import '../services/reminders.dart';
import '../services/plan_import.dart';

class AppController extends ChangeNotifier {
  AppController({LocalStore? store}) : _store = store ?? LocalStore();
  final LocalStore _store;
  final reminders = Reminders();
  AppData data = AppData();
  String? reminderError;
  bool saving = false;
  Future<void> _queue = Future.value();
  Future<void> load() async {
    final raw = await _store.load();
    if (raw != null) {
      data = validateBackup(raw);
    }
    await syncReminders();
    notifyListeners();
  }

  Future<void> mutate(void Function(AppData d) action) {
    final next = _queue.then((_) async {
      final previous = data.copy();
      saving = true;
      notifyListeners();
      try {
        action(data);
        await _store.save(jsonEncode(data.toJson()));
      } catch (_) {
        data = previous;
        rethrow;
      } finally {
        saving = false;
        notifyListeners();
      }
      await syncReminders();
    });
    _queue = next.catchError((Object _) {});
    return next;
  }

  Future<void> syncReminders() async {
    try {
      await reminders.sync(data);
      reminderError = null;
    } catch (_) {
      reminderError = '计划已保存，提醒同步失败；请检查提醒设置后重试';
    }
    notifyListeners();
  }

  Future<void> saveEvent(PlanItem value) => mutate((d) {
    final index = d.events.indexWhere((e) => e.id == value.id);
    if (index >= 0) {
      if (d.events[index].completed) {
        throw const FormatException('已完成事项请修改实际记录，计划记录保持原样');
      }
      d.events[index] = value.copy();
    } else {
      d.events.add(value.copy());
    }
  });
  Future<void> complete(String id, {Json? actual, bool deduct = false}) =>
      mutate((d) {
        final event = d.events.firstWhere((e) => e.id == id);
        if (event.completed) {
          return;
        }
        final entry = cloneJson(actual ?? {});
        final ingredients =
            ((entry['ingredients'] ?? event.details['ingredients'] ?? [])
                    as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
        final deductions = deduct && event.kind == 'meal'
            ? prepareDeductions(d, ingredients)
            : <String, double>{};
        for (final stock in d.inventory) {
          stock.quantity -= deductions[stock.id] ?? 0;
        }
        event.deductions = deductions;
        event.actual = entry;
        event.completedAt = DateTime.now();
        if (event.kind == 'habit') {
          d.habits.add({
            'eventId': event.id,
            'title': event.title,
            'date': dateKey(event.start),
            'completedAt': event.completedAt!.toIso8601String(),
          });
        }
      });
  Future<void> undoComplete(String id) => mutate((d) {
    final event = d.events.firstWhere((e) => e.id == id);
    for (final stock in d.inventory) {
      stock.quantity += number(event.deductions[stock.id]) ?? 0;
    }
    event.completedAt = null;
    event.actual = {};
    event.deductions = {};
    d.habits.removeWhere((h) => h['eventId'] == event.id);
  });
  Future<void> reviseActual(String id, Json actual, bool deduct) => mutate((d) {
    final event = d.events.firstWhere((e) => e.id == id);
    if (!event.completed) {
      throw const FormatException('尚未完成');
    }
    for (final stock in d.inventory) {
      stock.quantity += number(event.deductions[stock.id]) ?? 0;
    }
    final ingredients = ((actual['ingredients'] ?? []) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final deductions = deduct && event.kind == 'meal'
        ? prepareDeductions(d, ingredients)
        : <String, double>{};
    for (final stock in d.inventory) {
      stock.quantity -= deductions[stock.id] ?? 0;
    }
    event.actual = cloneJson(actual);
    event.deductions = deductions;
  });
  Future<void> saveWorkoutSet(String id, String key, Json set) => mutate((d) {
    final event = d.events.firstWhere((e) => e.id == id);
    final sets = Map<String, dynamic>.from(event.actual['sets'] as Map? ?? {});
    sets[key] = set;
    event.actual['sets'] = sets;
  });
  Future<void> applyImport(PlanImport plan, bool replace) => mutate((d) {
    final applied = plan.preview(d, replace);
    d.events.removeWhere((e) => applied.replacedIds.contains(e.id));
    d.events.addAll(applied.additions.map((e) => e.copy()));
  });
  String exportBackup() => const JsonEncoder.withIndent('  ').convert({
    ...data.toJson(),
    'exportedAt': DateTime.now().toIso8601String(),
    'app': 'Vitalog',
  });
  Future<void> restore(AppData restored) => mutate((d) {
    data = restored.copy();
  });
  Future<void> restorePrevious() async {
    final raw = await _store.previous();
    if (raw == null) {
      throw const FormatException('没有可恢复的上一份记录');
    }
    await restore(validateBackup(raw));
  }
}
