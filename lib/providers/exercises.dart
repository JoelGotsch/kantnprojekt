import 'dart:convert';
// import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../misc/exercise.dart';
import '../misc/user_exercise.dart';
import '../misc/functions.dart' as funcs;

class Exercises with ChangeNotifier {
  Map<String, Exercise> _exercises = {};
  Map<String, UserExercise> _userExercises = {};
  // Map<String, ChallengeExercise> _challenge_exercises = {};
  String token;
  final String uri = "http://api.kantnprojekt.club/v0_1/exercises";
  DateTime lastRefresh = DateTime(2020);
  bool loadedOnlineExercises = false; // makes sure that syncronize is only called once
  bool loadingOnlineExercises = false; // prevents that within an update, the sync process is started again.
  // TODO: test if fromPrevious while loading causes problems

  Exercises(this.token, this._exercises, this._userExercises, this.lastRefresh);

  factory Exercises.create() {
    print("Exercises created empty.");
    Exercises exs = Exercises("", {}, {}, DateTime(2020));
    return (exs);
  }

  factory Exercises.fromPrevious(String token, Exercises previousExercises) {
    print("Exercises.fromPrevious is run.");
    previousExercises.token = token;
    if (token != "" && !previousExercises.loadedOnlineExercises && !previousExercises.loadingOnlineExercises) {
      previousExercises.loadingOnlineExercises = true;
      previousExercises.setup();
    }
    return (previousExercises);
  }

