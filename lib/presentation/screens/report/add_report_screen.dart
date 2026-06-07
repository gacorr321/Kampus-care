import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
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

  // Pilih tanggal hilang/ditemukan
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
      _showSnackbar('Tanggal hilang/ditemukan wajib diisi!', isError: true);
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
      appBar: AppBar(title: const Text('Buat Laporan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Upload foto
            GestureDetector(
              onTap: _showImagePicker,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: _webImageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.memory(_webImageBytes!, fit: BoxFit.cover),
                      )
                    : _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(_selectedImage!, fit: BoxFit.cover),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt, size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Tap untuk tambah foto',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
              ),
            ),
            const SizedBox(height: 16),

            // Nama barang
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Nama Barang *',
                prefixIcon: Icon(Icons.inventory_2_outlined),
                hintText: 'Contoh: Mouse Voxy hitam',
              ),
            ),
            const SizedBox(height: 12),

            // Kategori
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: _categories
                  .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
            ),
            const SizedBox(height: 12),

            // Deskripsi
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Deskripsi',
                prefixIcon: Icon(Icons.description_outlined),
                hintText: 'Ciri-ciri khusus, warna, merek, dll.',
              ),
            ),
            const SizedBox(height: 12),

            // Tanggal Hilang/Ditemukan
            InkWell(
              onTap: _pickIncidentDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Tanggal Hilang/Ditemukan *',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  _incidentDate != null
                      ? '${_incidentDate!.day}/${_incidentDate!.month}/${_incidentDate!.year}'
                      : 'Pilih Tanggal',
                  style: TextStyle(
                    color: _incidentDate != null ? Colors.black87 : Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Lokasi
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Lokasi *',
                prefixIcon: const Icon(Icons.location_on_outlined),
                hintText: 'Contoh: Lab Pemrograman Lt.2',
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _isGettingLocation
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.my_location, color: Color(0xFF1565C0)),
                            onPressed: _getLocation,
                            tooltip: 'Gunakan lokasi saat ini (GPS)',
                          ),
                    IconButton(
                      icon: const Icon(Icons.map, color: Colors.green),
                      onPressed: _openMapPicker,
                      tooltip: 'Pilih di Peta (OSM)',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Tombol submit
            ElevatedButton(
              onPressed: _isLoading ? null : _submitReport,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Kirim Laporan', style: TextStyle(fontSize: 16)),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
