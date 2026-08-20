import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rwae3_mobile/services/api_service.dart';
import 'package:rwae3_mobile/services/location_service.dart';
import 'package:rwae3_mobile/screens/visit_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _customers = [];
  bool _isLoading = true;
  Position? _currentPosition;
  String _sortMode = 'distance'; // 'distance' or 'last_visit'

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    
    // Get location and customers concurrently if possible, or sequentially
    _currentPosition = await LocationService.getCurrentLocation();
    final customers = await ApiService.fetchCustomers();
    
    // Calculate distance for each customer
    for (var customer in customers) {
      if (_currentPosition != null && customer['latitude'] != null && customer['longitude'] != null) {
        final double lat = double.tryParse(customer['latitude'].toString()) ?? 0.0;
        final double lng = double.tryParse(customer['longitude'].toString()) ?? 0.0;
        
        if (lat != 0.0 && lng != 0.0) {
          customer['distance'] = LocationService.calculateDistanceInMeters(
            _currentPosition!.latitude, 
            _currentPosition!.longitude, 
            lat, 
            lng
          );
        } else {
          customer['distance'] = double.infinity;
        }
      } else {
        customer['distance'] = double.infinity;
      }
    }
    
    setState(() {
      _customers = customers;
      _isLoading = false;
    });
    
    _sortCustomers();
  }
  
  void _sortCustomers() {
    setState(() {
      _customers.sort((a, b) {
        // Calculate a priority score for each customer. Lower score = higher rank (closer to top).
        
        double getScore(dynamic customer) {
          double distanceScore = (customer['distance'] ?? double.infinity);
          if (distanceScore == double.infinity) distanceScore = 9999999;
          
          // Distance is in meters. Let's say 1 km = 1000 score.
          double score = distanceScore;
          
          // Time penalty: subtract from score for older visits
          if (customer['last_visit_date'] == null) {
            // Never visited: Huge priority boost (appear as if they are 50km closer)
            score -= 50000;
          } else {
            DateTime lastVisit = DateTime.tryParse(customer['last_visit_date'].toString()) ?? DateTime.now();
            int daysSinceVisit = DateTime.now().difference(lastVisit).inDays;
            
            // For every day since last visit, they appear 1km closer.
            score -= (daysSinceVisit * 1000); 
          }
          
          return score;
        }
        
        return getScore(a).compareTo(getScore(b));
      });
    });
  }

  Future<void> _openGoogleMaps(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن فتح خرائط جوجل')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('قائمة العملاء (الأقرب والأكثر احتياجاً للزيارة)', style: TextStyle(fontSize: 16)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCustomers,
              child: Column(
                children: [
                  Expanded(
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
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _customers.length,
                            itemBuilder: (context, index) {
                              final customer = _customers[index];
                              final bool hasLocation = customer['latitude'] != null && customer['longitude'] != null;
                              
                              String distanceText = '';
                              if (customer['distance'] != null && customer['distance'] != double.infinity) {
                                if (customer['distance'] < 1000) {
                                  distanceText = '${customer['distance'].toStringAsFixed(0)} متر';
                                } else {
                                  distanceText = '${(customer['distance'] / 1000).toStringAsFixed(1)} كم';
                                }
                              }
                              
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const CircleAvatar(
                                            backgroundColor: Colors.blue,
                                            child: Icon(Icons.store, color: Colors.white),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(customer['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                Text(customer['phone'] ?? 'لا يوجد رقم', style: TextStyle(color: Colors.grey[600])),
                                                if (distanceText.isNotEmpty)
                                                  Text('يبعد: $distanceText', style: const TextStyle(color: Colors.blue, fontSize: 12)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => VisitScreen(customer: customer),
                                                  ),
                                                ).then((_) => _loadCustomers());
                                              },
                                              icon: const Icon(Icons.check_circle_outline, size: 18),
                                              label: const Text('زيارة'),
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (hasLocation)
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () => _openGoogleMaps(
                                                  double.parse(customer['latitude'].toString()),
                                                  double.parse(customer['longitude'].toString())
                                                ),
                                                icon: const Icon(Icons.map, size: 18),
                                                label: const Text('الاتجاهات'),
                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                                              ),
                                            ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCustomerDialog(context),
        child: const Icon(Icons.person_add),
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('إضافة عميل جديد'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'اسم العميل / المحل'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                  keyboardType: TextInputType.phone,
                ),
                if (isSaving) const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: CircularProgressIndicator(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : () async {
                  if (nameController.text.trim().isEmpty) return;
                  setDialogState(() => isSaving = true);
                  
                  try {
                    // Try to get location, but don't fail if we can't
                    double? lat, lng;
                    try {
                      final position = await Geolocator.getCurrentPosition(
                          desiredAccuracy: LocationAccuracy.high);
                      lat = position.latitude;
                      lng = position.longitude;
                    } catch (e) {
                      debugPrint('Location error: $e');
                    }

                    final response = await ApiService.post('/customers', {
                      'name': nameController.text.trim(),
                      'phone': phoneController.text.trim(),
                      'latitude': lat,
                      'longitude': lng,
                    });

                    if (response['success'] == true && context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم تسجيل العميل بنجاح!')),
                      );
                      _loadCustomers(); // Refresh the list
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('حدث خطأ أثناء حفظ العميل')),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setDialogState(() => isSaving = false);
                    }
                  }
                },
                child: const Text('حفظ وتسجيل'),
              ),
            ],
          );
        });
      },
    );
  }
}
