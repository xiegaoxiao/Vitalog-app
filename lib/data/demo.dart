import 'models.dart';

AppData demoData(DateTime now) {
  final today = dayOf(now);
  DateTime at(int h, int m) => today.add(Duration(hours: h, minutes: m));
  final data = AppData(
    demo: true,
    profile: {
      'name': '元气同学',
      'height': 172.0,
      'weight': 72.0,
      'age': 25,
      'sex': 'male',
      'targetWeight': 68.0,
      'activity': 1.375,
      'goals': '减脂、改善作息、均衡饮食',
      'cooking': '宿舍小锅，有冷藏室；每餐尽量 20 分钟以内',
      'training': '健身入门，学校健身房',
      'preferences': '做法简单，土豆、红薯、燕麦替代米饭',
      'allergies': '',
      'budget': '按需填写',
    },
  );
  data.inventory = [
    InventoryItem(id: 'stock-potato', name: '土豆', quantity: 1500, unit: 'g'),
    InventoryItem(id: 'stock-chicken', name: '鸡胸肉', quantity: 500, unit: 'g'),
    InventoryItem(id: 'stock-greens', name: '小白菜', quantity: 1000, unit: 'g'),
    InventoryItem(id: 'stock-egg', name: '鸡蛋', quantity: 30, unit: '枚'),
    InventoryItem(id: 'stock-tomato', name: '西红柿', quantity: 1000, unit: 'g'),
    InventoryItem(id: 'stock-oats', name: '燕麦', quantity: 1000, unit: 'g'),
  ];
  for (var d = -6; d <= 7; d++) {
    final day = today.add(Duration(days: d));
    if (d <= 0) {
      data.weights.add({'date': dateKey(day), 'value': 72.5 - d * .05});
    }
    if (d < 0) {
      data.sleeps.add({
        'id': newId(),
        'start': day
            .subtract(const Duration(days: 1))
            .add(const Duration(hours: 23, minutes: 20))
            .toIso8601String(),
        'end': day.add(const Duration(hours: 7, minutes: 30)).toIso8601String(),
      });
      continue;
    }
    data.events.add(
      PlanItem(
        id: 'demo-meal-$d',
        kind: 'meal',
        title: '土豆鸡胸肉蔬菜汤',
        start: day.add(const Duration(hours: 12)),
        end: day.add(const Duration(hours: 12, minutes: 30)),
        priority: 'quiet',
        reminder: false,
        details: {
          'slot': '午餐',
          'minutes': 20,
          'nutrition': {
            'calories': 520.0,
            'protein': 42.0,
            'carbs': 63.0,
            'fat': 11.0,
          },
          'ingredients': [
            {'name': '土豆', 'quantity': 300.0, 'unit': 'g'},
            {'name': '鸡胸肉', 'quantity': 150.0, 'unit': 'g'},
            {'name': '小白菜', 'quantity': 200.0, 'unit': 'g'},
          ],
          'steps': [
            '土豆洗净切小块，放入小锅煮软。',
            '加入切薄片的鸡胸肉，充分煮熟。',
            '加入小白菜，煮熟后用少量酱油、盐调味。',
          ],
          'notes': '示例营养数据仅用于体验界面，请以你导入的计划为准。',
        },
      ),
    );
    data.events.add(
      PlanItem(
        id: 'demo-dinner-$d',
        kind: 'meal',
        title: '番茄鸡蛋汤 · 即食玉米',
        start: day.add(const Duration(hours: 18, minutes: 30)),
        end: day.add(const Duration(hours: 19)),
        priority: 'quiet',
        reminder: false,
        details: {
          'slot': '晚餐',
          'minutes': 15,
          'nutrition': {
            'calories': 480.0,
            'protein': 28.0,
            'carbs': 56.0,
            'fat': 16.0,
          },
          'ingredients': [
            {'name': '西红柿', 'quantity': 200.0, 'unit': 'g'},
            {'name': '鸡蛋', 'quantity': 2.0, 'unit': '枚'},
            {'name': '玉米', 'quantity': 250.0, 'unit': 'g'},
          ],
          'steps': ['西红柿洗净切块，放入锅中煮软。', '打入鸡蛋并煮熟，配按包装说明加热的即食玉米。'],
        },
      ),
    );
  }
  data.events.add(
    PlanItem(
      id: 'demo-course',
      kind: 'course',
      title: '软件需求工程',
      start: at(10, 20),
      end: at(11, 50),
      priority: 'important',
      leadMinutes: 15,
      details: {'location': '教学楼 A · 302'},
    ),
  );
  data.events.add(
    PlanItem(
      id: 'demo-training',
      kind: 'workout',
      title: '全身力量 · 训练 A',
      start: at(16, 30),
      end: at(17, 30),
      details: {
        'notes': '先热身，再按自己的能力选择重量。',
        'exercises': [
          {
            'name': '坐姿腿举',
            'sets': 2,
            'reps': 12,
            'weight': null,
            'rest_seconds': 90,
            'notes': '缓慢下放，膝盖保持自然。',
          },
          {
            'name': '坐姿推胸',
            'sets': 2,
            'reps': 10,
            'weight': null,
            'rest_seconds': 90,
            'notes': '肩膀稳定，推起时呼气。',
          },
          {
            'name': '高位下拉',
            'sets': 2,
            'reps': 12,
            'weight': null,
            'rest_seconds': 90,
            'notes': '避免身体大幅后仰。',
          },
          {
            'name': '平板支撑',
            'sets': 2,
            'seconds': 30,
            'rest_seconds': 60,
            'notes': '保持身体稳定。',
          },
        ],
      },
    ),
  );
  data.events.add(
    PlanItem(
      id: 'demo-sleep',
      kind: 'habit',
      title: '准备睡觉',
      start: at(23, 0),
      end: at(23, 10),
    ),
  );
  return data;
}
