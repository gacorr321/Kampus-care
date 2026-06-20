import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/comment_model.dart';
import '../../../../data/models/item_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/comment_provider.dart';

/// Opens the comment section as a bottom sheet.
void showCommentSection(BuildContext context, ItemModel item) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => CommentSectionSheet(item: item),
  );
}

class CommentSectionSheet extends StatefulWidget {
  final ItemModel item;

  const CommentSectionSheet({super.key, required this.item});

  @override
  State<CommentSectionSheet> createState() => _CommentSectionSheetState();
}

class _CommentSectionSheetState extends State<CommentSectionSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  String? _replyingToId;
  String? _replyingToName;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Subscribe to comments for this item
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CommentProvider>().subscribeToComments(widget.item.id);
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      final auth = context.read<AuthProvider>();
      final commentProvider = context.read<CommentProvider>();

      await commentProvider.addComment(
        itemId: widget.item.id,
        userId: auth.user!.uid,
        userName: auth.user!.name,
        userPhotoUrl: auth.user!.photoUrl,
        text: text,
        parentId: _replyingToId,
      );

      _commentController.clear();
      setState(() {
        _replyingToId = null;
        _replyingToName = null;
      });

      // Auto-scroll to bottom after sending
      if (context.mounted) {
        await Future.delayed(const Duration(milliseconds: 300));
        // The scroll controller is managed by DraggableScrollableSheet
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim komentar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _setReply(String commentId, String userName) {
    setState(() {
      _replyingToId = commentId;
      _replyingToName = userName;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _commentFocusNode.requestFocus();
      }
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingToId = null;
      _replyingToName = null;
    });
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} minggu lalu';
    return '${(diff.inDays / 30).floor()} bulan lalu';
  }

  @override
  Widget build(BuildContext context) {
    final commentCount =
        context.watch<CommentProvider>().getCommentCount(widget.item.id);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ── Drag handle ──────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── Header ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_rounded,
                        color: AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Komentar ($commentCount)',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // ── Comments list ────────────────────────────────────────────
              Expanded(
                child: Consumer<CommentProvider>(
                  builder: (context, provider, _) {
                    final comments = provider.getComments(widget.item.id);
                    if (comments.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 56, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(
                              'Belum ada komentar',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Jadilah yang pertama berkomentar!',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }

                    // Build threaded comment tree
                    final topLevel =
                        comments.where((c) => c.parentId == null).toList();

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      itemCount: topLevel.length,
                      itemBuilder: (context, index) {
                        final comment = topLevel[index];
                        final replies = comments
                            .where((c) => c.parentId == comment.id)
                            .toList();
                        return _buildCommentThread(
                            comment, replies, widget.item.reportedBy);
                      },
                    );
                  },
                ),
              ),

              // ── Reply indicator ──────────────────────────────────────────
              if (_replyingToName != null)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppColors.primary.withValues(alpha: 0.06),
                  child: Row(
                    children: [
                      const Icon(Icons.reply,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Membalas $_replyingToName',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _cancelReply,
                        child: const Icon(Icons.close,
                            size: 18, color: AppColors.textLight),
                      ),
                    ],
                  ),
                ),

              // ── Input bar ────────────────────────────────────────────────
              Container(
                padding: EdgeInsets.fromLTRB(
                  12,
                  8,
                  12,
                  8 +
                      MediaQuery.of(context).viewInsets.bottom +
                      MediaQuery.of(context).padding.bottom,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                      top: BorderSide(color: AppColors.divider, width: 1)),
                ),
                child: Row(
                  children: [
                    // User avatar
                    _buildAvatar(
                      context.watch<AuthProvider>().user?.photoUrl,
                      context.watch<AuthProvider>().user?.name ?? '',
                      size: 32,
                    ),
                    const SizedBox(width: 8),
                    // Input field
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        focusNode: _commentFocusNode,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendComment(),
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Tulis komentar...',
                          hintStyle:
                              TextStyle(color: Colors.grey[400], fontSize: 14),
                          filled: true,
                          fillColor: AppColors.surfaceVariant,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Send button
                    GestureDetector(
                      onTap: _isSending ? null : _sendComment,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _isSending
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded,
                                color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentThread(
      CommentModel comment, List<CommentModel> replies, String ownerId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCommentTile(comment, false, ownerId),
        // Replies (indented)
        ...replies.map((reply) => Padding(
              padding: const EdgeInsets.only(left: 44),
              child: _buildCommentTile(reply, true, ownerId),
            )),
      ],
    );
  }

  Widget _buildCommentTile(CommentModel comment, bool isReply, String ownerId) {
    final isOwner = comment.userId == ownerId;
    final currentUserId = context.read<AuthProvider>().user?.uid;
    final canDelete = comment.userId == currentUserId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          _buildAvatar(comment.userPhotoUrl, comment.userName, size: 34),
          const SizedBox(width: 10),
          // Comment bubble
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + owner badge + time
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          comment.userName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isOwner) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PEMILIK',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        _formatTimeAgo(comment.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Comment text
                  Text(
                    comment.text,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Reply button
                  GestureDetector(
                    onTap: () => _setReply(comment.id, comment.userName),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.reply, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 3),
                        Text(
                          'Balas',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Delete option for own comments
          if (canDelete)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: GestureDetector(
                onTap: () => _confirmDelete(comment.id),
                child:
                    Icon(Icons.more_horiz, size: 18, color: Colors.grey[400]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? photoUrl, String name, {double size = 34}) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: CachedNetworkImage(
          imageUrl: photoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _avatarPlaceholder(name, size),
          errorWidget: (_, __, ___) => _avatarPlaceholder(name, size),
        ),
      );
    }
    return _avatarPlaceholder(name, size);
  }

  Widget _avatarPlaceholder(String name, double size) {
    // Use first letter as fallback
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _confirmDelete(String commentId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Hapus komentar',
                    style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await context
                      .read<CommentProvider>()
                      .deleteComment(commentId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.close, color: AppColors.textLight),
                title: const Text('Batal'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
