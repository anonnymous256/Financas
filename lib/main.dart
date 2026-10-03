import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'providers/app_providers.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (details) {
    return const Material(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Algo inesperado aconteceu. Atualize a página e tente novamente.'),
        ),
      ),
    );
  };
  final preferences = await SharedPreferences.getInstance();
  final configured = firebaseIsConfigured;
  if (configured) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  runApp(
    ProviderScope(
      overrides: [
        firebaseReadyProvider.overrideWithValue(configured),
        prefsProvider.overrideWithValue(preferences),
      ],
      child: const FinancasApp(),
    ),
  );
}

class FinancasApp extends ConsumerWidget {
  const FinancasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Finanças',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
    );
  }
}
