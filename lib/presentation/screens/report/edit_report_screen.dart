import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/item_provider.dart';
import '../../../data/models/item_model.dart';
import '../../../data/services/camera_service.dart';
import '../../../data/services/location_service.dart';

class EditReportScreen extends StatefulWidget {
  final ItemModel item;
  const EditReportScreen({super.key, required this.item});

  @override
  State<EditReportScreen> createState() => _EditReportScreenState();
}

class _EditReportScreenState extends State<EditReportScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _locationController;
  final _cameraService = CameraService();
  final _locationService = LocationService();

  Uint8List? _webImageBytes;
  File? _selectedImage;
  late String _selectedCategory;
  late String _selectedStatus;
  bool _isLoading = false;
  bool _isGettingLocation = false;
  DateTime? _incidentDate;

  final List<String> _categories = [
    'Elektronik',
    'Aksesoris',
    'Dompet/Tas',
    'Pakaian',
    'Dokumen',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.title);
    _descController = TextEditingController(text: widget.item.description);
    _locationController = TextEditingController(text: widget.item.locationName);
    _selectedCategory = widget.item.category;
    _selectedStatus = widget.item.status;
    _incidentDate = widget.item.incidentDate;
    
    // Pastikan kategori yang dipilih valid
    if (!_categories.contains(_selectedCategory)) {
      _selectedCategory = 'Lainnya';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ganti Foto',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF1565C0)),
              title: const Text('Buka Kamera'),
              onTap: () async {
                Navigator.pop(context);
                final picker = ImagePicker();
                final XFile? photo = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 70,
                );
                if (photo != null) {
                  if (kIsWeb) {
                    final bytes = await photo.readAsBytes();
                    setState(() => _webImageBytes = bytes);
                  } else {
                    setState(() => _selectedImage = File(photo.path));
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF1565C0)),
              title: const Text('Pilih dari Galeri'),
              onTap: () async {
                Navigator.pop(context);
                final picker = ImagePicker();
                final XFile? photo = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 70,
                );
                if (photo != null) {
                  if (kIsWeb) {
                    final bytes = await photo.readAsBytes();
                    setState(() => _webImageBytes = bytes);
                  } else {
                    setState(() => _selectedImage = File(photo.path));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getLocation() async {
    setState(() => _isGettingLocation = true);
    final location = await _locationService.getCurrentLocationName();
    setState(() {
      _locationController.text = location;
      _isGettingLocation = false;
    });
  }

  Future<void> _pickIncidentDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _incidentDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );

    if (pickedDate != null && pickedDate != _incidentDate) {
      setState(() {
        _incidentDate = pickedDate;
      });
    }
  }

  Future<void> _updateReport() async {
    if (_titleController.text.trim().isEmpty) {
      _showSnackbar('Nama barang wajib diisi!', isError: true);
      return;
    }
    if (_locationController.text.trim().isEmpty) {
      _showSnackbar('Lokasi wajib diisi!', isError: true);
      return;
    }
    if (_incidentDate == null) {
      _showSnackbar('Tanggal hilang/ditemukan wajib diisi!', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final itemProvider = context.read<ItemProvider>();

      String imageUrl = widget.item.imageUrl;
      if (kIsWeb && _webImageBytes != null) {
        imageUrl = await _cameraService.uploadBytes(_webImageBytes!);
      } else if (_selectedImage != null) {
        imageUrl = await _cameraService.uploadPhoto(_selectedImage!);
      }

      final updatedItem = ItemModel(
        id: widget.item.id,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        imageUrl: imageUrl,
        category: _selectedCategory,
        status: _selectedStatus,
        reportedBy: widget.item.reportedBy,
        reportedByName: widget.item.reportedByName,
        reportedByPhone: widget.item.reportedByPhone,
        locationName: _locationController.text.trim(),
        reportedAt: widget.item.reportedAt,
        incidentDate: _incidentDate,
        returnProofImageUrl: widget.item.returnProofImageUrl,
        returnedAt: widget.item.returnedAt,
        claimedBy: widget.item.claimedBy,
        claimerProofImageUrl: widget.item.claimerProofImageUrl,
        claimerName: widget.item.claimerName,
      );

      await itemProvider.updateItem(updatedItem);

      if (mounted) {
        _showSnackbar('Laporan berhasil diperbarui! ✅');
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackbar('Gagal memperbarui laporan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Laporan'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Foto Section
            _buildSectionLabel('Foto Barang'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _showImagePicker,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: _webImageBytes != null
                    ? Image.memory(_webImageBytes!, fit: BoxFit.cover)
                    : _selectedImage != null
                        ? Image.file(_selectedImage!, fit: BoxFit.cover)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              widget.item.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(
                                    child: Icon(Icons.image_not_supported, size: 48, color: AppColors.textLight),
                                  ),
                            ),
                          ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Tap foto di atas untuk mengubahnya',
                style: TextStyle(color: AppColors.textLight, fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),

            // Detail Section
            _buildSectionLabel('Detail Laporan'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLabel('Nama Barang *'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Contoh: Mouse Voxy hitam',
                      prefixIcon: const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('Kategori'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Pilih Kategori',
                      prefixIcon: const Icon(Icons.category_outlined, color: AppColors.primary),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                    items: _categories
                        .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedCategory = val!),
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('Deskripsi'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Ciri-ciri khusus, warna, merek, dll.',
                      prefixIcon: const Icon(Icons.description_outlined, color: AppColors.primary),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('Tanggal Hilang/Ditemukan *'),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickIncidentDate,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.calendar_today_outlined, color: AppColors.primary),
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      child: Text(
                        _incidentDate != null
                            ? '${_incidentDate!.day}/${_incidentDate!.month}/${_incidentDate!.year}'
                            : 'Pilih Tanggal',
                        style: TextStyle(
                          color: _incidentDate != null ? AppColors.textPrimary : AppColors.textLight,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('Lokasi *'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _locationController,
                    style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Contoh: Lab Pemrograman Lt.2',
                      prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                      suffixIcon: _isGettingLocation
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.my_location_outlined, color: AppColors.primary),
                              onPressed: _getLocation,
                              tooltip: 'Gunakan lokasi saat ini',
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                  shadowColor: AppColors.primary.withValues(alpha: 0.3),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save_outlined, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Simpan Perubahan',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}
