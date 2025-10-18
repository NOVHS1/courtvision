import 'package:courtvision/home_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBlOn0XYusuwToUQGsgP5MWZd4TfZ1QUB4",
      authDomain: "courtvision-c400e.firebaseapp.com",
      projectId: "courtvision-c400e",
      storageBucket: "courtvision-c400e.firebasestorage.app",
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.grey,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomePage(),
      routes: {
        '/auth': (context) => const AuthPage(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}
