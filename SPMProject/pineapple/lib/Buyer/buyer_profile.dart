import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pineapple/loginpage.dart'; // <--- Ensure this matches your project structure

class BuyerProfilePage extends StatefulWidget {
  const BuyerProfilePage({super.key});

  @override
  State<BuyerProfilePage> createState() => _BuyerProfilePageState();
}

class _BuyerProfilePageState extends State<BuyerProfilePage> {
  // Firebase Instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? currentUser;

  // Location Data
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
  }

  @override
  Widget build(BuildContext context) {
    // Safety check: If not logged in, show simple text
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("Not Logged In")));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Light Grey Background
      appBar: AppBar(
        title: const Text(
          "My Profile",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // --- LOGOUT BUTTON ---
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: "Logout",
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      // --- STREAM BUILDER (Prevents Loading Freeze) ---
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore
            .collection('users')
            .doc(currentUser!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          // 1. Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Error or Empty State
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("No profile data found."));
          }

          // 3. Extract Data safely
          var data = snapshot.data!.data() as Map<String, dynamic>;

          String name = data['name'] ?? "No Name";
          String email = data['email'] ?? currentUser!.email ?? "No Email";
          String phone = data['phone'] ?? "Not Set";
          String location = data['location'] ?? "Not Set";
          // Use 'Buyer' as default role for this page
          String role = data['role'] ?? "Buyer";

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // --- PROFILE HEADER ---
                Center(
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 50,
                        backgroundColor: Color(0xFFE8F5E9), // Light Green
                        child: Icon(
                          Icons.person,
                          size: 50,
                          color: Color(0xFF2E7D32), // Dark Green
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
                      // Role Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
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
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // --- DETAILS CARD ---
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
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // --- EDIT BUTTON ---
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
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- WIDGET HELPER: Display Row ---
  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2E7D32), size: 22),
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

  // --- FUNCTION: Logout (Anti-Freeze Version) ---
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              // 1. Close the dialog FIRST
              Navigator.pop(dialogContext);

              // 2. Hide keyboard to prevent UI freezing
              FocusScope.of(context).unfocus();

              // 3. Perform Sign Out
              await _auth.signOut();

              // 4. Manually Navigate to Login
              // (If your main.dart handles this automatically, you can remove this block)
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
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

  // --- FUNCTION: Edit Dialog ---
  void _showEditDialog(
    BuildContext context,
    String currentName,
    String currentPhone,
    String currentLocation,
  ) {
    final nameController = TextEditingController(text: currentName);
    final phoneController = TextEditingController(
      text: currentPhone == "Not Set" ? "" : currentPhone,
    );

    // Validate Location Selection
    String selectedLocation = melakaArea.contains(currentLocation)
        ? currentLocation
        : melakaArea[0];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Edit Profile"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name Field
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: "Full Name",
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Phone Field
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: "Phone Number",
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Location Dropdown
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                  ),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Profile Updated Successfully!"),
                            backgroundColor: Color(0xFF2E7D32),
                          ),
                        );
                      }
                    } catch (e) {
                      debugPrint("Error updating profile: $e");
                    }
                  },
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
}
