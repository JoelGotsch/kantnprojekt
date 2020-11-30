// import 'dart:ffi';
import 'dart:convert';
// import 'dart:math';
// import 'dart:html';
// import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:collection'; // for linked hashmaps

import '../misc/functions.dart' as funcs;
import 'exercises.dart';
import 'workout.dart';

class Workouts with ChangeNotifier {
  // manages all the workout- objects: making sure they are uploaded/
  Map<String, Workout> _workouts = {};
  // Map<String, Exercise> _exercises = {};
  Exercises exercises;
  String _token;
  DateTime lastRefresh = DateTime(2020);
  bool loadedOnlineWorkouts = false; // makes sure that syncronize is only called once
  bool loadingOnlineWorkouts = false; // prevents that within an update, the sync process is started again.
  final String uri = "http://api.kantnprojekt.club/v0_1/workouts";

  Workouts(this._token, this._workouts, this.exercises, this.lastRefresh);

  factory Workouts.create() {
    print("Workouts created empty.");
    Workouts wos = Workouts("", {}, Exercises.create(), DateTime(2020));
    return (wos);
  }

  factory Workouts.fromPrevious(Exercises exs, Workouts previousWorkouts) {
    print("Workouts.fromPrevious is run.");
    previousWorkouts._token = exs.token;
    if (previousWorkouts._token != "" && !previousWorkouts.loadedOnlineWorkouts && !previousWorkouts.loadingOnlineWorkouts) {
      previousWorkouts.loadingOnlineWorkouts = true;
      previousWorkouts.setup();
    }
    return (previousWorkouts);
  }

  void setup() async {
    bool addedExercise = await addingFromStorage(saveAndNotifyIfChanged: false);
    addedExercise = await syncronize(saveAndNotifyIfChanged: false) || addedExercise;
    print("Setup completed, now notifying listeners");
    if (addedExercise) {
      print("saving from setup");
      this.save();
      notifyListeners();
    }
  }

  Future<bool> addingFromStorage({bool saveAndNotifyIfChanged = false}) async {
    bool addedExercise = false;
    print("adding from storage");
    try {
      final prefs = await SharedPreferences.getInstance();
      String woString = prefs.getString("Workouts");
      print(woString);
      Map<String, dynamic> _json = json.decode(woString);
      addedExercise = this.addingFromJson(_json, saveAndNotifyIfChanged: false);
      if (saveAndNotifyIfChanged && addedExercise) {
        // print("saving from add from storage");
        // this.save();
        notifyListeners();
      }
      return (addedExercise);
    } catch (Exception) {
      print("Error: Couldn't load exercises/ userExercises from storage, probably never saved them. " + Exception.toString());
    }
    return (false);
  }

  bool addingFromJson(Map<String, dynamic> workoutsMap, {saveAndNotifyIfChanged: true}) {
    // returns true if a workout was added or updated.
    // if saveAndNotifyIfChanged is true, then new workouts are saved and NotifyListeners is performed here.
    bool _addedWorkout = false;
    print("adding from json");
    try {
      workoutsMap.forEach((key, value) {
        // print("adding from json: try to create workout from $value");
        Workout wo = Workout.fromJson(value);
        _addedWorkout = this.addWorkout(wo, saveAndNotifyIfChanged: false) || _addedWorkout;
        // print("added exercise from storage: ${ex.exerciseId}");
      });
    } catch (e) {
      print("Couldn't load workouts from Json. " + e.toString());
    }
    if (saveAndNotifyIfChanged && _addedWorkout) {
      save();
      notifyListeners();
    }
    return (_addedWorkout);
  }

  bool addingFromParsed(Map<String, Workout> workoutsMap, {saveAndNotifyIfChanged: true}) {
    // returns true if a workout was added or updated.
    // if saveAndNotifyIfChanged is true, then new workouts are saved and NotifyListeners is performed here.
    bool _addedWorkout = false;
    try {
      workoutsMap.forEach((key, wo) {
        _addedWorkout = this.addWorkout(wo, saveAndNotifyIfChanged: false) || _addedWorkout;
        // print("added exercise from storage: ${ex.exerciseId}");
      });
    } catch (e) {
      print("Couldn't load parsed workouts. " + e.toString());
    }
    if (saveAndNotifyIfChanged && _addedWorkout) {
      save();
      notifyListeners();
    }
    return (_addedWorkout);
  }

