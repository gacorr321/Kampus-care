import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/repositories/item_repository.dart';
import '../../data/models/item_model.dart';

class ItemProvider extends ChangeNotifier {
  final ItemRepository _repository = ItemRepository();

  List<ItemModel> _items = [];
  bool _isLoading = false;
  String _filterStatus = 'semua';
  StreamSubscription<List<ItemModel>>? _subscription;

  // Pagination states
  int _currentLimit = 20;
  bool _isFetchingMore = false;

  // Search states
  List<ItemModel> _searchResults = [];
  bool _isSearching = false;
  int _searchLimit = 20;
  bool _isFetchingMoreSearch = false;

  List<ItemModel> get items => _items;
  bool get isLoading => _isLoading;
  bool get isFetchingMore => _isFetchingMore;
  String get filterStatus => _filterStatus;

  List<ItemModel> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  bool get isFetchingMoreSearch => _isFetchingMoreSearch;

  Future<void> listenToItems({bool reset = false}) async {
    if (reset || _items.isEmpty) {
      _currentLimit = 20;
      _isLoading = true;
      notifyListeners();
    }

    _subscription?.cancel();
    final stream = _filterStatus == 'semua'
        ? _repository.getAllItems(limit: _currentLimit)
        : _repository.getItemsByStatus(_filterStatus, limit: _currentLimit);

    _subscription = stream.listen((data) {
      _items = data;
      _isLoading = false;
      _isFetchingMore = false;
      notifyListeners();
    });
  }

  void loadMoreItems() {
    if (_isFetchingMore || _isLoading) return;
    _isFetchingMore = true;
    _currentLimit += 20;
    notifyListeners();
    listenToItems();
  }

  void setFilter(String status) {
    _filterStatus = status;
    listenToItems(reset: true);
  }

  Future<void> searchItems(String query, {bool reset = true}) async {
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    if (reset) {
      _searchLimit = 20;
      _isSearching = true;
      notifyListeners();
    }

    try {
      _searchResults = await _repository.searchItems(query, limit: _searchLimit);
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      _isSearching = false;
      _isFetchingMoreSearch = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreSearchResults(String query) async {
    if (_isFetchingMoreSearch || _isSearching || query.isEmpty) return;
    _isFetchingMoreSearch = true;
    _searchLimit += 20;
    notifyListeners();
    await searchItems(query, reset: false);
  }

  Future<void> addItem(ItemModel item) async {
    await _repository.addItem(item);
  }

  Future<void> setPendingClaimerProof(String itemId, String returnProofUrl) async {
    await _repository.setPendingClaimerProof(itemId, returnProofUrl);
  }

  Future<void> completeReturn(String itemId, String claimerProofUrl) async {
    await _repository.completeReturn(itemId, claimerProofUrl);
  }

  Future<void> updateItem(ItemModel item) async {
    await _repository.updateItem(item);
  }

  Future<void> deleteItem(String itemId) async {
    await _repository.deleteItem(itemId);
  }

  Stream<List<ItemModel>> getUserItemsStream(String userId) {
    return _repository.getItemsByUser(userId);
  }

  Stream<List<ItemModel>> getClaimedItemsStream(String userId) {
    return _repository.getAllItems().map((items) {
      return items.where((item) => item.claimedBy == userId).toList();
    });
  }

  Stream<List<ItemModel>> getCompletedItemsStream() {
    return _repository.getCompletedItems();
  }

  Stream<List<ItemModel>> getValidationItemsStream(String userId) {
    return _repository.getAllItems().map((items) {
      return items.where((item) =>
        item.reportedBy == userId &&        
        item.claimedBy != null &&           
        item.status != 'dikembalikan' &&
        item.status != 'menunggu_bukti_pengklaim'
      ).toList();
    });
  }

  Future<Map<String, dynamic>> claimItem({
    required ItemModel item,
    required String claimerId,
    required String claimerName,
  }) async {
    return await _repository.claimItem(
      item: item,
      claimerId: claimerId,
      claimerName: claimerName,
    );
  }

  Future<void> validateReturn({
    required ItemModel item,
    required String pin,
    required String imageUrl,
    required String currentUserId,
  }) async {
    await _repository.validateReturn(
      item: item,
      pin: pin,
      imageUrl: imageUrl,
      currentUserId: currentUserId,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
