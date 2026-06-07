import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';

class PinBottomSheet extends StatefulWidget {
  final String pin;
  final DateTime expiredAt;
  final String reportedByName;
  final String reportedByPhone;
  final String itemTitle;
  final bool isHilang;

  const PinBottomSheet({
    super.key,
    required this.pin,
    required this.expiredAt,
    required this.reportedByName,
    required this.reportedByPhone,
    required this.itemTitle,
    required this.isHilang,
  });

  @override
  State<PinBottomSheet> createState() => _PinBottomSheetState();
}

class _PinBottomSheetState extends State<PinBottomSheet> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.expiredAt.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _remaining = widget.expiredAt.difference(DateTime.now());
        if (_remaining.isNegative) {
          _remaining = Duration.zero;
          _timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _formattedTimer {
    final h = _remaining.inHours.toString().padLeft(2, '0');
    final m = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _openWhatsApp() async {
    try {
      String phone = widget.reportedByPhone.replaceAll(RegExp(r'\D'), '');
      if (phone.startsWith('0')) phone = '62${phone.substring(1)}';

      final message = widget.isHilang
          ? 'Halo ${widget.reportedByName}, saya menemukan barang ${widget.itemTitle} milikmu. Saya sudah memiliki kode pengembalian di aplikasi. Bisa kita atur waktu untuk bertemu? Terima kasih 🙏'
          : 'Halo ${widget.reportedByName}, saya adalah pemilik ${widget.itemTitle} yang kamu temukan. Saya sudah memiliki kode konfirmasi pengembalian. Bisa kita atur waktu dan tempat untuk pengambilan barang? Terima kasih 🙏';

      final url = Uri.parse(
        'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
      );

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak dapat membuka WhatsApp. Pastikan aplikasi terpasang.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = _remaining == Duration.zero;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '🔐 Kode Konfirmasi Kamu',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Sebutkan kode ini ke penemu saat kalian\nketemu langsung.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: widget.pin
                .split('')
                .map(
                  (digit) => Container(
                    width: 56,
                    height: 64,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      digit,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Text(
              isExpired
                  ? '⏱ Kode sudah kadaluarsa'
                  : '⏱ Berlaku: $_formattedTimer',
              style: TextStyle(
                color: isExpired ? Colors.red[700] : Colors.orange[800],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('⚠️ ', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: Text(
                    'Jangan kirim kode ini via WhatsApp atau chat. '
                    'Kode hanya disebutkan langsung saat bertemu penemu.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.deepOrange,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isExpired ? Colors.grey : const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: isExpired ? null : _openWhatsApp,
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: Text(
                'Lanjut Chat ke ${widget.reportedByName} di WA',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tutup', style: TextStyle(color: Colors.grey[500])),
          ),
        ],
      ),
    );
  }
}
