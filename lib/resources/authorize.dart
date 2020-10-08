// not used yet

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthService with ChangeNotifier {
  var currentUser;
  var firebaseUser;

  AuthService() {
    print("new AuthService");
  }

  Future getUser() {
    return Future.value(currentUser);
  }

  // wrappinhg the firebase calls
  Future logout() {
    this.currentUser = null;
    notifyListeners();
    return Future.value(currentUser);
  }

  // wrapping the firebase calls
  Future createUser(
      {String firstName,
      String lastName,
      String email,
      String password,
      String username}) async {
          try {
            await Firebase.initializeApp();
            User fbUser = (await FirebaseAuth.instance
                .createUserWithEmailAndPassword(
                    email: email,
                    password: password,)).user;
            if(fbUser != null){
              await FirebaseAuth.instance.currentUser.updateProfile(displayName:username);
              firebaseUser = fbUser;
            }

            // TODO: Create user also in our database!

          } catch (e) {
            print(e);
            // _usernameController.text = "";
            // _passwordController.text = "";
            // _repasswordController.text = "";
            // _emailController.text = "";
            // TODO: alertdialog with error
          }
      }

  // logs in the user if password matches
  Future loginUser({String email, String password}) {
    if (password == 'password123') {
      this.currentUser = {'email': email};
      notifyListeners();
      return Future.value(currentUser);
    } else {
      this.currentUser = null;
      return Future.value(null);
    }
  }
} 


        // onPressed: () async {
        //   try {
        //     await Firebase.initializeApp();
        //     User user = (await FirebaseAuth.instance
        //         .createUserWithEmailAndPassword(
        //             email: _emailController.text,
        //             password: _passwordController.text,)).user;
        //     if(user != null){
        //       await FirebaseAuth.instance.currentUser.updateProfile(displayName:_usernameController.text);
        //       Navigator.of(context).pushNamed(AppRoutes.menu);
        //     }
        //     // TODO: Create user also in our database!

        //   } catch (e) {
        //     print(e);
        //     // _usernameController.text = "";
        //     // _passwordController.text = "";
        //     // _repasswordController.text = "";
        //     // _emailController.text = "";
        //     // TODO: alertdialog with error
        //   }