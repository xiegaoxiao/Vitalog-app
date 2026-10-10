import 'dart:convert';

import '../data/models.dart';

void require(bool ok, String message) {
  if (!ok) {
    throw FormatException(message);
  }
}

Json object(dynamic input, String name) {
  require(input is Map, '$name 必须是对象');
  return Map<String, dynamic>.from(input as Map);
}

List list(dynamic input, String name) {
  require(input is List, '$name 必须是数组');
  return input as List;
}

String textValue(dynamic input, String name, {int max = 500}) {
  require(
    input is String && input.trim().isNotEmpty && input.length <= max,
    '$name 需要填写文字（最多 $max 字）',
  );
  return (input as String).trim();
}

DateTime dateValue(dynamic input, String name) {
  require(input is String, '$name 必须是日期时间');
  final matched = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.\d{1,6})?)?(?:Z|[+-](?:0\d|1[0-4]):[0-5]\d)?)?$',
  ).firstMatch(input as String);
  require(matched != null, '$name 需要使用 ISO 日期时间');
  final year = int.parse(matched!.group(1)!);
  final month = int.parse(matched.group(2)!);
  final day = int.parse(matched.group(3)!);
  final check = DateTime(year, month, day);
  require(
    check.year == year && check.month == month && check.day == day,
    '$name 的年月日无效',
  );
  require(
    int.parse(matched.group(4) ?? '0') < 24 &&
        int.parse(matched.group(5) ?? '0') < 60 &&
        int.parse(matched.group(6) ?? '0') < 60,
    '$name 的时间无效',
  );
  final value = DateTime.tryParse(input);
  require(value != null, '$name 不是有效日期时间');
  return value!.toLocal();
}

double finiteValue(
  dynamic input,
  String name, {
  double min = 0,
  double max = 100000,
}) {
  final n = number(input);
  require(n != null && n >= min && n <= max, '$name 必须在 $min～$max 之间');
  return n!;
}

void validateNutrition(dynamic input, String name) {
  if (input == null) {
    return;
  }
  final n = object(input, name);
  for (final key in nutrientKeys) {
    if (n[key] != null) {
      finiteValue(n[key], '$name.${nutrientNames[key]}');
    }
  }
}

void validateIngredients(dynamic input, String name) {
  if (input == null) {
    return;
  }
  final ingredients = list(input, name);
  require(ingredients.length <= 100, '$name 最多 100 种食材');
  for (final i in ingredients) {
    final v = object(i, name);
    textValue(v['name'], '$name.名称', max: 80);
    finiteValue(v['quantity'], '$name.用量');
    textValue(v['unit'], '$name.单位', max: 20);
  }
}

void validateDetails(Json details, String kind, String context) {
  for (final key in ['notes', 'location', 'slot']) {
    if (details[key] != null) {
      require(
        details[key] is String && (details[key] as String).length <= 10000,
        '$context.$key 必须是文字',
      );
    }
  }
  if (details['minutes'] != null) {
    finiteValue(details['minutes'], '$context.制作分钟', max: 1440);
  }
  validateNutrition(details['nutrition'], '$context.营养');
  validateIngredients(details['ingredients'], '$context.食材');
  if (details['steps'] != null) {
    final steps = list(details['steps'], '$context.步骤');
    require(steps.length <= 100, '步骤过多');
    for (final s in steps) {
      textValue(s, '$context.步骤', max: 2000);
    }
  }
  if (details['exercises'] != null) {
    final exercises = list(details['exercises'], '$context.动作');
    require(exercises.length <= 50, '一次训练最多 50 个动作');
    for (final raw in exercises) {
      final e = object(raw, '动作');
      textValue(e['name'], '动作名称', max: 100);
      final sets = finiteValue(e['sets'], '动作组数', min: 1, max: 30);
      require(sets == sets.roundToDouble(), '动作组数必须为整数');
      if (e['reps'] != null) {
        finiteValue(e['reps'], '次数', min: 1, max: 1000);
      }
      if (e['weight'] != null) {
        finiteValue(e['weight'], '重量', max: 1000);
      }
      if (e['seconds'] != null) {
        finiteValue(e['seconds'], '动作持续秒数', min: 1, max: 3600);
      }
      if (e['notes'] != null) {
        require(
          e['notes'] is String && (e['notes'] as String).length <= 2000,
          '动作要点必须是文字',
        );
      }
      if (e['rest_seconds'] != null) {
        finiteValue(e['rest_seconds'], '休息秒数', max: 1800);
      }
    }
  }
}

