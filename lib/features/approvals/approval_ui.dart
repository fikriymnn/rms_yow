import 'package:flutter/material.dart';

import '../../core/ui/ui_kit.dart';
import 'approval_models.dart';

extension ApprovalUi on ApprovalRequest {
  Tone get tone => switch (status) {
    'approved' => Tone.success,
    'rejected' => Tone.danger,
    'pending_l1' || 'pending_owner' => Tone.warning,
    _ => Tone.neutral,
  };

  String get shortStatus => switch (status) {
    'pending_l1' => 'Menunggu tingkat 1',
    'pending_owner' => 'Menunggu owner',
    _ => statusLabel,
  };

  IconData get typeIcon => switch (type) {
    'purchase_order' => Icons.shopping_cart_outlined,
    'ingredient' => Icons.egg_alt_outlined,
    _ => Icons.local_shipping_outlined,
  };
}