  Map<String, UserExercise> get exercises {
    // returns visible UserExercises
    print("getting list of visible exercises");
    Map<String, UserExercise> visibleExercises = {};
    _userExercises.forEach((key, value) {
      if (value.isVisible) {
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

  bool addingFromParsed(Map<String, Exercise> exercisesMap, Map<String, UserExercise> userExercisesMap, {saveAndNotifyIfChanged: true}) {
    // returns true if an exercise or UserExercise was added or updated.
    // if saveAndNotifyIfChanged is true, then new exercises are saved and NotifyListeners is performed here.
    bool _addedExercise = false;
    bool _addedUserExercise = false;
    try {
      exercisesMap.forEach((key, ex) {
        _addedExercise = this.addExercise(ex, saveAndNotifyIfChanged: false) || _addedExercise;
        // print("added exercise from storage: ${ex.exerciseId}");
      });
    } catch (e) {
      print("Couldn't load parsed exercises. " + e.toString());
    }
    try {
      userExercisesMap.forEach((key, usEx) {
        _addedUserExercise = this.addUserExercise(usEx, saveAndNotifyIfChanged: false) || _addedUserExercise;
        // print("added user-exercise from storage: ${usEx.userExerciseId}");
      });
    } catch (e) {
      print("Couldn't load parsed user-exercises. " + e.toString());
    }
    if (saveAndNotifyIfChanged && (_addedExercise || _addedUserExercise)) {
      saveExercises();
      saveUserExercises();
      notifyListeners();
    }
    return (_addedExercise || _addedUserExercise);
  }

  bool addingFromJson(Map<String, dynamic> exercisesMap, Map<String, dynamic> userExercisesMap, {saveAndNotifyIfChanged: true}) {
    // returns true if an exercise or UserExercise was added or updated.
    // if saveAndNotifyIfChanged is true, then new exercises are saved and NotifyListeners is performed here.
    bool _addedExercise = false;
    bool _addedUserExercise = false;
    try {
      exercisesMap.forEach((key, value) {
        Exercise ex = Exercise.fromJson(value);
        _addedExercise = this.addExercise(ex, saveAndNotifyIfChanged: false) || _addedExercise;
        // print("added exercise from storage: ${ex.exerciseId}");
      });
    } catch (e) {
      print("Couldn't load exercises from Json. " + e.toString());
    }
    try {
      userExercisesMap.forEach((key, value) {
        try {
          Exercise ex = this.getExercise(value["exercise_id"]);
          UserExercise usEx = UserExercise.fromJson(value, ex);
          _addedUserExercise = this.addUserExercise(usEx, saveAndNotifyIfChanged: false) || _addedUserExercise;
        } catch (e) {
          print("Couldn't load user-exercise from Json. " + e.toString());
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
    print("Setup completed, now notifying listeners");
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
    List<String> deledtedExIds = [];
    List<String> deledtedUserExIds = [];
    // TODO: backend accepting lists of exercise ids
    try {
      exerciseEditDates = await this.fetchHeaders();
      if (!exerciseEditDates.containsKey("common_exercises")) {
        print("Couldn't syncronize due to no connection to server.");
        return (false);
      }
      exerciseEditDates["common_exercises"].forEach((exId, exLatestEdit) {
        if (_exercises.containsKey(exId)) {
          //maybe an update?
          Exercise ex = _exercises[exId];
          if (ex.latestEdit.compareTo(exLatestEdit) < 0) {
            // exLatestEdit is later => info on server is newer
            serverNewExIds.add(exId);
          } else if (ex.latestEdit.compareTo(exLatestEdit) > 0) {
            if (ex.isUploaded) {
              ex.uploaded = false;
            }
          }
        } else {
          // new exercise
          serverNewExIds.add(exId);
        }
      });
      // now deleting all the exercises which were deleted on the server:
      _exercises.forEach((exId, ex) {
        if (!exerciseEditDates["common_exercises"].containsKey(exId) && ex.isUploaded) {
          deledtedExIds.add(exId); //TODO: What to do with deleted exercises? Delete also associated UserExercises?
        }
      });
      deledtedExIds.forEach((key) {
        _exercises.remove(key);
      });
      exerciseEditDates["user_exercises"].forEach((exId, exLatestEdit) {
        if (_userExercises.containsKey(exId)) {
          UserExercise ex = _userExercises[exId];
          if (ex.latestEdit.compareTo(exLatestEdit) < 0) {
            // exLatestEdit is later => info on server is newer
            serverNewUserExIds.add(exId);
          } else if (ex.latestEdit.compareTo(exLatestEdit) > 0) {
            if (ex.isUploaded) {
              ex.uploaded = false;
            }
          }
        } else {
          serverNewUserExIds.add(exId);
        }
      });
      _userExercises.forEach((exId, ex) {
        if (!exerciseEditDates["user_exercises"].containsKey(exId) && ex.isUploaded) {
          deledtedUserExIds.add(exId); //TODO: What to do with deleted exercises? Delete also associated UserExercises?
        }
      });
      deledtedUserExIds.forEach((key) {
        _userExercises.remove(key);
      });

      Map<String, Map<String, dynamic>> newExercises = await this._fetch(userExerciseIds: serverNewUserExIds, exerciseIds: serverNewExIds);
      addedExercise = addingFromParsed(newExercises["common_exercises"], newExercises["user_exercises"], saveAndNotifyIfChanged: false);
      loadedOnlineExercises = true;
      lastRefresh = DateTime.now();
      // print(exerciseEditDates);
      // check which editDates dont match with saved ones and get newer ones from server and post (send) if newer from app.
    } catch (Exception) {
      print("Error in syncronize Exercises: $Exception");
    }
    // this.fetchNew();
    if (saveAndNotifyIfChanged) {
      notifyListeners();
      if (_saving) {
        await this.save();
      }
    }

    addedExercise = await _uploadOfflineExercises() || addedExercise;
    loadingOnlineExercises = false;
    return (addedExercise);
  }

  Future<void> saveExercises() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("Exercises", this.exercisesToString());
  }

  Future<void> saveUserExercises() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("UserExercises", this.userExercisesToString(allUserExercises: true));
  }

  Future<void> save() async {
    await this.saveExercises();
    await this.saveUserExercises();
  }

  Future<Map<String, Map<String, dynamic>>> _fetch(
      {String exerciseId, int number = 0, DateTime minEditDate, List<String> userExerciseIds, List<String> exerciseIds}) async {
// helper function to get data via API
    Map<String, Exercise> newExercises = {};
    Map<String, UserExercise> newUserExercises = {};
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
    Uri url = Uri.http(
      "api.kantnprojekt.club",
      "/v0_1/exercises",
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

    if (response.statusCode == 201 || response.statusCode == 200) {
      print("adding common exercises");
      // print(result["common_exercises"]);
      for (Map json_ in (result["common_exercises"] as Map<String, dynamic>).values.toList()) {
        // for (Map json_ in result.values) {
        try {
          newExercises.putIfAbsent(json_["id"], () => Exercise.fromJson(json_));
        } catch (Exception) {
          print(Exception);
        }
      }
      print("adding user exercises");
      // print(result["user_exercises"]);
      for (Map json_ in (result["user_exercises"] as Map<String, dynamic>).values.toList()) {
        // for (Map json_ in result.values) {
        try {
          Exercise ex;
          String exId = json_["exercise_id"];
          if (newExercises.containsKey(exId)) {
            ex = newExercises[exId];
          } else if (_exercises.containsKey(exId)) {
            ex = _exercises[exId];
          } else {
            throw (Exception("Couldn't find exercise id $exId"));
          }

          newUserExercises.putIfAbsent(json_["id"], () => UserExercise.fromJson(json_, ex));
        } catch (Exception) {
          print(Exception);
        }
      }
    } else {
      // If that call was not successful, throw an error.
      throw Exception('Failed to load Exercises: ');
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
    Uri url = Uri.http(
      "api.kantnprojekt.club",
      "/v0_1/exercises",
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
        result["common_exercises"].forEach((key, value) {
          commonExercises.putIfAbsent(key, () => DateTime.parse(value));
        });
        result["user_exercises"].forEach((key, value) {
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
      print("Problem while fetching last edit dates of exerises: Status Code ${response.statusCode}, " + e.toString());
    }
    return (returnMap);
  }

  Future<void> fetchNew() async {
    this.setLastRefresh();
    print("fetching new exercises since $lastRefresh");
    Map<String, Map<String, dynamic>> newExercises = await this._fetch(minEditDate: lastRefresh);
    addingFromParsed(newExercises["common_exercises"], newExercises["user_exercises"], saveAndNotifyIfChanged: true);
    print("fetched new exercises");
    lastRefresh = DateTime.now();
  }

  Exercise getExercise(String exerciseId) {
    Exercise ex;
    if (_exercises.containsKey(exerciseId)) {
      ex = _exercises[exerciseId];
    } else {
      //TODO: download exercise; shouldn't happen so far anyways as in this case the exercise is sent as part of the workout!
      throw Exception("Tried to access exerciseID " + exerciseId.toString() + " which is not known. Maybe forgot to initialize the exercise object?");
    }
    return (ex);
  }

  UserExercise getUserExercise(String exerciseId) {
    UserExercise ex;
    if (_userExercises.containsKey(exerciseId)) {
      ex = _userExercises[exerciseId];
    } else if (_exercises.containsKey(exerciseId)) {
      _userExercises.forEach((key, usEx) {
        if (usEx.exercise.localId == exerciseId) {
          ex = usEx;
        }
      });
    } else {
      _userExercises.forEach((key, usEx) {
        if (usEx.localId == exerciseId) {
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

  Future<bool> _uploadOfflineExercises({bool saveAndNotifyIfChanged = false}) async {
    // returns true if at least one exercise was uploaded.
    // tries to upload all not uploaded workouts and updates the Ids, then saves to shared_preferences
    Map<String, UserExercise> offlineUserExercises = {};
    bool _uploaded = false;
    http.Response response;
    _userExercises.forEach((key, value) {
      if (!value.isUploaded) {
        offlineUserExercises.putIfAbsent(key, () => value);
        print("UserExercise $key is not uploaded yet. Will be synced now.");
      }
    });
    if (offlineUserExercises.length == 0) {
      print("There are no offline exercises");
      return (false);
    }
    String helper = this.userExercisesToString(exerciseMap: offlineUserExercises);
    try {
      response = await http.post(uri,
          headers: {
            "token": token,
            // "user_id": _userId,
          },
          body: helper);
      final result = json.decode(response.body) as Map<String, Map<String, String>>; //localId:workoutId
      print(response.statusCode);
      if (response.statusCode == 201 || response.statusCode == 200) {
        result["user_exercises"].forEach((_localId, _userExerciseId) {
          _uploaded = true;
          UserExercise usEx = _userExercises[_localId];
          usEx.userExerciseId = _userExerciseId;
          usEx.localId = _userExerciseId;
          usEx.uploaded = true;
          if (_localId != _userExerciseId) {
            _userExercises.removeWhere((key, value) => key == _localId);
            _userExercises[_userExerciseId] = usEx;
          }
          if (result["common_exercises"][_localId] != null) {
            Exercise ex = usEx.exercise;
            if (ex.exerciseId != result["common_exercises"][_localId]) {
              String oldLocalId = ex.localId;
              ex.exerciseId = result["common_exercises"][_localId];
              ex.localId = result["common_exercises"][_localId];
              _exercises.removeWhere((key, value) => key == oldLocalId);
              _exercises[ex.exerciseId] = ex;
            }
          }
        });
      } else {
        print("Couldn't get response from server while trying to upload offline exercises.");
      }
    } catch (e) {
      print("Couldn't upload offline exercises: $e");
      // print(response.body);
    }
    if (_uploaded && saveAndNotifyIfChanged) {
      this.save();
      notifyListeners();
    }
    return (_uploaded);
  }

  bool addExercise(Exercise ex, {bool saveAndNotifyIfChanged = false}) {
    // returns true if an exercise was added or changed.
    // if an exercise with the same id is found, then it is just updated.
    // Only the note of the exercise can change! Otherwise it is needed to create a new Exercise.
    bool _exerciseAdded = false;
    if (_exercises.containsKey(ex.localId) || _exercises.containsKey(ex.exerciseId)) {
      // update existing workout
      Exercise oldEx;
      if (_exercises.containsKey(ex.localId)) {
        oldEx = _exercises[ex.localId];
      } else {
        oldEx = _exercises[ex.exerciseId];
      }
      if (oldEx.note != ex.note) {
        print("updating exercise ${ex.localId}");
        oldEx.note = ex.note;
        oldEx.latestEdit = ex.latestEdit;
        _exerciseAdded = true;
      } else {
        print("Tried to add existing Exercise with the same note.");
      }
    } else {
      _exercises.putIfAbsent(ex.localId, () => ex);
      print("added exercise ${ex.localId}");
      _exerciseAdded = true;
    }
    if (saveAndNotifyIfChanged && _exerciseAdded) {
      if (!ex.isUploaded) {
        this._uploadOfflineExercises();
      }
      this.saveExercises();
      notifyListeners();
    }
    return (_exerciseAdded);
  }

  bool addUserExercise(UserExercise usEx, {bool saveAndNotifyIfChanged = false}) {
    // returns true if an Exercise was added or changed.
    // if an exercise with the same id is found, then it is just updated.
    // Only the note of the exercise can change! Otherwise it is needed to create a new Exercise.
    bool _exerciseAdded = false;
    if (_userExercises.containsKey(usEx.localId) || _userExercises.containsKey(usEx.userExerciseId)) {
      // update existing workout
      UserExercise oldEx;
      if (_userExercises.containsKey(usEx.localId)) {
        oldEx = _userExercises[usEx.localId];
      } else {
        oldEx = _userExercises[usEx.userExerciseId];
      }
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
      _userExercises[usEx.localId] = usEx;
      _exerciseAdded = true;
      if (saveAndNotifyIfChanged) {
        notifyListeners();
      }
    }
    if (saveAndNotifyIfChanged) {
      if (!usEx.isUploaded) {
        this._uploadOfflineExercises();
      }
      this.saveUserExercises();
    }
    return (_exerciseAdded);
  }

  void updateUserExercise(String id,
      {double points,
      double maxPointsDay,
      double maxPointsWeek,
      double dailyAllowance,
      double weeklyAllowance,
      DateTime latestEdit,
      bool isVisible,
      String note,
      bool uploaded}) {
    bool somethingChanged = false;
    UserExercise usEx = _userExercises[id];
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
    if (uploaded != null && uploaded != usEx.isUploaded) {
      somethingChanged = true;
      usEx.note = note;
    }
    if (latestEdit == null && somethingChanged) {
      latestEdit = DateTime.now();
      usEx.latestEdit = latestEdit;
      print("Test - latest edit date was null. good.");
      this._uploadOfflineExercises();
      this.saveUserExercises();
    } else if (latestEdit != null) {
      usEx.latestEdit = latestEdit;
      this._uploadOfflineExercises();
      this.saveUserExercises();
      print("Problem - not null at beginning.");
    }
  }

  // void deleteExercise(String id) {
  //   Exercise ex = _exercises[id];
  //   ex.notDeleted = false;
  //   ex.uploaded = false;
  //   // _exercises.removeWhere(
  //   //     (key, value) => value.exerciseId == id || value.localId == id);
  //   notifyListeners();
  //   this._uploadOfflineExercises();
  // }
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
      notifyListeners();
    }
  }
}
