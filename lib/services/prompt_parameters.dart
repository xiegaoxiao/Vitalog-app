import '../data/models.dart';

/// Editable planning constraints, separate from measured health records.
class PromptParameter {
  const PromptParameter(
    this.key,
    this.label,
    this.group, {
    this.min,
    this.max,
    this.integer = false,
    this.time = false,
    this.initial = '',
  });
  final String key, label, group, initial;
  final double? min, max;
  final bool integer, time;
  bool get numeric => min != null;
  bool get multiline => !numeric && !time;
  String get inputLabel => switch (key) {
    'mealMinutes' => '做饭上限 · 分钟',
    'sessionMinutes' => '单次时长 · 分钟',
    'commuteMinutes' => '前后预留 · 分钟',
    'importantLeadMinutes' => '提前提醒 · 分钟',
    'breakfast' => '早餐时间',
    'lunch' => '午餐时间',
    'dinner' => '晚餐时间',
    'sleepTime' => '准备睡觉',
    'wakeTime' => '起床时间',
    _ => label,
  };

  String? validate(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return null;
    if (time && !RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(text)) {
      return '请用 HH:mm，例如 07:30';
    }
    if (numeric) {
      final value = num.tryParse(text);
      if (value == null || !value.isFinite) return '请输入有效数字';
      if (integer && value != value.roundToDouble()) return '请输入整数';
      if (value < min! || value > max!) {
        return '范围 ${min!.toStringAsFixed(0)}–${max!.toStringAsFixed(0)}';
      }
    }
    return text.length > 2000 ? '最多 2000 个字' : null;
  }

  dynamic parse(String? raw) {
    final error = validate(raw);
    if (error != null) throw FormatException('$label：$error');
    final text = (raw ?? '').trim();
    if (text.isEmpty) return null;
    if (!numeric) return text;
    return integer ? num.parse(text).toInt() : num.parse(text);
  }
}

const promptParameters = [
  PromptParameter('goals', '健康目标', 'profile'),
  PromptParameter('height', '身高 · cm', 'profile', min: 80, max: 250),
  PromptParameter('weight', '当前体重 · kg', 'profile', min: 20, max: 400),
  PromptParameter('age', '年龄 · 周岁', 'profile', min: 1, max: 120, integer: true),
  PromptParameter('targetWeight', '目标体重 · kg', 'profile', min: 20, max: 400),
  PromptParameter('calories', '每日热量 · kcal', 'meal', min: 1, max: 20000),
  PromptParameter('protein', '每日蛋白质 · g', 'meal', min: 0, max: 2000),
  PromptParameter('carbs', '每日碳水 · g', 'meal', min: 0, max: 2000),
  PromptParameter('fat', '每日脂肪 · g', 'meal', min: 0, max: 2000),
  PromptParameter('dailyBudget', '每日预算 · 元', 'meal', min: 0, max: 10000),
  PromptParameter(
    'mealsPerDay',
    '每日餐数',
    'meal',
    min: 1,
    max: 10,
    integer: true,
  ),
  PromptParameter('servings', '用餐人数', 'meal', min: 1, max: 20, integer: true),
  PromptParameter(
    'mealMinutes',
    '每餐做饭上限 · 分钟',
    'meal',
    min: 1,
    max: 300,
    integer: true,
  ),
  PromptParameter('breakfast', '早餐时间 · HH:mm', 'meal', time: true),
  PromptParameter('lunch', '午餐时间 · HH:mm', 'meal', time: true),
  PromptParameter('dinner', '晚餐时间 · HH:mm', 'meal', time: true),
  PromptParameter('cooking', '做饭器具与储存条件', 'meal'),
  PromptParameter('preferences', '饮食偏好', 'meal'),
  PromptParameter('allergies', '过敏与饮食禁忌', 'meal'),
  PromptParameter(
    'sessionsPerWeek',
    '每周训练次数',
    'workout',
    min: 0,
    max: 14,
    integer: true,
  ),
  PromptParameter(
    'sessionMinutes',
    '单次训练上限 · 分钟',
    'workout',
    min: 1,
    max: 300,
    integer: true,
  ),
  PromptParameter(
    'restSeconds',
    '组间休息 · 秒',
    'workout',
    min: 0,
    max: 1800,
    integer: true,
  ),
  PromptParameter('training', '训练经验、场地与身体限制', 'workout'),
  PromptParameter('sleepTime', '准备睡觉 · HH:mm', 'habit', time: true),
  PromptParameter('wakeTime', '起床时间 · HH:mm', 'habit', time: true),
  PromptParameter(
    'windDownMinutes',
    '睡前准备 · 分钟',
    'habit',
    min: 0,
    max: 180,
    integer: true,
  ),
  PromptParameter(
    'commuteMinutes',
    '固定安排前后预留 · 分钟',
    'common',
    min: 0,
    max: 180,
    integer: true,
  ),
  PromptParameter(
    'importantLeadMinutes',
    '重要事项提前提醒 · 分钟',
    'common',
    min: 0,
    max: 1440,
    integer: true,
    initial: '15',
  ),
  PromptParameter('additional', '其他要求', 'common'),
];

bool parameterApplies(PromptParameter p, String module) =>
    p.group == 'profile' ||
    p.group == 'common' ||
    module == 'all' ||
    p.group == module;

Map<String, String> initialPromptParameters(AppData data) {
  final saved = data.settings['promptParameters'];
  final result = {
    for (final p in promptParameters)
      p.key: saved is Map && saved[p.key] is String
          ? saved[p.key] as String
          : p.initial,
  };
  // Always start body fields with current records, rather than a stale draft.
  for (final key in [
    'height',
    'weight',
    'age',
    'targetWeight',
    'goals',
    'cooking',
    'preferences',
    'allergies',
    'training',
  ]) {
    final value = key == 'weight' ? data.currentWeight : data.profile[key];
    result[key] = value?.toString() ?? '';
  }
  for (final key in ['sleepTime', 'wakeTime']) {
    if (saved is! Map || saved[key] is! String) {
      result[key] = data.settings[key] as String? ?? '';
    }
  }
  return result;
}

({Json profile, Json constraints}) parsePromptParameters(
  Map<String, String> raw,
  String module,
) {
  final profile = <String, dynamic>{};
  final constraints = <String, dynamic>{};
  if (module == 'all' || module == 'habit') {
    constraints['habit'] = <String, dynamic>{};
  }
  for (final p in promptParameters.where((p) => parameterApplies(p, module))) {
    final value = p.parse(raw[p.key]);
    if (p.group == 'profile' ||
        ['cooking', 'preferences', 'allergies', 'training'].contains(p.key)) {
      profile[p.key] = value;
    } else if (value != null) {
      final group =
          constraints.putIfAbsent(p.group, () => <String, dynamic>{}) as Json;
      group[p.label] = value;
    }
  }
  profile['currentWeight'] = profile['weight'];
  return (profile: profile, constraints: constraints);
}
