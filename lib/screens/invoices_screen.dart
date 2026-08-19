import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'create_invoice_screen.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  List<dynamic> _invoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('/invoices');
      if (response != null && response is List) {
        setState(() {
          _invoices = response;
        });
      }
    } catch (e) {
      debugPrint('Error loading invoices: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الفواتير والزيارات')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInvoices,
              child: _invoices.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        const Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text(
                            'لا يوجد فواتير حتى الآن',
                            style: TextStyle(fontSize: 20, color: Colors.grey),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _invoices.length,
                      itemBuilder: (context, index) {
                        final invoice = _invoices[index];
                        final customerName = invoice['customer'] != null ? invoice['customer']['name'] : 'عميل غير معروف';
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.teal,
                              child: Icon(Icons.receipt, color: Colors.white),
                            ),
                            title: Text(invoice['invoice_number'] ?? 'فاتورة'),
                            subtitle: Text('العميل: $customerName\nالتاريخ: ${invoice['date']}'),
                            trailing: Text(
                              '${invoice['total']} ج',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
          );
          if (result == true) {
            _loadInvoices(); // Refresh if new invoice was created
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
