// import 'dart:ffi';
import 'dart:convert';
import 'dart:math';
// import 'dart:html';
// import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import '../misc/functions.dart';
import '../misc/exercise.dart';

class Action {
  String actionId;
  String exerciseId;
  String workoutId;
  double number;
  String note;
  // double points;
  // Exercise exercise;

  // Action(this.exerciseId, this.workoutId, this.number, this.note, this.exercise);

  Action(this.exerciseId, this.workoutId, this.number, this.note);

  factory Action.create({String exerciseId = "", String workoutId = "", double number = 0, String note = ""}) {
    String actionId = getRandomString(20);
    Action ac = Action(exerciseId, workoutId, number, note);
    ac.actionId = actionId;
    return (ac);
  }

  factory Action.fromJson(Map<String, dynamic> parsedJson, String workoutId) {
    String exerciseId = parsedJson['exercise_id'];
    if (exerciseId == null || exerciseId == "") {
      throw ("Creating Action from json: empty exercise Id");
    }
    Action ac = Action(
      parsedJson['exercise_id'],
      workoutId,
      double.parse(parsedJson['number'].toString()),
      parsedJson['note'],
    );
    if (parsedJson['id'] != null) {
      ac.actionId = parsedJson['id'];
    }
    return (ac);
  }

  // double get points {
  //   return this.number * this.exercise.points;
  // }

  // double pointsAllowance(int number) {
  //   // returns points given that this exercise was already done *number* of times this week (adjusting for weekly allowance)
  //   double remainingAllowance = max(this.exercise.weeklyAllowance - number, 0);
  //   return ((this.number - remainingAllowance) * this.exercise.points);
  // }

  Map<String, dynamic> toJson() {
    return ({
      'id': actionId,
      'exercise_id': exerciseId,
      'workout_id': workoutId,
      'number': number,
      'note': note,
    });
  }

  bool equals(Action ac) {
    return (actionId == ac.actionId && exerciseId == ac.exerciseId && workoutId == ac.workoutId && number == ac.number && note == ac.note);
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

  bool get isNotDeleted {
    return (_notDeleted);
  }

  set isUploaded(bool val) {
    _uploaded = val;
  }

  set isNotDeleted(bool val) {
    _notDeleted = val;
  }

  bool equals(Workout wo) {
    if (actions.length != wo.actions.length) {
      return false;
    }
    actions.forEach((acId, ac) {
      if (wo.actions.containsKey(acId)) {
        if (!ac.equals(wo.actions[acId])) {
          return false;
        }
      } else {
        return false;
      }
    });
    return (workoutId == wo.workoutId &&
        localId == wo.localId &&
        userId == wo.userId &&
        date.isSameDate(wo.date) &&
        latestEdit.isSameDate(wo.latestEdit) &&
        note == wo.note &&
        _uploaded == wo._uploaded &&
        _notDeleted == wo._notDeleted);
  }

  Workout({this.workoutId, this.localId, this.userId, this.date, this.note, this.latestEdit});

  // set workoutId(String woId) {
  //   this.workoutId = woId;
  // }

  factory Workout.newWithUserId(userId) {
    return (Workout(workoutId: null, localId: getRandomString(30), userId: userId, date: DateTime.now(), latestEdit: DateTime.now(), note: ""));
  }

  factory Workout.fromJson(Map<String, dynamic> parsedJson) {
    String id;
    if (parsedJson.containsKey("id") && parsedJson['id'] != null) {
      //parsedJson['id'].toString().length > 0 &&
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
      wo.isUploaded = parsedJson['uploaded'];
    } else {
      // from api, no "uploaded" field is provided
      wo.isUploaded = true;
    }
    if (parsedJson['not_deleted'] != null) {
      // from phone storage
      wo._notDeleted = parsedJson['not_deleted'];
    }
    // add exercises
    (parsedJson['actions'] as Map<String, dynamic>).forEach((key, value) {
      try {
        wo.addAction(Action.fromJson(value as Map<String, dynamic>, wo.workoutId), fromUser: false);
      } catch (e) {
        print("Couldn't create action from json: $e");
      }
    });
    return (wo);
  }

  Workout copy() {
    Workout wo = Workout(date: this.date, localId: this.localId, note: this.note, userId: this.userId, workoutId: this.workoutId);
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
      'actions': helper,
      'not_deleted': _notDeleted,
      'uploaded': _uploaded,
    });
  }

  @override
  String toString() {
    return (json.encode(this.toJson()));
  }

  void addAction(Action ac, {bool fromUser = true}) {
    // can have mulitple actions of same exercise (i.e. mulitple push-up Exercises)
    ac.workoutId = this.workoutId;
    if (actions.containsKey(ac.actionId)) {
      // update action
      Action oldAc = actions[ac.actionId];
      oldAc.note = ac.note;
      oldAc.exerciseId = ac.exerciseId;
      oldAc.number = ac.number;
    } else {
      // create new
      actions.putIfAbsent(ac.actionId, () => ac);
    }

    // this.points += ac.points;
    if (fromUser) {
      _uploaded = false;
      latestEdit = DateTime.now();
    }
  }

  void setDate(DateTime newDate) {
    this.date = newDate;
    _uploaded = false;
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
