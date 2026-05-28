import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

class ApiClient {
  /// Base endpoint URL for the Django server.
  /// NOTE: For Android Emulator development, replace 'localhost' with '10.0.2.2'.

  // static const String baseUrl = 'http://localhost:8000';
  static const String baseUrl = 'http://10.0.2.2:8000';

  /// Fetches all active audio projects and their nested stem configurations.
  Future<List<dynamic>> fetchProjects() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/projects/'));
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      } else {
        throw Exception('Failed to load projects: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network connection error: $e');
    }
  }

  /// Uploads a new song project with multiple stem files.
  /// Uses a multipart/form-data request format.
  Future<Map<String, dynamic>> uploadProject(
      String title, List<PlatformFile> files) async {
    try {
      final uri = Uri.parse('$baseUrl/api/projects/');
      final request = http.MultipartRequest('POST', uri);

      // Populate text fields
      request.fields['title'] = title;

      // Populate audio stem files
      for (final file in files) {
        if (file.bytes != null) {
          // Supports Flutter Web or memory-buffered uploads
          request.files.add(
            http.MultipartFile.fromBytes(
              'files',
              file.bytes!,
              filename: file.name,
            ),
          );
        } else if (file.path != null) {
          // Supports standard Native Android/iOS/Desktop file system paths
          request.files.add(
            await http.MultipartFile.fromPath(
              'files',
              file.path!,
              filename: file.name,
            ),
          );
        } else {
          throw Exception(
              'File metadata is missing both path and byte content.');
        }
      }

      // Dispatch request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        return jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
      } else {
        final Map<String, dynamic> errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error'] ??
            'Server returned error ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Upload transaction failed: $e');
    }
  }
}
