import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://r.rseha.com/api'; // Replace with real server IP in production

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> login({required String phone, required String password}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'phone': phone,
          'password': password,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: ${e.toString()}'};
    }
  }

  static Future<bool> sendTrackingData({required int userId, required double lat, required double lng}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/tracking'),
        headers: headers,
        body: jsonEncode({
          'user_id': userId,
          'latitude': lat,
          'longitude': lng,
          'battery_level': '100%',
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  static Future<List<dynamic>> fetchCustomers() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/customers'), headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> submitVisit({
    required int userId,
    required int customerId,
    required double lat,
    required double lng,
    required bool isSuccessful,
    String? notes,
    XFile? photo,
  }) async {
    try {
      final headers = await _getHeaders();
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/visits'));
      request.headers.addAll(headers);
      request.fields['user_id'] = userId.toString();
      request.fields['customer_id'] = customerId.toString();
      request.fields['latitude'] = lat.toString();
      request.fields['longitude'] = lng.toString();
      request.fields['is_successful'] = isSuccessful ? '1' : '0';
      
      if (notes != null && notes.isNotEmpty) {
        request.fields['notes'] = notes;
      }

      if (photo != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'photo',
            photo.path,
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': jsonDecode(response.body)};
      }
    } catch (e) {
      return {'success': false, 'error': {'message': e.toString()}};
    }
  }

  static Future<dynamic> get(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl$endpoint'), headers: headers);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
