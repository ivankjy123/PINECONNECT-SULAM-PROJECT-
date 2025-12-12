import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:pineapple/wholesaler/dashboard_screen.dart';
import 'package:pineapple/wholesaler/inventory_screen.dart';
import 'package:pineapple/wholesaler/market_screen.dart';
import 'package:pineapple/wholesaler/profile_screen.dart';
import 'package:pineapple/wholesaler/wholesaler_sales_report.dart';
import 'package:pineapple/wholesaler/wholesaler_transaction_log.dart';
// 1. IMPORT THE NEW SCREEN
import 'package:pineapple/wholesaler/wholesaler_incoming_order.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const PineappleWholesaleApp());
}

class PineappleWholesaleApp extends StatelessWidget {
  const PineappleWholesaleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pineapple Wholesaler',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const MainLayout(),

      // 2. REGISTER THE NEW ROUTE
      routes: {
        '/sale_report': (context) => const SaleReportScreen(),
        '/transaction_log': (context) => const WholesalerTransactionLogScreen(),
        '/incoming_orders': (context) => const WholesalerIncomingOrdersScreen(),
      },
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DashboardScreen(),
    const MarketScreen(),
    const InventoryScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _pages[_currentIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green[800],
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront),
            label: 'Market',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'My Stock',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