void validateItem(PlanItem item) {
  require(kinds.contains(item.kind), '不支持的事项类型 ${item.kind}');
  textValue(item.id, '事项 ID', max: 250);
  textValue(item.title, '事项标题', max: 200);
  require(
    item.end.isAfter(item.start) &&
        item.end.difference(item.start).inHours <= 48,
    '${item.title} 的结束时间需要晚于开始时间，且不超过 48 小时',
  );
  require(priorities.contains(item.priority), '提醒等级无效');
  require(
    item.leadMinutes >= 0 && item.leadMinutes <= 1440,
    '提前提醒分钟数需要在 0～1440 之间',
  );
  validateDetails(item.details, item.kind, item.title);
  validateNutrition(item.actual['nutrition'], '实际营养');
  validateIngredients(item.actual['ingredients'], '实际食材');
  if (item.actual['title'] != null) {
    textValue(item.actual['title'], '实际餐食名称', max: 200);
  }
  if (item.actual['restUntil'] != null) {
    dateValue(item.actual['restUntil'], '休息结束时间');
  }
  if (item.actual['sets'] != null) {
    final sets = object(item.actual['sets'], '实际组数');
    require(sets.length <= 1500, '实际组数过多');
    for (final raw in sets.values) {
      final set = object(raw, '实际动作记录');
      for (final key in ['weight', 'reps', 'seconds']) {
        if (set[key] != null) {
          finiteValue(set[key], '实际动作 $key', max: 3600);
        }
      }
      if (set['at'] != null) {
        dateValue(set['at'], '动作记录时间');
      }
    }
  }
  require(item.completed || item.deductions.isEmpty, '未完成事项不能带有库存扣减记录');
  for (final deduction in item.deductions.values) {
    finiteValue(deduction, '库存扣减记录');
  }
}

class ImportPreview {
  ImportPreview(this.additions, this.replacedIds, this.skipped, this.conflicts);
  List<PlanItem> additions;
  Set<String> replacedIds;
  int skipped;
  List<String> conflicts;
}

class PlanImport {
  PlanImport({
    required this.start,
    required this.end,
    required this.modules,
    required this.events,
  });
  final DateTime start;
  final DateTime end;
  final List<String> modules;
  final List<PlanItem> events;
  ImportPreview preview(AppData data, bool replace) {
    final removed = replace
        ? data.events
              .where(
                (e) =>
                    !e.completed &&
                    !e.fixed &&
                    modules.contains(e.kind) &&
                    !dayOf(e.start).isBefore(start) &&
                    !dayOf(e.start).isAfter(end),
              )
              .map((e) => e.id)
              .toSet()
        : <String>{};
    final retained = data.events.where((e) => !removed.contains(e.id)).toList();
    final existingIds = retained.map((e) => e.id).toSet();
    final existingCompletions = retained
        .where((e) => e.completed)
        .map((e) => '${e.kind}:${e.start.toIso8601String()}')
        .toSet();
    final additions = <PlanItem>[];
    var skipped = 0;
    for (final event in events) {
      if (existingIds.contains(event.id) ||
          existingCompletions.contains(
            '${event.kind}:${event.start.toIso8601String()}',
          )) {
        skipped++;
        continue;
      }
      additions.add(event);
      existingIds.add(event.id);
    }
    final conflicts = <String>[];
    for (var i = 0; i < additions.length; i++) {
      final e = additions[i];
      for (final other in [
        ...retained.where((e) => !e.completed),
        ...additions.take(i),
      ]) {
        if (e.start.isBefore(other.end) && e.end.isAfter(other.start)) {
          conflicts.add(
            '${dateKey(e.start)} ${clock(e.start)}「${e.title}」与「${other.title}」重叠',
          );
        }
      }
    }
    return ImportPreview(
      additions,
      removed,
      skipped,
      conflicts.take(50).toList(),
    );
  }
}

