import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'dart:collection'; // for linked hashmaps

import '../providers/workouts.dart';
import '../providers/workout.dart';
import './workout_item.dart';

class WorkoutsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final workoutsData = Provider.of<Workouts>(context);
    final List<Workout> workouts = workoutsData.sortedWorkouts;
    return SafeArea(
      child: ListView.builder(
        padding: const EdgeInsets.all(7.0),
        itemCount: workouts.length,
        itemBuilder: (ctx, i) => ChangeNotifierProvider.value(
          // builder: (c) => products[i],
          value: workouts[i],
          child: WorkoutItem(key: ValueKey(workouts[i].workoutId)),
        ),
      ),
    );
  }
}
