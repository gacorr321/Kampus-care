import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  Future<String> getCurrentLocationName() async {
    // Cek permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return 'Lokasi tidak diizinkan';
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // 1. Coba fetch alamat dari geocoding package (Native Android/iOS)
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final addressParts = [
            place.street,
            place.subLocality,
            place.locality,
          ].where((e) => e != null && e.isNotEmpty).toList();
          
          if (addressParts.isNotEmpty) {
            return addressParts.join(', ');
          }
        }
      } catch (e) {
        // Jika geocoding native gagal (misal di Web), lanjut ke Nominatim
      }

      // 2. Coba fetch alamat dari Nominatim (Berguna untuk Web)
      try {
        final response = await http.get(
          Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1'),
          headers: {'User-Agent': 'KampusCareApp/1.0 (kampuscare@example.com)'},
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['display_name'] != null) {
            return data['display_name'];
          }
        }
      } catch (e) {
        // Fallback jika gagal fetch
      }

      // Format koordinat sebagai string lokasi jika geocoding gagal
      return 'Lat: ${position.latitude.toStringAsFixed(4)}, '
          'Lng: ${position.longitude.toStringAsFixed(4)}';
    } catch (e) {
      return 'Lokasi tidak tersedia';
    }
  }
}
