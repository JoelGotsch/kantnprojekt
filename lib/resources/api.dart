import 'package:http/http.dart' show Client;
// import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:kantnprojekt/resources/data_classes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ApiProvider {
  Client client = Client();
  // final _apiKey = 'your_api_key';

  Future<List<Workout>> getWorkouts(String username,
      {int workoutId, DateTime startDate, DateTime endDate}) async {
    // var uri = "http://api.kantnprojekt.club/v0_1/workout";
    var uri = "http://api.kantnprojekt.club/v0_1/test";

    final response = await client.get(
      uri,
      headers: {
        "username": "Viech",
        "start_date": DateFormat('yyyy-MM-dd').format(startDate),
        "end_date": DateFormat('yyyy-MM-dd').format(endDate)
      },
    );
    final Map result = json.decode(response.body);
    print(response.statusCode);
    // print(result["data"]);
    List<Workout> workouts=[];

    if (response.statusCode == 201 || response.statusCode == 200) {
      // for (Map json_ in result["data"]) {
      for (Map json_ in result.values) {
        try {
          workouts.add(Workout.fromJson(json_));
        } catch (Exception) {
          print(Exception);
        }
      }
    } else {
      // If that call was not successful, throw an error.
      throw Exception('Failed to load Workout');
    }
    return (workouts);
  }

  Future<BackendUser> registerUser(String username, String firstname,
      String lastname, String password, String email) async {
    // var uri = GlobalConfiguration().getValue("host_ip") +
    //     ":" +
    //     GlobalConfiguration().getValue("port") +
    //     "/" +
    //     GlobalConfiguration().getValue("api_name") +
    //     "/register";
    var uri = "http://api.kantnprojekt.club/v0_1/user";
    // TODO: first do the firebase registration

    final response =
        await client.post(uri, //"http://10.0.2.2:5000/api/register",
            // headers: "",
            body: jsonEncode({
              "emailadress": email,
              "username": username,
            }));
    final Map result = json.decode(response.body);
    if (response.statusCode == 201) {
      // If the call to the server was successful, parse the JSON
      await saveApiKey(result["data"]["api_key"]);
      await saveUserId(result["data"]["user_id"]);
      return BackendUser.fromJson(result["data"]);
    } else {
      // If that call was not successful, throw an error.
      throw Exception('Failed to load post');
    }
  }

  Future signinUser(String username, String password, String apiKey) async {
    // var uri = GlobalConfiguration().getValue("host_ip") +
    //     ":" +
    //     GlobalConfiguration().getValue("port") +
    //     "/" +
    //     GlobalConfiguration().getValue("api_name") +
    //     "/signin";
    var uri = "http://api.kantnprojekt.club/v0_1/user";
    // TODO: first login to firebase
    final response = await client.post(uri,
        headers: {"Authorization": apiKey},
        body: jsonEncode({
          "username": username,
          "password": password,
        }));
    final Map result = json.decode(response.body);
    if (response.statusCode == 201) {
      // If the call to the server was successful, parse the JSON
      if (result["data"][1] == 400) {
        print("Wrong Username/ password combination");
      } else {
        await saveApiKey(result["data"]["api_key"]);
      }
    } else {
      // If that call was not successful, throw an error.
      print('Failed to login user - no server answer.');
    }
  }

  // Future<List<Task>> getUserTasks(String apiKey) async {
  //   // var uri = GlobalConfiguration().getValue("host_ip") +
  //   //     ":" +
  //   //     GlobalConfiguration().getValue("port") +
  //   //     "/" +
  //   //     GlobalConfiguration().getValue("api_name") +
  //   //     "/tasks";

  //   var uri = "http://10.0.2.2:5000/api/tasks";
  //   final response = await client.get(
  //     uri,
  //     headers: {"Authorization": apiKey},
  //   );
  //   final Map result = json.decode(response.body);
  //   if (response.statusCode == 201) {
  //     // If the call to the server was successful, parse the JSON
  //     List<Task> tasks = [];
  //     for (Map json_ in result["data"]) {
  //       try {
  //         tasks.add(Task.fromJson(json_));
  //       } catch (Exception) {
  //         print(Exception);
  //       }
  //     }
  //     for (Task task in tasks) {
  //       print(task.taskId);
  //     }
  //     return tasks;
  //   } else {
  //     // If that call was not successful, throw an error.
  //     List<Task> tasks = [];
  //     print("Couldn't load tasks");
  //     return(tasks);
  //     // throw Exception('Failed to load tasks');
  //   }
  // }

  // Future addUserTask(String apiKey, String taskName, String deadline) async {
  //   // var uri = GlobalConfiguration().getValue("host_ip") +
  //   //     ":" +
  //   //     GlobalConfiguration().getValue("port") +
  //   //     "/" +
  //   //     GlobalConfiguration().getValue("api_name") +
  //   //     "/tasks";
  //   var uri = "http://10.0.2.2:5000/api/tasks";
  //   final response = await client.post(uri,
  //       headers: {"Authorization": apiKey},
  //       body: jsonEncode({
  //         "note": "",
  //         "repeats": "",
  //         "completed": false,
  //         "deadline": deadline,
  //         "reminders": "",
  //         "title": taskName
  //       }));
  //   if (response.statusCode == 201) {
  //     print("Task added");
  //   } else {
  //     // If that call was not successful, throw an error.
  //     print(json.decode(response.body));
  //     throw Exception('Failed to load tasks');
  //   }
  // }

  saveApiKey(String api_key) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('API_Token', api_key);
  }

  saveUserId(String id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('User_Id', id);
  }
}
