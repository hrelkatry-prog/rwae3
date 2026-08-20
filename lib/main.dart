import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rwae3_mobile/widgets/gps_enforcer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:rwae3_mobile/screens/login_screen.dart';
import 'package:rwae3_mobile/services/location_service.dart';
import 'package:rwae3_mobile/services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeBackgroundService();
  runApp(const MyApp());
}

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();
  
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'rwae3_tracking',
      initialNotificationTitle: 'Rwae3 Service',
      initialNotificationContent: 'Tracking location in background',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // This code runs in the background isolate
  
  Timer.periodic(const Duration(minutes: 3), (timer) async {
    // 1. Get current location
    final position = await LocationService.getCurrentLocation();
    
    // 2. Get user ID from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    
    if (position != null && userId != null) {
      // 3. Send to API
      await ApiService.sendTrackingData(
        userId: userId,
        lat: position.latitude,
        lng: position.longitude,
      );
    }
  });
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  return true;
}



class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rwae3 Mandoob',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: GpsEnforcer(child: child!),
        );
      },
      home: const LoginScreen(),
    );
  }
}
