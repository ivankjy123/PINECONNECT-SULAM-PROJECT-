import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_listing_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  // --- 1. CANCEL LISTING LOGIC ---
  Future<void> _cancelListing(
    String listingId,
    String productName,
    int qtyToAdd,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // A. Delete Listing (UPDATED COLLECTION NAME)
        final listingRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('sellListings') // <--- CHANGED FROM 'listings'
            .doc(listingId);
        transaction.delete(listingRef);

        // B. Return Stock to Inventory
        final inventoryQuery = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('inventory')
            .where('productName', isEqualTo: productName)
            .limit(1)
            .get();

        if (inventoryQuery.docs.isNotEmpty) {
          final inventoryRef = inventoryQuery.docs.first.reference;
          int currentStock =
              (inventoryQuery.docs.first.data()['qty'] as num? ?? 0).toInt();
          transaction.update(inventoryRef, {'qty': currentStock + qtyToAdd});
        } else {
          // Recreate if missing
          final newInvRef = FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('inventory')
              .doc();
          transaction.set(newInvRef, {
            'productName': productName,
            'qty': qtyToAdd,
            'unit': 'kg', // You might want to pass the unit in properly later
            'status': 'Returned',
            'boughtAt': FieldValue.serverTimestamp(),
          });
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Listing cancelled. Stock returned.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // --- 2. EDIT LISTING DIALOG ---
  void _showEditDialog(
    String listingId,
    double currentPrice,
    String currentTitle,
  ) {
    TextEditingController priceCtrl = TextEditingController(
      text: currentPrice.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit $currentTitle"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Update Price per Unit:"),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(prefixText: "RM "),
            ),
            const SizedBox(height: 10),
            const Text(
              "To change quantity, please Cancel and create a new listing.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              double newPrice = double.tryParse(priceCtrl.text) ?? currentPrice;

              // UPDATED COLLECTION NAME HERE TOO
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser!.uid)
                  .collection('sellListings') // <--- CHANGED FROM 'listings'
                  .doc(listingId)
                  .update({'price': newPrice});
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text(
            "Inventory Manager",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          bottom: const TabBar(
            labelColor: Colors.green,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.green,
            indicatorWeight: 3,
            tabs: [
              Tab(text: "Warehouse (Stock)"),
              Tab(text: "On Sale (Listings)"),
            ],
          ),
        ),
        body: TabBarView(children: [_buildWarehouseTab(), _buildListingsTab()]),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.green[700],
          child: const Icon(Icons.add, color: Colors.white),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateListingScreen(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWarehouseTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text("Please Login"));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('inventory')
          .orderBy('boughtAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty)
          return const Center(child: Text("Warehouse Empty"));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var data =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            String name = data['productName'] ?? 'Item';
            String qty = (data['qty'] as num? ?? 0).toInt().toString();
            String unit = data['unit'] ?? 'kg';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Image.asset(
                  data['image'] ?? 'assets/pineapple.png',
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => const Icon(Icons.image),
                ),
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("In Stock: $qty $unit"),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildListingsTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('sellListings') // <--- CHANGED FROM 'listings'
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty)
          return const Center(child: Text("No Active Listings"));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;

            // Adjust fields to match your 'CreateListingScreen'
            String title = data['title'] ?? data['name'] ?? 'Listing';
            double price = (data['price'] as num? ?? 0).toDouble();
            int qty = (data['qty'] as num? ?? 0).toInt();
            String unit = data['unit'] ?? 'kg';

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Image.asset(
                        data['image'] ?? 'assets/pineapple.png',
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Icon(Icons.image),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              "Price: RM ${price.toStringAsFixed(2)} / $unit",
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Selling: $qty $unit",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // EDIT BUTTON
                      TextButton.icon(
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text("Edit Price"),
                        onPressed: () => _showEditDialog(doc.id, price, title),
                      ),
                      // CANCEL BUTTON
                      TextButton.icon(
                        icon: const Icon(
                          Icons.delete,
                          size: 16,
                          color: Colors.red,
                        ),
                        label: const Text(
                          "Cancel Listing",
                          style: TextStyle(color: Colors.red),
                        ),
                        onPressed: () => _cancelListing(doc.id, title, qty),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
