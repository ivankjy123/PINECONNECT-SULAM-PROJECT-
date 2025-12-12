import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WholesalerTransactionLogScreen extends StatefulWidget {
  const WholesalerTransactionLogScreen({super.key});

  @override
  State<WholesalerTransactionLogScreen> createState() =>
      _WholesalerTransactionLogScreenState();
}

class _WholesalerTransactionLogScreenState
    extends State<WholesalerTransactionLogScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Please login")));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          "Transaction Log",
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.green[800],
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.green[800],
          tabs: const [
            Tab(text: "Purchases (From Farmer)"),
            Tab(text: "Sales (My Listings)"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: PURCHASES (Money Out)
          // FIXED: Pointing to 'inventoryHistory' and using 'date' field
          _buildTransactionList(
            collectionName: 'inventoryHistory',
            timeField: 'date',
            isPurchase: true,
            userId: user.uid,
          ),

          // TAB 2: SALES (Money In)
          // This matches your 'sellHistory' screenshot
          _buildTransactionList(
            collectionName: 'sellHistory',
            timeField: 'soldAt',
            isPurchase: false,
            userId: user.uid,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList({
    required String collectionName,
    required String timeField,
    required bool isPurchase,
    required String userId,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .doc(userId)
          .collection(collectionName)
          .orderBy(timeField, descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPurchase
                      ? Icons.shopping_basket_outlined
                      : Icons.sell_outlined,
                  size: 60,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 10),
                Text(
                  isPurchase
                      ? "No purchases from farmers yet"
                      : "No sales recorded yet",
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        // Filter the list:
        // For Purchases (inventoryHistory), we only want items where action == "Buy"
        final docs = snapshot.data!.docs.where((doc) {
          if (isPurchase) {
            final data = doc.data() as Map<String, dynamic>;
            return data['action'] == 'Buy';
          }
          return true; // Show all sales
        }).toList();

        if (docs.isEmpty) {
          return const Center(child: Text("No 'Buy' records found"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            // --- DATA PARSING ---
            String itemName = data['productName'] ?? 'Pineapple Batch';

            // NAME LOGIC:
            // For Sales, use 'buyerName'.
            // For Purchases, your DB has 'details' like "Bought from null". We try to use that.
            String otherPartyName = "Unknown";
            if (isPurchase) {
              otherPartyName = data['details'] ?? 'Farmer';
            } else {
              otherPartyName = data['buyerName'] ?? 'Unknown Buyer';
            }

            // AMOUNT LOGIC:
            // Sales use 'totalEarned'. Purchases use 'amount' (which is negative, e.g. -50).
            double totalAmount = 0.0;
            if (isPurchase) {
              // Convert -50 to 50 using .abs()
              totalAmount = (data['amount'] ?? 0).toDouble().abs();
            } else {
              totalAmount = (data['totalEarned'] ?? 0).toDouble();
            }

            // DATE LOGIC:
            Timestamp? ts = data[timeField];
            String dateStr = ts != null
                ? DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate())
                : "Date Unknown";

            // Status is optional
            String status =
                data['status'] ?? (isPurchase ? 'Stock In' : 'Completed');

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Icon Box
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isPurchase
                            ? Colors.orange[50]
                            : Colors.green[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isPurchase ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isPurchase ? Colors.orange : Colors.green,
                      ),
                    ),
                    const SizedBox(width: 15),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            itemName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${isPurchase ? '' : 'To: '}$otherPartyName",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateStr,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Price & Status
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "${isPurchase ? '-' : '+'} RM ${totalAmount.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isPurchase
                                ? Colors.red[700]
                                : Colors.green[700],
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
