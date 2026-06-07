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

  List<ItemModel> get items => _items;
  bool get isLoading => _isLoading;
  String get filterStatus => _filterStatus;

  Future<void> listenToItems() async {
    _isLoading = true;
    notifyListeners();

    _subscription?.cancel();
    _subscription = _repository.getAllItems().listen((data) {
      _items = data;
      _isLoading = false;
      notifyListeners();
    });
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void setFilter(String status) {
    _filterStatus = status;
    notifyListeners();

    _subscription?.cancel();
    if (status == 'semua') {
      _subscription = _repository.getAllItems().listen((data) {
        _items = data;
        notifyListeners();
      });
    } else {
      _subscription = _repository.getItemsByStatus(status).listen((data) {
        _items = data;
        notifyListeners();
      });
    }
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
