// import 'dart:ffi';
import 'dart:convert';
// import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../misc/functions.dart';

class Exercise {
  String exerciseId; //from database, provided by API
  String localId = getRandomString(20);
  final String title;
  String note;
  final String userId;
  final String unit;
  final double points;
  final double maxPointsDay;
  final int weeklyAllowance; //deducted from number
  bool _uploaded = false;
  bool _notDeleted = true; // used when deleting exercises

  bool get isUploaded {
    return (_uploaded);
  }

  Exercise(this.title, this.note, this.unit, this.points, this.maxPointsDay,
      this.weeklyAllowance,
      {this.exerciseId, this.localId, this.userId});

  factory Exercise.fromJson(Map<String, dynamic> parsedJson) {
    Exercise ex = Exercise(
      parsedJson['title'],
      parsedJson['note'],
      parsedJson['unit'],
      parsedJson['points'],
      parsedJson['max_points_day'],
      parsedJson['weekly_allowance'],
      exerciseId: parsedJson['id'],
      localId: parsedJson['local_id'],
      userId: parsedJson['user_id'],
    );
    if (parsedJson['not_deleted'] != null) {
      ex._notDeleted = parsedJson['not_deleted'];
    }
    if (parsedJson['uploaded'] != null) {
      ex._uploaded = parsedJson['uploaded'];
    } else {
      // from api
      ex._uploaded = true;
    }
    return (ex);
  }

  factory Exercise.fromString(String str) {
    Map<String, dynamic> parsedJson = json.decode(str);
    return (Exercise.fromJson(parsedJson));
  }

  @override
  String toString() {
    if (exerciseId == null) {
      exerciseId = localId;
    }
    return (json.encode({
      'id': exerciseId,
      'local_id': localId,
      'title': title,
      'note': note,
      'unit': unit,
      'user_id': userId,
      'points': points,
      'max_points_day': maxPointsDay,
      'weekly_allowance': weeklyAllowance,
      'uploaded': _uploaded,
      'not_deleted': _notDeleted,
    }));
  }

  String toJson() {
    return (this.toString());
  }
}

class Exercises with ChangeNotifier {
  Map<String, Exercise> _exercises = {};
  String _token;
  String _userId;
  final String uri = "http://api.kantnprojekt.club/v0_1/exercises";

  Map<String, Exercise> get exercises {
    Map<String, Exercise> notDeletedExercises;
    _exercises.forEach((key, value) {
      if (value._notDeleted) {
        notDeletedExercises.putIfAbsent(key, () => value);
      }
    });
    return {...notDeletedExercises};
  }

  void init() async {
    // load from shared preferences
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> _json = json.decode(prefs.getString("Exercises"));
    _json.forEach((key, value) {
      _exercises.putIfAbsent(value.id, () => Exercise.fromJson(value));
    });
    notifyListeners();
  }

  void save() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('Exercises', this.toString());
  }

  Future<Map<String, Exercise>> _fetch(
      {String exerciseId, int number = 0}) async {
// helper function to get data via API
    Map<String, Exercise> newExercises = {};
    Map<String, String> queryParameters = {};
    if (exerciseId != null) {
      queryParameters["exercise_id"] = exerciseId;
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
    final Map<String, dynamic> result = json.decode(response.body);
    print(response.statusCode);
    print("fetch workouts result:\\" + result.toString());

    if (response.statusCode == 201 || response.statusCode == 200) {
      // for (Map json_ in result["data"]) {
      for (Map json_ in result.values) {
        try {
          newExercises.putIfAbsent(json_["id"], () => Exercise.fromJson(json_));
        } catch (Exception) {
          print(Exception);
        }
      }
    } else {
      // If that call was not successful, throw an error.
      throw Exception('Failed to load Workout');
    }
    return (newExercises);
  }

  Exercise getExercise(String exerciseId) {
    Exercise ex;
    if (exercises.containsKey(exerciseId)) {
      ex = exercises[exerciseId];
    } else {
      //TODO: download exercise; shouldn't happen so far anyways as in this case the exercise is sent as part of the workout!
      throw Exception("Tried to access exerciseID " +
          exerciseId.toString() +
          " which is not known. Maybe forgot to initialize the exercise object?");
    }
    return (ex);
  }

  Future<bool> syncronize() async {
    // tries to upload all not uploaded workouts and updates the Ids, then saves to shared_preferences
    Map<String, Exercise> offlineExercises;
    _exercises.forEach((key, value) {
      if (!value.isUploaded) {
        offlineExercises.putIfAbsent(key, () => value);
      }
    });
    if (offlineExercises.length == 0) {
      return (true);
    }
    final response = await http.post(uri,
        headers: {
          "token": _token,
          "user_id": _userId,
        },
        body: json.encode(offlineExercises));
    final result =
        json.decode(response.body) as Map<String, String>; //localId:workoutId
    print(response.statusCode);
    if (response.statusCode == 201) {
      result.forEach((key, value) {
        if (value != null) {
          Exercise ex = _exercises[key];
          ex.exerciseId = value;
          ex._uploaded = true;
          _exercises.removeWhere((key, value) => value.localId == key);
          _exercises[value] = ex;
        }
      });
    } else {
      print("Couldn't sync exercises.");
      return (false);
    }
    this.save();
    notifyListeners();
    return (true);
  }

  void add(Exercise ex) {
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
      } else {
        print("Tried to add existing Exercise with the same note.");
      }
    } else {
      _exercises[ex.localId] = ex;
    }
    notifyListeners();
    this.syncronize();
  }

  void deleteExercise(String id) {
    Exercise ex = _exercises[id];
    ex._notDeleted = false;
    ex._uploaded = false;
    // _exercises.removeWhere(
    //     (key, value) => value.exerciseId == id || value.localId == id);
    notifyListeners();
    this.syncronize();
  }

  @override
  String toString() {
    String str = json.encode(_exercises);
    print(str);
    return (str);
  }
}