  void setLastRefresh() {
    List<DateTime> workoutEditTimes = [lastRefresh];
    _workouts.forEach((key, value) => workoutEditTimes.add(value.latestEdit));
    lastRefresh = funcs.calcMaxDate(workoutEditTimes);
  }

  Future<bool> syncronize({bool saveAndNotifyIfChanged = true}) async {
    bool addedWorkout = false;
    bool _saving = false;
    // loads workouts from sharedPreferences (i.e. Phone storage)
    print("workouts syncronize is running..");
    // now fetching the whole list of workouts with newest dates to compare to the one on the phone:
    Map<String, DateTime> workoutEditDates = {};
    List<String> serverNewWoIds = [];
    List<String> deledtedWoIds = [];
    try {
      workoutEditDates = await this.fetchHeaders();
      workoutEditDates.forEach((id, woLatestEdit) {
        if (_workouts.containsKey(id)) {
          Workout wo = _workouts[id];
          if (wo.latestEdit.compareTo(woLatestEdit) < 0) {
            // exLatestEdit is later => info on server is newer
            print("Found newer version of workout $id on server: server: ${woLatestEdit.toIso8601String()} vs local ${wo.latestEdit.toIso8601String()}");
            serverNewWoIds.add(id);
          } else if (wo.latestEdit.compareTo(woLatestEdit) > 0) {
            if (wo.isUploaded) {
              wo.isUploaded = false;
              print("Found newer version of workout $id on phone: server: ${woLatestEdit.toIso8601String()} vs local ${wo.latestEdit.toIso8601String()}");
            }
          }
        } else {
          serverNewWoIds.add(id);
        }
      });
      _workouts.forEach((woId, wo) {
        if (!workoutEditDates.containsKey(woId) && wo.isUploaded) {
          deledtedWoIds.add(woId);
        }
      });
      deledtedWoIds.forEach((key) {
        _workouts.remove(key);
      });

      Map<String, dynamic> newWorkouts = await this._fetch(workoutIds: serverNewWoIds);
      addedWorkout = addingFromParsed(newWorkouts, saveAndNotifyIfChanged: false);
      loadedOnlineWorkouts = true;
      lastRefresh = DateTime.now();
      // print(exerciseEditDates);
      // check which editDates dont match with saved ones and get newer ones from server and post (send) if newer from app.
    } catch (Exception) {
      print("Error in syncronize Exercises: $Exception");
    }
    // this.fetchNew();
    addedWorkout = await _uploadOfflineWorkouts(saveAndNotifyIfChanged: false) || addedWorkout;
    if (saveAndNotifyIfChanged) {
      notifyListeners();
      if (_saving) {
        print("saving from syncronize");
        await this.save();
      }
    }
    loadingOnlineWorkouts = false;
    return (addedWorkout);
  }

  Map<String, Workout> get workouts {
    Map<String, Workout> notDeletedWorkouts = {};
    _workouts.forEach((key, value) {
      if (value.isNotDeleted) {
        notDeletedWorkouts.putIfAbsent(key, () => value);
      }
    });
    // now sorting them: newest date first:
    return (notDeletedWorkouts);
  }

  List<Workout> get sortedWorkouts {
    Map<String, Workout> notDeletedWorkouts = this.workouts;
    List mapKeys = notDeletedWorkouts.keys.toList(growable: false);
    mapKeys.sort((k1, k2) => notDeletedWorkouts[k1].date.compareTo(notDeletedWorkouts[k2].date));
    List<Workout> returnList = [];
    mapKeys.forEach((k1) {
      returnList.insert(0, notDeletedWorkouts[k1]);
    });
    return (returnList);
  }

