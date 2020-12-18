// import 'dart:ffi';
import 'dart:convert';
// import 'dart:html';
// import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../misc/global_data.dart';

import '../misc/functions.dart';
import '../misc/challenge_exercise.dart';

class ChallengeWorkout {
  // for now only store points per day:
  final DateTime date;
  final double points;

  ChallengeWorkout(this.date, this.points);

  factory ChallengeWorkout.fromJson(Map<String, dynamic> parsedJson) {
    DateTime date = DateTime.parse(getFromJson("date", parsedJson, "2020-01-01 00:00:00.000").toString());
    double points = getFromJson("points", parsedJson, 0);
    ChallengeWorkout chWo = ChallengeWorkout(date, points);
    return (chWo);
  }

  Map<String, dynamic> toJson() {
    return ({
      'date': date.toIso8601String(),
      'points': points,
    });
  }
}

class ChallengeUser {
  final String userId;
  String userName;
  final DateTime startedChallenge;
  DateTime latestEdit;
  Map<String, ChallengeWorkout> userWorkouts;
  String hash = "";

  ChallengeUser(this.userId, this.userName, this.startedChallenge, this.latestEdit, this.hash);

  factory ChallengeUser.fromJson(Map<String, dynamic> parsedJson) {
    String userId = getFromJson("user_id", parsedJson, "").toString();
    String userName = getFromJson("user_name", parsedJson, "").toString();
    DateTime startedChallenge = DateTime.parse(getFromJson("user_start_challenge", parsedJson, "2020-01-01 00:00:00.000").toString());
    DateTime latestEdit = DateTime.parse(getFromJson("latest_edit", parsedJson, "2020-01-01 00:00:00.000").toString());
    String hash = getFromJson("hash", parsedJson, "").toString();
    ChallengeUser chUs = ChallengeUser(userId, userName, startedChallenge, latestEdit, hash);
    // now adding challengeWorkouts
    try {
      (parsedJson['workouts'] as Map<String, dynamic>).forEach((key, value) {
        try {
          chUs.userWorkouts.putIfAbsent(value['user_id'], () => ChallengeWorkout.fromJson(value as Map<String, dynamic>));
        } catch (e) {
          print("Couldn't create/add workout-data from challenge-json: $e");
        }
      });
    } catch (e) {
      print("No workout data was provided for this challenge-user.");
    }
    return (chUs);
  }

  void updateFromJson(Map<String, dynamic> parsedJson) {
    // deleting all workouts after oldest workout in parsedJson
    // adding new workouts
    // notifylisteners/ save
    DateTime minDate = DateTime.now();
    bool minDateChanged = false;
    Map<String, ChallengeWorkout> updatedUserWorkouts;
    List<String> deleteUserWorkouts;
    try {
      String newHash = getFromJson("hash", parsedJson, hash).toString();
      DateTime newLatestEdit = DateTime.parse(getFromJson("latest_edit", parsedJson, latestEdit.toIso8601String()).toString());
      String newUserName = getFromJson("user_name", parsedJson, userName).toString();
      hash = newHash;
      latestEdit = newLatestEdit;
      userName = newUserName;
      (parsedJson['workouts'] as Map<String, dynamic>).forEach((key, value) {
        try {
          ChallengeWorkout chWo = ChallengeWorkout.fromJson(value as Map<String, dynamic>);
          updatedUserWorkouts.putIfAbsent(value['user_id'], () => chWo);
          if (chWo.date.compareTo(minDate) < 0) {
            minDate = chWo.date;
            minDateChanged = true;
          }
        } catch (e) {
          print("Couldn't create/add user-data from challenge-json: $e");
          print("action json: $value");
        }
      });
    } catch (e) {
      print("No dfetailed data was provided for this challenge.");
    }
    if (minDateChanged) {
      userWorkouts.forEach((key, value) {
        if (value.date.compareTo(minDate) > 0) {
          deleteUserWorkouts.add(key);
        }
      });
      deleteUserWorkouts.forEach((element) {
        userWorkouts.remove(element);
      });
      updatedUserWorkouts.forEach((key, value) {
        userWorkouts.putIfAbsent(key, () => value);
      });
    }
  }

  Map<String, dynamic> toJson({int level = 0}) {
    // level 0: all, level 1: hash-compatible, level 2: headers (hash, latest_edit)
    Map<String, dynamic> helper = {};
    Map<String, dynamic> returnMap = {};

    userWorkouts.forEach((key, value) {
      helper[key] = value.toJson();
    });
    return ({
      'user_id': userId,
      'user_name': userName,
      'user_start_challenge': startedChallenge.toIso8601String(),
      'workouts': helper,
      'latest_edit': latestEdit.toIso8601String(),
      'hash': hash,
    });
  }

  bool verifyHash() {
    // in the future:
    // create compatible json/string output
    // calculate hash
    // check hash vs stored hash

    // to be used after update
    return (true);
  }
}

class Challenge with ChangeNotifier {
  String challengeId; //later from database, provided by API
  String name = "";
  String description = "";
  Map<String, ChallengeExercise> exercises = {}; //exerciseId(server):ChallengeExercise
  Map<String, ChallengeUser> users = {}; //userId: challengeuser
  double minPoints;
  DateTime startDate;
  DateTime endDate;
  String evalPeriod = "week"; // could be "day", "week", "month", "year"
  bool uploaded = false;
  DateTime lastRefresh = DateTime(2020);
  String hash = "";

  Challenge({
    this.challengeId,
    this.name,
    this.description,
    this.minPoints,
    this.startDate,
    this.endDate,
    this.evalPeriod,
    this.uploaded,
    this.lastRefresh,
    this.hash,
  });

