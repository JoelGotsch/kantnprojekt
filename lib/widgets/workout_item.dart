import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/workouts.dart';
import '../views/edit_workout.dart';

class WorkoutItem extends StatefulWidget {
  @override
  _WorkoutItemState createState() => _WorkoutItemState();
}

class _WorkoutItemState extends State<WorkoutItem> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final workout = Provider.of<Workout>(context, listen: false);
    return GestureDetector(
        onTap: () {
          Navigator.of(context).pushNamed(
            EditWorkoutScreen.routeName,
            arguments: workout.localId,
          );
        },
        child: Card(
          margin: EdgeInsets.all(5),
          child: Dismissible(
            key: ValueKey(workout.localId),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: EdgeInsets.only(right: 20),
              color: Theme.of(context).errorColor,
              child: Icon(
                Icons.delete,
                color: Colors.white,
                size: 40,
              ),
            ),
            onDismissed: (direction) {
              Provider.of<Workouts>(context, listen: false)
                  .deleteWorkout(workout.localId);
            },
            child: Column(
              children: <Widget>[
                ListTile(
                  title: Text('${workout.points} points'),
                  subtitle: Text(
                    DateFormat('EEE, dd-MM-yyyy').format(workout.date),
                  ),
                  trailing: IconButton(
                    icon:
                        Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                    onPressed: () {
                      setState(() {
                        _expanded = !_expanded;
                      });
                    },
                  ),
                ),
                if (_expanded)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 5, vertical: 0),
                    height: min(workout.actions.length * 20.0 + 25, 100),
                    child: ListView(
                      children: workout.actions.entries
                          .map(
                            (acEntry) => Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text(
                                  acEntry.value.exercise.title,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${acEntry.value.number} ${acEntry.value.exercise.unit}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  acEntry.value.points.toString(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  )
              ],
            ),
          ),
        ));
  }
}
