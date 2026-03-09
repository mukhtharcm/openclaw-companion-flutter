import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openclaw_companion/app/controller.dart';
import 'package:openclaw_companion/ui/home.dart';

class OpenClawCompanionBootstrap extends StatefulWidget {
  const OpenClawCompanionBootstrap({super.key});

  @override
  State<OpenClawCompanionBootstrap> createState() =>
      _OpenClawCompanionBootstrapState();
}

class _OpenClawCompanionBootstrapState
    extends State<OpenClawCompanionBootstrap> {
  late final Future<CompanionController> _controllerFuture =
      CompanionController.bootstrap();

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.manropeTextTheme();
    final displayTextTheme = GoogleFonts.spaceGroteskTextTheme(baseTextTheme);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OpenClaw Companion',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFEFE8DE),
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF162220),
          onPrimary: Colors.white,
          secondary: Color(0xFF7A5C38),
          onSecondary: Colors.white,
          error: Color(0xFFB42318),
          onError: Colors.white,
          surface: Color(0xFFF8F4ED),
          onSurface: Color(0xFF1B2220),
        ),
        textTheme: baseTextTheme
            .copyWith(
              headlineLarge: displayTextTheme.headlineLarge,
              headlineMedium: displayTextTheme.headlineMedium,
              headlineSmall: displayTextTheme.headlineSmall,
              titleLarge: displayTextTheme.titleLarge,
            )
            .apply(
              bodyColor: const Color(0xFF1B2220),
              displayColor: const Color(0xFF1B2220),
            ),
        cardTheme: CardThemeData(
          color: const Color(0xFFF8F4ED),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFD8D1C5)),
          ),
          margin: EdgeInsets.zero,
        ),
        dividerColor: const Color(0xFFD8D1C5),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFFFCF8),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD8D1C5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF162220), width: 1.4),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF162220),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1B2220),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            side: const BorderSide(color: Color(0xFFD8D1C5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFE8E1D1),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
      home: FutureBuilder<CompanionController>(
        future: _controllerFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _BootstrapError(error: snapshot.error.toString());
          }
          if (!snapshot.hasData) {
            return const _BootstrapSplash();
          }
          return CompanionHome(controller: snapshot.requireData);
        },
      ),
    );
  }
}

class _BootstrapSplash extends StatelessWidget {
  const _BootstrapSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Center(
        child: SizedBox(
          width: 42,
          height: 42,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }
}

class _BootstrapError extends StatelessWidget {
  const _BootstrapError({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'OpenClaw Companion could not start.',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(error, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
