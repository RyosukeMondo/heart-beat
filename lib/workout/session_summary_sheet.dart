import 'package:flutter/material.dart';
import 'session_repository.dart';

class SessionSummarySheet extends StatefulWidget {
  final SessionRecord session;
  final Function(int rpe) onSave;

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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Session Complete!',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildMetricRow('Duration', '${widget.session.minutesInZone} mins in zone'),
          _buildMetricRow('Avg BPM', '${widget.session.avgBpm}'),
          _buildMetricRow('Max BPM', '${widget.session.maxBpm}'),
          const SizedBox(height: 32),
          Text(
            'Rate Perceived Exertion (RPE)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'How hard was this session? (1-10)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: List.generate(10, (index) {
              final rpe = index + 1;
              final isSelected = _selectedRpe == rpe;
              return ChoiceChip(
                label: Text('$rpe'),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedRpe = selected ? rpe : null;
                    _showError = false;
                  });
                },
              );
            }),
          ),
          if (_showError)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Please select an RPE value.',
                style: TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 24),
          ElevatedButton(
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
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('SAVE SESSION'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
