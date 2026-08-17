import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8000/api'; // Replace with real server IP in production

  static Future<bool> sendTrackingData({required int userId, required double lat, required double lng}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tracking'),
        headers: {'Content-Type': 'application/json'},
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
      final response = await http.get(Uri.parse('$baseUrl/customers'));
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
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/visits'));
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
}
