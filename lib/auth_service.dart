import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Register a new user
  Future<User?> register(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      // ignore: avoid_print
      print('Registration error: $e');
      return null;
    }
  }

  // Login existing user
  Future<User?> login(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      // ignore: avoid_print
      print('Login error: $e');
      return null;
    }
  }

  // Logout user
  Future<void> logout() async {
    await _auth.signOut();
  }
}
