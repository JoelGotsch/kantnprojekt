import 'dart:convert';
import 'exercise_parents.dart';

import '../misc/functions.dart' as misc;

class Exercise extends ExerciseParent {
  String exerciseId; //from database, provided by API
  String localId = misc.getRandomString(20);
  final String title;
  String note;
  final String description;
  final String userId;
  final String unit;
  final double points;
  final double maxPointsDay;
  final double maxPointsWeek;
  final double dailyAllowance;
  final double weeklyAllowance; //deducted from number
  final bool checkbox; // is this exercise just "checked"
  final int checkboxReset; // in which frequency is it reset? (1 = per reset checkbox per workout, 2 = reset per day, 3 = reset per week, 4 = reset per month)
  DateTime latestEdit = DateTime.now();
  bool uploaded = true;
  // bool _notDeleted = true; // used when deleting exercises

  Exercise(this.title, this.note, this.unit, this.points,
      {this.description = "",
      this.maxPointsDay = .0,
      this.maxPointsWeek = .0,
      this.dailyAllowance = .0,
      this.weeklyAllowance = .0,
      this.exerciseId = "",
      this.localId,
      this.userId = "",
      this.latestEdit,
      this.checkbox = false,
      this.checkboxReset = 2,
      this.uploaded = true});

  factory Exercise.newWithUserId(userId) {
    return (Exercise("", "", "", 0, userId: userId, latestEdit: DateTime.now(), localId: misc.getRandomString(30), uploaded: true));
  }

  factory Exercise.fromJson(Map<String, dynamic> parsedJson) {
    String id = misc.getFromJson("id", parsedJson, "") as String;
    String localId = misc.getFromJson("localId", parsedJson, id) as String;
    String title = misc.getFromJson("title", parsedJson, "") as String;
    if (title == "") {
      throw ("Invalid json!");
    }
    String note = misc.getFromJson("note", parsedJson, "") as String;
    String unit = misc.getFromJson("unit", parsedJson, "") as String;
    String description = misc.getFromJson("description", parsedJson, "") as String;
    String userId = misc.getFromJson("user_id", parsedJson, "") as String;
    double points = misc.getFromJson("points", parsedJson, .0) as double;
    double maxPointsDay = misc.getFromJson("max_points_day", parsedJson, .0) as double;
    double maxPointsWeek = misc.getFromJson("max_points_week", parsedJson, .0) as double;
    double dailyAllowance = misc.getFromJson("daily_allowance", parsedJson, .0) as double;
    double weeklyAllowance = misc.getFromJson("weekly_allowance", parsedJson, .0) as double;
    DateTime latestEdit = DateTime.parse(misc.getFromJson("latest_edit", parsedJson, "2020-01-01 00:00:00.000").toString());
    bool uploaded = misc.getFromJson("uploaded", parsedJson, "true").toString().toLowerCase() == "true";
    bool checkbox = misc.getFromJson("checkbox", parsedJson, "false").toString().toLowerCase() == "true";
    int checkboxReset = misc.getFromJson("checkbox_reset", parsedJson, 2);
    if (localId == null || localId == "" || localId == "null" || title == "" || userId == "") {
      throw ("tried to add exercise from invalid json: $parsedJson");
    }
    print("Exercise from Json input: uploaded = $uploaded");
    Exercise ex = Exercise(title, note, unit, points,
        description: description,
        maxPointsDay: maxPointsDay,
        maxPointsWeek: maxPointsWeek,
        dailyAllowance: dailyAllowance,
        weeklyAllowance: weeklyAllowance,
        exerciseId: id,
        localId: localId,
        userId: userId,
        latestEdit: latestEdit,
        checkbox: checkbox,
        checkboxReset: checkboxReset);
    ex.uploaded = uploaded;
    return (ex);
  }

  factory Exercise.fromString(String str) {
    Map<String, dynamic> parsedJson = json.decode(str);
    return (Exercise.fromJson(parsedJson));
  }

  @override
  String toString() {
    return (json.encode(this.toJson()));
  }

  Map<String, dynamic> toJson() {
    if (exerciseId == null) {
      exerciseId = localId;
    }
    return ({
      'id': exerciseId,
      'local_id': localId,
      'title': title,
      'user_id': userId,
      'note': note,
      'description': description,
      'unit': unit,
      'points': points,
      'max_points_day': maxPointsDay,
      'max_points_week': maxPointsWeek,
      'daily_allowance': dailyAllowance,
      'weekly_allowance': weeklyAllowance,
      'latest_edit': latestEdit.toIso8601String(),
      'checkbox': checkbox,
      'checkbox_reset': checkboxReset,
      'uploaded': uploaded,
      // 'not_deleted': _notDeleted,
    });
  }

  bool equals(Exercise ex) {
    // returns true if everything, including the ids match
    return (exerciseId == ex.exerciseId &&
        localId == ex.localId &&
        title == ex.title &&
        note == ex.note &&
        unit == ex.unit &&
        userId == ex.userId &&
        points == ex.points &&
        maxPointsDay == ex.maxPointsDay &&
        maxPointsWeek == ex.maxPointsWeek &&
        dailyAllowance == ex.dailyAllowance &&
        weeklyAllowance == ex.weeklyAllowance &&
        uploaded == ex.uploaded);
  }
}
