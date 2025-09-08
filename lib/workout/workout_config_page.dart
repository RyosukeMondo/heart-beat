import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'profile.dart';
import 'workout_settings.dart';
import 'workout_config.dart';

class WorkoutConfigPage extends StatefulWidget {
  const WorkoutConfigPage({super.key});

  @override
  State<WorkoutConfigPage> createState() => _WorkoutConfigPageState();
}

class _WorkoutConfigPageState extends State<WorkoutConfigPage> {
  final _ageCtl = TextEditingController();
  final _restCtl = TextEditingController();
  Gender _gender = Gender.other;
  WorkoutType _selected = WorkoutType.fatBurn;
  
  // Custom workout configuration management
  int _currentTabIndex = 0;
  final _formKey = GlobalKey<FormState>();
  
  // Custom workout form controllers
  final _nameCtl = TextEditingController();
  final _descriptionCtl = TextEditingController();
  final _minHrCtl = TextEditingController();
  final _maxHrCtl = TextEditingController();
  final _durationMinutesCtl = TextEditingController();
  int _intensityLevel = 3;
  Color _selectedColor = Colors.blue;
  
  // For editing existing configs
  WorkoutConfig? _editingConfig;

  @override
  void initState() {
    super.initState();
    final w = context.read<WorkoutSettings>();
    _ageCtl.text = w.age.toString();
    _restCtl.text = w.restingHr?.toString() ?? '';
    _gender = w.gender;
    _selected = w.selected;
  }

