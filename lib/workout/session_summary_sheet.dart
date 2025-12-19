import 'package:flutter/material.dart';
import 'session_repository.dart';

class SessionSummarySheet extends StatefulWidget {
  final SessionRecord session;
  final Function(int? rpe) onSave;

  const SessionSummarySheet({
    super.key,
    required this.session,
    required this.onSave,
  });

  @override
  State<SessionSummarySheet> createState() => _SessionSummarySheetState();
}

class _SessionSummarySheetState extends State<SessionSummarySheet> {
  int? _selectedRpe;
  bool _showError = false;
  bool _isSkipping = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isSkipping) {
      return _buildSkipConfirmation(context, theme);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'お疲れ様でした！',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'セッションのまとめ',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _buildMetricGrid(theme),
          const SizedBox(height: 40),
          Text(
            '主観的運動強度 (RPE)',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '今日のトレーニングはどれくらいきつかったですか？ (1:非常に楽 〜 10:限界)',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 20),
          _buildRpePicker(theme),
          if (_showError)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Text(
                'RPEを選択してください',
                style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _isSkipping = true;
                    });
                  },
                  child: Text('スキップ', style: TextStyle(color: theme.hintColor)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () {
                    if (_selectedRpe == null) {
                      setState(() {
                        _showError = true;
                      });
                      return;
                    }
                    widget.onSave(_selectedRpe!);
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('保存して終了', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkipConfirmation(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.help_outline_rounded, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            'RPEを入力しますか？',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'RPEを入力することで、次回のトレーニング設定がより正確に調整されます。',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () {
              setState(() {
                _isSkipping = false;
              });
            },
            child: const Text('入力に戻る'),
          ),
          TextButton(
            onPressed: () {
              widget.onSave(null);
              Navigator.pop(context);
            },
            child: Text('スキップする', style: TextStyle(color: theme.hintColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricGrid(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetricItem(theme, 'ゾーン内', '${widget.session.minutesInZone}', '分'),
          _buildMetricItem(theme, '平均心拍', '${widget.session.avgBpm}', 'BPM'),
          _buildMetricItem(theme, '最大心拍', '${widget.session.maxBpm}', 'BPM'),
        ],
      ),
    );
  }

  Widget _buildMetricItem(ThemeData theme, String label, String value, String unit) {
    return Column(
      children: [
        Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(width: 2),
            Text(unit, style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
          ],
        ),
      ],
    );
  }

  Widget _buildRpePicker(ThemeData theme) {
    return Center(
      child: Wrap(
        spacing: 8,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: List.generate(10, (index) {
          final rpe = index + 1;
          final isSelected = _selectedRpe == rpe;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedRpe = rpe;
                _showError = false;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  '$rpe',
                  style: TextStyle(
                    color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
