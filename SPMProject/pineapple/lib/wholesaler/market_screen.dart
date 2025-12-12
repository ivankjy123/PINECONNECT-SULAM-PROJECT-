import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  // 1. FILTER VARIABLES
  String selectedType = "All";
  String searchQuery = "";
  final List<String> filterOptions = ["All", "Pineapple", "Seeds"];

  // 2. USER VARIABLES
  String _currentUserName = "Unknown Buyer";
  String? _currentUserId; // <--- ADDED THIS to store your ID

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  // --- FETCH CURRENT USER DATA ---
  Future<void> _loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.uid; // <--- Store your ID here
      });

      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists && mounted) {
          setState(() {
            _currentUserName = doc.data()?['name'] ?? "Unknown Buyer";
          });
        }
      } catch (e) {
        debugPrint("Error loading user profile: $e");
      }
    }
  }

  // --- BUY DIALOG ---
  Future<void> _showBuyDialog(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final double qty = (num.tryParse(data['qty'].toString()) ?? 0).toDouble();
    final double totalPrice = (num.tryParse(data['price'].toString()) ?? 0)
        .toDouble();
    final String unit = data['unit'] ?? 'kg';

    final String displayFarmerName = data['farmerName'] ?? 'Unknown Farmer';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Buy ${data['name']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Seller: $displayFarmerName"),
            const SizedBox(height: 10),
            Text(
              "Confirm purchase of entire batch?",
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 10),
            Text(
              "$qty $unit  for  RM ${totalPrice.toStringAsFixed(2)}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(context);
              _processTransaction(doc, qty, totalPrice, data);
            },
            child: const Text(
              "Confirm Buy",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // --- TRANSACTION ---
  Future<void> _processTransaction(
    DocumentSnapshot productDoc,
    double qty,
    double totalCost,
    Map<String, dynamic> productData,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (productDoc.reference.parent.parent == null) return;
    final String farmerId = productDoc.reference.parent.parent!.id;

    String safeSellerName = productData['farmerName'] ?? "Unknown Farmer";

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot fresh = await transaction.get(productDoc.reference);
        if (!fresh.exists) throw Exception("Item sold!");

        // 1. SAVE TO INVENTORY
        transaction.set(
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('inventory')
              .doc(),
          {
            'productName': productData['name'],
            'qty': qty,
            'unit': productData['unit'],
            'totalCost': totalCost,
            'boughtAt': FieldValue.serverTimestamp(),
            'sellerId': farmerId,
            'sellerName': safeSellerName,
            'type': 'Stock In',
            'image': productData['image'],
            'status': 'In Stock',
          },
        );

        // 2. SAVE TO INVENTORY HISTORY
        transaction.set(
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('inventoryHistory')
              .doc(),
          {
            'action': 'Buy',
            'productName': productData['name'],
            'qty': qty,
            'unit': productData['unit'],
            'amount': -totalCost,
            'date': FieldValue.serverTimestamp(),
            'details': 'Bought from $safeSellerName',
          },
        );

        // 3. FARMER RECEIPT
        transaction.set(
          FirebaseFirestore.instance
              .collection('users')
              .doc(farmerId)
              .collection('sellHistory')
              .doc(),
          {
            'productName': productData['name'],
            'qty': qty,
            'unit': productData['unit'],
            'totalEarned': totalCost,
            'soldAt': FieldValue.serverTimestamp(),
            'buyerId': user.uid,
            'buyerName': _currentUserName,
            'status': 'Completed',
          },
        );

        // 4. DELETE LISTING
        transaction.delete(productDoc.reference);
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Purchase Success!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER & SEARCH ---
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Wholesale Market",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    onChanged: (val) => setState(() => searchQuery = val),
                    decoration: InputDecoration(
                      hintText: "Search farmer or crop...",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ],
              ),
            ),

            // --- FILTER CHIPS ---
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.white,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filterOptions.length,
                itemBuilder: (context, index) {
                  final category = filterOptions[index];
                  final isSelected = category == selectedType;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        setState(() => selectedType = category);
                      },
                      selectedColor: Colors.green,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                    ),
                  );
                },
              ),
            ),

            // --- MARKET LIST ---
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collectionGroup('sellListings')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No Listings Found."));
                  }

                  var docs = snapshot.data!.docs;

                  // --- UPDATED FILTERING LOGIC ---
                  var filteredDocs = docs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;

                    // 1. Hide OWN listings (The Fix)
                    // We check if the parent ID (the farmer's ID) matches your ID
                    String ownerId = doc.reference.parent.parent?.id ?? '';
                    if (_currentUserId != null && ownerId == _currentUserId) {
                      return false; // Skip this item
                    }

                    // 2. Type Filter
                    bool typeMatch =
                        selectedType == "All" ||
                        (data['type'] ?? '') == selectedType;

                    // 3. Search Filter
                    String title = (data['name'] ?? '')
                        .toString()
                        .toLowerCase();
                    bool searchMatch =
                        searchQuery.isEmpty ||
                        title.contains(searchQuery.toLowerCase());

                    return typeMatch && searchMatch;
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return const Center(
                      child: Text("No items match your search."),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      var doc = filteredDocs[index];
                      var data = doc.data() as Map<String, dynamic>;

                      return _buildMarketCard(doc, data);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- CUSTOM CARD WIDGET ---
  Widget _buildMarketCard(DocumentSnapshot doc, Map<String, dynamic> data) {
    String name = data['name'] ?? "No Name";
    String farmer = data['farmerName'] ?? "Unknown Farmer";
    String location = data['location'] ?? "Malaysia";
    String price =
        "RM ${num.tryParse(data['price'].toString())?.toStringAsFixed(2) ?? '0.00'}";
    String qty = "${data['qty']}";
    String unit = "${data['unit'] ?? 'kg'}";
    String image = data['image'] ?? "assets/pineapple.png";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Column(
        children: [
          // 1. Image & Overlay
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Container(
                  height: 140,
                  width: double.infinity,
                  color: Colors.grey[200],
                  child: Image.asset(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const Icon(Icons.image),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        location,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 2. Info Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        farmer,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      // Big Quantity
                      Text(
                        "$qty $unit",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Price & Buy Button
                Column(
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _showBuyDialog(doc),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Buy Now",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
