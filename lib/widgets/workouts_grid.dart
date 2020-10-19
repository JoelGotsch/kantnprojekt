import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/workouts.dart';
import './workout_item.dart';

class WorkoutsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final workoutsData = Provider.of<Workouts>(context);
    final Map<String, Workout> workouts = workoutsData.workouts;
    return ListView.builder(
      padding: const EdgeInsets.all(7.0),
      itemCount: workouts.length,
      itemBuilder: (ctx, i) => ChangeNotifierProvider.value(
        // builder: (c) => products[i],
        value: workouts.values.toList()[i],
        child: WorkoutItem(),
      ),
    );
  }
}
