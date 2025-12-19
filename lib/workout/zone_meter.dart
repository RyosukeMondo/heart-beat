import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'coaching_controller.dart';
import 'coaching_state.dart';

class ZoneMeter extends ConsumerStatefulWidget {
  const ZoneMeter({super.key});

  @override
  ConsumerState<ZoneMeter> createState() => _ZoneMeterState();
}

class _ZoneMeterState extends ConsumerState<ZoneMeter> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(coachingControllerProvider);
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCueDisplay(state),
        const SizedBox(height: 32),
        _buildBpmDisplay(state, theme),
      ],
    );
  }

  Widget _buildCueDisplay(CoachingState state) {
    String text;
    String subText;
    List<Color> gradientColors;
    IconData icon;
    bool shouldPulse = false;

    switch (state.cue) {
      case ZoneCue.up:
        text = 'UP ↑';
        subText = '心拍数を上げて';
        gradientColors = [Colors.blue.shade400, Colors.blue.shade700];
        icon = Icons.keyboard_double_arrow_up_rounded;
        break;
      case ZoneCue.keep:
        text = 'KEEP ⟷';
        subText = 'この調子で！';
        gradientColors = [Colors.green.shade500, Colors.orange.shade500];
        icon = Icons.sync_rounded;
        shouldPulse = true;
        break;
      case ZoneCue.down:
        text = 'DOWN ↓';
        subText = '心拍数を下げて';
        gradientColors = [Colors.red.shade400, Colors.red.shade700];
        icon = Icons.keyboard_double_arrow_down_rounded;
        break;
    }

    if (state.currentBpm == 0 || state.status == SessionStatus.idle) {
      text = '--';
      subText = '接続待ち';
      gradientColors = [Colors.grey.shade400, Colors.grey.shade600];
      icon = Icons.sensors_off_rounded;
      shouldPulse = false;
    }

    Widget display = Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.white),
          const SizedBox(height: 12),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subText,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    if (shouldPulse) {
      return ScaleTransition(
        scale: _pulseAnimation,
        child: display,
      );
    }

    return AnimatedScale(
      scale: 1.0,
      duration: const Duration(milliseconds: 300),
      child: display,
    );
  }

  Widget _buildBpmDisplay(CoachingState state, ThemeData theme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              state.currentBpm > 0 ? '${state.currentBpm}' : '--',
              style: theme.textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 80,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'BPM',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.hintColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Target: ${state.targetLowerBpm} - ${state.targetUpperBpm}',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