  Workout byId(String workoutId) {
    Workout returnWo;
    if (_workouts.containsKey(workoutId)) {
      returnWo = _workouts[workoutId];
    } else {
      _workouts.forEach((key, wo) {
        if (wo.workoutId == workoutId || wo.localId == workoutId) {
          returnWo = wo;
        }
      });
    }
    if (returnWo != null) {
      return (returnWo);
    } else {
      throw (Exception("Couldn't find workout with id: " + workoutId));
    }
  }

  Workout byActionId(String actionId) {
    Workout returnWo;
    _workouts.forEach((key, wo) {
      if (wo.actions.containsKey(actionId)) {
        returnWo = wo;
      }
    });
    if (returnWo != null) {
      return (returnWo);
    } else {
      throw (Exception("Couldn't find workout with action id: " + actionId));
    }
  }

  Map<String, Workout> get allWorkouts {
    return (_workouts);
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    print("saving ${_workouts.length} workouts..");
    String output = this.toString();
    print(output);
    prefs.setString('Workouts', output);
  }

  Future<Map<String, Workout>> _fetch(
      {String workoutId, List<String> workoutIds, DateTime minEditDate, DateTime startDate, DateTime endDate, int number = 0}) async {
    // deletes all locally stored exercises and loads the complete list from online database and stores values in sharedPreferences
    Map<String, Workout> newWorkouts = {};
    Map<String, String> queryParameters = {};
    print("start fetching workouts..");
    if (workoutId != null) {
      queryParameters["workout_id"] = workoutId;
    }
    if (workoutIds != null) {
      queryParameters["workout_ids"] = workoutIds.join(",");
    }
    if (minEditDate != null) {
      queryParameters["latest_edit_date"] = minEditDate.toIso8601String();
    }
    if (startDate != null) {
      queryParameters["start_date"] = startDate.toIso8601String();
    }
    if (endDate != null) {
      queryParameters["end_date"] = endDate.toIso8601String();
    }
    queryParameters["number"] = number.toString();
    Uri url = Uri.http(
      "api.kantnprojekt.club",
      "/v0_1/workouts",
      queryParameters,
    );
    final response = await http.get(
      url,
      headers: {
        "token": _token,
        // "user_id": _userId,
      },
    );
    final Map result = json.decode(response.body);
    // print("Response in fetch: $result");

    if (response.statusCode == 201 || response.statusCode == 200) {
      // for (Map json_ in result["data"]) {
      for (Map json_ in result.values) {
        try {
          print("Trying to create workout:");
          Workout wo = Workout.fromJson(json_);
          if (json_["id"] != null) {
            newWorkouts.putIfAbsent(json_["id"], () => wo);
            print("fetched workout.. " + wo.workoutId);
          }
        } catch (e) {
          print("Error while trying to create workout in fetch: $e");
        }
      }
    } else {
      // If that call was not successful, throw an error.
      throw Exception('Failed to load Workout: ' + result["message"].toString());
    }
    return (newWorkouts);
  }

  // Future<void> fetchWorkout(String workoutId, {bool save = false}) async {
  //   print("Fetching workout $workoutId");
  //   if (workoutId == null) {
  //     throw (Exception("wanted to fetch workout null."));
  //   } else {
  //     Map<String, Workout> oneWorkout = await this._fetch(workoutId: workoutId);
  //     if (oneWorkout != null && oneWorkout.length > 0) {
  //       _workouts[workoutId] = oneWorkout[workoutId];
  //       notifyListeners();
  //       if (save) {
  //         this.pruneWorkoutList();
  //         this.save();
  //       }
  //     }
  //   }
  // }

  Future<void> fetchNew() async {
    this.setLastRefresh();
    print("fetching new workouts since $lastRefresh");
    Map<String, dynamic> newWorkouts = await this._fetch(minEditDate: lastRefresh);
    addingFromParsed(newWorkouts, saveAndNotifyIfChanged: true);
    print("fetched new workouts");
    lastRefresh = DateTime.now();
  }

