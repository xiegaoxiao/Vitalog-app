import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/controller.dart';
import '../data/models.dart';
import '../services/plan_import.dart';
import 'design.dart';

Future<void> editProfile(BuildContext context, AppController c) async {
  final p = c.data.profile;
  final keys = [
    'name',
    'height',
    'weight',
    'age',
    'targetWeight',
    'goals',
    'cooking',
    'training',
    'preferences',
    'allergies',
    'budget',
  ];
  final cs = {
    for (final key in keys)
      key: TextEditingController(
        text: p[key]?.toString() ?? (key == 'goals' ? '减脂、改善作息、均衡饮食' : ''),
      ),
  };
  var sex = p['sex'] as String? ?? 'male';
  var activity = number(p['activity']) ?? 1.2;
  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, set) => EditorDialog(
        title: '我的身体与生活条件',
        onSave: () async {
          final height = finiteValue(
            double.tryParse(cs['height']!.text),
            '身高',
            min: 80,
            max: 250,
          );
          final weight = finiteValue(
            double.tryParse(cs['weight']!.text),
            '体重',
            min: 20,
            max: 400,
          );
          final age = finiteValue(
            int.tryParse(cs['age']!.text),
            '年龄',
            min: 1,
            max: 120,
          );
          final target = finiteValue(
            double.tryParse(cs['targetWeight']!.text),
            '目标体重',
            min: 20,
            max: 400,
          );
          await c.mutate((d) {
            d.profile = {
              for (final key in keys) key: cs[key]!.text.trim(),
              'height': height,
              'weight': weight,
              'age': age.toInt(),
              'targetWeight': target,
              'sex': sex,
              'activity': activity,
            };
            if (d.weights.isEmpty) {
              d.weights.add({'date': dateKey(DateTime.now()), 'value': weight});
            }
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            field(cs['name']!, '昵称（可选）'),
            rowFields(
              field(cs['height']!, '身高 · cm', numeric: true),
              field(cs['weight']!, '体重 · kg', numeric: true),
            ),
            rowFields(
              field(cs['age']!, '年龄 · 周岁', numeric: true),
              field(cs['targetWeight']!, '目标体重 · kg', numeric: true),
            ),
            rowFields(
              DropdownButtonFormField<String>(
                initialValue: sex,
                decoration: const InputDecoration(labelText: '公式使用的性别'),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('男')),
                  DropdownMenuItem(value: 'female', child: Text('女')),
                ],
                onChanged: (v) => set(() => sex = v!),
              ),
              DropdownButtonFormField<double>(
                initialValue: activity,
                decoration: const InputDecoration(labelText: '日常活动量'),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 1.2, child: Text('久坐')),
                  DropdownMenuItem(value: 1.375, child: Text('轻度活动')),
                  DropdownMenuItem(value: 1.55, child: Text('中等活动')),
                  DropdownMenuItem(value: 1.725, child: Text('较多活动')),
                ],
                onChanged: (v) => set(() => activity = v!),
              ),
            ),
            const SizedBox(height: 12),
            field(cs['goals']!, '健康目标', lines: 2),
            field(cs['cooking']!, '做饭器具、冷藏条件与可用时间', lines: 2),
            field(cs['training']!, '训练经验、场地与运动限制', lines: 2),
            field(cs['preferences']!, '饮食偏好', lines: 2),
            field(cs['allergies']!, '过敏、饮食禁忌（可选）'),
            field(cs['budget']!, '饮食预算（可选）'),
            const Text(
              '身体指标由公式估算；活动量可随实际生活调整。',
              style: TextStyle(fontSize: 12, color: V.muted),
            ),
          ],
        ),
      ),
    ),
  );
  for (final t in cs.values) {
    t.dispose();
  }
}

