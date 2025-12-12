// Simple Global Cart List (In a real app, use Provider/Bloc)
List<Map<String, dynamic>> globalCart = [];

void addToCart(Map<String, dynamic> item) {
  globalCart.add(item);
}

void clearCart() {
  globalCart.clear();
}

double getCartTotal() {
  double total = 0;
  for (var item in globalCart) {
    total += (item['buyQty'] * item['pricePerKg']);
  }
  return total;
}
