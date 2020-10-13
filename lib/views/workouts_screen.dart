import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/routes.dart';

class AddWorkoutScreen extends StatefulWidget {
  final String apiKey;
  AddWorkoutScreen({this.apiKey});

  @override
  AddWorkoutScreenState createState() => AddWorkoutScreenState();
}

class AddWorkoutScreenState extends State<AddWorkoutScreen> {
  List<Workout> workouts = [];
  WorkoutBloc workoutBloc;

  @override
  void initState() {
    workoutBloc = WorkoutBloc(widget.apiKey);
  }

  @override
  void dispose() {
    super.dispose();
  }

  // AddWorkoutScreenState();
  Widget build(BuildContext context) {
    return Container(
        color: Colors.grey, //darkGrey
        child: StreamBuilder(
          // Wrap our widget with a StreamBuilder
          stream: workoutBloc.getWorkouts, // pass our Stream getter here
          initialData: [], // provide an initial data
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot != null) {
              if (snapshot.data.length > 0) {
                return _buildListSimple(context, snapshot.data);
              } else if (snapshot.data.length == 0) {
                return Center(child: Text('No Data'));
              }
            } else if (snapshot.hasError) {
              return Container();
            }
            return CircularProgressIndicator();
          }, // access the data in our Stream here
        )
        // child: ReorderableListView(∆
        //   padding: EdgeInsets.only(top: 300),
        //   children: todoItems,
        //   onReorder: _onReorder,
        // ),
        );
  }

  Widget _buildListSimple(BuildContext context, List<Workout> workoutList) {
    return Theme(
      data: ThemeData(canvasColor: Colors.transparent),
      child: ListView(
        padding: EdgeInsets.only(top: 300.0),
        children: workoutList
            .map((Workout item) => _buildListTile(context, item))
            .toList(),
      ),
    );
  }

  Widget _buildListTile(BuildContext context, Workout item) {
    return ListTile(
      leading: Icon(Icons.account_circle),
      key: Key(item.workoutId.toString()),
      title: Text(DateFormat('EEE, MMM d').format(item.date)),
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.menu),
      subtitle: generateSubtitleWorkout(item),
      isThreeLine: true,
      dense: true,
    );
  }

  Text generateSubtitleWorkout(wo) {
    return (Text(""));
  }

  Widget _workoutTitle(BuildContext context, Workout wo) {}
}

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:cached_network_image/cached_network_image.dart';

// class AddWorkoutScreen extends StatefulWidget {
//   AddWorkoutScreen();

//   @override
//   AddWorkoutScreenState createState() => AddWorkoutScreenState();
// }

// class AddWorkoutScreenState extends State<AddWorkoutScreen> {
//   AddWorkoutScreenState();

//   _launchURL(String url) async {
//     if (await canLaunch(url)) {
//       await launch(url);
//     } else {
//       throw 'Could not launch $url';
//     }
//   }

//   Widget build(BuildContext context) {
//     return Scaffold(
//       floatingActionButton: null,
//       body: StreamBuilder(
//           stream: FirebaseFirestore.instance.collection('Articles').snapshots(),
//           builder:
//               (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
//             if (!snapshot.hasData) {
//               return Center(
//                 child: CircularProgressIndicator(),
//               );
//             }

//             return ListView(
//               children: snapshot.data.docs.map((document) {
//                 return Padding(
//                   padding: EdgeInsets.only(top: 15),
//                   child: Container(
//                     width: MediaQuery.of(context).size.width / 1.2,
//                     decoration: BoxDecoration(
//                       borderRadius: BorderRadius.circular(15.0),
//                       color: Color(0xff8c52ff),
//                     ),
//                     child: MaterialButton(
//                       onPressed: () {
//                         _launchURL(document['url']);
//                       },
//                       child: Column(
//                         children: <Widget>[
//                           Padding(
//                             padding: EdgeInsets.symmetric(vertical: 10),
//                             child: Text(document['title'], style: TextStyle(color: Colors.white,)),
//                           ),
//                           Padding(
//                             padding: EdgeInsets.symmetric(vertical: 10),
//                             child: CachedNetworkImage(
//                               imageUrl: document['image'],
//                               placeholder: (context, url) =>
//                                   CircularProgressIndicator(),
//                               errorWidget: (context, url, error) => Icon(
//                                 Icons.error,
//                                 color: Colors.red,
//                               ),
//                             )
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 );
//               }).toList(),
//             );
//           }),
//     );
//   }
// }
