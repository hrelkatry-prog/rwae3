import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class SyncService {
  static const String _pendingVisitsKey = 'pending_visits';

  static Future<void> savePendingVisit(Map<String, dynamic> visitData) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingVisitsStr = prefs.getString(_pendingVisitsKey) ?? '[]';
    final List<dynamic> pendingVisits = json.decode(pendingVisitsStr);
    
    // Add current timestamp as the client_time so the server knows exactly when it happened
    visitData['client_time'] = DateTime.now().toIso8601String();
    
    pendingVisits.add(visitData);
    await prefs.setString(_pendingVisitsKey, json.encode(pendingVisits));
    
    // Attempt to sync immediately just in case
    syncPendingVisits();
  }

  static Future<void> syncPendingVisits() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return; // No internet
    }

    final prefs = await SharedPreferences.getInstance();
    final pendingVisitsStr = prefs.getString(_pendingVisitsKey);
    if (pendingVisitsStr == null) return;

    final List<dynamic> pendingVisits = json.decode(pendingVisitsStr);
    if (pendingVisits.isEmpty) return;

    List<dynamic> remainingVisits = [];
    
    for (var visit in pendingVisits) {
      try {
        bool success = await _uploadVisit(visit);
        if (!success) {
          remainingVisits.add(visit); // Keep it if upload failed
        }
      } catch (e) {
        remainingVisits.add(visit);
      }
    }

    // Save only the ones that failed to upload
    await prefs.setString(_pendingVisitsKey, json.encode(remainingVisits));
  }

  static Future<bool> _uploadVisit(Map<String, dynamic> visitData) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token == null) return false;

    var request = http.MultipartRequest('POST', Uri.parse('${ApiService.baseUrl}/visits'));
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    request.fields['customer_id'] = visitData['customer_id'].toString();
    request.fields['user_id'] = visitData['user_id'].toString();
    request.fields['latitude'] = visitData['latitude'].toString();
    request.fields['longitude'] = visitData['longitude'].toString();
    request.fields['is_successful'] = visitData['is_successful'].toString();
    request.fields['client_time'] = visitData['client_time'].toString();
    
    if (visitData['notes'] != null) {
      request.fields['notes'] = visitData['notes'];
    }

    if (visitData['photo_path'] != null) {
      request.files.add(await http.MultipartFile.fromPath('photo', visitData['photo_path']));
    }

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    
    return response.statusCode == 201;
  }
}
