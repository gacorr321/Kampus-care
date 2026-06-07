import 'package:flutter/material.dart';
import '../../../data/models/item_model.dart';
import 'active_item_card.dart';
import 'completed_item_card.dart';

class ItemCard extends StatelessWidget {
  final ItemModel item;
  final bool showActionButton;

  const ItemCard({
    super.key,
    required this.item,
    this.showActionButton = true,
  });

  @override
  Widget build(BuildContext context) {
    if (item.status == 'dikembalikan') {
      return CompletedItemCard(item: item);
    }
    return ActiveItemCard(
      item: item,
      showActionButton: showActionButton,
    );
  }
}
