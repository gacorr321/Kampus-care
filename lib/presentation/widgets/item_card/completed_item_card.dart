import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/item_model.dart';

class CompletedItemCard extends StatelessWidget {
  final ItemModel item;

  const CompletedItemCard({super.key, required this.item});

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
                TextSpan(text: label, style: const TextStyle(fontWeight: FontWeight.w500)),
                TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
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
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
              errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.grey)),
            )
          : Container(
              height: 100,
              width: double.infinity,
              color: Colors.grey[200],
              child: const Center(
                  child: Text('Tidak ada', style: TextStyle(color: Colors.grey, fontSize: 10))),
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
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 180,
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                      ),
                    )
                  : Container(
                      height: 180,
                      width: double.infinity,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              item.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(),
            ),
            _buildDetailRow(Icons.person, 'Ditemukan oleh: ', item.reportedByName),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.person_outline, 'Dikembalikan ke: ', item.claimerName ?? 'Tidak diketahui'),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.location_on, 'Lokasi ketemu: ', item.locationName),
            const SizedBox(height: 8),
            if (item.incidentDate != null) ...[
              _buildDetailRow(
                  Icons.calendar_today_outlined,
                  item.status == 'hilang' ? 'Tanggal hilang: ' : 'Tanggal ditemukan: ',
                  '${item.incidentDate!.day}/${item.incidentDate!.month}/${item.incidentDate!.year}'
              ),
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
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
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
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
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
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
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
