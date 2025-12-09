import 'package:flutter/material.dart';
import 'profile_tab.dart';
import 'custom_workouts_tab.dart';

class WorkoutConfigPage extends StatefulWidget {
  const WorkoutConfigPage({super.key});

  @override
  State<WorkoutConfigPage> createState() => _WorkoutConfigPageState();
}

class _WorkoutConfigPageState extends State<WorkoutConfigPage> {
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
        body: const TabBarView(
          children: [
            ProfileTab(),
            CustomWorkoutsTab(),
          ],
        ),
      ),
    );
  }
}
