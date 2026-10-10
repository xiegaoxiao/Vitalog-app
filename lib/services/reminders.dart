import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';

class Reminders {
  static const channel = MethodChannel('vitalog/reminders');
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  Future<Json> status() async => supported
      ? Map<String, dynamic>.from(await channel.invokeMethod('status') as Map)
      : {'notifications': false, 'exact': false, 'preview': true};
  Future<void> requestNotifications() async {
    if (supported) {
      await channel.invokeMethod('requestNotifications');
    }
  }

  Future<void> openExactSettings() async {
    if (supported) {
      await channel.invokeMethod('exactSettings');
    }
  }

  Future<void> openAppSettings() async {
    if (supported) {
      await channel.invokeMethod('appSettings');
    }
  }

  Future<void> sync(AppData data) async {
    if (!supported) {
      return;
    }
    final future =
        data.events
            .where(
              (e) =>
                  !e.completed &&
                  e.reminder &&
                  e.priority != 'quiet' &&
                  e.start
                      .subtract(Duration(minutes: e.leadMinutes))
                      .isAfter(DateTime.now()),
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    await channel.invokeMethod(
      'sync',
      future
          .map(
            (e) => {
              'id': e.id,
              'title': e.title,
              'body': '${clock(e.start)} · ${kindNames[e.kind]}',
              'at': e.start
                  .subtract(Duration(minutes: e.leadMinutes))
                  .millisecondsSinceEpoch,
              'alarm': e.alarm,
              'priority': e.priority,
            },
          )
          .toList(),
    );
  }

  Future<void> test() async {
    if (supported) {
      await channel.invokeMethod('test');
    }
  }

  Future<void> startTimer(DateTime until) async {
    if (supported) {
      await channel.invokeMethod('timer', {'at': until.millisecondsSinceEpoch});
    }
  }

  Future<void> cancelTimer() async {
    if (supported) {
      await channel.invokeMethod('cancelTimer');
    }
  }
}
