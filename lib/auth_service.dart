import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserCredential> register(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthException(code: e.code, message: e.message);
    }
  }

  Future<UserCredential> login(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthException(code: e.code, message: e.message);
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
  /// CURRENT USER
  User? get currentUser => _auth.currentUser;

  /// PASSWORD RESET
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  /// ERROR HANDLER
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case "invalid-email":
        return "The email address is not valid.";
      case "user-not-found":
        return "No user found with this email.";
      case "wrong-password":
        return "Wrong password.";
      case "email-already-in-use":
        return "This email is already registered.";
      case "weak-password":
        return "Password is too weak.";
      case "too-many-requests":
        return "Too many attempts. Try again later.";
      case "network-request-failed":
        return "Network error. Check your connection.";
      default:
        return "Authentication error: ${e.message}";
    }
  }
}
