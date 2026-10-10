import 'dart:convert';
import 'dart:math';

typedef Json = Map<String, dynamic>;

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
String clock(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
int _sequence = 0;
String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
Json cloneJson(Json json) => jsonDecode(jsonEncode(json)) as Json;
double? number(dynamic v) => v is num && v.isFinite ? v.toDouble() : null;
const kinds = ['meal', 'workout', 'course', 'meeting', 'habit', 'other'];
const kindNames = {
  'meal': '饮食',
  'workout': '训练',
  'course': '课程',
  'meeting': '组会',
  'habit': '习惯',
  'other': '日程',
};
const priorities = ['important', 'normal', 'quiet'];
const priorityNames = {'important': '重要', 'normal': '普通', 'quiet': '安静'};
const nutrientKeys = ['calories', 'protein', 'carbs', 'fat'];
const nutrientNames = {
  'calories': '热量',
  'protein': '蛋白质',
  'carbs': '碳水',
  'fat': '脂肪',
};

class PlanItem {
  PlanItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.start,
    required this.end,
    this.priority = 'normal',
    this.reminder = true,
    this.leadMinutes = 0,
    this.alarm = false,
    this.groupId,
    Json? details,
    this.completedAt,
    Json? actual,
    Json? deductions,
  }) : details = details ?? {},
       actual = actual ?? {},
       deductions = deductions ?? {};
  final String id;
  String kind;
  String title;
  DateTime start;
  DateTime end;
  String priority;
  bool reminder;
  int leadMinutes;
  bool alarm;
  String? groupId;
  Json details;
  DateTime? completedAt;
  Json actual;
  Json deductions;
  bool get completed => completedAt != null;
  bool get fixed => kind == 'course' || kind == 'meeting';
  List<Json> get ingredients => ((details['ingredients'] ?? []) as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  List<Json> get exercises => ((details['exercises'] ?? []) as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  Json get nutrition =>
      Map<String, dynamic>.from((details['nutrition'] ?? {}) as Map);
  Json toJson() => {
    'id': id,
    'kind': kind,
    'title': title,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'priority': priority,
    'reminder': reminder,
    'leadMinutes': leadMinutes,
    'alarm': alarm,
    'groupId': groupId,
    'details': details,
    'completedAt': completedAt?.toIso8601String(),
    'actual': actual,
    'deductions': deductions,
  };
  factory PlanItem.fromJson(Json j) => PlanItem(
    id: j['id'] as String,
    kind: j['kind'] as String,
    title: j['title'] as String,
    start: DateTime.parse(j['start'] as String).toLocal(),
    end: DateTime.parse(j['end'] as String).toLocal(),
    priority: j['priority'] as String? ?? 'normal',
    reminder: j['reminder'] as bool? ?? true,
    leadMinutes: (j['leadMinutes'] as num?)?.toInt() ?? 0,
    alarm: j['alarm'] as bool? ?? false,
    groupId: j['groupId'] as String?,
    details: Map<String, dynamic>.from(j['details'] as Map? ?? {}),
    completedAt: j['completedAt'] == null
        ? null
        : DateTime.parse(j['completedAt'] as String),
    actual: Map<String, dynamic>.from(j['actual'] as Map? ?? {}),
    deductions: Map<String, dynamic>.from(j['deductions'] as Map? ?? {}),
  );
  PlanItem copy() => PlanItem.fromJson(cloneJson(toJson()));
}

class InventoryItem {
  InventoryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
  });
  final String id;
  String name;
  double quantity;
  String unit;
  Json toJson() => {'id': id, 'name': name, 'quantity': quantity, 'unit': unit};
  factory InventoryItem.fromJson(Json j) => InventoryItem(
    id: j['id'] as String,
    name: j['name'] as String,
    quantity: (j['quantity'] as num).toDouble(),
    unit: j['unit'] as String,
  );
}

