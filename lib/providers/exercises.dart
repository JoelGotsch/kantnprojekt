import 'dart:convert';
// import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../misc/exercise.dart';
import '../misc/global_data.dart';
import '../misc/user_exercise.dart';
import '../misc/functions.dart' as funcs;

class Exercises with ChangeNotifier {
  Map<String, Exercise> _exercises = {};
  Map<String, UserExercise> _userExercises = {};
  // Map<String, ChallengeExercise> _challenge_exercises = {};
  String token;
  String userId;
  DateTime lastRefresh = DateTime(2020);
  bool loadedOnlineExercises = false; // makes sure that syncronize is only called once
  bool loadingOnlineExercises = false; // prevents that within an update, the sync process is started again.
  // TODO: test if fromPrevious while loading causes problems

  Exercises(this.token, this.userId, this._exercises, this._userExercises, this.lastRefresh);

  factory Exercises.create() {
    print("Exercises created empty.");
    Exercises exs = Exercises("", "", {}, {}, DateTime(2020));
    return (exs);
  }

  factory Exercises.fromPrevious(String token, String userId, Exercises previousExercises) {
    print("Exercises.fromPrevious is run.");
    previousExercises.token = token;
    previousExercises.userId = userId;
    if (token != "" && !previousExercises.loadedOnlineExercises && !previousExercises.loadingOnlineExercises) {
      previousExercises.loadingOnlineExercises = true;
      previousExercises.setup();
    } else if (token == "") {
      // on logout, token is set to ""
      previousExercises = Exercises.create();
    }
    return (previousExercises);
  }

  Map<String, UserExercise> get exercises {
    // returns visible UserExercises which are uploaded (have a non-empty exerciseId)
    print("getting list of visible exercises");
    Map<String, UserExercise> visibleExercises = {};
    _userExercises.forEach((key, value) {
      if (value.isVisible && value.userExerciseId != "" && value.userExerciseId != null && value.notDeleted && value.exercise.exerciseId != "") {
        visibleExercises.putIfAbsent(key, () => value);
      }
    });
    // return {...visibleExercises};
    return visibleExercises;
  }

  Map<String, Exercise> get commonExercises {
    return _exercises;
  }

  Map<String, UserExercise> get userExercises {
    // print("userExercises = $_userExercises");
    return _userExercises;
  }

  List<UserExercise> get sortedUserExercises {
    Map<String, UserExercise> sortedUsEx = this.userExercises;
    List mapKeys = sortedUsEx.keys.toList(growable: false);
    mapKeys.sort((k1, k2) => sortedUsEx[k1].latestEdit.compareTo(sortedUsEx[k2].latestEdit));
    List<UserExercise> returnList = [];
    mapKeys.forEach((k1) {
      returnList.insert(0, sortedUsEx[k1]);
    });
    return (returnList);
  }

  bool addingFromJson(Map<String, dynamic> exercisesMap, Map<String, dynamic> userExercisesMap, {saveAndNotifyIfChanged: true}) {
    // returns true if an exercise or UserExercise was added or updated.
    // if saveAndNotifyIfChanged is true, then new exercises are saved and NotifyListeners is performed here.
    bool _addedExercise = false;
    bool _addedUserExercise = false;
    print("adding exercises from json");
    exercisesMap.forEach((key, value) {
      try {
        Exercise ex = Exercise.fromJson(value);
        _addedExercise = this.addExercise(ex, saveAndNotifyIfChanged: false) || _addedExercise;
        // print("added exercise from storage: ${ex.exerciseId}");
      } catch (e) {
        print("Couldn't load exercises from Json. " + e.toString());
      }
    });
    try {
      userExercisesMap.forEach((key, value) {
        try {
          // print("ex from json: $key: $value");
          Exercise ex = this.getExercise(value["exercise_id"]);
          UserExercise usEx = UserExercise.fromJson(value, ex);
          _addedUserExercise = this.addUserExercise(usEx, saveAndNotifyIfChanged: false) || _addedUserExercise;
        } catch (e) {
          print("Couldn't load user-exercise from Json. " + e.toString());
          print(value);
        }

        // print("added user-exercise from storage: ${usEx.userExerciseId}");
      });
    } catch (e) {
      print("Couldn't load user-exercises from Json. " + e.toString());
    }
    if (saveAndNotifyIfChanged && (_addedExercise || _addedUserExercise)) {
      saveExercises();
      saveUserExercises();
      notifyListeners();
    }
    return (_addedExercise || _addedUserExercise);
  }

