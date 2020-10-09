import 'dart:ffi';
import 'dart:convert';
import 'dart:html';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'functions.dart';

class Action {
  String actionId = getRandomString(20);
  String exerciseId;
  String workoutId;
  Float number;
  String note;
  Float points;

  Action(this.exerciseId, this.workoutId, this.number, this.note, this.points);

  factory Action.fromJson(Map<String, dynamic> parsedJson, workoutId) {
    Action ac = Action(
      parsedJson['exercise_id'],
      workoutId,
      parsedJson['number'],
      parsedJson['note'],
      parsedJson['points'],
    );
    if (parsedJson['actionId'] != null) {
      ac.actionId = parsedJson['actionId'];
      // } else {
      //   ac.actionId = getRandomString(20);
    }
    return (ac);
  }

  @override
  String toString() {
    return (json.encode({
      'action_id': actionId,
      'exercise_id': exerciseId,
      'workout_id': workoutId,
      'number': number,
      'note': note,
      'points': points,
    }));
  }
}

class Workout {
  String workoutId;
  String localId;
  String userId;
  DateTime date;
  DateTime latestEdit = DateTime.now();
  String note;
  Map<String, Action> actions; //actionId:action
  Float points;
  bool _uploaded = false;

  bool get isUploaded {
    return (_uploaded);
  }

  Workout(this.workoutId, this.userId, this.date, this.note, this.points);

  factory Workout.fromJson(Map<String, dynamic> parsedJson) {
    Workout wo = Workout(
      parsedJson['id'],
      parsedJson['user_id'].toString(),
      DateTime.parse(parsedJson['date']),
      parsedJson['note'].toString(),
      parsedJson['points'],
    );
    wo.latestEdit = DateTime.parse(parsedJson['latest_edit']);
    if (parsedJson['uploaded'] != null) {
      // from phone storage
      wo._uploaded = parsedJson['uploaded'];
    } else {
      // from api, no "uploaded" field is provided
      wo._uploaded = true;
    }
    // add exercises
    (parsedJson['actions'] as Map<String, Action>).forEach((key, value) {
      wo.addAction(
          Action.fromJson(value as Map<String, dynamic>, wo.workoutId));
    });
    return (wo);
  }

  @override
  String toString() {
    final String actionsStr = json.encode(actions);
    // json.encode(Map.fromIterable(actions, key: (e) => e.workoutId, value: (e) => e.toString()));
    print("action_str:\\" + actionsStr);
    return (json.encode({
      'id': workoutId,
      'user_id': userId,
      // 'date': new DateFormat("EEE, d MMM yyyy HH:mm:ss vvv").format(date),
      'date': date.toIso8601String(),
      'latest_edit': latestEdit.toIso8601String(),
      'note': note,
      'actions': actionsStr,
      'uploaded': _uploaded,
    }));
  }

  void addAction(Action ac) {
    // can have mulitple actions of same exercise (i.e. mulitple push-up Exercises)
    actions.putIfAbsent(ac.actionId, () => ac);
    this.points += ac.points;
    _uploaded = false;
    latestEdit = DateTime.now();
  }

  void deleteAction(String actionId) {
    Action ac = actions[actionId];
    this.points -= ac.points;
    actions.removeWhere((key, value) => key == actionId);
    _uploaded = false;
    latestEdit = DateTime.now();
  }
}

class Workouts with ChangeNotifier {
  // manages all the workout- objects: making sure they are uploaded/
  Map<String, Workout> workouts;
  String _token;
  String _userId;
  // final String uri = "http://api.kantnprojekt.club/v0_1/test";
  final String uri = "http://api.kantnprojekt.club/v0_1/workouts";

  Future<void> load() async {
    // loads workouts from sharedPreferences (i.e. Phone storage)
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> _json = json.decode(prefs.getString("Workouts"));
    _json.forEach((key, value) {
      workouts.putIfAbsent(value.id, () => Workout.fromJson(value));
    });
    notifyListeners();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('Workouts', this.toString());
  }

  Future<Map<String, Workout>> fetch(
      {String workoutId,
      DateTime startDate,
      DateTime endDate,
      int number}) async {
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
    if (number != null) {
      queryParameters["number"] = number.toString();
    }
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
    Map<String, Workout> allWorkouts = await this.fetch();
    if (allWorkouts.length > 0) {
      workouts = allWorkouts;
      notifyListeners();
      this.save();
    }
  }

  Future<void> fetchNew() async {
    List<DateTime> workoutTimes = [];
    workouts.forEach((key, value) => workoutTimes.add(value.latestEdit));
    DateTime newestDate = calcMaxDate(workoutTimes);
    Map<String, Workout> newWorkouts = await this.fetch(startDate: newestDate);
    if (newWorkouts.length > 0) {
      newWorkouts.forEach((key, value) {
        workouts[key] = value;
      });
      notifyListeners();
      this.save();
    }
  }

  @override
  String toString() {
    // returns a list with names consistent with database (e.g. id instead of workoutId)
    String str = json.encode(workouts);
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
      workouts.putIfAbsent(value["id"], () => Workout.fromJson(value));
    });
  }

  void addWorkout(Workout wo) {
    //upload with future.then(set _uploaded=true)
    // add to workouts
    workouts[wo.localId] = wo;
    notifyListeners();
    this.syncronize();

    //update shared_preferences a
  }

  void addAction(Action ac) {
    Workout wo = workouts[ac.workoutId];
    wo.addAction(ac);
    notifyListeners();
    this.syncronize();
  }

  void deleteAction(Action ac) {
    Workout wo = workouts[ac.workoutId];
    wo.deleteAction(ac.actionId);
    notifyListeners();
    this.syncronize();
  }

  void syncronize() async {
    // tries to upload all not uploaded workouts and updates the Ids, then saves to shared_preferences
    Map<String, Workout> offlineWorkouts;
    workouts.forEach((key, value) {
      if (!value.isUploaded) {
        offlineWorkouts.putIfAbsent(key, () => value);
      }
    });
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
      result.forEach((key, value) {
        if (value != null) {
          Workout wo = workouts[key];
          wo.workoutId = value;
          wo._uploaded = true;
          workouts.removeWhere((key, value) => value.localId == key);
          workouts[value] = wo;
        }
      });
    }
    this.save();
    notifyListeners();
  }

  // Todo:
}
