import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_2/firebase_options.dart';

// Pantallas principales
import 'package:flutter_application_2/presentation/login/loginprincipal.dart';
import 'package:flutter_application_2/presentation/register/register.dart';
import 'package:flutter_application_2/presentation/menu/main_menu_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // ✅ Observa el estado del usuario en tiempo real
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Step Life',
          theme: ThemeData(
            primaryColor: const Color(0xFFFF6B00),
            scaffoldBackgroundColor: const Color(0xFFF4F4F4),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF303030),
              foregroundColor: Colors.white,
              centerTitle: true,
            ),
          ),
          // 🔹 Si Firebase todavía carga
          home: snapshot.connectionState == ConnectionState.waiting
              ? const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                )
              // 🔹 Si no hay usuario, ir al login
              : snapshot.hasData
                  ? const MainMenuScreen()
                  : const LoginScreen(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/inicio': (context) => const MainMenuScreen(),
          },
        );
      },
    );
  }
}