  void pruneWorkoutList() {
    // deletes all deleted, and uploaded workouts. Actually only necessary if something went wrong..
    List<String> deleteKeys = [];
    if (_workouts.length > 0) {
      _workouts.forEach((key, value) {
        if (value.isUploaded && !value.isNotDeleted) {
          print("Workout $key was pruned. Something happened.");
          deleteKeys.add(key);
        }
      });
      deleteKeys.forEach((element) {
        _workouts.remove(element);
      });
    }
  }

  Future<Map<String, DateTime>> fetchHeaders() async {
    Map<String, DateTime> allWorkouts = {};
    Map<String, String> queryParameters = {};
    print("start fetching workout headers ..");
    queryParameters["latest_edit_date_only"] = true.toString();
    Uri url = Uri.http(
      "api.kantnprojekt.club",
      "/v0_1/workouts",
      queryParameters,
    );
    final response = await http.get(
      url,
      headers: {
        "token": _token,
        // "user_id": _userId,
      },
    );
    final Map result = json.decode(response.body);
    print("result in fetching workout headers: $result");

    if (response.statusCode == 201 || response.statusCode == 200) {
      // for (Map json_ in result["data"]) {
      result.forEach((key, value) {
        try {
          allWorkouts.putIfAbsent(key, () => DateTime.parse(value));
        } catch (Exception) {
          print(Exception);
        }
      });
    } else {
      // If that call was not successful, throw an error.
      throw Exception('Failed to load Workout ' + result["message"]);
    }
    return (allWorkouts);
  }

  Map<String, dynamic> toJson({bool allWorkouts = true, Map<String, Workout> workoutsMap}) {
    // contains all workouts by default, if set to false, only the not deleted ones are returned
    Map<String, dynamic> helper = {};
    if (workoutsMap != null) {
      workoutsMap.forEach((key, value) {
        helper.putIfAbsent(key, () => value.toJson());
      });
      return (helper);
    }
    if (allWorkouts) {
      this.allWorkouts.forEach((key, value) {
        helper.putIfAbsent(key, () => value.toJson());
      });
    } else {
      // only not deleted
      this.workouts.forEach((key, value) {
        helper.putIfAbsent(key, () => value.toJson());
      });
    }
    return (helper);
  }

  @override
  String toString() {
    // returns a list with names consistent with database (e.g. id instead of workoutId)
    // includes deleted workouts!
    return (json.encode(this.toJson()));
  }

  // void fromString(String str) {
  //   Map<String, dynamic> parsedJson = json.decode(str);
  //   this.fromJson(parsedJson);
  // }

  // void fromJson(Map<String, dynamic> parsedJson) {
  //   parsedJson.forEach((key, value) {
  //     this.addWorkout(Workout.fromJson(value));
  //   });
  // }

  bool addWorkout(Workout wo, {bool saveAndNotifyIfChanged = true}) {
    // returns true if a workout was added or changed.
    bool _addedWorkout = false;
    if (_workouts.containsKey(wo.localId) || _workouts.containsKey(wo.workoutId)) {
      // update existing workout
      Workout oldWo;
      if (_workouts.containsKey(wo.localId)) {
        oldWo = _workouts[wo.localId];
      } else {
        oldWo = _workouts[wo.workoutId];
      }
      if (!oldWo.equals(wo)) {
        oldWo.actions = wo.actions;
        oldWo.date = wo.date;
        oldWo.latestEdit = DateTime.now();
        oldWo.note = wo.note;
        oldWo.isUploaded = wo.isUploaded;
        _addedWorkout = true;
      }
    } else {
      // a new workout!
      if (wo.localId == null) {
        throw (Exception("localId of workout is null."));
      }
      print("added new workout ${wo.localId}");
      _workouts[wo.localId] = wo;
      _addedWorkout = true;
    }

    if (saveAndNotifyIfChanged && _addedWorkout) {
      if (!wo.isUploaded) {
        print("_uploadOfflineWorkouts from add workout 1");
        this._uploadOfflineWorkouts(saveAndNotifyIfChanged: true);
      } else {
        print("saving from add_workout");
        this.save();
        notifyListeners();
      }
    }
    return (_addedWorkout);
  }