Future<PlanItem?> editEvent(
  BuildContext context, {
  PlanItem? original,
  DateTime? day,
  AppController? controller,
}) async {
  final startDefault = day ?? DateTime.now();
  var start =
      original?.start ??
      DateTime(
        startDefault.year,
        startDefault.month,
        startDefault.day,
        DateTime.now().hour + 1,
      );
  var end = original?.end ?? start.add(const Duration(hours: 1));
  var kind = original?.kind ?? 'other',
      priority = original?.priority ?? 'normal';
  var reminder = original?.reminder ?? true, alarm = original?.alarm ?? false;
  var repeat = 'none';
  var repeatEnd = dayOf(start).add(const Duration(days: 28));
  final title = TextEditingController(text: original?.title ?? '');
  final lead = TextEditingController(
    text: (original?.leadMinutes ?? 0).toString(),
  );
  final details = TextEditingController(
    text: const JsonEncoder.withIndent('  ').convert(original?.details ?? {}),
  );
  PlanItem? saved;
  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, set) => EditorDialog(
        title: original == null ? '添加安排' : '修改安排',
        onSave: () async {
          final value = PlanItem(
            id: original?.id ?? newId(),
            kind: kind,
            title: title.text.trim(),
            start: start,
            end: end,
            priority: priority,
            reminder: reminder,
            alarm: alarm,
            leadMinutes: int.tryParse(lead.text) ?? -1,
            groupId: original?.groupId,
            details: object(jsonDecode(details.text), '详细内容'),
          );
          validateItem(value);
          if (controller != null) {
            if (repeat != 'none' && original == null) {
              require(
                !repeatEnd.isBefore(dayOf(start)) &&
                    repeatEnd.difference(dayOf(start)).inDays <= 366,
                '重复周期最多一年',
              );
              final group = newId();
              final items = <PlanItem>[];
              for (
                var date = dayOf(start);
                !date.isAfter(repeatEnd);
                date = date.add(const Duration(days: 1))
              ) {
                if (repeat == 'weekly' && date.weekday != start.weekday) {
                  continue;
                }
                final item = value.copy();
                final delta = date.difference(dayOf(start));
                items.add(
                  PlanItem(
                    id: newId(),
                    kind: item.kind,
                    title: item.title,
                    start: item.start.add(delta),
                    end: item.end.add(delta),
                    priority: item.priority,
                    reminder: item.reminder,
                    leadMinutes: item.leadMinutes,
                    alarm: item.alarm,
                    groupId: group,
                    details: cloneJson(item.details),
                  ),
                );
              }
              await controller.mutate((d) => d.events.addAll(items));
            } else {
              await controller.saveEvent(value);
            }
          }
          saved = value;
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            field(title, '名称'),
            DropdownButtonFormField<String>(
              initialValue: kind,
              decoration: const InputDecoration(labelText: '模块'),
              items: kinds
                  .map(
                    (k) =>
                        DropdownMenuItem(value: k, child: Text(kindNames[k]!)),
                  )
                  .toList(),
              onChanged: (v) => set(() => kind = v!),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final d = await chooseDateTime(context, start);
                if (d != null) {
                  set(() => start = d);
                }
              },
              icon: const Icon(Icons.schedule),
              label: Text('开始 ${dateKey(start)} ${clock(start)}'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final d = await chooseDateTime(context, end);
                if (d != null) {
                  set(() => end = d);
                }
              },
              icon: const Icon(Icons.schedule),
              label: Text('结束 ${dateKey(end)} ${clock(end)}'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: priority,
              decoration: const InputDecoration(labelText: '提醒等级'),
              items: priorities
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text(priorityNames[p]!),
                    ),
                  )
                  .toList(),
              onChanged: (v) => set(() => priority = v!),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('发送提醒'),
              subtitle: const Text('安静等级只在计划中显示'),
              value: reminder,
              onChanged: (v) => set(() => reminder = v),
            ),
            field(lead, '提前提醒 · 分钟', numeric: true),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('添加闹钟'),
              subtitle: const Text('开启后到点响铃，需手动关闭'),
              value: alarm,
              onChanged: reminder && priority != 'quiet'
                  ? (v) => set(() => alarm = v)
                  : null,
            ),
            if (original == null && controller != null) ...[
              DropdownButtonFormField<String>(
                initialValue: repeat,
                decoration: const InputDecoration(labelText: '重复方式'),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('不重复')),
                  DropdownMenuItem(value: 'daily', child: Text('每天')),
                  DropdownMenuItem(value: 'weekly', child: Text('每周同一天')),
                ],
                onChanged: (v) => set(() => repeat = v!),
              ),
              if (repeat != 'none')
                TextButton(
                  onPressed: () async {
                    final d = await chooseDate(context, repeatEnd);
                    if (d != null) {
                      set(() => repeatEnd = d);
                    }
                  },
                  child: Text('重复至 ${dateKey(repeatEnd)}'),
                ),
            ],
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('详细内容'),
              subtitle: const Text('菜谱、动作和备注，可修改 JSON 内容'),
              children: [field(details, 'details · JSON', lines: 10)],
            ),
          ],
        ),
      ),
    ),
  );
  title.dispose();
  lead.dispose();
  details.dispose();
  return saved;
}

