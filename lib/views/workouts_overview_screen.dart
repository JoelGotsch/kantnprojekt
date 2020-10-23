import 'package:flutter/material.dart';
import 'package:kantnprojekt/providers/user.dart';
import 'package:provider/provider.dart';

import '../providers/workout.dart' as wo;
import '../providers/workouts.dart' as wos;

import '../widgets/app_drawer.dart';
import '../widgets/workout_item.dart';

class WorkoutsOverviewScreen extends StatefulWidget {
  static const routeName = '/workouts';
  @override
  _WorkoutsOverviewScreenState createState() => _WorkoutsOverviewScreenState();
}

class _WorkoutsOverviewScreenState extends State<WorkoutsOverviewScreen> {
  var _isInit = true;
  var _isLoading = false;

  @override
  void didChangeDependencies() {
    if (_isInit) {
      setState(() {
        _isLoading = true;
      });
      print("init workouts in didChangedependencies");
      if (Provider.of<wos.Workouts>(context, listen: false).workouts.length ==
          0) {
        Provider.of<wos.Workouts>(context, listen: false).init().then((_) {
          setState(() {
            _isLoading = false;
          });
        });
      }
    }
    _isInit = false;
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    print("building WorkoutsOverviewScreen.");
    final workoutsData = Provider.of<wos.Workouts>(context);
    final List<wo.Workout> workouts = workoutsData.sortedWorkouts;
    return Scaffold(
        drawer: AppDrawer(),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(),
              )
            : SafeArea(
                child: ListView.builder(
                  padding: const EdgeInsets.all(7.0),
                  itemCount: workouts.length,
                  itemBuilder: (ctx, i) => ChangeNotifierProvider.value(
                    value: workouts[i],
                    child: WorkoutItem(key: ValueKey(workouts[i].workoutId)),
                  ),
                ),
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            String userId = Provider.of<User>(context, listen: false).userId;
            wo.Workout newWorkout = wo.Workout.newWithUserId(userId);
            Provider.of<wos.Workouts>(context, listen: false)
                .addWorkout(newWorkout);
          },
          icon: Icon(Icons.add),
          label: Text("New Workout"),
        ));
  }
}
