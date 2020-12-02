import 'package:flutter/material.dart';
import 'package:kantnprojekt/providers/user.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

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
  RefreshController _refreshController = RefreshController(initialRefresh: false);

  void _onRefresh() async {
    // monitor network fetch
    print("Refreshing due to pull down on exercises view.");
    await Provider.of<exs.Exercises>(context, listen: false).fetchNew();
    await Provider.of<exs.Exercises>(context, listen: false).uploadOfflineExercises(saveAndNotifyIfChanged: true);
    // if failed,use refreshFailed()
    _refreshController.refreshCompleted();
  }

  // void _onLoading() async {
  //   // monitor network fetch
  //   await Future.delayed(Duration(milliseconds: 1000));
  //   // if failed,use loadFailed(),if no data return,use LoadNodata()
  //   print("Tried to load, should be turned off.");
  //   if (mounted) setState(() {});
  //   _refreshController.loadComplete();
  // }

  // @override
  // void didChangeDependencies() {
  //   if (_isInit) {
  //     setState(() {
  //       _isLoading = true;
  //     });
  //     if (Provider.of<exs.Exercises>(context, listen: false).exercises.length == 0) {
  //       print("init exercises in didChangedependencies");
  //       Provider.of<exs.Exercises>(context, listen: false).init().then((_) {
  //         _isInit = false;
  //         setState(() {
  //           _isLoading = false;
  //         });
  //       });
  //     } else {
  //       _isInit = false;
  //       setState(() {
  //         _isLoading = false;
  //       });
  //     }
  //   }
  //   super.didChangeDependencies();
  // }

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
            : SmartRefresher(
                enablePullDown: true,
                enablePullUp: false,
                header: WaterDropMaterialHeader(
                  backgroundColor: Theme.of(context).accentColor,
                  color: Theme.of(context).accentColor,
                ),
                controller: _refreshController,
                onRefresh: _onRefresh,
                // onLoading: _onLoading,
                child: ListView(children: <Widget>[
                  Container(
                    height: (MediaQuery.of(context).size.height - 82) * 0.99,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(7.0),
                      itemCount: userExercises.length,
                      itemBuilder: (ctx, i) => ExerciseItem(key: ValueKey(userExercises[i].localId), userExercise: userExercises[i]),
                    ),
                  ),
                ]),
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            String userId = Provider.of<User>(context, listen: false).userId;
            ex.Exercise exercise = ex.Exercise.newWithUserId(userId); // set uploaded to true so that the empty exercise is not uploaded!
            usEx.UserExercise userExercise = usEx.UserExercise.fromExercise(exercise);
            userExercise.uploaded = true;
            Provider.of<exs.Exercises>(context, listen: false).addExercise(exercise, saveAndNotifyIfChanged: false);
            Provider.of<exs.Exercises>(context, listen: false).addUserExercise(userExercise, saveAndNotifyIfChanged: true); // rebuilding the list
          },
          icon: Icon(Icons.add),
          label: Text("New Exercise"),
        ));
  }
}
