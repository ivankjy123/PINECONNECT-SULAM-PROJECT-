import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TransactionLogPage extends StatefulWidget {
  const TransactionLogPage({super.key});

  @override
  State<TransactionLogPage> createState() => _TransactionLogPageState();
}

class _TransactionLogPageState extends State<TransactionLogPage> {
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

  // --- HELPER: CHECK DATE ---
  bool _shouldShowItem(Timestamp? timestamp) {
    if (_selectedFilter == 'All Time') return true;
    if (timestamp == null) return false;

    DateTime date = timestamp.toDate();
    DateTime now = DateTime.now();

    if (_selectedFilter == '1 Week') {
      return date.isAfter(now.subtract(const Duration(days: 7)));
    } else if (_selectedFilter == '1 Month') {
      return date.isAfter(now.subtract(const Duration(days: 30)));
    } else if (_selectedFilter == '1 Year') {
      return date.isAfter(now.subtract(const Duration(days: 365)));
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
          "Stock Activity",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),

        // --- ADDED: FILTER DROPDOWN ---
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
      // Directly build the Stock Log
      body: _buildStockLog(user.uid),
    );
  }

  // ---------------------------------------------------------------------------
  // STOCK LOG BUILDER
  // ---------------------------------------------------------------------------
  Widget _buildStockLog(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .doc(uid)
          .collection('inventoryHistory')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        // 1. Loading State
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // 2. Empty State (Database Empty)
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            Icons.inventory_2_outlined,
            "No stock changes recorded yet.",
          );
        }

        // 3. FILTERING LOGIC
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          // Filter A: Exclude "Listed for Sale"
          bool isNotListed = data['action'] != 'Listed for Sale';

          // Filter B: Check Date (1 Week, 1 Month, etc.)
          bool isInDateRange = _shouldShowItem(data['timestamp']);

          return isNotListed && isInDateRange;
        }).toList();

        // 4. Empty State (Filtered Result Empty)
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.filter_list_off, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text(
                  "No stock activity in the last $_selectedFilter",
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            String name = data['itemName'] ?? "Unknown";
            String action = data['action'] ?? "Update";

            // Safe conversion
            int change = (data['change'] as num?)?.toInt() ?? 0;

            String unit = data['unit'] ?? "units";
            Timestamp? ts = data['timestamp'];

            String date = ts != null
                ? DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate())
                : "-";

            bool isPositive = change > 0;
            bool isDelete = action.contains("Deleted");

            Color iconColor;
            IconData iconData;

            if (isDelete) {
              iconColor = Colors.red;
              iconData = Icons.delete_outline;
            } else if (isPositive) {
              iconColor = Colors.green;
              iconData = Icons.add_circle_outline;
            } else {
              iconColor = Colors.orange;
              iconData = Icons.remove_circle_outline;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: iconColor.withValues(alpha: 0.1),
                  child: Icon(iconData, color: iconColor, size: 20),
                ),
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "$action • $date",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                trailing: Text(
                  "${isPositive ? '+' : ''}$change $unit",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isPositive ? Colors.green[700] : Colors.black87,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- HELPER: EMPTY STATE ---
  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 15),
          Text(
            message,
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }
}
