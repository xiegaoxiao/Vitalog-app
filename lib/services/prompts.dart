import 'dart:convert';

import '../data/models.dart';

Json planExample(DateTime day, {String kind = 'meal'}) {
  final start = DateTime(
    day.year,
    day.month,
    day.day,
    kind == 'meal' ? 12 : 17,
  );
  final detail = kind == 'meal'
      ? <String, dynamic>{
          'slot': '午餐',
          'nutrition': {
            'calories': null,
            'protein': null,
            'carbs': null,
            'fat': null,
          },
          'ingredients': [
            {'name': '土豆', 'quantity': 300, 'unit': 'g'},
            {'name': '鸡胸肉', 'quantity': 150, 'unit': 'g'},
            {'name': '小白菜', 'quantity': 200, 'unit': 'g'},
          ],
          'steps': ['土豆洗净切块，放入锅中煮软。', '加入切薄片的鸡肉并煮熟，再放入蔬菜和调味料。'],
          'minutes': 20,
          'notes': '示例只说明格式，营养由 AI 按实际用量估算。',
        }
      : kind == 'workout'
      ? <String, dynamic>{
          'exercises': [
            {
              'name': '坐姿推胸',
              'sets': 2,
              'reps': 10,
              'weight': null,
              'rest_seconds': 90,
              'notes': '选适合自己的重量，保持动作稳定。',
            },
          ],
          'notes': '根据你的场地和身体条件修改。',
        }
      : <String, dynamic>{'notes': '示例安排'};
  return {
    'schemaVersion': 1,
    'range': {'start': dateKey(day), 'end': dateKey(day)},
    'modules': [kind],
    'events': [
      {
        'id': '${dateKey(day)}-$kind-1',
        'kind': kind,
        'title': kind == 'meal'
            ? '土豆鸡胸肉蔬菜汤'
            : kind == 'workout'
            ? '全身训练 A'
            : '日程安排',
        'start': start.toIso8601String(),
        'end': start
            .add(Duration(minutes: kind == 'meal' ? 30 : 60))
            .toIso8601String(),
        'priority': 'normal',
        'reminder': kind != 'meal',
        'leadMinutes': 0,
        'alarm': false,
        'details': detail,
      },
    ],
  };
}

String buildPrompt(
  AppData data,
  DateTime start,
  DateTime end,
  String module,
  bool includeHistory,
) {
  final context = <String, dynamic>{
    'profile': {...data.profile, 'currentWeight': data.currentWeight},
    'inventory': data.inventory.map((e) => e.toJson()).toList(),
    'fixedSchedule': data.events
        .where(
          (e) =>
              e.fixed &&
              !dayOf(e.start).isBefore(start) &&
              !dayOf(e.start).isAfter(end),
        )
        .map(
          (e) => {
            'title': e.title,
            'start': e.start.toIso8601String(),
            'end': e.end.toIso8601String(),
            'location': e.details['location'],
          },
        )
        .toList(),
    'sleepPreferences': {
      'sleepTime': data.settings['sleepTime'],
      'wakeTime': data.settings['wakeTime'],
    },
  };
  if (includeHistory) {
    final since = DateTime.now().subtract(const Duration(days: 7));
    context['lastWeek'] = {
      'weights': data.weights
          .where((e) => DateTime.parse(e['date'] as String).isAfter(since))
          .toList(),
      'sleep': data.sleeps
          .where((e) => DateTime.parse(e['start'] as String).isAfter(since))
          .toList(),
      'executed': data.events
          .where((e) => e.completed && e.completedAt!.isAfter(since))
          .map(
            (e) => {
              'kind': e.kind,
              'title': e.title,
              'plannedStart': e.start.toIso8601String(),
              'completedAt': e.completedAt!.toIso8601String(),
              'actual': e.actual,
            },
          )
          .toList(),
      'habits': data.habits
          .where((e) => DateTime.parse(e['date'] as String).isAfter(since))
          .toList(),
    };
  }
  return '''请为我制定 ${dateKey(start)} 至 ${dateKey(end)} 的${module == 'all' ? '作息、饮食、训练与习惯综合' : kindNames[module]}计划，供元气簿 Vitalog 导入。
我的信息与限制（可向我追问缺失的关键条件）：
${const JsonEncoder.withIndent('  ').convert(context)}

要求：
1. 结合目标、预算、饮食禁忌、做饭器具、储存条件、已有食材、训练经验与场地；避开课程和固定安排，留出通勤、做饭和休息时间。
2. 饮食尽量简单，提供食材重量与单位、步骤、耗时、每餐估算热量 kcal、蛋白质/碳水/脂肪 g。不能可靠估算则填 null，禁止将缺失值填 0。不要把所有人的目标热量固定为一个数。
3. 训练提供动作名称、组数、次数或计时（seconds）、重量（未知填 null）、休息秒数和动作要点；安排循序渐进和恢复，不依据 BMI 直接制定高强度训练。
4. 提醒 priority 使用 important / normal / quiet：课程和组会通常 important，提前 15 分钟；训练 normal；饮食通常 quiet 且 reminder=false。alarm 默认 false，交给我决定。
5. 不修改已经发生的执行记录，不自动改变固定课程。综合计划用 modules 声明要更新的类型；只生成所需的模块。
6. 每个安排输出独立日期时间，展开重复日程；start/end 使用 ISO 8601 并写明 +08:00（我在中国），end 晚于 start。所有事项的开始日期在声明周期内；id 必须唯一、稳定。
7. 如信息不足或存在运动限制，先说明并询问我；输出计划前核对日程冲突、食材用量与每日营养总量。导入格式只接受可解析的 JSON，不包含注释。

仅返回以下结构的 JSON（示例中的日期、内容和 null 按真实计划替换，食材单位优先 g/ml/枚/个）：
${const JsonEncoder.withIndent('  ').convert(planExample(start, kind: module == 'all' ? 'meal' : module))}
range.end 改成 ${dateKey(end)}。modules 可包含 meal/workout/course/meeting/habit/other。details 根据类型填写：饮食 nutrition/ingredients/steps/minutes/slot；训练 exercises/notes；课程 location/notes；习惯 notes。不要输出 completedAt/actual/deductions，这些由我执行后记录。''';
}
