import 'package:flutter/material.dart';
// import 'package:kantnprojekt/providers/exercises.dart';
import 'package:provider/provider.dart';
import 'providers/user.dart';
import 'misc/color_definition.dart';

import 'providers/workouts.dart';
import 'views/auth_screen.dart';
import 'views/splash_screen.dart';
import 'views/workouts_overview_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => User(),
        ),
        // ChangeNotifierProvider(
        //   create: (_) => Cart(),
        // ),
        // ChangeNotifierProxyProvider<User, Exercises>(
        //   create: null,
        //   update: (ctx, auth, previousExercises) => Exercises(
        //     auth.token,
        //     auth.userId,
        //     previousExercises == null ? [] : previousExercises.allExercises,
        //   ),
        // ),
        ChangeNotifierProxyProvider<User, Workouts>(
          create: null,
          update: (ctx, user, previousWorkouts) => Workouts(
            user.token,
            previousWorkouts == null ? {} : previousWorkouts.allWorkouts,
            previousWorkouts == null ? {} : previousWorkouts.allExercises,
          ),
        ),
      ],
      child: Consumer<User>(
        builder: (ctx, user, _) => MaterialApp(
          title: 'Kantnprojekt',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primarySwatch:
                generateMaterialColor(Color.fromRGBO(124, 222, 27, 1)),
            // accentColor: Colors.deepOrange,
            // fontFamily: 'Lato',
          ),
          home: user.isAuth
              ? WorkoutsOverviewScreen()
              : FutureBuilder(
                  future: user.tryAutoLogin(),
                  builder: (ctx, authResultSnapshot) =>
                      authResultSnapshot.connectionState ==
                              ConnectionState.waiting
                          ? SplashScreen()
                          : AuthScreen(),
                ),
          routes: {
            WorkoutsOverviewScreen.routeName: (ctx) => WorkoutsOverviewScreen(),
          },
        ),
      ),
    );
  }
}
