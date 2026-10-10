import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/controller.dart';
import '../data/models.dart';
import '../data/demo.dart';
import '../services/plan_import.dart';
import 'design.dart';
import 'editors.dart';
import 'ai_center.dart';
import 'workout.dart';
import 'agenda.dart';

class Home extends StatefulWidget {
  const Home({super.key, required this.controller});
  final AppController controller;
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0, foodTab = 0;
  DateTime selected = dayOf(DateTime.now());
  String calendarKind = 'all';
  AppController get c => widget.controller;
  AppData get d => c.data;
  static const names = ['今日', '饮食', '日程', '训练', '我的'];
  static const icons = [
    Icons.grid_view_rounded,
    Icons.restaurant_outlined,
    Icons.calendar_month_outlined,
    Icons.fitness_center_outlined,
    Icons.person_outline_rounded,
  ];
  Future<void> action(
    Future<void> Function() callback, {
    String? message,
  }) async {
    try {
      await callback();
      if (mounted && message != null) {
        toast(context, message);
      }
    } catch (e) {
      if (mounted) {
        toast(context, errorText(e));
      }
    }
  }

  void ai() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => AiCenter(c: c)),
  );
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 950;
    return Scaffold(
      bottomNavigationBar: wide
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                border: V.isCartoon(context)
                    ? const Border(top: BorderSide(color: V.ink, width: 2.5))
                    : null,
              ),
              child: NavigationBar(
                height: 76,
                selectedIndex: tab,
                onDestinationSelected: (v) => setState(() => tab = v),
                backgroundColor: Theme.of(context).colorScheme.surface,
                indicatorColor: V.panelColor(
                  context,
                  [V.blue, V.orange, V.blue, V.green, V.purple][tab],
                ),
                destinations: List.generate(
                  5,
                  (i) => NavigationDestination(
                    icon: Icon(icons[i]),
                    label: names[i],
                  ),
                ),
              ),
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (wide) _rail(),
            Expanded(
              child: Column(
                children: [
                  if (c.saving) const LinearProgressIndicator(minHeight: 2),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(
                            wide ? 36 : 20,
                            20,
                            wide ? 36 : 20,
                            30,
                          ),
                          children: [
                            _header(wide),
                            if (d.demo)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Panel(
                                  padding: 12,
                                  color: V.orange,
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.science_outlined,
                                        size: 18,
                                        color: V.ink,
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          '示例数据 · 用于体验，可随时清空',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          if (await confirm(
                                            context,
                                            '开始使用自己的记录？',
                                            '会清空示例及其修改，建立你的独立档案。',
                                            action: '清空示例',
                                          )) {
                                            await action(
                                              () => c.restore(AppData()),
                                            );
                                          }
                                        },
                                        child: const Text('开始使用'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (c.reminderError != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  c.reminderError!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            if (d.profile.isEmpty)
                              _welcome()
                            else
                              ...switch (tab) {
                                0 => _today(wide),
                                1 => _food(),
                                2 => _calendar(),
                                3 => _training(),
                                _ => _profile(),
                              },
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rail() => Container(
    width: 214,
    padding: const EdgeInsets.fromLTRB(22, 30, 22, 24),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: V.isCartoon(context)
          ? const Border(right: BorderSide(color: V.ink, width: 2.5))
          : null,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _brand(),
            const SizedBox(width: 10),
            const Text(
              '元气簿',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(0, 10, 0, 35),
          child: Text(
            'VITALOG · LIVE A LITTLE BETTER',
            style: TextStyle(fontSize: 8, color: V.muted, letterSpacing: 1),
          ),
        ),
        for (var i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: i == tab
                  ? V.panelColor(
                      context,
                      V.color(
                        i == 1
                            ? 'meal'
                            : i == 3
                            ? 'workout'
                            : i == 4
                            ? 'habit'
                            : 'course',
                      ),
                    )
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: ListTile(
                dense: true,
                leading: Icon(icons[i], color: i == tab ? V.ink : V.muted),
                title: Text(
                  names[i],
                  style: TextStyle(
                    fontWeight: i == tab ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                onTap: () => setState(() => tab = i),
              ),
            ),
          ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: ai,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('AI 计划'),
          ),
        ),
        const SizedBox(height: 20),
        const Row(
          children: [
            Icon(Icons.lock_outline, size: 13, color: V.muted),
            SizedBox(width: 6),
            Text('本地保存 · 随时备份', style: TextStyle(fontSize: 11, color: V.muted)),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Vitalog 0.1',
          style: TextStyle(fontSize: 10, color: V.muted),
        ),
      ],
    ),
  );
  Widget _brand() => Container(
    width: 46,
    height: 46,
    decoration: BoxDecoration(
      color: V.isCartoon(context)
          ? V.cream
          : Theme.of(context).colorScheme.primary,
      borderRadius: BorderRadius.circular(16),
      border: V.isCartoon(context) ? Border.all(color: V.ink, width: 2) : null,
      boxShadow: V.isCartoon(context)
          ? const [BoxShadow(color: V.ink, offset: Offset(2, 2))]
          : const [],
    ),
    child: V.isCartoon(context)
        ? const Buddy(size: 42)
        : const Center(
            child: Text(
              'V',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
  );
  Widget _header(bool wide) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Row(
      children: [
        if (!wide) ...[_brand(), const SizedBox(width: 10)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                wide ? (tab == 0 ? '今天，也要元气满满' : names[tab]) : '元气簿',
                style: TextStyle(
                  fontSize: wide ? 27 : 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${DateTime.now().month}月${DateTime.now().day}日 · 星期${'一二三四五六日'[DateTime.now().weekday - 1]}${wide ? '  /  ${names[tab]}' : '  · Vitalog'}',
                style: const TextStyle(fontSize: 11, color: V.muted),
              ),
            ],
          ),
        ),
        if (!wide)
          IconButton.filledTonal(
            onPressed: ai,
            tooltip: 'AI 计划工作台',
            icon: const Icon(Icons.auto_awesome_rounded, color: V.ink),
          ),
      ],
    ),
  );
  Widget _welcome() => Column(
    children: [
      Panel(
        color: V.blue,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Tag('HELLO, VITALOG', color: V.cream),
            const Align(
              alignment: Alignment.centerRight,
              child: Buddy(size: 120),
            ),
            const SizedBox(height: 20),
            const Text(
              '把每一天\n过得刚刚好。',
              style: TextStyle(
                fontSize: 36,
                color: V.ink,
                fontWeight: FontWeight.w800,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '吃得均衡，练得从容，睡得规律。\n从你的身体与生活条件开始，安排属于自己的节奏。',
              style: TextStyle(fontSize: 13, color: V.muted, height: 1.9),
            ),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: () => editProfile(context, c),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('建立我的档案'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      const SizedBox(height: 18),
      ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.asset(
          V.mealImage(context),
          height: 190,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
      const SizedBox(height: 18),
      Panel(
        child: const Row(
          children: [
            Icon(Icons.offline_bolt_outlined, color: V.orange),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '计划、记录和食材都保存在本机。\n你可以随时导出备份。',
                style: TextStyle(fontSize: 13, height: 1.8),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      CardAction(
        onPressed: () => action(() => c.restore(demoData(DateTime.now()))),
        label: '先体验示例数据',
      ),
    ],
  );

  List<Widget> _today(bool wide) {
    final today = d.onDay(DateTime.now());
    final future = today
        .where((e) => !e.completed && e.end.isAfter(DateTime.now()))
        .toList();
    final next = future.firstOrNull;
    final meals = today.where((e) => e.kind == 'meal').toList();
    final completed = today.where((e) => e.completed).length;
    final cartoon = V.isCartoon(context);
    final heroColor = cartoon ? V.pink : Theme.of(context).colorScheme.primary;
    final heroInk = cartoon ? V.ink : Theme.of(context).colorScheme.onPrimary;
    final hero = Panel(
      color: heroColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tag(
                  next == null ? '留一点时间给自己' : '接下来 · 慢慢来',
                  color: cartoon ? V.cream : heroInk.withValues(alpha: .12),
                  foregroundColor: heroInk,
                ),
                const SizedBox(height: 16),
                Text(
                  next?.title ?? '今天的节奏，由你安排',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: heroInk,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  next == null
                      ? '导入计划，开启你的健康日常'
                      : '${clock(next.start)}—${clock(next.end)}${next.details['location'] != null ? '  · ${next.details['location']}' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: cartoon ? V.muted : heroInk.withValues(alpha: .8),
                  ),
                ),
                const SizedBox(height: 14),
                CardAction(
                  onPressed: next == null ? ai : () => details(next),
                  label: next == null ? '生成我的计划' : '查看安排',
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 106,
            child: Column(
              children: [
                if (cartoon) ...[
                  const Buddy(size: 106),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: 70,
                  height: 70,
                  child: Semantics(
                    container: true,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 68,
                          height: 68,
                          child: CircularProgressIndicator(
                            value: today.isEmpty ? 0 : completed / today.length,
                            strokeWidth: 5,
                            backgroundColor: cartoon
                                ? V.cream
                                : heroInk.withValues(alpha: .2),
                            color: cartoon
                                ? V.ink
                                : V.moduleColor(context, 'meal'),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$completed/${today.length}',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: heroInk,
                              ),
                            ),
                            Text(
                              '已完成',
                              style: TextStyle(
                                fontSize: 9,
                                color: cartoon
                                    ? V.muted
                                    : heroInk.withValues(alpha: .8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final plan = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          '今日节奏',
          trailing: CardAction(
            onPressed: () => setState(() {
              tab = 2;
              selected = dayOf(DateTime.now());
            }),
            label: '完整日程',
          ),
        ),
        if (today.isEmpty)
          EmptyState(
            '今天还没有安排',
            '导入 AI 计划，或添加一项你想完成的事。',
            action: OutlinedButton(
              onPressed: () => editEvent(context, controller: c),
              child: const Text('添加安排'),
            ),
            icon: Icons.calendar_month_outlined,
          )
        else
          AgendaTimeline(
            events: today.take(wide ? 7 : 5).toList(),
            onView: details,
            onComplete: complete,
          ),
      ],
    );
    final diet = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          '今天吃什么',
          trailing: CardAction(
            onPressed: () => setState(() => tab = 1),
            label: '餐单',
          ),
        ),
        if (meals.isEmpty)
          EmptyState(
            '让好好吃饭变得简单',
            '生成食谱后，这里会显示每餐食材和做法。',
            action: OutlinedButton(onPressed: ai, child: const Text('生成饮食计划')),
            icon: Icons.restaurant_outlined,
          )
        else
          _recipe(meals.first, hero: true),
      ],
    );
    return [
      hero,
      const SizedBox(height: 16),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Tag('今日营养', color: V.orange),
                const Spacer(),
                Text(
                  '${meals.where((e) => e.completed).length}/${meals.length} 餐已记录',
                  style: const TextStyle(fontSize: 13, color: V.muted),
                ),
              ],
            ),
            const SizedBox(height: 14),
            NutritionRow({
              for (final k in nutrientKeys)
                k: nutrientTotal(meals.map((e) => e.nutrition), k),
            }),
            const SizedBox(height: 10),
            const Text(
              '计划摄入 · 未提供的营养值显示为 —',
              style: TextStyle(fontSize: 12, color: V.muted, height: 1.6),
            ),
          ],
        ),
      ),
      if (wide)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: plan),
            const SizedBox(width: 22),
            Expanded(flex: 5, child: diet),
          ],
        )
      else ...[
        plan,
        diet,
      ],
      const SectionTitle('规律一点，轻松一点'),
      _sleepPanel(),
      if (today.any((e) => e.kind == 'habit')) ...[
        const SectionTitle('今日习惯'),
        Panel(
          padding: 8,
          child: Column(
            children: today
                .where((e) => e.kind == 'habit')
                .map(_eventTile)
                .toList(),
          ),
        ),
      ],
    ];
  }

  Widget _eventTile(PlanItem event) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    leading: SizedBox(
      width: 48,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            clock(event.start),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          Text(
            clock(event.end),
            style: const TextStyle(fontSize: 9, color: V.muted),
          ),
        ],
      ),
    ),
    title: Row(
      children: [
        Container(
          width: 5,
          height: 28,
          decoration: BoxDecoration(
            color: V.color(event.kind),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            event.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              decoration: event.completed ? TextDecoration.lineThrough : null,
              color: event.completed ? V.muted : null,
            ),
          ),
        ),
      ],
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(left: 15, top: 3),
      child: Text(
        '${kindNames[event.kind]}${event.priority == 'important' ? ' · 提前 ${event.leadMinutes} 分钟' : ''}${event.completed
            ? ' · 已完成'
            : event.end.isBefore(DateTime.now())
            ? ' · 未完成'
            : ''}${event.alarm ? ' · 闹钟' : ''}',
        style: const TextStyle(fontSize: 10, color: V.muted),
      ),
    ),
    trailing: IconButton(
      tooltip: event.completed ? '查看完成记录' : '记录完成',
      onPressed: () => event.completed ? details(event) : complete(event),
      icon: Icon(
        event.completed ? Icons.check_circle_rounded : Icons.circle_outlined,
        color: event.completed
            ? V.color(event.kind)
            : V.muted.withValues(alpha: .5),
        size: 23,
      ),
    ),
    onTap: () => details(event),
  );
  Widget _recipe(PlanItem event, {bool hero = false}) => Panel(
    padding: 0,
    onTap: () => details(event),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hero)
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.5,
                child: Image.asset(
                  V.mealImage(context),
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const Positioned(
                right: 12,
                top: 12,
                child: Tag('饮食配图', color: V.ink),
              ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Tag(
                    event.details['slot'] as String? ?? '餐食',
                    color: V.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${clock(event.start)}${event.details['minutes'] != null ? ' · ${event.details['minutes']} 分钟做完' : ''}',
                    style: const TextStyle(fontSize: 11, color: V.muted),
                  ),
                  const Spacer(),
                  if (event.completed)
                    const Icon(Icons.check_circle, color: V.green, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                event.title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              NutritionRow(event.nutrition, compact: true),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: event.ingredients
                    .take(4)
                    .map(
                      (i) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FoodPicture(i['name'] as String, size: 25),
                          const SizedBox(width: 4),
                          Text(
                            i['name'] as String,
                            style: const TextStyle(
                              fontSize: 11,
                              color: V.muted,
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text(
                    '查看食材与做法',
                    style: TextStyle(fontSize: 12, color: V.muted),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded, color: V.ink, size: 20),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _dateStrip() => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        IconButton(
          onPressed: () => setState(
            () => selected = selected.subtract(const Duration(days: 1)),
          ),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: TextButton(
            onPressed: () async {
              final value = await chooseDate(context, selected);
              if (value != null) {
                setState(() => selected = value);
              }
            },
            child: Text(
              '${dateKey(selected)} · 星期${'一二三四五六日'[selected.weekday - 1]}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        IconButton(
          onPressed: () =>
              setState(() => selected = selected.add(const Duration(days: 1))),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );

  List<Widget> _food() {
    final meals = d.onDay(selected).where((e) => e.kind == 'meal').toList();
    final nutrition = {
      for (final key in nutrientKeys)
        key: nutrientTotal(meals.map((e) => e.nutrition), key),
    };
    final actual = {
      for (final key in nutrientKeys)
        key: nutrientTotal(
          meals
              .where((e) => e.completed)
              .map(
                (e) => Map<String, dynamic>.from(
                  e.actual['nutrition'] as Map? ?? {},
                ),
              ),
          key,
        ),
    };
    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(
          4,
          (i) => ChoiceChip(
            label: Text(['餐单', '菜谱', '食材库存', '购物清单'][i]),
            selected: foodTab == i,
            onSelected: (_) => setState(() => foodTab = i),
          ),
        ),
      ),
      const SizedBox(height: 18),
      if (foodTab == 0) ...[
        _dateStrip(),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Tag('计划摄入', color: V.orange),
              const SizedBox(height: 12),
              NutritionRow(nutrition),
              const Divider(height: 32),
              const Tag('实际摄入', color: V.green),
              const SizedBox(height: 12),
              NutritionRow(actual),
              const SizedBox(height: 10),
              const Text(
                '实际摄入只汇总已打卡餐食。任一餐缺失某项营养时，该项合计显示 —。',
                style: TextStyle(fontSize: 12, color: V.muted, height: 1.6),
              ),
            ],
          ),
        ),
        SectionTitle(
          '三餐有着落',
          trailing: TextButton.icon(
            onPressed: () => editEvent(context, controller: c, day: selected),
            icon: const Icon(Icons.add, size: 17),
            label: const Text('添加'),
          ),
        ),
        if (meals.isEmpty)
          EmptyState(
            '这天还没有餐单',
            '在 AI 工作台生成饮食计划，再预览导入。',
            action: FilledButton(onPressed: ai, child: const Text('制定饮食计划')),
          ),
        for (final e in meals)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _recipe(e, hero: e == meals.first),
          ),
      ],
      if (foodTab == 1) ...[
        const Text(
          '导入过的菜谱，随时可以加入新的日期。',
          style: TextStyle(fontSize: 12, color: V.muted),
        ),
        const SizedBox(height: 14),
        if (!d.events.any((e) => e.kind == 'meal'))
          const EmptyState('你的菜谱库正在等待第一道菜', '通过 AI 导入菜谱，或手动添加餐食。'),
        for (final e in {
          for (final e in d.events.where((e) => e.kind == 'meal')) e.title: e,
        }.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _recipe(e),
          ),
      ],
      if (foodTab == 2) ...[
        SectionTitle(
          '冰箱里有什么',
          trailing: TextButton.icon(
            onPressed: () => editInventory(context, c),
            icon: const Icon(Icons.add, size: 17),
            label: const Text('添加'),
          ),
        ),
        if (d.inventory.isEmpty)
          EmptyState(
            '先记下你已有的食材',
            '生成食谱时可以考虑库存，购物清单也会扣除已有用量。',
            action: FilledButton(
              onPressed: () => editInventory(context, c),
              child: const Text('添加第一种食材'),
            ),
          ),
        for (final item in d.inventory)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              padding: 14,
              onTap: () => editInventory(context, c, original: item),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: V.orange.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: FoodPicture(item.name),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 1)} ${item.unit}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.edit_outlined, size: 17, color: V.muted),
                ],
              ),
            ),
          ),
      ],
      if (foodTab == 3) ...[_shopping()],
    ];
  }

  Widget _shopping() {
    final start = selected, end = selected.add(const Duration(days: 6));
    final items = shoppingList(d, start, end);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dateStrip(),
        Panel(
          color: V.orange.withValues(alpha: .14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '未来 7 天，需要补什么？',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '${dateKey(start)} — ${dateKey(end)}',
                style: const TextStyle(fontSize: 12, color: V.muted),
              ),
              const SizedBox(height: 8),
              const Text(
                '根据未完成餐单汇总，再扣除已有库存。',
                style: TextStyle(fontSize: 12, color: V.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          const EmptyState('暂时没有需要采购的食材', '导入带有食材与用量的饮食计划后自动生成。'),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              padding: 14,
              child: Row(
                children: [
                  FoodPicture(item['name'] as String, size: 35),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '需 ${_quantity(item['need'])} · 已有 ${_quantity(item['owned'])} ${item['unit']}',
                          style: const TextStyle(fontSize: 10, color: V.muted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    (item['missing'] as double) == 0
                        ? '已备齐'
                        : '补 ${_quantity(item['missing'])} ${item['unit']}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: (item['missing'] as double) == 0
                          ? V.green
                          : V.orange,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (items.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(
                    text: items
                        .where((e) => (e['missing'] as double) > 0)
                        .map(
                          (e) =>
                              '${e['name']}：${_quantity(e['missing'])} ${e['unit']}',
                        )
                        .join('\n'),
                  ),
                );
                if (mounted) {
                  toast(context, '采购清单已复制');
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('复制采购清单'),
            ),
          ),
      ],
    );
  }

  String _quantity(dynamic value) =>
      (value as num).toStringAsFixed(value == value.round() ? 0 : 1);

  List<Widget> _calendar() {
    final weekStart = selected.subtract(Duration(days: selected.weekday - 1));
    final items = d
        .onDay(selected)
        .where((e) => calendarKind == 'all' || e.kind == calendarKind)
        .toList();
    return [
      Panel(
        padding: 12,
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(
                    () => selected = selected.subtract(const Duration(days: 7)),
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${selected.year} 年 ${selected.month} 月',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => selected = dayOf(DateTime.now())),
                  child: const Text('今天'),
                ),
                IconButton(
                  onPressed: () => setState(
                    () => selected = selected.add(const Duration(days: 7)),
                  ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(7, (i) {
                final day = weekStart.add(Duration(days: i));
                final active = dateKey(day) == dateKey(selected);
                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => selected = day),
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: active ? V.blue : null,
                        borderRadius: BorderRadius.circular(15),
                        border: active
                            ? Border.all(color: V.ink, width: 2)
                            : null,
                      ),
                      child: Column(
                        children: [
                          Text(
                            '一二三四五六日'[i],
                            style: TextStyle(
                              fontSize: 10,
                              color: active ? V.ink : V.muted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: active ? V.ink : null,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: d.onDay(day).isEmpty
                                  ? Colors.transparent
                                  : active
                                  ? V.orange
                                  : V.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: ['all', ...kinds]
            .map(
              (k) => ChoiceChip(
                label: Text(k == 'all' ? '全部' : kindNames[k]!),
                selected: calendarKind == k,
                onSelected: (_) => setState(() => calendarKind = k),
              ),
            )
            .toList(),
      ),
      SectionTitle(
        '${dateKey(selected)} 的安排',
        trailing: TextButton.icon(
          onPressed: () => editEvent(context, controller: c, day: selected),
          icon: const Icon(Icons.add_rounded),
          label: const Text('添加安排'),
        ),
      ),
      if (items.isEmpty)
        EmptyState(
          '给这天留一点期待',
          '添加课程、组会、训练、餐食或习惯。',
          action: OutlinedButton(
            onPressed: () => editEvent(context, controller: c, day: selected),
            child: const Text('添加安排'),
          ),
        ),
      if (items.isNotEmpty)
        AgendaTimeline(events: items, onView: details, onComplete: complete),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: ai,
        icon: const Icon(Icons.file_download_outlined),
        label: const Text('导入 AI 计划 / .ics 课表'),
      ),
    ];
  }

  List<Widget> _training() {
    final workouts = d
        .onDay(selected)
        .where((e) => e.kind == 'workout')
        .toList();
    final since = dayOf(DateTime.now())
        .subtract(Duration(days: DateTime.now().weekday - 1));
    final count = d.events
        .where(
          (e) =>
              e.kind == 'workout' &&
              e.completed &&
              !e.start.isBefore(since) &&
              e.start.isBefore(since.add(const Duration(days: 7))),
        )
        .length;
    return [
      Panel(
        color: V.green,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Tag('MOVE AT YOUR PACE', color: V.ink),
            const SizedBox(height: 16),
            const Text(
              '每一次完成\n都算数。',
              style: TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w800,
                color: V.ink,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '本周已完成 $count 次训练',
              style: const TextStyle(color: V.muted, fontSize: 13),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      _dateStrip(),
      const SectionTitle('训练安排'),
      if (workouts.isEmpty)
        EmptyState(
          '这天没有训练计划',
          '休息也是计划的一部分。需要训练时，可通过 AI 制定合适的安排。',
          action: FilledButton(onPressed: ai, child: const Text('生成训练计划')),
          icon: Icons.fitness_center_outlined,
        ),
      for (final e in workouts)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Panel(
            onTap: () => session(e),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Tag(e.completed ? '已完成' : '待训练', color: V.green),
                    const Spacer(),
                    Text(
                      '${clock(e.start)}—${clock(e.end)}',
                      style: const TextStyle(fontSize: 11, color: V.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Text(
                  e.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${e.exercises.length} 个动作 · 支持逐组记录与休息计时',
                  style: const TextStyle(fontSize: 12, color: V.muted),
                ),
                const SizedBox(height: 16),
                ...e.exercises
                    .take(3)
                    .map(
                      (exercise) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '•  ${exercise['name']}  ${exercise['sets']} 组',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => session(e),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(e.completed ? '查看实际训练' : '进入训练'),
                  ),
                ),
              ],
            ),
          ),
        ),
      const SectionTitle('最近完成'),
      for (final e
          in (d.events.where((e) => e.kind == 'workout' && e.completed).toList()
                ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!)))
              .take(5))
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(padding: 6, child: _eventTile(e)),
        ),
    ];
  }

  void session(PlanItem e) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => WorkoutSession(c: c, id: e.id),
    ),
  );

  List<Widget> _profile() {
    final current = d.currentWeight, target = number(d.profile['targetWeight']);
    return [
      Panel(
        color: V.purple,
        child: Row(
          children: [
            const Buddy(size: 60),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.profile['name'] as String? ?? '元气同学',
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      color: V.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    d.profile['goals'] as String? ?? '',
                    style: const TextStyle(fontSize: 12, color: V.muted),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => editProfile(context, c),
              tooltip: '修改身体与生活条件',
              icon: const Icon(Icons.edit_outlined, color: V.ink),
            ),
          ],
        ),
      ),
      const SectionTitle('身体的小变化'),
      Panel(
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _stat(
                    '当前体重',
                    current?.toStringAsFixed(1) ?? '—',
                    'kg',
                    V.purple,
                  ),
                ),
                Expanded(
                  child: _stat(
                    '目标体重',
                    target?.toStringAsFixed(1) ?? '—',
                    'kg',
                    V.green,
                  ),
                ),
                Expanded(
                  child: _stat(
                    '本周均重',
                    d.weekAverage(DateTime.now())?.toStringAsFixed(1) ?? '—',
                    'kg',
                    V.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TrendChart(d.weights),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => logWeight(context, c),
                icon: const Icon(Icons.add),
                label: const Text('记录今天的体重'),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Panel(
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _stat(
                    'BMI',
                    d.bmi?.toStringAsFixed(1) ?? '—',
                    'kg/m²',
                    V.blue,
                  ),
                ),
                Expanded(
                  child: _stat(
                    '基础代谢估算',
                    d.bmr?.toStringAsFixed(0) ?? '—',
                    'kcal / 天',
                    V.purple,
                  ),
                ),
                Expanded(
                  child: _stat(
                    '每日消耗估算',
                    d.tdee?.toStringAsFixed(0) ?? '—',
                    'kcal / 天',
                    V.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              '能量消耗由身体数据和活动系数估算，可在档案中修改活动量；不代表实测结果。',
              style: TextStyle(fontSize: 12, color: V.muted, height: 1.6),
            ),
          ],
        ),
      ),
      const SectionTitle('作息与坚持'),
      _sleepPanel(),
      const SizedBox(height: 14),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '最近的习惯记录',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (d.habits.isEmpty)
              const Text(
                '在日程里添加每日习惯，完成后会记录在这里。',
                style: TextStyle(fontSize: 12, color: V.muted),
              ),
            for (final h in d.habits.reversed.take(7))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: V.purple, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        h['title'] as String,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      h['date'] as String,
                      style: const TextStyle(fontSize: 10, color: V.muted),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SectionTitle('我的记录'),
      Panel(
        padding: 6,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(
                Icons.monitor_weight_outlined,
                color: V.purple,
              ),
              title: const Text('体重记录'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => weightHistory(),
            ),
            ListTile(
              leading: const Icon(Icons.bedtime_outlined, color: V.purple),
              title: const Text('睡眠记录与作息目标'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => sleepHistory(),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined, color: V.blue),
              title: const Text('提醒设置'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => notificationSettings(),
            ),
            ListTile(
              leading: const Icon(Icons.backup_outlined, color: V.blue),
              title: const Text('备份与恢复'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => backups(),
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined, color: V.orange),
              title: const Text('主题风格'),
              trailing: DropdownButton<String>(
                value: d.settings['appearance'] as String? ?? 'classic',
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'classic', child: Text('经典蓝白')),
                  DropdownMenuItem(value: 'cartoon', child: Text('元气卡通')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    action(() => c.mutate((d) => d.settings['appearance'] = v));
                  }
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.brightness_6_outlined, color: V.blue),
              title: const Text('明暗模式'),
              trailing: DropdownButton<String>(
                value: d.settings['theme'] as String? ?? 'light',
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'light', child: Text('浅色')),
                  DropdownMenuItem(value: 'dark', child: Text('深色')),
                  DropdownMenuItem(value: 'system', child: Text('随系统')),
                ],
                onChanged: (v) =>
                    action(() => c.mutate((d) => d.settings['theme'] = v)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: V.muted),
              title: const Text('素材与指标说明'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => about(),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _stat(String label, String value, String unit, Color color) =>
      MetricTile(label: label, value: value, unit: unit, accent: color);
  Widget _sleepPanel() {
    final active = d.sleeps.where((s) => s['end'] == null).firstOrNull;
    final last = d.sleeps.where((s) => s['end'] != null).lastOrNull;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bedtime_outlined, color: V.purple),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  active != null
                      ? '正在休息 · ${clock(DateTime.parse(active['start'] as String))} 开始'
                      : '今晚，早点给自己充电',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            last == null
                ? '目标 ${d.settings['sleepTime']} 准备睡觉 · ${d.settings['wakeTime']} 起床'
                : '上次记录 ${DateTime.parse(last['end'] as String).difference(DateTime.parse(last['start'] as String)).inMinutes / 60 >= 0 ? (DateTime.parse(last['end'] as String).difference(DateTime.parse(last['start'] as String)).inMinutes / 60).toStringAsFixed(1) : '—'} 小时 · 目标 ${d.settings['sleepTime']} 睡觉',
            style: const TextStyle(fontSize: 11, color: V.muted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => action(
                    () => c.mutate((d) {
                      if (active == null) {
                        d.sleeps.add({
                          'id': newId(),
                          'start': DateTime.now().toIso8601String(),
                          'end': null,
                        });
                      } else {
                        final start = DateTime.parse(active['start'] as String);
                        require(
                          DateTime.now().isAfter(start) &&
                              DateTime.now().difference(start).inHours <= 48,
                          '这条记录已超过 48 小时，请通过补填修改时间',
                        );
                        active['end'] = DateTime.now().toIso8601String();
                      }
                    }),
                    message: active == null ? '已记录准备睡觉时间' : '已记录起床时间',
                  ),
                  icon: Icon(
                    active == null
                        ? Icons.bedtime_outlined
                        : Icons.wb_sunny_outlined,
                  ),
                  label: Text(active == null ? '准备睡觉' : '已起床'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => editSleep(context, c, original: active),
                child: const Text('补填'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> complete(PlanItem e) async {
    if (e.kind == 'meal') {
      await logMeal(context, c, e);
    } else if (e.kind == 'workout') {
      session(e);
    } else {
      await action(() => c.complete(e.id), message: '已完成「${e.title}」');
    }
  }

  Future<void> details(PlanItem original) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (routeContext) => AnimatedBuilder(
          animation: c,
          builder: (context, _) {
            final e = d.events.where((e) => e.id == original.id).firstOrNull;
            if (e == null) {
              return Scaffold(
                appBar: AppBar(title: const Text('事项已移除')),
                body: const Center(child: Text('返回查看其他安排')),
              );
            }
            return Scaffold(
              appBar: AppBar(
                title: Text(kindNames[e.kind]!),
                actions: [
                  if (!e.completed)
                    IconButton(
                      tooltip: '修改安排',
                      onPressed: () => editExisting(context, e),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                ],
              ),
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Panel(
                        color: V.color(e.kind).withValues(alpha: .15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Tag(
                              e.completed ? '已完成' : priorityNames[e.priority]!,
                              color: V.color(e.kind),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              e.title,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${dateKey(e.start)} ${clock(e.start)}—${clock(e.end)}',
                              style: const TextStyle(color: V.muted),
                            ),
                            if (e.details['location'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(e.details['location'] as String),
                              ),
                            const SizedBox(height: 10),
                            Text(
                              e.reminder && e.priority != 'quiet'
                                  ? '提前 ${e.leadMinutes} 分钟提醒${e.alarm ? ' · 闹钟' : ''}'
                                  : '只在计划中显示',
                              style: const TextStyle(
                                fontSize: 12,
                                color: V.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (e.kind == 'meal') ...[
                        const SectionTitle('计划营养'),
                        Panel(child: NutritionRow(e.nutrition)),
                        if (e.completed) ...[
                          const SectionTitle('实际摄入'),
                          Panel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.actual['title'] as String? ?? e.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                NutritionRow(
                                  Map<String, dynamic>.from(
                                    e.actual['nutrition'] as Map? ?? {},
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  e.deductions.isEmpty
                                      ? '本餐没有扣除库存'
                                      : '已按实际食材扣除库存',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: V.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SectionTitle('食材与用量'),
                        Panel(
                          child: Column(
                            children: [
                              for (final i in e.ingredients)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      FoodPicture(
                                        i['name'] as String,
                                        size: 36,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(i['name'] as String),
                                      ),
                                      Text(
                                        '${i['quantity']} ${i['unit']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (e.ingredients.isEmpty)
                                const Text('这道菜尚未提供食材'),
                            ],
                          ),
                        ),
                        const SectionTitle('简单做法'),
                        Panel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (
                                var i = 0;
                                i < (e.details['steps'] as List? ?? []).length;
                                i++
                              )
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Tag('${i + 1}', color: V.orange),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          (e.details['steps'] as List)[i]
                                              as String,
                                          style: const TextStyle(height: 1.9),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if ((e.details['steps'] as List? ?? []).isEmpty)
                                const Text('尚未提供制作步骤'),
                            ],
                          ),
                        ),
                      ],
                      if (e.details['notes'] != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            e.details['notes'] as String,
                            style: const TextStyle(color: V.muted, height: 1.8),
                          ),
                        ),
                      if (e.kind == 'workout') ...[
                        const SectionTitle('动作安排'),
                        Panel(
                          child: Column(
                            children: e.exercises
                                .map(
                                  (x) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(x['name'] as String),
                                    subtitle: Text(
                                      '${x['sets']} 组 · ${x['seconds'] != null ? '${x['seconds']} 秒' : '${x['reps'] ?? '自定'} 次'}',
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (!e.completed)
                        FilledButton.icon(
                          onPressed: () => complete(e),
                          icon: Icon(
                            e.kind == 'workout'
                                ? Icons.play_arrow
                                : Icons.check,
                          ),
                          label: Text(
                            e.kind == 'meal'
                                ? '按计划吃完 / 修改实际餐食'
                                : e.kind == 'workout'
                                ? '进入训练'
                                : '标记完成',
                          ),
                        )
                      else ...[
                        if (e.kind == 'meal')
                          FilledButton.tonal(
                            onPressed: () => logMeal(context, c, e),
                            child: const Text('修改实际餐食'),
                          ),
                        if (e.kind == 'workout')
                          FilledButton.tonal(
                            onPressed: () => session(e),
                            child: const Text('查看 / 修改逐组记录'),
                          ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () async {
                            if (await confirm(
                              context,
                              '撤销这次打卡？',
                              '会恢复本餐扣除的库存，并清除这次实际完成记录。训练逐组记录会一并清除。',
                              action: '撤销打卡',
                            )) {
                              await action(() => c.undoComplete(e.id));
                            }
                          },
                          child: const Text('撤销打卡'),
                        ),
                      ],
                      if (e.kind == 'meal')
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: TextButton.icon(
                            onPressed: () async {
                              final date = await chooseDate(context, selected);
                              if (date == null || !context.mounted) {
                                return;
                              }
                              final copy = PlanItem(
                                id: newId(),
                                kind: e.kind,
                                title: e.title,
                                start: DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  e.start.hour,
                                  e.start.minute,
                                ),
                                end: DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  e.start.hour,
                                  e.start.minute,
                                ).add(e.end.difference(e.start)),
                                priority: e.priority,
                                reminder: e.reminder,
                                leadMinutes: e.leadMinutes,
                                alarm: e.alarm,
                                details: cloneJson(e.details),
                              );
                              await editEvent(
                                context,
                                original: copy,
                                controller: c,
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('将这道菜加入其他日期'),
                          ),
                        ),
                      const SizedBox(height: 14),
                      TextButton.icon(
                        onPressed: () async {
                          if (await confirm(
                            context,
                            '移除这项安排？',
                            e.completed ? '实际记录也会移除，扣除的库存会恢复。' : '只移除这一次安排。',
                            action: '移除',
                          )) {
                            await action(
                              () => c.mutate((d) {
                                for (final stock in d.inventory) {
                                  stock.quantity +=
                                      number(e.deductions[stock.id]) ?? 0;
                                }
                                d.events.removeWhere((x) => x.id == e.id);
                                d.habits.removeWhere(
                                  (h) => h['eventId'] == e.id,
                                );
                              }),
                            );
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          }
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('移除安排'),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> editExisting(BuildContext context, PlanItem e) async {
    var all = false;
    if (e.groupId != null) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('修改重复安排'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('仅这一次'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('这次及后续未完成安排'),
            ),
          ],
        ),
      );
      if (result == null) {
        return;
      }
      all = result;
    }
    final previous = e.copy();
    if (!context.mounted) {
      return;
    }
    final saved = await editEvent(context, original: e);
    if (saved != null && !all) {
      await action(() => c.saveEvent(saved));
    } else if (saved != null && all) {
      await action(
        () => c.mutate((d) {
          final index = d.events.indexWhere((x) => x.id == saved.id);
          require(index >= 0 && !d.events[index].completed, '该事项已被修改，请重新打开');
          d.events[index] = saved.copy();
          final delta = saved.start.difference(previous.start);
          final duration = saved.end.difference(saved.start);
          for (final other in d.events.where(
            (x) =>
                x.id != saved.id &&
                x.groupId == previous.groupId &&
                !x.completed &&
                !x.start.isBefore(previous.start),
          )) {
            other.title = saved.title;
            other.kind = saved.kind;
            other.start = other.start.add(delta);
            other.end = other.start.add(duration);
            other.priority = saved.priority;
            other.reminder = saved.reminder;
            other.alarm = saved.alarm;
            other.leadMinutes = saved.leadMinutes;
            other.details = cloneJson(saved.details);
            validateItem(other);
          }
        }),
      );
    }
  }

  void weightHistory() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AnimatedBuilder(
        animation: c,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('体重记录')),
          floatingActionButton: FloatingActionButton(
            onPressed: () => logWeight(context, c),
            child: const Icon(Icons.add),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final w
                  in (d.weights.toList()..sort(
                    (a, b) =>
                        (b['date'] as String).compareTo(a['date'] as String),
                  )))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                    padding: 4,
                    child: ListTile(
                      title: Text('${w['value']} kg'),
                      subtitle: Text(w['date'] as String),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => logWeight(context, c, original: w),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  void sleepHistory() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AnimatedBuilder(
        animation: c,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('睡眠与作息')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _sleepPanel(),
              const SizedBox(height: 12),
              Panel(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('目标准备睡觉时间'),
                      trailing: Text(
                        d.settings['sleepTime'] as String? ?? '23:00',
                      ),
                      onTap: () => setSleepTime(context, 'sleepTime'),
                    ),
                    ListTile(
                      title: const Text('目标起床时间'),
                      trailing: Text(
                        d.settings['wakeTime'] as String? ?? '07:00',
                      ),
                      onTap: () => setSleepTime(context, 'wakeTime'),
                    ),
                    const Text(
                      '作息目标会写入 AI 提示词；提醒可在日程里另行设置。',
                      style: TextStyle(fontSize: 11, color: V.muted),
                    ),
                  ],
                ),
              ),
              const SectionTitle('实际记录'),
              for (final s in d.sleeps.reversed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                    padding: 4,
                    child: ListTile(
                      title: Text(
                        dateKey(DateTime.parse(s['start'] as String)),
                      ),
                      subtitle: Text(
                        '${clock(DateTime.parse(s['start'] as String))} → ${s['end'] == null ? '尚未记录起床' : clock(DateTime.parse(s['end'] as String))}',
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => editSleep(context, c, original: s),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  Future<void> setSleepTime(BuildContext context, String key) async {
    final parts = (d.settings[key] as String? ?? '23:00').split(':');
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );
    if (time != null) {
      await action(
        () => c.mutate(
          (d) => d.settings[key] =
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
        ),
      );
    }
  }

  void backups() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('备份与恢复')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Panel(
                  child: Text(
                    '一份备份包含身体档案、计划、实际记录、食材库存与设置。\n\n选择你自己的保存位置，换手机时可导入恢复。内置图片随应用提供。',
                    style: TextStyle(height: 1.9),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => exportBackup(context, c),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('导出完整备份'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => restoreBackup(context, c),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('选择备份并预览恢复'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    if (await confirm(
                      context,
                      '恢复上一份本机记录？',
                      '将当前记录替换为上次保存前的数据。建议先导出当前备份。',
                      action: '恢复上一份',
                    )) {
                      await action(c.restorePrevious, message: '已恢复上一份记录');
                    }
                  },
                  child: const Text('恢复上次操作前的记录'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Future<void> notificationSettings() async {
    final state = await c.reminders.status();
    if (!mounted) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatefulBuilder(
          builder: (context, set) => Scaffold(
            appBar: AppBar(title: const Text('提醒设置')),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (kIsWeb)
                      const Panel(
                        child: Text(
                          '浏览器用于体验界面。通知、锁屏闹钟和重启后的提醒，请在安卓应用中使用。',
                          style: TextStyle(height: 1.9),
                        ),
                      )
                    else ...[
                      Panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '通知权限：${state['notifications'] == true ? '已开启' : '未开启'}',
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonal(
                              onPressed: () async {
                                await c.reminders.requestNotifications();
                                final newState = await c.reminders.status();
                                set(() => state.addAll(newState));
                              },
                              child: const Text('开启通知 / 查看状态'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '准时提醒权限：${state['exact'] == true ? '已开启' : '未开启'}',
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '课程的提前提醒和闹钟需要准时触发。授权后返回应用，点击重新同步。',
                              style: TextStyle(
                                fontSize: 12,
                                color: V.muted,
                                height: 1.8,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: c.reminders.openExactSettings,
                              child: const Text('设置闹钟与提醒权限'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () async {
                          await c.syncReminders();
                          final newState = await c.reminders.status();
                          set(() => state.addAll(newState));
                          if (context.mounted) {
                            toast(context, c.reminderError ?? '已重新同步未来提醒');
                          }
                        },
                        child: const Text('重新同步提醒'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () async {
                          await c.reminders.test();
                          if (context.mounted) {
                            toast(context, '测试通知将在约 5 秒后触发');
                          }
                        },
                        child: const Text('发送测试通知'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: c.reminders.openAppSettings,
                        child: const Text('打开手机应用设置'),
                      ),
                      const Text(
                        'realme 手机如果限制后台活动，请在手机应用设置中允许元气簿的后台运行，并在真机上测试锁屏提醒。',
                        style: TextStyle(
                          fontSize: 12,
                          color: V.muted,
                          height: 1.8,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Panel(
                      child: Text(
                        '重要：课程、组会默认提前 15 分钟通知，闹钟可选。\n普通：训练等到点通知。\n安静：只在今日计划中展示。\n\n每项安排都可以修改等级、提前时间和闹钟开关。',
                        style: TextStyle(height: 1.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> about() async {
    final license = await rootBundle.loadString(
      'assets/licenses/OpenMoji-CC-BY-SA-4.0.txt',
    );
    if (!mounted) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('关于元气簿')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    '元气簿 Vitalog',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'BMI：体重 kg ÷ 身高 m 的平方。\n基础代谢：Mifflin–St Jeor 公式估算，18 岁以下不显示成人能量估算。\n每日消耗：代谢估算 × 你选择的活动系数。\n营养信息：来自你导入的 AI 计划与实际修改，不是食物检测值。',
                    style: TextStyle(height: 2),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '食材插画：OpenMoji 17.0.0，HfG Schwäbisch Gmünd 及贡献者，CC BY-SA 4.0，未修改。\n饮食配图：使用 ImageGen 生成，仅作为配图，不对应每一道菜。\n字体：Noto Sans SC，SIL Open Font License。',
                    style: TextStyle(fontSize: 12, height: 2),
                  ),
                  const SizedBox(height: 16),
                  ExpansionTile(
                    title: const Text('OpenMoji 许可全文'),
                    children: [
                      SelectableText(
                        license,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => showLicensePage(
                      context: context,
                      applicationName: '元气簿 Vitalog',
                      applicationVersion: '0.1.0',
                    ),
                    child: const Text('查看依赖许可'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
