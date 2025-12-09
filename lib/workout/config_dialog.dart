import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'workout_config.dart';
import 'workout_settings.dart';
import 'config_form.dart';

class ConfigDialog extends StatefulWidget {
  final String title;
  final bool isEditing;
  final WorkoutConfig? editingConfig;
  final String? initialName;
  final String? initialDescription;
  final String? initialMinHr;
  final String? initialMaxHr;
  final String? initialDuration;
  final int initialIntensity;
  final Color initialColor;

  const ConfigDialog({
    super.key,
    required this.title,
    required this.isEditing,
    this.editingConfig,
    this.initialName,
    this.initialDescription,
    this.initialMinHr,
    this.initialMaxHr,
    this.initialDuration,
    this.initialIntensity = 3,
    this.initialColor = Colors.blue,
  });

  @override
  State<ConfigDialog> createState() => _ConfigDialogState();
}

class _ConfigDialogState extends State<ConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtl;
  late final TextEditingController _descriptionCtl;
  late final TextEditingController _minHrCtl;
  late final TextEditingController _maxHrCtl;
  late final TextEditingController _durationMinutesCtl;
  late int _intensityLevel;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: widget.initialName);
    _descriptionCtl = TextEditingController(text: widget.initialDescription);
    _minHrCtl = TextEditingController(text: widget.initialMinHr);
    _maxHrCtl = TextEditingController(text: widget.initialMaxHr);
    _durationMinutesCtl = TextEditingController(text: widget.initialDuration);
    _intensityLevel = widget.initialIntensity;
    _selectedColor = widget.initialColor;
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _descriptionCtl.dispose();
    _minHrCtl.dispose();
    _maxHrCtl.dispose();
    _durationMinutesCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: SingleChildScrollView(
            child: ConfigForm(
              nameCtl: _nameCtl,
              descriptionCtl: _descriptionCtl,
              minHrCtl: _minHrCtl,
              maxHrCtl: _maxHrCtl,
              durationMinutesCtl: _durationMinutesCtl,
              intensityLevel: _intensityLevel,
              selectedColor: _selectedColor,
              onIntensityChanged: (val) => setState(() => _intensityLevel = val),
              onColorChanged: (val) => setState(() => _selectedColor = val),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saveConfig,
          child: Text(widget.isEditing ? 'Update' : 'Create'),
        ),
      ],
    );
  }

  void _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final workoutSettings = context.read<WorkoutSettings>();
      final colorHex =
          '#${_selectedColor.value.toRadixString(16).substring(2).toUpperCase()}';

      if (widget.isEditing && widget.editingConfig != null) {
        await workoutSettings.updateWorkoutConfig(
          widget.editingConfig!.id,
          name: _nameCtl.text.trim(),
          description: _descriptionCtl.text.trim(),
          minHeartRate: int.parse(_minHrCtl.text),
          maxHeartRate: int.parse(_maxHrCtl.text),
          duration: Duration(minutes: int.parse(_durationMinutesCtl.text)),
          intensityLevel: _intensityLevel,
          colorCode: colorHex,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Workout configuration updated!')),
          );
        }
      } else {
        await workoutSettings.createWorkoutConfig(
          name: _nameCtl.text.trim(),
          description: _descriptionCtl.text.trim(),
          minHeartRate: int.parse(_minHrCtl.text),
          maxHeartRate: int.parse(_maxHrCtl.text),
          duration: Duration(minutes: int.parse(_durationMinutesCtl.text)),
          intensityLevel: _intensityLevel,
          colorCode: colorHex,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Custom workout configuration created!')),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }
}
