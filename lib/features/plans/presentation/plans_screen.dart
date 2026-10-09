import 'package:fitlog/features/exercises/presentation/exercise_list_screen.dart';
import 'package:fitlog/features/plans/presentation/plans_list_screen.dart';
import 'package:flutter/material.dart';

/// The Plans tab: a segmented switch between "My Plans" and the shared
/// "Exercise Library" (docs/ARCHITECTURE.md section 8).
class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plans'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('My Plans'),
                  icon: Icon(Icons.assignment_outlined),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Exercise Library'),
                  icon: Icon(Icons.fitness_center),
                ),
              ],
              selected: {_segment},
              onSelectionChanged: (selection) =>
                  setState(() => _segment = selection.first),
            ),
          ),
        ),
      ),
      // IndexedStack keeps each segment's state (search, scroll) alive.
      body: IndexedStack(
        index: _segment,
        children: const [PlansListScreen(), ExerciseListScreen()],
      ),
    );
  }
}
