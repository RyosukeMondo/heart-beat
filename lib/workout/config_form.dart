import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ConfigForm extends StatelessWidget {
  final TextEditingController nameCtl;
  final TextEditingController descriptionCtl;
  final TextEditingController minHrCtl;
  final TextEditingController maxHrCtl;
  final TextEditingController durationMinutesCtl;
  final int intensityLevel;
  final Color selectedColor;
  final ValueChanged<int> onIntensityChanged;
  final ValueChanged<Color> onColorChanged;

  const ConfigForm({
    super.key,
    required this.nameCtl,
    required this.descriptionCtl,
    required this.minHrCtl,
    required this.maxHrCtl,
    required this.durationMinutesCtl,
    required this.intensityLevel,
    required this.selectedColor,
    required this.onIntensityChanged,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: nameCtl,
          decoration: const InputDecoration(
            labelText: 'Workout Name',
            hintText: 'e.g., Morning HIIT',
            prefixIcon: Icon(Icons.fitness_center),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a workout name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: descriptionCtl,
          decoration: const InputDecoration(
            labelText: 'Description',
            hintText: 'Brief description of the workout',
            prefixIcon: Icon(Icons.description),
          ),
          maxLines: 2,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a description';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: minHrCtl,
                decoration: const InputDecoration(
                  labelText: 'Min HR (BPM)',
                  prefixIcon: Icon(Icons.favorite_border),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  final intValue = int.tryParse(value ?? '');
                  if (intValue == null || intValue < 30 || intValue > 220) {
                    return 'Enter valid BPM (30-220)';
                  }
                  final maxValue = int.tryParse(maxHrCtl.text);
                  if (maxValue != null && intValue >= maxValue) {
                    return 'Must be < Max HR';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: maxHrCtl,
                decoration: const InputDecoration(
                  labelText: 'Max HR (BPM)',
                  prefixIcon: Icon(Icons.favorite),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  final intValue = int.tryParse(value ?? '');
                  if (intValue == null || intValue < 30 || intValue > 220) {
                    return 'Enter valid BPM (30-220)';
                  }
                  final minValue = int.tryParse(minHrCtl.text);
                  if (minValue != null && intValue <= minValue) {
                    return 'Must be > Min HR';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: durationMinutesCtl,
          decoration: const InputDecoration(
            labelText: 'Duration (minutes)',
            hintText: '30',
            prefixIcon: Icon(Icons.timer),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) {
            final intValue = int.tryParse(value ?? '');
            if (intValue == null || intValue < 1 || intValue > 300) {
              return 'Enter valid duration (1-300 min)';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildIntensitySlider(),
        _buildColorPicker(),
      ],
    );
  }

  Widget _buildIntensitySlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Intensity Level: $intensityLevel/5'),
        Slider(
          value: intensityLevel.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          label: intensityLevel.toString(),
          onChanged: (value) => onIntensityChanged(value.round()),
        ),
      ],
    );
  }

  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Color:'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            Colors.red,
            Colors.orange,
            Colors.yellow,
            Colors.green,
            Colors.blue,
            Colors.indigo,
            Colors.purple,
            Colors.pink,
          ]
              .map((color) => GestureDetector(
                    onTap: () => onColorChanged(color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selectedColor == color
                            ? Border.all(color: Colors.black, width: 3)
                            : null,
                      ),
                      child: selectedColor == color
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
