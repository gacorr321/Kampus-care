import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CameraService {
  final ImagePicker _picker = ImagePicker();

  // Konfigurasi Cloudinary
  static String get _cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static String get _uploadPreset => dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';
  static String get _uploadUrl =>
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  // Ambil foto dari kamera
  Future<File?> takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (photo == null) return null;
    return File(photo.path);
  }

  // Ambil foto dari galeri
  Future<File?> pickFromGallery() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (photo == null) return null;
    return File(photo.path);
  }

  // Upload dari File (Android/iOS)
  Future<String> uploadPhoto(File imageFile) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
      request.fields['upload_preset'] = _uploadPreset;
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          filename: 'img_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      final response = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception(
              'Upload timeout. Periksa koneksi internet atau coba gambar yang lebih kecil.');
        },
      );

      final responseBody = await response.stream.bytesToString();
      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        return data['secure_url'] as String;
      } else {
        final error = jsonDecode(responseBody);
        throw Exception('Upload gagal: ${error['error']?['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Gagal upload foto: $e');
    }
  }

  // Upload dari Bytes (Web)
  Future<String> uploadBytes(Uint8List bytes) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
      request.fields['upload_preset'] = _uploadPreset;
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'img_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      final response = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception(
              'Upload timeout. Periksa koneksi internet atau coba gambar yang lebih kecil.');
        },
      );

      final responseBody = await response.stream.bytesToString();
      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        return data['secure_url'] as String;
      } else {
        final error = jsonDecode(responseBody);
        throw Exception('Upload gagal: ${error['error']?['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Gagal upload foto: $e');
    }
  }
}
