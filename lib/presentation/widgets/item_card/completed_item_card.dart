import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/item_model.dart';
import '../../../../data/services/location_service.dart';
import 'components/item_map_preview.dart';

class CompletedItemCard extends StatefulWidget {
  final ItemModel item;

  const CompletedItemCard({super.key, required this.item});

  @override
  State<CompletedItemCard> createState() => _CompletedItemCardState();
}

class _CompletedItemCardState extends State<CompletedItemCard> {
  ItemModel get item => widget.item;
  final LocationService _locationService = LocationService();

  /// Opens the map using GPS coordinates directly, or geocodes the address
  /// if GPS coordinates are missing.
  Future<void> _openMapForItem(BuildContext context) async {
    final hasMap = item.latitude != null && item.longitude != null;

    if (hasMap) {
      showItemMapPreview(
          context, item.locationName, item.latitude!, item.longitude!);
      return;
    }

    // No GPS coordinates — try to geocode the address
    if (item.locationName.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lokasi tidak tersedia untuk barang ini.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Show loading dialog while geocoding
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Mencari lokasi...'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final result = await _locationService.geocodeAddress(item.locationName);

    if (context.mounted) {
      // Close loading dialog
      Navigator.of(context).pop();

      if (result != null) {
        showItemMapPreview(context, item.locationName, result.lat, result.lng);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat menemukan lokasi pada peta.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13, color: Colors.grey[800]),
              children: [
                TextSpan(
                    text: label,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                TextSpan(
                    text: value,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Builds a tappable location row that opens the map when tapped.
  Widget _buildLocationRow(BuildContext context) {
    final hasMap = item.latitude != null && item.longitude != null;
    final hasLocation = hasMap || item.locationName.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          hasLocation ? Icons.location_on : Icons.location_off,
          size: 16,
          color: hasLocation ? AppColors.primary : Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openMapForItem(context),
            child: Text(
              'Lokasi ketemu: ${item.locationName}',
              style: TextStyle(
                fontSize: 13,
                color: hasLocation ? AppColors.primary : Colors.grey[800],
                fontWeight: FontWeight.w500,
                decoration: hasLocation
                    ? TextDecoration.underline
                    : TextDecoration.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProofImage(String? url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: url != null && url.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url,
              height: 100,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2))),
              errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.grey)),
            )
          : Container(
              height: 100,
              width: double.infinity,
              color: Colors.grey[200],
              child: const Center(
                  child: Text('Tidak ada',
                      style: TextStyle(color: Colors.grey, fontSize: 10))),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: item.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrl,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 180,
                          color: Colors.grey[200],
                          child:
                              const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 180,
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image,
                              size: 50, color: Colors.grey),
                        ),
                      )
                    : Container(
                        height: 180,
                        width: double.infinity,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported,
                            size: 50, color: Colors.grey),
                      ),
              ),
              const SizedBox(height: 16),
              Text(
                item.title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(),
              ),
              _buildDetailRow(
                  Icons.person, 'Ditemukan oleh: ', item.reportedByName),
              const SizedBox(height: 8),
              _buildDetailRow(Icons.person_outline, 'Dikembalikan ke: ',
                  item.claimerName ?? 'Tidak diketahui'),
              const SizedBox(height: 8),
              _buildLocationRow(context),
              const SizedBox(height: 8),
              if (item.incidentDate != null) ...[
                _buildDetailRow(
                    Icons.calendar_today_outlined,
                    item.status == 'hilang'
                        ? 'Tanggal hilang: '
                        : 'Tanggal ditemukan: ',
                    '${item.incidentDate!.day}/${item.incidentDate!.month}/${item.incidentDate!.year}'),
                const SizedBox(height: 8),
              ],
              _buildDetailRow(
                  Icons.calendar_today,
                  'Tanggal selesai: ',
                  item.returnedAt != null
                      ? '${item.returnedAt!.day}/${item.returnedAt!.month}/${item.returnedAt!.year}'
                      : '-'),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(),
              ),
              const Text(
                '📸 Bukti Serah Terima:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildProofImage(item.returnProofImageUrl),
                        const SizedBox(height: 4),
                        Text('Dari: ${item.reportedByName}',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        _buildProofImage(item.claimerProofImageUrl),
                        const SizedBox(height: 4),
                        Text('Dari: ${item.claimerName ?? "Pengklaim"}',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'TERVERIFIKASI',
                      style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
