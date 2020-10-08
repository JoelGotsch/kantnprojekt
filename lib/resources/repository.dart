import 'dart:async';
import 'package:flutter/material.dart';

import 'api.dart';
import 'data_classes.dart';

class Repository {
  final apiProvider = ApiProvider();
  BackendUser user;

  Future<BackendUser> registerUser(String username, String firstname, String lastname, String password, String email) 
    => apiProvider.registerUser(username, firstname, lastname, password, email);

  Future<List<Workout>> getWorkouts(String api_key, DateTime startDate, DateTime endDate) 
    => apiProvider.getWorkouts(api_key, startDate: startDate, endDate: endDate);

  Future signinUser(String username, String password, String apiKey) 
    => apiProvider.signinUser(username, password, apiKey);
  
  // Future getUserTasks(String apiKey) 
  //   => apiProvider.getUserTasks(apiKey);

  // Future<Null> addUserTask(String apiKey, String taskName, String deadline) async {
  //   apiProvider.addUserTask(apiKey, taskName, deadline);
  // }

}