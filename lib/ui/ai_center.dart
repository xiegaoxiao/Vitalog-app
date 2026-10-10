import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/controller.dart';
import '../data/models.dart';
import '../services/prompts.dart';
import '../services/prompt_parameters.dart';
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
  final historySections = <String>{
    'weights',
    'sleep',
    'meal',
    'workout',
    'habits',
  };
  final form = GlobalKey<FormState>();
  final scroll = ScrollController();
  late final Map<String, TextEditingController> parameters;
  String sex = '', activity = '';
  bool generated = false, dirty = false;
  DateTime start = dayOf(DateTime.now()),
      end = dayOf(DateTime.now()).add(const Duration(days: 6));
  final prompt = TextEditingController();
  final input = TextEditingController();
  String? error;
  bool loading = false;
  @override
  void initState() {
    super.initState();
    parameters = {
      for (final entry in initialPromptParameters(widget.c.data).entries)
        entry.key: TextEditingController(text: entry.value),
    };
    sex = widget.c.data.profile['sex'] as String? ?? '';
    activity = widget.c.data.profile['activity']?.toString() ?? '';
  }

  void changed() {
    if (generated && !dirty) setState(() => dirty = true);
  }

  Future<void> generate() async {
    if (end.isBefore(start) || end.difference(start).inDays > 366) {
      toast(context, '请选择一年以内的有效周期');
      return;
    }
    form.currentState?.validate();
    for (final p in promptParameters.where(
      (p) => parameterApplies(p, module),
    )) {
      final message = p.validate(parameters[p.key]!.text);
      if (message != null) {
        toast(context, '${p.label}：$message');
        return;
      }
    }
    setState(() => loading = true);
    try {
      final raw = {
        for (final e in parameters.entries) e.key: e.value.text.trim(),
      };
      final parsed = parsePromptParameters(raw, module);
      parsed.profile['sex'] = sex.isEmpty ? null : sex;
      parsed.profile['activity'] = num.tryParse(activity);
      final sections = {...historySections};
      if (sections.contains('meal') || sections.contains('workout')) {
        sections.add('executed');
      }
      final text = buildPrompt(
        widget.c.data,
        start,
        end,
        module,
        history,
        profileOverrides: parsed.profile,
        planningParameters: parsed.constraints,
        historySections: sections,
      );
      await widget.c.mutate((data) {
        data.settings['promptParameters'] = {
          for (final p in promptParameters)
            if (p.group != 'profile' &&
                ![
                  'cooking',
                  'preferences',
                  'allergies',
                  'training',
                ].contains(p.key))
              p.key: raw[p.key],
        };
      });
      if (!mounted) return;
      setState(() {
        prompt.text = text;
        generated = true;
        dirty = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scroll.hasClients) {
          scroll.animateTo(
            scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) toast(context, errorText(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    prompt.dispose();
    input.dispose();
    scroll.dispose();
    for (final c in parameters.values) {
      c.dispose();
    }
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
    bottomNavigationBar: tab == 0
        ? SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: loading ? null : generate,
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: Text(
                        loading
                            ? '正在生成…'
                            : generated
                            ? '重新生成'
                            : '生成提示词',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: !generated || dirty || loading
                          ? null
                          : () async {
                              await Clipboard.setData(
                                ClipboardData(text: prompt.text),
                              );
                              if (context.mounted) {
                                toast(context, '提示词已复制，可以交给你使用的 AI');
                              }
                            },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('复制提示词'),
                    ),
                  ),
                ],
              ),
            ),
          )
        : null,
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          controller: scroll,
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
                    '先填条件\n再让 AI 做规划',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: V.ink,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '填写参数 → 生成提示词 → 外部 AI → 导入预览',
                    style: TextStyle(fontSize: 13, color: V.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('填写参数'),
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
                      onSelected: (_) => setState(() {
                        module = kind;
                        if (generated) dirty = true;
                      }),
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
                          if (generated) dirty = true;
                        });
                      }
                    },
                    child: Text('开始 ${dateKey(start)}'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final d = await chooseDate(context, end);
                      if (d != null) {
                        setState(() {
                          end = d;
                          if (generated) dirty = true;
                        });
                      }
                    },
                    child: Text('结束 ${dateKey(end)}'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                '能量、营养和训练指标可留空，交给 AI 询问或建议。身体信息来自档案，这里的修改只用于本轮规划。',
                style: TextStyle(fontSize: 13, height: 1.7),
              ),
              const SizedBox(height: 12),
              Form(
                key: form,
                child: Column(
                  children: [
                    parameterGroup('身体与目标', 'profile', expanded: false),
                    if (module == 'meal' || module == 'all')
                      parameterGroup('饮食参数', 'meal'),
                    if (module == 'workout' || module == 'all')
                      parameterGroup('训练参数', 'workout'),
                    if (module == 'habit' || module == 'all')
                      parameterGroup('作息参数', 'habit'),
                    parameterGroup('时间预留与补充', 'common', expanded: false),
                  ],
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('附带最近一周的执行记录'),
                subtitle: const Text('选择允许 AI 参考的记录'),
                value: history,
                onChanged: (v) => setState(() {
                  history = v;
                  if (generated) dirty = true;
                }),
              ),
              if (history)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in const {
                      'weights': '体重',
                      'sleep': '睡眠',
                      'meal': '饮食',
                      'workout': '训练',
                      'habits': '习惯',
                    }.entries)
                      FilterChip(
                        label: Text(entry.value),
                        selected: historySections.contains(entry.key),
                        onSelected: (value) => setState(() {
                          value
                              ? historySections.add(entry.key)
                              : historySections.remove(entry.key);
                          if (generated) dirty = true;
                        }),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              if (dirty)
                Panel(
                  color: V.orange,
                  padding: 12,
                  child: const Text(
                    '参数已改变，请重新生成后再复制。重新生成会替换下方手动编辑的提示词。',
                    style: TextStyle(fontSize: 13, height: 1.7),
                  ),
                ),
              if (generated) ...[
                const SectionTitle('提示词预览', subtitle: '已包含库存与固定安排，复制前仍可删改'),
                TextField(
                  key: const Key('generated-prompt'),
                  controller: prompt,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: '最终提示词',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                '生成时将计划参数保存在本机；身体档案、目标作息与执行记录不会被这里的输入修改。复制前可以查看完整内容，再交给外部 AI。',
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

  Widget parameterGroup(String title, String group, {bool expanded = true}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        padding: 0,
        child: ExpansionTile(
          key: PageStorageKey('prompt-$group'),
          initiallyExpanded: expanded,
          maintainState: true,
          title: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            group == 'profile' ? '从当前档案带入，可展开调整' : '按你的实际条件填写，留空表示未指定',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          shape: const Border(),
          collapsedShape: const Border(),
          childrenPadding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final twoColumns =
                    width >= 290 &&
                    MediaQuery.textScalerOf(context).scale(14) <= 20;
                return Wrap(
                  spacing: 12,
                  runSpacing: 16,
                  children: [
                    for (final p in promptParameters.where(
                      (p) => p.group == group,
                    ))
                      SizedBox(
                        width: twoColumns && !p.multiline
                            ? (width - 12) / 2
                            : width,
                        child: TextFormField(
                          key: ValueKey('parameter-${p.key}'),
                          controller: parameters[p.key],
                          validator: p.validate,
                          onChanged: (_) => changed(),
                          maxLines: p.multiline ? 2 : 1,
                          keyboardType: p.numeric
                              ? TextInputType.numberWithOptions(
                                  decimal: !p.integer,
                                )
                              : p.time
                              ? TextInputType.datetime
                              : TextInputType.multiline,
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            labelText: p.inputLabel,
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            hintText: p.time ? '例如 07:30' : '可留空',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ),
                    if (group == 'profile') ...[
                      SizedBox(
                        width: width,
                        child: DropdownButtonFormField<String>(
                          initialValue: ['', 'male', 'female'].contains(sex)
                              ? sex
                              : '',
                          decoration: const InputDecoration(labelText: '性别'),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('未指定')),
                            DropdownMenuItem(value: 'male', child: Text('男')),
                            DropdownMenuItem(value: 'female', child: Text('女')),
                          ],
                          onChanged: (v) {
                            sex = v!;
                            changed();
                          },
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: DropdownButtonFormField<String>(
                          initialValue:
                              [
                                '',
                                '1.2',
                                '1.375',
                                '1.55',
                                '1.725',
                              ].contains(activity)
                              ? activity
                              : '',
                          decoration: const InputDecoration(labelText: '日常活动量'),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('未指定')),
                            DropdownMenuItem(value: '1.2', child: Text('久坐')),
                            DropdownMenuItem(
                              value: '1.375',
                              child: Text('轻度活动'),
                            ),
                            DropdownMenuItem(
                              value: '1.55',
                              child: Text('中等活动'),
                            ),
                            DropdownMenuItem(
                              value: '1.725',
                              child: Text('较多活动'),
                            ),
                          ],
                          onChanged: (v) {
                            activity = v!;
                            changed();
                          },
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

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
