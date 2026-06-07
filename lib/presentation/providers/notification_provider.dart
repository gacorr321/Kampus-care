import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  StreamSubscription? _notificationSub;
  String? _userId;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get isLoading => _isLoading;

  void listenToNotifications(String userId) {
    if (_userId == userId) return;
    
    _userId = userId;
    _notificationSub?.cancel();
    _isLoading = true;
    notifyListeners();

    _notificationSub = _firestore
        .collection('notifications')
        .where('targetUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        _notifications = snapshot.docs
            .map((doc) => NotificationModel.fromMap(doc.data()))
            .toList();
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Error listening to notifications: $error');
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> sendNotification({
    required String targetUserId,
    required String title,
    required String body,
    String? relatedItemId,
  }) async {
    final id = const Uuid().v4();
    final notification = NotificationModel(
      id: id,
      targetUserId: targetUserId,
      title: title,
      body: body,
      isRead: false,
      createdAt: DateTime.now(),
      relatedItemId: relatedItemId,
    );

    await _firestore.collection('notifications').doc(id).set(notification.toMap());
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
  }

  Future<void> markAllAsRead() async {
    if (_userId == null) return;
    
    final batch = _firestore.batch();
    final unreadDocs = await _firestore
        .collection('notifications')
        .where('targetUserId', isEqualTo: _userId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in unreadDocs.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    super.dispose();
  }
}