class AppData {
  AppData({
    Json? profile,
    List<PlanItem>? events,
    List<InventoryItem>? inventory,
    List<Json>? weights,
    List<Json>? sleeps,
    List<Json>? habits,
    Json? settings,
    this.demo = false,
  }) : profile = profile ?? {},
       events = events ?? [],
       inventory = inventory ?? [],
       weights = weights ?? [],
       sleeps = sleeps ?? [],
       habits = habits ?? [],
       settings =
           settings ??
           {
             'theme': 'light',
             'appearance': 'classic',
             'sleepTime': '23:00',
             'wakeTime': '07:00',
           };
  Json profile;
  List<PlanItem> events;
  List<InventoryItem> inventory;
  List<Json> weights;
  List<Json> sleeps;
  List<Json> habits;
  Json settings;
  bool demo;
  Json toJson() => {
    'schemaVersion': 1,
    'profile': profile,
    'events': events.map((e) => e.toJson()).toList(),
    'inventory': inventory.map((e) => e.toJson()).toList(),
    'weights': weights,
    'sleeps': sleeps,
    'habits': habits,
    'settings': settings,
    'demo': demo,
  };
  factory AppData.fromJson(Json j) {
    if (j['schemaVersion'] != 1) {
      throw const FormatException('备份版本不受支持');
    }
    return AppData(
      profile: Map<String, dynamic>.from(j['profile'] as Map),
      events: (j['events'] as List)
          .map((e) => PlanItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      inventory: (j['inventory'] as List)
          .map(
            (e) => InventoryItem.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      weights: (j['weights'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      sleeps: (j['sleeps'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      habits: (j['habits'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      settings: Map<String, dynamic>.from(j['settings'] as Map),
      demo: j['demo'] == true,
    );
  }
  AppData copy() => AppData.fromJson(cloneJson(toJson()));
  List<PlanItem> onDay(DateTime day) =>
      events.where((e) => dateKey(e.start) == dateKey(day)).toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  double? get currentWeight {
    if (weights.isEmpty) {
      return number(profile['weight']);
    }
    final sorted = [...weights]
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return number(sorted.last['value']);
  }

  double? get bmi {
    final h = number(profile['height']);
    final w = currentWeight;
    return h == null || w == null || h <= 0 ? null : w / pow(h / 100, 2);
  }

  double? get bmr {
    final h = number(profile['height']);
    final w = currentWeight;
    final age = number(profile['age']);
    final sex = profile['sex'];
    if (h == null ||
        w == null ||
        age == null ||
        age < 18 ||
        (sex != 'male' && sex != 'female')) {
      return null;
    }
    return 10 * w + 6.25 * h - 5 * age + (sex == 'male' ? 5 : -161);
  }

  double? get tdee =>
      bmr == null ? null : bmr! * (number(profile['activity']) ?? 1.2);
  double? weekAverage(DateTime until) {
    final records = weights.where((e) {
      final date = dayOf(DateTime.parse(e['date'] as String));
      return !date.isAfter(dayOf(until)) &&
          date.isAfter(dayOf(until).subtract(const Duration(days: 7)));
    }).toList();
    if (records.isEmpty) {
      return null;
    }
    return records.map((e) => number(e['value'])!).reduce((a, b) => a + b) /
        records.length;
  }
}

class Quantity {
  Quantity(this.value, this.unit);
  final double value;
  final String unit;
}

Quantity normalizeQuantity(double value, String unit) {
  switch (unit.trim().toLowerCase()) {
    case 'kg':
    case '千克':
    case '公斤':
      return Quantity(value * 1000, 'g');
    case '斤':
      return Quantity(value * 500, 'g');
    case '克':
    case 'g':
      return Quantity(value, 'g');
    case 'l':
    case '升':
      return Quantity(value * 1000, 'ml');
    case '毫升':
    case 'ml':
      return Quantity(value, 'ml');
    default:
      return Quantity(value, unit.trim());
  }
}

String foodName(String s) => s.trim().replaceAll(RegExp(r'\s'), '');

// An unknown nutrient stays unknown, including when an incomplete daily total is shown.
double? nutrientTotal(Iterable<Json> records, String key) {
  final values = records.toList();
  if (values.isEmpty) {
    return null;
  }
  if (values.any((n) => number(n[key]) == null)) {
    return null;
  }
  return values.map((n) => number(n[key])!).reduce((a, b) => a + b);
}

Map<String, double> prepareDeductions(AppData data, List<Json> ingredients) {
  final wanted = <String, double>{};
  for (final ingredient in ingredients) {
    final amount = number(ingredient['quantity']);
    if (amount == null || amount < 0) {
      throw const FormatException('食材用量必须为非负数');
    }
    if (amount == 0) {
      continue;
    }
    final need = normalizeQuantity(amount, ingredient['unit'] as String);
    final matches = data.inventory
        .where(
          (s) =>
              foodName(s.name) == foodName(ingredient['name'] as String) &&
              normalizeQuantity(s.quantity, s.unit).unit == need.unit,
        )
        .toList();
    var remaining = need.value;
    for (final stock in matches) {
      final factor = normalizeQuantity(1, stock.unit).value;
      final available =
          stock.quantity * factor - (wanted[stock.id] ?? 0) * factor;
      final take = min(max(available, 0), remaining);
      wanted[stock.id] = (wanted[stock.id] ?? 0) + take / factor;
      remaining -= take;
      if (remaining < 0.000001) {
        break;
      }
    }
    if (remaining > 0.000001) {
      throw FormatException(
        '${ingredient['name']} 库存不足，还缺 ${remaining.toStringAsFixed(1)} ${need.unit}；补充库存或关闭本餐扣库存',
      );
    }
  }
  return wanted;
}

List<Json> shoppingList(AppData data, DateTime start, DateTime end) {
  final sums = <String, Json>{};
  for (final event in data.events.where(
    (e) =>
        e.kind == 'meal' &&
        !e.completed &&
        !dayOf(e.start).isBefore(dayOf(start)) &&
        !dayOf(e.start).isAfter(dayOf(end)),
  )) {
    for (final i in event.ingredients) {
      final normalized = normalizeQuantity(
        number(i['quantity']) ?? 0,
        i['unit'] as String,
      );
      final key = '${foodName(i['name'] as String)}:${normalized.unit}';
      sums.putIfAbsent(
        key,
        () => {'name': i['name'], 'unit': normalized.unit, 'need': 0.0},
      );
      sums[key]!['need'] = (sums[key]!['need'] as double) + normalized.value;
    }
  }
  return sums.values.map((i) {
    final owned = data.inventory
        .where((s) => foodName(s.name) == foodName(i['name'] as String))
        .map((s) => normalizeQuantity(s.quantity, s.unit))
        .where((s) => s.unit == i['unit'])
        .fold(0.0, (sum, q) => sum + q.value);
    return {
      ...i,
      'owned': owned,
      'missing': max(0.0, (i['need'] as double) - owned),
    };
  }).toList()..sort(
    (a, b) => (b['missing'] as double).compareTo(a['missing'] as double),
  );
}
