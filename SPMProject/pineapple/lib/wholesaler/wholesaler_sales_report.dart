import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SaleReportScreen extends StatefulWidget {
  const SaleReportScreen({super.key});

  @override
  State<SaleReportScreen> createState() => _SaleReportScreenState();
}

class _SaleReportScreenState extends State<SaleReportScreen> {
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
    // Always return 7 points for the line chart (smooth curve)
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
      // Calculate bucket index (0 = oldest, 6 = newest)
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

          final allDocs = snapshot.data!.docs;

          // --- 1. FILTER DATA ---
          final filteredDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;

            // Check Status (Accept "Completed" or anything with "Sold")
            String status = data['status'] ?? '';
            if (status != 'Completed' && !status.contains('Sold')) return false;

            // Date Filter
            Timestamp? ts = data['soldAt'];
            if (ts == null) return false;
            return _isWithinFilter(ts.toDate(), _selectedFilter);
          }).toList();

          // --- 2. CALCULATE METRICS ---
          double totalRevenue = 0.0;
          for (var doc in filteredDocs) {
            final data = doc.data() as Map<String, dynamic>;
            double amount = (data['totalEarned'] ?? 0).toDouble();
            totalRevenue += amount;
          }

          double averageOrderValue = filteredDocs.isNotEmpty
              ? totalRevenue / filteredDocs.length
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
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
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
                        color: const Color(0xFF1B5E20).withOpacity(0.3),
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
                    ],
                  ),
                ),
                const SizedBox(height: 25),

                // --- LINE CHART (NEW) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Order Trend",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Legend
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          color: const Color(0xFF1B5E20),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          "Volume",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Container(
                  height: 200,
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  // Check if empty
                  child: chartValues.isEmpty || chartValues.every((e) => e == 0)
                      ? const Center(
                          child: Text(
                            "No data for chart",
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : CustomPaint(
                          size: Size.infinite,
                          painter: LineChartPainter(
                            dataPoints: chartValues,
                            color: const Color(0xFF1B5E20),
                          ),
                        ),
                ),
                const SizedBox(height: 25),

                // --- METRICS ROW ---
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        "Total Orders",
                        "${filteredDocs.length}",
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

                // --- RECENT TRANSACTIONS ---
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

                          String name = data['productName'] ?? 'Unknown Item';
                          String buyerName =
                              data['buyerName'] ?? 'Unknown Buyer';
                          int qty = (data['qty'] ?? 0).toInt();
                          String unit = data['unit'] ?? 'kg';

                          double totalAmount = (data['totalEarned'] ?? 0)
                              .toDouble();
                          String formattedTotal = totalAmount.toStringAsFixed(
                            2,
                          );

                          Timestamp? ts = data['soldAt'];
                          String dateStr = ts != null
                              ? DateFormat('dd MMM yyyy').format(ts.toDate())
                              : "No Date";
                          String timeStr = ts != null
                              ? DateFormat('hh:mm a').format(ts.toDate())
                              : "";

                          String imagePath = _getImagePath(name);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 1),
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: Row(
                              children: [
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
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Container(
                                            margin: const EdgeInsets.only(
                                              left: 8,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green[50],
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              "$qty $unit",
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.green[800],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        "Buyer: $buyerName",
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black54,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
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
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
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

// --- NEW CLASS: LINE CHART PAINTER ---
class LineChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final Color color;

  LineChartPainter({required this.dataPoints, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    // 1. Paint for the line
    final Paint linePaint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 2. Paint for the dots
    final Paint dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 3. Paint for the gradient fill below the line
    final Paint fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final Path path = Path();
    // Calculate spacing between points
    final double stepX = size.width / (dataPoints.length - 1);

    for (int i = 0; i < dataPoints.length; i++) {
      double x = i * stepX;
      // Invert Y because canvas 0 is at top
      // Value is 0.0 to 1.0, so we multiply by height
      // We add 10px padding from top/bottom to ensure dots aren't cut off
      double graphHeight = size.height - 20;
      double y = (size.height - 10) - (dataPoints[i] * graphHeight);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw the Gradient Fill
    Path fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    // Draw the Line
    canvas.drawPath(path, linePaint);

    // Draw the Dots on top
    for (int i = 0; i < dataPoints.length; i++) {
      double x = i * stepX;
      double graphHeight = size.height - 20;
      double y = (size.height - 10) - (dataPoints[i] * graphHeight);

      // Draw white circle background for dot (makes it pop)
      canvas.drawCircle(Offset(x, y), 6.0, Paint()..color = Colors.white);
      // Draw colored dot
      canvas.drawCircle(Offset(x, y), 4.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) {
    return oldDelegate.dataPoints != dataPoints;
  }
}
