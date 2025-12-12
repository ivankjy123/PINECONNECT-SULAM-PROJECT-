import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_model.dart';
import 'cart_screen.dart';

class BuyerShopScreen extends StatefulWidget {
  const BuyerShopScreen({super.key});

  @override
  State<BuyerShopScreen> createState() => _BuyerShopScreenState();
}

class _BuyerShopScreenState extends State<BuyerShopScreen> {
  String selectedType = "All";
  final List<String> filterOptions = ["All", "Pineapple", "Seeds"];

  // --- ADD TO CART DIALOG ---
  void _showAddToCartDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // 1. Handle Names (Wholesaler uses 'title', Farmer uses 'name')
    String title = data['title'] ?? data['name'] ?? 'Product';
    String seller = data['sellerName'] ?? data['farmerName'] ?? 'Unknown';

    final double maxQty = (num.tryParse(data['qty'].toString()) ?? 0)
        .toDouble();
    final double pricePerKg = (num.tryParse(data['price'].toString()) ?? 0)
        .toDouble();
    final String unit = data['unit'] ?? 'kg';

    final TextEditingController qtyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Add $title to Cart"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Sold by: $seller"),
            const SizedBox(height: 10),
            Text(
              "Available: $maxQty $unit",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: qtyController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: "Quantity ($unit)",
                border: const OutlineInputBorder(),
                helperText:
                    "Price: RM ${pricePerKg.toStringAsFixed(2)} / $unit",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              double buyQty = double.tryParse(qtyController.text) ?? 0;

              if (buyQty <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Enter a valid amount")),
                );
                return;
              }
              if (buyQty > maxQty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Not enough stock!")),
                );
                return;
              }

              // --- ADD TO LOCAL CART ---
              addToCart({
                'docId': doc.id,
                'wholesalerId': doc.reference.parent.parent!.id,
                'title': title,
                'sellerName': seller,
                'buyQty': buyQty,
                'pricePerKg': pricePerKg,
                'unit': unit,
                'image': data['image'],
                'listingRef': doc.reference,
              });

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Added $buyQty $unit to Cart!"),
                  duration: const Duration(seconds: 2),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text(
              "Add to Cart",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Marketplace"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.grey),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            color: Colors.white,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: filterOptions.map((filter) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: selectedType == filter,
                    selectedColor: const Color(0xFF2E7D32),
                    labelStyle: TextStyle(
                      color: selectedType == filter
                          ? Colors.white
                          : Colors.black,
                    ),
                    onSelected: (val) => setState(() => selectedType = filter),
                  ),
                );
              }).toList(),
            ),
          ),
          // List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // We read from 'sellListings' because that is where we saved everything
              stream: FirebaseFirestore.instance
                  .collectionGroup('sellListings')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data!.docs;

                var filtered = docs.where((d) {
                  var data = d.data() as Map<String, dynamic>;

                  // --- FIX: FILTER TO SHOW ONLY WHOLESALERS ---
                  // Only Wholesaler listings have 'wholesalerId'.
                  // Farmer listings usually only have 'farmerId'.
                  if (data['wholesalerId'] == null) {
                    return false; // Skip Farmer items
                  }
                  // -------------------------------------------

                  bool typeMatch =
                      selectedType == "All" ||
                      (data['type'] ?? '') == selectedType;

                  double qty = (num.tryParse(data['qty'].toString()) ?? 0)
                      .toDouble();

                  return typeMatch && qty > 0;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text("No Wholesaler items available"),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    var doc = filtered[index];
                    var data = doc.data() as Map<String, dynamic>;

                    return _buildBigMarketCard(doc, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- BIGGER CARD DESIGN ---
  Widget _buildBigMarketCard(DocumentSnapshot doc, Map<String, dynamic> data) {
    // Priority: 'title' (Wholesaler) -> 'name' (Farmer fallback)
    String title = data['title'] ?? data['name'] ?? "Product";
    // Priority: 'sellerName' (Wholesaler) -> 'farmerName' (Farmer fallback)
    String seller =
        data['sellerName'] ?? data['farmerName'] ?? "Unknown Seller";

    String location = data['location'] ?? "Malaysia";
    String price =
        "RM ${num.tryParse(data['price'].toString())?.toStringAsFixed(2) ?? '0.00'}";
    String qty = data['qty'].toString();
    String unit = data['unit'] ?? 'kg';
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
                  height: 160,
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
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Sold by: $seller",
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "$qty $unit left",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Price & Add Button
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
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => _showAddToCartDialog(doc),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add_shopping_cart, size: 18),
                          SizedBox(width: 5),
                          Text(
                            "Add",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
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
