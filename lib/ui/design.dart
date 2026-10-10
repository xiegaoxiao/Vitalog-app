import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/models.dart';

class VitalogAppearance extends ThemeExtension<VitalogAppearance> {
  const VitalogAppearance({required this.cartoon});
  final bool cartoon;

  @override
  VitalogAppearance copyWith({bool? cartoon}) =>
      VitalogAppearance(cartoon: cartoon ?? this.cartoon);
  @override
  VitalogAppearance lerp(covariant VitalogAppearance? other, double t) =>
      other == null || t < .5 ? this : other;
}

class V {
  static const ink = Color(0xFF292723);
  static const paper = Color(0xFFFFE7EF);
  static const cream = Color(0xFFFFFDF5);
  static const pink = Color(0xFFF3A2C4);
  static const blue = Color(0xFFB9B7ED);
  static const orange = Color(0xFFF5C77E);
  static const green = Color(0xFFA8D6B5);
  static const purple = Color(0xFFD5B9E8);
  static const muted = Color(0xFF756769);
  static bool isCartoon(BuildContext context) =>
      Theme.of(context).extension<VitalogAppearance>()?.cartoon ?? false;
  static Color moduleColor(BuildContext context, String kind) =>
      isCartoon(context)
      ? color(kind)
      : switch (kind) {
          'meal' => const Color(0xFFF19761),
          'workout' => const Color(0xFF36AD9F),
          'habit' => const Color(0xFF9673CF),
          _ => const Color(0xFF3854EF),
        };
  static Color panelColor(BuildContext context, Color? color) {
    final surface = Theme.of(context).colorScheme.surface;
    if (color == null) return surface;
    if (isCartoon(context)) return color;
    final kind = color == orange
        ? 'meal'
        : color == green
        ? 'workout'
        : color == purple
        ? 'habit'
        : 'course';
    if ([blue, orange, green, purple, pink].contains(color)) {
      return Color.alphaBlend(
        moduleColor(context, kind).withValues(alpha: .1),
        surface,
      );
    }
    return color == cream ? surface : color;
  }

