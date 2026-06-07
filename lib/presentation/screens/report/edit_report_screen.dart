import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
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
      appBar: AppBar(title: const Text('Edit Laporan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: _showImagePicker,
              child: Container(
                height: 200,
                width: double.infinity,
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
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              widget.item.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                            ),
                          ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Tap foto di atas untuk mengubahnya',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Nama Barang *',
                prefixIcon: Icon(Icons.inventory_2_outlined),
                hintText: 'Contoh: Mouse Voxy hitam',
              ),
            ),
            const SizedBox(height: 12),

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

            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Lokasi *',
                prefixIcon: const Icon(Icons.location_on_outlined),
                hintText: 'Contoh: Lab Pemrograman Lt.2',
                suffixIcon: _isGettingLocation
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(
                          Icons.my_location,
                          color: Color(0xFF1565C0),
                        ),
                        onPressed: _getLocation,
                        tooltip: 'Gunakan lokasi saat ini',
                      ),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _updateReport,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Simpan Perubahan', style: TextStyle(fontSize: 16)),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
