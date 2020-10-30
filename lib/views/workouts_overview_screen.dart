import 'package:flutter/material.dart';
import 'package:kantnprojekt/providers/user.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../providers/workout.dart' as wo;
import '../providers/workouts.dart' as wos;

import '../widgets/app_drawer.dart';
import '../widgets/weekly_view.dart';
import '../widgets/workout_item.dart';

class WorkoutsOverviewScreen extends StatefulWidget {
  static const routeName = '/workouts';
  @override
  _WorkoutsOverviewScreenState createState() => _WorkoutsOverviewScreenState();
}

class _WorkoutsOverviewScreenState extends State<WorkoutsOverviewScreen> {
  var _isInit = true;
  var _isLoading = false;
  RefreshController _refreshController = RefreshController(initialRefresh: false);

  void _onRefresh() async {
    // monitor network fetch
    await Provider.of<wos.Workouts>(context, listen: false).fetchNew();
    // if failed,use refreshFailed()
    _refreshController.refreshCompleted();
  }

  void _onLoading() async {
    // monitor network fetch
    await Future.delayed(Duration(milliseconds: 1000));
    // if failed,use loadFailed(),if no data return,use LoadNodata()
    print("Tried to load, should be turned off.");
    if (mounted) setState(() {});
    _refreshController.loadComplete();
  }

  @override
  void didChangeDependencies() {
    if (_isInit) {
      setState(() {
        _isLoading = true;
      });
      if (Provider.of<wos.Workouts>(context, listen: false).workouts.length == 0) {
        print("init workouts in didChangedependencies");
        Provider.of<wos.Workouts>(context, listen: false).init().then((_) {
          _isInit = false;
          setState(() {
            _isLoading = false;
          });
        });
      } else {
        _isInit = false;
        setState(() {
          _isLoading = false;
        });
      }
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    print("building WorkoutsOverviewScreen.");
    final workoutsData = Provider.of<wos.Workouts>(context);
    final List<wo.Workout> workouts = workoutsData.sortedWorkouts;
    return Scaffold(
        appBar: AppBar(),
        drawer: AppDrawer(),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(),
              )
            : SafeArea(
                child: SmartRefresher(
                  enablePullDown: true,
                  enablePullUp: false,
                  header: WaterDropMaterialHeader(
                    // Configure the default header indicator. If you have the same header indicator for each page, you need to set this
                    // semanticsLabel: "Test",
                    // distance: 200,
                    backgroundColor: Theme.of(context).accentColor,
                    color: Theme.of(context).accentColor,
                  ),
                  controller: _refreshController,
                  onRefresh: _onRefresh,
                  onLoading: _onLoading,
                  child: Column(children: <Widget>[
                    Container(
                      height: (MediaQuery.of(context).size.height - 82) * 0.27,
                      child: WeeklySummary(),
                    ),
                    Container(
                      height: (MediaQuery.of(context).size.height - 82) * 0.73,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(7.0),
                        itemCount: workouts.length,
                        itemBuilder: (ctx, i) => ChangeNotifierProvider.value(
                          value: workouts[i],
                          child: WorkoutItem(key: ValueKey(workouts[i].workoutId)),
                        ),
                      ),
                    ),
                  ]),
                ),
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
        ));
  }
}
