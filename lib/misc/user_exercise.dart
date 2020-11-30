import 'dart:convert';
import '../misc/functions.dart' as misc;
import 'exercise.dart';

class UserExercise {
  String userExerciseId;
  // String exerciseId; //from database, provided by API
  final Exercise exercise;
  String title;
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
  bool _uploaded = false;

  bool get isUploaded {
    return (_uploaded);
  }

  String get description {
    return (exercise.description);
  }

  bool get isCheckbox {
    return (exercise.checkbox);
  }

  int get checkBoxReset {
    return (exercise.checkboxReset);
  }

  set uploaded(bool value) {
    _uploaded = value;
  }

  UserExercise(this.note, this.exercise, this.points, this.unit,
      {this.title = "",
      this.maxPointsDay = .0,
      this.maxPointsWeek = .0,
      this.dailyAllowance = .0,
      this.weeklyAllowance = .0,
      this.localId,
      this.userId = "",
      this.latestEdit,
      this.isVisible = true});

  factory UserExercise.fromJson(Map<String, dynamic> parsedJson, Exercise exercise) {
    String id;
    // print(parsedJson);
    if (parsedJson['id'].toString().length > 0) {
      id = parsedJson['id'];
    } else {
      id = parsedJson['local_id'];
    }
    String title = misc.getFromJson("title", parsedJson, "") as String;
    if (title == "") {
      throw ("Invalid json!");
    }
    String unit = misc.getFromJson("unit", parsedJson, "") as String;
    String note = misc.getFromJson("note", parsedJson, "") as String;
    String userId = misc.getFromJson("user_id", parsedJson, "") as String;
    double points = misc.getFromJson("points", parsedJson, .0) as double;
    double maxPointsDay = misc.getFromJson("max_points_day", parsedJson, .0) as double;
    double maxPointsWeek = misc.getFromJson("max_points_week", parsedJson, .0) as double;
    double dailyAllowance = misc.getFromJson("daily_allowance", parsedJson, .0) as double;
    double weeklyAllowance = misc.getFromJson("weekly_allowance", parsedJson, .0) as double;
    DateTime latestEdit = DateTime.parse(misc.getFromJson("latest_edit", parsedJson, "2020-01-01 00:00:00.000") as String);
    bool isVisible = misc.getFromJson("is_visible", parsedJson, true);
    UserExercise ex = UserExercise(
      note,
      exercise,
      points,
      unit,
      title: title,
      maxPointsDay: maxPointsDay,
      maxPointsWeek: maxPointsWeek,
      dailyAllowance: dailyAllowance,
      weeklyAllowance: weeklyAllowance,
      localId: id,
      userId: userId,
      latestEdit: latestEdit,
      isVisible: isVisible,
    );
    // if (parsedJson['not_deleted'] != null) {
    //   ex._notDeleted = parsedJson['not_deleted'];
    // }
    if (parsedJson['uploaded'] != null) {
      ex.uploaded = parsedJson['uploaded'];
    } else {
      // from api
      ex.uploaded = true;
    }
    return (ex);
  }

  factory UserExercise.fromExercise(Exercise exercise) {
    String id = misc.getRandomString(20);
    UserExercise ex = UserExercise(
      exercise.note,
      exercise,
      exercise.points,
      exercise.unit,
      title: exercise.title,
      maxPointsDay: exercise.maxPointsDay,
      maxPointsWeek: exercise.maxPointsWeek,
      dailyAllowance: exercise.dailyAllowance,
      weeklyAllowance: exercise.weeklyAllowance,
      localId: id,
      userId: exercise.userId,
      latestEdit: exercise.latestEdit,
      isVisible: true,
    );
    // if (parsedJson['not_deleted'] != null) {
    //   ex._notDeleted = parsedJson['not_deleted'];
    // }
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
      userExerciseId = localId;
    }
    return ({
      'id': userExerciseId,
      'local_id': localId,
      'title': title,
      'user_id': userId,
      'exercise_id': exercise.localId,
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
      'uploaded': _uploaded,
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
        title == ex.title &&
        note == ex.note &&
        unit == ex.unit &&
        userId == ex.userId &&
        points == ex.points &&
        maxPointsDay == ex.maxPointsDay &&
        maxPointsWeek == ex.maxPointsWeek &&
        dailyAllowance == ex.dailyAllowance &&
        weeklyAllowance == ex.weeklyAllowance &&
        _uploaded == ex._uploaded);
  }
}
