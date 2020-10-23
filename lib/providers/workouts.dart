// import 'dart:ffi';
import 'dart:convert';
import 'dart:math';
// import 'dart:html';
// import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:collection'; // for linked hashmaps

import '../misc/functions.dart';
import 'exercises.dart';
import 'workout.dart';

class Workouts with ChangeNotifier {
  // manages all the workout- objects: making sure they are uploaded/
  Map<String, Workout> _workouts = {};
  Map<String, Exercise> _exercises = {};
  String _token;
  DateTime lastRefresh = DateTime(2020);
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
        print("Definitely not all exercises are loaded. Now loading them from server.");
        await this.fetchAllExercises();
      }
    } catch (e) {
      print("Error loading exercises from memory. Now fetching from server.. " + e.toString());
      try {
        await this.fetchAllExercises();
      } catch (e) {
        print("Couldn't fetch exercises from server " + e.toString());
      }
    }
    try {
      Map<String, dynamic> _json = json.decode(prefs.getString("Workouts"));
      _json.forEach((key, value) {
        Workout wo = Workout.fromJson(value);
        this.addWorkout(wo, fromOnline: true);
        print("added workout from storage: ${wo.workoutId}");
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
      if (value.isNotDeleted) {
        notDeletedWorkouts.putIfAbsent(key, () => value);
      }
    });
    // now sorting them: newest date first:
    return (notDeletedWorkouts);
  }

  List<Workout> get sortedWorkouts {
    Map<String, Workout> notDeletedWorkouts = this.workouts;
    List mapKeys = notDeletedWorkouts.keys.toList(growable: false);
    mapKeys.sort((k1, k2) => notDeletedWorkouts[k1].date.compareTo(notDeletedWorkouts[k2].date));
    List<Workout> returnList = [];
    mapKeys.forEach((k1) {
      returnList.insert(0, notDeletedWorkouts[k1]);
    });
    return (returnList);
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

  Future<Map<String, Workout>> _fetch({String workoutId, DateTime editDate, DateTime startDate, DateTime endDate, int number = 0}) async {
    // deletes all locally stored exercises and loads the complete list from online database and stores values in sharedPreferences
    Map<String, Workout> newWorkouts = {};
    Map<String, String> queryParameters = {};
    print("start fetching workouts..");
    if (workoutId != null) {
      queryParameters["workout_id"] = workoutId;
    }
    if (editDate != null) {
      queryParameters["last_edit_date"] = editDate.toIso8601String();
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
    print("fetching new workouts");
    // List<DateTime> workoutTimes = [];
    // _workouts.forEach((key, value) => workoutTimes.add(value.latestEdit));
    // DateTime newestDate = calcMaxDate(workoutTimes);

    Map<String, Workout> newWorkouts = await this._fetch(editDate: lastRefresh);
    print("fetched new workouts");
    lastRefresh = DateTime.now().toUtc();
    if (newWorkouts != null && newWorkouts.length > 0) {
      newWorkouts.forEach((key, wo) {
        print("added workout $key");
        this.addWorkout(wo, fromOnline: true);
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

  Map<String, dynamic> workoutsToJson({bool allWorkouts = true, Map<String, Workout> workoutsMap}) {
    // contains all workouts by default, if set to false, only the not deleted ones are returned
    Map<String, dynamic> helper = {};
    if (workoutsMap != null) {
      workoutsMap.forEach((key, value) {
        helper.putIfAbsent(key, () => value.toJson());
      });
      return (helper);
    }
    if (allWorkouts) {
      this.allWorkouts.forEach((key, value) {
        helper.putIfAbsent(key, () => value.toJson());
      });
    } else {
      // only not deleted
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

  void addWorkout(Workout wo, {bool fromOnline = false}) {
    //upload with future.then(set _uploaded=true)
    // add to workouts
    wo.actions.forEach((key, action) {
      this.addExercise(action.exercise);
    });
    if (_workouts.containsKey(wo.localId) || _workouts.containsKey(wo.workoutId)) {
      // update existing workout
      Workout oldWo;
      if (_workouts.containsKey(wo.localId)) {
        oldWo = _workouts[wo.localId];
      } else {
        oldWo = _workouts[wo.workoutId];
      }
      if (!oldWo.equals(wo)) {
        oldWo.actions = wo.actions;
        oldWo.date = wo.date;
        oldWo.latestEdit = DateTime.now();
        oldWo.note = wo.note;
        oldWo.isUploaded = wo.isUploaded;
        notifyListeners();
        if (!fromOnline && !wo.isUploaded) {
          print("syncronize from add workout 1");
          this.syncronize();
        }
      }
    } else {
      _workouts[wo.localId] = wo;
      notifyListeners();
      if (!fromOnline && !wo.isUploaded) {
        print("syncronize from add workout 2");
        this.syncronize();
      }
    }
  }

  void deleteWorkout(String workoutId) {
    Workout wo = _workouts[workoutId];
    wo.isNotDeleted = false;
    wo.isUploaded = false;
    // _workouts.removeWhere((key, value) => false);
    notifyListeners();
    print("syncronize from deleting workout");
    this.syncronize();
  }

  void addAction(Action ac) {
    Workout wo = _workouts[ac.workoutId];
    wo.addAction(ac);
    notifyListeners();
    print("syncronize from adding action.");
    this.syncronize();
  }

  void deleteAction(Action ac) {
    Workout wo = _workouts[ac.workoutId];
    wo.deleteAction(ac.actionId);
    notifyListeners();
    print("syncronize from deleting action");
    this.syncronize();
  }

  Future<bool> syncronize() async {
    // tries to upload all not uploaded workouts and updates the Ids, then saves to shared_preferences
    Map<String, Workout> offlineWorkouts = {};
    print("start syncronizing workouts.");
    _workouts.forEach((key, wo) {
      if (!wo.isUploaded) {
        offlineWorkouts.putIfAbsent(key, () => wo);
        print("Workout $key is not uploaded yet. Will be synced now.");
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
    try {
      final response = await http.post(url,
          headers: {
            "token": _token,
            'Content-Type': 'application/json; charset=UTF-8',
            // "user_id": _userId,
          },
          body: jsonEncode(this.workoutsToJson(workoutsMap: offlineWorkouts)));
      final result2 = json.decode(response.body) as Map<String, dynamic>; //localId:workoutId
      Map<String, dynamic> result = result2["data"];
      if (response.statusCode == 201) {
        print("Successful response in syncronization.");
        result.forEach((_localId, _workoutId2) {
          String _workoutId = _workoutId2.toString();
          print("local id: $_localId workoutId: $_workoutId");
          if (_workoutId != null) {
            Workout wo = _workouts[_localId.toString()];
            if (wo == null) {
              print("Something happened. WO is null! Inspect!");
              print(this.toString());
            }
            wo.workoutId = _workoutId.toString();
            wo.localId = _workoutId.toString();
            wo.isUploaded = true;
            wo.actions.forEach((key, ac) {
              ac.workoutId = _workoutId;
            });
            if (_workoutId != _localId) {
              _workouts.removeWhere((key, value) => key == _localId.toString());
              _workouts[_workoutId] = wo;
            }
          }
        });
      } else {
        print("Couldn't sync workouts. " + result2["message"].toString());
        return (false);
      }
    } catch (e) {
      print("Error while syncing workouts: " + e.toString());
      return (false);
    }

    this.save();
    notifyListeners();
    return (true);
  }

  Map<String, int> noExerciseWeek(DateTime dayInWeek, {bool onlyBeforeDayInWeek: true}) {
    // calculates for each exercise the number how often it was performed in a given week (optionally: before the given date)
    int weeknr = weekNumber(dayInWeek);
    Map<String, int> number = {};
    _workouts.forEach((key, value) {
      if (weekNumber(value.date) == weeknr && (!onlyBeforeDayInWeek || value.date.isBefore(dayInWeek))) {
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
    summary["date"] = new DateFormat("EEE, d MMM yyyy").format(previousDate).toString();
    _workouts.forEach((key, value) {
      if (value.date.isSameDate(previousDate)) {
        // workoutsDay[key] = value;
        Map<String, int> previousExercises = noExerciseWeek(value.date, onlyBeforeDayInWeek: true);
        value.actions.forEach((key2, ac) {
          double thisPoints = 0;
          if (previousExercises.containsKey(ac.exerciseId)) {
            thisPoints = ac.pointsAllowance(previousExercises[ac.exerciseId]);
          } else {
            thisPoints = ac.points;
          }
          if (ac.exercise.maxPointsDay == 0) {
            pointsPerExercise[ac.exerciseId] = pointsPerExercise[ac.exerciseId] + thisPoints;
          } else {
            pointsPerExercise[ac.exerciseId] = min(ac.exercise.maxPointsDay, pointsPerExercise[ac.exerciseId] + thisPoints);
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
    if (_exercises.containsKey(ex.localId) || _exercises.containsKey(ex.exerciseId)) {
      // update existing workout
      Exercise oldEx;
      if (_exercises.containsKey(ex.localId)) {
        oldEx = _exercises[ex.localId];
      } else {
        oldEx = _exercises[ex.exerciseId];
      }
      if (!oldEx.equals(ex)) {
        oldEx.note = ex.note;
        print("syncronize from adding exercise 1");
        this.syncronize();
        notifyListeners();
      }
    } else {
      print("Added new exercise to internal list: " + ex.title);
      _exercises[ex.localId] = ex;
      print("syncronize from adding exercise 2");
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
    print("syncronize from deleting exercise");
    this.syncronize();
  }

  String exercisesToString() {
    String str = json.encode(_exercises);
    return (str);
  }

  // Todo:
}
