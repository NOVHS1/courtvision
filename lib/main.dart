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

  runApp(CourtVisionApp());
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.grey,
          brightness: Brightness.dark,
        ),
      ),
      home: HomePage(), // removed const to avoid stale type issue
      routes: {
        '/auth': (context) => AuthPage(), // removed const as well
        '/home': (context) => HomePage(),
        '/compare': (context) => const PlayerComparePage(),
      },
    );
  }
}
