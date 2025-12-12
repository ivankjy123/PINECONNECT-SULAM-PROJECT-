import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// --- FIREBASE IMPORTS ---
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- PAGE IMPORTS ---
import 'farmer_profile_page.dart';
import 'transaction_log_page.dart';
import 'farmer_inventory.dart';
import 'shop_manager.dart'; // For "My Products" tab
import 'sales_report_page.dart'; // For "Sales Report" button
import 'incoming_order_page.dart'; // For "Incoming Order" button
import 'farmer_actions_pages.dart'; // For Transaction Log & Help

class SulamApp extends StatelessWidget {
  const SulamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SULAM Melaka Dashboard',
      theme: ThemeData(
        primaryColor: const Color(0xFF1B5E20),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          secondary: const Color(0xFFFBC02D),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const FarmerDashboard(),
    );
  }
}

class FarmerDashboard extends StatefulWidget {
  const FarmerDashboard({super.key});

  @override
  State<FarmerDashboard> createState() => _FarmerDashboardState();
}

class _FarmerDashboardState extends State<FarmerDashboard> {
  int _selectedIndex = 0;

  // --- FIREBASE ---
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final double lat = 2.1896;
  final double long = 102.2501;
  final String priceApiUrl = "https://api.npoint.io/e97d8487313009762952";

  String temperature = "--";
  String weatherCode = "Loading...";
  bool isLoading = true;
  String marketPrice = "RM 2.60";
  String priceTrend = "--";
  String priceGrade = "";
  String todayDate = "";