Future<void> editInventory(
  BuildContext context,
  AppController c, {
  InventoryItem? original,
}) async {
  final name = TextEditingController(text: original?.name ?? '');
  final quantity = TextEditingController(
    text: original?.quantity.toString() ?? '',
  );
  final unit = TextEditingController(text: original?.unit ?? 'g');
  await showDialog(
    context: context,
    builder: (context) => EditorDialog(
      title: original == null ? '添加食材' : '调整食材',
      onSave: () async {
        final n = textValue(name.text, '食材名称', max: 80);
        final q = finiteValue(
          double.tryParse(quantity.text),
          '库存',
          max: 10000000,
        );
        final u = textValue(unit.text, '单位', max: 20);
        if (original != null &&
            c.data.events.any((e) => e.deductions.containsKey(original.id))) {
          require(
            n == original.name &&
                normalizeQuantity(1, u).unit ==
                    normalizeQuantity(1, original.unit).unit,
            '该食材已有扣减记录，请保留名称与原单位；可添加另一种食材',
          );
          require(u == original.unit, '已有扣减记录的库存请保持原单位');
        }
        await c.mutate((d) {
          final index = d.inventory.indexWhere((i) => i.id == original?.id);
          final item = InventoryItem(
            id: original?.id ?? newId(),
            name: n,
            quantity: q,
            unit: u,
          );
          if (index < 0) {
            d.inventory.add(item);
          } else {
            d.inventory[index] = item;
          }
        });
      },
      child: Column(
        children: [
          field(name, '食材名称'),
          rowFields(
            field(quantity, '当前剩余量', numeric: true),
            field(unit, '单位 · g / ml / 枚 / 个'),
          ),
          const Text(
            '与菜谱使用相同名称；支持 kg、斤、g 和 l、ml 换算。鸡蛋等计数食材请统一使用“枚”或“个”。',
            style: TextStyle(fontSize: 12, color: V.muted),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  quantity.dispose();
  unit.dispose();
}

Future<void> logMeal(
  BuildContext context,
  AppController c,
  PlanItem event,
) async {
  final base = event.completed ? event.actual : event.details;
  final title = TextEditingController(
    text: base['title'] as String? ?? event.title,
  );
  final nutrients = {
    for (final key in nutrientKeys)
      key: TextEditingController(
        text: number((base['nutrition'] as Map? ?? {})[key])?.toString() ?? '',
      ),
  };
  final ingredients = ((base['ingredients'] ?? []) as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  final ingredientCs = ingredients
      .map(
        (i) => [
          TextEditingController(text: i['name'] as String),
          TextEditingController(text: i['quantity'].toString()),
          TextEditingController(text: i['unit'] as String),
        ],
      )
      .toList();
  var deduct = !event.completed || event.deductions.isNotEmpty;
  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, set) => EditorDialog(
        title: event.completed ? '修改实际餐食' : '记录这餐 · 实际吃了什么',
        label: event.completed ? '保存实际记录' : '按实际餐食打卡',
        onSave: () async {
          final actual = <String, dynamic>{
            'title': textValue(title.text, '实际餐食名称', max: 200),
            'nutrition': {
              for (final key in nutrientKeys)
                key: nutrients[key]!.text.trim().isEmpty
                    ? null
                    : finiteValue(
                        double.tryParse(nutrients[key]!.text),
                        nutrientNames[key]!,
                      ),
            },
            'ingredients': ingredientCs
                .map(
                  (cs) => {
                    'name': textValue(cs[0].text, '食材名称', max: 80),
                    'quantity': finiteValue(
                      double.tryParse(cs[1].text),
                      '实际用量',
                    ),
                    'unit': textValue(cs[2].text, '单位', max: 20),
                  },
                )
                .toList(),
          };
          if (event.completed) {
            await c.reviseActual(event.id, actual, deduct);
          } else {
            await c.complete(event.id, actual: actual, deduct: deduct);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            field(title, '实际餐食名称'),
            const Text(
              '默认按计划填写；改吃了别的，可替换食材与营养。未知营养留空。',
              style: TextStyle(fontSize: 12, color: V.muted, height: 1.8),
            ),
            const SizedBox(height: 12),
            rowFields(
              field(nutrients['calories']!, '热量 · kcal', numeric: true),
              field(nutrients['protein']!, '蛋白质 · g', numeric: true),
            ),
            rowFields(
              field(nutrients['carbs']!, '碳水 · g', numeric: true),
              field(nutrients['fat']!, '脂肪 · g', numeric: true),
            ),
            const Text('实际食材用量', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            for (var i = 0; i < ingredientCs.length; i++)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: field(ingredientCs[i][0], '食材')),
                  const SizedBox(width: 6),
                  Expanded(
                    child: field(ingredientCs[i][1], '用量', numeric: true),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: field(ingredientCs[i][2], '单位')),
                  IconButton(
                    onPressed: () => set(() {
                      final cs = ingredientCs.removeAt(i);
                      for (final v in cs) {
                        v.dispose();
                      }
                    }),
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: '移除食材',
                  ),
                ],
              ),
            TextButton.icon(
              onPressed: () => set(
                () => ingredientCs.add([
                  TextEditingController(),
                  TextEditingController(),
                  TextEditingController(text: 'g'),
                ]),
              ),
              icon: const Icon(Icons.add),
              label: const Text('添加实际食材'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('本餐扣除库存'),
              subtitle: const Text('库存不足时会提示，可关闭后只记录餐食'),
              value: deduct,
              onChanged: (v) => set(() => deduct = v),
            ),
          ],
        ),
      ),
    ),
  );
  title.dispose();
  for (final t in nutrients.values) {
    t.dispose();
  }
  for (final cs in ingredientCs) {
    for (final t in cs) {
      t.dispose();
    }
  }
}

Future<void> logWeight(
  BuildContext context,
  AppController c, {
  Json? original,
}) async {
  var date = original == null
      ? DateTime.now()
      : DateTime.parse(original['date'] as String);
  final value = TextEditingController(
    text: (original?['value'] ?? c.data.currentWeight)?.toString() ?? '',
  );
  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, set) => EditorDialog(
        title: '记录体重',
        onSave: () async {
          final weight = finiteValue(
            double.tryParse(value.text),
            '体重',
            min: 20,
            max: 400,
          );
          await c.mutate((d) {
            if (original != null) {
              d.weights.removeWhere((w) => w['date'] == original['date']);
            }
            d.weights.removeWhere((w) => w['date'] == dateKey(date));
            d.weights.add({'date': dateKey(date), 'value': weight});
          });
        },
        child: Column(
          children: [
            field(value, '体重 · kg', numeric: true),
            OutlinedButton.icon(
              onPressed: () async {
                final v = await chooseDate(context, date);
                if (v != null) {
                  set(() => date = v);
                }
              },
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(dateKey(date)),
            ),
            const SizedBox(height: 10),
            const Text(
              '同一天保留一条记录；每周平均值只使用实际记录。',
              style: TextStyle(fontSize: 12, color: V.muted),
            ),
          ],
        ),
      ),
    ),
  );
  value.dispose();
}