  Future<bool> addingFromStorage({bool saveAndNotifyIfChanged = false}) async {
    bool addedExercise = false;
    print("adding exercises from storage");
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> exercisesMap = json.decode(prefs.getString("Exercises"));
      Map<String, dynamic> userExerciseMap = json.decode(prefs.getString("UserExercises"));
      addedExercise = this.addingFromJson(exercisesMap, userExerciseMap, saveAndNotifyIfChanged: false);
      if (saveAndNotifyIfChanged && addedExercise) {
        this.saveExercises();
        this.saveUserExercises();
        notifyListeners();
      }
      return (addedExercise);
    } catch (Exception) {
      print("Error: Couldn't load exercises/ userExercises from storage, probably never saved them. " + Exception.toString());
    }
    return (false);
  }

  void setup() async {
    await addingFromStorage(saveAndNotifyIfChanged: false);
    bool addedExercise = await syncronize(saveAndNotifyIfChanged: false);
    print("Exercises setup completed, now notifying listeners");
    if (addedExercise) {
      this.saveExercises();
      this.saveUserExercises();
    }
    notifyListeners();
  }

  void setLastRefresh() {
    List<DateTime> exerciseEditTimes = [lastRefresh];
    _exercises.forEach((key, value) => exerciseEditTimes.add(value.latestEdit));
    _userExercises.forEach((key, value) => exerciseEditTimes.add(value.latestEdit));
    lastRefresh = funcs.calcMaxDate(exerciseEditTimes);
  }

  Future<bool> syncronize({bool saveAndNotifyIfChanged = true}) async {
    // returns true if an exercise was added or updated.
    bool addedExercise = false;
    bool _saving = false;
    // loads workouts from sharedPreferences (i.e. Phone storage)
    print("exercises syncronize is running..");
    // now fetching the whole list of workouts with newest dates to compare to the one on the phone:
    Map<String, Map<String, DateTime>> exerciseEditDates = {};
    List<String> serverNewUserExIds = [];
    List<String> serverNewExIds = [];
    List<String> deletedExIds = [];
    List<String> deletedUserExIds = [];
    try {
      exerciseEditDates = await this.fetchHeaders();
      if (!exerciseEditDates.containsKey("common_exercises")) {
        print("Couldn't syncronize due to no connection to server.");
        return (false);
      }
      exerciseEditDates["common_exercises"].forEach((exId, exLatestEdit) {
        if (existsExercise(exId)) {
          //maybe an update?
          Exercise ex = getExercise(exId);
          if (ex.latestEdit.compareTo(exLatestEdit) < 0) {
            // exLatestEdit is later => info on server is newer
            print("Found newer version of exercise $exId on server: server: ${exLatestEdit.toIso8601String()} vs local ${ex.latestEdit.toIso8601String()}");
            serverNewExIds.add(exId);
          } else if (ex.latestEdit.compareTo(exLatestEdit) > 0) {
            print("Found newer version of exercise $exId on phone: server: ${exLatestEdit.toIso8601String()} vs local ${ex.latestEdit.toIso8601String()}");
            if (ex.uploaded) {
              print("ERROR: exercise should be newer on the phone, but it is already uploaded???");
              ex.uploaded = false;
            }
          }
        } else {
          // new exercise
          serverNewExIds.add(exId);
        }
      });
      // now deleting all the exercises which were deleted on the server:
      commonExercises.forEach((exId, ex) {
        if (!exerciseEditDates["common_exercises"].containsKey(ex.exerciseId) && ex.uploaded) {
          deletedExIds.add(exId);
        }
      });
      deletedExIds.forEach((key) {
        print("removing exercise $key and associated user-exercise because it is deleted on the server.");
        _deleteExercise(key);
      });
      exerciseEditDates["user_exercises"].forEach((exId, exLatestEdit) {
        if (existsUserExercise(exId)) {
          UserExercise ex = getUserExercise(exId);
          if (ex.latestEdit.compareTo(exLatestEdit) < 0) {
            // exLatestEdit is later => info on server is newer
            print(
                "Found newer version of user-exercise $exId on server: server: ${exLatestEdit.toIso8601String()} vs local ${ex.latestEdit.toIso8601String()}");
            serverNewUserExIds.add(exId);
          } else if (ex.latestEdit.compareTo(exLatestEdit) > 0) {
            print("Found newer version of user-exercise $exId on phone: server: ${exLatestEdit.toIso8601String()} vs local ${ex.latestEdit.toIso8601String()}");
            if (ex.uploaded) {
              print("ERROR: user-exercise should be newer on the phone, but it is already uploaded???");
              ex.uploaded = false;
            }
          }
        } else {
          serverNewUserExIds.add(exId);
        }
      });
      // now deleting all the user-exercises which were deleted on the server (except where their exercise was deleted, those are deleted from the exercise already):
      userExercises.forEach((exId, usEx) {
        if ((!exerciseEditDates["user_exercises"].containsKey(usEx.userExerciseId) && usEx.uploaded) && !deletedExIds.contains(usEx.exercise.localId)) {
          deletedUserExIds.add(exId);
        }
      });
      deletedUserExIds.forEach((key) {
        print("removing user-exercise $key because it is deleted on the server.");
        deleteUserExercise(key, false, saveAndNotifyIfChanged: false);
      });

      Map<String, Map<String, dynamic>> newExercises = await this._fetch(userExerciseIds: serverNewUserExIds, exerciseIds: serverNewExIds);
      addedExercise = addingFromJson(newExercises["common_exercises"], newExercises["user_exercises"], saveAndNotifyIfChanged: false);
      loadedOnlineExercises = true;
      print("Loaded online exercises!!");
      lastRefresh = DateTime.now();
      // print(exerciseEditDates);
      // check which editDates dont match with saved ones and get newer ones from server and post (send) if newer from app.
    } catch (e) {
      print("Error in syncronize Exercises: $e");
    }
    // this.fetchNew();
    if (saveAndNotifyIfChanged) {
      notifyListeners();
      if (_saving) {
        await this.save();
      }
    }

    addedExercise = await uploadOfflineExercises() == "" || addedExercise;
    loadingOnlineExercises = false;
    return (addedExercise);
  }

  Future<void> saveExercises() async {
    print("saving exercises");
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("Exercises", this.exercisesToString());
  }

  Future<void> saveUserExercises() async {
    print("saving user-exercises");
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("UserExercises", this.userExercisesToString(allUserExercises: true));
  }

  Future<void> save() async {
    await this.saveExercises();
    await this.saveUserExercises();
  }

  Future<Map<String, Map<String, dynamic>>> _fetch({String exerciseId, DateTime minEditDate, List<String> userExerciseIds, List<String> exerciseIds}) async {
// helper function to get data via API
    Map<String, dynamic> newExercises = {};
    Map<String, dynamic> newUserExercises = {};
    Map<String, Map<String, dynamic>> returnMap = {};
    Map<String, String> queryParameters = {};
    if (exerciseId != null) {
      queryParameters["exercise_id"] = exerciseId;
    }
    if (minEditDate != null) {
      queryParameters["latest_edit_date"] = minEditDate.toIso8601String();
    }
    if (userExerciseIds != null) {
      queryParameters["user_exercise_ids"] = userExerciseIds.join(",");
    }
    if (exerciseIds != null) {
      queryParameters["exercise_ids"] = exerciseIds.join(",");
    }
    // queryParameters["number"] = number.toString();
    Uri url = Uri.https(
      GlobalData.apiUrlStart,
      GlobalData.apiUrlVersion + "exercises",
      queryParameters,
    );
    final response = await http.get(
      url,
      headers: {
        "token": token,
        // "user_id": _userId,
      },
    );
    Map<String, dynamic> result = {
      "data": {"common_exercises": [], "user_exercises": []}
    };
    try {
      result = json.decode(response.body);
      // print(response.statusCode);
      // print("result in fetch exercises: $result");
    } catch (Exception) {
      print("Couldn't parse response in fetch exercises: " + response.toString());
    }

    if (response.statusCode == 201) {
      print("adding common exercises");
      // print(result["common_exercises"]);
      newExercises = result["data"]["common_exercises"] as Map<String, dynamic>;
      newUserExercises = result["data"]["user_exercises"] as Map<String, dynamic>;
    } else {
      // If that call was not successful, throw an error.
      throw Exception('Failed to load Exercises: ${response.body}');
    }
    returnMap.putIfAbsent("common_exercises", () => newExercises);
    returnMap.putIfAbsent("user_exercises", () => newUserExercises);
    // print("returnmap in fetch exercises: $returnMap");
    return (returnMap);
  }

  Future<Map<String, Map<String, DateTime>>> fetchHeaders() async {
    // returns a map with common_exercises and user_exercises, returns an empty map if the api call was unsuccessful
    Map<String, DateTime> commonExercises = {};
    Map<String, DateTime> userExercises = {};
    Map<String, String> queryParameters = {};
    Map<String, Map<String, DateTime>> returnMap = {};
    print("start fetching exercise headers ..");
    queryParameters["latest_edit_date_only"] = true.toString();
    Uri url = Uri.https(
      GlobalData.apiUrlStart,
      GlobalData.apiUrlVersion + "exercises",
      queryParameters,
    );
    final response = await http.get(
      url,
      headers: {
        "token": token,
        // "user_id": _userId,
      },
    );
    try {
      final Map result = json.decode(response.body);
      print("result in fetching exercise headers: $result");
      if (response.statusCode == 201 || response.statusCode == 200) {
        // for (Map json_ in result["data"]) {
        result["data"]["common_exercises"].forEach((key, value) {
          commonExercises.putIfAbsent(key, () => DateTime.parse(value));
        });
        result["data"]["user_exercises"].forEach((key, value) {
          userExercises.putIfAbsent(key, () => DateTime.parse(value));
        });
        returnMap.putIfAbsent("common_exercises", () => commonExercises);
        returnMap.putIfAbsent("user_exercises", () => userExercises);
        return (returnMap);
      } else {
        // If that call was not successful, throw an error.
        throw Exception('Failed to load exercise headers ' + result["message"]);
      }
    } catch (e) {
      throw ("Problem while fetching last edit dates of exerises: Response: ${response.body}, error:" + e.toString());
    }
  }

  Future<void> fetchNew() async {
    this.setLastRefresh();
    print("fetching new exercises since $lastRefresh");
    Map<String, Map<String, dynamic>> newExercises = await this._fetch(minEditDate: lastRefresh);
    addingFromJson(newExercises["common_exercises"], newExercises["user_exercises"], saveAndNotifyIfChanged: true);
    print("fetched new exercises");
    lastRefresh = DateTime.now();
  }

  Exercise getExercise(String exerciseId) {
    Exercise ex;
    if (_exercises.containsKey(exerciseId)) {
      ex = _exercises[exerciseId];
    } else {
      _exercises.forEach((key, ex2) {
        if (ex2.localId == exerciseId || ex2.exerciseId == exerciseId) {
          ex = ex2;
        }
      });
    }
    if (ex == null) {
      throw Exception("Tried to access exerciseID " + exerciseId.toString() + " which is not known. Maybe forgot to initialize the exercise object?");
    }
    return (ex);
  }

  bool existsExercise(String exerciseId) {
    // returns true if exerciseId can be found as either localId or exerciseId in _exercises
    bool returnval = false;
    try {
      Exercise ex = getExercise(exerciseId);
      if (ex != null) {
        returnval = true;
      }
    } catch (e) {
      returnval = false;
    }
    return (returnval);
  }

  UserExercise getUserExercise(String exerciseId) {
    UserExercise ex;
    if (_userExercises.containsKey(exerciseId)) {
      ex = _userExercises[exerciseId];
    } else {
      _userExercises.forEach((key, usEx) {
        if (usEx.userExerciseId == exerciseId || usEx.exercise.localId == exerciseId || usEx.exercise.exerciseId == exerciseId) {
          ex = usEx;
        }
      });
    }
    if (ex == null) {
      throw Exception(
          "Tried to access UserExercise with exerciseID " + exerciseId.toString() + " which is not known. Maybe forgot to initialize the exercise object?");
    }
    return (ex);
  }

  bool existsUserExercise(String exerciseId) {
    // returns true if exerciseId can be found as either localId or exerciseId in _userExercises or if one of their exercises has this id.
    bool returnval = false;
    try {
      UserExercise ex = getUserExercise(exerciseId);
      if (ex != null) {
        returnval = true;
      }
    } catch (e) {
      returnval = false;
    }
    return (returnval);
  }

  Future<Map<String, dynamic>> uploadUserExercise(UserExercise usEx, {bool saveAndNotifyIfChanged = false}) async {
    // returns true if at least one exercise was uploaded.
    // tries to upload all not uploaded workouts and updates the Ids, then saves to shared_preferences
    String errorMsg = "";
    bool _uploaded = false;
    http.Response response;
    String helper = this.userExercisesToString(exerciseMap: {usEx.localId: usEx});

    Uri url = Uri.https(
      GlobalData.apiUrlStart,
      GlobalData.apiUrlVersion + "exercises",
    );
    try {
      response = await http.post(url,
          headers: {
            "token": token,
            // "user_id": _userId,
          },
          body: helper);
      dynamic result2 = json.decode(response.body);
      // Map<String, Map<String, String>> result = result2["data"] as Map<String, Map<String, String>>; //localId:workoutId
      dynamic result = result2["data"];
      print(response.statusCode);
      // Either statusCode is not 201 or the user exercise contains a message with a dict {"status": "failure", "message": "Exercise with that title already exists. Choose a different title."} instead of the id
      if (response.statusCode == 201 || response.statusCode == 200) {
        result["user_exercises"].forEach((_localId, _userExerciseId) async {
          String localId = _localId.toString();
          String userExerciseId = _userExerciseId.toString();
          // check if Error message was delivered in the userExerciseId:
          try {
            Map<String, dynamic> exerciseMsg = _userExerciseId;
            errorMsg = "Couldn't upload Exercise " + usEx.title + ": " + exerciseMsg["message"];
            print(errorMsg);
            return ({"success": false, "message": errorMsg});
          } catch (e) {
            // print("Everything fine");
            _uploaded = true;
          }
          if ((userExerciseId == null || userExerciseId == "null" || userExerciseId == "") && !usEx.notDeleted) {
// UserExercise was deleted, the server was informed and acknowledged
            deleteUserExercise(localId, false, saveAndNotifyIfChanged: false);
          } else if (usEx.notDeleted) {
            print("uploaded user-exercise ${usEx.localId}, got id $userExerciseId");
            usEx.userExerciseId = userExerciseId;
            usEx.uploaded = true;
            if (result["common_exercises"][localId] != null) {
              // a new exercise was created; update the id as stored on server.

              Exercise ex = usEx.exercise;
              String exerciseId = result["common_exercises"][localId];
              if (ex.exerciseId != exerciseId) {
                ex.exerciseId = exerciseId;
                print("uploaded exercise ${ex.localId}, got id $exerciseId");
                ex.uploaded = true;
              }
            }
          } else {
            errorMsg = "ERROR: userExercise is not deleted but id came back empty: $usEx";
            print("ERROR: userExercise is not deleted but id came back empty: $usEx");
            print("$userExerciseId");
            return ({"success": false, "message": errorMsg});
          }
        });
      } else {
        errorMsg = "Couldn't get response from server while trying to upload offline exercises.";
        print("Couldn't get response from server while trying to upload offline exercises.");
        return ({"success": false, "message": errorMsg});
      }
    } catch (e) {
      errorMsg = "Couldn't upload offline exercises: $e";
      print("Couldn't upload offline exercises: $e");
      return ({"success": false, "message": errorMsg});
      // print(response.body);
    }
    if (_uploaded && saveAndNotifyIfChanged) {
      this.save();
      notifyListeners();
    }
    return ({"success": errorMsg == "", "message": errorMsg});
  }

  Future<Map<String, dynamic>> uploadOfflineExercises({bool saveAndNotifyIfChanged = false}) async {
    // returns true if at least one exercise was uploaded.
    // tries to upload all not uploaded workouts and updates the Ids, then saves to shared_preferences
    Map<String, UserExercise> offlineUserExercises = {};
    List<String> errorMsgs = [];
    bool _uploaded = false;
    bool _success = true;
    _userExercises.forEach((key, usEx) async {
      if (!usEx.uploaded) {
        offlineUserExercises.putIfAbsent(key, () => usEx);
        print("UserExercise $key is not uploaded yet. Will be synced now.");
        Map<String, dynamic> response = await uploadUserExercise(usEx, saveAndNotifyIfChanged: false);
        if (!response["success"]) {
          _success = false;
          errorMsgs.add(response["message"]);
        }
      }
    });
    if (_uploaded && saveAndNotifyIfChanged) {
      this.save();
      notifyListeners();
    }
    return ({"success": _success, "messages": errorMsgs});
  }

  bool addExercise(Exercise ex, {bool saveAndNotifyIfChanged = false}) {
    // returns true if an exercise was added or changed.
    // if an exercise with the same id is found, then it is just updated.
    // Only the note of the exercise can change! Otherwise it is needed to create a new Exercise.
    bool _exerciseAdded = false;
    if (ex.localId == "" || ex.localId == null) {
      throw ("Tried to add invalid exercise: $ex");
    }
    try {
      // update existing workout
      Exercise oldEx = getExercise(ex.localId);
      if (oldEx.note != ex.note) {
        print("updating exercise ${ex.localId}");
        oldEx.note = ex.note;
        oldEx.latestEdit = ex.latestEdit;
        _exerciseAdded = true;
      } else {
        print("Tried to add existing Exercise with the same note.");
      }
    } catch (e) {
      // oldEx doesn't exist
      _exercises.putIfAbsent(ex.localId, () => ex);
      print("added exercise ${ex.localId} with id ${ex.exerciseId}");
      _exerciseAdded = true;
    }
    if (saveAndNotifyIfChanged && _exerciseAdded) {
      if (!ex.uploaded) {
        this.uploadOfflineExercises();
      }
      this.saveExercises();
      notifyListeners();
    }
    return (_exerciseAdded);
  }

  void _deleteExercise(String exerciseId) {
    // this method must only be called from syncronize as the frontend-user cant delete an exercise, only the backend can.
    print("Deleting exercise $exerciseId");
    if (exerciseId == null)
      try {
        Exercise ex = getExercise(exerciseId);
        _exercises.remove(ex.localId);
        if (this.existsUserExercise(exerciseId)) {
          UserExercise usEx = getUserExercise(exerciseId);
          deleteUserExercise(usEx.localId, false);
        }
      } catch (e) {
        print("Couldn't delete Exercise $exerciseId");
      }
  }

  bool addUserExercise(UserExercise usEx, {bool saveAndNotifyIfChanged = false}) {
    // returns true if an Exercise was added or changed.
    // if an exercise with the same id is found, then it is just updated.
    // Only the note of the exercise can change! Otherwise it is needed to create a new Exercise.
    bool _exerciseAdded = false;
    if (existsUserExercise(usEx.localId)) {
      // update existing workout
      UserExercise oldEx = getUserExercise(usEx.localId);
      if (!oldEx.equals(usEx)) {
        print("updating user-exercise ${usEx.localId}");
        _userExercises.putIfAbsent(usEx.localId, () => usEx);
        if (saveAndNotifyIfChanged) {
          _exerciseAdded = true;
          notifyListeners();
        }
      } else {
        print("Error: Tried to add the same existing UserExercise again???");
      }
    } else {
      print("adding user-exercise ${usEx.localId}");
      _userExercises.putIfAbsent(usEx.localId, () => usEx);
      _exerciseAdded = true;
    }
    if (saveAndNotifyIfChanged && _exerciseAdded) {
      if (!usEx.uploaded) {
        this.uploadOfflineExercises(saveAndNotifyIfChanged: saveAndNotifyIfChanged);
      } else {
        this.saveUserExercises();
        notifyListeners();
      }
    }
    return (_exerciseAdded);
  }

  void deleteUserExercise(String exerciseId, bool upload, {bool saveAndNotifyIfChanged = false}) {
    print("Deleting user-exercise $exerciseId, and upload = $upload");
    // if
    try {
      UserExercise usEx = getUserExercise(exerciseId);
      usEx.notDeleted = false;
      usEx.uploaded = false;
      if (upload && usEx.userExerciseId != "" && usEx.userExerciseId != null) {
        // this is run only if the exercise + userexercise were already uploaded and the user deletes the userexercise
        this.uploadOfflineExercises(saveAndNotifyIfChanged: saveAndNotifyIfChanged);
      } else {
        _userExercises.remove(usEx.localId);
        if (usEx.exercise.exerciseId == "" || usEx.exercise.exerciseId == null) {
          _deleteExercise(usEx.exercise.localId);
        }
        if (saveAndNotifyIfChanged) {
          print("saving from deleteUserexercise");
          this.save();
          notifyListeners();
        }
      }
    } catch (e) {
      print("Couldn't delete UserExercise $exerciseId: $e");
    }
  }

  void updateUserExercise(String id,
      {double points, double maxPointsDay, double maxPointsWeek, double dailyAllowance, double weeklyAllowance, bool isVisible, String note, bool uploaded}) {
    bool somethingChanged = false;
    UserExercise usEx = getUserExercise(id);
    if (points != null && points != usEx.points) {
      somethingChanged = true;
      usEx.points = points;
    }
    if (maxPointsDay != null && maxPointsDay != usEx.maxPointsDay) {
      somethingChanged = true;
      usEx.maxPointsDay = maxPointsDay;
    }
    if (maxPointsWeek != null && maxPointsWeek != usEx.maxPointsWeek) {
      somethingChanged = true;
      usEx.maxPointsWeek = maxPointsWeek;
    }
    if (dailyAllowance != null && dailyAllowance != usEx.dailyAllowance) {
      somethingChanged = true;
      usEx.dailyAllowance = dailyAllowance;
    }
    if (weeklyAllowance != null && points != usEx.weeklyAllowance) {
      somethingChanged = true;
      usEx.weeklyAllowance = weeklyAllowance;
    }
    if (isVisible != null && isVisible != usEx.isVisible) {
      somethingChanged = true;
      usEx.isVisible = isVisible;
    }
    if (note != null && note != usEx.note) {
      somethingChanged = true;
      usEx.note = note;
    }
    if (uploaded != null && uploaded != usEx.uploaded) {
      somethingChanged = true;
      usEx.uploaded = uploaded;
    }
    if (somethingChanged) {
      DateTime latestEdit = DateTime.now();
      usEx.uploaded = false;
      usEx.latestEdit = latestEdit;
      print("updated user-exercise: $latestEdit");
      this.uploadOfflineExercises();
      this.saveUserExercises();
    }
  }

  Map<String, dynamic> exercisesToJson({Map<String, Exercise> exerciseMap}) {
    // contains all workouts by default, if set to false, only the not deleted ones are returned
    Map<String, dynamic> helper = {};
    if (exerciseMap != null) {
      exerciseMap.forEach((key, value) {
        helper.putIfAbsent(key, () => value.toJson());
      });
      return (helper);
    }
    this.commonExercises.forEach((key, value) {
      helper.putIfAbsent(key, () => value.toJson());
    });
    return (helper);
  }

  Map<String, dynamic> userExercisesToJson({bool allUserExercises = true, Map<String, UserExercise> exerciseMap}) {
    // contains all workouts by default, if set to false, only the not deleted ones are returned
    Map<String, dynamic> helper = {};
    if (exerciseMap != null) {
      exerciseMap.forEach((key, value) {
        helper.putIfAbsent(key, () => value.toJson());
      });
      return (helper);
    }
    if (allUserExercises) {
      this.userExercises.forEach((key, value) {
        helper.putIfAbsent(key, () => value.toJson());
      });
    } else {
      // only not deleted
      this.userExercises.forEach((key, value) {
        helper.putIfAbsent(key, () => value.toJson());
      });
    }
    return (helper);
  }

  String exercisesToString({Map<String, Exercise> exerciseMap}) {
    return (json.encode(this.exercisesToJson(exerciseMap: exerciseMap)));
  }

  String userExercisesToString({bool allUserExercises = true, Map<String, UserExercise> exerciseMap}) {
    return (json.encode(this.userExercisesToJson(allUserExercises: allUserExercises, exerciseMap: exerciseMap)));
  }

  void cleanEmptyExercises() {
    print("cleaning the exercises..");
    bool _notify = false;
    List<String> deleteExercises = [];
    List<String> deleteUserExercises = [];
    _userExercises.forEach((key, value) {
      if (value.title == "" || value.title == "New exercise") {
        deleteExercises.add(value.exercise.localId);
        deleteUserExercises.add(value.localId);
      }
    });
    deleteUserExercises.forEach((key) {
      _userExercises.remove(key);
    });
    deleteExercises.forEach((key) {
      _exercises.remove(key);
    });
    _notify = deleteExercises.length > 0 || deleteUserExercises.length > 0;
    if (_notify) {
      save();
    }
    notifyListeners();
  }
}
