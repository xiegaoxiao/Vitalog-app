import 'package:timezone/timezone.dart' as tz;

import '../data/models.dart';
import 'plan_import.dart';

class _Property {
  _Property(this.name, this.params, this.value);
  String name;
  Map<String, String> params;
  String value;
}

_Property _property(String line) {
  final colon = line.indexOf(':');
  require(colon > 0, 'ICS 属性格式无效');
  final parts = line.substring(0, colon).split(';');
  final parameters = <String, String>{};
  for (final p in parts.skip(1)) {
    final equal = p.indexOf('=');
    if (equal > 0) {
      parameters[p.substring(0, equal).toUpperCase()] = p
          .substring(equal + 1)
          .replaceAll('"', '');
    }
  }
  return _Property(
    parts.first.toUpperCase(),
    parameters,
    line.substring(colon + 1),
  );
}

DateTime _icalDate(String raw, {String? zone}) {
  final match = RegExp(
    r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$',
  ).firstMatch(raw);
  require(match != null, '不支持的 ICS 日期：$raw');
  final values = List.generate(6, (i) => int.parse(match!.group(i + 1) ?? '0'));
  final checked = DateTime.utc(values[0], values[1], values[2]);
  require(
    values[0] >= 1900 &&
        values[0] <= 2200 &&
        checked.year == values[0] &&
        checked.month == values[1] &&
        checked.day == values[2] &&
        values[3] < 24 &&
        values[4] < 60 &&
        values[5] < 60,
    'ICS 日期或时间无效：$raw',
  );
  if (raw.endsWith('Z')) {
    return DateTime.utc(
      values[0],
      values[1],
      values[2],
      values[3],
      values[4],
      values[5],
    );
  }
  if (zone != null) {
    try {
      return tz.TZDateTime(
        tz.getLocation(zone),
        values[0],
        values[1],
        values[2],
        values[3],
        values[4],
        values[5],
      );
    } catch (_) {
      throw FormatException('无法识别课表时区 $zone，请转换为标准 IANA 时区或 UTC');
    }
  }
  return DateTime(
    values[0],
    values[1],
    values[2],
    values[3],
    values[4],
    values[5],
  );
}

DateTime _atDay(DateTime original, DateTime day) {
  if (original is tz.TZDateTime) {
    return tz.TZDateTime(
      original.location,
      day.year,
      day.month,
      day.day,
      original.hour,
      original.minute,
      original.second,
    );
  }
  if (original.isUtc) {
    return DateTime.utc(
      day.year,
      day.month,
      day.day,
      original.hour,
      original.minute,
      original.second,
    );
  }
  return DateTime(
    day.year,
    day.month,
    day.day,
    original.hour,
    original.minute,
    original.second,
  );
}

