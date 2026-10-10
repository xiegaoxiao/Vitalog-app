import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'app.dart';
import 'data/controller.dart';
import 'data/demo.dart';
import 'ui/design.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  if (kIsWeb) {
    SemanticsBinding.instance.ensureSemantics();
  }
  final controller = AppController();
  try {
    await controller.load();
    if (kIsWeb &&
        Uri.base.queryParameters['demo'] == '1' &&
        controller.data.profile.isEmpty) {
      controller.data = demoData(DateTime.now());
    }
    runApp(VitalogApp(controller: controller));
  } catch (e) {
    runApp(
      MaterialApp(
        theme: V.theme(Brightness.light),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storage_outlined, size: 48, color: V.blue),
                  const SizedBox(height: 16),
                  const Text(
                    '本机记录暂时无法读取',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(errorText(e), textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () async {
                      try {
                        await controller.load();
                        runApp(VitalogApp(controller: controller));
                      } catch (_) {
                        /* Keep the current data intact. */
                      }
                    },
                    child: const Text('重新读取'),
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        await controller.restorePrevious();
                        runApp(VitalogApp(controller: controller));
                      } catch (_) {
                        /* No valid previous snapshot; never silently reset. */
                      }
                    },
                    child: const Text('尝试恢复上一份记录'),
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
