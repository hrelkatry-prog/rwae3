import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class GpsEnforcer extends StatefulWidget {
  final Widget child;

  const GpsEnforcer({super.key, required this.child});

  @override
  State<GpsEnforcer> createState() => _GpsEnforcerState();
}

class _GpsEnforcerState extends State<GpsEnforcer> {
  bool _isGpsEnabled = true;
  StreamSubscription<ServiceStatus>? _serviceStatusStreamSubscription;

  @override
  void initState() {
    super.initState();
    _checkInitialGpsStatus();
    _listenToGpsStatus();
  }

  Future<void> _checkInitialGpsStatus() async {
    bool isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    setState(() {
      _isGpsEnabled = isLocationServiceEnabled;
    });
  }

  void _listenToGpsStatus() {
    _serviceStatusStreamSubscription = Geolocator.getServiceStatusStream().listen(
      (ServiceStatus status) {
        setState(() {
          _isGpsEnabled = status == ServiceStatus.enabled;
        });
      },
    );
  }

  @override
  void dispose() {
    _serviceStatusStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_isGpsEnabled)
          Positioned.fill(
            child: Container(
              color: Colors.white, // Full opaque white overlay
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.location_off_rounded,
                        size: 100,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "تنبيه هام",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40.0),
                        child: Text(
                          "يجب تشغيل خدمة الموقع (GPS) لتتمكن من استخدام التطبيق. لا يمكن المتابعة حتى تقوم بتشغيلها.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton.icon(
                        onPressed: () {
                          Geolocator.openLocationSettings();
                        },
                        icon: const Icon(Icons.settings),
                        label: const Text("تفعيل الـ GPS الآن"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