String _unescape(String s) => s
    .replaceAll(r'\n', '\n')
    .replaceAll(r'\N', '\n')
    .replaceAll(r'\,', ',')
    .replaceAll(r'\;', ';')
    .replaceAll(r'\\', r'\');

PlanImport parseCalendar(String raw) {
  require(
    raw.length <= 2000000 && raw.contains('BEGIN:VCALENDAR'),
    '请导入有效的 .ics 日历文件（最多 2 MB）',
  );
  final lines = raw
      .replaceAll('\r\n', '\n')
      .replaceAll(RegExp(r'\n[ \t]'), '')
      .split('\n');
  final blocks = <List<_Property>>[];
  List<_Property>? current;
  var nested = 0;
  for (final line in lines) {
    if (line.trim() == 'BEGIN:VEVENT') {
      current = [];
      nested = 0;
    } else if (line.trim() == 'END:VEVENT' && current != null) {
      blocks.add(current);
      current = null;
    } else if (current != null && line.startsWith('BEGIN:')) {
      nested++;
    } else if (current != null && line.startsWith('END:')) {
      if (nested > 0) nested--;
    } else if (current != null && nested == 0 && line.contains(':')) {
      current.add(_property(line));
    }
  }
  require(blocks.length <= 1000 && blocks.isNotEmpty, '课表需要包含 1～1000 个 VEVENT');
  final events = <PlanItem>[];
  final cancelled = <String>{};
  final overrideKeys = <String>{};
  for (final block in blocks) {
    final uid = block.where((p) => p.name == 'UID').firstOrNull?.value;
    final recurrence = block
        .where((p) => p.name == 'RECURRENCE-ID')
        .firstOrNull;
    if (uid != null && recurrence != null) {
      overrideKeys.add(
        '$uid:${_icalDate(recurrence.value, zone: recurrence.params['TZID']).millisecondsSinceEpoch}',
      );
    }
  }
  for (final block in blocks) {
    _Property? get(String name) =>
        block.where((p) => p.name == name).firstOrNull;
    final uid = get('UID')?.value ?? newId();
    final dtstart = get('DTSTART');
    require(dtstart != null, 'ICS 事项缺少 DTSTART');
    final start = _icalDate(dtstart!.value, zone: dtstart.params['TZID']);
    final dtend = get('DTEND');
    var duration = dtend == null
        ? const Duration(hours: 1)
        : _icalDate(dtend.value, zone: dtend.params['TZID']).difference(start);
    if (get('DURATION') != null) {
      final m = RegExp(r'^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$')
          .firstMatch(get('DURATION')!.value);
      require(m != null, '不支持的 ICS DURATION');
      duration = Duration(
        days: int.parse(m!.group(1) ?? '0'),
        hours: int.parse(m.group(2) ?? '0'),
        minutes: int.parse(m.group(3) ?? '0'),
        seconds: int.parse(m.group(4) ?? '0'),
      );
    }
    require(duration > Duration.zero && duration.inHours <= 48, '课程持续时间无效');
    if (get('STATUS')?.value == 'CANCELLED') {
      cancelled.add('$uid:${start.millisecondsSinceEpoch}');
      continue;
    }
    final rule = <String, String>{};
    if (get('RRULE') != null) {
      for (final part in get('RRULE')!.value.split(';')) {
        final p = part.split('=');
        require(p.length == 2, 'RRULE 格式无效');
        rule[p[0]] = p[1];
      }
    }
    final dates = <DateTime>[];
    if (rule.isEmpty) {
      dates.add(start);
    } else {
      require(
        ['DAILY', 'WEEKLY'].contains(rule['FREQ']),
        '第一版支持按天或按周重复；请将按月/年重复展开后导入',
      );
      require(
        rule.containsKey('COUNT') || rule.containsKey('UNTIL'),
        '重复课程需要结束日期 UNTIL 或次数 COUNT',
      );
      require(
        !rule.containsKey('BYSETPOS') &&
            !rule.containsKey('BYMONTHDAY') &&
            !rule.containsKey('BYMONTH'),
        '该课表重复规则较复杂，请展开为独立事项后导入',
      );
      final count = rule['COUNT'] == null ? 1000 : int.tryParse(rule['COUNT']!);
      require(count != null && count > 0 && count <= 1000, '重复次数必须为 1～1000');
      final interval = int.tryParse(rule['INTERVAL'] ?? '1');
      require(interval != null && interval > 0 && interval <= 52, '重复间隔无效');
      final until = rule['UNTIL'] == null
          ? null
          : _icalDate(rule['UNTIL']!, zone: dtstart.params['TZID']);
      const codes = {
        'MO': 1,
        'TU': 2,
        'WE': 3,
        'TH': 4,
        'FR': 5,
        'SA': 6,
        'SU': 7,
      };
      final days =
          rule['BYDAY']?.split(',').map((d) {
            require(codes.containsKey(d), '仅支持普通星期重复');
            return codes[d]!;
          }).toSet() ??
          {start.weekday};
      final firstDay = DateTime.utc(start.year, start.month, start.day);
      final weekStart = firstDay.subtract(Duration(days: start.weekday - 1));
      for (var offset = 0; offset <= 366; offset++) {
        final day = firstDay.add(Duration(days: offset));
        final candidate = _atDay(start, day);
        if (until != null && candidate.isAfter(until)) {
          break;
        }
        final active = rule['FREQ'] == 'DAILY'
            ? offset % interval! == 0
            : (day.difference(weekStart).inDays ~/ 7) % interval! == 0 &&
                  days.contains(day.weekday);
        if (active) {
          dates.add(candidate);
        }
        if (dates.length >= count!) {
          break;
        }
      }
      require(dates.isNotEmpty, '课表重复规则没有有效日期');
      if (until == null) {
        require(dates.length == count, '重复课程超过一年，请缩短课表周期');
      } else {
        require(
          !until.isAfter(
            _atDay(start, firstDay.add(const Duration(days: 367))),
          ),
          '课表周期超过一年，请分段导入',
        );
      }
    }
    final exceptions = <int>{};
    for (final p in block.where((p) => p.name == 'EXDATE')) {
      for (final value in p.value.split(',')) {
        exceptions.add(
          _icalDate(value, zone: p.params['TZID']).millisecondsSinceEpoch,
        );
      }
    }
    for (final p in block.where((p) => p.name == 'RDATE')) {
      for (final value in p.value.split(',')) {
        dates.add(_icalDate(value, zone: p.params['TZID']));
      }
    }
    for (final date in dates) {
      final key = '$uid:${date.millisecondsSinceEpoch}';
      if (exceptions.contains(date.millisecondsSinceEpoch) ||
          (get('RECURRENCE-ID') == null && overrideKeys.contains(key))) {
        continue;
      }
      final title = _unescape(get('SUMMARY')?.value ?? '课程');
      final item = PlanItem(
        id: 'ics:$key',
        kind: 'course',
        title: title,
        start: date.toLocal(),
        end: date.add(duration).toLocal(),
        priority: 'important',
        leadMinutes: 15,
        groupId: 'ics:$uid',
        details: {
          'location': _unescape(get('LOCATION')?.value ?? ''),
          'notes': _unescape(get('DESCRIPTION')?.value ?? ''),
        },
      );
      validateItem(item);
      events.add(item);
    }
  }
  events.removeWhere((e) => cancelled.contains(e.id.substring(4)));
  require(events.isNotEmpty && events.length <= 1000, '展开后的课表需要包含 1～1000 个事项');
  events.sort((a, b) => a.start.compareTo(b.start));
  final unique = <String, PlanItem>{for (final e in events) e.id: e};
  return PlanImport(
    start: dayOf(events.first.start),
    end: dayOf(events.last.start),
    modules: ['course'],
    events: unique.values.toList(),
  );
}
