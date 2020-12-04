import 'dart:math';
// import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

import '../misc/functions.dart';
import '../providers/workout.dart';
import '../misc/user_exercise.dart';

class WorkoutOverview {
  double points;
  int noActions;
  int noWorkouts;
  final DateTime date;
  final int weekYearNr;
  final String weekDayAbbrev;
  int daysAgo; // TODO: should recalculate after midnight?

  WorkoutOverview(this.points, this.noActions, this.noWorkouts, this.date, this.weekYearNr, this.weekDayAbbrev, this.daysAgo);

  factory WorkoutOverview.fromDate(DateTime date) {
    int daysAgo = DateTime.now().difference(date).inDays;
    DateTime cleanDate = DateTime(date.year, date.month, date.day);
    String weekDayAbbrev = ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][date.weekday];
    return (WorkoutOverview(0.0, 0, 0, cleanDate, weekYearNumber(date), weekDayAbbrev, daysAgo));
  }

  @override
  String toString() {
    return ("$weekDayAbbrev ${date.day}.${date.month}: $points points, $noActions actions");
  }
}

class DailyStatus {
  final DateTime date;
  Map<String, double> pointsPerExercise = {}; //per ExerciseId to check for max_per_day
  Map<String, double> countExercisePerWeek = {}; //to check for weekly_allowance

  DailyStatus(this.date);
}

class WorkoutOverviews extends ChangeNotifier {
  Map<int, WorkoutOverview> workoutOverviews = {};
  Map<int, DailyStatus> dailyStatus = {};
  final Map<String, UserExercise> userExercises;
  Map<String, Map<String, double>> workoutPoints = {};

  WorkoutOverviews(this.userExercises);

  factory WorkoutOverviews.calc(Map<String, Workout> workouts, Map<String, UserExercise> userExercises) {
    // sort workouts to add earliest workout first:
    print("WorkoutOverviews is re-calculated..");
    List mapKeys = workouts.keys.toList(growable: false);
    mapKeys.sort((k1, k2) => workouts[k2].date.compareTo(workouts[k1].date));
    List<Workout> sortedWorkouts = [];
    mapKeys.forEach((k1) {
      sortedWorkouts.insert(0, workouts[k1]);
    });
    Map<String, UserExercise> newUserExercises = {};
    // because the actions in workouts refer to exercise ids and not user-exercise ids, we need to re-map here:
    userExercises.forEach((key, usEx) {
      newUserExercises.putIfAbsent(usEx.exercise.localId, () => usEx);
    });
    WorkoutOverviews woOverview = WorkoutOverviews(newUserExercises);
    for (Workout workout in sortedWorkouts) {
      woOverview.addWorkout(workout);
    }
    return (woOverview);
  }

// TODO: optional argument exercises to make it possible to work with UserExercises and ChallengeExercises
  void addWorkout(Workout wo) {
    WorkoutOverview ov;
    int daywynr = dayWeekYearNumber(wo.date);
    // if (daywynr == 20204405) {
    //   print("this is today!");
    // }
    if (workoutPoints.containsKey(wo.localId)) {
      print("Error: workout is added twice to workoutoverview!");
    }
    if (workoutOverviews.containsKey(daywynr)) {
      ov = workoutOverviews[daywynr];
    } else {
      ov = WorkoutOverview.fromDate(wo.date);
    }
    ov.noWorkouts += 1;
    workoutOverviews[daywynr] = ov;
    workoutPoints[wo.localId] = {};
    for (Action ac in wo.actions.values) {
      //initializing, will be updated
      workoutPoints[wo.localId][ac.actionId] = 0;
      this.addAction(ac, wo.date);
    }
  }

  bool setActionPoints(String actionId, double points) {
    // goes through all workouts to find actionId and inserts points
    workoutPoints.forEach((workoutId, actionList) {
      if (actionList.containsKey(actionId)) {
        actionList[actionId] = points;
        return (true);
      }
    });
    return (false);
  }

  double getActionPoints(String actionId) {
    // goes through all workouts to find actionId and inserts points
    workoutPoints.forEach((workoutId, actionList) {
      if (actionList.containsKey(actionId)) {
        return (actionList[actionId]);
      }
    });
    print("ERROR: couldnt find action $actionId in workoutoverviews.");
    return (.0);
  }

