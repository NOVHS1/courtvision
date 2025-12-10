import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  User? user = FirebaseAuth.instance.currentUser;
  String? photoUrl;
  String? displayName;
  String? bio;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      photoUrl = data["photoUrl"];
      displayName = data["displayName"] ?? "";
      bio = data["bio"] ?? "";
    }

    setState(() => loading = false);
  }

  // ------------------------------
  // PICK PROFILE PHOTO
  // ------------------------------
  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);

    if (file == null) return;

    final ref = FirebaseStorage.instance
        .ref("profile_photos")
        .child("${user!.uid}.jpg");

    await ref.putFile(File(file.path));
    final url = await ref.getDownloadURL();

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .update({"photoUrl": url});

    setState(() => photoUrl = url);
  }

  // ------------------------------
  // EDIT FIELD
  // ------------------------------
  void _editField(String title, String fieldName, String currentValue) {
    final controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF10131A),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection("users")
                  .doc(user!.uid)
                  .update({fieldName: controller.text});

              setState(() {
                if (fieldName == "displayName") displayName = controller.text;
                if (fieldName == "bio") bio = controller.text;
              });

              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // ------------------------------
  // LOGOUT
  // ------------------------------
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/home');
  }

  // ------------------------------
  // UI
  // ------------------------------
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF050816),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("My Account"),
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            // ------------------------------
            // PROFILE HEADER
            // ------------------------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1D9BF0), Color(0xFF0A4AA6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickProfilePhoto,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      backgroundImage:
                          photoUrl != null ? NetworkImage(photoUrl!) : null,
                      child: photoUrl == null
                          ? const Icon(Icons.person,
                              size: 50, color: Colors.black)
                          : null,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    displayName?.isNotEmpty == true
                        ? displayName!
                        : "Unnamed User",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),

                  Text(
                    user!.email!,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ------------------------------
            // SETTINGS LIST
            // ------------------------------
            _settingsTile(
              icon: Icons.person,
              title: "Display Name",
              value: displayName ?? "",
              onTap: () => _editField("Update Name", "displayName", displayName ?? ""),
            ),

            _settingsTile(
              icon: Icons.description,
              title: "Bio",
              value: bio ?? "",
              onTap: () => _editField("Edit Bio", "bio", bio ?? ""),
            ),

            _settingsTile(
              icon: Icons.star,
              title: "Favorites",
              value: "View your saved players",
              onTap: () {
                Navigator.pushNamed(context, "/favorites");
              },
            ),

            _settingsTile(
              icon: Icons.logout,
              title: "Logout",
              value: "Sign out of your account",
              onTap: _logout,
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 18)),
      subtitle:
          Text(value, style: const TextStyle(color: Colors.white60)),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white70),
      onTap: onTap,
    );
  }
}
