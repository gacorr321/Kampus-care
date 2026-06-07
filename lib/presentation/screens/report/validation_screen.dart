import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/item_provider.dart';
import '../../providers/notification_provider.dart';
import '../../../data/models/item_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/camera_service.dart';
import '../../widgets/item_card.dart';

class ValidationScreen extends StatefulWidget {
  const ValidationScreen({super.key});

  @override
  State<ValidationScreen> createState() => _ValidationScreenState();
}

class _ValidationScreenState extends State<ValidationScreen> {
  bool _isProcessing = false;

  Future<void> _showConfirmDialog(ItemModel item) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _ConfirmReturnSheet(
        item: item,
        onConfirm: (pin, imageUrl) async {
          Navigator.pop(context);
          await _processReturn(item, pin, imageUrl);
        },
      ),
    );
  }

  Future<void> _processReturn(
    ItemModel item,
    String pin,
    String imageUrl,
  ) async {
    final itemProvider = context.read<ItemProvider>();
    final currentUserId = context.read<AuthProvider>().user?.uid;
    setState(() => _isProcessing = true);
    try {
      // ── Guard: sesi login valid ──
      if (currentUserId == null) {
        throw 'Sesi tidak valid. Silakan login ulang.';
      }

      // ── Guard: hanya pelapor yang boleh memvalidasi ──
      if (currentUserId != item.reportedBy) {
        throw 'Anda tidak memiliki hak untuk memvalidasi barang ini. Hanya pelapor yang dapat melakukan konfirmasi.';
      }

      // Validasi melalui provider/repository
      await itemProvider.validateReturn(
        item: item,
        pin: pin,
        imageUrl: imageUrl,
        currentUserId: currentUserId,
      );

      // Send notification to the claimer
      if (item.claimedBy != null) {
        if (!mounted) return;
        final notifProvider = context.read<NotificationProvider>();
        await notifProvider.sendNotification(
          targetUserId: item.claimedBy!,
          title: 'Konfirmasi Penemu Selesai ✅',
          body: 'Penemu sudah mengkonfirmasi! Silakan upload foto bukti terima kamu di tab Riwayat -> Diklaim untuk menyelesaikan proses.',
          relatedItemId: item.id,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Barang berhasil dikonfirmasi kembali! ✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userId = authProvider.user?.uid;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Selesaikan laporan Anda jika barang sudah kembali ke pemiliknya.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: userId == null
                  ? _buildEmptyState()
                  : StreamBuilder<List<ItemModel>>(
                      stream: context.read<ItemProvider>().getValidationItemsStream(userId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'Terjadi kesalahan: ${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          );
                        }
                        
                        final myItems = snapshot.data ?? [];
                        if (myItems.isEmpty) return _buildEmptyState();

                        return ListView.builder(
                          padding: const EdgeInsets.only(bottom: 100),
                          itemCount: myItems.length,
                          itemBuilder: (context, index) {
                            final item = myItems[index];
                            return Column(
                              children: [
                                ItemCard(item: item, showActionButton: false),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showConfirmDialog(item),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      icon: const Icon(Icons.verified, size: 18),
                                      label: const Text('Konfirmasi Selesai'),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
        if (_isProcessing)
          Container(
            color: Colors.black26,
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment_turned_in_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tidak ada laporan aktif',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Semua barang Anda telah divalidasi.',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Bottom Sheet: PIN + Foto Bukti Pengembalian
// ────────────────────────────────────────────────────────────
class _ConfirmReturnSheet extends StatefulWidget {
  final ItemModel item;
  final Function(String pin, String imageUrl) onConfirm;

  const _ConfirmReturnSheet({required this.item, required this.onConfirm});

  @override
  State<_ConfirmReturnSheet> createState() => _ConfirmReturnSheetState();
}

class _ConfirmReturnSheetState extends State<_ConfirmReturnSheet> {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  final _cameraService = CameraService();

  File? _imageFile;
  Uint8List? _imageBytes; // for web
  bool _isUploading = false;
  String? _uploadedImageUrl;

  bool get _pinComplete => _pinController.text.length == 4;
  bool get _canConfirm => _pinComplete && _uploadedImageUrl != null;

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

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
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.camera_alt, color: AppColors.primary),
              ),
              title: const Text(
                'Ambil Foto dengan Kamera',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.photo_library, color: Colors.orange),
              ),
              title: const Text(
                'Pilih dari Galeri',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
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

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                color: Colors.blue,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Foto Bukti Pengembalian',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            if (_uploadedImageUrl != null)
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Upload foto barang yang diserahkan ke pemiliknya sebagai bukti.',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 12),

        // Preview / upload area
        GestureDetector(
          onTap: _isUploading ? null : _showImageSourceSheet,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _uploadedImageUrl != null
                  ? Colors.transparent
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _uploadedImageUrl != null
                    ? Colors.green.withValues(alpha: 0.6)
                    : Colors.grey[300]!,
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _isUploading
                ? _buildUploadingState()
                : _uploadedImageUrl != null
                ? _buildImagePreview()
                : _buildEmptyPhotoState(),
          ),
        ),

        if (_uploadedImageUrl != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: _showImageSourceSheet,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Ganti Foto'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUploadingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: AppColors.primary),
        const SizedBox(height: 12),
        Text(
          'Mengupload foto...',
          style: TextStyle(color: Colors.grey[500], fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildEmptyPhotoState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo_outlined, size: 40, color: Colors.grey[400]),
        const SizedBox(height: 8),
        Text(
          'Tap untuk upload foto bukti',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Kamera atau galeri',
          style: TextStyle(color: Colors.grey[400], fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    Widget imageWidget;
    if (kIsWeb && _imageBytes != null) {
      imageWidget = Image.memory(
        _imageBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (_imageFile != null) {
      imageWidget = Image.file(
        _imageFile!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else {
      imageWidget = const Center(child: Icon(Icons.image, size: 40));
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        imageWidget,
        // overlay badge
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, color: Colors.white, size: 12),
                SizedBox(width: 4),
                Text(
                  'Terupload',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
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

          // Title
          const Center(
            child: Text(
              'Konfirmasi Pengembalian',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Masukkan PIN & upload foto sebagai bukti',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ),
          const SizedBox(height: 24),

          // ── STEP 1: PIN ──────────────────────────────────────
          Row(
            children: [
              _buildStepBadge(
                1,
                _pinComplete ? Colors.green : AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Input PIN dari pemilik',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              if (_pinComplete)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 18,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  bool isFilled = _pinController.text.length > index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 56,
                    height: 64,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isFilled ? Colors.green : Colors.grey[300]!,
                        width: 2,
                      ),
                      boxShadow: isFilled
                          ? [
                              BoxShadow(
                                color: Colors.green.withValues(alpha: 0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      isFilled ? '•' : '',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  );
                }),
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _pinController,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Center(
            child: Text(
              'Ketik PIN yang disebutkan oleh pemilik barang',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          const SizedBox(height: 24),

          // ── STEP 2: Foto Bukti ────────────────────────────────
          Row(
            children: [
              _buildStepBadge(
                2,
                _uploadedImageUrl != null
                    ? Colors.green
                    : (_pinComplete ? AppColors.primary : Colors.grey[400]!),
              ),
              const SizedBox(width: 8),
              const Text(
                'Upload Foto Bukti',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          AnimatedOpacity(
            opacity: _pinComplete ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 300),
            child: IgnorePointer(
              ignoring: !_pinComplete,
              child: _buildPhotoSection(),
            ),
          ),

          const SizedBox(height: 24),

          // ── Tombol Konfirmasi ─────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _canConfirm
                  ? () => widget.onConfirm(
                      _pinController.text,
                      _uploadedImageUrl!,
                    )
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF198754),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey[300],
              ),
              icon: const Icon(Icons.check_circle, size: 20),
              label: const Text(
                'Konfirmasi Sudah Kembali',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          if (!_pinComplete)
            _buildHintBanner(
              Icons.lock_outline,
              'Lengkapi PIN terlebih dahulu',
              Colors.orange,
            ),
          if (_pinComplete && _uploadedImageUrl == null && !_isUploading)
            _buildHintBanner(
              Icons.camera_alt_outlined,
              'Upload foto bukti untuk melanjutkan',
              Colors.blue,
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStepBadge(int step, Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 26,
      height: 26,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        '$step',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildHintBanner(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
