// lib/widgets/loading_overlay.dart
import 'package:flutter/material.dart';

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final Color? color;
  final double opacity;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.color,
    this.opacity = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: _buildLoadingWidget(context),
          ),
      ],
    );
  }

  Widget _buildLoadingWidget(BuildContext context) {
    return Container(
      color: (color ?? Colors.black).withOpacity(opacity),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}