import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'screens/splash_screen.dart';
import 'services/language_service.dart';
import 'services/notifier.dart';
import 'services/store.dart';

// MedRemind: medication reminders for Luweero Health Centre outpatients.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.init();
  await Notifier.init();
  for (final medication in Store.meds) {
    await Notifier.schedule(medication);
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
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
    if (state == AppLifecycleState.resumed) {
      for (final medication in Store.meds) {
        Notifier.schedule(medication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.currentLanguage,
      builder: (context, lang, child) {
        return MaterialApp(
          title: 'MedRemind',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: AppColors.background,
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              centerTitle: true,
            ),
          ),
          // Keep the app phone-width when opened on a wide browser window.
          builder: (context, widgetChild) => ColoredBox(
            color: const Color(0xFFE2E8F0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: widgetChild,
              ),
            ),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}
