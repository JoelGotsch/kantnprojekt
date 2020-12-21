import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../views/workouts_overview_screen.dart';
import '../views/exercise_view.dart';
import '../views/challenge_overview.dart';
// import '../screens/user_products_screen.dart';
import '../providers/user.dart';

class AppDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final String userName = Provider.of<User>(context, listen: false).userName;
    return Drawer(
      child: Column(
        children: <Widget>[
          AppBar(
            title: Text('Hello $userName!'),
            // automaticallyImplyLeading: false,
          ),
          Divider(),
          ListTile(
            leading: FaIcon(FontAwesomeIcons.running),
            title: Text('Workouts'),
            onTap: () {
              Navigator.of(context).pushReplacementNamed(WorkoutsOverviewScreen.routeName);
            },
          ),
          Divider(),
          ListTile(
            leading: FaIcon(FontAwesomeIcons.dumbbell),
            title: Text("Exercises"),
            onTap: () {
              Navigator.of(context).pushReplacementNamed(ExercisesOverviewScreen.routeName);
            },
          ),
          Divider(),
          ListTile(
            leading: FaIcon(FontAwesomeIcons.trophy),
            title: Text("Challenges"),
            onTap: () {
              Navigator.of(context).pushReplacementNamed(ChallengesOverviewScreen.routeName);
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.exit_to_app),
            title: Text('Logout'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacementNamed('/');

              // Navigator.of(context)
              //     .pushReplacementNamed(UserProductsScreen.routeName);
              Provider.of<User>(context, listen: false).logout();
            },
          ),
        ],
      ),
    );
  }
}