  DateTime plantingDate = DateTime(2024, 10, 15);
  DateTime harvestDate = DateTime.now();
  int currentDayCount = 0;
  int daysRemaining = 0;
  String cropStage = "";
  final int totalCycleDays = 450;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
    _loadCropDate();
  }

  void _initializeDashboard() {
    fetchMelakaWeather();
    fetchMarketPrice();
    _recalculateCropCycle();
    final DateTime now = DateTime.now();
    todayDate = DateFormat('EEEE, d MMM yyyy', 'en_US').format(now);
  }

  Future<void> _loadCropDate() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()!.containsKey('plantingDate')) {
          Timestamp ts = doc['plantingDate'];
          if (mounted) {
            setState(() {
              plantingDate = ts.toDate();
              _recalculateCropCycle();
            });
          }
        }
      } catch (e) {
        debugPrint("Error loading crop date: $e");
      }
    }
  }

  Future<void> _saveCropDate(DateTime date) async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'plantingDate': Timestamp.fromDate(date),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint("Error saving date: $e");
      }
    }
  }

  void _recalculateCropCycle() {
    final DateTime now = DateTime.now();
    harvestDate = plantingDate.add(const Duration(days: 450));
    currentDayCount = now.difference(plantingDate).inDays;
    daysRemaining = totalCycleDays - currentDayCount;

    if (currentDayCount < 0) {
      cropStage = "Not Started";
      daysRemaining = totalCycleDays;
    } else if (currentDayCount < 240) {
      cropStage = "Stage: Vegetative (Growing)";
    } else if (currentDayCount < 270) {
      cropStage = "Stage: Flowering (Induction)";
    } else if (currentDayCount < 400) {
      cropStage = "Stage: Fruiting";
    } else {
      cropStage = "READY TO HARVEST";
      daysRemaining = 0;
    }
    if (mounted) setState(() {});
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: plantingDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1B5E20),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != plantingDate) {
      setState(() {
        plantingDate = picked;
        _recalculateCropCycle();
      });
      await _saveCropDate(picked);
    }
  }

  // --- FETCH CURRENT WEATHER (SMALL CARD) ---
  Future<void> fetchMelakaWeather() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$long&current_weather=true',
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            temperature = "${data['current_weather']['temperature']}°C";
            double code = data['current_weather']['weathercode'].toDouble();
            weatherCode = _getWeatherString(code);
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          temperature = "Err";
          isLoading = false;
        });
      }
    }
  }

  // --- HELPER: CONVERT WMO CODE TO STRING ---
  String _getWeatherString(double code) {
    if (code <= 3) return "Clear / Cloudy";
    if (code < 50) return "Foggy";
    if (code < 80) return "Rain";
    return "Thunderstorm";
  }

  // --- NEW: FETCH 7-DAY FORECAST ---
  Future<List<Map<String, dynamic>>> fetchWeeklyForecast() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$long&daily=temperature_2m_max,temperature_2m_min,weathercode&timezone=Asia%2FSingapore',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> dates = data['daily']['time'];
        List<dynamic> maxTemps = data['daily']['temperature_2m_max'];
        List<dynamic> minTemps = data['daily']['temperature_2m_min'];
        List<dynamic> codes = data['daily']['weathercode'];

        List<Map<String, dynamic>> forecast = [];
        for (int i = 0; i < dates.length; i++) {
          forecast.add({
            'date': dates[i],
            'max': maxTemps[i],
            'min': minTemps[i],
            'code': codes[i],
          });
        }
        return forecast;
      }
    } catch (e) {
      debugPrint("Error fetching forecast: $e");
    }
    return [];
  }

  // --- NEW: SHOW WEATHER NEWS DIALOG ---
  void _showWeatherDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                margin: const EdgeInsets.only(top: 15, bottom: 10),
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Text(
                "7-Day Weather Forecast",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Text(
                "Melaka, Malaysia",
                style: TextStyle(color: Colors.grey),
              ),
              const Divider(),

              // List
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: fetchWeeklyForecast(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text("Unable to load forecast data."),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final day = snapshot.data![index];
                        DateTime date = DateTime.parse(day['date']);
                        String dateStr = DateFormat('EEE, d MMM').format(date);
                        double code = (day['code'] as num).toDouble();

                        IconData icon = Icons.wb_sunny;
                        Color iconColor = Colors.orange;
                        String status = "Clear";

                        // Map WMO codes to Icons
                        if (code > 3 && code < 50) {
                          icon = Icons.cloud;
                          iconColor = Colors.grey;
                          status = "Cloudy";
                        } else if (code >= 51 && code < 80) {
                          icon = Icons.umbrella; // Rain icon
                          iconColor = Colors.blue;
                          status = "Rain";
                        } else if (code >= 80) {
                          icon = Icons.flash_on; // Thunderstorm icon
                          iconColor = Colors.deepPurple;
                          status = "Storm";
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(icon, color: iconColor),
                                  const SizedBox(width: 15),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dateStr,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        status,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Text(
                                "${day['max']}° / ${day['min']}°",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> fetchMarketPrice() async {
    try {
      final response = await http
          .get(Uri.parse(priceApiUrl))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            marketPrice = "RM ${data['price']}";
            priceTrend = data['trend'];
            priceGrade = "/ kg (${data['grade']})";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          marketPrice = "RM 2.60";
          priceTrend = "Offline";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    final homePage = RefreshIndicator(
      onRefresh: () async {
        await fetchMelakaWeather();
        await fetchMarketPrice();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              todayDate.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 5),

            // --- REAL-TIME HEADER ---
            StreamBuilder<DocumentSnapshot>(
              stream: user != null
                  ? _firestore.collection('users').doc(user.uid).snapshots()
                  : null,
              builder: (context, snapshot) {
                String userName = "Entrepreneur";
                String userLocation = "Jasin, Melaka";

                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  userName = data['name'] ?? "Entrepreneur";

                  String loc = data['location'] ?? "";
                  if (loc.isNotEmpty && loc != "Not Set") {
                    userLocation = "$loc, Melaka";
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Hello, $userName!",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    Text(
                      "Location: $userLocation",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    icon: Icons.monetization_on_outlined,
                    label: "Market Price",
                    value: marketPrice,
                    subValue: priceGrade,
                    trend: priceTrend,
                    isPositive: true,
                    // No onTap needed for Price for now
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    icon: Icons.thermostat,
                    label: "Weather",
                    value: temperature,
                    subValue: weatherCode,
                    trend: "Forecast", // Changed from Live to Forecast hint
                    isPositive: true,
                    // --- CLICK ACTION FOR WEATHER ---
                    onTap: () => _showWeatherDetails(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildCropCycleCard(),
            const SizedBox(height: 20),
            const Text(
              "Farm Log (Actions)",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildActionCard(
                  icon: Icons.shopping_cart_checkout,
                  title: "Incoming Order",
                  subtitle: "Check Orders",
                  color: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const IncomingOrderPage(),
                      ),
                    );
                  },
                ),
                _buildActionCard(
                  icon: Icons.receipt_long,
                  title: "Transaction Log",
                  subtitle: "View History",
                  color: Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TransactionLogPage(),
                      ),
                    );
                  },
                ),
                _buildActionCard(
                  icon: Icons.help_outline,
                  title: "Help",
                  subtitle: "Support Center",
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const HelpPage()),
                    );
                  },
                ),
                _buildActionCard(
                  icon: Icons.bar_chart,
                  title: "Sales Report",
                  subtitle: "Analytics",
                  color: Colors.purple,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SalesReportPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: _selectedIndex == 0 ? _buildAppBar() : null,
      body: _selectedIndex == 0
          ? homePage
          : _selectedIndex == 1
          ? const FarmerInventoryPage()
          : _selectedIndex == 2
          ? const ShopManager()
          : const FarmerProfilePage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFF1B5E20),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.sell), label: 'My Products'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.spa, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Text(
            "SULAM Melaka",
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  // --- UPDATED: ADDED onTap capability ---
  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required String subValue,
    required String trend,
    required bool isPositive,
    VoidCallback? onTap, // Added this parameter
  }) {
    return InkWell(
      onTap: onTap, // Hook it up
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: Colors.grey[600], size: 20),
                if (trend.isNotEmpty && trend != "--")
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: onTap != null
                          ? Colors.blueAccent
                          : Colors.redAccent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      trend,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              subValue,
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCropCycleCard() {
    double progress = (currentDayCount / totalCycleDays).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Crop Cycle (MD2)",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month,
                        size: 12,
                        color: Color(0xFF1B5E20),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Start: ${DateFormat('dd MMM yy', 'en_US').format(plantingDate)}",
                        style: const TextStyle(
                          color: Color(0xFF1B5E20),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFF144618),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFFBC02D),
              ),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoColumn("Day", "$currentDayCount"),
              _buildInfoColumn(
                "Est. Harvest",
                DateFormat('MMM yyyy', 'en_US').format(harvestDate),
              ),
              _buildInfoColumn("Days Left", "$daysRemaining"),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              cropStage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
