import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

// import '../models/http_exception.dart';

class User with ChangeNotifier {
  String _token;
  String _userName;
  String _email;
  String _userId;

  bool get isAuth {
    return token != null;
  }

  String get token {
    return _token;
  }

  String get userName {
    return _userName;
  }

  String get userId {
    return _userId;
  }

  String get email {
    return _email;
  }

  Future<void> _authenticate(
      String email, String password, String urlSgement) async {
    final url = 'https://api.kantnprojekt.club/v0_1/user/$urlSgement/';
    try {
      final response = await http.post(
        url,
        body: json.encode(
          {
            'email': email,
            'password': password,
            'returnSecureToken': true,
          },
        ),
      );
      final responseData = json.decode(response.body);
      //TODO: check for responsecode and throw error in Snackbar

      // if (responseData['error'] != null) {
      //   throw HttpException(responseData['error']['message']);
      // }
      _token = responseData['token'];
      _userName = responseData['user_name'];
      _userId = responseData['user_id'];
      _email = email;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      final userData = json.encode(
        {
          'token': _token,
          'userName': _userName,
          'userId': _userId,
          'email': email,
        },
      );
      prefs.setString('userData', userData);
    } catch (error) {
      throw error;
    }
  }

  Future<void> register(String email, String password) async {
    return _authenticate(email, password, 'register');
  }

  Future<void> login(String email, String password) async {
    return _authenticate(email, password, 'login');
  }

  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('userData')) {
      return false;
    }
    final extractedUserData =
        json.decode(prefs.getString('userData')) as Map<String, Object>;

    _token = extractedUserData['token'];
    _userName = extractedUserData['userName'];
    _userId = extractedUserData['userId'];
    _email = extractedUserData['email'];
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    _token = null;
    _userName = null;
    _email = null;
    _userId = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('userData');
    // prefs.clear();
  }
}

class Users {
  Map<String, String> users; //userId: userName

  Users();

  Future init() async {
    final prefs = await SharedPreferences.getInstance();
    users = json.decode(prefs.get("users"));
    print(users);
  }

  Future<String> getUsername(String userId) async {
    //first: try to get it from sharedprefs. If not, get from server and save
    if (users.containsKey(userId)) {
      return (users[userId]);
    }
    //TODO: get username via API
    return ("Kantn");
  }
}
