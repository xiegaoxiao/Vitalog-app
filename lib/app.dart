import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/controller.dart';
import 'ui/design.dart';
import 'ui/home.dart';

class VitalogApp extends StatelessWidget {
  const VitalogApp({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => MaterialApp(
      title: '元气簿 Vitalog',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: localizationDelegates,
      theme: V.theme(Brightness.light),
      darkTheme: V.theme(Brightness.dark),
      themeMode: switch (controller.data.settings['theme']) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      },
      home: Home(controller: controller),
    ),
  );
}

// Kept as a separate library so domain and widget tests do not start storage.
const localizationDelegates = <LocalizationsDelegate<dynamic>>[
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];
