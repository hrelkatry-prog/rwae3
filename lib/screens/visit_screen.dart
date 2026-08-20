import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rwae3_mobile/services/api_service.dart';
import 'package:rwae3_mobile/services/location_service.dart';
import 'package:rwae3_mobile/services/sync_service.dart';

class VisitScreen extends StatefulWidget {
  final Map<String, dynamic> customer;
  const VisitScreen({super.key, required this.customer});

  @override
  State<VisitScreen> createState() => _VisitScreenState();
}

class _VisitScreenState extends State<VisitScreen> {
  bool _isSuccessful = true;
  final _notesController = TextEditingController();
  XFile? _photo;
  final ImagePicker _picker = ImagePicker();
  
  Position? _currentPosition;
  double? _distance;
  bool _isCheckingLocation = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _checkLocation();
  }

  Future<void> _checkLocation() async {
    setState(() => _isCheckingLocation = true);
    final position = await LocationService.getCurrentLocation();
    
    if (position != null) {
      _currentPosition = position;
      final custLat = widget.customer['latitude'] != null ? double.tryParse(widget.customer['latitude'].toString()) : null;
      final custLng = widget.customer['longitude'] != null ? double.tryParse(widget.customer['longitude'].toString()) : null;

      if (custLat != null && custLng != null) {
        _distance = LocationService.calculateDistanceInMeters(
          position.latitude, position.longitude, custLat, custLng
        );
      } else {
        _distance = 0; // Customer has no location, allowed.
      }
    }
    
    setState(() => _isCheckingLocation = false);
  }

  Future<void> _takePhoto() async {
    final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (photo != null) {
      setState(() => _photo = photo);
    }
  }

  Future<void> _submitVisit() async {
    if (_photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى التقاط صورة للمحل')));
      return;
    }

    setState(() => _isSubmitting = true);
    
    try {
      final result = await ApiService.submitVisit(
        userId: 1, // Placeholder
        customerId: widget.customer['id'],
        lat: _currentPosition!.latitude,
        lng: _currentPosition!.longitude,
        isSuccessful: _isSuccessful,
        notes: _notesController.text,
        photo: _photo,
      );
      setState(() => _isSubmitting = false);

      if (result['success']) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الزيارة بنجاح')));
        }
      } else {
        throw Exception(result['error']);
      }
    } catch (e) {
      // If it failed, save it locally for auto-sync
      await SyncService.savePendingVisit({
        'user_id': 1,
        'customer_id': widget.customer['id'],
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'is_successful': _isSuccessful ? 1 : 0,
        'notes': _notesController.text,
        'photo_path': _photo!.path,
      });

      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم الحفظ في الهاتف مؤقتاً لعدم توفر إنترنت. ستتم المزامنة لاحقاً.'),
          backgroundColor: Colors.orange,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAllowed = _distance != null && _distance! <= 100;

    return Scaffold(
      appBar: AppBar(title: Text('زيارة: ${widget.customer['name']}')),
      body: _isCheckingLocation
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_distance != null && _distance! > 100)
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.red.shade100,
                      child: Text(
                        'أنت بعيد عن العميل بمسافة ${_distance!.toStringAsFixed(1)} متر. يجب أن تقترب لمسافة 100 متر على الأقل.',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  
                  const SizedBox(height: 20),
                  SwitchListTile(
                    title: const Text('حالة الزيارة (ناجحة أم لا)'),
                    value: _isSuccessful,
                    onChanged: (val) => setState(() => _isSuccessful = val),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات (أسباب عدم البيع أو غيره)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  
                  _photo != null
                      ? Image.file(File(_photo!.path), height: 200)
                      : ElevatedButton.icon(
                          onPressed: _takePhoto,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('التقاط صورة للمكان'),
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                        ),
                        
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: (isAllowed && !_isSubmitting) ? _submitVisit : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: isAllowed ? Colors.green : Colors.grey,
                    ),
                    child: _isSubmitting 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('حفظ الزيارة', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ],
              ),
            ),
    );
  }
}
