import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/item_model.dart';
import '../../../../data/services/camera_service.dart';
import '../../../providers/item_provider.dart';
import '../../../providers/notification_provider.dart';

class UploadClaimerProofSheet extends StatefulWidget {
  final ItemModel item;

  const UploadClaimerProofSheet({super.key, required this.item});

  @override
  State<UploadClaimerProofSheet> createState() => _UploadClaimerProofSheetState();
}

class _UploadClaimerProofSheetState extends State<UploadClaimerProofSheet> {
  final _cameraService = CameraService();
  File? _imageFile;
  Uint8List? _imageBytes;
  bool _isUploading = false;
  bool _isProcessing = false;
  String? _uploadedImageUrl;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1280,
      );
      if (picked == null) return;

      setState(() {
        _isUploading = true;
        _uploadedImageUrl = null;
      });

      String url;
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() => _imageBytes = bytes);
        url = await _cameraService.uploadBytes(bytes);
      } else {
        final file = File(picked.path);
        setState(() => _imageFile = file);
        url = await _cameraService.uploadPhoto(file);
      }

      setState(() {
        _uploadedImageUrl = url;
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal upload foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Kamera', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.orange),
              title: const Text('Galeri', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_uploadedImageUrl == null) return;

    setState(() => _isProcessing = true);
    try {
      final itemProvider = context.read<ItemProvider>();
      final notifProvider = context.read<NotificationProvider>();

      await itemProvider.completeReturn(widget.item.id, _uploadedImageUrl!);

      await notifProvider.sendNotification(
        targetUserId: widget.item.reportedBy,
        title: 'Proses Selesai ✅',
        body: 'Pengklaim telah mengunggah bukti terima. Kasus barang ${widget.item.title} telah SELESAI.',
        relatedItemId: widget.item.id,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bukti berhasil dikirim. Proses selesai! ✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyelesaikan proses: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Center(
            child: Text(
              'Upload Bukti Terima',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Silakan upload foto barang sebagai bukti bahwa Anda sudah menerimanya kembali.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _isUploading || _isProcessing ? null : _showImageSourceSheet,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _uploadedImageUrl != null ? Colors.transparent : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _uploadedImageUrl != null
                      ? Colors.green.withValues(alpha: 0.6)
                      : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: _isUploading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _uploadedImageUrl != null
                      ? (kIsWeb && _imageBytes != null
                          ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                          : (_imageFile != null
                              ? Image.file(_imageFile!, fit: BoxFit.cover)
                              : const SizedBox()))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined, size: 40, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'Tap untuk pilih foto',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
            ),
          ),
          if (_uploadedImageUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: TextButton.icon(
                  onPressed: _showImageSourceSheet,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Ganti Foto'),
                ),
              ),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _uploadedImageUrl != null && !_isProcessing ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF198754),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle, size: 20),
              label: Text(
                _isProcessing ? 'Memproses...' : 'Selesaikan Proses',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
