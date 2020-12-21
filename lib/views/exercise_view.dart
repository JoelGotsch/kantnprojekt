import 'package:flutter/material.dart';
import 'package:kantnprojekt/providers/user.dart';
import 'package:provider/provider.dart';

import '../misc/exercise.dart' as ex;
import '../misc/user_exercise.dart' as usEx;
import '../providers/exercises.dart' as exs;

import '../widgets/app_drawer.dart';
import '../widgets/exercise_item.dart';

class ExercisesOverviewScreen extends StatefulWidget {
  static const routeName = '/exercises';
  @override
  _ExercisesOverviewScreenState createState() => _ExercisesOverviewScreenState();
}

class _ExercisesOverviewScreenState extends State<ExercisesOverviewScreen> {
  // var _isInit = true;
  var _isLoading = false;

  Future<void> _onRefresh() async {
    // monitor network fetch
    print("Refreshing due to pull down on exercises view.");
    await Provider.of<exs.Exercises>(context, listen: false).fetchNew();
    await Provider.of<exs.Exercises>(context, listen: false).uploadOfflineExercises(saveAndNotifyIfChanged: true);
    // if failed,use refreshFailed()
  }

  @override
  Widget build(BuildContext context) {
    print("building ExerciseOverview.");
    final List<usEx.UserExercise> userExercises = Provider.of<exs.Exercises>(context).sortedUserExercises;
    // print(userExercises);
    return Scaffold(
        appBar: AppBar(
          title: Text(
            "Exercises",
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
                child: Container(
                  height: (MediaQuery.of(context).size.height - 82) * 0.99,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(7.0),
                    itemCount: userExercises.length,
                    itemBuilder: (ctx, i) => ExerciseItem(key: ValueKey(userExercises[i].localId), userExercise: userExercises[i]),
                  ),
                ),
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            String userId = Provider.of<User>(context, listen: false).userId;
            ex.Exercise exercise = ex.Exercise.newWithUserId(userId); // set uploaded to true so that the empty exercise is not uploaded!
            usEx.UserExercise userExercise = usEx.UserExercise.fromExercise(exercise);
            userExercise.uploaded = true;
            exercise.uploaded = true;
            Provider.of<exs.Exercises>(context, listen: false).addExercise(exercise, saveAndNotifyIfChanged: false);
            Provider.of<exs.Exercises>(context, listen: false).addUserExercise(userExercise, saveAndNotifyIfChanged: true); // rebuilding the list
          },
          icon: Icon(Icons.add),
          label: Text("New Exercise"),
        ));
  }
}
