// import 'dart:ffi';
import 'dart:convert';
// import 'dart:math';
// import 'dart:html';
// import 'package:intl/intl.dart';
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
  bool _saving = false;
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
    // now fetching the whole list of workouts with newest dates to compare to the one on the phone:
    Map<String, DateTime> allWorkouts = {};
    try {
      allWorkouts = await this.fetchHeaders();
      print(allWorkouts);
    } catch (Exception) {
      print(Exception);
    }
    for (String key in allWorkouts.keys) {
      try {
        if (!_workouts.containsKey(key) || _workouts[key].latestEdit.compareTo(allWorkouts[key]) <= 0) {
          _saving = true;
          if (!_workouts.containsKey(key)) {
            print("Fetching workout $key because workout is missing locally.");
          } else {
            print("Fetching workout $key because {_workouts[key].latestEdit} is before the last online edit on {allWorkouts[key]}");
          }
          await this.fetchWorkout(key);
        }
      } catch (Exception) {
        print(Exception);
      }
    }
    // delete workouts which were deleted on server:
    if (allWorkouts.length > 0) {
      for (String key in _workouts.keys) {
        if (!allWorkouts.containsKey(key) && _workouts[key].isUploaded == true) {
          print("removed workout $key because it was not found on server.");
          _workouts.remove(key);
        }
      }
    }
    List<DateTime> workoutTimes = [];
    _workouts.forEach((key, value) => workoutTimes.add(value.latestEdit));
    lastRefresh = calcMaxDate(workoutTimes);

    // print("now fetching new workouts..");
    // await this.fetchNew();
    notifyListeners();
    if (_saving) {
      this.save();
    }
    print(this.toString());
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
          if (json_["id"] != null) {
            newWorkouts.putIfAbsent(json_["id"], () => wo);
            print("fetched workout.. " + wo.workoutId);
          }
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
      this.pruneWorkoutList();
      notifyListeners();
      this.save();
    }
  }

  Future<void> fetchWorkout(String workoutId, {bool save = false}) async {
    print("Fetching all workouts...");
    if (workoutId == null) {
      throw (Exception("wanted to fetch workout null."));
    } else {
      Map<String, Workout> oneWorkout = await this._fetch(workoutId: workoutId);
      if (oneWorkout != null && oneWorkout.length > 0) {
        _workouts[workoutId] = oneWorkout[workoutId];
        notifyListeners();
        if (save) {
          this.pruneWorkoutList();
          this.save();
        }
      }
    }
  }

  Future<void> fetchNew() async {
    print("fetching new workouts since $lastRefresh");
    // List<DateTime> workoutTimes = [];
    // _workouts.forEach((key, value) => workoutTimes.add(value.latestEdit));
    // DateTime newestDate = calcMaxDate(workoutTimes);

    Map<String, Workout> newWorkouts = await this._fetch(editDate: lastRefresh);
    print("fetched new workouts");
    lastRefresh = DateTime.now().toUtc();
    if (newWorkouts != null && newWorkouts.length > 0) {
      newWorkouts.forEach((key, wo) {
        print("add workout $key");
        this.addWorkout(wo, fromOnline: true);
      });
      this.pruneWorkoutList();
      notifyListeners();
      this.save();
    }
  }

  void pruneWorkoutList() {
    // deletes all deleted, and uploaded workouts. Actually only necessary if something went wrong..
    List<String> deleteKeys = [];
    if (_workouts.length > 0) {
      _workouts.forEach((key, value) {
        if (value.isUploaded && !value.isNotDeleted) {
          print("Workout $key was pruned. Something happened.");
          deleteKeys.add(key);
        }
      });
      deleteKeys.forEach((element) {
        _workouts.remove(element);
      });
    }
  }

  Future<Map<String, DateTime>> fetchHeaders() async {
    Map<String, DateTime> allWorkouts = {};
    Map<String, String> queryParameters = {};
    print("start fetching workout headers ..");
    queryParameters["only_header"] = true.toString();
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
      result.forEach((key, value) {
        try {
          allWorkouts.putIfAbsent(key, () => DateTime.parse(value));
        } catch (Exception) {
          print(Exception);
        }
      });
    } else {
      // If that call was not successful, throw an error.
      throw Exception('Failed to load Workout ' + result["message"]);
    }
    return (allWorkouts);
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
    if (wo.actions.length > 0) {
      wo.actions.forEach((key, action) {
        this.addExercise(action.exercise);
      });
    }
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
      if (wo.localId == null) {
        throw (Exception("localId of workout is null."));
      }
      print("added new workout ${wo.localId}");
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
    try {
      _workouts.remove(null);
    } catch (Exception) {
      print("something..");
    }
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
          if (_workoutId == "") {
            // thats the response if workout was deleted on server
            print("removed exercise $_localId");
            _workouts.remove(_localId.toString());
          } else if (_workoutId != null) {
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
