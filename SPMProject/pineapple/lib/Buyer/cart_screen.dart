import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_model.dart'; // Import global cart

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isCheckingOut = false;

  // --- CHECKOUT LOGIC (The Heavy Lifting) ---
  Future<void> _processCheckout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (globalCart.isEmpty) return;

    setState(() => _isCheckingOut = true);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        for (var item in globalCart) {
          DocumentReference listingRef = item['listingRef'];

          // 1. Check Live Stock (Prevent over-selling)
          DocumentSnapshot freshSnap = await transaction.get(listingRef);
          if (!freshSnap.exists)
            throw Exception("${item['title']} is no longer available!");

          double currentStock = (num.tryParse(freshSnap['qty'].toString()) ?? 0)
              .toDouble();
          double buyQty = item['buyQty'];

          if (currentStock < buyQty) {
            throw Exception(
              "Not enough stock for ${item['title']}. Available: $currentStock",
            );
          }

          // 2. Deduct Listing Stock
          transaction.update(listingRef, {'qty': currentStock - buyQty});

          // 3. Create Wholesaler Sales Record
          double totalItemCost = buyQty * item['pricePerKg'];
          DocumentReference sellerHistoryRef = FirebaseFirestore.instance
              .collection('users')
              .doc(item['wholesalerId'])
              .collection('sellHistory')
              .doc();

          transaction.set(sellerHistoryRef, {
            'productName': item['title'],
            'qty': buyQty,
            'unit': item['unit'],
            'totalEarned': totalItemCost,
            'soldAt': FieldValue.serverTimestamp(),
            'buyerId': user.uid,
            'buyerName': user.displayName ?? "Buyer",
            'status': 'Sold via Cart',
          });

          // 4. Create Buyer Order Record
          DocumentReference buyerOrderRef = FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('orders')
              .doc();

          transaction.set(buyerOrderRef, {
            'productName': item['title'],
            'sellerName': item['sellerName'],
            'qty': buyQty,
            'totalCost': totalItemCost,
            'boughtAt': FieldValue.serverTimestamp(),
            'status': 'Processing',
            'image': item['image'],
          });
        }
      });

      // Success!
      setState(() {
        clearCart(); // Empty local cart
        _isCheckingOut = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Order Confirmed! Items purchased successfully."),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Go back or stay here
      }
    } catch (e) {
      setState(() => _isCheckingOut = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Checkout Failed"),
            content: Text(e.toString().replaceAll("Exception: ", "")),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double total = getCartTotal();

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Cart"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: globalCart.isEmpty
          ? const Center(child: Text("Your cart is empty."))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: globalCart.length,
                    itemBuilder: (context, index) {
                      final item = globalCart[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Image.asset(
                            item['image'],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                          title: Text(item['title']),
                          subtitle: Text(
                            "${item['buyQty']} ${item['unit']} x RM ${item['pricePerKg']}",
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                globalCart.removeAt(index);
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.white,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Total:",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "RM ${total.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                          ),
                          onPressed: _isCheckingOut ? null : _processCheckout,
                          child: _isCheckingOut
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  "CONFIRM CHECKOUT",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
