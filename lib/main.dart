import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'screens/main_shell.dart';
import 'screens/web_admin_dashboard.dart';
import 'services/app_state.dart';

const String kMapboxAccessToken =
    'pk.eyJ1IjoibWFydWZhdGZvbnR5cyIsImEiOiJjbXdiOWwybmMwZGw0MnhzZngxN2QxdHN2In0.neL9Qhxoz56PBPy1UQa1Yg';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MapboxOptions.setAccessToken(kMapboxAccessToken);
  runApp(FestivalBuddyApp());
}

class FestivalBuddyApp extends StatefulWidget {
  FestivalBuddyApp({super.key, AppState? appState})
      : appState = appState ?? AppState();

  final AppState appState;

  @override
  State<FestivalBuddyApp> createState() => _FestivalBuddyAppState();
}

class _FestivalBuddyAppState extends State<FestivalBuddyApp> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        final isDark = widget.appState.isHighContrastNightMode;

        final colorScheme = ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C3AED),
          primary: isDark ? const Color(0xFFA855F7) : const Color(0xFF6D28D9),
          secondary: const Color(0xFFFF2E93),
          tertiary: isDark ? const Color(0xFF00E5FF) : const Color(0xFF0284C7),
          brightness: isDark ? Brightness.dark : Brightness.light,
        );

        return MaterialApp(
          title: 'Festival Buddy',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: colorScheme,
            scaffoldBackgroundColor: isDark
                ? const Color(0xFF0B0A14)
                : const Color(0xFFF6F5FF),
            appBarTheme: AppBarTheme(
              backgroundColor: isDark
                  ? const Color(0xFF0B0A14)
                  : const Color(0xFFF6F5FF),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              color: isDark ? const Color(0xFF161426) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE5E0FF),
                ),
              ),
            ),
          ),
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(widget.appState.textScale),
              ),
              child: child!,
            );
          },
          home: kIsWeb
              ? WebAdminDashboardScreen(appState: widget.appState)
              : MainShellScreen(appState: widget.appState),
        );
      },
    );
  }
}
