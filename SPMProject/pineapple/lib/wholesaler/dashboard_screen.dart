import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pineapple/wholesaler/action_card.dart';
import 'package:pineapple/wholesaler/metric_card.dart';
import 'package:pineapple/wholesaler/help_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    String currentDate = DateFormat(
      'EEEE, d MMM y',
    ).format(DateTime.now()).toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER ---
          Text(
            currentDate,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            "Hello, Wholesaler!",
            style: TextStyle(
              color: Colors.green[900],
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          // --- LOCATION ---
          const SizedBox(height: 5),
          if (user != null)
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                String locationText = "Detecting...";
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  locationText = data['location'] ?? "Location not set";
                }
                return Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      "Location: $locationText",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                );
              },
            ),

          const SizedBox(height: 20),

          // --- METRIC CARDS ROW ---
          Row(
            children: [
              // 1. Current Stock (Static / Separate Stream)
              const Expanded(
                child: MetricCard(
                  title: "Current Stock",
                  value: "1,250",
                  unit: "kg",
                  status: "Available",
                  statusColor: Colors.green,
                  icon: Icons.inventory_2_outlined,
                ),
              ),
              const SizedBox(width: 12),

              // 2. WEEKLY SALES (Connected to sellHistory)
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/sale_report'),
                  child: StreamBuilder<QuerySnapshot>(
                    // CHANGED: Pointing to the correct 'sellHistory' collection
                    // to match your Sales Report Screen
                    stream: (user != null)
                        ? FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('sellHistory')
                              .snapshots()
                        : null,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const MetricCard(
                          title: "Weekly Sales",
                          value: "-",
                          unit: "RM",
                          status: "Loading...",
                          statusColor: Colors.grey,
                          icon: Icons.calendar_view_week,
                        );
                      }

                      double weeklyRevenue = 0.0;

                      // LOGIC: Calculate total for the last 7 days
                      if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                        DateTime now = DateTime.now();
                        // Filter for last 7 days (Same as your Report Filter "0")
                        DateTime sevenDaysAgo = now.subtract(
                          const Duration(days: 7),
                        );

                        for (var doc in snapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;

                          // 1. Check Status (Optional: match report logic)
                          String status = data['status'] ?? '';
                          // Skip if not completed/sold
                          if (status != 'Completed' && !status.contains('Sold'))
                            continue;

                          // 2. Check Date
                          Timestamp? ts = data['soldAt'];
                          if (ts != null) {
                            DateTime date = ts.toDate();
                            if (date.isAfter(sevenDaysAgo)) {
                              // 3. Add to Total
                              weeklyRevenue += (data['totalEarned'] ?? 0)
                                  .toDouble();
                            }
                          }
                        }
                      }

                      return MetricCard(
                        title: "Weekly Sales",
                        value: weeklyRevenue.toStringAsFixed(2),
                        unit: "RM",
                        status: "View Report >",
                        statusColor: Colors.blue,
                        icon: Icons.calendar_view_week,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          _buildInventoryCard(),

          const SizedBox(height: 25),

          // --- QUICK ACTIONS ---
          const Text(
            "Quick Actions",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 1.4,
            children: [
              ActionCard(
                icon: Icons.add_business,
                label: "Incoming Orders",
                subLabel: "Check Status",
                color: Colors.orange[50]!,
                iconColor: Colors.orange,
                onTap: () => Navigator.pushNamed(context, '/incoming_orders'),
              ),
              ActionCard(
                icon: Icons.local_shipping,
                label: "Transaction Log",
                subLabel: "Transaction",
                color: Colors.blue[50]!,
                iconColor: Colors.blue,
                onTap: () => Navigator.pushNamed(context, '/transaction_log'),
              ),
              ActionCard(
                icon: Icons.emergency,
                label: "Help",
                subLabel: "Provide Assistance",
                color: Colors.red[50]!,
                iconColor: Colors.red,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpScreen()),
                ),
              ),
              ActionCard(
                icon: Icons.analytics,
                label: "Sales Report",
                subLabel: "Analytics",
                color: Colors.green[50]!,
                iconColor: Colors.green,
                onTap: () => Navigator.pushNamed(context, '/sale_report'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[800]!, Colors.green[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Inventory Capacity",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "MD2 Grade A",
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: 0.7,
              minHeight: 12,
              backgroundColor: Colors.green[900],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ),
          const SizedBox(height: 15),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Space: 70% Full", style: TextStyle(color: Colors.white)),
              Text(
                "Next Restock: 12 Dec",
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
