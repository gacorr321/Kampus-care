import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/item_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/item_provider.dart';
import '../../providers/notification_provider.dart';
import 'components/item_map_preview.dart';
import 'components/pin_bottom_sheet.dart';
import 'components/upload_claimer_proof_sheet.dart';
import 'components/claim_wizard_sheet.dart';

class ActiveItemCard extends StatefulWidget {
  final ItemModel item;
  final bool showActionButton;

  const ActiveItemCard({
    super.key,
    required this.item,
    this.showActionButton = true,
  });

  @override
  State<ActiveItemCard> createState() => _ActiveItemCardState();
}

class _ActiveItemCardState extends State<ActiveItemCard> {
  ItemModel get item => widget.item;

  Future<void> _processClaim(BuildContext context, bool isHilang) async {
    final authProvider = context.read<AuthProvider>();
    final notifProvider = context.read<NotificationProvider>();
    final itemProvider = context.read<ItemProvider>();

    try {
      final claimResult = await itemProvider.claimItem(
        item: item,
        claimerId: authProvider.user!.uid,
        claimerName: authProvider.user!.name,
      );

      final pin = claimResult['pin'] as String;
      final expiredAt = claimResult['expiredAt'] as DateTime;
      final isHilangFlag = claimResult['isHilang'] as bool;

      await notifProvider.sendNotification(
        targetUserId: item.reportedBy,
        title: isHilangFlag ? 'Barang Anda Ditemukan!' : 'Seseorang Mengklaim Barang Anda!',
        body: '${authProvider.user!.name} merespons laporan ${item.title}. Siap-siap untuk dihubungi via WA.',
        relatedItemId: item.id,
      );

      if (context.mounted) {
        _showPinBottomSheet(context, pin, expiredAt, isHilangFlag);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memproses klaim: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow; // Biar ditangkap oleh ClaimWizardSheet
    }
  }

  void _handleKlaimBarang(BuildContext context, bool isHilang) {
    final authProvider = context.read<AuthProvider>();

    if (authProvider.user?.uid == item.reportedBy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda tidak dapat mengklaim barang yang Anda laporkan sendiri.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClaimWizardSheet(
        item: item,
        onClaimSubmit: (submitCtx, submitIsHilang) => _processClaim(submitCtx, submitIsHilang),
      ),
    );
  }

  void _showPinBottomSheet(BuildContext context, String pin, DateTime expiredAt, bool isHilang) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => PinBottomSheet(
        pin: pin,
        expiredAt: expiredAt,
        reportedByName: item.reportedByName,
        reportedByPhone: item.reportedByPhone,
        itemTitle: item.title,
        isHilang: isHilang,
      ),
    );
  }

  Widget _buildProgressStepper() {
    int currentStep = 0;
    if (widget.item.claimedBy != null) currentStep = 1;
    if (widget.item.status == 'menunggu_bukti_pengklaim') currentStep = 2;
    if (widget.item.status == 'dikembalikan') currentStep = 3;

    final steps = ['Dilaporkan', 'Aktif', 'Menunggu', 'Selesai'];

    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status Proses:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(steps.length, (index) {
              final isCompleted = index <= currentStep;
              final isLast = index == steps.length - 1;
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCompleted ? AppColors.primary : Colors.grey[300],
                            ),
                            child: isCompleted
                                ? const Icon(Icons.check, size: 12, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            steps[index],
                            style: TextStyle(
                              fontSize: 10,
                              color: isCompleted ? AppColors.primary : Colors.grey[500],
                              fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.visible,
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        flex: 3,
                        child: Container(
                          height: 2,
                          color: index < currentStep ? AppColors.primary : Colors.grey[300],
                          margin: const EdgeInsets.only(bottom: 20),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHilang = item.status == 'hilang';
    final isDikembalikan = item.status == 'dikembalikan';
    final hasMap = item.latitude != null && item.longitude != null;
    final currentUserId = context.watch<AuthProvider>().user?.uid;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          if (hasMap) {
            showItemMapPreview(context, item.locationName, item.latitude!, item.longitude!);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Lokasi spesifik pada peta tidak tersedia untuk barang ini.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: item.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: item.imageUrl,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              height: 180,
                              color: Colors.grey[100],
                              child: const Center(
                                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              height: 180,
                              color: Colors.grey[100],
                              child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                            ),
                          )
                        : Container(
                            height: 180,
                            color: Colors.grey[100],
                            child: const Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey),
                          ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDikembalikan
                                ? Colors.blue.withValues(alpha: 0.75)
                                : (isHilang
                                    ? Colors.red.withValues(alpha: 0.75)
                                    : Colors.green.withValues(alpha: 0.75)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isDikembalikan
                                    ? Icons.verified
                                    : (isHilang ? Icons.search : Icons.check_circle),
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isDikembalikan ? 'Selesai' : (isHilang ? 'Hilang' : 'Ditemukan'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item.category,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          hasMap ? Icons.location_on : Icons.location_off,
                          size: 16,
                          color: hasMap ? AppColors.primary : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: hasMap ? () => showItemMapPreview(context, item.locationName, item.latitude!, item.longitude!) : null,
                            child: Text(
                              item.locationName,
                              style: TextStyle(
                                color: hasMap ? AppColors.primary : Colors.grey,
                                fontSize: 12,
                                decoration: hasMap ? TextDecoration.underline : TextDecoration.none,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            item.reportedByName,
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (item.incidentDate != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${isHilang ? "Hilang" : "Ditemukan"} pd: ${item.incidentDate!.day}/${item.incidentDate!.month}/${item.incidentDate!.year}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                    _buildProgressStepper(),
                    if (widget.showActionButton &&
                        item.reportedByPhone.isNotEmpty &&
                        !isDikembalikan &&
                        currentUserId != item.reportedBy &&
                        item.status != 'menunggu_bukti_pengklaim') ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.1),
                            foregroundColor: const Color(0xFF1DA851),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: const Color(0xFF1DA851).withValues(alpha: 0.3)),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () => _handleKlaimBarang(context, isHilang),
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          label: const Text('Klaim Barang Ini', style: TextStyle(fontSize: 14)),
                        ),
                      ),
                    ],
                    if (widget.showActionButton &&
                        item.status == 'menunggu_bukti_pengklaim' &&
                        currentUserId == item.claimedBy) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.withValues(alpha: 0.1),
                            foregroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                              ),
                              builder: (ctx) => UploadClaimerProofSheet(item: item),
                            );
                          },
                          icon: const Icon(Icons.camera_alt_outlined, size: 18),
                          label: const Text(
                            'Upload Bukti Terima',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
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
