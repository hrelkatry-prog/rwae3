import 'package:flutter/material.dart';
import 'package:rwae3_mobile/services/api_service.dart';
import 'package:rwae3_mobile/screens/visit_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final customers = await ApiService.fetchCustomers();
    setState(() {
      _customers = customers;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('قائمة العملاء'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCustomers,
              child: _customers.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        const Icon(Icons.people_outline, size: 80, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text(
                            'لا يوجد عملاء متاحين حالياً',
                            style: TextStyle(fontSize: 20, color: Colors.grey),
                          ),
                        ),
                        const Center(
                          child: Text(
                            'اسحب الشاشة للأسفل للتحديث',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _customers.length,
                      itemBuilder: (context, index) {
                        final customer = _customers[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.blue,
                              child: Icon(Icons.store, color: Colors.white),
                            ),
                            title: Text(customer['name']),
                            subtitle: Text(customer['phone'] ?? 'لا يوجد رقم'),
                            trailing: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => VisitScreen(customer: customer),
                                  ),
                                );
                              },
                              child: const Text('تسجيل زيارة'),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
