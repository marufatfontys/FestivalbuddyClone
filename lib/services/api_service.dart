import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/festival_models.dart';

class ApiService {
  /// Live Vercel REST API URL connected to Turso Cloud SQLite
  static const String cloudApiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://festivalbuddy-seven.vercel.app',
  );

  // Configured dynamically:
  // - On Web in production (Vercel): uses the same Vercel domain automatically (Uri.base.origin)
  // - On Web locally (localhost): uses http://localhost:3000
  // - On iPhone / Mobile: uses cloudApiUrl
  static String get baseUrl {
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host != 'localhost' && host != '127.0.0.1' && host.isNotEmpty) {
        return Uri.base.origin;
      }
      return 'http://localhost:3000';
    }
    return cloudApiUrl;
  }

  /// Uploads a file (banner image, profile picture) to the SQLite Node server
  /// Returns the public network URL of the uploaded image
  static Future<String?> uploadImage(String filePath) async {
    try {
      final uri = Uri.parse('$baseUrl/api/upload');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      
      final streamedResponse = await request.send().timeout(const Duration(seconds: 8));
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['url'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Fetches all festivals from the SQLite backend database
  static Future<List<Festival>> fetchFestivals() async {
    try {
      final uri = Uri.parse('$baseUrl/api/festivals');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
        return list.map((json) => Festival.fromJson(json as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Syncs/Publishes a festival to the SQLite backend database
  static Future<bool> publishFestival(Festival festival) async {
    try {
      final uri = Uri.parse('$baseUrl/api/festivals');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(festival.toJson()),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Updates an existing festival in the backend database
  static Future<bool> updateFestival(String festivalId, Map<String, dynamic> updateData) async {
    try {
      final uri = Uri.parse('$baseUrl/api/festivals/$festivalId');
      final response = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updateData),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Deletes a festival from the backend database
  static Future<bool> deleteFestival(String festivalId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/festivals/$festivalId');
      final response = await http.delete(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetches registered organizers for admin review
  static Future<List<Map<String, dynamic>>> fetchOrganizers() async {
    try {
      final uri = Uri.parse('$baseUrl/api/organizers');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
        return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Approves or rejects an organizer account
  static Future<bool> approveOrganizer(String email, {required bool approved, String? statusNote}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/organizers/$email/approve');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'approved': approved,
          'statusNote': statusNote,
        }),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Registers an organizer account to the backend database (`pending_organizer_accounts`)
  static Future<bool> registerOrganizer(Map<String, dynamic> organizerData) async {
    try {
      final uri = Uri.parse('$baseUrl/api/organizers/register');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(organizerData),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Registers or updates a visitor account in `visitor_accounts` database
  static Future<bool> registerVisitor(Map<String, dynamic> visitorData) async {
    try {
      final uri = Uri.parse('$baseUrl/api/visitors/register');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(visitorData),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Fetches registered visitors from `visitor_accounts` database
  static Future<List<Map<String, dynamic>>> fetchVisitors() async {
    try {
      final uri = Uri.parse('$baseUrl/api/visitors');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
        return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Fetches active system announcements
  static Future<List<SystemAnnouncement>> fetchAnnouncements() async {
    try {
      final uri = Uri.parse('$baseUrl/api/announcements');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
        return list.map((json) => SystemAnnouncement.fromJson(json as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Publishes a system announcement
  static Future<bool> publishAnnouncement(SystemAnnouncement announcement) async {
    try {
      final uri = Uri.parse('$baseUrl/api/announcements');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(announcement.toJson()),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Deletes a system announcement
  static Future<bool> deleteAnnouncement(String id) async {
    try {
      final uri = Uri.parse('$baseUrl/api/announcements/$id');
      final response = await http.delete(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
