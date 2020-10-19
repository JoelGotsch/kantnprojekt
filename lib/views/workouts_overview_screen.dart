import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/workouts.dart';
import '../widgets/app_drawer.dart';
import '../widgets/workouts_grid.dart';
import 'edit_workout.dart';

class WorkoutsOverviewScreen extends StatefulWidget {
  @override
  _WorkoutsOverviewScreenState createState() => _WorkoutsOverviewScreenState();
}

class _WorkoutsOverviewScreenState extends State<WorkoutsOverviewScreen> {
  var _isInit = true;
  var _isLoading = false;

  @override
  void initState() {
    // Provider.of<Workouts>(context).fetchAndSetWorkouts(); // WON'T WORK!
    // Future.delayed(Duration.zero).then((_) {
    //   Provider.of<Workouts>(context).fetchAndSetWorkouts();
    // });
    super.initState();
  }

  @override
  void didChangeDependencies() {
    if (_isInit) {
      setState(() {
        _isLoading = true;
      });
      Provider.of<Workouts>(context).init().then((_) {
        setState(() {
          _isLoading = false;
        });
      });
    }
    _isInit = false;
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        //   appBar: AppBar(
        //     title: Text('MyShop'),
        //     actions: <Widget>[
        //       Consumer<Workouts>(
        //         builder: (_, workout, ch) => Badge(
        //           child: ch,
        //           value: workout.itemCount.toString(),
        //         ),
        //         child: IconButton(
        //           icon: Icon(
        //             Icons.edit,
        //           ),
        //           onPressed: () {
        //             Navigator.of(context).pushNamed(EditWorkoutScreen.routeName);
        //           },
        //         ),
        //       ),
        //     ],
        //   ),
        drawer: AppDrawer(),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(),
              )
            : WorkoutsGrid(),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context).pushNamed(
              EditWorkoutScreen.routeName,
              arguments: null,
            );
          },
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white70,
          icon: Icon(Icons.add),
          label: Text("New Workout"),
        ));
  }
}

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';

// import '../providers/workouts.dart' show Workouts;
// import '../widgets/workout_item.dart';
// import '../widgets/app_drawer.dart';

// class WorkoutsScreen extends StatelessWidget {
//   static const routeName = '/workouts';

//   @override
//   Widget build(BuildContext context) {
//     print('building orders');
//     // final orderData = Provider.of<Orders>(context);
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Your Orders'),
//       ),
//       drawer: AppDrawer(),
//       body: FutureBuilder(
//         future: Provider.of<Workouts>(context, listen: false).fetchAll(),
//         builder: (ctx, dataSnapshot) {
//           if (dataSnapshot.connectionState == ConnectionState.waiting) {
//             return Center(child: CircularProgressIndicator());
//           } else {
//             if (dataSnapshot.error != null) {
//               // ...
//               // Do error handling stuff
//               return Center(
//                 child: Text('An error occurred!'),
//               );
//             } else {
//               return Consumer<Workouts>(
//                 builder: (ctx, orderData, child) => ListView.builder(
//                   itemCount: orderData.workouts.length,
//                   itemBuilder: (ctx, i) => WorkoutItem(orderData.workouts[i]),
//                 ),
//               );
//             }
//           }
//         },
//       ),
//     );
//   }
// }
