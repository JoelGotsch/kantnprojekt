// import 'dart:ffi';
import 'dart:convert';
import 'dart:math';
// import 'dart:html';
// import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../misc/functions.dart';
import 'exercises.dart';

class Action {
  String actionId = getRandomString(20);
  String exerciseId;
  String workoutId;
  int number;
  String note;
  // double points;
  Exercise exercise;

  Action(
      this.exerciseId, this.workoutId, this.number, this.note, this.exercise);

  factory Action.fromJson(Map<String, dynamic> parsedJson, workoutId) {
    Exercise ex;
    Exercises exs = Exercises();
    exs.init();
    // this is probably inefficient as a new object is created each time, one is sufficient and cleaner!
    try {
      ex = Exercise.fromJson(parsedJson['exercise']);
    } catch (e) {
      ex = exs.getExercise(parsedJson['exercise_id']);
    }

    Action ac = Action(
      parsedJson['exercise_id'],
      workoutId,
      parsedJson['number'],
      parsedJson['note'],
      ex,
    );
    if (parsedJson['actionId'] != null) {
      ac.actionId = parsedJson['actionId'];
      // } else {
      //   ac.actionId = getRandomString(20);
    }
    return (ac);
  }

  double get points {
    return this.number * this.exercise.points;
  }

  double pointsAllowance(int number) {
    // returns points given that this exercise was already done *number* of times this week (adjusting for weekly allowance)
    int remainingAllowance = max(this.exercise.weeklyAllowance - number, 0);
    return ((this.number - remainingAllowance) * this.exercise.points);
  }

  @override
  String toString() {
    return (json.encode({
      'id': actionId,
      'exercise_id': exerciseId,
      'workout_id': workoutId,
      'number': number,
      'note': note,
      'points': this.points,
    }));
  }
}

class Workout {
  String workoutId; //later from database, provided by API
  String localId;
  String userId;
  DateTime date;
  DateTime latestEdit = DateTime.now();
  String note;
  Map<String, Action> actions; //actionId:action
  bool _uploaded = false;
  bool _notDeleted = true;

  bool get isUploaded {
    return (_uploaded);
  }

  Workout(this.workoutId, this.localId, this.userId, this.date, this.note);

  factory Workout.fromJson(Map<String, dynamic> parsedJson) {
    String id;
    if (parsedJson['id'].toString().length > 0) {
      id = parsedJson['id'];
    } else {
      id = parsedJson['local_id'];
    }
    Workout wo = Workout(
      parsedJson['id'],
      id,
      parsedJson['user_id'].toString(),
      DateTime.parse(parsedJson['date']),
      parsedJson['note'].toString(),
      // parsedJson['points'],
    );
    wo.latestEdit = DateTime.parse(parsedJson['latest_edit']);
    if (parsedJson['uploaded'] != null) {
      // from phone storage
      wo._uploaded = parsedJson['uploaded'];
    } else {
      // from api, no "uploaded" field is provided
      wo._uploaded = true;
    }
    if (parsedJson['not_deleted'] != null) {
      // from phone storage
      wo._notDeleted = parsedJson['not_deleted'];
    }
    // add exercises
    (parsedJson['actions'] as Map<String, Action>).forEach((key, value) {
      wo.addAction(
          Action.fromJson(value as Map<String, dynamic>, wo.workoutId));
    });
    return (wo);
  }

  double get points {
    double points = 0.0;
    actions.forEach((key, value) {
      points += value.points;
    });
    return points;
  }

  @override
  String toString() {
    final String actionsStr = json.encode(actions);
    // json.encode(Map.fromIterable(actions, key: (e) => e.workoutId, value: (e) => e.toString()));
    print("action_str:\\" + actionsStr);
    return (json.encode({
      'id': workoutId,
      'local_id': localId,
      'user_id': userId,
      // 'date': new DateFormat("EEE, d MMM yyyy HH:mm:ss vvv").format(date),
      'date': date.toIso8601String(),
      'latest_edit': latestEdit.toIso8601String(),
      'note': note,
      'points': points,
      'actions': actionsStr,
      'not_deleted': _notDeleted,
      // 'uploaded': _uploaded,
    }));
  }

  void addAction(Action ac) {
    // can have mulitple actions of same exercise (i.e. mulitple push-up Exercises)
    if (actions.containsKey(ac.actionId)) {
      // update action
      Action oldAc = actions[ac.actionId];
      oldAc.note = ac.note;
      oldAc.exerciseId = ac.exerciseId;
      oldAc.number = ac.number;
      oldAc.exercise = ac.exercise;
    } else {
      // create new
      actions.putIfAbsent(ac.actionId, () => ac);
    }

    // this.points += ac.points;
    _uploaded = false;
    latestEdit = DateTime.now();
  }

