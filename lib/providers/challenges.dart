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
import 'challenge.dart';

class Challenges with ChangeNotifier {
  // manages all the challenge- objects: making sure they are uploaded/
  Map<String, Challenge> _challenges = {};
  String _token;
  DateTime lastRefresh = DateTime(2020);
  bool loadedOnlineChallenges = false; // makes sure that syncronize is only called once
  bool loadingOnlineChallenges = false; // prevents that within an update, the sync process is started again.

  Challenges(this._token, this._challenges, this.lastRefresh);

  factory Challenges.create() {
    print("Challenges created empty.");
    Challenges chs = Challenges("", {}, DateTime(2020));
    return (chs);
  }

  factory Challenges.fromPrevious(String token, Challenges previousChallenges) {
    print("Challenges.fromPrevious is run.");
    if (token == "" || token == null) {
      // on logout, token is set to null
      previousChallenges = Challenges.create();
      return (previousChallenges);
    }
    previousChallenges._token = token;
    // dont save new exercises yet, as the old ones are needed to compare to news for action updates
    print("challenges from previous $token, ${!previousChallenges.loadedOnlineChallenges}, ${!previousChallenges.loadingOnlineChallenges}");
    if (token != null && token != "" && !previousChallenges.loadedOnlineChallenges && !previousChallenges.loadingOnlineChallenges) {
      previousChallenges.loadingOnlineChallenges = true;
      previousChallenges.totalRefresh();
      // TODO: run through the normal setup process, only loading necessary data
    }
    return (previousChallenges);
  }

  void setup() async {
    print("running challenges setup..");
    bool addedChallenge = await addingFromStorage(saveAndNotifyIfChanged: false);
    // print("after added challenges from storage: $this");
    addedChallenge = await syncronize(saveAndNotifyIfChanged: false) || addedChallenge;
    // print("after added challenges from syncronizing: $this");
    print("Challenges setup completed, now notifying listeners");
    if (addedChallenge) {
      print("saving from setup");
      this.save();
    }
    notifyListeners();
  }

  Future<bool> addingFromStorage({bool saveAndNotifyIfChanged = false}) async {
    bool addedExercise = false;
    print("adding challenges from storage");
    try {
      final prefs = await SharedPreferences.getInstance();
      String chString = prefs.getString("Challenges");
      // print(chString);
      Map<String, dynamic> _json = json.decode(chString);
      addedExercise = this.addingFromJson(_json, saveAndNotifyIfChanged: false);
      if (saveAndNotifyIfChanged && addedExercise) {
        // print("saving from add from storage");
        // this.save();
        notifyListeners();
      }
      return (addedExercise);
    } catch (e) {
      print("Error: Couldn't load exercises/ userExercises from storage, probably never saved them. " + e.toString());
    }
    return (false);
  }

  bool addingFromJson(Map<String, dynamic> challengesMap, {saveAndNotifyIfChanged: true}) {
    // returns true if a challenge was added or updated.
    // if saveAndNotifyIfChanged is true, then new challenges are saved and NotifyListeners is performed here.
    bool _addedChallenge = false;
    print("adding from json");
    try {
      challengesMap.forEach((key, value) {
        // print("adding from json: try to create challenge from $value");
        Challenge ch = Challenge.fromJson(value);
        _addedChallenge = this.addChallenge(ch, saveAndNotifyIfChanged: false) || _addedChallenge;
        // print("added exercise from storage: ${ex.exerciseId}");
      });
    } catch (e) {
      print("Couldn't load challenges from Json. " + e.toString());
    }
    if (saveAndNotifyIfChanged && _addedChallenge) {
      save();
      notifyListeners();
    }
    return (_addedChallenge);
  }

