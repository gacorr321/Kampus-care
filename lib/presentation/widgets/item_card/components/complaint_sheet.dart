import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/complaint_model.dart';
import '../../../../data/models/item_model.dart';
import '../../../../data/repositories/complaint_repository.dart';
import '../../../../data/services/camera_service.dart';

/// Opens the complaint (aduan) bottom sheet for a given [item].
void showComplaintSheet(BuildContext context, ItemModel item) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ComplaintSheet(item: item),
  );
}

class ComplaintSheet extends StatefulWidget {
  final ItemModel item;

  const ComplaintSheet({super.key, required this.item});

  @override
  State<ComplaintSheet> createState() => _ComplaintSheetState();
}

class _ComplaintSheetState extends State<ComplaintSheet> {
  final _formKey = GlobalKey<FormState>();
  final _ownerNameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  final _cameraService = CameraService();
  final _repo = ComplaintRepository();

  /// List of picked local file paths (non-web) paired with their Cloudinary URLs.
  final List<_PhotoEntry> _photos = [];

  bool _isSubmitting = false;

  @override
  void dispose() {
    _ownerNameCtrl.dispose();
    _contactCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────── Photo handling ──────────────────────────────

  void _showPickerSheet() {
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
            const SizedBox(height: 8),
            ListTile(
              leading:
                  const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: const Text('Kamera',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _pickImages(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: Colors.orange),
              title: const Text('Galeri (bisa pilih banyak)',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _pickImages(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImages(ImageSource source) async {
    try {
      final picker = ImagePicker();
      List<XFile> picked = [];

      if (source == ImageSource.gallery) {
        picked = await picker.pickMultiImage(imageQuality: 75, maxWidth: 1280);
      } else {
        final single = await picker.pickImage(
            source: ImageSource.camera, imageQuality: 75, maxWidth: 1280);
        if (single != null) picked = [single];
      }

      if (picked.isEmpty) return;

      // Add placeholder entries so the user sees progress immediately
      final entries = picked
          .map((_) => _PhotoEntry(file: null, uploading: true))
          .toList();
      setState(() => _photos.addAll(entries));

      // Upload each photo concurrently
      final futures = List.generate(picked.length, (i) async {
        try {
          String url;
          if (kIsWeb) {
            final bytes = await picked[i].readAsBytes();
            url = await _cameraService.uploadBytes(bytes);
            entries[i]
              ..bytes = bytes
              ..cloudUrl = url
              ..uploading = false;
          } else {
            final file = File(picked[i].path);
            url = await _cameraService.uploadPhoto(file);
            entries[i]
              ..file = file
              ..cloudUrl = url
              ..uploading = false;
          }
        } catch (e) {
          entries[i]
            ..uploading = false
            ..error = true;
        }
        if (mounted) setState(() {});
      });

      await Future.wait(futures);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal memilih foto: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  // ─────────────────────────── Submit ──────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if any photo is still uploading
    final stillUploading = _photos.any((p) => p.uploading);
    if (stillUploading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tunggu hingga semua foto selesai diupload.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final uploadedUrls =
          _photos.where((p) => p.cloudUrl != null).map((p) => p.cloudUrl!).toList();

      final complaint = ComplaintModel(
        id: 'complaint_${DateTime.now().millisecondsSinceEpoch}',
        reportId: widget.item.id,
        ownerName: _ownerNameCtrl.text.trim(),
        ownerContact: _contactCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        proofImageUrls: uploadedUrls,
        submittedAt: DateTime.now(),
      );

      await _repo.submitComplaint(complaint);

      if (mounted) {
        Navigator.pop(context);
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal mengirim aduan: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_read_rounded,
                    size: 38, color: Color(0xFF1565C0)),
              ),
              const SizedBox(height: 20),
              const Text(
                'Aduan Terkirim!',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E)),
              ),
              const SizedBox(height: 12),
              const Text(
                'Aduanmu telah terkirim ke admin. Kami akan segera meninjau laporanmu.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Oke, Mengerti',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── Build ───────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF57C00).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFF57C00), size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Laporkan Aduan',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark),
                    ),
                    Text(
                      'Klaim kepemilikan barang ini',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Divider(height: 1),
          ),

          // Scrollable form body
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Nama pemilik asli ─────────────────────────────────
                    _label('Nama Pemilik Asli', required: true),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _ownerNameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDeco(
                        hint: 'Masukkan nama lengkap Anda',
                        icon: Icons.person_outline_rounded,
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),

                    // ── Nomor kontak ──────────────────────────────────────
                    _label('Nomor Kontak', required: true),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _contactCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDeco(
                        hint: 'Contoh: 08123456789',
                        icon: Icons.phone_outlined,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Nomor kontak wajib diisi';
                        }
                        if (v.trim().length < 8) {
                          return 'Nomor kontak tidak valid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Keterangan aduan ──────────────────────────────────
                    _label('Keterangan Aduan', required: true),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 4,
                      minLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDeco(
                        hint:
                            'Jelaskan mengapa kamu adalah pemilik asli barang ini...',
                        icon: Icons.description_outlined,
                        alignIconTop: true,
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Keterangan wajib diisi'
                              : null,
                    ),
                    const SizedBox(height: 16),

                    // ── Foto bukti ────────────────────────────────────────
                    Row(
                      children: [
                        _label('Foto Bukti Kepemilikan', required: false),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Dianjurkan',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tambahkan foto untuk memperkuat aduan Anda',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 10),
                    _buildPhotoGrid(),
                    const SizedBox(height: 28),

                    // ── Buttons ───────────────────────────────────────────
                    Row(
                      children: [
                        // Batal
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              side: const BorderSide(color: AppColors.border),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Batal',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Kirim
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1565C0),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.send_rounded, size: 18),
                            label: Text(
                              _isSubmitting ? 'Mengirim...' : 'Kirim Aduan',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _label(String text, {bool required = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
        ),
        if (required) ...[
          const SizedBox(width: 3),
          const Text('*',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ],
      ],
    );
  }

  InputDecoration _inputDeco({
    required String hint,
    required IconData icon,
    bool alignIconTop = false,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
      filled: true,
      fillColor: AppColors.surfaceVariant,
      prefixIcon: Padding(
        padding: EdgeInsets.only(top: alignIconTop ? 12 : 0),
        child: Icon(icon, size: 20, color: AppColors.textLight),
      ),
      prefixIconConstraints:
          const BoxConstraints(minWidth: 48, minHeight: 48),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(0xFF1565C0), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  Widget _buildPhotoGrid() {
    const double tileSize = 90;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        // Existing photo tiles
        ..._photos.asMap().entries.map((entry) {
          final idx = entry.key;
          final photo = entry.value;
          return _buildPhotoTile(photo, idx, tileSize);
        }),
        // Add button (always visible)
        GestureDetector(
          onTap: _isSubmitting ? null : _showPickerSheet,
          child: Container(
            width: tileSize,
            height: tileSize,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.3),
                  width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_outlined,
                    size: 28,
                    color: const Color(0xFF1565C0).withValues(alpha: 0.7)),
                const SizedBox(height: 4),
                Text(
                  'Tambah Foto',
                  style: TextStyle(
                      fontSize: 10,
                      color: const Color(0xFF1565C0).withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoTile(_PhotoEntry photo, int index, double size) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: size,
            height: size,
            child: photo.uploading
                ? Container(
                    color: Colors.grey[100],
                    child: const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    ),
                  )
                : photo.error
                    ? Container(
                        color: Colors.red[50],
                        child: const Center(
                          child: Icon(Icons.error_outline,
                              color: Colors.red, size: 28),
                        ),
                      )
                    : (photo.file != null
                        ? Image.file(photo.file!, fit: BoxFit.cover)
                        : (photo.bytes != null
                            ? Image.memory(photo.bytes!, fit: BoxFit.cover)
                            : const SizedBox())),
          ),
        ),
        // Remove button
        if (!photo.uploading)
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removePhoto(index),
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child:
                    const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        // Upload success indicator
        if (!photo.uploading && !photo.error && photo.cloudUrl != null)
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                  color: Colors.green, shape: BoxShape.circle),
              child: const Icon(Icons.check, size: 12, color: Colors.white),
            ),
          ),
      ],
    );
  }
}

/// Internal helper class to track a single picked photo's state.
class _PhotoEntry {
  File? file;
  Uint8List? bytes;
  String? cloudUrl;
  bool uploading;
  bool error;

  _PhotoEntry({
    this.file,
    this.uploading = false,
  }) : error = false;
}
