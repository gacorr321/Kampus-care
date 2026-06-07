import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/item_model.dart';
import '../../../providers/auth_provider.dart';

class ClaimWizardSheet extends StatefulWidget {
  final ItemModel item;
  final Future<void> Function(BuildContext context, bool isHilang) onClaimSubmit;

  const ClaimWizardSheet({
    super.key,
    required this.item,
    required this.onClaimSubmit,
  });

  @override
  State<ClaimWizardSheet> createState() => _ClaimWizardSheetState();
}

class _ClaimWizardSheetState extends State<ClaimWizardSheet> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Step 1 Controllers
  final _nameController = TextEditingController();
  final _nimController = TextEditingController();

  // Step 2 Controllers
  final _q1Controller = TextEditingController();
  final _q2Controller = TextEditingController();
  final _q3Controller = TextEditingController();

  bool _isProcessing = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _nimController.dispose();
    _q1Controller.dispose();
    _q2Controller.dispose();
    _q3Controller.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      // Validasi Step 1
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.user;

      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesi tidak valid, harap login kembali.')),
        );
        return;
      }

      final inputName = _nameController.text.trim();
      final inputNim = _nimController.text.trim();

      if (inputName.isEmpty || inputNim.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Harap isi Nama dan NIM Anda.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (inputName.toLowerCase() != currentUser.name.toLowerCase() || inputNim != currentUser.nim) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data tidak cocok dengan akun terdaftar.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      _goToPage(1);
    } else if (_currentStep == 1) {
      // Validasi Step 2
      if (_q1Controller.text.trim().isEmpty ||
          _q2Controller.text.trim().isEmpty ||
          _q3Controller.text.trim().isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Harap jawab semua pertanyaan rahasia.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      _submitClaim();
    }
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() {
      _currentStep = page;
    });
  }

  Future<void> _submitClaim() async {
    setState(() => _isProcessing = true);
    
    // Panggil callback klaim
    final isHilang = widget.item.status == 'hilang';
    await widget.onClaimSubmit(context, isHilang);

    if (mounted) {
      setState(() => _isProcessing = false);
      // Tutup bottom sheet setelah sukses
      Navigator.pop(context);
    }
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepCircle(1, 'Verifikasi'),
        _buildStepLine(0),
        _buildStepCircle(2, 'Pertanyaan'),
        _buildStepLine(1),
        _buildStepCircle(3, 'Selesai'),
      ],
    );
  }

  Widget _buildStepCircle(int step, String label) {
    final isActive = _currentStep == step - 1;
    final isPassed = _currentStep > step - 1;
    
    Color bgColor = Colors.grey[800]!;
    Color textColor = Colors.grey[400]!;

    if (isActive) {
      bgColor = Colors.blue;
      textColor = Colors.white;
    } else if (isPassed) {
      bgColor = Colors.green;
      textColor = Colors.white;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive || isPassed ? Colors.transparent : Colors.grey[600]!,
        ),
      ),
      alignment: Alignment.center,
      child: isPassed 
        ? const Icon(Icons.check, size: 18, color: Colors.white)
        : Text('$step', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStepLine(int index) {
    final isPassed = _currentStep > index;
    return Container(
      width: 40,
      height: 2,
      color: isPassed ? Colors.green : Colors.grey[700],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[500]),
            filled: true,
            fillColor: Colors.grey[850],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[700]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[700]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'Verifikasi Identitas',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Masukkan data dirimu untuk melanjutkan',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'DATA MAHASISWA',
            style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _nameController,
            label: 'Nama lengkap',
            hint: 'Masukkan nama sesuai KTM...',
          ),
          _buildTextField(
            controller: _nimController,
            label: 'NIM',
            hint: 'Contoh: 4103191234',
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Data akan dicocokkan dengan akun terdaftar secara otomatis.',
                    style: TextStyle(color: Colors.blue[200], fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           const Center(
            child: Text(
              'Pertanyaan Rahasia',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Jawab pertanyaan seputar barang yang diklaim',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
          _buildTextField(
            controller: _q1Controller,
            label: 'PERTANYAAN 1 DARI 3\n\nApa warna dominan dari barang ini?',
            hint: 'Ketik jawabanmu...',
          ),
          _buildTextField(
            controller: _q2Controller,
            label: 'PERTANYAAN 2 DARI 3\n\nApakah ada ciri khusus pada barang? (stiker, coretan, kerusakan)',
            hint: 'Ketik jawabanmu...',
            maxLines: 2,
          ),
          _buildTextField(
            controller: _q3Controller,
            label: 'PERTANYAAN 3 DARI 3\n\nDi mana kamu terakhir melihat barang ini?',
            hint: 'Ketik jawabanmu...',
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF2D2D2D), // Dark background based on screenshot
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildStepIndicator(),
              const SizedBox(height: 24),
              const Divider(color: Colors.grey, height: 1),
              const SizedBox(height: 24),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(), // Disable swipe
                  children: [
                    _buildStep1(),
                    _buildStep2(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isProcessing ? null : _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isProcessing 
                  ? const SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentStep == 0 ? 'Lanjut' : 'Kirim Jawaban',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        if (_currentStep == 0) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 20),
                        ] else ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.send, size: 20),
                        ]
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
