import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' show cos, sqrt, asin;

import '../../../core/constants/app_colors.dart';
import '../../providers/item_provider.dart';
import '../../../data/models/item_model.dart';
import '../../widgets/item_card.dart';
import '../../widgets/item_card/item_grid_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

// ── Filter option data ────────────────────────────────────────────────────────

const _colorOptions = [
  ('Hitam', Color(0xFF212121)),
  ('Putih', Color(0xFFF5F5F5)),
  ('Merah', Color(0xFFD32F2F)),
  ('Biru', Color(0xFF1565C0)),
  ('Hijau', Color(0xFF2E7D32)),
  ('Coklat', Color(0xFF6D4C41)),
  ('Abu-abu', Color(0xFF757575)),
  ('Emas', Color(0xFFFFB300)),
  ('Silver', Color(0xFFBDBDBD)),
  ('Pink', Color(0xFFE91E63)),
];

const _brandOptions = [
  'Samsung',
  'Apple',
  'Xiaomi',
  'Oppo',
  'Vivo',
  'Realme',
  'Asus',
  'Lenovo',
  'HP',
  'Dell',
];

const _distanceOptions = [
  ('500m', 500.0),
  ('1 km', 1000.0),
  ('3 km', 3000.0),
  ('Seluruh Kampus', double.infinity),
];