  factory Challenge.empty() {
    return (Challenge(
        challengeId: "",
        name: "",
        description: "",
        minPoints: 0,
        startDate: DateTime.now(),
        endDate: DateTime(DateTime.now().year + 1, DateTime.now().month),
        evalPeriod: "week",
        uploaded: true,
        lastRefresh: DateTime.now(),
        hash: ""));
  }

  factory Challenge.fromJson(Map<String, dynamic> parsedJson) {
    String challengeId = getFromJson("id", parsedJson, "");
    String name = getFromJson("name", parsedJson, "").toString();
    String description = getFromJson("description", parsedJson, "").toString();
    double minPoints = getFromJson("min_points", parsedJson, 0);
    DateTime startDate = DateTime.parse(getFromJson("start_date", parsedJson, "2020-01-01 00:00:00.000").toString());
    DateTime endDate = DateTime.parse(getFromJson("end_date", parsedJson, "2020-01-01 00:00:00.000").toString());
    String evalPeriod = getFromJson("eval_period", parsedJson, "").toString();
    DateTime lastRefresh = DateTime.parse(getFromJson("last_refresh", parsedJson, DateTime.now().toIso8601String()).toString());
    String hash = getFromJson("hash", parsedJson, "").toString();

    bool uploaded = getFromJson("uploaded", parsedJson, "true").toString().toLowerCase() == "true";
    // print("Workout from Json input: $parsedJson, uploaded = $uploaded");
    print("Workout from Json input uploaded = $uploaded");

    if (challengeId == null || challengeId == "" || challengeId == "None" || challengeId == "null") {
      throw ("Invalid input to challenge.fromjson: $parsedJson");
    }
    Challenge ch = Challenge(
        challengeId: challengeId,
        name: name,
        description: description,
        minPoints: minPoints,
        startDate: startDate,
        endDate: endDate,
        evalPeriod: evalPeriod,
        uploaded: uploaded,
        lastRefresh: lastRefresh,
        hash: hash);
    // add exercises
    try {
      (parsedJson['users'] as Map<String, dynamic>).forEach((key, value) {
        try {
          ch.users.putIfAbsent(value['user_id'], () => ChallengeUser.fromJson(value as Map<String, dynamic>));
        } catch (e) {
          print("Couldn't create/add user-data from challenge-json: $e");
        }
      });
    } catch (e) {
      print("No dfetailed data was provided for this challenge.");
    }
    try {
      (parsedJson['exercises'] as Map<String, dynamic>).forEach((key, value) {
        try {
          ch.exercises.putIfAbsent(value['exercise_id'], () => ChallengeExercise.fromJson(value as Map<String, dynamic>));
        } catch (e) {
          print("Couldn't create/add user-data from challenge-json: $e");
        }
      });
    } catch (e) {
      print("No dfetailed data was provided for this challenge.");
    }
    // wo.latestEdit =latestEdit;
    return (ch);
  }

  void updateFromJson(Map<String, dynamic> parsedJson) {
    // deleting all workouts after oldest workout in parsedJson
    // adding new workouts
    // notifylisteners/ save
    ChallengeUser chUs;
    try {
      String newname = getFromJson("name", parsedJson, name).toString();
      String newdescription = getFromJson("description", parsedJson, description).toString();
      double newminPoints = getFromJson("min_points", parsedJson, minPoints);
      DateTime newstartDate = DateTime.parse(getFromJson("start_date", parsedJson, startDate.toIso8601String()).toString());
      DateTime newendDate = DateTime.parse(getFromJson("end_date", parsedJson, endDate.toIso8601String()).toString());
      String newevalPeriod = getFromJson("eval_period", parsedJson, evalPeriod).toString();
      DateTime newlastRefresh = DateTime.parse(getFromJson("last_refresh", parsedJson, lastRefresh.toIso8601String()).toString());
      String newhash = getFromJson("hash", parsedJson, hash).toString();
      name = newname;
      description = newdescription;
      minPoints = newminPoints;
      startDate = newstartDate;
      endDate = newendDate;
      evalPeriod = newevalPeriod;
      lastRefresh = newlastRefresh;
      hash = newhash;
      // exercises shouldn't change over time!!
      (parsedJson['users'] as Map<String, dynamic>).forEach((key, value) {
        try {
          if (users.containsKey(value["user_id"])) {
            chUs = users[value["user_id"]];
            chUs.updateFromJson(value as Map<String, dynamic>);
          } else {
            chUs = ChallengeUser.fromJson(value as Map<String, dynamic>);
            users.putIfAbsent(value['user_id'], () => chUs);
          }
        } catch (e) {
          print("Couldn't create/add user-data from challenge-json: $e");
          print("action json: $value");
        }
      });
    } catch (e) {
      print("No dfetailed data was provided for this challenge.");
    }
  }

  void setLastRefresh() {
    List<DateTime> chUserEditTimes = [lastRefresh];
    users.forEach((key, value) => chUserEditTimes.add(value.latestEdit));
    lastRefresh = calcMaxDate(chUserEditTimes);
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> helperUsers = {};
    users.forEach((key, value) {
      helperUsers[key] = value.toJson();
    });
    Map<String, dynamic> helperExercises = {};
    exercises.forEach((key, value) {
      helperExercises[key] = value.toJson();
    });
    return ({
      'id': challengeId,
      'name': name,
      'description': description,
      'min_points': minPoints,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'eval_period': evalPeriod,
      'users': helperUsers,
      'exercises': helperExercises,
      'uploaded': uploaded,
      'last_refresh': lastRefresh.toIso8601String(),
      'hash': hash,
    });
  }

  @override
  String toString() {
    return (json.encode(this.toJson()));
  }

  bool verifyHash() {
    // in the future:
    // create compatible json/string output
    // calculate hash
    // check hash vs stored hash

    // to be used after update
    return (true);
  }
}
