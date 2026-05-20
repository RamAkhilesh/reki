// ─────────────────────────────────────────────────────────────
// lib/main.dart
// ─────────────────────────────────────────────────────────────

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/library/providers/library_providers.dart';
import 'features/settings/providers/settings_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  assert(
    SupabaseConfig.url.isNotEmpty && SupabaseConfig.anonKey.isNotEmpty,
    'Missing Supabase credentials.\n'
    'Run with: flutter run --dart-define-from-file=secrets.json',
  );

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MediaVaultApp(),
    ),
  );
}

class MediaVaultApp extends ConsumerWidget {
  const MediaVaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final colorTheme = ref.watch(appColorThemeProvider);
    final themeMode = ref.watch(appThemeModeProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        // Only apply dynamic color when that option is selected and device supports it
        final useDynamic =
            colorTheme == AppColorTheme.dynamic &&
            lightDynamic != null &&
            darkDynamic != null;

        return MaterialApp.router(
          title: 'reki',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(
            dynamicScheme: useDynamic ? lightDynamic : null,
            seedColor: colorTheme.seedColor,
          ),
          darkTheme: AppTheme.dark(
            dynamicScheme: useDynamic ? darkDynamic : null,
            seedColor: colorTheme.seedColor,
          ),
          themeMode: themeMode,
          routerConfig: router,
        );
      },
    );
  }
}
