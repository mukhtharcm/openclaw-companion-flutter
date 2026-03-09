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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OpenClaw Companion',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFEEF1ED),
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF16423C),
          onPrimary: Colors.white,
          secondary: Color(0xFF3B6B63),
          onSecondary: Colors.white,
          error: Color(0xFFB42318),
          onError: Colors.white,
          surface: Color(0xFFF9FBF8),
          onSurface: Color(0xFF102421),
        ),
        textTheme: baseTextTheme.apply(
          bodyColor: const Color(0xFF102421),
          displayColor: const Color(0xFF102421),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFFF9FBF8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFD9E3DD)),
          ),
          margin: EdgeInsets.zero,
        ),
        dividerColor: const Color(0xFFD9E3DD),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFFFFFF),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD9E3DD)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF16423C), width: 1.4),
          ),
        ),
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: Colors.transparent,
          indicatorColor: Color(0xFF16423C),
          selectedIconTheme: IconThemeData(color: Colors.white),
          selectedLabelTextStyle: TextStyle(
            color: Color(0xFF102421),
            fontWeight: FontWeight.w700,
          ),
          unselectedIconTheme: IconThemeData(color: Color(0xFF42615A)),
          unselectedLabelTextStyle: TextStyle(
            color: Color(0xFF42615A),
            fontWeight: FontWeight.w600,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF16423C),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF102421),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            side: const BorderSide(color: Color(0xFFD9E3DD)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFE7EEEA),
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
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFFF5F7F3), Color(0xFFE6ECE7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: SizedBox(
            width: 42,
            height: 42,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      ),
    );
  }
}

class _BootstrapError extends StatelessWidget {
  const _BootstrapError({
    required this.error,
  });

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
                  Text(
                    error,
                    style: Theme.of(context).textTheme.bodyMedium,
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