  double getWorkoutPoints(String workoutId) {
    double points = 0;
    if (workoutPoints.containsKey(workoutId)) {
      workoutPoints[workoutId].forEach((key, value) {
        points += value;
      });
    } else {
      print("ERROR: couldnt find workout $workoutId in workoutoverviews.");
      return (.0);
    }
    return (points);
  }

  bool addAction(Action action, DateTime date) {
    DailyStatus ds;
    WorkoutOverview ov;
    DateTime iterDate;
    int daywynr = dayWeekYearNumber(date);
    int wynr = weekYearNumber(date);
    int daynr = date.weekday;
    UserExercise usEx;
    double pointsBefore = 0;
    double actionPoints;
    userExercises.forEach((key, usEx2) {
      if (usEx2.exercise.localId == action.localExerciseId) {
        usEx = usEx2;
      } else if (usEx2.localId == action.exerciseId || usEx2.userExerciseId == action.localExerciseId || usEx2.userExerciseId == action.exerciseId) {
        print("ERROR in workouts_overview add_action: this is stragen, investigate!");
      }
    });
    if (usEx == null) {
      print("Error: couldn't find exerciseId ${action.localExerciseId} in list of userExercise-Exercises.");
      return (false);
    }

    if (dailyStatus.containsKey(daywynr)) {
      ds = dailyStatus[daywynr];
    } else {
      ds = DailyStatus(date);
    }
    if (workoutOverviews.containsKey(daywynr)) {
      ov = workoutOverviews[daywynr];
    } else {
      ov = WorkoutOverview.fromDate(date);
    }

    if (ds.countExercisePerWeek.containsKey(action.exerciseId)) {
      ds.countExercisePerWeek[action.exerciseId] += action.number;
    } else {
      ds.countExercisePerWeek[action.exerciseId] = action.number;
    }
    if (ds.pointsPerExercise.containsKey(action.exerciseId)) {
      pointsBefore = ds.pointsPerExercise[action.exerciseId];
      ds.pointsPerExercise[action.exerciseId] += action.number * usEx.points;
    } else {
      ds.pointsPerExercise[action.exerciseId] = action.number * usEx.points;
    }
    // making sure that not more than the maximum points per day can be achieved
    if (usEx.maxPointsDay > 0 && ds.pointsPerExercise[action.exerciseId] > usEx.maxPointsDay) {
      ds.pointsPerExercise[action.exerciseId] = usEx.maxPointsDay;
    }
    if (usEx.weeklyAllowance > 0) {
      ds.pointsPerExercise[action.exerciseId] = max(ds.countExercisePerWeek[action.exerciseId] - usEx.weeklyAllowance, 0) * usEx.points;
    }
    ov.noActions += 1;
    actionPoints = ds.pointsPerExercise[action.exerciseId] - pointsBefore;
    this.setActionPoints(action.actionId, actionPoints);
    ov.points += actionPoints;
    // ov.points = 0;
    // ds.pointsPerExercise.forEach((key, value) {
    //   ov.points += value;
    // });

    dailyStatus[daywynr] = ds;
    workoutOverviews[daywynr] = ov;

    // to be sure to accomodate for a weekly allowance, we have to calculate everything for the remainder of the week too.
    daynr += 1;
    iterDate = date.add(Duration(days: 1));
    while (daynr <= 7) {
      daywynr = wynr * 100 + daynr;
      if (dailyStatus.containsKey(daywynr)) {
        ds = dailyStatus[daywynr];
      } else {
        ds = DailyStatus(iterDate);
      }
      if (workoutOverviews.containsKey(daywynr)) {
        ov = workoutOverviews[daywynr];
      } else {
        ov = WorkoutOverview.fromDate(iterDate);
      }
      if (ds.countExercisePerWeek.containsKey(action.exerciseId)) {
        ds.countExercisePerWeek[action.exerciseId] += action.number;
      } else {
        ds.countExercisePerWeek[action.exerciseId] = action.number;
      }
      if (usEx.weeklyAllowance > 0) {
        ds.pointsPerExercise[action.exerciseId] = max(ds.countExercisePerWeek[action.exerciseId] - usEx.weeklyAllowance, 0) * usEx.points;
        // we dont need to change the action points in that case as the workouts are provided in a timeley ascending
        ov.points = 0;
        ds.pointsPerExercise.forEach((key, value) {
          ov.points += value;
        });
      }
      dailyStatus[daywynr] = ds;
      workoutOverviews[daywynr] = ov;
      daynr += 1;
      iterDate = iterDate.add(Duration(days: 1));
    }
    return (true);
  }

