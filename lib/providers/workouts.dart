// import 'dart:ffi';
import 'dart:convert';
// import 'dart:math';
// import 'dart:html';
// import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:collection'; // for linked hashmaps

import '../misc/global_data.dart';
import '../misc/functions.dart' as funcs;
import '../misc/exercise.dart';
import 'exercises.dart';
import 'workout.dart';

class Workouts with ChangeNotifier {
  // manages all the workout- objects: making sure they are uploaded/
  Map<String, Workout> _workouts = {};
  // Map<String, Exercise> _exercises = {};
  Exercises exercises;
  String _token;
  String userId;
  DateTime lastRefresh = DateTime(2020);
  bool loadedOnlineWorkouts = false; // makes sure that syncronize is only called once
  bool loadingOnlineWorkouts = false; // prevents that within an update, the sync process is started again.

  Workouts(this._token, this._workouts, this.exercises, this.lastRefresh, this.userId);

  factory Workouts.create() {
    print("Workouts created empty.");
    Workouts wos = Workouts("", {}, Exercises.create(), DateTime(2020), "");
    return (wos);
  }

  factory Workouts.fromPrevious(Exercises exs, Workouts previousWorkouts) {
    print("Workouts.fromPrevious is run.");
    if (exs.token == "" || exs.token == null) {
      // on logout, token is set to null
      previousWorkouts = Workouts.create();
      return (previousWorkouts);
    }
    previousWorkouts._token = exs.token;
    previousWorkouts.userId = exs.userId;
    print(
        "workouts from previous ${exs.token}, ${!previousWorkouts.loadedOnlineWorkouts}, ${!previousWorkouts.loadingOnlineWorkouts}, ${exs.loadedOnlineExercises}");
    if (exs.token != "" && !previousWorkouts.loadedOnlineWorkouts && !previousWorkouts.loadingOnlineWorkouts && exs.loadedOnlineExercises) {
      previousWorkouts.loadingOnlineWorkouts = true;
      previousWorkouts.setup();
    }
    return (previousWorkouts);
  }

  void updateActionExerciseIds(Exercises exs) {
    _workouts.forEach((localId, wo) {
      wo.actions.forEach((key, action) {
        if (action.exerciseId == null || action.exerciseId == "") {
          // was the exercise now uploaded?
          try {
            Exercise ex = exs.getExercise(action.localExerciseId);
            if (ex.exerciseId != null && ex.exerciseId != "") {
              action.exerciseId = ex.exerciseId;
            } else {
              print("Still waiting for upload of exercise ${action.localExerciseId}");
            }
          } catch (e) {
            print("Still waiting for upload of exercise ${action.localExerciseId}");
          }
        }
      });
    });
  }

  void setup() async {
    print("running workouts setup..");
    bool addedWorkout = await addingFromStorage(saveAndNotifyIfChanged: false);
    // print("after added workouts from storage: $this");
    addedWorkout = await syncronize(saveAndNotifyIfChanged: false) || addedWorkout;
    // print("after added workouts from syncronizing: $this");
    print("Workouts setup completed, now notifying listeners");
    if (addedWorkout) {
      print("saving from setup");
      this.save();
    }
    notifyListeners();
  }

  Future<bool> addingFromStorage({bool saveAndNotifyIfChanged = false}) async {
    bool addedExercise = false;
    print("adding workouts from storage");
    try {
      final prefs = await SharedPreferences.getInstance();
      String woString = prefs.getString("Workouts" + userId);
      // print(woString);
      Map<String, dynamic> _json = json.decode(woString);
      addedExercise = this.addingFromJson(_json, saveAndNotifyIfChanged: false);
      if (saveAndNotifyIfChanged && addedExercise) {
        // print("saving from add from storage");
        // this.save();
        notifyListeners();
      }
      return (addedExercise);
    } catch (e) {
      print("Error: Couldn't load workouts from storage, probably never saved them. " + e.toString());
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
        if (hasWorkout(id)) {
          Workout wo = getWorkout(id);
          if (wo.latestEdit.compareTo(woLatestEdit) < 0) {
            // exLatestEdit is later => info on server is newer
            print("Found newer version of workout $id on server: server: ${woLatestEdit.toIso8601String()} vs local ${wo.latestEdit.toIso8601String()}");
            serverNewWoIds.add(id);
          } else if (wo.latestEdit.compareTo(woLatestEdit) > 0) {
            print("Found newer version of workout $id on phone: server: ${woLatestEdit.toIso8601String()} vs local ${wo.latestEdit.toIso8601String()}");
            if (wo.uploaded) {
              print("ERROR: workout should be newer on the phone, but it is already uploaded???");
              wo.uploaded = false;
            }
          }
        } else {
          serverNewWoIds.add(id);
        }
      });
      _workouts.forEach((woId, wo) {
        if (!workoutEditDates.containsKey(woId) && wo.uploaded) {
          deledtedWoIds.add(woId);
        }
      });
      deledtedWoIds.forEach((key) {
        _workouts.remove(key);
      });

