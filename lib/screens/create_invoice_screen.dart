import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  List<dynamic> _customers = [];
  List<dynamic> _products = [];
  dynamic _selectedCustomer;
  final List<Map<String, dynamic>> _invoiceItems = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final customersRes = await ApiService.get('/customers');
      final productsRes = await ApiService.get('/products');
      
      if (mounted) {
        setState(() {
          if (customersRes is List) _customers = customersRes;
          if (productsRes is List) _products = productsRes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error loading data for invoice: $e');
    }
  }

  void _showAddProductDialog() {
    dynamic selectedProduct;
    int quantity = 1;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('إضافة منتج للفاتورة'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<dynamic>(
                  decoration: const InputDecoration(labelText: 'اختر المنتج'),
                  items: _products.map((p) {
                    return DropdownMenuItem(
                      value: p,
                      child: Text('${p['name']} (${p['price']} ج)'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setDialogState(() => selectedProduct = val);
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الكمية:'),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle),
                          onPressed: () {
                            if (quantity > 1) {
                              setDialogState(() => quantity--);
                            }
                          },
                        ),
                        Text('$quantity', style: const TextStyle(fontSize: 18)),
                        IconButton(
                          icon: const Icon(Icons.add_circle),
                          onPressed: () {
                            setDialogState(() => quantity++);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () {
                  if (selectedProduct != null) {
                    setState(() {
                      _invoiceItems.add({
                        'product_id': selectedProduct['id'],
                        'name': selectedProduct['name'],
                        'unit_price': selectedProduct['price'],
                        'quantity': quantity,
                        'total': (double.parse(selectedProduct['price'].toString()) * quantity),
                      });
                    });
                    Navigator.pop(context);
                  }
                },
                child: const Text('إضافة'),
              ),
            ],
          );
        });
      },
    );
  }

  double get _subtotal {
    return _invoiceItems.fold(0, (sum, item) => sum + item['total']);
  }

  Future<void> _saveInvoice() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار العميل')));
      return;
    }
    if (_invoiceItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إضافة منتجات للفاتورة')));
      return;
    }

    setState(() => _isSaving = true);
    
    try {
      final payload = {
        'customer_id': _selectedCustomer['id'],
        'subtotal': _subtotal,
        'tax_amount': 0, // No tax for now
        'discount': 0, // No discount for now
        'total': _subtotal,
        'payment_method': 'cash',
        'items': _invoiceItems.map((item) => {
          'product_id': item['product_id'],
          'quantity': item['quantity'],
          'unit_price': item['unit_price'],
          'total': item['total'],
        }).toList(),
      };

      final response = await ApiService.post('/invoices', payload);
      
      if (response['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الفاتورة بنجاح!')));
        Navigator.pop(context, true); // Return true to signal refresh needed
      } else {
        throw Exception(response['message'] ?? 'Unknown error');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('فاتورة جديدة')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<dynamic>(
                    decoration: const InputDecoration(
                      labelText: 'العميل',
                      border: OutlineInputBorder(),
                    ),
                    items: _customers.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text(c['name']),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedCustomer = val);
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المنتجات:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ElevatedButton.icon(
                        onPressed: _showAddProductDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة منتج'),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: _invoiceItems.isEmpty
                        ? const Center(child: Text('لم يتم إضافة منتجات للفاتورة بعد', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: _invoiceItems.length,
                            itemBuilder: (context, index) {
                              final item = _invoiceItems[index];
                              return Card(
                                child: ListTile(
                                  title: Text(item['name']),
                                  subtitle: Text('${item['quantity']} × ${item['unit_price']} ج'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('${item['total']} ج', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () {
                                          setState(() => _invoiceItems.removeAt(index));
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('الإجمالي:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('$_subtotal ج', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveInvoice,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.teal,
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('حفظ الفاتورة', style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ),
    );
  }
}
