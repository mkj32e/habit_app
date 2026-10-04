import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'data/habit_store.dart';
import 'services/background.dart';
import 'services/desktop_service.dart';
import 'services/notification_service.dart';
import 'services/social_service.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/shell.dart';
import 'ui/widgets/celebration.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  await DesktopService.init();
  await NotificationService.init();
  if (!kIsWeb && Platform.isAndroid) {
    await HomeWidget.registerInteractivityCallback(widgetInteractivityCallback);
  }

  final social = SocialService();
  final store = HabitStore(social);
  await store.load();
  await social.init(store.settings);

  NotificationService.foregroundHandler = store.handleNotifAction;
  unawaited(NotificationService.handleLaunchDetails());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: social),
        ChangeNotifierProvider(create: (_) => DesktopService()),
        Provider(create: (_) => CelebrationController(), dispose: (_, c) => c.dispose()),
      ],
      child: const RituelApp(),
    ),
  );
}

class RituelApp extends StatefulWidget {
  const RituelApp({super.key});

  @override
  State<RituelApp> createState() => _RituelAppState();
}

class _RituelAppState extends State<RituelApp> with WidgetsBindingObserver {
  DateTime _lastResume = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Widget taps / notification actions may have written to disk meanwhile,
    // and the day may have changed: reload and rebuild the reminder window.
    if (DateTime.now().difference(_lastResume) > const Duration(seconds: 2)) {
      _lastResume = DateTime.now();
      context.read<HabitStore>().reloadFromDisk();
      context.read<SocialService>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.select<HabitStore, (ThemeMode, int, bool)>(
      (s) => (s.settings.themeMode, s.settings.accent, s.settings.onboardingDone),
    );
    final accent = Color(settings.$2);
    return MaterialApp(
      title: 'Rituel',
      debugShowCheckedModeBanner: false,
      themeMode: settings.$1,
      theme: buildTheme(Brightness.light, accent),
      darkTheme: buildTheme(Brightness.dark, accent),
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => ConfettiLayer(child: child!),
      home: settings.$3 ? const Shell() : const OnboardingScreen(),
    );
  }
}
