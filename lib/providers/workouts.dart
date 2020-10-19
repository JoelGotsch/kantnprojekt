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

  factory Action.fromJson(Map<String, dynamic> parsedJson, workoutId,
      {Exercise exercise}) {
    Exercise ex;
    // Exercises exs = Exercises();
    // exs.init();
    // this is probably inefficient as a new object is created each time, one is sufficient and cleaner!
    try {
      if (exercise != null) {
        ex = exercise;
      } else {
        ex = Exercise.fromJson(parsedJson['exercise']);
      }
    } catch (e) {
      throw Exception("Exercise was not part of the Action-information");
      // ex = exs.getExercise(parsedJson['exercise_id']);
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

  Map<String, dynamic> toJson() {
    return ({
      'id': actionId,
      'exercise_id': exerciseId,
      'exercise': exercise.toJson(),
      'workout_id': workoutId,
      'number': number,
      'note': note,
      'points': points,
    });
  }

  @override
  String toString() {
    return (json.encode(this.toJson()));
  }
}

class Workout with ChangeNotifier {
  String workoutId; //later from database, provided by API
  String localId;
  String userId;
  DateTime date = DateTime.now();
  DateTime latestEdit = DateTime.now();
  String note = "";
  Map<String, Action> actions = {}; //actionId:action
  bool _uploaded = false;
  bool _notDeleted = true;

  bool get isUploaded {
    return (_uploaded);
  }

  Workout({this.workoutId, this.localId, this.userId, this.date, this.note});

  // set workoutId(String woId) {
  //   this.workoutId = woId;
  // }

  factory Workout.newWithUserId(userId) {
    return (Workout(
        workoutId: null,
        localId: getRandomString(20),
        userId: userId,
        date: DateTime.now(),
        note: ""));
  }

  factory Workout.fromJson(Map<String, dynamic> parsedJson) {
    String id;
    if (parsedJson['id'].toString().length > 0) {
      id = parsedJson['id'];
    } else {
      id = parsedJson['local_id'];
    }
    Workout wo = Workout(
      workoutId: parsedJson['id'],
      localId: id,
      userId: parsedJson['user_id'].toString(),
      date: DateTime.parse(parsedJson['date']),
      note: parsedJson['note'].toString(),
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
    (parsedJson['actions'] as Map<String, dynamic>).forEach((key, value) {
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

  Workout copy() {
    Workout wo = Workout(
        date: this.date,
        localId: this.localId,
        note: this.note,
        userId: this.userId,
        workoutId: this.workoutId);
    wo.actions = this.actions;
    wo.latestEdit = this.latestEdit;
    return (wo);
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> helper = {};
    actions.forEach((key, value) {
      helper[key] = value.toJson();
    });
    return ({
      'id': workoutId,
      'local_id': localId,
      'user_id': userId,
      // 'date': new DateFormat("EEE, d MMM yyyy HH:mm:ss vvv").format(date),
      'date': date.toIso8601String(),
      'latest_edit': latestEdit.toIso8601String(),
      'note': note,
      'points': points,
      'actions': helper,
      'not_deleted': _notDeleted,
      // 'uploaded': _uploaded,
    });
  }

  @override
  String toString() {
    return (json.encode(this.toJson()));
  }

  void addAction(Action ac) {
    // can have mulitple actions of same exercise (i.e. mulitple push-up Exercises)
    ac.workoutId = this.workoutId;
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

  void setDate(DateTime newDate) {
    this.date = newDate;
    notifyListeners();
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
  Map<String, Workout> _workouts = {};
  Map<String, Exercise> _exercises = {};
  String _token;
  // final String uri = "http://api.kantnprojekt.club/v0_1/test";
  final String uri = "http://api.kantnprojekt.club/v0_1/workouts";

  Workouts(this._token, this._workouts, this._exercises);

  Future<void> init() async {
    // loads workouts from sharedPreferences (i.e. Phone storage)
    print("workouts init is running..");
    final prefs = await SharedPreferences.getInstance();
    try {
      Map<String, dynamic> _jsonEx = json.decode(prefs.getString("Exercises"));
      _jsonEx.forEach((key, value) {
        this.addExercise(Exercise.fromJson(value));
      });
      if (_exercises.length < 6) {
        print(
            "Definitely not all exercises are loaded. Now loading them from server.");
        await this.fetchAllExercises();
      }
    } catch (e) {
      print("Error loading exercises from memory. Now fetching from server.. " +
          e.toString());
      try {
        await this.fetchAllExercises();
      } catch (e) {
        print("Couldn't fetch exercises from server " + e.toString());
      }
    }
    try {
      Map<String, dynamic> _json = json.decode(prefs.getString("Workouts"));
      _json.forEach((key, value) {
        this.addWorkout(Workout.fromJson(value));
      });
    } catch (e) {
      print("Couldn't load stored exercises/workouts. " + e.toString());
    }
    print("now fetching new workouts..");
    await this.fetchNew();
    notifyListeners();
  }

  Map<String, Workout> get workouts {
    Map<String, Workout> notDeletedWorkouts = {};
    _workouts.forEach((key, value) {
      if (value._notDeleted) {
        notDeletedWorkouts.putIfAbsent(key, () => value);
      }
    });
    return (notDeletedWorkouts);
  }

  Map<String, Exercise> get exercises {
    Map<String, Exercise> notDeletedExercises = {};
    _exercises.forEach((key, value) {
      if (value.notDeleted) {
        notDeletedExercises.putIfAbsent(key, () => value);
      }
    });
    return (notDeletedExercises);
  }

  Workout byId(String workoutId) {
    if (_workouts.containsKey(workoutId)) {
      return (_workouts[workoutId]);
    } else {
      throw (Exception("Couldn't find workout with id: " + workoutId));
    }
  }

  Map<String, Workout> get allWorkouts {
    return (_workouts);
  }

  Map<String, Exercise> get allExercises {
    return (_exercises);
  }

  void save() async {
    final prefs = await SharedPreferences.getInstance();
    print("saving workouts and exercises..");
    prefs.setString('Workouts', this.toString());
    prefs.setString('Exercises', this.exercisesToString());
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
    Uri url = Uri.http(
      "api.kantnprojekt.club",
      "/v0_1/workouts",
      queryParameters,
    );
    final response = await http.get(
      url,
      headers: {
        "token": _token,
        // "user_id": _userId,
      },
    );
    final Map result = json.decode(response.body);

    if (response.statusCode == 201 || response.statusCode == 200) {
      // for (Map json_ in result["data"]) {
      for (Map json_ in result.values) {
        try {
          Workout wo = Workout.fromJson(json_);
          newWorkouts.putIfAbsent(json_["id"], () => wo);
          print("fetched workout.. " + wo.workoutId);
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
    print("Fetching all workouts...");
    Map<String, Workout> allWorkouts = await this._fetch();
    if (allWorkouts != null && allWorkouts.length > 0) {
      _workouts = allWorkouts;
      notifyListeners();
      this.save();
    }
  }

  Future<void> fetchNew() async {
    List<DateTime> workoutTimes = [];
    print("fetching new workouts");
    _workouts.forEach((key, value) => workoutTimes.add(value.date));
    DateTime newestDate = calcMaxDate(workoutTimes);
    Map<String, Workout> newWorkouts = await this._fetch(startDate: newestDate);
    print("fetched new workouts");
    if (newWorkouts != null && newWorkouts.length > 0) {
      newWorkouts.forEach((key, value) {
        print("added workout $key");
        _workouts[key] = value;
      });
      notifyListeners();
      this.save();
    }
  }

  Future<void> fetchAllExercises() async {
    Uri url = Uri.http(
      "api.kantnprojekt.club",
      "/v0_1/exercises",
      // queryParameters,
    );
    final response = await http.get(
      url,
      headers: {
        "token": _token,
        // "user_id": _userId,
      },
    );
    final Map<String, dynamic> result = json.decode(response.body);
    if (response.statusCode == 201 || response.statusCode == 200) {
      for (Map json_ in result.values) {
        // for (Map json_ in result.values) {
        try {
          print("added exercise from server to list.");
          this.addExercise(Exercise.fromJson(json_));
        } catch (Exception) {
          print(Exception);
        }
      }
    } else {
      // If that call was not successful, throw an error.
      throw Exception('Failed to load Exercises');
    }
  }

  Map<String, dynamic> workoutsToJson({bool allWorkouts = true}) {
    // contains all workouts by default, if set to false, only the not deleted ones are returned
    Map<String, dynamic> helper = {};
    if (allWorkouts) {
      this.allWorkouts.forEach((key, value) {
        helper.putIfAbsent(key, () => value.toJson());
      });
    } else {
      this.workouts.forEach((key, value) {
        helper.putIfAbsent(key, () => value.toJson());
      });
    }

    return (helper);
  }

  @override
  String toString() {
    // returns a list with names consistent with database (e.g. id instead of workoutId)
    // includes deleted workouts!
    return (json.encode(this.workoutsToJson()));
  }

  void fromString(String str) {
    Map<String, dynamic> parsedJson = json.decode(str);
    this.fromJson(parsedJson);
  }

  void fromJson(Map<String, dynamic> parsedJson) {
    parsedJson.forEach((key, value) {
      this.addWorkout(Workout.fromJson(value));
    });
  }

  void addWorkout(Workout wo) {
    //upload with future.then(set _uploaded=true)
    // add to workouts
    wo.actions.forEach((key, action) {
      this.addExercise(action.exercise);
    });
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
    Map<String, Workout> offlineWorkouts = {};
    _workouts.forEach((key, value) {
      if (!value.isUploaded) {
        offlineWorkouts.putIfAbsent(key, () => value);
      }
    });
    if (offlineWorkouts == null || offlineWorkouts.length == 0) {
      // print("offlineworkouts are null or 0");
      return (true);
    }
    Uri url = Uri.http(
      "api.kantnprojekt.club",
      "/v0_1/workouts",
    );
    final response = await http.post(url,
        headers: {
          "token": _token,
          'Content-Type': 'application/json; charset=UTF-8',
          // "user_id": _userId,
        },
        body: jsonEncode(this.workoutsToJson()));
    final result2 =
        json.decode(response.body) as Map<String, dynamic>; //localId:workoutId
    Map<String, dynamic> result = result2["data"];
    if (response.statusCode == 201) {
      result.forEach((_localId, _workoutId) {
        _workouts.forEach((key, value) {
          print("workout id: " + key);
        });
        print("local id: $_localId workoutId: $_workoutId");
        //TODO: check if workoutId == localId, in this case nothing needs to be changed
        if (_workoutId != null) {
          Workout wo = _workouts[_localId.toString()];
          if (wo == null) {
            print("Something happened.");
            print(this.toString());
          } else {
            wo.workoutId = _workoutId.toString();
            wo.localId = _workoutId.toString();
            wo._uploaded = true;
            wo.actions.forEach((key, ac) {
              ac.workoutId = _workoutId;
            });
            _workouts.removeWhere((key, value) => key == _localId.toString());
            _workouts[_workoutId] = wo;
          }
        }
      });
    } else {
      print("Couldn't sync workouts. " + result2["message"].toString());
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
    Map<String, int> number = {};
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
    Map<String, dynamic> summary = {};
    Map<String, double> pointsPerExercise = {}; //to check for max_per_day
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

  void addExercise(Exercise ex) {
    // if an exercise with the same id is found, then it is just updated.
    // Only the note of the exercise can change! Otherwise it is needed to create a new Exercise.
    if (_exercises.containsKey(ex.localId) ||
        _exercises.containsKey(ex.exerciseId)) {
      // update existing workout
      Exercise oldEx;
      if (_exercises.containsKey(ex.localId)) {
        oldEx = _exercises[ex.localId];
      } else {
        oldEx = _exercises[ex.exerciseId];
      }
      if (oldEx.note != ex.note) {
        oldEx.note = ex.note;
        this.syncronize();
        notifyListeners();
      } else {
        print("Tried to add existing Exercise with the same note.");
      }
    } else {
      print("Added new exercise to internal list: " + ex.title);
      _exercises[ex.localId] = ex;
      this.syncronize();
      notifyListeners();
    }
  }

  void deleteExercise(String id) {
    Exercise ex = _exercises[id];
    ex.setNotDeleted = false;
    ex.setUploaded = false;
    // _exercises.removeWhere(
    //     (key, value) => value.exerciseId == id || value.localId == id);
    notifyListeners();
    this.syncronize();
  }

  String exercisesToString() {
    String str = json.encode(_exercises);
    return (str);
  }

  // Todo:
}
