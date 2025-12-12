import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pineapple/loginpage.dart'; // Ensure this matches your login file

class FarmerProfilePage extends StatefulWidget {
  const FarmerProfilePage({super.key});

  @override
  State<FarmerProfilePage> createState() => _FarmerProfilePageState();
}

class _FarmerProfilePageState extends State<FarmerProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? currentUser;

  final List<String> melakaArea = [
    "Alor Gajah",
    "Ayer Keroh",
    "Ayer Molek",
    "Bandar Hilir",
    "Batu Berendam",
    "Bemban",
    "Bukit Baru",
    "Bukit Beruang",
    "Cheng",
    "Durian Tunggal",
    "Jasin",
    "Klebang",
    "Krubong",
    "Lubok China",
    "Masjid Tanah",
    "Melaka Raya",
    "Merlimau",
    "Nyalas",
    "Peringgit",
    "Pulau Gadong",
    "Selandar",
    "Serkam",
    "Simpang Ampat",
    "Sungai Udang",
    "Tanjung Bidara",
    "Tanjung Kling",
    "Telok Mas",
    "Ujong Pasir",
  ];

  @override
  void initState() {
    super.initState();
    currentUser = _auth.currentUser;
    print("ProfilePage Init: User is ${currentUser?.uid}"); // DEBUG
  }

  @override
  Widget build(BuildContext context) {
    // 1. Check if user is logged in immediately
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Profile")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("User not logged in"),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                },
                child: const Text("Go to Login"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          "My Profile",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () => _showLogoutDialog(context),
            tooltip: "Logout",
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore
            .collection('users')
            .doc(currentUser!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          // 2. Handle Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 3. Handle Errors
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          // 4. Handle Missing Data
          if (!snapshot.hasData || !snapshot.data!.exists) {
            print(
              "ProfilePage: Document does not exist for uid ${currentUser!.uid}",
            ); // DEBUG
            return const Center(
              child: Text("Profile document does not exist."),
            );
          }

          // 5. Data Retrieval
          var data = snapshot.data!.data() as Map<String, dynamic>;
          print("ProfilePage: Data received: $data"); // DEBUG

          String name = data['name'] ?? "No Name";
          String email = data['email'] ?? "No Email";
          String role = data['role'] ?? "User";
          String license = data['license_number'] ?? "N/A";
          String phone = data['phone'] ?? "Not Set";
          String location = data['location'] ?? "Not Set";
          String status = data['status'] ?? "Pending";

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // --- 1. NEW HEADER STYLE ---
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.green[100],
                        child: Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.green[800],
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // BADGES ROW (Role + Status)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Role Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[800],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              role.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Status Badge (Dynamic Color)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              // Green if approved, Orange if pending
                              color: status == 'approved'
                                  ? Colors.green
                                  : Colors.orange,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  status == 'approved'
                                      ? Icons.check_circle
                                      : Icons.access_time_filled,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  status.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // --- 2. DETAILS CARD ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildProfileRow(Icons.email_outlined, "Email", email),
                      const Divider(),
                      _buildProfileRow(Icons.phone_outlined, "Phone", phone),
                      const Divider(),
                      _buildProfileRow(
                        Icons.location_on_outlined,
                        "Location",
                        location,
                      ),
                      const Divider(),
                      _buildProfileRow(
                        Icons.badge_outlined,
                        "License ID",
                        license,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // --- 3. EDIT BUTTON ---
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _showEditDialog(context, name, phone, location),
                    icon: const Icon(Icons.edit, color: Colors.white),
                    label: const Text(
                      "EDIT DETAILS",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                TextButton(
                  onPressed: () => _sendPasswordReset(email),
                  child: const Text("", style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.green[700], size: 22),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await _auth.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- EDIT DIALOG ---
  void _showEditDialog(
    BuildContext parentContext,
    String currentName,
    String currentPhone,
    String currentLocation,
  ) {
    final nameController = TextEditingController(text: currentName);
    final phoneController = TextEditingController(
      text: currentPhone == "Not Set" ? "" : currentPhone,
    );

    // Safety check for location value
    String selectedLocation = melakaArea.contains(currentLocation)
        ? currentLocation
        : melakaArea[0];

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Edit Profile"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: "Full Name",
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: "Phone Number",
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: selectedLocation,
                      decoration: const InputDecoration(
                        labelText: "Location",
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      items: melakaArea.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => selectedLocation = val!);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await _firestore
                          .collection('users')
                          .doc(currentUser!.uid)
                          .update({
                            'name': nameController.text.trim(),
                            'phone': phoneController.text.trim(),
                            'location': selectedLocation,
                          });

                      if (mounted) {
                        Navigator.pop(dialogContext); // Close Dialog
                        // Show Success Toast
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          SnackBar(
                            content: const Text(
                              "Profile Updated Successfully!",
                            ),
                            backgroundColor: Colors.green[800],
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      print("Error updating profile: $e"); // DEBUG
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        SnackBar(content: Text("Failed to update: $e")),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                  ),
                  child: const Text(
                    "Save",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password reset email sent!")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
}