      Map<String, dynamic> newWorkouts = await this._fetch(workoutIds: serverNewWoIds);
      addedWorkout = addingFromJson(newWorkouts, saveAndNotifyIfChanged: false);
      loadedOnlineWorkouts = true;
      lastRefresh = DateTime.now();
      // print(exerciseEditDates);
      // check which editDates dont match with saved ones and get newer ones from server and post (send) if newer from app.
    } catch (e) {
      print("Error in syncronize Workouts: $e");
    }
    // this.fetchNew();
    addedWorkout = await uploadOfflineWorkouts(saveAndNotifyIfChanged: false) || addedWorkout;
    if (saveAndNotifyIfChanged && addedWorkout) {
      notifyListeners();
      if (_saving) {
        print("saving workouts from syncronize");
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
    prefs.setString('Workouts' + userId, output);
  }

  Future<Map<String, dynamic>> _fetch(
      {String workoutId, List<String> workoutIds, DateTime minEditDate, DateTime startDate, DateTime endDate, int number = 0}) async {
    Map<String, dynamic> newWorkouts = {};
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
    queryParameters["user_id"] = userId.toString();
    Uri url = Uri.http(
      GlobalData.api_url,
      "workouts",
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
      newWorkouts = result["data"];
    } else {
      // If that call was not successful, throw an error.
      throw Exception('Failed to load Workout: ' + result["message"].toString());
    }
    return (newWorkouts);
  }

  Future<void> fetchNew() async {
    this.setLastRefresh();
    print("fetching new workouts since $lastRefresh");
    try {
      Map<String, dynamic> newWorkouts = await this._fetch(minEditDate: lastRefresh);
      addingFromJson(newWorkouts, saveAndNotifyIfChanged: true);
      print("fetched new workouts");
    } catch (e) {
      print("Couldn't fetch new workouts: $e");
    }

    lastRefresh = DateTime.now();
  }

  void pruneWorkoutList() {
    // deletes all deleted, and uploaded workouts. Actually only necessary if something went wrong..
    List<String> deleteKeys = [];
    if (_workouts.length > 0) {
      _workouts.forEach((key, value) {
        if (value.uploaded && !value.isNotDeleted) {
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
      GlobalData.api_url,
      "workouts",
      queryParameters,
    );
    final response = await http.get(
      url,
      headers: {
        "token": _token,
        // "user_id": _userId,
      },
    );
    try {
      final Map result = json.decode(response.body)["data"];
      // print("result in fetching workout headers: $result");

      if (response.statusCode == 201 || response.statusCode == 200) {
        // for (Map json_ in result["data"]) {
        result.forEach((key, value) {
          try {
            allWorkouts.putIfAbsent(key, () => DateTime.parse(value));
          } catch (Exception) {
            print(Exception);
          }
        });
        return (allWorkouts);
      } else {
        // If that call was not successful, throw an error.
        throw Exception('Failed to load Workout ' + result["message"]);
      }
    } catch (e) {
      throw ("Problem while fetching last edit dates of workouts: Response: ${response.body}, error:" + e.toString());
    }
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
      print("Trying to update workout..");
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
        oldWo.uploaded = wo.uploaded;
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
      if (!wo.uploaded) {
        print("_uploadOfflineWorkouts from add workout 1");
        this.uploadOfflineWorkouts(saveAndNotifyIfChanged: true);
      } else {
        print("saving from add_workout");
        this.save();
        notifyListeners();
      }
    }
    return (_addedWorkout);
  }

  void deleteWorkout(String workoutId, bool upload, {bool saveAndNotifyIfChanged = true}) async {
    print("Deleting workout $workoutId and upload = $upload");
    try {
      Workout wo = getWorkout(workoutId);
      wo.isNotDeleted = false;
      wo.uploaded = false;
      if (upload) {
        await this.uploadOfflineWorkouts(saveAndNotifyIfChanged: saveAndNotifyIfChanged);
      } else {
        _workouts.remove(wo.localId);
        if (saveAndNotifyIfChanged) {
          print("saving from delete_workout");
          this.save();
          notifyListeners();
        }
      }
    } catch (e) {
      print("Couldn't delete workout $workoutId because: $e");
    }
  }

  Workout getWorkout(String workoutId) {
    Workout workout;
    if (_workouts.containsKey(workoutId)) {
      workout = _workouts[workoutId];
    } else {
      _workouts.forEach((key, wo) {
        if (wo.localId == workoutId || wo.workoutId == workoutId) {
          workout = wo;
        }
      });
    }
    if (workout == null) {
      throw ("Couldn't find workout with id $workoutId");
    }
    return (workout);
  }

  bool hasWorkout(String workoutId) {
    bool hasWo = false;
    try {
      Workout wo = getWorkout(workoutId);
      if (wo != null) {
        hasWo = true;
      }
    } catch (e) {
      hasWo = false;
    }
    return (hasWo);
  }

  void addAction(Action ac, String workoutId, {bool saveAndNotifyIfChanged = true}) async {
    print("Workouts: adding action..");
    try {
      Workout wo = this.getWorkout(workoutId);
      wo.addAction(ac, fromUser: true);
      if (saveAndNotifyIfChanged) {
        print("_uploadOfflineWorkouts from adding action.");
        await this.uploadOfflineWorkouts(saveAndNotifyIfChanged: false);
        print("saving from add action");
        this.save();
        notifyListeners();
      }
    } catch (e) {
      print("couldn't add action: $e");
    }
  }

  void deleteAction(Action ac, {bool saveAndNotifyIfChanged = true}) async {
    Workout wo = byActionId(ac.actionId);
    // Workout wo = _workouts[ac.workoutId];
    wo.deleteAction(ac.actionId);
    if (saveAndNotifyIfChanged) {
      print("_uploadOfflineWorkouts from adding action.");
      await this.uploadOfflineWorkouts(saveAndNotifyIfChanged: false);
      print("saving from delete action");
      this.save();
      notifyListeners();
    }
  }

  Future<bool> uploadOfflineWorkouts({bool saveAndNotifyIfChanged = true}) async {
    // returns true if at least one workout was uploaded
    // tries to upload all not uploaded workouts and updates the Ids, then saves to shared_preferences
    // if saveAndNotifyIfChanged,  the current state is saved on phone.
    Map<String, Workout> offlineWorkouts = {};
    bool _uploaded = false;
    print("start uploading offline workouts.");
    _workouts.forEach((key, wo) {
      if (!wo.uploaded) {
        bool allExercisesUploaded = true;
        wo.actions.forEach((key, ac) {
          if (ac.exerciseId == "") {
            allExercisesUploaded = false;
          }
        });
        if (allExercisesUploaded) {
          offlineWorkouts.putIfAbsent(key, () => wo);
          print("Workout $key is not uploaded yet. Will be synced now.");
        } else {
          print("Workout $key can't be uploaded yet because at least one exercise is not uploaded yet.");
        }
      }
    });
    if (offlineWorkouts == null || offlineWorkouts.length == 0) {
      // print("offlineworkouts are null or 0");
      return (_uploaded);
    }
    Uri url = Uri.http(
      GlobalData.api_url,
      "workouts",
    );
    try {
      final response = await http.post(url,
          headers: {
            "token": _token,
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(this.toJson(workoutsMap: offlineWorkouts)));
      final result2 = json.decode(response.body) as Map<String, dynamic>; //localId:workoutId
      Map<String, dynamic> result = result2["data"];
      if (response.statusCode == 201) {
        result.forEach((_localId, _workoutId2) {
          try {
            String _workoutId = _workoutId2.toString();
            print("local id: $_localId workoutId: $_workoutId");
            Workout wo = getWorkout(_localId);
            _uploaded = true;
            if ((_workoutId == "" || _workoutId == "null" || _workoutId == null) && !wo.isNotDeleted) {
              // that's the response if workout was deleted on server after the deletion request was sent to server
              deleteWorkout(_localId, false, saveAndNotifyIfChanged: false);
            } else if (wo.isNotDeleted) {
              wo.workoutId = _workoutId;
              // localId is not changed! consistency with behaviour in exercises where it is needed to find exercises with local id.
              // this fixes the issue when an exercise is created offline, then an action is created with that exercise (so no id), then after syncing the ids for exercises change
              // so the action refers to a non-existent exercise.
              wo.uploaded = true;
            } else {
              print("ERROR: workout is not deleted but id came back empty: $wo");
              print("$_workoutId");
            }
          } catch (e2) {
            print("Error while syncing workouts: " + e2.toString());
          }
        });
      } else {
        print("Couldn't sync workouts. " + result2["message"].toString());
      }
    } catch (e) {
      print("Error while syncing workouts: " + e.toString());
    }
    if (saveAndNotifyIfChanged && _uploaded) {
      print("saving from offline uploads");
      this.save();
      notifyListeners();
    }
    return (_uploaded);
  }
}
