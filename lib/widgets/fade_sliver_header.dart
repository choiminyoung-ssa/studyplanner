import 'package:flutter/material.dart';

class FadeSliverHeader extends StatelessWidget {
  final double maxHeight;
  final double minHeight;
  final Widget child;

  const FadeSliverHeader({
    super.key,
    required this.maxHeight,
    required this.child,
    this.minHeight = 0,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: false,
      delegate: _FadeSliverHeaderDelegate(
        maxHeight: maxHeight,
        minHeight: minHeight,
        child: child,
      ),
    );
  }
}

class _FadeSliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double maxHeight;
  final double minHeight;
  final Widget child;

  _FadeSliverHeaderDelegate({
    required this.maxHeight,
    required this.minHeight,
    required this.child,
  });

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final range = (maxHeight - minHeight).clamp(1.0, double.infinity);
    final t = ((maxHeight - shrinkOffset) / range).clamp(0.0, 1.0);
    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, (1 - t) * -8),
        child: SizedBox.expand(child: child),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _FadeSliverHeaderDelegate oldDelegate) {
    return oldDelegate.maxHeight != maxHeight ||
        oldDelegate.minHeight != minHeight ||
        oldDelegate.child != child;
  }
}
