// ─────────────────────────────────────────────────────────────
// lib/features/settings/providers/settings_providers.dart
// ─────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../library/providers/library_providers.dart';

// ── Color theme ────────────────────────────────────────────────

enum AppColorTheme {
  dynamic,
  scarlet,
  ocean,
  forest,
  lavender,
  sunset,
  slate,
}

extension AppColorThemeInfo on AppColorTheme {
  String get label => switch (this) {
        AppColorTheme.dynamic => 'Dynamic',
        AppColorTheme.scarlet => 'Scarlet',
        AppColorTheme.ocean => 'Ocean',
        AppColorTheme.forest => 'Forest',
        AppColorTheme.lavender => 'Lavender',
        AppColorTheme.sunset => 'Sunset',
        AppColorTheme.slate => 'Slate',
      };

  // null means "use system dynamic color" (only valid for AppColorTheme.dynamic)
  Color? get seedColor => switch (this) {
        AppColorTheme.dynamic => null,
        AppColorTheme.scarlet => const Color(0xFFC0392B),
        AppColorTheme.ocean => const Color(0xFF1A6B8A),
        AppColorTheme.forest => const Color(0xFF2D6A4F),
        AppColorTheme.lavender => const Color(0xFF7C6FAF),
        AppColorTheme.sunset => const Color(0xFFE07B39),
        AppColorTheme.slate => const Color(0xFF607D8B),
      };
}

class AppColorThemeNotifier extends Notifier<AppColorTheme> {
  static const _key = 'settings_color_theme';

  @override
  AppColorTheme build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final stored = prefs.getString(_key);
    if (stored != null) {
      return AppColorTheme.values.firstWhere(
        (t) => t.name == stored,
        orElse: () => _defaultTheme,
      );
    }
    return _defaultTheme;
  }

  // Dynamic on Android if supported; Ocean everywhere else
  AppColorTheme get _defaultTheme {
    if (!kIsWeb && Platform.isAndroid) return AppColorTheme.dynamic;
    return AppColorTheme.ocean;
  }

  void set(AppColorTheme theme) {
    state = theme;
    ref.read(sharedPreferencesProvider).setString(_key, theme.name);
  }
}

final appColorThemeProvider =
    NotifierProvider<AppColorThemeNotifier, AppColorTheme>(
  AppColorThemeNotifier.new,
);

// ── Theme mode (Light / Dark / System) ────────────────────────

class AppThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'settings_theme_mode';

  @override
  ThemeMode build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final stored = prefs.getString(_key);
    return ThemeMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  void set(ThemeMode mode) {
    state = mode;
    ref.read(sharedPreferencesProvider).setString(_key, mode.name);
  }
}

final appThemeModeProvider =
    NotifierProvider<AppThemeModeNotifier, ThemeMode>(
  AppThemeModeNotifier.new,
);

// ── Cloud backup toggle ────────────────────────────────────────

class CloudBackupEnabledNotifier extends Notifier<bool> {
  static const _key = 'settings_cloud_backup';

  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? false;
  }

  void set(bool enabled) {
    state = enabled;
    ref.read(sharedPreferencesProvider).setBool(_key, enabled);
  }
}

final cloudBackupEnabledProvider =
    NotifierProvider<CloudBackupEnabledNotifier, bool>(
  CloudBackupEnabledNotifier.new,
);

// ── Last sync timestamp ────────────────────────────────────────

final lastSyncedProvider = Provider<DateTime?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final ts = prefs.getString('settings_last_synced');
  return ts != null ? DateTime.tryParse(ts) : null;
});

// ── Package info ───────────────────────────────────────────────

final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return PackageInfo.fromPlatform();
});
