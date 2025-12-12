import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SalesReportPage extends StatefulWidget {
  const SalesReportPage({super.key});

  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  // 0 = Week, 1 = Month, 2 = Year
  int _selectedFilter = 0;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- HELPER: GET IMAGE PATH ---
  String _getImagePath(String productName) {
    String name = productName.toLowerCase();
    if (name.contains('seed')) {
      return 'assets/seeds.png';
    } else {
      return 'assets/pineapple.png';
    }
  }

  // --- HELPER: CHECK DATE FILTER ---
  bool _isWithinFilter(DateTime date, int filter) {
    final now = DateTime.now();
    if (filter == 0) {
      // Last 7 Days
      return date.isAfter(now.subtract(const Duration(days: 7)));
    } else if (filter == 1) {
      // Last 30 Days
      return date.isAfter(now.subtract(const Duration(days: 30)));
    } else {
      // Last 365 Days
      return date.isAfter(now.subtract(const Duration(days: 365)));
    }
  }

  // --- HELPER: GENERATE CHART DATA ---
  List<double> _generateChartData(List<DocumentSnapshot> docs) {
    if (docs.isEmpty) return List.filled(7, 0.0);

    List<int> buckets = List.filled(7, 0);
    DateTime now = DateTime.now();
    int totalDays = _selectedFilter == 0
        ? 7
        : (_selectedFilter == 1 ? 30 : 365);
    double daysPerBucket = totalDays / 7;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      Timestamp? ts = data['soldAt'];
      if (ts == null) continue;

      int daysAgo = now.difference(ts.toDate()).inDays;
      int bucketIndex = 6 - (daysAgo / daysPerBucket).floor();

      if (bucketIndex >= 0 && bucketIndex < 7) {
        buckets[bucketIndex]++;
      }
    }

    int maxVal = buckets.reduce((curr, next) => curr > next ? curr : next);
    if (maxVal == 0) return List.filled(7, 0.0);

    return buckets.map((count) => count / maxVal).toList();
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
          "Sales Report",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(user.uid)
            .collection('sellHistory')
            .orderBy('soldAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No sales data available"));
          }

          // --- 1. FILTER DATA ---
          final allDocs = snapshot.data!.docs;
          final filteredDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            Timestamp? ts = data['soldAt'];
            if (ts == null) return false;
            return _isWithinFilter(ts.toDate(), _selectedFilter);
          }).toList();

          // --- 2. CALCULATE METRICS ---
          double totalRevenue = 0.0;
          int totalOrders = filteredDocs.length;

          for (var doc in filteredDocs) {
            final data = doc.data() as Map<String, dynamic>;
            double amount = (data['totalEarned'] ?? 0).toDouble();
            totalRevenue += amount;
          }

          double averageOrderValue = totalOrders > 0
              ? totalRevenue / totalOrders
              : 0.0;
          List<double> chartValues = _generateChartData(filteredDocs);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- FILTER TABS ---
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildTab("Week", 0),
                      _buildTab("Month", 1),
                      _buildTab("Year", 2),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // --- REVENUE CARD ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1B5E20).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Total Revenue",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "RM ${totalRevenue.toStringAsFixed(2)}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "${_selectedFilter == 0
                            ? 'Past 7 Days'
                            : _selectedFilter == 1
                            ? 'Past 30 Days'
                            : 'Past 365 Days'}",
                        style: TextStyle(
                          color: Colors.green[100],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),

                // --- CHART SECTION ---
                const Text(
                  "Order Volume",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                Container(
                  height: 200,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: chartValues.isEmpty || chartValues.every((e) => e == 0)
                      ? const Center(
                          child: Text(
                            "No data for chart",
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: chartValues.map((pct) {
                            return _buildBar(pct);
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 25),

                // --- METRICS ROW ---
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        "Total Orders",
                        "$totalOrders",
                        Icons.shopping_bag_outlined,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildInfoCard(
                        "Avg. Value",
                        "RM ${averageOrderValue.toStringAsFixed(0)}",
                        Icons.attach_money,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                // --- RECENT TRANSACTIONS (UPDATED WITH DIRECT BUYER NAME) ---
                const Text(
                  "Recent Transactions",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                filteredDocs.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(
                          child: Text("No transactions in this period"),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final doc = filteredDocs[index];
                          final data = doc.data() as Map<String, dynamic>;

                          // 1. Parse Data
                          String name = data['productName'] ?? 'Unknown Item';

                          // --- GET BUYER NAME DIRECTLY FROM DB ---
                          String buyerName =
                              data['buyerName'] ?? 'Walk-in Customer';

                          double totalAmount = (data['totalEarned'] ?? 0)
                              .toDouble();
                          String formattedTotal = totalAmount.toStringAsFixed(
                            2,
                          );

                          // Format Date
                          Timestamp? ts = data['soldAt'];
                          String dateStr = ts != null
                              ? DateFormat('dd MMM yyyy').format(ts.toDate())
                              : "No Date";
                          String timeStr = ts != null
                              ? DateFormat('hh:mm a').format(ts.toDate())
                              : "";

                          String imagePath = _getImagePath(name);

                          // 2. Build Card
                          return Container(
                            margin: const EdgeInsets.only(bottom: 1),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 16.0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: Row(
                              children: [
                                // 1. Image
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(10),
                                    image: DecorationImage(
                                      image: AssetImage(imagePath),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // 2. Middle: Name, Buyer Name, Time
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Product Name
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),

                                      // --- SHOW BUYER NAME ---
                                      Text(
                                        "Buyer: $buyerName",
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black54,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),

                                      const SizedBox(height: 4),
                                      // Date & Time
                                      Text(
                                        "$dateStr • $timeStr",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // 3. Right: PRICE
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "+ RM $formattedTotal",
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF00C853),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildTab(String text, int index) {
    bool isSelected = _selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1B5E20) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBar(double pct) {
    double safePct = pct.isNaN || pct.isInfinite ? 0.0 : pct;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: safePct),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Container(
          width: 15,
          height: 150 * value,
          decoration: BoxDecoration(
            color: value >= 0.9
                ? const Color(0xFF1B5E20)
                : const Color(0xFFFBC02D),
            borderRadius: BorderRadius.circular(20),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.1),
            radius: 20,
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 15),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
    );
  }
}
