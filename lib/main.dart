import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import 'misc/color_definition.dart';

import 'providers/workouts.dart';
import 'providers/user.dart';
import 'providers/exercises.dart';

import 'views/auth_screen.dart';
import 'views/splash_screen.dart';
import 'views/workouts_overview_screen.dart';
import 'views/exercise_view.dart';
import 'views/challenge_overview.dart';

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
        //   create: (_) => Exercises(),
        // ),
        ChangeNotifierProxyProvider<User, Exercises>(
          create: (_) => Exercises.create(),
          update: (ctx, user, previousExercises) => Exercises.fromPrevious(user.token, user.userId, previousExercises),
        ),
        ChangeNotifierProxyProvider<Exercises, Workouts>(
            create: (_) => Workouts.create(), // note: init can't be run here, since user is not accessible
            update: (ctx, exercises, previousWorkouts) {
              bool updateActions = false;
              if (exercises.hashCode != previousWorkouts.exercises.hashCode && !previousWorkouts.loadingOnlineWorkouts) {
                // make sure, that if some userExercises/ Exercises where uploaded, that all actions refer to exerciseId
                updateActions = true;
              }
              Workouts newWos = Workouts.fromPrevious(
                exercises,
                previousWorkouts,
              );
              if (updateActions) {
                newWos.updateActionExerciseIds(exercises);
              }
              return (newWos);
            }),
      ],
      child: Consumer<User>(
        builder: (ctx, user, _) => RefreshConfiguration(
          footerBuilder: () => ClassicFooter(), // Configure default bottom indicator
          headerTriggerDistance: 80.0, // header trigger refresh trigger distance
          springDescription: SpringDescription(stiffness: 170, damping: 16, mass: 1.9), // custom spring back animate,the props meaning see the flutter api
          // maxOverScrollExtent: 100, //The maximum dragging range of the head. Set this property if a rush out of the view area occurs
          maxUnderScrollExtent: 0, // Maximum dragging range at the bottom
          enableScrollWhenRefreshCompleted:
              true, //This property is incompatible with PageView and TabBarView. If you need TabBarView to slide left and right, you need to set it to true.
          enableLoadingWhenFailed: true, //In the case of load failure, users can still trigger more loads by gesture pull-up.
          hideFooterWhenNotFull: false, // Disable pull-up to load more functionality when Viewport is less than one screen
          enableBallisticLoad: true, // trigger load more by BallisticScrollActivity
          // headerBuilder: () => WaterDropMaterialHeader(
          //   // Configure the default header indicator. If you have the same header indicator for each page, you need to set this
          //   semanticsLabel: "Test",
          //   distance: 200,
          //   backgroundColor: Theme.of(context).accentColor,
          //   color: Theme.of(context).accentColor,
          // ),
          child: MaterialApp(
            title: 'Kantnprojekt',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primarySwatch: generateMaterialColor(Color.fromRGBO(124, 222, 27, 1)),
              // accentColor: Colors.deepOrange,
              // fontFamily: 'Lato',
            ),
            home: user.isAuth
                ? WorkoutsOverviewScreen()
                : FutureBuilder(
                    future: user.tryAutoLogin(),
                    builder: (ctx, authResultSnapshot) => authResultSnapshot.connectionState == ConnectionState.waiting ? SplashScreen() : AuthScreen(),
                  ),
            routes: {
              WorkoutsOverviewScreen.routeName: (ctx) => WorkoutsOverviewScreen(),
              ExercisesOverviewScreen.routeName: (ctx) => ExercisesOverviewScreen(),
              ChallengesOverviewScreen.routeName: (ctx) => ChallengesOverviewScreen(),
            },
          ),
        ),
      ),
    );
  }
}
