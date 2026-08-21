import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rwae3_mobile/screens/main_screen.dart';
import 'package:rwae3_mobile/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkSavedCredentials();
  }

  Future<void> _checkSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    
    if (rememberMe) {
      final token = prefs.getString('auth_token');
      if (token != null && mounted) {
        // Request permissions before starting service on auto-login
        bool permissionsGranted = await _requestPermissions();
        if (permissionsGranted) {
          FlutterBackgroundService().startService();
        }
        
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        }
      }
    } else {
      // Clear token if we shouldn't remember the user
      await prefs.remove('auth_token');
    }
  }

  Future<bool> _requestPermissions() async {
    // 1. Request Notifications (Android 13+)
    await Permission.notification.request();

    // 2. Request Foreground Location
    var locationStatus = await Permission.location.request();
    if (!locationStatus.isGranted) {
      return false;
    }

    // 3. Request Background Location (Required for background service)
    var bgLocationStatus = await Permission.locationAlways.request();
    if (!bgLocationStatus.isGranted) {
      // We can still try to start, but background tracking might fail
    }

    return true;
  }

  void _login() async {
    if (_phoneController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = "الرجاء إدخال رقم الهاتف وكلمة المرور");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await ApiService.login(
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
    );

    if (response['success'] == true) {
      final prefs = await SharedPreferences.getInstance();
      
      // Always save token for the current session so API calls work
      await prefs.setString('auth_token', response['token']);
      // Save remember me preference for next app launch
      await prefs.setBool('remember_me', _rememberMe);
      
      // Save user details for tracking and session
      if (response['user'] != null) {
        await prefs.setInt('user_id', response['user']['id']);
        await prefs.setString('user_name', response['user']['name'] ?? '');
        await prefs.setString('user_phone', response['user']['phone'] ?? '');
      }

      // Request permissions before starting service
      bool permissionsGranted = await _requestPermissions();

      if (permissionsGranted) {
        // Start the background tracking service
        FlutterBackgroundService().startService();

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يجب الموافقة على صلاحيات الموقع لكي تتمكن من الدخول للتطبيق'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = response['message'] ?? "حدث خطأ غير معروف";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on, size: 80, color: Colors.blue),
                  const SizedBox(height: 16),
                  const Text('روائع الصحة', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const Text('تطبيق تتبع المناديب', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 48),
                  
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),

                  TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف', 
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور', 
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                      ),
                      const Text('تذكرني (تسجيل الدخول التلقائي)'),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('تسجيل الدخول', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
