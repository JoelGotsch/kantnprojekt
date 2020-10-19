import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../views/workouts_overview_screen.dart';
// import '../screens/user_products_screen.dart';
import '../providers/user.dart';

class AppDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: <Widget>[
          AppBar(
            title: Text('Hello Friend!'),
            automaticallyImplyLeading: false,
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.shop),
            title: Text('Workouts'),
            onTap: () {
              Navigator.of(context).pushReplacementNamed('/');
            },
          ),
          // Divider(),
          // ListTile(
          //   leading: Icon(Icons.payment),
          //   title: Text('Exercises'),
          //   onTap: () {
          //     Navigator.of(context)
          //         .pushReplacementNamed(ExercisesScreen.routeName);
          //   },
          // ),
          // Divider(),
          // ListTile(
          //   leading: Icon(Icons.edit),
          //   title: Text('Challenges'),
          //   onTap: () {
          //     Navigator.of(context)
          //         .pushReplacementNamed(UserProductsScreen.routeName);
          //   },
          // ),
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
