import 'dart:convert';
import '../misc/functions.dart' as misc;
import 'exercise.dart';

class ChallengeExercise {
  String challengeExerciseId;
  // String exerciseId; //from database, provided by API
  // String title;
  String localId = misc.getRandomString(20);
  String note;
  final String challengeId;
  String exerciseId;
  String localExerciseId;
  double points;
  double maxPointsDay;
  double maxPointsWeek;
  double dailyAllowance;
  double weeklyAllowance; //deducted from number
  String unit;
  String description;
  bool checkbox;
  int checkboxReset;
  String title;

  ChallengeExercise(
    this.note,
    this.points,
    this.exerciseId,
    this.localExerciseId,
    this.title, {
    this.maxPointsDay = .0,
    this.maxPointsWeek = .0,
    this.dailyAllowance = .0,
    this.weeklyAllowance = .0,
    this.localId,
    this.challengeId = "",
    this.unit = "",
    this.description = "",
    this.checkbox = false,
    this.checkboxReset = 2,
  });

  factory ChallengeExercise.fromJson(Map<String, dynamic> parsedJson) {
    String id = misc.getFromJson("id", parsedJson, "") as String;
    String localId = misc.getFromJson("localId", parsedJson, id) as String;
    if (localId == null || localId == "" || localId == "null") {
      throw ("tried to add exercise from json with empty id: $parsedJson");
    }
    String exerciseId = misc.getFromJson("exercise_id", parsedJson, "") as String;
    String localExerciseId = misc.getFromJson("local_exercise_id", parsedJson, exerciseId) as String;
    if (localId == null || localId == "" || localId == "null") {
      throw ("tried to add exercise from json with empty id: $parsedJson");
    }
    String title = misc.getFromJson("title", parsedJson, "") as String;
    String note = misc.getFromJson("note", parsedJson, "") as String;
    String challengeId = misc.getFromJson("challenge_id", parsedJson, "") as String;
    double points = misc.getFromJson("points", parsedJson, .0) as double;
    double maxPointsDay = misc.getFromJson("max_points_day", parsedJson, .0) as double;
    double maxPointsWeek = misc.getFromJson("max_points_week", parsedJson, .0) as double;
    double dailyAllowance = misc.getFromJson("daily_allowance", parsedJson, .0) as double;
    double weeklyAllowance = misc.getFromJson("weekly_allowance", parsedJson, .0) as double;
    String unit = misc.getFromJson("unit", parsedJson, "") as String;
    String description = misc.getFromJson("description", parsedJson, "") as String;
    bool checkbox = misc.getFromJson("checkbox", parsedJson, "false").toString().toLowerCase() == "true";
    int checkboxReset = misc.getFromJson("checkbox_reset", parsedJson, 0) as int;
    ChallengeExercise ex = ChallengeExercise(
      note,
      points,
      exerciseId,
      localExerciseId,
      title,
      maxPointsDay: maxPointsDay,
      maxPointsWeek: maxPointsWeek,
      dailyAllowance: dailyAllowance,
      weeklyAllowance: weeklyAllowance,
      localId: localId,
      challengeId: challengeId,
      unit: unit,
      description: description,
      checkbox: checkbox,
      checkboxReset: checkboxReset,
    );
    ex.challengeExerciseId = id;
    return (ex);
  }

  factory ChallengeExercise.fromExercise(Exercise exercise, challengeId) {
    // print("Create ChallengeExercise from exercise ${exercise.localId} (will be uploaded).");
    String id = misc.getRandomString(20);
    ChallengeExercise ex = ChallengeExercise(
      exercise.note,
      exercise.points,
      exercise.exerciseId,
      exercise.localId,
      exercise.title,
      maxPointsDay: exercise.maxPointsDay,
      maxPointsWeek: exercise.maxPointsWeek,
      dailyAllowance: exercise.dailyAllowance,
      weeklyAllowance: exercise.weeklyAllowance,
      localId: id,
      challengeId: challengeId,
      unit: exercise.unit,
      description: exercise.description,
      checkbox: exercise.checkbox,
      checkboxReset: exercise.checkboxReset,
    );
    return (ex);
  }

  factory ChallengeExercise.fromString(String str) {
    Map<String, dynamic> parsedJson = json.decode(str);
    return (ChallengeExercise.fromJson(parsedJson));
  }

  Map<String, dynamic> toJson() {
    // the Json is sufficient to also create an Exercise from it in the database if there is none created yet.
    if (challengeExerciseId == null) {
      challengeExerciseId = "";
    }

    return ({
      'id': challengeExerciseId,
      'local_id': localId,
      'title': title,
      'challenge_id': challengeId,
      'exercise_id': exerciseId,
      'local_exercise_id': localExerciseId,
      'points': points,
      'unit': unit,
      'max_points_day': maxPointsDay,
      'max_points_week': maxPointsWeek,
      'daily_allowance': dailyAllowance,
      'weekly_allowance': weeklyAllowance,
      'checkbox': checkbox,
      'checkbox_reset': checkboxReset,
      'note': note,
      'description': description,
    });
  }

  @override
  String toString() {
    return (json.encode(this.toJson()));
  }
}
