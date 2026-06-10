import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';

/// Opens the full-screen map preview for an item's location.
void showItemMapPreview(
    BuildContext context, String locationName, double lat, double lng) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => MapPreviewScreen(
        locationName: locationName,
        latitude: lat,
        longitude: lng,
      ),
    ),
  );
}

/// Full-screen OpenStreetMap page showing an item's exact location.
class MapPreviewScreen extends StatefulWidget {
  final String locationName;
  final double latitude;
  final double longitude;

  const MapPreviewScreen({
    super.key,
    required this.locationName,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<MapPreviewScreen> createState() => _MapPreviewScreenState();
}

class _MapPreviewScreenState extends State<MapPreviewScreen> {
  late final MapController _mapController;
  late final LatLng _location;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _location = LatLng(widget.latitude, widget.longitude);
  }

  Future<void> _openInGoogleMaps() async {
    // Try Google Maps directions intent first (works on Android/iOS)
    final gmapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${widget.latitude},${widget.longitude}',
    );

    if (await canLaunchUrl(gmapsUrl)) {
      await launchUrl(gmapsUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka Google Maps.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  void _recenter() {
    _mapController.move(_location, 16.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Full-screen Map ──────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _location,
              initialZoom: 16.0,
              minZoom: 3.0,
              maxZoom: 19.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.kampus_care',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _location,
                    width: 50,
                    height: 50,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 50,
                      shadows: [Shadow(color: Colors.black26, blurRadius: 6)],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── Top bar (gradient + back + title) ───────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  children: [
                    // Back button
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppColors.textPrimary,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    // Location name
                    const Icon(Icons.location_on,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.locationName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Zoom controls (right side) ──────────────────────────────────
          Positioned(
            right: 12,
            top: MediaQuery.of(context).size.height * 0.40,
            child: SafeArea(
              child: Column(
                children: [
                  _buildMapButton(Icons.add, _zoomIn),
                  const SizedBox(height: 8),
                  _buildMapButton(Icons.remove, _zoomOut),
                  const SizedBox(height: 8),
                  _buildMapButton(Icons.my_location, _recenter),
                ],
              ),
            ),
          ),

          // ── Bottom action bar ───────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Coordinates info
                    Row(
                      children: [
                        const Icon(Icons.explore,
                            size: 14, color: AppColors.textLight),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.latitude.toStringAsFixed(6)}, ${widget.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Open in Google Maps button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4285F4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _openInGoogleMaps,
                        icon: const Icon(Icons.navigation, size: 18),
                        label: const Text(
                          'Buka di Google Maps',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
