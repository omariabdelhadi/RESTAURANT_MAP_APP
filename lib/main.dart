import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/map_screen.dart';
import 'screens/splash_screen.dart';
import 'services/session_manager.dart';
import 'screens/register_screen.dart';

void main() {
  runApp(const RestaurantMapApp());
}

class RestaurantMapApp extends StatelessWidget {
  const RestaurantMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SessionManager>(
      future: SessionManager.create(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text('Erreur: ${snapshot.error}'),
              ),
            ),
          );
        }

        final sessionManager = snapshot.data!;

        return ChangeNotifierProvider.value(
          value: sessionManager,
          child: MaterialApp(
            title: 'Restaurant Map',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              useMaterial3: true,
            ),
            home: const SplashScreen(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/map': (context) => const MapScreen(),
            },
          ),
        );
      },
    );
  }
}
