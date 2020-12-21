import 'package:flutter/material.dart';
import 'package:kantnprojekt/providers/user.dart';
import 'package:provider/provider.dart';
// import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../providers/workout.dart' as wo;
import '../providers/workouts.dart' as wos;
import '../providers/exercises.dart';

import '../widgets/app_drawer.dart';
import '../widgets/weekly_view.dart';
import '../widgets/workout_item.dart';

import '../misc/user_exercise.dart';
import '../misc/workouts_overview.dart';

class WorkoutsOverviewScreen extends StatefulWidget {
  static const routeName = '/workouts';
  @override
  _WorkoutsOverviewScreenState createState() => _WorkoutsOverviewScreenState();
}

class _WorkoutsOverviewScreenState extends State<WorkoutsOverviewScreen> {
  var _isLoading = false;

  Future<void> _onRefresh() async {
    // monitor network fetch
    await Provider.of<wos.Workouts>(context, listen: false).fetchNew();
    await Provider.of<wos.Workouts>(context, listen: false).uploadOfflineWorkouts(saveAndNotifyIfChanged: true);
    // if failed,use refreshFailed()
  }

  // void _onLoading() async {
  //   // monitor network fetch
  //   await Future.delayed(Duration(milliseconds: 1000));
  //   // if failed,use loadFailed(),if no data return,use LoadNodata()
  //   print("Tried to load, should be turned off.");
  //   if (mounted) setState(() {});
  //   _refreshController.loadComplete();
  // }

  @override
  Widget build(BuildContext context) {
    print("building WorkoutsOverviewScreen.");
    final workoutsData = Provider.of<wos.Workouts>(context);
    final List<wo.Workout> sortedWorkouts = workoutsData.sortedWorkouts;
    print("workouts _loading: ${workoutsData.loadingOnlineWorkouts}, ${workoutsData.exercises.loadedOnlineExercises}");
    _isLoading = workoutsData.loadingOnlineWorkouts || !workoutsData.exercises.loadedOnlineExercises;
    final Map<String, wo.Workout> workouts = workoutsData.workouts;
    final Map<String, UserExercise> usExs = Provider.of<Exercises>(context).userExercises;
    final Map<String, UserExercise> visibleUsExs = Provider.of<Exercises>(context).exercises;
    final WorkoutOverviews wovs = WorkoutOverviews.calc(workouts, usExs);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Workouts",
          style: TextStyle(color: Colors.white70),
        ),
      ),
      drawer: AppDrawer(),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _onRefresh,
              // onLoading: _onLoading,
              child: ListView(children: <Widget>[
                Container(
                  height: (MediaQuery.of(context).size.height - 82) * 0.27,
                  child: WeeklySummary(wovs),
                ),
                Container(
                  height: (MediaQuery.of(context).size.height - 82 - 100) * 0.73,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(7.0),
                    itemCount: sortedWorkouts.length,
                    itemBuilder: (ctx, i) => ChangeNotifierProvider.value(
                      value: sortedWorkouts[i],
                      child: WorkoutItem(
                        key: ValueKey(sortedWorkouts[i].localId),
                        workoutPoints: wovs.getWorkoutPoints(sortedWorkouts[i].localId),
                        workout: sortedWorkouts[i],
                        userExercises: visibleUsExs,
                      ),
                    ),
                  ),
                ),
              ]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          String userId = Provider.of<User>(context, listen: false).userId;
          wo.Workout newWorkout = wo.Workout.newWithUserId(userId);
          Provider.of<wos.Workouts>(context, listen: false).addWorkout(newWorkout);
          setState(() {});
        },
        icon: Icon(Icons.add),
        label: Text("New Workout"),
      ),
    );
  }
}