  @override
  void dispose() {
    _ageCtl.dispose();
    _restCtl.dispose();
    _nameCtl.dispose();
    _descriptionCtl.dispose();
    _minHrCtl.dispose();
    _maxHrCtl.dispose();
    _durationMinutesCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Workout Configuration'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.settings), text: 'Profile & Default'),
              Tab(icon: Icon(Icons.fitness_center), text: 'Custom Workouts'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildProfileTab(),
            _buildCustomWorkoutsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    final w = context.watch<WorkoutSettings>();
    final profile = WorkoutProfile(
      age: int.tryParse(_ageCtl.text) ?? w.age,
      gender: _gender,
      restingHr: int.tryParse(_restCtl.text),
    );
    final zones = profile.zonesByKarvonen() ?? profile.zonesByMax();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ageCtl,
                decoration: const InputDecoration(labelText: 'Age (years)')
                    .copyWith(prefixIcon: const Icon(Icons.cake)),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<Gender>(
                value: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: Gender.values
                    .map((g) => DropdownMenuItem(value: g, child: Text(g.name)))
                    .toList(),
                onChanged: (v) => setState(() => _gender = v ?? Gender.other),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _restCtl,
          decoration: const InputDecoration(
            labelText: 'Resting HR (optional, bpm)',
            hintText: 'e.g., 60',
            prefixIcon: Icon(Icons.favorite_outline),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        const Text('Default Workout Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: WorkoutType.values.map((t) {
            final selected = _selected == t && !w.isUsingCustomConfig;
            return ChoiceChip(
              label: Text(_labelFor(t)),
              selected: selected,
              onSelected: (_) => setState(() {
                _selected = t;
                // Clear custom workout selection when selecting default type
                context.read<WorkoutSettings>().clearCustomWorkoutSelection();
              }),
            );
          }).toList(),
        ),
        if (w.isUsingCustomConfig) ...[
          const SizedBox(height: 8),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.fitness_center, color: Theme.of(context).colorScheme.onPrimaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Custom workout "${w.selectedCustomConfig!.name}" is currently selected',
                      style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text('Current Target Zone (bpm)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (w.isUsingCustomConfig) ...[
                  Text('Custom: ${w.selectedCustomConfig!.targetZoneText}'),
                  Text('Duration: ${w.selectedCustomConfig!.durationText}'),
                  Text('Intensity: ${w.selectedCustomConfig!.intensityLevel}/5'),
                ] else ...[
                  Text('Max HR ≈ ${profile.effectiveMaxHr()} bpm'),
                  const SizedBox(height: 8),
                  final (lower, upper) = w.targetRange(),
                  Text('Target Range: $lower - $upper bpm', 
                       style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Full Zone Breakdown:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ...[1, 2, 3, 4, 5].map((z) {
                    final rng = zones[z]!;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('Z$z: ${rng.$1} - ${rng.$2} bpm'),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Reset to Current'),
                onPressed: () {
                  final ww = context.read<WorkoutSettings>();
                  setState(() {
                    _ageCtl.text = ww.age.toString();
                    _restCtl.text = ww.restingHr?.toString() ?? '';
                    _gender = ww.gender;
                    _selected = ww.selected;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save Profile'),
                onPressed: () async {
                  final age = int.tryParse(_ageCtl.text) ?? w.age;
                  final rest = int.tryParse(_restCtl.text);
                  await w.updateProfile(age: age, gender: _gender, restingHr: rest);
                  if (!w.isUsingCustomConfig) {
                    await w.selectWorkout(_selected);
                  }
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile saved successfully!')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomWorkoutsTab() {
    final w = context.watch<WorkoutSettings>();
    final allConfigs = w.allConfigs;
    final customConfigs = w.customConfigs;
    
    return Column(
      children: [
        // Current selection header
        if (w.isUsingCustomConfig)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Currently using: ${w.selectedCustomConfig!.name}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => w.clearCustomWorkoutSelection(),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
        
        // List of all workout configurations
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Default configurations section
              const Text('Default Configurations', 
                         style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...w.defaultConfigs.map((config) => _buildConfigCard(config, isDefault: true)),
              
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text('Custom Configurations', 
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  FilledButton.icon(
                    onPressed: () => _showCreateConfigDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Create'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              if (customConfigs.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.fitness_center, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No custom workout configurations yet',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap "Create" to add a custom workout profile',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...customConfigs.map((config) => _buildConfigCard(config, isDefault: false)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfigCard(WorkoutConfig config, {required bool isDefault}) {
    final w = context.watch<WorkoutSettings>();
    final isSelected = w.isUsingCustomConfig && w.selectedCustomConfig?.id == config.id;
    
    return Card(
      elevation: isSelected ? 4 : 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          if (!isDefault) {
            w.selectCustomWorkout(config.id);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Color(int.parse(config.colorCode.substring(1), radix: 16) + 0xFF000000),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      config.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                  if (!isDefault) ...[
                    IconButton(
                      onPressed: () => _showEditConfigDialog(config),
                      icon: const Icon(Icons.edit, size: 18),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      onPressed: () => _showDeleteConfigDialog(config),
                      icon: const Icon(Icons.delete, size: 18),
                      tooltip: 'Delete',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                config.description,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.favorite, size: 16, color: Colors.red[400]),
                  const SizedBox(width: 4),
                  Text(config.targetZoneText),
                  const SizedBox(width: 16),
                  Icon(Icons.timer, size: 16, color: Colors.blue[400]),
                  const SizedBox(width: 4),
                  Text(config.durationText),
                  const SizedBox(width: 16),
                  Icon(Icons.whatshot, size: 16, color: Colors.orange[400]),
                  const SizedBox(width: 4),
                  Text('${config.intensityLevel}/5'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateConfigDialog() {
    _clearForm();
    _showConfigDialog('Create Custom Workout', isEditing: false);
  }

  void _showEditConfigDialog(WorkoutConfig config) {
    _loadConfigIntoForm(config);
    _showConfigDialog('Edit Custom Workout', isEditing: true);
  }

  void _clearForm() {
    _nameCtl.clear();
    _descriptionCtl.clear();
    _minHrCtl.clear();
    _maxHrCtl.clear();
    _durationMinutesCtl.text = '30';
    _intensityLevel = 3;
    _selectedColor = Colors.blue;
    _editingConfig = null;
  }

  void _loadConfigIntoForm(WorkoutConfig config) {
    _nameCtl.text = config.name;
    _descriptionCtl.text = config.description;
    _minHrCtl.text = config.minHeartRate.toString();
    _maxHrCtl.text = config.maxHeartRate.toString();
    _durationMinutesCtl.text = config.durationInMinutes.toString();
    _intensityLevel = config.intensityLevel;
    _selectedColor = Color(int.parse(config.colorCode.substring(1), radix: 16) + 0xFF000000);
    _editingConfig = config;
  }

  void _showConfigDialog(String title, {required bool isEditing}) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: Form(
            key: _formKey,
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name field
                    TextFormField(
                      controller: _nameCtl,
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
                    
                    // Description field
                    TextFormField(
                      controller: _descriptionCtl,
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
                    
                    // Heart rate range
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _minHrCtl,
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
                              final maxValue = int.tryParse(_maxHrCtl.text);
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
                            controller: _maxHrCtl,
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
                              final minValue = int.tryParse(_minHrCtl.text);
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
                    
                    // Duration field
                    TextFormField(
                      controller: _durationMinutesCtl,
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
                    
                    // Intensity level slider
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Intensity Level: $_intensityLevel/5'),
                        Slider(
                          value: _intensityLevel.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: _intensityLevel.toString(),
                          onChanged: (value) => setDialogState(() {
                            _intensityLevel = value.round();
                          }),
                        ),
                      ],
                    ),
                    
                    // Color picker
                    Column(
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
                          ].map((color) => GestureDetector(
                            onTap: () => setDialogState(() {
                              _selectedColor = color;
                            }),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: _selectedColor == color
                                    ? Border.all(color: Colors.black, width: 3)
                                    : null,
                              ),
                              child: _selectedColor == color
                                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                                  : null,
                            ),
                          )).toList(),
                        ),
                      ],
                    ),
                  ],
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
              onPressed: () => _saveConfig(isEditing),
              child: Text(isEditing ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveConfig(bool isEditing) async {
    if (!_formKey.currentState!.validate()) return;
    
    try {
      final workoutSettings = context.read<WorkoutSettings>();
      final colorHex = '#${_selectedColor.value.toRadixString(16).substring(2).toUpperCase()}';
      
      if (isEditing && _editingConfig != null) {
        await workoutSettings.updateWorkoutConfig(
          _editingConfig!.id,
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
        final newConfig = await workoutSettings.createWorkoutConfig(
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
            const SnackBar(content: Text('Custom workout configuration created!')),
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

  void _showDeleteConfigDialog(WorkoutConfig config) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workout Configuration'),
        content: Text(
          'Are you sure you want to delete "${config.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final workoutSettings = context.read<WorkoutSettings>();
              final success = await workoutSettings.deleteWorkoutConfig(config.id);
              
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success 
                        ? 'Workout configuration deleted'
                        : 'Failed to delete workout configuration',
                    ),
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _labelFor(WorkoutType t) {
    switch (t) {
      case WorkoutType.recovery:
        return 'Recovery (Z1)';
      case WorkoutType.fatBurn:
        return 'Fat Burn (Z2)';
      case WorkoutType.endurance:
        return 'Endurance (Z2-3)';
      case WorkoutType.tempo:
        return 'Tempo (Z4)';
      case WorkoutType.hiit:
        return 'HIIT (Z5)';
    }
  }
}
