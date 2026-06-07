import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/item_provider.dart';
import '../../../data/models/item_model.dart';
import '../../widgets/item_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ItemModel> _searchResults = [];
  Timer? _debounce;

  // Filter state
  String? _selectedCategory;
  String? _selectedStatus;
  String? _selectedTimeRange;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _performSearch(_searchController.text.trim());
      }
    });
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }
    
    // Pecah jadi per kata untuk pencarian lebih longgar
    final words = query.toLowerCase().split(' ').where((w) => w.length > 2).toList();
    if (words.isEmpty) words.add(query.toLowerCase());

    final allItems = context.read<ItemProvider>().items;
    List<ItemModel> results = [];

    // Tentukan batasan waktu berdasarkan filter
    DateTime? minDate;
    if (_selectedTimeRange != null) {
      final now = DateTime.now();
      if (_selectedTimeRange == '7 Hari Terakhir') {
        minDate = now.subtract(const Duration(days: 7));
      } else if (_selectedTimeRange == '30 Hari Terakhir') {
        minDate = now.subtract(const Duration(days: 30));
      }
    }

    for (var item in allItems) {
      // 1. Filter Kategori
      if (_selectedCategory != null && item.category != _selectedCategory) {
        continue;
      }

      // 2. Filter Status
      final currentStatus = _selectedStatus;
      if (currentStatus != null && item.status != currentStatus.toLowerCase()) {
        continue;
      }

      // 3. Filter Waktu
      if (minDate != null) {
        if (item.reportedAt.isBefore(minDate)) continue;
      }

      // 4. Filter Teks
      if (words.isNotEmpty) {
        final textToSearch = "${item.title} ${item.description} ${item.category}".toLowerCase();
        bool isMatch = false;
        
        for (var word in words) {
          if (textToSearch.contains(word)) {
            isMatch = true;
            break;
          }
        }
        if (!isMatch) continue;
      }

      results.add(item);
    }

    setState(() {
      _searchResults = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Header
        Container(
          width: double.infinity,
          color: const Color(0xFF1565C0).withValues(alpha: 0.05),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            children: [
              const Icon(Icons.search, size: 48, color: Color(0xFF1565C0)),
              const SizedBox(height: 8),
              const Text(
                'Cari Laporan',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ketik nama barang, deskripsi, atau kategori',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              
              // Search Input Field & Filter Button
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Cari sesuatu...',
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: _searchController.text.isNotEmpty 
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.grey),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged();
                                },
                              ) 
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: const Color(0xFF1565C0).withValues(alpha: 0.5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: const Color(0xFF1565C0).withValues(alpha: 0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: _showFilterBottomSheet,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _hasActiveFilters() ? const Color(0xFF1565C0) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF1565C0).withValues(alpha: _hasActiveFilters() ? 1.0 : 0.2),
                        ),
                      ),
                      child: Icon(
                        Icons.tune, 
                        color: _hasActiveFilters() ? Colors.white : const Color(0xFF1565C0),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Body state
        Expanded(
          child: _searchController.text.isEmpty
              ? const Center(
                  child: Text(
                    'Mulai mengetik untuk mencari...',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : _searchResults.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        return ItemCard(item: _searchResults[index]);
                      },
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
          const Icon(Icons.search_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            _hasActiveFilters() ? 'Tidak ada hasil dengan filter tersebut.' : 'Barang tidak ditemukan dalam laporan.',
            style: const TextStyle(color: Colors.grey),
          ),
          if (_hasActiveFilters())
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedCategory = null;
                  _selectedStatus = null;
                  _selectedTimeRange = null;
                });
                _onSearchChanged();
              },
              child: const Text('Hapus Filter'),
            ),
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return _selectedCategory != null || _selectedStatus != null || _selectedTimeRange != null;
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Filter Pencarian', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        if (_hasActiveFilters())
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                _selectedStatus = null;
                                _selectedCategory = null;
                                _selectedTimeRange = null;
                              });
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF1565C0),
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(50, 30),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8,
                      children: ['Semua', 'Hilang', 'Ditemukan'].map((status) {
                        final isSelected = _selectedStatus == (status == 'Semua' ? null : status);
                        return ChoiceChip(
                          label: Text(status),
                          selected: isSelected,
                          onSelected: (selected) {
                            setModalState(() {
                              _selectedStatus = status == 'Semua' ? null : status;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Kategori', style: TextStyle(fontWeight: FontWeight.bold)),
                        if (_selectedCategory != null)
                          TextButton(
                            onPressed: () => setModalState(() => _selectedCategory = null),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                            child: const Text('Reset', style: TextStyle(fontSize: 12, color: Color(0xFF1565C0))),
                          ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      children: ['Semua', 'Elektronik', 'Dokumen', 'Kunci', 'Dompet', 'Lainnya'].map((cat) {
                        final isSelected = _selectedCategory == (cat == 'Semua' ? null : cat);
                        return ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (selected) {
                            setModalState(() {
                              _selectedCategory = cat == 'Semua' ? null : cat;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Waktu Laporan', style: TextStyle(fontWeight: FontWeight.bold)),
                        if (_selectedTimeRange != null)
                          TextButton(
                            onPressed: () => setModalState(() => _selectedTimeRange = null),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                            child: const Text('Reset', style: TextStyle(fontSize: 12, color: Color(0xFF1565C0))),
                          ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      children: ['Semua Waktu', '7 Hari Terakhir', '30 Hari Terakhir'].map((time) {
                        final isSelected = _selectedTimeRange == (time == 'Semua Waktu' ? null : time);
                        return ChoiceChip(
                          label: Text(time),
                          selected: isSelected,
                          onSelected: (selected) {
                            setModalState(() {
                              _selectedTimeRange = time == 'Semua Waktu' ? null : time;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _onSearchChanged();
                        },
                        child: const Text('Terapkan Filter'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