  Future<bool> totalRefresh() async {
    bool success = false;
    Map<String, String> queryParameters = {};
    queryParameters["detail_level"] = "details";
    Uri url = Uri.https(
      GlobalData.apiUrlStart,
      GlobalData.apiUrlVersion + "challenges",
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

    if (response.statusCode == 201) {
      _challenges = {};
      Map<String, dynamic> newChallenges = result["data"];
      newChallenges.forEach((key, value) {
        Challenge ch = Challenge.fromJson(value);
        _challenges.putIfAbsent(ch.challengeId, () => ch);
      });
      this.save();
      loadedOnlineChallenges = true;
      success = true;
    } else {
      // If that call was not successful, throw an error.
      print('ERROR: Failed to load Challenge: ' + result["message"].toString());
    }
    loadingOnlineChallenges = false;
    if (success) {
      notifyListeners();
    }
    return (success);
  }

  Future<bool> joinChallenge(Challenge ch, String userId) async {
    // server should return the ChallengeUser data of user.
    bool success = false;
    Map<String, String> queryParameters = {};
    queryParameters["challenge_id"] = ch.challengeId;
    Uri url = Uri.https(
      GlobalData.apiUrlStart,
      GlobalData.apiUrlVersion + "challengeaccept",
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

    if (response.statusCode == 201) {
      Map<String, dynamic> challengeUserInfo = result["data"];
      ChallengeUser myself = ChallengeUser.fromJson(challengeUserInfo);
      ch.users.putIfAbsent(myself.userId, () => myself);
      this.save();
      loadedOnlineChallenges = true;
      success = true;
    } else {
      // If that call was not successful, throw an error.
      print('ERROR: Failed to join Challenge: ' + result["message"].toString());
    }
    loadingOnlineChallenges = false;
    if (success) {
      notifyListeners();
    }
    return (success);
  }

  Future<bool> syncronize({bool saveAndNotifyIfChanged = true}) async {
    // for now, just download everything!

    // syncronize users, update challenge-list
    bool addedChallenge = false;
    bool _saving = false;
    print("challenges syncronize is running..");
    // now fetching the whole list of challenges with newest dates to compare to the one on the phone:
    Map<String, DateTime> challengeEditDates = {};
    List<String> serverNewChIds = [];
    List<String> deledtedChIds = [];
    try {
      // post json with {challengeId:{hash, latestEdit, users:{userId:{hash, latestEdit}}}}
      challengeEditDates = await this.fetchHeaders();
      challengeEditDates.forEach((id, chLatestEdit) {
        if (_challenges.containsKey(id)) {
          Challenge ch = _challenges[id];
          if (ch.lastRefresh.compareTo(chLatestEdit) < 0) {
            // exLatestEdit is later => info on server is newer
            print("Found newer version of challenge $id on server: server: ${chLatestEdit.toIso8601String()} vs local ${ch.lastRefresh.toIso8601String()}");
            serverNewChIds.add(id);
          } else if (ch.lastRefresh.compareTo(chLatestEdit) > 0) {
            print("Found newer version of challenge $id on phone: server: ${chLatestEdit.toIso8601String()} vs local ${ch.lastRefresh.toIso8601String()}");
            if (ch.uploaded) {
              print("ERROR: challenge should be newer on the phone, but it is already uploaded???");
              ch.uploaded = false;
            }
          }
        } else {
          serverNewChIds.add(id);
        }
      });
      _challenges.forEach((chId, ch) {
        if (!challengeEditDates.containsKey(chId) && ch.uploaded) {
          deledtedChIds.add(chId);
        }
      });
      deledtedChIds.forEach((key) {
        _challenges.remove(key);
      });

      Map<String, dynamic> newChallenges = await this._fetch(challengeIds: serverNewChIds);
      addedChallenge = addingFromJson(newChallenges, saveAndNotifyIfChanged: false);
      loadedOnlineChallenges = true;
      lastRefresh = DateTime.now();
      // print(exerciseEditDates);
      // check which editDates dont match with saved ones and get newer ones from server and post (send) if newer from app.
    } catch (e) {
      print("Error in syncronize Challenges: $e");
    }
    // this.fetchNew();
    if (saveAndNotifyIfChanged && addedChallenge) {
      notifyListeners();
      if (_saving) {
        print("saving challenges from syncronize");
        await this.save();
      }
    }
    loadingOnlineChallenges = false;
    return (addedChallenge);
  }

  Map<String, Challenge> get allChallenges {
    return (_challenges);
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    print("saving ${_challenges.length} challenges..");
    String output = this.toString();
    prefs.setString('Challenges', output);
  }

  Future<Map<String, dynamic>> _fetch(
      {String challengeId, List<String> challengeIds, DateTime minEditDate, DateTime startDate, DateTime endDate, int number = 0}) async {
    // deletes all locally stored exercises and loads the complete list from online database and stores values in sharedPreferences
    Map<String, dynamic> newChallenges = {};
    Map<String, String> queryParameters = {};
    print("start fetching challenges..");
    if (challengeId != null) {
      queryParameters["challenge_id"] = challengeId;
    }
    if (challengeIds != null) {
      queryParameters["challenge_ids"] = challengeIds.join(",");
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
    Uri url = Uri.https(
      GlobalData.apiUrlStart,
      GlobalData.apiUrlVersion + "challenges",
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
      newChallenges = result["data"];
    } else {
      // If that call was not successful, throw an error.
      throw Exception('Failed to load Challenge: ' + result["message"].toString());
    }
    return (newChallenges);
  }

  Future<void> fetchNew() async {
    print("fetching new challenges since $lastRefresh");
    try {
      Map<String, dynamic> newChallenges = await this._fetch(minEditDate: lastRefresh);
      addingFromJson(newChallenges, saveAndNotifyIfChanged: true);
      print("fetched new challenges");
    } catch (e) {
      print("Couldn't fetch new challenges: $e");
    }

    lastRefresh = DateTime.now();
  }

  Future<Map<String, DateTime>> fetchHeaders() async {
    Map<String, DateTime> allChallenges = {};
    Map<String, String> queryParameters = {};
    print("start fetching challenge headers ..");
    queryParameters["detail_level"] = "headers";
    Uri url = Uri.https(
      GlobalData.apiUrlStart,
      GlobalData.apiUrlVersion + "challenges",
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
      // print("result in fetching challenge headers: $result");

      if (response.statusCode == 201 || response.statusCode == 200) {
        // for (Map json_ in result["data"]) {
        result.forEach((key, value) {
          try {
            allChallenges.putIfAbsent(key, () => DateTime.parse(value));
          } catch (Exception) {
            print(Exception);
          }
        });
        return (allChallenges);
      } else {
        // If that call was not successful, throw an error.
        throw Exception('Failed to load Challenge ' + result["message"]);
      }
    } catch (e) {
      throw ("Problem while fetching last edit dates of challenges: Response: ${response.body}, error:" + e.toString());
    }
  }

  Map<String, dynamic> toJson({Map<String, Challenge> challengesMap}) {
    // contains all challenges by default, if set to false, only the not deleted ones are returned
    Map<String, dynamic> helper = {};
    if (challengesMap == null) {
      challengesMap = this.allChallenges;
    }
    challengesMap.forEach((key, value) {
      helper.putIfAbsent(key, () => value.toJson());
    });
    return (helper);
  }

  @override
  String toString() {
    return (json.encode(this.toJson()));
  }

  bool addChallenge(Challenge ch, {bool saveAndNotifyIfChanged = true}) {
    // returns true if a challenge was added or changed.
    bool _addedChallenge = false;

    if (hasChallenge(ch.challengeId)) {
      // update existing challenge
      Challenge oldCh = getChallenge(ch.challengeId);
      print("ERROR: adding challenge: challenge already exists. this shouldn't happen..");
    } else {
      // a new challenge!
      if (ch.challengeId.toString().length <= 10) {
        throw (Exception("challenge id is null. ${ch.challengeId}"));
      }
      print("added new challenge ${ch.challengeId}");
      _challenges[ch.challengeId] = ch;
      _addedChallenge = true;
    }

    if (saveAndNotifyIfChanged && _addedChallenge && ch.uploaded) {
      print("saving from add_challenge");
      this.save();
      notifyListeners();
    }
    return (_addedChallenge);
  }

  Challenge getChallenge(String challengeId) {
    // getting Challenge by its real Id. but localId works too.
    Challenge challenge;
    if (_challenges.containsKey(challengeId)) {
      challenge = _challenges[challengeId];
    } else {
      throw ("Couldn't find challenge with id $challengeId");
      // _challenges.forEach((key, ch) {
      //   if (ch.localId == challengeId || ch.challengeId == challengeId) {
      //     challenge = ch;
      //   }
      // });
    }
    // if (challenge == null) {
    //   throw ("Couldn't find challenge with id $challengeId");
    // }
    return (challenge);
  }

  bool hasChallenge(String challengeId) {
    bool hasCh = false;
    try {
      Challenge ch = getChallenge(challengeId);
      hasCh = true;
    } catch (e) {
      hasCh = false;
    }
    return (hasCh);
  }

  Future<bool> uploadChallenge(Challenge ch, {bool saveAndNotifyIfChanged = true}) async {
    // sending to server, getting challengeId
    if (ch.uploaded) {
      print("ERROR: For some reason an already uploaded challenge was tried to be uploaded.");
      return (true);
    }
    bool success = false;
    Uri url = Uri.https(
      GlobalData.apiUrlStart,
      GlobalData.apiUrlVersion + "challenge",
    );
    try {
      final response = await http.post(url,
          headers: {
            "token": _token,
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(ch.toJson()));

      final result2 = json.decode(response.body) as Map<String, dynamic>; //localId:workoutId
      Map<String, dynamic> result = result2["data"];
      if (response.statusCode == 201) {
        String newChallengeId = result["challenge_id"];
        if (newChallengeId == null || newChallengeId == "" || newChallengeId.length < 10) {
          throw ("No valild response from server to posting new challenge");
        } else {
          ch.challengeId = newChallengeId;
          ch.uploaded = true;
          (result["exercises"] as Map<String, dynamic>).forEach((key, value) {
            try {
              ch.exercises[key].challengeExerciseId = value.toString();
            } catch (e) {
              print("ERROR: couldn't update challenge-exercise-ids after uploading challenge: $e");
            }
          });

          addChallenge(ch, saveAndNotifyIfChanged: true);
          success = true;
        }
      } else {
        print("Couldn't upload challenge. " + result2["message"].toString());
      }
    } catch (e) {
      print("Error while uploading challenge: " + e.toString());
    }
    return (success);
  }
}
