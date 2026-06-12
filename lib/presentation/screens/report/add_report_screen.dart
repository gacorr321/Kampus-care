import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/item_provider.dart';
import '../../../data/models/item_model.dart';
import '../../../data/services/camera_service.dart';
import '../../../data/services/location_service.dart';
import 'map_picker_screen.dart';

class AddReportScreen extends StatefulWidget {
  const AddReportScreen({super.key});

  @override
  State<AddReportScreen> createState() => _AddReportScreenState();
}

class _AddReportScreenState extends State<AddReportScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _cameraService = CameraService();
  final _locationService = LocationService();

  Uint8List? _webImageBytes;
  File? _selectedImage;
  
  double? _latitude;
  double? _longitude;

  String _selectedCategory = 'Elektronik';
  final String _selectedStatus = 'hilang';
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
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // Pilih foto — kamera atau galeri
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
            const Text('Pilih Foto',
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

  // Ambil lokasi otomatis via GPS
  Future<void> _getLocation() async {
    setState(() => _isGettingLocation = true);
    final location = await _locationService.getCurrentLocationName();
    // Jika kita ingin koordinat akurat, LocationService harusnya mengembalikan LatLng,
    // tapi karena ini sudah ada, kita hanya set nama lokasi.
    setState(() {
      _locationController.text = location;
      _isGettingLocation = false;
    });
  }

  // Pilih lokasi via Peta OSM
  Future<void> _openMapPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MapPickerScreen(),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _locationController.text = result['locationName'];
        _latitude = result['latitude'];
        _longitude = result['longitude'];
      });
    }
  }

  // Pilih tanggal hilang/dikembalikan
  Future<void> _pickIncidentDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _incidentDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)), // 1 tahun ke belakang
      lastDate: now,
    );

    if (pickedDate != null && pickedDate != _incidentDate) {
      setState(() {
        _incidentDate = pickedDate;
      });
    }
  }

  // Submit laporan
  Future<void> _submitReport() async {
    if (_titleController.text.trim().isEmpty) {
      _showSnackbar('Nama barang wajib diisi!', isError: true);
      return;
    }
    if (_selectedImage == null && _webImageBytes == null) {
      _showSnackbar('Foto barang wajib ditambahkan!', isError: true);
      return;
    }
    if (_locationController.text.trim().isEmpty) {
      _showSnackbar('Lokasi wajib diisi!', isError: true);
      return;
    }
    if (_incidentDate == null) {
      _showSnackbar('Tanggal hilang/dikembalikan wajib diisi!', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final itemProvider = context.read<ItemProvider>();

      // Upload foto ke Firebase Storage
      String imageUrl;
      if (kIsWeb && _webImageBytes != null) {
        imageUrl = await _cameraService.uploadBytes(_webImageBytes!);
      } else if (_selectedImage != null) {
        imageUrl = await _cameraService.uploadPhoto(_selectedImage!);
      } else {
        _showSnackbar('Foto wajib ditambahkan!', isError: true);
        return;
      }

      // Buat objek laporan
      final item = ItemModel(
        id: const Uuid().v4(),
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        imageUrl: imageUrl,
        category: _selectedCategory,
        status: _selectedStatus,
        reportedBy: authProvider.user?.uid ?? '',
        reportedByName: authProvider.user?.name ?? 'Anonim',
        reportedByPhone: authProvider.user?.phone ?? '',
        locationName: _locationController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        reportedAt: DateTime.now(),
        incidentDate: _incidentDate,
      );

      await itemProvider.addItem(item);

      if (mounted) {
        _showSnackbar('Laporan berhasil dibuat! ✅');
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackbar('Gagal membuat laporan: $e', isError: true);
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
        title: const Text('Buat Laporan'),
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
            // Section: Foto Barang
            _buildSectionLabel('Foto Barang'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _showImagePicker,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (_webImageBytes != null || _selectedImage != null)
                        ? AppColors.success.withValues(alpha: 0.5)
                        : AppColors.border,
                    width: (_webImageBytes != null || _selectedImage != null) ? 2 : 1.5,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _webImageBytes != null
                    ? Image.memory(_webImageBytes!, fit: BoxFit.cover)
                    : _selectedImage != null
                        ? Image.file(_selectedImage!, fit: BoxFit.cover)
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt_outlined, size: 36, color: AppColors.primary),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Tap untuk tambah foto',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
              ),
            ),
            const SizedBox(height: 20),

            // Section: Detail Laporan
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
                  // Nama barang
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

                  // Kategori
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

                  // Deskripsi
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

                  // Tanggal Hilang/Dikembalikan
                  _buildLabel('Tanggal Hilang/Dikembalikan *'),
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

                  // Lokasi
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
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _isGettingLocation
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
                                  tooltip: 'Gunakan lokasi saat ini (GPS)',
                                ),
                          IconButton(
                            icon: const Icon(Icons.map_outlined, color: AppColors.success),
                            onPressed: _openMapPicker,
                            tooltip: 'Pilih di Peta (OSM)',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Tombol submit
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitReport,
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
                          Icon(Icons.send_outlined, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Kirim Laporan',
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
