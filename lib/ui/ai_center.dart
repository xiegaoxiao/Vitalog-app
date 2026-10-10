import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/controller.dart';
import '../data/models.dart';
import '../services/prompts.dart';
import '../services/calendar_import.dart';
import '../services/plan_import.dart';
import 'design.dart';
import 'editors.dart';

class AiCenter extends StatefulWidget {
  const AiCenter({super.key, required this.c});
  final AppController c;
  @override
  State<AiCenter> createState() => _AiCenterState();
}

class _AiCenterState extends State<AiCenter> {
  int tab = 0;
  String module = 'meal';
  bool history = false;
  DateTime start = dayOf(DateTime.now()),
      end = dayOf(DateTime.now()).add(const Duration(days: 6));
  final prompt = TextEditingController();
  final input = TextEditingController();
  String? error;
  bool loading = false;
  @override
  void initState() {
    super.initState();
    generate();
  }

  void generate() {
    prompt.text = buildPrompt(widget.c.data, start, end, module, history);
  }

  @override
  void dispose() {
    prompt.dispose();
    input.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'ics'],
        withData: true,
      );
      if (result == null) {
        return;
      }
      final file = result.files.single;
      require(file.size <= 2000000, '一次导入最多 2 MB');
      require(file.bytes != null, '无法读取该文件');
      input.text = utf8.decode(file.bytes!).replaceFirst('\uFEFF', '');
      if (mounted) {
        setState(() => error = null);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = errorText(e));
      }
    }
  }

  void preview() {
    try {
      final raw = input.text.trim();
      final plan = raw.startsWith('BEGIN:VCALENDAR')
          ? parseCalendar(raw)
          : parsePlan(raw);
      setState(() => error = null);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ImportReview(c: widget.c, plan: plan),
        ),
      );
    } catch (e) {
      setState(
        () => error = e is FormatException
            ? e.message.toString()
            : '内容格式不正确，请检查 JSON 的类型和字段。',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AI 计划工作台')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Panel(
              color: V.blue,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tag('你的计划，你做主', color: V.ink),
                  SizedBox(height: 14),
                  Text(
                    '让 AI 做规划\n让元气簿陪你执行',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: V.ink,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '复制提示词 → 外部 AI → 导入预览 → 加入计划',
                    style: TextStyle(fontSize: 12, color: V.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('生成提示词'),
                  icon: Icon(Icons.auto_awesome),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('导入计划'),
                  icon: Icon(Icons.file_download_outlined),
                ),
              ],
              selected: {tab},
              onSelectionChanged: (s) => set(() => tab = s.first),
            ),
            const SizedBox(height: 20),
            if (tab == 0) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kind in ['meal', 'workout', 'habit', 'all'])
                    ChoiceChip(
                      label: Text(kind == 'all' ? '综合计划' : kindNames[kind]!),
                      selected: module == kind,
                      onSelected: (_) => setState(() => module = kind),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      final d = await chooseDate(context, start);
                      if (d != null) {
                        setState(() {
                          start = d;
                          if (end.isBefore(start)) {
                            end = start.add(const Duration(days: 6));
                          }
                        });
                      }
                    },
                    child: Text('开始 ${dateKey(start)}'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final d = await chooseDate(context, end);
                      if (d != null) {
                        setState(() => end = d);
                      }
                    },
                    child: Text('结束 ${dateKey(end)}'),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('附带最近一周的执行记录'),
                subtitle: const Text('体重、睡眠、饮食、训练与习惯'),
                value: history,
                onChanged: (v) => setState(() => history = v),
              ),
              FilledButton.tonalIcon(
                onPressed: () {
                  if (end.isBefore(start) ||
                      end.difference(start).inDays > 366) {
                    toast(context, '请选择一年以内的有效周期');
                    return;
                  }
                  setState(generate);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('生成 / 更新提示词'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: prompt,
                maxLines: 16,
                decoration: const InputDecoration(
                  labelText: '复制前可以查看、删改',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: prompt.text));
                  if (context.mounted) {
                    toast(context, '提示词已复制，可以交给你使用的 AI');
                  }
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('复制提示词'),
              ),
              const SizedBox(height: 12),
              const Text(
                '应用只复制你确认的内容。生成计划时可继续向 AI 补充条件，再把最终 JSON 带回来。',
                style: TextStyle(fontSize: 12, color: V.muted, height: 1.8),
              ),
            ] else ...[
              const Text(
                '粘贴 AI 输出的 JSON，或选择 JSON / .ics 文件。',
                style: TextStyle(color: V.muted, height: 1.8),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: input,
                maxLines: 13,
                decoration: const InputDecoration(
                  labelText: '计划内容',
                  alignLabelWithHint: true,
                  hintText: '{"schemaVersion": 1, "range": ..., "events": ...}',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: pick,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('选择文件'),
                  ),
                  TextButton(
                    onPressed: () {
                      input.text = const JsonEncoder.withIndent('  ').convert(
                        planExample(
                          start,
                          kind: module == 'all' ? 'meal' : module,
                        ),
                      );
                      setState(() => error = null);
                    },
                    child: const Text('填入格式示例'),
                  ),
                ],
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: preview,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('预览并修改'),
              ),
              const SizedBox(height: 16),
              const Text(
                '课表支持按天、按周重复、单双周间隔、排除日期和单次改课。导入时不会自动覆盖已完成记录或固定安排。',
                style: TextStyle(fontSize: 12, color: V.muted, height: 1.8),
              ),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    ),
  );
  void set(VoidCallback action) => setState(action);
}