  void deleteWorkout(String workoutId, {bool saveAndNotifyIfChanged = true}) async {
    Workout wo = _workouts[workoutId];
    wo.isNotDeleted = false;
    wo.isUploaded = false;
    // _workouts.removeWhere((key, value) => false);
    if (saveAndNotifyIfChanged) {
      print("_uploadOfflineWorkouts from adding action.");
      await this._uploadOfflineWorkouts(saveAndNotifyIfChanged: false);
      print("saving from delete workout");
      this.save();
      notifyListeners();
    }
  }

  void addAction(Action ac, {bool saveAndNotifyIfChanged = true}) async {
    print("adding action..");
    Workout wo = _workouts[ac.workoutId];
    wo.addAction(ac);
    if (saveAndNotifyIfChanged) {
      print("_uploadOfflineWorkouts from adding action.");
      await this._uploadOfflineWorkouts(saveAndNotifyIfChanged: false);
      print("saving from add action");
      this.save();
      notifyListeners();
    }
  }

  void deleteAction(Action ac, {bool saveAndNotifyIfChanged = true}) async {
    Workout wo = byActionId(ac.actionId);
    // Workout wo = _workouts[ac.workoutId];
    wo.deleteAction(ac.actionId);
    if (saveAndNotifyIfChanged) {
      print("_uploadOfflineWorkouts from adding action.");
      await this._uploadOfflineWorkouts(saveAndNotifyIfChanged: false);
      print("saving from delete action");
      this.save();
      notifyListeners();
    }
  }

  Future<bool> _uploadOfflineWorkouts({bool saveAndNotifyIfChanged = true}) async {
    // returns true if at least one workout was uploaded
    // tries to upload all not uploaded workouts and updates the Ids, then saves to shared_preferences
    // if saveAndNotifyIfChanged,  the current state is saved on phone.
    Map<String, Workout> offlineWorkouts = {};
    bool _uploaded = false;
    print("start syncronizing workouts.");
    _workouts.forEach((key, wo) {
      if (!wo.isUploaded) {
        offlineWorkouts.putIfAbsent(key, () => wo);
        print("Workout $key is not uploaded yet. Will be synced now.");
      }
    });
    if (offlineWorkouts == null || offlineWorkouts.length == 0) {
      // print("offlineworkouts are null or 0");
      return (_uploaded);
    }
    Uri url = Uri.http(
      "api.kantnprojekt.club",
      "/v0_1/workouts",
    );
    try {
      final response = await http.post(url,
          headers: {
            "token": _token,
            'Content-Type': 'application/json; charset=UTF-8',
            // "user_id": _userId,
          },
          body: jsonEncode(this.toJson(workoutsMap: offlineWorkouts)));
      final result2 = json.decode(response.body) as Map<String, dynamic>; //localId:workoutId
      Map<String, dynamic> result = result2["data"];
      if (response.statusCode == 201) {
        result.forEach((_localId, _workoutId2) {
          String _workoutId = _workoutId2.toString();
          print("local id: $_localId workoutId: $_workoutId");
          // if (_workoutId == "") {
          //   // thats the response if workout was deleted on server
          //   print("removed workout $_localId");
          //   _workouts.remove(_localId.toString());
          // } else
          if (_workoutId != null) {
            Workout wo = _workouts[_localId.toString()];
            if (wo == null) {
              print("Something happened. WO is null! Inspect!");
              print(this.toString());
            }
            wo.workoutId = _workoutId.toString();
            wo.localId = _workoutId.toString();
            wo.isUploaded = true;
            _uploaded = true;
            wo.actions.forEach((key, ac) {
              ac.workoutId = _workoutId;
            });
            if (_workoutId != _localId) {
              _workouts.removeWhere((key, value) => key == _localId.toString());
              _workouts[_workoutId] = wo;
            }
          }
        });
      } else {
        print("Couldn't sync workouts. " + result2["message"].toString());
      }
    } catch (e) {
      print("Error while syncing workouts: " + e.toString());
    }
    if (saveAndNotifyIfChanged) {
      print("saving from offline uploads");
      this.save();
      notifyListeners();
    }
    return (_uploaded);
  }
}
