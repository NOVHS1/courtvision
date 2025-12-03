import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:courtvision/home_page.dart';
import 'auth_page.dart';
import 'player_compare_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "8myBedKoqaXIIPl1Mp2kXOSSALwqtGKEGBCic43k",
      authDomain: "courtvision-c400e.firebaseapp.com",
      projectId: "courtvision-c400e",
      storageBucket: "courtvision-c400e.appspot.com",
      messagingSenderId: "968476071875",
      appId: "1:968476071875:web:6bec8817d1e0dd74de0f76",
      measurementId: "G-GGK1HVZGCG",
    ),
  );

  runApp(const CourtVisionApp());
}

class CourtVisionApp extends StatelessWidget {
  const CourtVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CourtVision',
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF050816),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(), // removed const to avoid stale type issue
      routes: {
        '/auth': (context) => AuthPage(),
        '/home': (context) => HomePage(),
        '/compare': (context) => const PlayerComparePage(),
      },
    );
  }
}
