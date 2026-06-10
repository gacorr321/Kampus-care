import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/comment_model.dart';

class CommentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream of comments for a specific item, ordered by creation time.
  Stream<List<CommentModel>> getCommentsForItem(String itemId) {
    return _firestore
        .collection('comments')
        .where('itemId', isEqualTo: itemId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CommentModel.fromMap(doc.data()))
            .toList());
  }

  /// Get comment count for a specific item.
  Stream<int> getCommentCount(String itemId) {
    return _firestore
        .collection('comments')
        .where('itemId', isEqualTo: itemId)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  /// Add a new comment (top-level or reply).
  Future<void> addComment(CommentModel comment) async {
    await _firestore
        .collection('comments')
        .doc(comment.id)
        .set(comment.toMap());
  }

  /// Delete a comment (and optionally cascade-delete replies).
  Future<void> deleteComment(String commentId) async {
    // First delete all replies to this comment
    final replies = await _firestore
        .collection('comments')
        .where('parentId', isEqualTo: commentId)
        .get();

    final batch = _firestore.batch();
    for (final reply in replies.docs) {
      batch.delete(reply.reference);
    }
    batch.delete(_firestore.collection('comments').doc(commentId));
    await batch.commit();
  }
}