class ImportReview extends StatefulWidget {
  const ImportReview({super.key, required this.c, required this.plan});
  final AppController c;
  final PlanImport plan;
  @override
  State<ImportReview> createState() => _ImportReviewState();
}

class _ImportReviewState extends State<ImportReview> {
  bool replace = true, busy = false;
  String? error;
  late PlanImport plan;
  @override
  void initState() {
    super.initState();
    plan = PlanImport(
      start: widget.plan.start,
      end: widget.plan.end,
      modules: widget.plan.modules,
      events: widget.plan.events.map((e) => e.copy()).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = plan.preview(widget.c.data, replace);
    return Scaffold(
      appBar: AppBar(title: const Text('确认你的新计划')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: busy
                ? null
                : () async {
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      for (final e in plan.events) {
                        validateItem(e);
                        require(
                          !dayOf(e.start).isBefore(plan.start) &&
                              !dayOf(e.start).isAfter(plan.end),
                          '修改后的事项需要在计划周期内',
                        );
                      }
                      await widget.c.applyImport(plan, replace);
                      if (context.mounted) {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.popUntil(context, (r) => r.isFirst);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              '已加入 ${preview.additions.length} 项安排；完成记录与固定日程已保留',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() {
                          busy = false;
                          error = errorText(e);
                        });
                      }
                    }
                  },
            icon: const Icon(Icons.check),
            label: Text(
              busy ? '正在保存…' : '确认加入 ${preview.additions.length} 项安排',
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                '${dateKey(plan.start)} — ${dateKey(plan.end)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: plan.modules
                    .map((m) => Tag(kindNames[m]!, color: V.color(m)))
                    .toList(),
              ),
              const SizedBox(height: 20),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('替换未完成计划')),
                  ButtonSegment(value: false, label: Text('追加导入')),
                ],
                selected: {replace},
                onSelectionChanged: busy
                    ? null
                    : (s) => setState(() => replace = s.first),
              ),
              const SizedBox(height: 14),
              Panel(
                child: Text(
                  '新增 ${preview.additions.length} 项 · 替换 ${preview.replacedIds.length} 项 · 跳过 ${preview.skipped} 项\n已完成记录、课程和组会始终保留。',
                  style: const TextStyle(height: 1.9),
                ),
              ),
              if (preview.conflicts.isNotEmpty) ...[
                const SizedBox(height: 14),
                Panel(
                  color: V.orange.withValues(alpha: .18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '有时间重叠，请检查后再导入',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ...preview.conflicts.map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(s, style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SectionTitle('逐项预览', subtitle: '点击修改时间、提醒和详细内容；不需要的事项可以移除'),
              for (final event in [...plan.events])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                    padding: 14,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: V.color(event.kind).withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            V.icon(event.kind),
                            color: V.color(event.kind),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: busy
                                ? null
                                : () async {
                                    final edited = await editEvent(
                                      context,
                                      original: event,
                                    );
                                    if (edited != null && mounted) {
                                      setState(() {
                                        final index = plan.events.indexWhere(
                                          (e) => e.id == event.id,
                                        );
                                        plan.events[index] = edited;
                                      });
                                    }
                                  },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${dateKey(event.start)} ${clock(event.start)}—${clock(event.end)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: V.muted,
                                  ),
                                ),
                                Text(
                                  '${priorityNames[event.priority]}${event.alarm ? ' · 闹钟' : ''}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: V.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: busy
                              ? null
                              : () => setState(
                                  () => plan.events.removeWhere(
                                    (e) => e.id == event.id,
                                  ),
                                ),
                          tooltip: '移除这一项',
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> exportBackup(BuildContext context, AppController c) async {
  try {
    final bytes = Uint8List.fromList(utf8.encode(c.exportBackup()));
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '保存元气簿备份',
      fileName: 'vitalog-${dateKey(DateTime.now())}.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
    if (path != null && context.mounted) {
      toast(context, '备份已导出，请保存到你选择的位置');
    }
  } catch (e) {
    if (context.mounted) {
      toast(context, errorText(e));
    }
  }
}

Future<void> restoreBackup(BuildContext context, AppController c) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null) {
      return;
    }
    require(result.files.single.size <= 20000000, '备份最多 20 MB');
    final bytes = result.files.single.bytes;
    require(bytes != null, '无法读取备份');
    final restored = validateBackup(
      utf8.decode(bytes!).replaceFirst('\uFEFF', ''),
    );
    if (!context.mounted) {
      return;
    }
    final accepted = await confirm(
      context,
      '恢复这份备份？',
      '档案：${restored.profile['name'] ?? '未填写'}\n${restored.events.length} 项安排，${restored.inventory.length} 种食材，${restored.weights.length} 次体重记录。\n\n恢复会替换当前本机数据。应用会保留操作前的数据，方便恢复上一份记录。',
      action: '恢复备份',
    );
    if (accepted) {
      await c.restore(restored);
      if (context.mounted) {
        toast(context, '备份已恢复，请检查手机提醒权限');
      }
    }
  } catch (e) {
    if (context.mounted) {
      toast(context, errorText(e));
    }
  }
}