Future<void> editSleep(
  BuildContext context,
  AppController c, {
  Json? original,
}) async {
  var start = original == null
      ? DateTime.now().subtract(const Duration(hours: 8))
      : DateTime.parse(original['start'] as String);
  var end = original?['end'] == null
      ? DateTime.now()
      : DateTime.parse(original!['end'] as String);
  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, set) => EditorDialog(
        title: '补填或修改睡眠记录',
        onSave: () async {
          require(
            end.isAfter(start) && end.difference(start).inHours <= 48,
            '起床需晚于准备睡觉时间，间隔不超过 48 小时',
          );
          await c.mutate((d) {
            final id = original?['id'] ?? newId();
            final overlaps = d.sleeps.where(
              (s) =>
                  s['id'] != id &&
                  s['end'] != null &&
                  start.isBefore(DateTime.parse(s['end'] as String)) &&
                  end.isAfter(DateTime.parse(s['start'] as String)),
            );
            require(overlaps.isEmpty, '与已有睡眠记录重叠，请修改时间');
            d.sleeps.removeWhere((s) => s['id'] == id);
            d.sleeps.add({
              'id': id,
              'start': start.toIso8601String(),
              'end': end.toIso8601String(),
            });
          });
        },
        child: Column(
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final v = await chooseDateTime(context, start);
                if (v != null) {
                  set(() => start = v);
                }
              },
              icon: const Icon(Icons.bedtime_outlined),
              label: Text('准备睡觉 ${dateKey(start)} ${clock(start)}'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final v = await chooseDateTime(context, end);
                if (v != null) {
                  set(() => end = v);
                }
              },
              icon: const Icon(Icons.wb_sunny_outlined),
              label: Text('已起床 ${dateKey(end)} ${clock(end)}'),
            ),
            const SizedBox(height: 12),
            const Text(
              '记录的是两次操作之间的间隔，可事后调整时间。',
              style: TextStyle(fontSize: 12, color: V.muted),
            ),
          ],
        ),
      ),
    ),
  );
}
