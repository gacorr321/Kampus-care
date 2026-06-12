import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as dart_math;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/item_model.dart';

class ItemRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _hashPin(String pin) {
    var bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  // Ambil semua laporan realtime
  Stream<List<ItemModel>> getAllItems({int limit = 20}) {
    return _firestore
        .collection('items')
        .orderBy('reportedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ItemModel.fromMap(doc.data()))
              .toList(),
        );
  }

  // Filter by status
  Stream<List<ItemModel>> getItemsByStatus(String status, {int limit = 20}) {
    // Note: This requires composite indexes in Firestore for (status, reportedAt)
    if (status == 'ditemukan') {
      return _firestore
          .collection('items')
          .where('status', whereIn: ['ditemukan', 'dikembalikan'])
          .orderBy('reportedAt', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                  .map((doc) => ItemModel.fromMap(doc.data()))
                  .toList()
          );
    }
    
    return _firestore
        .collection('items')
        .where('status', isEqualTo: status)
        .orderBy('reportedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
                .map((doc) => ItemModel.fromMap(doc.data()))
                .toList()
        );
  }

  // Server-side search
  Future<List<ItemModel>> searchItems(String query, {int limit = 20}) async {
    // Note: Firestore search is case-sensitive on the exact field. 
    // Usually a separate lowercase field or Algolia is used for full-text.
    // We'll use 'title' here, so it only matches exact prefixes (e.g. "hp" won't match "HP").
    final snapshot = await _firestore
        .collection('items')
        .orderBy('title')
        .startAt([query])
        .endAt(['$query\uf8ff'])
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => ItemModel.fromMap(doc.data())).toList();
  }

  // Ambil semua barang yang sudah selesai (publik)
  Stream<List<ItemModel>> getCompletedItems() {
    return _firestore
        .collection('items')
        .where('status', isEqualTo: 'dikembalikan')
        .snapshots()
        .map(
          (snapshot) {
            final items = snapshot.docs
                .map((doc) => ItemModel.fromMap(doc.data()))
                .toList();
            items.sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
            return items;
          }
        );
  }

  // Tambah laporan baru
  Future<void> addItem(ItemModel item) async {
    await _firestore.collection('items').doc(item.id).set(item.toMap());
  }

  // Update status barang
  Future<void> updateStatus(String itemId, String newStatus) async {
    await _firestore.collection('items').doc(itemId).update({
      'status': newStatus,
    });
  }

  // Penemu mengunggah bukti, menunggu bukti dari pengklaim
  Future<void> setPendingClaimerProof(String itemId, String returnProofUrl) async {
    await _firestore.collection('items').doc(itemId).update({
      'status': 'menunggu_bukti_pengklaim',
      'returnProofImageUrl': returnProofUrl,
    });
  }

  // Pengklaim mengunggah bukti, proses selesai
  Future<void> completeReturn(String itemId, String claimerProofUrl) async {
    await _firestore.collection('items').doc(itemId).update({
      'status': 'dikembalikan',
      'claimerProofImageUrl': claimerProofUrl,
      'returnedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Update laporan
  Future<void> updateItem(ItemModel item) async {
    await _firestore.collection('items').doc(item.id).update(item.toMap());
  }

  // Hapus laporan
  Future<void> deleteItem(String itemId) async {
    await _firestore.collection('items').doc(itemId).delete();
  }

  // Ambil laporan berdasarkan user
  Stream<List<ItemModel>> getItemsByUser(String userId) {
    return _firestore
        .collection('items')
        .where('reportedBy', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) {
            final items = snapshot.docs
                .map((doc) => ItemModel.fromMap(doc.data()))
                .toList();
            // Sort client-side to avoid requiring composite index in Firestore
            items.sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
            return items;
          },
        );
  }

  // Klaim Barang
  Future<Map<String, dynamic>> claimItem({
    required ItemModel item,
    required String claimerId,
    required String claimerName,
  }) async {
    // Cek klaim aktif
    final existingClaim = await _firestore.collection('claims').doc(item.id).get();
    if (existingClaim.exists) {
      final data = existingClaim.data()!;
      final exp = data['expiredAt'] ?? 0;
      final isConfirmed = data['isConfirmed'] ?? false;
      final existingClaimerId = data['claimerId'];

      if (!isConfirmed && DateTime.now().millisecondsSinceEpoch < exp) {
        if (existingClaimerId == claimerId) {
          // Update PIN baru jika user meminta ulang untuk keamanan
          final newPin = (1000 + dart_math.Random.secure().nextInt(9000)).toString();
          await _firestore.collection('claims').doc(item.id).update({
            'pin': _hashPin(newPin),
          });
          
          await updateItemClaimer(item.id, claimerId, claimerName);
          return {
            'pin': newPin,
            'expiredAt': DateTime.fromMillisecondsSinceEpoch(exp),
            'isHilang': item.status == 'hilang',
          };
        }
        throw 'Barang ini sedang dalam proses klaim. Silakan coba lagi nanti.';
      }
    }

    // Generate PIN
    final pin = (1000 + dart_math.Random.secure().nextInt(9000)).toString();
    final expiredAt = DateTime.now().add(const Duration(hours: 24));
    
    await _firestore.collection('claims').doc(item.id).set({
      'pin': _hashPin(pin),
      'itemId': item.id,
      'itemTitle': item.title,
      'claimerId': claimerId,
      'finderName': item.reportedByName,
      'finderPhone': item.reportedByPhone,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'expiredAt': expiredAt.millisecondsSinceEpoch,
      'isConfirmed': false,
    });

    await updateItemClaimer(item.id, claimerId, claimerName);

    return {
      'pin': pin,
      'expiredAt': expiredAt,
      'isHilang': item.status == 'hilang',
    };
  }

  Future<void> updateItemClaimer(String itemId, String claimerId, String claimerName) async {
    await _firestore.collection('items').doc(itemId).update({
      'claimedBy': claimerId,
      'claimerName': claimerName,
    });
  }

  // Validasi Pengembalian
  Future<void> validateReturn({
    required ItemModel item,
    required String pin,
    required String imageUrl,
    required String currentUserId,
  }) async {
    final claimDoc = await _firestore.collection('claims').doc(item.id).get();
    if (!claimDoc.exists) {
      throw 'Kode PIN belum dibuat oleh pengklaim.';
    }
    final claimData = claimDoc.data()!;

    final claimerId = claimData['claimerId'] as String?;
    if (claimerId != null && claimerId == currentUserId) {
      throw 'Anda adalah pengklaim barang ini. Hanya penemu/pelapor yang dapat memvalidasi.';
    }

    final storedPin = claimData['pin'] as String;
    if (storedPin != _hashPin(pin) && storedPin != pin) {
      throw 'PIN salah. Silakan periksa kembali.';
    }
    if (DateTime.now().millisecondsSinceEpoch > claimData['expiredAt']) {
      throw 'PIN sudah kadaluarsa.';
    }

    await _firestore.collection('claims').doc(item.id).update({
      'isConfirmed': true,
      'returnProofImageUrl': imageUrl,
      'confirmedAt': DateTime.now().millisecondsSinceEpoch,
    });

    await setPendingClaimerProof(item.id, imageUrl);
  }
}
