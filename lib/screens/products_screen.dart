import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<dynamic> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('/products');
      if (response != null && response is List) {
        setState(() {
          _products = response;
        });
      }
    } catch (e) {
      debugPrint('Error loading products: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المنتجات')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProducts,
              child: _products.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        const Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text(
                            'لا يوجد منتجات متاحة',
                            style: TextStyle(fontSize: 20, color: Colors.grey),
                          ),
                        ),
                      ],
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      physics: const AlwaysScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.grey.withOpacity(0.15), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  child: Container(
                                    width: double.infinity,
                                    color: Colors.grey[100],
                                    child: product['image_url'] != null
                                        ? Image.network(product['image_url'], fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.image, size: 50, color: Colors.grey))
                                        : const Icon(Icons.inventory_2, size: 50, color: Colors.teal),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        product['name'],
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${product['price']} ج',
                                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: (product['stock'] ?? 0) > 0 ? Colors.teal.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'مخزون: ${product['stock'] ?? 0}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: (product['stock'] ?? 0) > 0 ? Colors.teal : Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
