import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/repositories/comment_repository.dart';
import '../../data/models/comment_model.dart';

class CommentProvider extends ChangeNotifier {
  final CommentRepository _repository = CommentRepository();

  // Cache comments per item
  final Map<String, List<CommentModel>> _itemComments = {};
  final Map<String, StreamSubscription<List<CommentModel>>> _subscriptions = {};

  List<CommentModel> getComments(String itemId) => _itemComments[itemId] ?? [];

  /// Count is derived from the actual comments list — always in sync.
  int getCommentCount(String itemId) => _itemComments[itemId]?.length ?? 0;

  /// Subscribe to comments for a specific item.
  void subscribeToComments(String itemId) {
    // Avoid duplicate subscriptions
    if (_subscriptions.containsKey(itemId)) return;

    _subscriptions[itemId] = _repository.getCommentsForItem(itemId).listen(
      (comments) {
        _itemComments[itemId] = comments;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('CommentProvider stream error for $itemId: $error');
      },
    );
  }

  /// Unsubscribe from a specific item's comments.
  void unsubscribeFromComments(String itemId) {
    _subscriptions[itemId]?.cancel();
    _subscriptions.remove(itemId);
  }

  /// Add a new comment or reply.
  Future<void> addComment({
    required String itemId,
    required String userId,
    required String userName,
    String? userPhotoUrl,
    required String text,
    String? parentId,
  }) async {
    final comment = CommentModel(
      id: '${itemId}_${DateTime.now().millisecondsSinceEpoch}',
      itemId: itemId,
      userId: userId,
      userName: userName,
      userPhotoUrl: userPhotoUrl,
      text: text,
      createdAt: DateTime.now(),
      parentId: parentId,
    );
    await _repository.addComment(comment);
  }

  /// Delete a comment (cascades to replies).
  Future<void> deleteComment(String commentId) async {
    await _repository.deleteComment(commentId);
  }

  @override
  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    super.dispose();
  }
}
