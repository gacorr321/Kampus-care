import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

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
    context.read<ItemProvider>().searchItems(query);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ItemProvider>();
    final displayItems = _searchController.text.isEmpty
        ? provider.items
        : provider.searchResults;

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
                ],
              ),

            ],
          ),
        ),

        // ── Results Body ──────────────────────────────────────────────────
        Expanded(
          child: provider.isSearching
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : displayItems.isEmpty
                  ? _buildEmptyState()
                  : Column(
                  children: [
                    // ── Results header with toggle ────────────────────
                    _buildResultsHeader(displayItems),
                    // ── Results list or grid ─────────────────────────
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (ScrollNotification scrollInfo) {
                          if (scrollInfo.metrics.pixels >=
                              scrollInfo.metrics.maxScrollExtent - 200) {
                            if (_searchController.text.isEmpty) {
                              context.read<ItemProvider>().loadMoreItems();
                            } else {
                              context.read<ItemProvider>().loadMoreSearchResults(_searchController.text.trim());
                            }
                          }
                          return false;
                        },
                        child: _isGridView
                            ? _buildGridView(displayItems)
                            : ListView.builder(
                                padding: const EdgeInsets.only(top: 8),
                                itemCount: displayItems.length,
                                itemBuilder: (context, index) =>
                                    ItemCard(item: displayItems[index]),
                              ),
                      ),
                    ),
                    if ((_searchController.text.isEmpty && provider.isFetchingMore) ||
                        (_searchController.text.isNotEmpty && provider.isFetchingMoreSearch))
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                            child: CircularProgressIndicator(color: AppColors.primary)),
                      ),
                  ],
                ),
        ),
      ],
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
            'Barang tidak ditemukan dalam laporan.',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── Results Header (count + view toggle) ────────────────────────────────────

  Widget _buildResultsHeader(List<ItemModel> items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Result count
          Text(
            '${items.length} hasil ditemukan',
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

  Widget _buildGridView(List<ItemModel> items) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
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
