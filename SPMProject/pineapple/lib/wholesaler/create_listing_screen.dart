import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({super.key});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();

  List<Map<String, dynamic>> _inventoryItems = [];
  String? _selectedInventoryId;
  Map<String, dynamic>? _selectedItem;
  bool _isLoading = true;

  // Profile Data
  String _wholesalerName = "Unknown Seller";
  String _wholesalerLocation = "Malaysia";

  // Helper to check if item is seed
  bool get _isSeedSelected {
    if (_selectedItem == null) return false;
    String name =
        (_selectedItem!['productName'] ?? _selectedItem!['product'] ?? '')
            .toString();
    return name.toLowerCase().contains('seed');
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Get Profile
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        _wholesalerName = data['name'] ?? "Unknown Seller";
        _wholesalerLocation = data['location'] ?? "Malaysia";
      }

      // 2. Get Inventory
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('inventory')
          .where('qty', isGreaterThan: 0)
          .get();

      setState(() {
        _inventoryItems = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _publishListing() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItem == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final double price = double.parse(_priceController.text);
    final int qtyToList = int.parse(_qtyController.text);
    final int currentStock = (_selectedItem!['qty'] as num? ?? 0).toInt();

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // 1. Deduct from Inventory
        final inventoryRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('inventory')
            .doc(_selectedInventoryId);

        transaction.update(inventoryRef, {
          'qty': currentStock - qtyToList,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 2. Create Listing
        final newListingRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection(
              'sellListings',
            ) // Ensure this matches your collection name
            .doc();

        // Determine Unit based on Type
        String finalUnit = _isSeedSelected ? 'bags' : 'kg';

        transaction.set(newListingRef, {
          'title': _selectedItem!['productName'] ?? _selectedItem!['product'],
          'name':
              _selectedItem!['productName'] ??
              _selectedItem!['product'], // Added 'name' for consistency
          'price': price,
          'qty': qtyToList,
          'unit': finalUnit, // Saves 'bags' or 'kg'
          'image': _selectedItem!['image'],
          'status': 'Active',
          'wholesalerId': user.uid,
          'farmerId': user.uid, // Ensuring compatibility
          'createdAt': FieldValue.serverTimestamp(),
          'type': _isSeedSelected ? 'Seeds' : 'Pineapple',
          'farmerName': _wholesalerName, // Saves User Name
          'location': _wholesalerLocation, // Saves User Location
        });
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("New Listing"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Select Item from Warehouse",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedInventoryId,
                      decoration: _inputDecoration("Select Product"),
                      items: _inventoryItems.map((item) {
                        String name =
                            item['productName'] ?? item['product'] ?? 'Unknown';
                        int stock = (item['qty'] as num? ?? 0).toInt();

                        // Show 'bags' if seed, else 'kg' (visual only)
                        bool isSeed = name.toLowerCase().contains('seed');
                        String displayUnit = isSeed
                            ? 'bags'
                            : (item['unit'] ?? 'kg');

                        return DropdownMenuItem(
                          value: item['id'] as String,
                          child: Text("$name ($stock $displayUnit available)"),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedInventoryId = val;
                          _selectedItem = _inventoryItems.firstWhere(
                            (i) => i['id'] == val,
                          );
                        });
                      },
                      validator: (val) => val == null ? "Required" : null,
                    ),
                    const SizedBox(height: 25),

                    // --- DYNAMIC FIELDS ROW ---
                    Row(
                      children: [
                        // QUANTITY FIELD
                        Expanded(
                          child: TextFormField(
                            controller: _qtyController,
                            keyboardType: TextInputType.number,
                            // Dynamic Label: Bags vs Kg
                            decoration: _inputDecoration(
                              _isSeedSelected
                                  ? "Quantity (Bags)"
                                  : "Weight (Kg)",
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return "Required";
                              if (_selectedItem != null) {
                                int available =
                                    (_selectedItem!['qty'] as num? ?? 0)
                                        .toInt();
                                if (int.parse(val) > available)
                                  return "Max $available";
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 15),

                        // PRICE FIELD
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            // Dynamic Label: Per Bag vs Per Kg
                            decoration: _inputDecoration(
                              _isSeedSelected
                                  ? "Price per Bag (RM)"
                                  : "Price per Kg (RM)",
                            ),
                            validator: (val) =>
                                val!.isEmpty ? "Required" : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _inventoryItems.isEmpty
                            ? null
                            : _publishListing,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "PUBLISH LISTING",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }
}
