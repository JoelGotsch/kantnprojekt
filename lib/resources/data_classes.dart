import 'dart:ffi';
import 'package:intl/intl.dart';

// class Task {
//   List<Task> tasks;
//   String note;
//   DateTime timeToComplete;
//   bool completed;
//   String repeats;
//   DateTime deadline;
//   List<DateTime> reminders;
//   int taskId;
//   String title;
  
//   Task(this.title, this.completed, this.taskId, this.note);

//   factory Task.fromJson(Map<String, dynamic> parsedJson) {
//     return Task(
//       parsedJson['title'],
//       parsedJson['completed'],
//       parsedJson['id'],
//       parsedJson['note'],
//       );
//   }
// }



// import 'package:flutter/rendering.dart';

class BackendUser {
  String username;
  String email;
  String password;
  String api_key;
  int id;

  BackendUser(this.username, this.email, this.password, this.id, this.api_key);

  factory BackendUser.fromJson(Map<String, dynamic> parsedJson) {
    return BackendUser(
      parsedJson['username'],
      parsedJson['emailadress'],
      parsedJson['password'],
      parsedJson['api_key'],
      parsedJson['id'],
      );
  }

}

class Exercise{
  int exerciseId;
  String title;
  String note;
  int userId;
  String unit;
  Float points;
  Float maxPointsDay;
  int weeklyAllowance;

  Exercise(this.title, this.note, this.unit, this.points, this.maxPointsDay, this.weeklyAllowance);

  factory Exercise.fromJson(Map<String, dynamic> parsedJson) {
    return Exercise(
      parsedJson['title'],
      parsedJson['note'],
      parsedJson['unit'],
      parsedJson['points'],
      parsedJson['max_points_day'],
      parsedJson['weekly_allowance'],
      );
  }
}

class Action{
  int actionId;
  Exercise exercise;
  Float number;
  String note;

  Action(this.exercise, this.number, this.note);

  factory Action.fromJson(Map<String, dynamic> parsedJson) {
    return Action(
      Exercise.fromJson(parsedJson['exercise']),
      parsedJson['number'],
      parsedJson['note'],
      );
  }
}

class Workout{
  int workoutId;
  String userId;
  DateTime date;
  String note;
  List<Action> actions;

  Workout(this.workoutId, this.userId, this.date, this.note);

  factory Workout.fromJson(Map<String, dynamic> parsedJson) {
    return Workout(
      parsedJson['id'],
      parsedJson['user_id'].toString(),
      new DateFormat("EEE, d MMM yyyy HH:mm:ss vvv").parse(parsedJson['date']),
      parsedJson['note'].toString(),
      );
  }
}