  static String mealImage(BuildContext context) => isCartoon(context)
      ? 'assets/images/meal-cartoon.png'
      : 'assets/images/meal-hero.png';
  static const buttonTextStyle = TextStyle(
    fontFamily: 'NotoSansSC',
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.35,
  );
  static Color color(String kind) => switch (kind) {
    'meal' => orange,
    'workout' => green,
    'habit' => purple,
    _ => blue,
  };
  static IconData icon(String kind) => switch (kind) {
    'meal' => Icons.restaurant_rounded,
    'workout' => Icons.fitness_center_rounded,
    'course' => Icons.school_outlined,
    'meeting' => Icons.groups_outlined,
    'habit' => Icons.auto_awesome_outlined,
    _ => Icons.event_outlined,
  };
  static ThemeData theme(Brightness brightness, {bool cartoon = false}) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: cartoon ? blue : const Color(0xFF3854EF),
          brightness: brightness,
          surface: dark
              ? const Color(0xFF302D36)
              : cartoon
              ? cream
              : Colors.white,
        ).copyWith(
          primary: cartoon
              ? (dark ? pink : ink)
              : (dark ? const Color(0xFFB8C2FF) : const Color(0xFF3854EF)),
          onPrimary: cartoon
              ? (dark ? ink : cream)
              : (dark ? ink : Colors.white),
          secondaryContainer: cartoon ? pink : const Color(0xFFE7EAFF),
          onSecondaryContainer: ink,
          outline: cartoon
              ? (dark ? const Color(0xFFDBCFD4) : ink)
              : (dark ? const Color(0xFF676B7D) : const Color(0xFFDDE1ED)),
        );
    return ThemeData(
      useMaterial3: true,
      extensions: [VitalogAppearance(cartoon: cartoon)],
      colorScheme: scheme,
      fontFamily: 'NotoSansSC',
      scaffoldBackgroundColor: dark
          ? const Color(0xFF211E29)
          : cartoon
          ? paper
          : const Color(0xFFF7F8FD),
      textTheme: Typography.material2021().black.apply(
        fontFamily: 'NotoSansSC',
        bodyColor: dark ? Colors.white : ink,
        displayColor: dark ? Colors.white : ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: dark
            ? const Color(0xFF211E29)
            : cartoon
            ? paper
            : const Color(0xFFF7F8FD),
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark
            ? const Color(0xFF3F3744)
            : cartoon
            ? cream
            : const Color(0xFFF6F7FC),
        // Draw a full rounded stroke without moving labels onto the top edge.
        border: const DoodleInputBorder(),
        enabledBorder: DoodleInputBorder(
          borderSide: BorderSide(color: scheme.outline, width: 1.8),
        ),
        focusedBorder: DoodleInputBorder(
          borderSide: BorderSide(color: scheme.outline, width: 2.8),
        ),
        errorBorder: DoodleInputBorder(
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        focusedErrorBorder: DoodleInputBorder(
          borderSide: BorderSide(color: scheme.error, width: 2.8),
        ),
        alignLabelWithHint: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cartoon ? pink : scheme.primary,
          foregroundColor: cartoon ? ink : scheme.onPrimary,
          textStyle: buttonTextStyle,
          iconSize: 18,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: cartoon
                ? const BorderSide(color: ink, width: 2)
                : BorderSide.none,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          foregroundColor: dark ? cream : ink,
          textStyle: buttonTextStyle,
          iconSize: 18,
          side: BorderSide(color: scheme.outline, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          backgroundColor: scheme.surface,
          foregroundColor: dark ? cream : ink,
          textStyle: buttonTextStyle,
          iconSize: 18,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          side: BorderSide(color: scheme.outline, width: 1.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: cartoon
              ? BorderSide(color: scheme.outline, width: 2.5)
              : BorderSide.none,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surface,
        selectedColor: cartoon ? orange : scheme.secondaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        showCheckmark: true,
        checkmarkColor: ink,
        iconTheme: const IconThemeData(size: 18),
        side: BorderSide(color: scheme.outline, width: 1.7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: WidgetStateTextStyle.resolveWith(
          (states) => TextStyle(
            color: dark && !states.contains(WidgetState.selected) ? cream : ink,
            fontFamily: 'NotoSansSC',
            fontSize: 14,
            height: 1.4,
            letterSpacing: 0,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: cartoon
              ? const BorderSide(color: ink, width: 2)
              : BorderSide.none,
        ),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'NotoSansSC',
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: dark ? cream : ink,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.outline, width: 2),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? scheme.secondaryContainer
                : scheme.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                dark && !states.contains(WidgetState.selected) ? cream : ink,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: dark ? Colors.white12 : const Color(0xFFEDF0F5),
      ),
    );
  }
}

/// Filled-layout labels with a complete cartoon outline, including on focus.
class DoodleInputBorder extends InputBorder {
  const DoodleInputBorder({
    super.borderSide = const BorderSide(color: V.ink, width: 1.8),
    this.radius = 14,
  });
  final double radius;
  @override
  bool get isOutline => false;
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(borderSide.width);
  @override
  DoodleInputBorder copyWith({BorderSide? borderSide}) => DoodleInputBorder(
    borderSide: borderSide ?? this.borderSide,
    radius: radius,
  );
  @override
  DoodleInputBorder scale(double t) =>
      DoodleInputBorder(borderSide: borderSide.scale(t), radius: radius * t);
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(
        RRect.fromRectAndRadius(
          rect.deflate(borderSide.width),
          Radius.circular(max(0, radius - borderSide.width)),
        ),
      );
  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0,
    double gapPercentage = 0,
    TextDirection? textDirection,
  }) {
    if (borderSide.style != BorderStyle.none) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(borderSide.width / 2),
          Radius.circular(radius),
        ),
        borderSide.toPaint(),
      );
    }
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) => a is DoodleInputBorder
      ? DoodleInputBorder(
          borderSide: BorderSide.lerp(a.borderSide, borderSide, t),
          radius: a.radius + (radius - a.radius) * t,
        )
      : super.lerpFrom(a, t);
  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) =>
      b is DoodleInputBorder ? b.lerpFrom(this, t) : super.lerpTo(b, t);
}

