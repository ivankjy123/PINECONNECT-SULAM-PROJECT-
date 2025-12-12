import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ShopManager extends StatefulWidget {
  const ShopManager({super.key});

  @override
  State<ShopManager> createState() => _ShopManagerState();
}

class _ShopManagerState extends State<ShopManager> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- HELPER: Get Image Path ---
  String _getImagePath(String productName) {
    String name = productName.toLowerCase();
    if (name.contains('seed')) {
      return 'assets/seeds.png';
    } else {
      return 'assets/pineapple.png';
    }
  }

  // --- LOGIC: UNPUBLISH ITEM (Unchanged) ---
  Future<void> _unpublishItem({
    required String docId,
    required String name,
    required int qty,
    required String unit,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sellListings')
          .doc(docId)
          .delete();

      final inventoryQuery = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('inventory')
          .where('product', isEqualTo: name)
          .limit(1)
          .get();

      if (inventoryQuery.docs.isNotEmpty) {
        final invDoc = inventoryQuery.docs.first;
        int currentStock = invDoc['stock'] ?? 0;
        await invDoc.reference.update({'stock': currentStock + qty});
      } else {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('inventory')
            .add({
              'product': name,
              'stock': qty,
              'unit': unit,
              'status': 'In Stock',
              'image': _getImagePath(name),
              'createdAt': FieldValue.serverTimestamp(),
            });
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('inventoryHistory')
          .add({
            'itemName': name,
            'action': "Unpublished (Returned)",
            'change': qty,
            'finalStock': -1,
            'unit': unit,
            'timestamp': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Item unpublished and stock restored.")),
        );
      }
    } catch (e) {
      debugPrint("Error unpublishing: $e");
    }
  }

  void _confirmUnpublish(String docId, String name, int qty, String unit) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Unpublish Listing"),
        content: Text(
          "Are you sure you want to remove '$name' from the shop?\nStock ($qty $unit) will be returned to your inventory.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _unpublishItem(docId: docId, name: name, qty: qty, unit: unit);
            },
            child: const Text(
              "Unpublish",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // --- AUTO-FIX FUNCTION ---
  // This will add 'farmerName' and 'location' to listings that are missing them
  void _fixListingData(DocumentSnapshot doc, String myName, String myLocation) {
    final data = doc.data() as Map<String, dynamic>;

    bool missingName = data['farmerName'] == null;
    bool missingLoc = data['location'] == null;

    if ((missingName || missingLoc) && myName != "Loading...") {
      doc.reference.update({'farmerName': myName, 'location': myLocation});
      print(
        "Fixed listing: ${doc.id} -> Added Name: $myName, Loc: $myLocation",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please login to view listings")),
      );
    }

    // 1. Fetch USER PROFILE first (to get the correct name/location)
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnapshot) {
        String myName = "Loading...";
        String myLocation = "Malaysia";

        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          myName = userData['name'] ?? "Farmer";
          myLocation = userData['location'] ?? "Malaysia";
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: AppBar(
            title: const Text(
              "My Shop Listings",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Show the user info in AppBar so you know it's loaded
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(20),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  "Posting as: $myName • $myLocation",
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0.5,
            iconTheme: const IconThemeData(color: Colors.black),
            centerTitle: true,
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .doc(user.uid)
                .collection('sellListings')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No Active Listings"));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;

                  // --- 2. RUN THE FIX ---
                  // This checks if data is missing and updates Firebase immediately
                  _fixListingData(doc, myName, myLocation);

                  // Display Data
                  String name = data['name'] ?? 'Unknown';
                  String price = data['price'].toString();
                  int qty = data['qty'] ?? 0;
                  String unit = data['unit'] ?? 'kg';
                  String type = data['type'] ?? 'Pineapple';
                  String imagePath = data['image'] ?? _getImagePath(name);

                  // Use the data from DB, or fallback to Profile data if update is slow
                  String location = data['location'] ?? myLocation;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: AssetImage(imagePath),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "$qty $unit • RM $price",
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _buildTag(type, Colors.blue),
                                  const SizedBox(width: 5),
                                  _buildTag(location, Colors.orange),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            IconButton(
                              onPressed: () =>
                                  _confirmUnpublish(doc.id, name, qty, unit),
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.red,
                              ),
                            ),
                            const Text(
                              "Unpublish",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
