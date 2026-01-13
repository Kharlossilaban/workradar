import 'package:flutter/material.dart';

/// Shimmer effect animation for skeleton loading
class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;

  const ShimmerEffect({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final base = widget.baseColor ??
        (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300);
    final highlight = widget.highlightColor ??
        (isDarkMode ? Colors.grey.shade600 : Colors.grey.shade100);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, highlight, highlight, base],
              stops: [
                0.0,
                ((_animation.value + 2) / 4).clamp(0.0, 0.5),
                ((_animation.value + 2) / 4 + 0.1).clamp(0.5, 1.0),
                1.0,
              ],
              transform: _SlidingGradientTransform(_animation.value),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform(this.slidePercent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

/// Base skeleton container with shimmer
class SkeletonContainer extends StatelessWidget {
  final Widget child;

  const SkeletonContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading content',
      excludeSemantics: true,
      child: ShimmerEffect(child: child),
    );
  }
}

/// Skeleton box for rectangular shapes
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Skeleton circle for avatars/icons
class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Skeleton text line
class SkeletonText extends StatelessWidget {
  final double? width;
  final double height;

  const SkeletonText({
    super.key,
    this.width,
    this.height = 14,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Skeleton for task card
class SkeletonTaskCard extends StatelessWidget {
  const SkeletonTaskCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        children: [
          // Checkbox placeholder
          SkeletonCircle(size: 24),
          SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(width: 180, height: 16),
                SizedBox(height: 8),
                SkeletonText(width: 120, height: 12),
              ],
            ),
          ),
          // Category chip
          SkeletonBox(width: 60, height: 24, borderRadius: 12),
        ],
      ),
    );
  }
}

/// Skeleton for task list
class SkeletonTaskList extends StatelessWidget {
  final int itemCount;

  const SkeletonTaskList({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return SkeletonContainer(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) => const SkeletonTaskCard(),
      ),
    );
  }
}

/// Skeleton for weather card
class SkeletonWeatherCard extends StatelessWidget {
  const SkeletonWeatherCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [Colors.grey.shade800, Colors.grey.shade900]
              : [Colors.grey.shade200, Colors.grey.shade300],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Weather info
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonText(width: 100, height: 14),
                  SizedBox(height: 8),
                  SkeletonText(width: 80, height: 32),
                  SizedBox(height: 4),
                  SkeletonText(width: 120, height: 12),
                ],
              ),
              // Weather icon
              SkeletonCircle(size: 64),
            ],
          ),
          SizedBox(height: 16),
          // Recommendation
          SkeletonBox(width: double.infinity, height: 50, borderRadius: 12),
        ],
      ),
    );
  }
}

/// Skeleton for statistics card
class SkeletonStatCard extends StatelessWidget {
  const SkeletonStatCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonCircle(size: 40),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonText(width: 80, height: 12),
                    SizedBox(height: 4),
                    SkeletonText(width: 50, height: 24),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton for profile statistics grid
class SkeletonStatsGrid extends StatelessWidget {
  const SkeletonStatsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonContainer(
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
        children: const [
          SkeletonStatCard(),
          SkeletonStatCard(),
          SkeletonStatCard(),
          SkeletonStatCard(),
        ],
      ),
    );
  }
}

/// Skeleton for chart
class SkeletonChart extends StatelessWidget {
  final double height;

  const SkeletonChart({super.key, this.height = 200});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SkeletonContainer(
        child: Column(
          children: [
            // Title
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SkeletonText(width: 120, height: 18),
                SkeletonBox(width: 80, height: 28, borderRadius: 14),
              ],
            ),
            const SizedBox(height: 24),
            // Chart bars
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (index) {
                  final heights = [60, 100, 80, 120, 90, 70, 110];
                  return SkeletonBox(
                    width: 30,
                    height: heights[index % heights.length].toDouble(),
                    borderRadius: 4,
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            // X-axis labels
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SkeletonText(width: 24, height: 10),
                SkeletonText(width: 24, height: 10),
                SkeletonText(width: 24, height: 10),
                SkeletonText(width: 24, height: 10),
                SkeletonText(width: 24, height: 10),
                SkeletonText(width: 24, height: 10),
                SkeletonText(width: 24, height: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for calendar event
class SkeletonCalendarEvent extends StatelessWidget {
  const SkeletonCalendarEvent({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400,
            width: 4,
          ),
        ),
      ),
      child: const Row(
        children: [
          // Time
          Column(
            children: [
              SkeletonText(width: 40, height: 14),
              SizedBox(height: 4),
              SkeletonText(width: 40, height: 14),
            ],
          ),
          SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(width: 150, height: 16),
                SizedBox(height: 6),
                SkeletonText(width: 100, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for calendar events list
class SkeletonCalendarEvents extends StatelessWidget {
  final int itemCount;

  const SkeletonCalendarEvents({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return SkeletonContainer(
      child: Column(
        children: List.generate(
          itemCount,
          (index) => const SkeletonCalendarEvent(),
        ),
      ),
    );
  }
}

/// Skeleton for profile header
class SkeletonProfileHeader extends StatelessWidget {
  const SkeletonProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonContainer(
      child: Column(
        children: [
          const SkeletonCircle(size: 100),
          const SizedBox(height: 16),
          const SkeletonText(width: 150, height: 20),
          const SizedBox(height: 8),
          const SkeletonText(width: 200, height: 14),
          const SizedBox(height: 12),
          SkeletonBox(
            width: 100,
            height: 28,
            borderRadius: 14,
          ),
        ],
      ),
    );
  }
}

/// Skeleton for message item
class SkeletonMessageItem extends StatelessWidget {
  const SkeletonMessageItem({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ),
      ),
      child: const Row(
        children: [
          SkeletonCircle(size: 50),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonText(width: 120, height: 16),
                    SkeletonText(width: 50, height: 12),
                  ],
                ),
                SizedBox(height: 6),
                SkeletonText(width: 200, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for message list
class SkeletonMessageList extends StatelessWidget {
  final int itemCount;

  const SkeletonMessageList({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return SkeletonContainer(
      child: Column(
        children: List.generate(
          itemCount,
          (index) => const SkeletonMessageItem(),
        ),
      ),
    );
  }
}
