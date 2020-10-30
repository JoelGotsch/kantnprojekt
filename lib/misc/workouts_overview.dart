import 'dart:math';
// import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

import '../misc/functions.dart';
import '../providers/workout.dart';

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

  WorkoutOverviews();

  factory WorkoutOverviews.calc(Map<String, Workout> workouts) {
    WorkoutOverviews woOverview = WorkoutOverviews();
    for (Workout workout in workouts.values) {
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

    if (workoutOverviews.containsKey(daywynr)) {
      ov = workoutOverviews[daywynr];
    } else {
      ov = WorkoutOverview.fromDate(wo.date);
    }
    ov.noWorkouts += 1;
    workoutOverviews[daywynr] = ov;
    for (Action ac in wo.actions.values) {
      this.addAction(ac, wo.date);
    }
  }

  void addAction(Action action, DateTime date) {
    DailyStatus ds;
    WorkoutOverview ov;
    DateTime iterDate;
    int daywynr = dayWeekYearNumber(date);
    int wynr = weekYearNumber(date);
    int daynr = date.weekday;
    // print(action.exercise.title);

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
      ds.pointsPerExercise[action.exerciseId] += action.number * action.exercise.points;
    } else {
      ds.pointsPerExercise[action.exerciseId] = action.number * action.exercise.points;
    }
    // making sure that not more than the maximum points per day can be achieved
    if (action.exercise.maxPointsDay > 0 && ds.pointsPerExercise[action.exerciseId] > action.exercise.maxPointsDay) {
      ds.pointsPerExercise[action.exerciseId] = action.exercise.maxPointsDay;
    }
    if (action.exercise.weeklyAllowance > 0) {
      ds.pointsPerExercise[action.exerciseId] = max(ds.countExercisePerWeek[action.exerciseId] - action.exercise.weeklyAllowance, 0) * action.exercise.points;
    }
    ov.noActions += 1;
    ov.points = 0;
    ds.pointsPerExercise.forEach((key, value) {
      ov.points += value;
    });

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
      if (action.exercise.weeklyAllowance > 0) {
        ds.pointsPerExercise[action.exerciseId] = max(ds.countExercisePerWeek[action.exerciseId] - action.exercise.weeklyAllowance, 0) * action.exercise.points;
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
  }

  List<WorkoutOverview> lastNDays(int noDays) {
    // first element of list is the noDays ago, last element is today
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
    List<WorkoutOverview> lastn = this.lastNDays(noDays);
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
