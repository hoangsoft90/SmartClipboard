import 'package:flutter/material.dart';

/// Pro upgrade banner — currently hidden (free limits removed in Plan 11 P0-2).
/// Will be reactivated in P0-3 with Rewarded Ad Pro unlock.
class ProUpgradeBanner extends StatelessWidget {
  const ProUpgradeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // Free limits removed — no archived items to show.
    // P0-3 will add Rewarded Ad unlock banner here.
    return const SizedBox.shrink();
  }
}
