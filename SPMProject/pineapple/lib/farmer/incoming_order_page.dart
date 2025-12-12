import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class IncomingOrderPage extends StatefulWidget {
  const IncomingOrderPage({super.key});

  @override
  State<IncomingOrderPage> createState() => _IncomingOrderPageState();
}

class _IncomingOrderPageState extends State<IncomingOrderPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- STATE: FILTER SELECTION ---
  String _selectedFilter = 'All Time';
  final List<String> _filterOptions = [
    '1 Week',
    '1 Month',
    '1 Year',
    'All Time',
  ];

  // --- HELPER: GET IMAGE PATH ---
  String _getImagePath(String productName) {
    String name = productName.toLowerCase();
    if (name.contains('seed')) {
      return 'assets/seeds.png';
    } else {
      return 'assets/pineapple.png';
    }
  }

  // --- HELPER: CHECK DATE ---
  bool _shouldShowOrder(Timestamp? timestamp) {
    if (_selectedFilter == 'All Time') return true;
    if (timestamp == null) return false;

    DateTime orderDate = timestamp.toDate();
    DateTime now = DateTime.now();

    if (_selectedFilter == '1 Week') {
      return orderDate.isAfter(now.subtract(const Duration(days: 7)));
    } else if (_selectedFilter == '1 Month') {
      return orderDate.isAfter(now.subtract(const Duration(days: 30)));
    } else if (_selectedFilter == '1 Year') {
      return orderDate.isAfter(now.subtract(const Duration(days: 365)));
    }
    return true;
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
          "Incoming Orders",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFilter,
                icon: const Icon(Icons.filter_list, color: Colors.green),
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
                items: _filterOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedFilter = newValue;
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(user.uid)
            .collection('sellHistory')
            // Note: .where() is removed as requested to show ALL (Completed & Pending)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyMsg();
          }

          // Filter Data based on Date Dropdown
          final allDocs = snapshot.data!.docs;
          final filteredDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _shouldShowOrder(data['soldAt']);
          }).toList();

          if (filteredDocs.isEmpty) {
            return Center(child: Text("No orders found for $_selectedFilter"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final doc = filteredDocs[index];
              final data = doc.data() as Map<String, dynamic>;

              // 1. GET DATA
              String name = data['productName'] ?? 'Unknown Item';

              // --- NEW: Get Buyer Name ---
              String buyerName = data['buyerName'] ?? 'Walk-in Customer';

              String qty = "0";
              var rawQty = data['qty'];
              if (rawQty is num) {
                qty = rawQty.toInt().toString();
              } else if (rawQty != null) {
                qty = rawQty.toString();
              }

              String unit = data['unit'] ?? 'unit';
              String total = (data['totalEarned'] ?? 0).toString();
              String status = data['status'] ?? 'Pending';

              Timestamp? ts = data['soldAt'];
              String dateStr = ts != null
                  ? DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate())
                  : "No Date";

              String imagePath = _getImagePath(name);

              // 2. Set Status Colors
              Color badgeColor = Colors.orange[50]!;
              Color textColor = Colors.orange[800]!;

              if (status == 'Completed') {
                badgeColor = Colors.green[50]!;
                textColor = Colors.green;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Image
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                          image: DecorationImage(
                            image: AssetImage(imagePath),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),

                      // Details Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Name
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),

                            const SizedBox(height: 2),

                            // --- SHOW BUYER NAME HERE ---
                            Text(
                              "Buyer: $buyerName",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.blueGrey, // Distinct color
                              ),
                            ),

                            const SizedBox(height: 4),

                            // Qty and Total
                            Text(
                              "$qty $unit • Total: RM $total",
                              style: TextStyle(color: Colors.grey[700]),
                            ),

                            const SizedBox(height: 6),

                            // Date & Status Badge
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    dateStr,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
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
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyMsg() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 10),
          const Text(
            "No Orders Found",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
