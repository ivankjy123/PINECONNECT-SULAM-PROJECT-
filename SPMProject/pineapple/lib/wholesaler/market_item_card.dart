import 'package:flutter/material.dart';

class MarketItemCard extends StatelessWidget {
  final String title; // e.g. "Nanas MD2 Premium"
  final String pricePerKg; // e.g. "RM 2.50"
  final String minOrder; // e.g. "Min: 500kg"
  final String farmerName; // e.g. "Pak Mat Farm"
  final String location; // e.g. "Johor"
  final String imageUrl; // URL for the image

  const MarketItemCard({
    super.key,
    required this.title,
    required this.pricePerKg,
    required this.minOrder,
    required this.farmerName,
    required this.location,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. PINEAPPLE IMAGE
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 100,
              width: 100,
              color: Colors.green[50], // Loading placeholder color
              child: Image.asset(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (c, o, s) =>
                    Icon(Icons.broken_image, color: Colors.green[200]),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // 2. DETAILS COLUMN
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- START OF FIX ---
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start, // Aligns text to top
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // We wrap the Title in 'Expanded' so it knows its size limit
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2, // Allow it to take 2 lines
                        overflow: TextOverflow
                            .ellipsis, // Add "..." if still too long
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ), // Add space between title and price
                    Text(
                      pricePerKg,
                      style: TextStyle(
                        color: Colors.green[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Text(
                  "/kg",
                  style: TextStyle(color: Colors.grey[400], fontSize: 10),
                ), // Helper text for unit

                const SizedBox(height: 8),

                // Farmer & Location
                Row(
                  children: [
                    const Icon(Icons.storefront, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      farmerName,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      location,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 3. BOTTOM ACTION ROW
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Min Order Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        minOrder,
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Contact Button
                    InkWell(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "Chat",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
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
    );
  }
}
