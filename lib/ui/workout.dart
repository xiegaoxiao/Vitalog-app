import 'dart:async';

import 'package:flutter/material.dart';

import '../data/controller.dart';
import '../data/models.dart';
import '../services/plan_import.dart';
import 'design.dart';

class WorkoutSession extends StatefulWidget {
  const WorkoutSession({super.key, required this.c, required this.id});
  final AppController c;
  final String id;
  @override
  State<WorkoutSession> createState() => _WorkoutSessionState();
}

class _WorkoutSessionState extends State<WorkoutSession> {
  Timer? timer;
  DateTime? until;
  int remaining = 0;
  int duration = 90;
  PlanItem get event =>
      widget.c.data.events.firstWhere((e) => e.id == widget.id);
  @override
  void initState() {
    super.initState();
    final stored = event.actual['restUntil'];
    if (stored is String) {
      until = DateTime.tryParse(stored);
      tick();
    }
    timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void tick() {
    if (!mounted) {
      return;
    }
    if (until != null) {
      final delta = until!.difference(DateTime.now()).inSeconds;
      setState(() => remaining = delta > 0 ? delta : 0);
      if (delta <= 0) {
        until = null;
      }
    }
  }

  Future<void> beginRest(int seconds) async {
    duration = seconds;
    until = DateTime.now().add(Duration(seconds: seconds));
    setState(() => remaining = seconds);
    try {
      await widget.c.mutate((d) {
        final e = d.events.firstWhere((e) => e.id == widget.id);
        e.actual['restUntil'] = until!.toIso8601String();
      });
      await widget.c.reminders.startTimer(until!);
    } catch (e) {
      if (mounted) {
        toast(context, errorText(e));
      }
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> record(int exerciseIndex, int setIndex, Json exercise) async {
    final key = '$exerciseIndex-$setIndex';
    final old = (event.actual['sets'] as Map? ?? {})[key] as Map? ?? {};
    final weight = TextEditingController(
      text: (old['weight'] ?? exercise['weight'])?.toString() ?? '',
    );
    final reps = TextEditingController(
      text: (old['reps'] ?? exercise['reps'])?.toString() ?? '',
    );
    final seconds = TextEditingController(
      text: (old['seconds'] ?? exercise['seconds'])?.toString() ?? '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => EditorDialog(
        title: '${exercise['name']} · 第 ${setIndex + 1} 组',
        onSave: () async {
          final entry = {
            'weight': weight.text.trim().isEmpty
                ? null
                : finiteValue(double.tryParse(weight.text), '重量', max: 1000),
            'reps': reps.text.trim().isEmpty
                ? null
                : finiteValue(int.tryParse(reps.text), '次数', min: 1, max: 1000),
            'seconds': seconds.text.trim().isEmpty
                ? null
                : finiteValue(
                    int.tryParse(seconds.text),
                    '秒数',
                    min: 1,
                    max: 3600,
                  ),
            'at': DateTime.now().toIso8601String(),
          };
          require(
            entry['reps'] != null || entry['seconds'] != null,
            '请填写次数或持续秒数',
          );
          await widget.c.saveWorkoutSet(widget.id, key, entry);
        },
        child: Column(
          children: [
            field(weight, '实际重量 · kg（徒手可留空）', numeric: true),
            rowFields(
              field(reps, '实际次数', numeric: true),
              field(seconds, '或持续秒数', numeric: true),
            ),
          ],
        ),
      ),
    );
    weight.dispose();
    reps.dispose();
    seconds.dispose();
    if (saved == true && mounted && !event.completed) {
      await beginRest((number(exercise['rest_seconds']) ?? 90).toInt());
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.c,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text(event.title)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: event.completed
                ? null
                : () async {
                    try {
                      await widget.c.complete(
                        event.id,
                        actual: cloneJson(event.actual),
                      );
                      await widget.c.reminders.cancelTimer();
                      if (context.mounted) {
                        toast(context, '训练已完成，实际组数已保存');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        toast(context, errorText(e));
                      }
                    }
                  },
            icon: const Icon(Icons.check),
            label: Text(event.completed ? '本次训练已完成' : '完成本次训练'),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Panel(
                color: V.green,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Tag('专注这一组', color: V.ink),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${(remaining ~/ 60).toString().padLeft(2, '0')}:${(remaining % 60).toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w800,
                                  color: V.ink,
                                ),
                              ),
                              Text(
                                remaining > 0 ? '组间休息' : '准备好后，开始下一组',
                                style: const TextStyle(color: V.muted),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: () async {
                            if (until != null) {
                              until = null;
                              setState(() => remaining = 0);
                              await widget.c.reminders.cancelTimer();
                              await widget.c.mutate(
                                (d) => d.events
                                    .firstWhere((e) => e.id == widget.id)
                                    .actual
                                    .remove('restUntil'),
                              );
                            } else {
                              await beginRest(duration);
                            }
                          },
                          icon: Icon(
                            until == null
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                          ),
                          tooltip: until == null ? '开始休息计时' : '停止休息计时',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final s in [60, 90, 120])
                          TextButton(
                            onPressed: () => beginRest(s),
                            style: TextButton.styleFrom(foregroundColor: V.ink),
                            child: Text('$s 秒'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (event.details['notes'] != null)
                Text(
                  event.details['notes'] as String,
                  style: const TextStyle(color: V.muted, height: 1.8),
                ),
              if (event.exercises.isEmpty)
                const EmptyState('还没有动作列表', '在计划详情里填写动作，或通过 AI 导入完整训练计划。'),
              for (var i = 0; i < event.exercises.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Tag('${i + 1}'.padLeft(2, '0'), color: V.green),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                event.exercises[i]['name'] as String,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${event.exercises[i]['sets']} 组 × ${event.exercises[i]['seconds'] != null ? '${event.exercises[i]['seconds']} 秒' : '${event.exercises[i]['reps'] ?? '自定'} 次'} · 休息 ${event.exercises[i]['rest_seconds'] ?? 90} 秒',
                          style: const TextStyle(fontSize: 12, color: V.muted),
                        ),
                        if (event.exercises[i]['notes'] != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              event.exercises[i]['notes'] as String,
                              style: const TextStyle(fontSize: 13, height: 1.8),
                            ),
                          ),
                        for (
                          var s = 0;
                          s < (event.exercises[i]['sets'] as num).toInt();
                          s++
                        )
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text('第 ${s + 1} 组'),
                            subtitle: Text(_setSummary(i, s)),
                            trailing: OutlinedButton(
                              onPressed: () => record(i, s, event.exercises[i]),
                              child: Text(
                                (event.actual['sets'] as Map? ?? {})
                                        .containsKey('$i-$s')
                                    ? '修改'
                                    : '记录',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    ),
  );
  String _setSummary(int i, int s) {
    final set = (event.actual['sets'] as Map? ?? {})['$i-$s'] as Map?;
    return set == null
        ? '尚未记录'
        : '${set['weight'] != null ? '${set['weight']} kg · ' : ''}${set['seconds'] != null ? '${set['seconds']} 秒' : '${set['reps']} 次'}';
  }
}
