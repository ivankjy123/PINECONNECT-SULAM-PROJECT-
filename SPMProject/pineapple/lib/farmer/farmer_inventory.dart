import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import this for Date Formatting

// --- CARD WIDGET ---
class InventoryCard extends StatelessWidget {
  final String name;
  final String stock;
  final String unit;
  final String status;
  final String imagePath;
  final VoidCallback onEdit;
  final VoidCallback onSell;
  final VoidCallback onDelete;

  const InventoryCard({
    super.key,
    required this.name,
    required this.stock,
    required this.unit,
    required this.status,
    required this.imagePath,
    required this.onEdit,
    required this.onSell,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- IMAGE DISPLAY ---
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: AssetImage(imagePath),
                      fit: BoxFit.cover,
                      onError: (exception, stackTrace) {},
                    ),
                  ),
                  child: imagePath.isEmpty
                      ? const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Stock: $stock $unit",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey[200]),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.edit,
                    label: "Edit",
                    color: Colors.blue,
                    onTap: onEdit,
                  ),
                ),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.storefront,
                    label: "Sell",
                    color: Colors.orange,
                    onTap: onSell,
                  ),
                ),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.delete,
                    label: "Delete",
                    color: Colors.red,
                    onTap: onDelete,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- INVENTORY PAGE ---
class FarmerInventoryPage extends StatefulWidget {
  const FarmerInventoryPage({super.key});

  @override
  State<FarmerInventoryPage> createState() => _FarmerInventoryPageState();
}

