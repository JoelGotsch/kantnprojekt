import 'dart:ffi';
import 'dart:convert';
// import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';

import 'functions.dart';

class Exercise {
  String exerciseId; //from database, provided by API
  String localId = getRandomString(20);
  final String title;
  final String note;
  final String userId;
  final String unit;
  final Float points;
  final Float maxPointsDay;
  final int weeklyAllowance;
  bool _uploaded = false;

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
      localId: parsedJson['id'],
      userId: parsedJson['user_id'],
    );
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
      'title': title,
      'note': note,
      'unit': unit,
      'user_id': userId,
      'points': points,
      'max_points_day': maxPointsDay,
      'weekly_allowance': weeklyAllowance,
      'uploaded': _uploaded,
    }));
  }

  String toJson() {
    return (this.toString());
  }
}

class Exercises with ChangeNotifier {
  Map<String, Exercise> _exercises = {};

  Map<String, Exercise> get exercises {
    return {..._exercises};
  }

  void add(Exercise exercise) {
    _exercises.putIfAbsent(exercise.localId, () => exercise);
    notifyListeners();
  }

  void removeExercise(String id) {
    _exercises.removeWhere(
        (key, value) => value.exerciseId == id || value.localId == id);
    notifyListeners();
  }

  @override
  String toString() {
    String str = json.encode(_exercises);
    print(str);
    return (str);
  }
}
