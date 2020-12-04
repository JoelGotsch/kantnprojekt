import 'dart:convert';
import '../misc/functions.dart' as misc;
import 'exercise.dart';

class UserExercise {
  String userExerciseId;
  // String exerciseId; //from database, provided by API
  final Exercise exercise;
  // String title;
  String localId = misc.getRandomString(20);
  String note;
  final String userId;
  final String unit;
  double points;
  double maxPointsDay;
  double maxPointsWeek;
  double dailyAllowance;
  double weeklyAllowance; //deducted from number
  DateTime latestEdit = DateTime.now();
  bool isVisible = true;
  bool notDeleted = true;
  bool uploaded = false;

  String get description {
    return (exercise.description);
  }

  bool get isCheckbox {
    return (exercise.checkbox);
  }

  int get checkBoxReset {
    return (exercise.checkboxReset);
  }

  UserExercise(this.note, this.exercise, this.points, this.unit,
      {
      // this.title = "",
      this.maxPointsDay = .0,
      this.maxPointsWeek = .0,
      this.dailyAllowance = .0,
      this.weeklyAllowance = .0,
      this.localId,
      this.userId = "",
      this.latestEdit,
      this.isVisible = true,
      this.notDeleted = true});

  factory UserExercise.fromJson(Map<String, dynamic> parsedJson, Exercise exercise) {
    String id = misc.getFromJson("id", parsedJson, "") as String;
    String localId = misc.getFromJson("localId", parsedJson, id) as String;
    if (localId == null || localId == "" || localId == "null") {
      throw ("tried to add exercise from json with empty id: $parsedJson");
    }
    // String title = misc.getFromJson("title", parsedJson, "") as String;
    String unit = misc.getFromJson("unit", parsedJson, "") as String;
    String note = misc.getFromJson("note", parsedJson, "") as String;
    String userId = misc.getFromJson("user_id", parsedJson, "") as String;
    double points = misc.getFromJson("points", parsedJson, .0) as double;
    double maxPointsDay = misc.getFromJson("max_points_day", parsedJson, .0) as double;
    double maxPointsWeek = misc.getFromJson("max_points_week", parsedJson, .0) as double;
    double dailyAllowance = misc.getFromJson("daily_allowance", parsedJson, .0) as double;
    double weeklyAllowance = misc.getFromJson("weekly_allowance", parsedJson, .0) as double;
    DateTime latestEdit = DateTime.parse(misc.getFromJson("latest_edit", parsedJson, "2020-01-01 00:00:00.000") as String);
    bool isVisible = misc.getFromJson("is_visible", parsedJson, "true").toString().toLowerCase() == "true";
    bool notDeleted = misc.getFromJson("not_deleted", parsedJson, "true").toString().toLowerCase() == "true";
    bool uploaded = misc.getFromJson("uploaded", parsedJson, "true").toString().toLowerCase() == "true";
    UserExercise ex = UserExercise(
      note,
      exercise,
      points,
      unit,
      // title: exercise.title,
      maxPointsDay: maxPointsDay,
      maxPointsWeek: maxPointsWeek,
      dailyAllowance: dailyAllowance,
      weeklyAllowance: weeklyAllowance,
      localId: localId,
      userId: userId,
      latestEdit: latestEdit,
      isVisible: isVisible,
      notDeleted: notDeleted,
    );
    ex.userExerciseId = id;
    ex.uploaded = uploaded;
    return (ex);
  }

  factory UserExercise.fromExercise(Exercise exercise) {
    print("Create UserExercise from exercise ${exercise.localId} (will be uploaded).");
    String id = misc.getRandomString(20);
    UserExercise ex = UserExercise(
      exercise.note,
      exercise,
      exercise.points,
      exercise.unit,
      // title: exercise.title,
      maxPointsDay: exercise.maxPointsDay,
      maxPointsWeek: exercise.maxPointsWeek,
      dailyAllowance: exercise.dailyAllowance,
      weeklyAllowance: exercise.weeklyAllowance,
      localId: id,
      userId: exercise.userId,
      latestEdit: exercise.latestEdit,
      isVisible: true,
    );
    ex.uploaded = false;
    return (ex);
  }

  factory UserExercise.fromString(String str, Exercise exercise) {
    Map<String, dynamic> parsedJson = json.decode(str);
    return (UserExercise.fromJson(parsedJson, exercise));
  }

  Map<String, dynamic> toJson() {
    // the Json is sufficient to also create an Exercise from it in the database if there is none created yet.
    if (userExerciseId == null) {
      userExerciseId = "";
    }
    return ({
      'id': userExerciseId,
      'local_id': localId,
      // 'title': title,
      'user_id': userId,
      'exercise_id': exercise.exerciseId,
      'local_exercise_id': exercise.localId,
      'note': note,
      'description': description,
      'unit': unit,
      'points': points,
      'max_points_day': maxPointsDay,
      'max_points_week': maxPointsWeek,
      'daily_allowance': dailyAllowance,
      'weekly_allowance': weeklyAllowance,
      'is_visible': isVisible,
      'checkbox': isCheckbox,
      'checkbox_reset': checkBoxReset,
      'latest_edit': latestEdit.toIso8601String(),
      'uploaded': uploaded,
      'not_deleted': notDeleted,
    });
  }

  @override
  String toString() {
    return (json.encode(this.toJson()));
  }

  bool equals(UserExercise ex) {
    // returns true if everything, including the ids match
    return (exercise.equals(ex.exercise) &&
        localId == ex.localId &&
        // title == ex.title &&
        note == ex.note &&
        unit == ex.unit &&
        userId == ex.userId &&
        points == ex.points &&
        maxPointsDay == ex.maxPointsDay &&
        maxPointsWeek == ex.maxPointsWeek &&
        dailyAllowance == ex.dailyAllowance &&
        weeklyAllowance == ex.weeklyAllowance &&
        uploaded == ex.uploaded &&
        notDeleted == ex.notDeleted);
  }

  String get title {
    return (exercise.title);
  }
}