const _categoryOptions = [
  'Elektronik',
  'Aksesoris',
  'Dompet/Tas',
  'Pakaian',
  'Dokumen',
  'Lainnya',
];

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ItemModel> _searchResults = [];
  Timer? _debounce;

  // Filter state
  String? _selectedCategory;
  String? _selectedStatus;
  String? _selectedTimeRange;
  String? _selectedColor;
  String? _selectedBrand;
  double? _selectedDistance; // in meters, null = no filter
  Position? _userPosition;
  bool _isFilterExpanded = false;
  bool _isGettingLocation = false;
  bool _isGridView = false;

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

  // ── Search & Filter Logic ──────────────────────────────────────────────────

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _performSearch(_searchController.text.trim());
    });
  }

  void _performSearch(String query) {
    final words =
        query.toLowerCase().split(' ').where((w) => w.length > 2).toList();
    if (words.isEmpty && query.isNotEmpty) words.add(query.toLowerCase());

    final allItems = context.read<ItemProvider>().items;
    List<ItemModel> results = [];

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
      // Category filter
      if (_selectedCategory != null && item.category != _selectedCategory) {
        continue;
      }

      // Status filter
      if (_selectedStatus != null &&
          item.status != _selectedStatus!.toLowerCase()) {
        continue;
      }

      // Time filter
      if (minDate != null && item.reportedAt.isBefore(minDate)) {
        continue;
      }

      // Color filter — match in title + description
      if (_selectedColor != null) {
        final searchable = '${item.title} ${item.description}'.toLowerCase();
        if (!searchable.contains(_selectedColor!.toLowerCase())) continue;
      }

      // Brand filter — match in title + description
      if (_selectedBrand != null) {
        final searchable = '${item.title} ${item.description}'.toLowerCase();
        if (!searchable.contains(_selectedBrand!.toLowerCase())) continue;
      }

      // Distance filter
      if (_selectedDistance != null && _selectedDistance != double.infinity) {
        if (item.latitude == null || item.longitude == null) continue;
        if (_userPosition == null) continue;
        final dist = _haversineDistance(
          _userPosition!.latitude,
          _userPosition!.longitude,
          item.latitude!,
          item.longitude!,
        );
        if (dist > _selectedDistance!) continue;
      }

      // Text search
      if (words.isNotEmpty) {
        final textToSearch =
            '${item.title} ${item.description} ${item.category}'.toLowerCase();
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

    setState(() => _searchResults = results);
  }

  /// Haversine distance in meters between two lat/lng points.
  double _haversineDistance(
      double lat1, double lng1, double lat2, double lng2) {
    const p = 0.017453292519943295; // pi / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lng2 - lng1) * p)) / 2;
    return 12742000 * asin(sqrt(a)); // Earth diameter in meters * asin
  }

  Future<void> _fetchUserLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Izin lokasi diperlukan untuk filter jarak.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      _userPosition = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      // Re-run search with location available
      _onSearchChanged();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mendapatkan lokasi.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  int _activeFilterCount() {
    int count = 0;
    if (_selectedCategory != null) count++;
    if (_selectedStatus != null) count++;
    if (_selectedTimeRange != null) count++;
    if (_selectedColor != null) count++;
    if (_selectedBrand != null) count++;
    if (_selectedDistance != null) count++;
    return count;
  }

  bool _hasActiveFilters() => _activeFilterCount() > 0;

  void _clearAllFilters() {
    setState(() {
      _selectedCategory = null;
      _selectedStatus = null;
      _selectedTimeRange = null;
      _selectedColor = null;
      _selectedBrand = null;
      _selectedDistance = null;
    });
    _onSearchChanged();
  }

  void _removeFilter(String type) {
    setState(() {
      switch (type) {
        case 'category':
          _selectedCategory = null;
          break;
        case 'status':
          _selectedStatus = null;
          break;
        case 'time':
          _selectedTimeRange = null;
          break;
        case 'color':
          _selectedColor = null;
          break;
        case 'brand':
          _selectedBrand = null;
          break;
        case 'distance':
          _selectedDistance = null;
          break;
      }
    });
    _onSearchChanged();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Search Header ───────────────────────────────────────────────────
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border:
                Border(bottom: BorderSide(color: AppColors.divider, width: 1)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            children: [
              // Search bar row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(
                          fontSize: 15, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Cari barang, merek, warna...',
                        hintStyle: const TextStyle(color: AppColors.textHint),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: AppColors.textLight),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded,
                                    color: AppColors.textLight),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () =>
                        setState(() => _isFilterExpanded = !_isFilterExpanded),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _hasActiveFilters()
                            ? AppColors.primary
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _hasActiveFilters()
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            color: _hasActiveFilters()
                                ? Colors.white
                                : AppColors.primary,
                            size: 22,
                          ),
                          if (_activeFilterCount() > 0) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_activeFilterCount()}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ── Active filter chips ──────────────────────────────────────
              if (_hasActiveFilters()) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _buildActiveChips(),
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Inline Filter Panel (expandable) ──────────────────────────────
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.40,
            ),
            child: SingleChildScrollView(
              child: _buildFilterPanel(),
            ),
          ),
          crossFadeState: _isFilterExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),

        // ── Results Body ──────────────────────────────────────────────────
        Expanded(
          child: _searchController.text.isEmpty && !_hasActiveFilters()
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_rounded,
                          size: 72, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Mulai mengetik untuk mencari...',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'atau gunakan filter untuk menjelajahi',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                )
              : _searchResults.isEmpty
                  ? _buildEmptyState()
                  : Column(
                      children: [
                        // ── Results header with toggle ────────────────────
                        _buildResultsHeader(),
                        // ── Results list or grid ─────────────────────────
                        Expanded(
                          child: _isGridView
                              ? _buildGridView()
                              : ListView.builder(
                                  padding: const EdgeInsets.only(top: 8),
                                  itemCount: _searchResults.length,
                                  itemBuilder: (context, index) =>
                                      ItemCard(item: _searchResults[index]),
                                ),
                        ),
                      ],
                    ),
        ),
      ],
    );
  }

  // ── Active Chips ──────────────────────────────────────────────────────────

  List<Widget> _buildActiveChips() {
    final chips = <Widget>[];
    const gap = SizedBox(width: 8);

    if (_selectedStatus != null) {
      chips.add(_chip('Status: $_selectedStatus', 'status'));
      chips.add(gap);
    }
    if (_selectedCategory != null) {
      chips.add(_chip('Kategori: $_selectedCategory', 'category'));
      chips.add(gap);
    }
    if (_selectedColor != null) {
      chips.add(_chip('Warna: $_selectedColor', 'color'));
      chips.add(gap);
    }
    if (_selectedBrand != null) {
      chips.add(_chip('Merek: $_selectedBrand', 'brand'));
      chips.add(gap);
    }
    if (_selectedDistance != null) {
      final label = _selectedDistance == double.infinity
          ? 'Seluruh Kampus'
          : '≤ ${_selectedDistance!.toInt()}m';
      chips.add(_chip('Jarak: $label', 'distance'));
      chips.add(gap);
    }
    if (_selectedTimeRange != null) {
      chips.add(_chip('Waktu: $_selectedTimeRange', 'time'));
    }

    // Add "Clear all" at the end
    chips.add(gap);
    chips.add(
      GestureDetector(
        onTap: _clearAllFilters,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.close, size: 14, color: Colors.red),
              SizedBox(width: 4),
              Text('Hapus Semua',
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );

    return chips;
  }

  Widget _chip(String label, String type) {
    return GestureDetector(
      onTap: () => _removeFilter(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.close, size: 14, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  // ── Filter Panel ────────────────────────────────────────────────────────────

  Widget _buildFilterPanel() {
    return Container(
      color: AppColors.surfaceVariant.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status ─────────────────────────────────────────────────────
            _sectionHeader(
                'Status', () => setState(() => _selectedStatus = null)),
            const SizedBox(height: 6),
            _buildChipRow(['Hilang', 'Ditemukan'], _selectedStatus, (v) {
              setState(() => _selectedStatus = _selectedStatus == v ? null : v);
              _onSearchChanged();
            }),

            const SizedBox(height: 12),

            // ── Kategori ───────────────────────────────────────────────────
            _sectionHeader(
                'Kategori', () => setState(() => _selectedCategory = null)),
            const SizedBox(height: 6),
            _buildChipRow(_categoryOptions, _selectedCategory, (v) {
              setState(
                  () => _selectedCategory = _selectedCategory == v ? null : v);
              _onSearchChanged();
            }),

            const SizedBox(height: 12),

            // ── Warna ──────────────────────────────────────────────────────
            _sectionHeader(
                'Warna', () => setState(() => _selectedColor = null)),
            const SizedBox(height: 6),
            _buildColorPicker(),

            const SizedBox(height: 12),

            // ── Merek ──────────────────────────────────────────────────────
            _sectionHeader('Merek (Elektronik)',
                () => setState(() => _selectedBrand = null)),
            const SizedBox(height: 6),
            _buildChipRow(_brandOptions, _selectedBrand, (v) {
              setState(() => _selectedBrand = _selectedBrand == v ? null : v);
              _onSearchChanged();
            }),

            const SizedBox(height: 12),

            // ── Jarak ──────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionHeader('Jarak dari Anda', () {
                  setState(() => _selectedDistance = null);
                  _onSearchChanged();
                }),
                if (_isGettingLocation)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _buildDistanceRow(),

            const SizedBox(height: 12),

            // ── Waktu ──────────────────────────────────────────────────────
            _sectionHeader('Waktu Laporan',
                () => setState(() => _selectedTimeRange = null)),
            const SizedBox(height: 6),
            _buildChipRow(
                ['7 Hari Terakhir', '30 Hari Terakhir'], _selectedTimeRange,
                (v) {
              setState(() =>
                  _selectedTimeRange = _selectedTimeRange == v ? null : v);
              _onSearchChanged();
            }),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, VoidCallback onReset) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textPrimary)),
        GestureDetector(
          onTap: onReset,
          child: const Text('Reset',
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildChipRow(
      List<String> options, String? selected, ValueChanged<String> onTap) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = selected == opt;
        return GestureDetector(
          onTap: () => onTap(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 4)
                    ]
                  : null,
            ),
            child: Text(
              opt,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorPicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _colorOptions.map((entry) {
        final (name, color) = entry;
        final isSelected = _selectedColor == name;
        final isLight = color == const Color(0xFFF5F5F5) ||
            color == const Color(0xFFBDBDBD) ||
            color == const Color(0xFFFFB300);
        return GestureDetector(
          onTap: () {
            setState(
                () => _selectedColor = _selectedColor == name ? null : name);
            _onSearchChanged();
          },
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isSelected ? 40 : 34,
                height: isSelected ? 40 : 34,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isLight
                            ? Colors.grey.shade400
                            : Colors.grey.shade300),
                    width: isSelected ? 3 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 6)
                        ]
                      : null,
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        size: 18,
                        color: isLight ? AppColors.textPrimary : Colors.white,
                      )
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                name,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? AppColors.primary : AppColors.textLight,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDistanceRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _distanceOptions.map((entry) {
        final (label, distance) = entry;
        final isSelected = _selectedDistance == distance;
        return GestureDetector(
          onTap: () async {
            if (_userPosition == null) {
              await _fetchUserLocation();
              if (_userPosition == null) return; // Location fetch failed
            }
            setState(() => _selectedDistance =
                _selectedDistance == distance ? null : distance);
            _onSearchChanged();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 4)
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.place,
                  size: 14,
                  color: isSelected ? Colors.white : AppColors.textLight,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            _hasActiveFilters()
                ? 'Tidak ada hasil dengan filter tersebut.'
                : 'Barang tidak ditemukan dalam laporan.',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          if (_hasActiveFilters()) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _clearAllFilters,
              child: const Text('Hapus Semua Filter'),
            ),
          ],
        ],
      ),
    );
  }

  // ── Results Header (count + view toggle) ────────────────────────────────────

  Widget _buildResultsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Result count
          Text(
            '${_searchResults.length} hasil ditemukan',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          // View toggle
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildViewButton(Icons.view_list_rounded, false),
                _buildViewButton(Icons.grid_view_rounded, true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewButton(IconData icon, bool isGrid) {
    final isActive = _isGridView == isGrid;
    return GestureDetector(
      onTap: () => setState(() => _isGridView = isGrid),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isActive ? Colors.white : AppColors.textLight,
        ),
      ),
    );
  }

  // ── Grid View ───────────────────────────────────────────────────────────────

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        return ItemGridTile(
          item: item,
          onTap: () {
            // Show full card in bottom sheet
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => DraggableScrollableSheet(
                initialChildSize: 0.85,
                maxChildSize: 0.95,
                minChildSize: 0.5,
                expand: false,
                builder: (_, scrollController) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: ItemCard(item: item),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
