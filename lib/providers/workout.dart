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
  String localExerciseId;
  // String workoutId;
  double number;
  String note;
  // double points;
  // Exercise exercise;

  Action(this.exerciseId, this.localExerciseId, this.number, this.note);

  // Action(this.exerciseId, this.workoutId, this.number, this.note);

  // factory Action.create({String exerciseId = "", String workoutId = "", double number = 0, String note = ""}) {
  factory Action.create({String exerciseId = "", String localExerciseId = "", double number = 0, String note = ""}) {
    String actionId = getRandomString(20);
    // Action ac = Action(exerciseId, workoutId, number, note);
    Action ac = Action(exerciseId, localExerciseId, number, note);
    ac.actionId = actionId;
    return (ac);
  }

  factory Action.fromJson(Map<String, dynamic> parsedJson) {
    String exerciseId = getFromJson("exercise_id", parsedJson, "");
    String localExerciseId = getFromJson("local_id", parsedJson, exerciseId);
    String note = getFromJson("note", parsedJson, exerciseId);
    double number = double.parse(getFromJson("number", parsedJson, "0").toString());
    String id = getFromJson("id", parsedJson, "");
    if (localExerciseId == null || localExerciseId == "") {
      throw ("Creating Action from json: empty exercise Id");
    }
    Action ac = Action(
      exerciseId,
      localExerciseId,
      number,
      note,
    );
    if (id != "") {
      ac.actionId = id;
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
      'local_id': localExerciseId,
      'number': number,
      'note': note,
    });
  }

  bool equals(Action ac) {
    // return (actionId == ac.actionId && exerciseId == ac.exerciseId && workoutId == ac.workoutId && number == ac.number && note == ac.note);
    return (actionId == ac.actionId && exerciseId == ac.exerciseId && exerciseId == ac.exerciseId && number == ac.number && note == ac.note);
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
  bool uploaded = false;
  bool _notDeleted = true;

  bool get isNotDeleted {
    return (_notDeleted);
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
        uploaded == wo.uploaded &&
        _notDeleted == wo._notDeleted);
  }

  Workout({this.workoutId, this.localId, this.userId, this.date, this.note, this.latestEdit});

  factory Workout.newWithUserId(userId) {
    return (Workout(workoutId: null, localId: getRandomString(30), userId: userId, date: DateTime.now(), latestEdit: DateTime.now(), note: ""));
  }

  factory Workout.fromJson(Map<String, dynamic> parsedJson) {
    String woId = getFromJson("id", parsedJson, "");
    String localWoId = getFromJson("local_id", parsedJson, woId);
    String userId = getFromJson("user_id", parsedJson, "").toString();
    String note = getFromJson("note", parsedJson, "").toString();
    DateTime latestEdit = DateTime.parse(getFromJson("latest_edit", parsedJson, "2020-01-01 00:00:00.000").toString());
    DateTime date = DateTime.parse(getFromJson("date", parsedJson, "2020-01-01 00:00:00.000").toString());
    bool uploaded = getFromJson("uploaded", parsedJson, "true").toString().toLowerCase() == "true";
    bool notDeleted = getFromJson("not_deleted", parsedJson, "true").toString().toLowerCase() == "true";
    // print("Workout from Json input: $parsedJson, uploaded = $uploaded");
    print("Workout from Json input uploaded = $uploaded");

    if (localWoId == "" || userId == "") {
      throw ("Invalid input to workout.fromjson: $parsedJson");
    }
    Workout wo = Workout(
      workoutId: woId,
      localId: localWoId,
      userId: userId,
      date: date,
      note: note,
      latestEdit: latestEdit,
    );
    wo.uploaded = uploaded;
    wo.isNotDeleted = notDeleted;
    // add exercises
    (parsedJson['actions'] as Map<String, dynamic>).forEach((key, value) {
      try {
        wo.addAction(Action.fromJson(value as Map<String, dynamic>), fromUser: false);
      } catch (e) {
        print("Couldn't create/add action from json: $e");
        print("action json: $value");
      }
    });
    // wo.latestEdit =latestEdit; // must be after adding actions
    return (wo);
  }

  Workout copy() {
    Workout wo = Workout(date: this.date, localId: this.localId, note: this.note, userId: this.userId, workoutId: this.workoutId);
    wo.actions = this.actions;
    wo.latestEdit = this.latestEdit;
    wo.uploaded = this.uploaded;
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
      'date': date.toIso8601String(),
      'latest_edit': latestEdit.toIso8601String(),
      'note': note,
      'actions': helper,
      'not_deleted': _notDeleted,
      'uploaded': uploaded,
    });
  }

  @override
  String toString() {
    return (json.encode(this.toJson()));
  }

  void addAction(Action ac, {bool fromUser = true}) {
    // can have mulitple actions of same exercise (i.e. mulitple push-up Exercises)
    // ac.workoutId = this.workoutId;

    if (actions.containsKey(ac.actionId)) {
      // update action
      print("update action ${ac.actionId}");
      Action oldAc = actions[ac.actionId];
      oldAc.note = ac.note;
      oldAc.exerciseId = ac.exerciseId;
      oldAc.localExerciseId = ac.localExerciseId;
      oldAc.number = ac.number;
    } else {
      // create new
      print("added action ${ac.actionId}");
      actions.putIfAbsent(ac.actionId, () => ac);
    }

    // this.points += ac.points;
    if (fromUser) {
      print("Workout: added action from user => set uploaded to false.");
      uploaded = false;
      latestEdit = DateTime.now();
    }
  }

  void setDate(DateTime newDate) {
    this.date = newDate;
    print("Workout: setDate=> set uploaded to false.");
    uploaded = false;
    notifyListeners();
  }

  void deleteAction(String actionId) {
    // Action ac = actions[actionId];
    // this.points -= ac.points;
    actions.removeWhere((key, value) => key == actionId);
    print("Workout: deleted action from user => set uploaded to false.");
    uploaded = false;
    latestEdit = DateTime.now();
  }
}