  List<WorkoutOverview> lastNDays(int noDays) {
    // first element of list is the noDays ago, last element is today
    //=> length of return list = noDays + 1
    List<WorkoutOverview> returnList = [];
    int daywynr;
    DateTime today = DateTime.now();
    DateTime iterDate;
    WorkoutOverview ov;
    for (int i in Iterable<int>.generate(noDays + 1).toList()) {
      iterDate = today.add(Duration(days: -i));
      daywynr = dayWeekYearNumber(iterDate);
      if (workoutOverviews.containsKey(daywynr)) {
        ov = workoutOverviews[daywynr];
      } else {
        ov = WorkoutOverview.fromDate(iterDate);
      }
      // returnList.add(ov);
      returnList.insert(0, ov);
    }
    return (returnList);
  }

  double pointsLastNDays(int noDays) {
    if (noDays < 1) {
      print("Exception: pointsLastNDays: noDays = $noDays");
      return (0);
    }
    List<WorkoutOverview> lastn = this.lastNDays(noDays - 1);
    double points = 0;
    lastn.forEach((element) {
      points += element.points;
    });
    return (points);
  }

  double pointsCurrWeek() {
    return (this.pointsLastNDays(DateTime.now().weekday));
  }

  //TODO: possible extension: not recalculating everything after each workouts-update, but also adding functionality for deleting workouts and actions here, called from workouts or vice versa.
}

// Map<String, int> noExerciseWeek(DateTime dayInWeek, {bool onlyBeforeDayInWeek: true}) {
//   // calculates for each exercise the number how often it was performed in a given week (optionally: before the given date)
//   int weeknr = weekYearNumber(dayInWeek);
//   Map<String, int> number = {};
//   _workouts.forEach((key, value) {
//     if (weekYearNumber(value.date) == weeknr && (!onlyBeforeDayInWeek || value.date.isBefore(dayInWeek))) {
//       value.actions.forEach((key2, value2) {
//         number[value2.exerciseId] += value2.number;
//       });
//     }
//   });
//   return (number);
// }

// Map<int, dynamic> weeklySummary() {
//   //returns for each "day_ago from 0..20" (3 weeks) the daily summary
//   Map<int, dynamic> returnMap = {};
//   List<int> helper = List<int>.generate(21, (index) => index);
//   helper.forEach((element) {
//     returnMap.putIfAbsent(element, () => this.dailySummary(element));
//   });
//   return (returnMap);
// }

//   factory WorkoutOverview.calc(int daysAgo, , Map<String, int> previousExercises) {
//     Map<String, dynamic> summary = {};
//     Map<String, double> pointsPerExercise = {}; //to check for max_per_day
//     double points = 0;
//     int noWorkouts = 0;
//     int noActions = 0;
//     DateTime previousDate = DateTime.now().add(Duration(days: -daysAgo));
//     summary["date"] = new DateFormat("EEE, d MMM yyyy").format(previousDate).toString();
//     workouts.forEach((key, value) {
//       if (value.date.isSameDate(previousDate)) {
//         // Map<String, int> previousExercises = noExerciseWeek(value.date, onlyBeforeDayInWeek: true);
//         value.actions.forEach((key2, ac) {
//           double thisPoints = 0;
//           if (previousExercises.containsKey(ac.exerciseId)) {
//             thisPoints = ac.pointsAllowance(previousExercises[ac.exerciseId]);
//           } else {
//             thisPoints = ac.points;
//           }
//           if (ac.exercise.maxPointsDay == 0) {
//             pointsPerExercise[ac.exerciseId] = pointsPerExercise[ac.exerciseId] + thisPoints;
//           } else {
//             pointsPerExercise[ac.exerciseId] = min(ac.exercise.maxPointsDay, pointsPerExercise[ac.exerciseId] + thisPoints);
//           }

//           noActions += 1;
//         });

//         // points += value.points;
//         noWorkouts += 1;
//       }
//     });
//     pointsPerExercise.forEach((key, value) {
//       points += value;
//     });

//     return (WorkoutsOverview(points, noActions, noWorkouts));
//   }