  void deleteAction(String actionId) {
    // Action ac = actions[actionId];
    // this.points -= ac.points;
    actions.removeWhere((key, value) => key == actionId);
    _uploaded = false;
    latestEdit = DateTime.now();
  }
}

class Workouts with ChangeNotifier {
  // manages all the workout- objects: making sure they are uploaded/
  Map<String, Workout> _workouts;
  String _token;
  String _userId;
  // final String uri = "http://api.kantnprojekt.club/v0_1/test";
  final String uri = "http://api.kantnprojekt.club/v0_1/workouts";

  void init() async {
    // loads workouts from sharedPreferences (i.e. Phone storage)
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> _json = json.decode(prefs.getString("Workouts"));
    _json.forEach((key, value) {
      _workouts.putIfAbsent(value.id, () => Workout.fromJson(value));
    });
    notifyListeners();
  }

  Map<String, Workout> get workouts {
    Map<String, Workout> notDeletedWorkouts;
    _workouts.forEach((key, value) {
      if (value._notDeleted) {
        notDeletedWorkouts.putIfAbsent(key, () => value);
      }
    });
    return {...notDeletedWorkouts};
  }

  void save() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('Workouts', this.toString());
  }

  Future<Map<String, Workout>> _fetch(
      {String workoutId,
      DateTime startDate,
      DateTime endDate,
      int number = 0}) async {
    // deletes all locally stored exercises and loads the complete list from online database and stores values in sharedPreferences
    Map<String, Workout> newWorkouts = {};
    Map<String, String> queryParameters = {};
    if (workoutId != null) {
      queryParameters["workout_id"] = workoutId;
    }
    if (startDate != null) {
      queryParameters["start_date"] = startDate.toIso8601String();
    }
    if (endDate != null) {
      queryParameters["end_date"] = endDate.toIso8601String();
    }
    queryParameters["number"] = number.toString();
    String url = Uri(
      host: uri,
      queryParameters: queryParameters,
    ).toString();
    print("fetch Url=" + url);
    final response = await http.get(
      url,
      headers: {
        "token": _token,
        "user_id": _userId,
      },
    );
    final Map result = json.decode(response.body);
    print(response.statusCode);
    print("fetch workouts result:\\" + result.toString());

    if (response.statusCode == 201 || response.statusCode == 200) {
      // for (Map json_ in result["data"]) {
      for (Map json_ in result.values) {
        try {
          newWorkouts.putIfAbsent(json_["id"], () => Workout.fromJson(json_));
        } catch (Exception) {
          print(Exception);
        }
      }
    } else {
      // If that call was not successful, throw an error.
      throw Exception('Failed to load Workout');
    }
    return (newWorkouts);
  }

  Future<void> fetchAll() async {
    Map<String, Workout> allWorkouts = await this._fetch();
    if (allWorkouts.length > 0) {
      _workouts = allWorkouts;
      notifyListeners();
      this.save();
    }
  }

  Future<void> fetchNew() async {
    List<DateTime> workoutTimes = [];
    _workouts.forEach((key, value) => workoutTimes.add(value.latestEdit));
    DateTime newestDate = calcMaxDate(workoutTimes);
    Map<String, Workout> newWorkouts = await this._fetch(startDate: newestDate);
    if (newWorkouts.length > 0) {
      newWorkouts.forEach((key, value) {
        _workouts[key] = value;
      });
      notifyListeners();
      this.save();
    }
  }

  @override
  String toString() {
    // returns a list with names consistent with database (e.g. id instead of workoutId)
    // includes deleted workouts!

    // Map<String, Workout> notDeletedWorkouts;
    // workouts.forEach((key, value) {
    //   if (value._notDeleted) {
    //     notDeletedWorkouts[key] = value;
    //   }
    // });
    // String str = json.encode(notDeletedWorkouts);
    String str = json.encode(_workouts);
    print("Workouts string:\\" + str);
    return (str);
  }

  void fromString(String str) {
    Map<String, dynamic> parsedJson = json.decode(str);
    this.fromJson(parsedJson);
  }

  void fromJson(Map<String, dynamic> parsedJson) {
    parsedJson.forEach((key, value) {
      print(key);
      print(value);
      _workouts.putIfAbsent(value["id"], () => Workout.fromJson(value));
    });
  }

  void addWorkout(Workout wo) {
    //upload with future.then(set _uploaded=true)
    // add to workouts
    if (_workouts.containsKey(wo.localId) ||
        _workouts.containsKey(wo.workoutId)) {
      // update existing workout
      Workout oldWo;
      if (_workouts.containsKey(wo.localId)) {
        oldWo = _workouts[wo.localId];
      } else {
        oldWo = _workouts[wo.workoutId];
      }
      oldWo.actions = wo.actions;
      oldWo.date = wo.date;
      oldWo.latestEdit = DateTime.now();
      oldWo.note = wo.note;
      oldWo._uploaded = wo._uploaded;
    } else {
      _workouts[wo.localId] = wo;
    }
    notifyListeners();
    this.syncronize();
  }

  void deleteWorkout(String workoutId) {
    Workout wo = _workouts[workoutId];
    wo._notDeleted = false;
    wo._uploaded = false;
    // _workouts.removeWhere((key, value) => false);
    notifyListeners();
    this.syncronize();
  }

  void addAction(Action ac) {
    Workout wo = _workouts[ac.workoutId];
    wo.addAction(ac);
    notifyListeners();
    this.syncronize();
  }

  void deleteAction(Action ac) {
    Workout wo = _workouts[ac.workoutId];
    wo.deleteAction(ac.actionId);
    notifyListeners();
    this.syncronize();
  }

  Future<bool> syncronize() async {
    // tries to upload all not uploaded workouts and updates the Ids, then saves to shared_preferences
    Map<String, Workout> offlineWorkouts;
    _workouts.forEach((key, value) {
      if (!value.isUploaded) {
        offlineWorkouts.putIfAbsent(key, () => value);
      }
    });
    if (offlineWorkouts.length == 0) {
      return (true);
    }
    final response = await http.post(uri,
        headers: {
          "token": _token,
          "user_id": _userId,
        },
        body: json.encode(offlineWorkouts));
    final result =
        json.decode(response.body) as Map<String, String>; //localId:workoutId
    print(response.statusCode);
    if (response.statusCode == 201) {
      result.forEach((_localId, _workoutId) {
        if (_workoutId != null) {
          Workout wo = _workouts[_localId];
          wo.workoutId = _workoutId;
          wo._uploaded = true;
          wo.actions.forEach((key, ac) {
            ac.workoutId = _workoutId;
          });
          _workouts.removeWhere((key, value) => value.localId == key);
          _workouts[_workoutId] = wo;
        }
      });
    } else {
      print("Couldn't sync workouts.");
      return (false);
    }
    this.save();
    notifyListeners();
    return (true);
  }

  Map<String, int> noExerciseWeek(DateTime dayInWeek,
      {bool onlyBeforeDayInWeek: true}) {
    // calculates for each exercise the number how often it was performed in a given week (optionally: before the given date)
    int weeknr = weekNumber(dayInWeek);
    Map<String, int> number;
    _workouts.forEach((key, value) {
      if (weekNumber(value.date) == weeknr &&
          (!onlyBeforeDayInWeek || value.date.isBefore(dayInWeek))) {
        value.actions.forEach((key2, value2) {
          number[value2.exerciseId] += value2.number;
        });
      }
    });
    return (number);
  }

  Map<String, String> dailySummary(int daysAgo) {
    // Map<String, Workout> workoutsDay;
    Map<String, dynamic> summary;
    Map<String, double> pointsPerExercise; //to check for max_per_day
    double points = 0;
    int noWorkouts = 0;
    int noActions = 0;
    DateTime previousDate = DateTime.now().add(Duration(days: -daysAgo));
    summary["date"] =
        new DateFormat("EEE, d MMM yyyy").format(previousDate).toString();
    _workouts.forEach((key, value) {
      if (value.date.isSameDate(previousDate)) {
        // workoutsDay[key] = value;
        Map<String, int> previousExercises =
            noExerciseWeek(value.date, onlyBeforeDayInWeek: true);
        value.actions.forEach((key2, ac) {
          double thisPoints = 0;
          if (previousExercises.containsKey(ac.exerciseId)) {
            thisPoints = ac.pointsAllowance(previousExercises[ac.exerciseId]);
          } else {
            thisPoints = ac.points;
          }
          if (ac.exercise.maxPointsDay == 0) {
            pointsPerExercise[ac.exerciseId] =
                pointsPerExercise[ac.exerciseId] + thisPoints;
          } else {
            pointsPerExercise[ac.exerciseId] = min(ac.exercise.maxPointsDay,
                pointsPerExercise[ac.exerciseId] + thisPoints);
          }

          noActions += 1;
        });

        // points += value.points;
        noWorkouts += 1;
      }
    });
    pointsPerExercise.forEach((key, value) {
      points += value;
    });

    summary["points"] = points;
    summary["noActions"] = noActions;
    summary["noWorkouts"] = noWorkouts;

    return (summary);
  }

  // Todo:
}
