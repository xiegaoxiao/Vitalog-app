import 'package:flutter/material.dart';

import '../data/models.dart';
import 'design.dart';

/// A compact timeline with a separate, readable card for each arrangement.
class AgendaTimeline extends StatelessWidget {
  const AgendaTimeline({
    super.key,
    required this.events,
    required this.onView,
    required this.onComplete,
  });

  final List<PlanItem> events;
  final ValueChanged<PlanItem> onView;
  final ValueChanged<PlanItem> onComplete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    return Column(
      children: [
        for (var i = 0; i < events.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == events.length - 1 ? 0 : 12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 46,
                    child: Column(
                      children: [
                        const SizedBox(height: 14),
                        Text(
                          clock(events[i].start),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          clock(events[i].end),
                          style: TextStyle(fontSize: 10, color: muted),
                        ),
                        if (i < events.length - 1)
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.only(top: 10),
                              decoration: BoxDecoration(
                                color: scheme.outline.withValues(alpha: .18),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _card(context, events[i])),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _card(BuildContext context, PlanItem event) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final color = V.color(event.kind);
    return Material(
      color: Color.alphaBlend(color.withValues(alpha: .2), scheme.surface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outline, width: 1.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onView(event),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: V.ink, width: 1.4),
                    ),
                    child: Icon(V.icon(event.kind), size: 18, color: V.ink),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      event.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: event.completed ? '查看完成记录' : '记录完成',
                    onPressed: () =>
                        event.completed ? onView(event) : onComplete(event),
                    style: IconButton.styleFrom(
                      foregroundColor: V.ink,
                      backgroundColor: event.completed ? color : V.cream,
                      side: const BorderSide(color: V.ink, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      fixedSize: const Size(36, 36),
                      padding: const EdgeInsets.all(4),
                      tapTargetSize: MaterialTapTargetSize.padded,
                    ),
                    icon: event.completed
                        ? const Icon(Icons.check_rounded, size: 20)
                        : const Text(
                            '打卡',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      kindNames[event.kind] ?? '日程',
                      style: const TextStyle(fontSize: 10, color: V.ink),
                    ),
                  ),
                  Text(
                    event.completed ? '已完成' : '待完成',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                  if (event.reminder && event.priority == 'important')
                    _note(
                      event.alarm
                          ? Icons.alarm_rounded
                          : Icons.notifications_none_rounded,
                      '提前 ${event.leadMinutes} 分钟',
                      muted,
                    )
                  else if (event.alarm)
                    _note(Icons.alarm_rounded, '闹钟', muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _note(IconData icon, String label, Color muted) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: muted),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 10, color: muted)),
    ],
  );
}