class _FarmerInventoryPageState extends State<FarmerInventoryPage> {
  List<Map<String, dynamic>> inventoryItems = [];
  final List<String> unitOptions = ['kg', 'gram', 'poly'];
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (_auth.currentUser != null) {
        await _loadInventory();
      }
    });
  }

  // --- 1. SHOW HISTORY DIALOG ---
  void _showHistoryDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Inventory History",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(_auth.currentUser!.uid)
                    .collection('inventoryHistory')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text("No history recorded yet."),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final data =
                          snapshot.data!.docs[index].data()
                              as Map<String, dynamic>;

                      String itemName = data['itemName'] ?? "Unknown";
                      String action = data['action'] ?? "Update";
                      int change = data['change'] ?? 0;
                      String unit = data['unit'] ?? "";

                      Timestamp? ts = data['timestamp'];
                      String dateStr = ts != null
                          ? DateFormat(
                              'dd MMM yyyy, hh:mm a',
                            ).format(ts.toDate())
                          : "-";

                      bool isPositive = change > 0;
                      Color color = isPositive ? Colors.green : Colors.red;
                      String sign = isPositive ? "+" : "";

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.1),
                          child: Icon(
                            isPositive ? Icons.add : Icons.remove,
                            color: color,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          itemName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text("$action • $dateStr"),
                        trailing: Text(
                          "$sign$change $unit",
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      );
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

  // --- LOG TRANSACTION HELPER ---
  Future<void> _logTransaction({
    required String itemName,
    required String action,
    required int quantityChange,
    required int finalStock,
    required String unit,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('inventoryHistory')
        .add({
          'itemName': itemName,
          'action': action,
          'change': quantityChange,
          'finalStock': finalStock,
          'unit': unit,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  // --- LOAD INVENTORY ---
  Future<void> _loadInventory() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('inventory')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        inventoryItems = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            "id": doc.id,
            "name": data['product'] ?? '',
            "stock": data['stock'] ?? 0,
            "unit": data['unit'] ?? 'kg',
            "status": data['status'] ?? 'In Stock',
            "image": data['image'] ?? 'assets/pineapple.png',
          };
        }).toList();
      });
    } catch (e) {
      debugPrint("Error loading inventory: $e");
    }
  }

  // --- ADD NEW ITEM ---
  void _addNewItem() {
    TextEditingController stockController = TextEditingController();
    String selectedCategory = "Pineapple";
    String selectedProduct = "Pineapple MD2";
    final List<String> pineappleVarieties = [
      "Pineapple MD2",
      "Josapine",
      "Moris",
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Add Inventory"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text("Pineapple"),
                        selected: selectedCategory == "Pineapple",
                        selectedColor: Colors.green[100],
                        onSelected: (bool selected) {
                          if (selected) {
                            setDialogState(() {
                              selectedCategory = "Pineapple";
                              selectedProduct = "Pineapple MD2";
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text("Seeds"),
                        selected: selectedCategory == "Seeds",
                        selectedColor: Colors.green[100],
                        onSelected: (bool selected) {
                          if (selected) {
                            setDialogState(() {
                              selectedCategory = "Seeds";
                              selectedProduct = "Pineapple Seeds";
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (selectedCategory == "Pineapple")
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Variety",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedProduct,
                          isExpanded: true,
                          items: pineappleVarieties.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setDialogState(() {
                              selectedProduct = newValue!;
                            });
                          },
                        ),
                      ),
                    )
                  else
                    TextField(
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: "Product Name",
                        border: OutlineInputBorder(),
                      ),
                      controller: TextEditingController(
                        text: "Pineapple Seeds",
                      ),
                    ),

                  const SizedBox(height: 20),

                  TextField(
                    controller: stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Initial Stock",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    selectedCategory == "Pineapple" ? "Unit: kg" : "Unit: poly",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  onPressed: () async {
                    if (stockController.text.isEmpty) return;

                    int stock = int.tryParse(stockController.text) ?? 0;
                    String finalImage = selectedCategory == "Seeds"
                        ? "assets/seeds.png"
                        : "assets/pineapple.png";
                    String finalUnit = selectedCategory == "Seeds"
                        ? "poly"
                        : "kg";

                    await _saveToDatabase(
                      product: selectedProduct,
                      stock: stock,
                      unit: finalUnit,
                      imagePath: finalImage,
                    );

                    // LOG HISTORY
                    await _logTransaction(
                      itemName: selectedProduct,
                      action: "New Item Added",
                      quantityChange: stock,
                      finalStock: stock,
                      unit: finalUnit,
                    );

                    await _loadInventory();
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "Add",
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

  // --- EDIT ITEM ---
  void _editItem(int index) {
    final item = inventoryItems[index];
    int currentStock = item['stock'];
    TextEditingController stockController = TextEditingController(
      text: currentStock.toString(),
    );
    String selectedUnit = item['unit'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Edit Item"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Item Name: ${item['name']}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Stock",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: "Unit",
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedUnit,
                        items: unitOptions.map((unit) {
                          return DropdownMenuItem(
                            value: unit,
                            child: Text(unit),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setDialogState(() {
                            selectedUnit = newValue!;
                          });
                        },
                      ),
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
                  onPressed: () async {
                    final uid = _auth.currentUser!.uid;
                    int newStock =
                        int.tryParse(stockController.text) ?? currentStock;
                    int difference = newStock - currentStock;

                    await FirebaseFirestore.instance
                        .collection("users")
                        .doc(uid)
                        .collection("inventory")
                        .doc(item['id'])
                        .update({
                          "stock": newStock,
                          "unit": selectedUnit,
                          "updatedAt": FieldValue.serverTimestamp(),
                        });

                    // LOG HISTORY
                    if (difference != 0) {
                      await _logTransaction(
                        itemName: item['name'],
                        action: difference > 0
                            ? "Stock Added (Edit)"
                            : "Stock Removed (Edit)",
                        quantityChange: difference,
                        finalStock: newStock,
                        unit: selectedUnit,
                      );
                    }

                    await _loadInventory();
                    Navigator.pop(context);
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- SELL ITEM (UPDATED WITH VALIDATION) ---
  void _sellItem(int index) {
    final item = inventoryItems[index];
    TextEditingController sellAmountController = TextEditingController();
    TextEditingController priceController = TextEditingController();
    final uid = _auth.currentUser!.uid;
    int currentStock = item['stock'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Sell ${item['name']}"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Stock Available: $currentStock ${item['unit']}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: sellAmountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Amount",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Price (Total RM)",
                      border: OutlineInputBorder(),
                      prefixText: "RM ",
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  onPressed: () async {
                    // --- UPDATED VALIDATION LOGIC START ---

                    // 1. Check for Empty Fields
                    if (sellAmountController.text.isEmpty ||
                        priceController.text.isEmpty) {
                      _showErrorDialog("Please fill in both Amount and Price.");
                      return;
                    }

                    int sellAmount =
                        int.tryParse(sellAmountController.text) ?? 0;
                    double price = double.tryParse(priceController.text) ?? 0.0;

                    // 2. Check for Zero or Negative Numbers (Minimum 1)
                    if (sellAmount < 1) {
                      _showErrorDialog(
                        "Amount cannot be 0 or less. Minimum is 1.",
                      );
                      return;
                    }

                    if (price < 1) {
                      _showErrorDialog(
                        "Price cannot be 0 or less. Minimum is RM 1.",
                      );
                      return;
                    }

                    // 3. Check for Insufficient Stock
                    if (sellAmount > currentStock) {
                      _showErrorDialog(
                        "Insufficient Stock! You only have $currentStock available.",
                      );
                      return;
                    }

                    // --- UPDATED VALIDATION LOGIC END ---

                    int finalStock = currentStock - sellAmount;

                    // Update Inventory
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('inventory')
                        .doc(item['id'])
                        .update({
                          "stock": finalStock,
                          "updatedAt": FieldValue.serverTimestamp(),
                        });

                    // Add to Shop Listings
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('sellListings')
                        .add({
                          "name": item['name'],
                          "qty": sellAmount,
                          "unit": item['unit'],
                          "price": price,
                          "image": item['image'],
                          "status": "Published",
                          "createdAt": FieldValue.serverTimestamp(),
                        });

                    // LOG HISTORY
                    await _logTransaction(
                      itemName: item['name'],
                      action: "Listed for Sale",
                      quantityChange: -sellAmount,
                      finalStock: finalStock,
                      unit: item['unit'],
                    );

                    await _loadInventory();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Listed ${item['name']} for sale!"),
                      ),
                    );
                  },
                  child: const Text(
                    "List for Sale",
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

  // --- CONFIRM DELETE ---
  void _confirmDelete(String itemId, String itemName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Item"),
        content: Text(
          "Are you sure you want to delete '$itemName'?\nThis cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteItem(itemId, itemName);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- DELETE FUNCTION ---
  Future<void> _deleteItem(String itemId, String itemName) async {
    try {
      final uid = _auth.currentUser!.uid;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('inventory')
          .doc(itemId)
          .delete();

      // LOG HISTORY
      await _logTransaction(
        itemName: itemName,
        action: "Item Deleted",
        quantityChange: 0,
        finalStock: 0,
        unit: "-",
      );

      await _loadInventory();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Item deleted successfully")),
      );
    } catch (e) {
      debugPrint("Error deleting item: $e");
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Oops!", style: TextStyle(color: Colors.red)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Try Again"),
          ),
        ],
      ),
    );
  }

  Future<void> _saveToDatabase({
    required String product,
    required int stock,
    required String unit,
    required String imagePath,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('inventory')
        .add({
          "product": product,
          "stock": stock,
          "unit": unit,
          "image": imagePath,
          "status": "In Stock",
          "createdAt": FieldValue.serverTimestamp(),
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "My Inventory",
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          // --- NEW: HISTORY BUTTON ---
          IconButton(
            icon: const Icon(Icons.history, color: Colors.black),
            tooltip: "View History",
            onPressed: _showHistoryDialog,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewItem,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: inventoryItems.isEmpty
          ? const Center(child: Text("No items in inventory"))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: inventoryItems.length,
              itemBuilder: (context, index) {
                final item = inventoryItems[index];
                return InventoryCard(
                  name: item['name'],
                  stock: item['stock'].toString(),
                  unit: item['unit'],
                  status: item['status'],
                  imagePath: item['image'],
                  onEdit: () => _editItem(index),
                  onSell: () => _sellItem(index),
                  onDelete: () => _confirmDelete(item['id'], item['name']),
                );
              },
            ),
    );
  }
}