class Buddy extends StatelessWidget {
  const Buddy({super.key, this.size = 100});
  final double size;
  @override
  Widget build(BuildContext context) => V.isCartoon(context)
      ? Image.asset(
          'assets/images/vitalog-buddy.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        )
      : Icon(
          Icons.spa_rounded,
          size: size,
          color: Theme.of(context).colorScheme.primary,
        );
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.color,
    this.padding = 20,
    this.onTap,
  });
  final Widget child;
  final Color? color;
  final double padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    container: onTap != null,
    button: onTap != null,
    onTap: onTap,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: V.isCartoon(context)
            ? const [BoxShadow(color: V.ink, offset: Offset(3, 4))]
            : const [],
      ),
      child: Material(
        color: V.panelColor(context, color),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: V.isCartoon(context)
              ? BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                  width: 2.5,
                )
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          excludeFromSemantics: onTap != null,
          child: Padding(padding: EdgeInsets.all(padding), child: child),
        ),
      ),
    ),
  );
}

/// A small sticker-style entry point that belongs inside a colored card.
class CardAction extends StatelessWidget {
  const CardAction({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      backgroundColor: V.isCartoon(context)
          ? V.cream
          : Theme.of(context).colorScheme.surface,
      foregroundColor: V.isCartoon(context)
          ? V.ink
          : Theme.of(context).colorScheme.onSurface,
      side: BorderSide(
        color: V.isCartoon(context)
            ? V.ink
            : Theme.of(context).colorScheme.outline,
        width: 1.8,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(label)),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward_rounded, size: 18),
      ],
    ),
  );
}

class Tag extends StatelessWidget {
  const Tag(
    this.text, {
    super.key,
    this.color = V.blue,
    this.solid = false,
    this.foregroundColor,
  });
  final String text;
  final Color color;
  final bool solid;
  final Color? foregroundColor;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: V.panelColor(context, color == V.ink ? V.cream : color),
      borderRadius: BorderRadius.circular(8),
      border: V.isCartoon(context)
          ? Border.all(color: V.ink, width: 1.4)
          : null,
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: foregroundColor ?? V.ink,
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing, this.subtitle});
  final String title;
  final Widget? trailing;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 12, color: V.muted),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
    this.title,
    this.subtitle, {
    super.key,
    this.action,
    this.icon = Icons.spa_outlined,
  });
  final String title, subtitle;
  final Widget? action;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            const Buddy(size: 76),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: V.orange,
                shape: BoxShape.circle,
                border: Border.all(color: V.ink, width: 1.5),
              ),
              child: Icon(icon, size: 20, color: V.ink),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: V.muted, height: 1.8),
        ),
        if (action != null)
          Padding(padding: const EdgeInsets.only(top: 16), child: action!),
      ],
    ),
  );
}

String foodAsset(String name) {
  for (final entry in {
    '红薯': 'sweetpotato',
    '土豆': 'potato',
    '番茄': 'tomato',
    '西红柿': 'tomato',
    '黄瓜': 'cucumber',
    '胡萝卜': 'carrot',
    '西兰花': 'broccoli',
    '苹果': 'apple',
    '香蕉': 'banana',
    '玉米': 'corn',
    '鸡蛋': 'egg',
    '鸡': 'chicken',
    '奶': 'milk',
    '菜': 'greens',
    '桃': 'peach',
    '橙': 'orange',
    '面包': 'bread',
  }.entries) {
    if (name.contains(entry.key)) {
      return entry.value;
    }
  }
  return 'greens';
}

class FoodPicture extends StatelessWidget {
  const FoodPicture(this.name, {super.key, this.size = 42});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/food/${foodAsset(name)}.svg',
    width: size,
    height: size,
    semanticsLabel: name,
    placeholderBuilder: (_) =>
        Icon(Icons.eco_outlined, size: size, color: V.green),
  );
}

/// Shared, readable typography for nutrition and body measurements.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    this.compact = false,
    this.accent,
  });
  final String label, value, unit;
  final bool compact;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$label $value $unit',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: accent == null ? 0 : 42),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (accent != null) ...[
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: compact ? 13 : 14,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 5,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: compact ? 20 : 22,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                  height: 1.3,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class NutritionRow extends StatelessWidget {
  const NutritionRow(this.nutrition, {super.key, this.compact = false});
  final Json nutrition;
  final bool compact;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 16.0;
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final minimum = (compact ? 110 : 120) * scale;
      final columns = constraints.maxWidth >= minimum * 4 + gap * 3
          ? 4
          : constraints.maxWidth >= minimum * 2 + gap
          ? 2
          : 1;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: compact ? 14 : 18,
        children: [
          for (final key in nutrientKeys)
            SizedBox(
              width: width,
              child: MetricTile(
                label: nutrientNames[key]!,
                value: _value(key),
                unit: key == 'calories' ? 'kcal' : 'g',
                compact: compact,
              ),
            ),
        ],
      );
    },
  );

  String _value(String key) {
    final value = number(nutrition[key]);
    if (value == null) return '—';
    final text = value.toStringAsFixed(key == 'calories' ? 0 : 1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }
}