PlanImport parsePlan(String raw) {
  require(raw.length <= 2000000, '计划文件过大（最多 2 MB）');
  final cleaned = raw
      .trim()
      .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
      .replaceFirst(RegExp(r'\s*```$'), '');
  final root = object(jsonDecode(cleaned), '计划');
  require(root['schemaVersion'] == 1, '计划 schemaVersion 必须是 1');
  final range = object(root['range'], 'range');
  final start = dayOf(dateValue(range['start'], '计划开始日期'));
  final end = dayOf(dateValue(range['end'], '计划结束日期'));
  require(
    !end.isBefore(start) && end.difference(start).inDays <= 366,
    '计划周期必须在 1～367 天内',
  );
  final rows = list(root['events'], 'events');
  require(rows.length <= 1000, '一次最多导入 1000 个事项');
  final ids = <String>{};
  final events = <PlanItem>[];
  for (var index = 0; index < rows.length; index++) {
    final j = object(rows[index], '第 ${index + 1} 项');
    final id = textValue(j['id'], '第 ${index + 1} 项 ID', max: 200);
    require(ids.add(id), '重复 ID：$id');
    final item = PlanItem(
      id: 'ai:$id',
      kind: textValue(j['kind'], '类型'),
      title: textValue(j['title'], '标题', max: 200),
      start: dateValue(j['start'], '开始时间'),
      end: dateValue(j['end'], '结束时间'),
      priority: j['priority'] as String? ?? 'normal',
      reminder: j['reminder'] as bool? ?? j['kind'] != 'meal',
      leadMinutes: (j['leadMinutes'] as num?)?.toInt() ?? 0,
      alarm: j['alarm'] as bool? ?? false,
      groupId: j['groupId'] as String?,
      details: object(j['details'] ?? {}, 'details'),
    );
    validateItem(item);
    require(
      !dayOf(item.start).isBefore(start) && !dayOf(item.start).isAfter(end),
      '${item.title} 不在声明的计划周期内',
    );
    events.add(item);
  }
  final modules = root['modules'] == null
      ? events.map((e) => e.kind).toSet().toList()
      : list(
          root['modules'],
          'modules',
        ).map((e) => textValue(e, '模块')).toSet().toList();
  require(modules.isNotEmpty && modules.every(kinds.contains), '需要声明有效的计划模块');
  require(
    events.every((e) => modules.contains(e.kind)),
    'events 包含 modules 未声明的类型',
  );
  return PlanImport(start: start, end: end, modules: modules, events: events);
}

AppData validateBackup(String raw) {
  require(raw.length <= 20000000, '备份过大（最多 20 MB）');
  final root = object(jsonDecode(raw), '备份');
  for (final rawEvent in list(root['events'], '备份事项')) {
    final e = object(rawEvent, '备份事项');
    dateValue(e['start'], '事项开始时间');
    dateValue(e['end'], '事项结束时间');
    if (e['completedAt'] != null) {
      dateValue(e['completedAt'], '完成时间');
    }
  }
  final data = AppData.fromJson(root);
  require(
    data.events.length <= 20000 && data.inventory.length <= 2000,
    '备份记录过多',
  );
  final eventIds = <String>{};
  final stockIds = <String>{};
  for (final e in data.events) {
    validateItem(e);
    require(eventIds.add(e.id), '备份存在重复事项 ID');
  }
  for (final i in data.inventory) {
    require(stockIds.add(i.id), '备份存在重复库存 ID');
    textValue(i.name, '食材名称', max: 80);
    textValue(i.unit, '食材单位', max: 20);
    finiteValue(i.quantity, '库存', max: 10000000);
  }
  for (final e in data.events) {
    require(e.deductions.keys.every(stockIds.contains), '备份的库存扣减关联不完整');
  }
  for (final w in data.weights) {
    dateValue(w['date'], '体重记录日期');
    finiteValue(w['value'], '体重', min: 20, max: 400);
  }
  for (final s in data.sleeps) {
    textValue(s['id'], '睡眠记录 ID', max: 200);
    final start = dateValue(s['start'], '入睡时间');
    if (s['end'] != null) {
      final end = dateValue(s['end'], '起床时间');
      require(
        end.isAfter(start) && end.difference(start).inHours <= 48,
        '睡眠记录时间不合理',
      );
    }
  }
  require(
    data.sleeps.where((s) => s['end'] == null).length <= 1,
    '只能有一条尚未结束的睡眠记录',
  );
  require(
    data.sleeps.map((s) => s['id']).toSet().length == data.sleeps.length,
    '睡眠记录 ID 重复',
  );
  for (final h in data.habits) {
    textValue(h['title'], '习惯名称', max: 200);
    dateValue(h['date'], '习惯日期');
    if (h['completedAt'] != null) {
      dateValue(h['completedAt'], '习惯完成时间');
    }
  }
  require(
    ['light', 'dark', 'system'].contains(data.settings['theme']),
    '外观设置无效',
  );
  for (final key in ['sleepTime', 'wakeTime']) {
    final time = data.settings[key];
    require(
      time is String && RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(time),
      '作息目标时间无效',
    );
  }
  if (data.profile.isNotEmpty) {
    for (final key in [
      'name',
      'goals',
      'cooking',
      'training',
      'preferences',
      'allergies',
      'budget',
    ]) {
      if (data.profile[key] != null) {
        require(
          data.profile[key] is String &&
              (data.profile[key] as String).length <= 10000,
          '档案 $key 必须是文字',
        );
      }
    }
    finiteValue(data.profile['height'], '身高', min: 80, max: 250);
    finiteValue(data.profile['weight'], '体重', min: 20, max: 400);
    finiteValue(data.profile['age'], '年龄', min: 1, max: 120);
    finiteValue(data.profile['targetWeight'], '目标体重', min: 20, max: 400);
    require(['male', 'female'].contains(data.profile['sex']), '档案性别无效');
    finiteValue(data.profile['activity'], '活动系数', min: 1, max: 2.5);
  }
  return data;
}
