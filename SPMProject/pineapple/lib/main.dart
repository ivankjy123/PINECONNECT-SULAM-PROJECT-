import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'onboardingscreen1.dart';
import 'loginpage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // <-- Initialize Firebase

  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('*********Firebase initialized successfully************');
  } catch (e) {
    print('*********Error initializing Firebase: $e ************');
  }

  final prefs = await SharedPreferences.getInstance();
  final bool? seenOnboarding = prefs.getBool('onboardingscreen1');

  runApp(MyApp(seenOnboarding: seenOnboarding ?? false));
}

class MyApp extends StatelessWidget {
  final bool seenOnboarding;

  const MyApp({super.key, required this.seenOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Green Themed Login App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green.shade700),
        useMaterial3: true,
        //fontFamily: 'RobotoMono'
      ),
      // ✅ Only show onboarding once after install
      home: seenOnboarding ? const LoginPage() : const OnboardingScreen1(),
    );
  }
}