Future<DateTime?> chooseDateTime(BuildContext context, DateTime initial) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(2040),
  );
  if (date == null || !context.mounted) {
    return null;
  }
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  return time == null
      ? null
      : DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

Future<DateTime?> chooseDate(BuildContext context, DateTime initial) =>
    showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
void toast(BuildContext context, String message) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

String errorText(Object e) => e is FormatException
    ? e.message.toString()
    : '操作未完成，请检查输入或存储空间后重试。${e is ArgumentError ? ' 输入格式无效。' : ''}';
Future<bool> confirm(
  BuildContext context,
  String title,
  String text, {
  String action = '确认',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

class EditorDialog extends StatefulWidget {
  const EditorDialog({
    super.key,
    required this.title,
    required this.child,
    required this.onSave,
    this.label = '保存',
  });
  final String title, label;
  final Widget child;
  final Future<void> Function() onSave;
  @override
  State<EditorDialog> createState() => _EditorDialogState();
}

class _EditorDialogState extends State<EditorDialog> {
  bool busy = false;
  String? error;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outline,
        width: 2.5,
      ),
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 580,
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: busy ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(child: SingleChildScrollView(child: widget.child)),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        setState(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          await widget.onSave();
                          if (context.mounted) {
                            Navigator.pop(context, true);
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
                child: busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(widget.label),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget field(
  TextEditingController c,
  String label, {
  bool numeric = false,
  int lines = 1,
  String? hint,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: TextField(
    controller: c,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true)
        : lines > 1
        ? TextInputType.multiline
        : TextInputType.text,
    maxLines: lines,
    decoration: InputDecoration(labelText: label, hintText: hint),
  ),
);
Widget rowFields(Widget a, Widget b) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(child: a),
    const SizedBox(width: 12),
    Expanded(child: b),
  ],
);

class TrendChart extends StatelessWidget {
  const TrendChart(this.records, {super.key});
  final List<Json> records;
  @override
  Widget build(BuildContext context) {
    final sorted = [...records]
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    final values = sorted.length > 14
        ? sorted.sublist(sorted.length - 14)
        : sorted;
    if (values.length < 2) {
      return const SizedBox(
        height: 130,
        child: Center(
          child: Text(
            '记录两次体重后，会在这里看到趋势',
            style: TextStyle(fontSize: 12, color: V.muted),
          ),
        ),
      );
    }
    return Semantics(
      label:
          '最近 ${values.length} 次体重：${values.first['value']} 到 ${values.last['value']} 千克',
      child: Column(
        children: [
          SizedBox(
            height: 140,
            width: double.infinity,
            child: CustomPaint(
              painter: _TrendPainter(
                values.map((e) => number(e['value'])!).toList(),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                (values.first['date'] as String).substring(5),
                style: const TextStyle(fontSize: 11, color: V.muted),
              ),
              Text(
                (values.last['date'] as String).substring(5),
                style: const TextStyle(fontSize: 11, color: V.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.values);
  final List<double> values;
  @override
  void paint(Canvas canvas, Size size) {
    final lo = values.reduce(min) - .2, hi = values.reduce(max) + .2;
    final line = Paint()
      ..color = V.purple
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final path = Path();
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final p = Offset(
        i / (values.length - 1) * size.width,
        12 + (hi - values[i]) / (hi - lo) * (size.height - 24),
      );
      points.add(p);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(
        Offset(0, size.height * i / 4),
        Offset(size.width, size.height * i / 4),
        Paint()..color = V.muted.withValues(alpha: .12),
      );
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x339474E8), Color(0x009474E8)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(path, line);
    for (final point in points) {
      canvas.drawCircle(point, 3, Paint()..color = V.purple);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.values.toString() != values.toString();
}
