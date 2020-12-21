import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import 'package:intl/intl.dart';
import 'package:kantnprojekt/misc/challenge_exercise.dart';
import 'package:kantnprojekt/misc/decimalInputFormatter.dart';
import 'package:kantnprojekt/misc/user_exercise.dart';
import 'package:kantnprojekt/providers/exercises.dart';
import 'package:provider/provider.dart';

import '../providers/challenge.dart';
import '../providers/challenges.dart';
// import '../providers/user.dart';

import '../widgets/app_drawer.dart';

class CreateChallengeScreen extends StatefulWidget {
  // static const routeName = '/challenge';
  final Challenge challenge;

  CreateChallengeScreen(this.challenge);

  @override
  _CreateChallengeScreenState createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> {
  var _isLoading = false;
  final _challengeNameFocusNode = FocusNode();
  final _minPointsFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  final _formActions = GlobalKey<FormState>();
  final exerciseScrollController = ScrollController();

  @override
  void dispose() {
    _challengeNameFocusNode.dispose();
    _minPointsFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  Future<void> _createChallenge() async {
    final isValid = _formActions.currentState.validate();
    _formActions.currentState.save();
    print("creating challenge: ${widget.challenge.name}");
    if (!isValid ||
        widget.challenge.minPoints == 0 ||
        widget.challenge.startDate.compareTo(widget.challenge.endDate) > 0 ||
        widget.challenge.exercises.length == 0 ||
        widget.challenge.name == "Challenge-name") {
      return;
    }
    //updating existing UserExercise
    bool success = await Provider.of<Challenges>(context, listen: false).uploadChallenge(widget.challenge);
    if (success) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // String userId = Provider.of<User>(context, listen: false).userId;
    List<UserExercise> usExs = Provider.of<Exercises>(context, listen: false).userExercises.values.toList();

    print("building CreateChallengeScreen.");

    return Form(
      key: _formActions,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "Create new Challenge",
            style: TextStyle(color: Colors.white70),
          ),
        ),
        drawer: AppDrawer(),
        body: SingleChildScrollView(
          child: Container(
            height: MediaQuery.of(context).size.height - 80,
            width: MediaQuery.of(context).size.width,
            padding: EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Flexible(child: Text("How do you call your challenge? Must be a new (unique) name..")),
                SizedBox(
                  height: 10,
                ),
                Row(
                  // mainAxisAlignment: MainAxisAlignment.start,
                  // crossAxisAlignment: CrossAxisAlignment.baseline,
                  children: <Widget>[
                    Container(
                      width: MediaQuery.of(context).size.width * 0.7,
                      height: 20,
                      child: TextFormField(
                        autocorrect: true,
                        initialValue: "Challenge-name",
                        // decoration: InputDecoration(labelText: 'Anzahl'),
                        focusNode: _challengeNameFocusNode,
                        onSaved: (value) {
                          widget.challenge.name = value;
                        },
                        keyboardType: TextInputType.text,
                      ),
                    ),
                  ],
                ),
                Row(
                  // mainAxisAlignment: MainAxisAlignment.start,
                  // crossAxisAlignment: CrossAxisAlignment.baseline,
                  children: <Widget>[
                    Text("Choose the evaluation period: "),
                    SizedBox(
                      width: 20,
                    ),
                    Container(
                      width: 75,
                      child: DropdownButton<String>(
                        items: <String>["day", "week", "month", "year"].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        value: widget.challenge.evalPeriod,
                        onChanged: (value) {
                          print("Changed eval-period to $value");
                          widget.challenge.evalPeriod = value;
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 10,
                ),
                Row(
                  // mainAxisAlignment: MainAxisAlignment.start,
                  // crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Container(
                      width: MediaQuery.of(context).size.width * 0.2,
                      height: 20,
                      child: TextFormField(
                        autocorrect: false,
                        initialValue: "0",
                        // decoration: InputDecoration(labelText: 'points'),
                        focusNode: _minPointsFocusNode,
                        validator: (value) {
                          try {
                            var val = double.parse(value);
                          } catch (e) {
                            return (e.toString());
                          }
                          return null;
                        },
                        onSaved: (value) {
                          widget.challenge.minPoints = double.parse(value);
                        },
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [DecimalTextInputFormatter(decimalRange: 2)], // Only numbers can be entered
                      ),
                    ),
                    Flexible(
                      child: Text(" points must be reached each period"),
                    ),
                  ],
                ),
                GestureDetector(
                  child: Container(
                    // color: Theme.of(context).accentColor,
                    padding: EdgeInsets.all(10),
                    child: Row(
                      children: <Widget>[
                        Text("Start the challenge on: "),
                        CircleAvatar(
                          backgroundColor: Theme.of(context).accentColor,
                          radius: 20,
                          child: Icon(
                            Icons.calendar_today,
                            color: Colors.white70,
                          ),
                        ),
                        SizedBox(
                          width: 7,
                        ),
                        Text(
                          DateFormat('EEE, dd-MM-yyyy').format(widget.challenge.startDate),
                        ),
                      ],
                    ),
                  ),
                  onTap: () {
                    DatePicker.showDatePicker(context,
                        currentTime: widget.challenge.startDate,
                        showTitleActions: true,
                        minTime: DateTime(2020, 1, 1),
                        onChanged: (date) {}, onConfirm: (date) {
                      setState(() {
                        widget.challenge.startDate = date;
                      });
                    }, locale: LocaleType.de);
                  },
                ),
                GestureDetector(
                  child: Container(
                    // color: Theme.of(context).accentColor,
                    padding: EdgeInsets.all(10),
                    child: Row(
                      children: <Widget>[
                        Text("End the challenge on: "),
                        CircleAvatar(
                          backgroundColor: Theme.of(context).accentColor,
                          radius: 20,
                          child: Icon(
                            Icons.calendar_today,
                            color: Colors.white70,
                          ),
                        ),
                        SizedBox(
                          width: 7,
                        ),
                        Text(
                          DateFormat('EEE, dd-MM-yyyy').format(widget.challenge.endDate),
                        ),
                      ],
                    ),
                  ),
                  onTap: () {
                    DatePicker.showDatePicker(context,
                        currentTime: widget.challenge.endDate, showTitleActions: true, minTime: DateTime(2020, 1, 1), onChanged: (date) {}, onConfirm: (date) {
                      setState(() {
                        widget.challenge.endDate = date;
                      });
                    }, locale: LocaleType.de);
                  },
                ),
                SizedBox(
                  height: 10,
                ),
                Text("Describe the challenge:"),
                Container(
                  height: 90,
                  child: TextFormField(
                    autocorrect: true,
                    initialValue: widget.challenge.description,
                    // decoration: InputDecoration(labelText: 'Anzahl'),
                    focusNode: _descriptionFocusNode,
                    onSaved: (value) {
                      widget.challenge.description = value;
                    },
                    maxLines: 4,
                    keyboardType: TextInputType.multiline,
                  ),
                ),
                SizedBox(
                  height: 10,
                ),
                Text("Exercises:"),
                Container(
                  height: min(max(MediaQuery.of(context).size.height - 560, 200), 500),
                  child: Scrollbar(
                    isAlwaysShown: true,
                    controller: exerciseScrollController,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(7.0),
                      itemCount: usExs.length,
                      controller: exerciseScrollController,
                      itemBuilder: (ctx, i) => Card(
                        margin: EdgeInsets.all(5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: ListTile(
                          title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
                            Flexible(
                              child: Text("${usExs[i].title}"),
                            ),
                            usExs[i].unit == "" ? Text("${usExs[i].points} points per exercise") : Text("${usExs[i].points} points per ${usExs[i].unit}"),
                            widget.challenge.exercises.containsKey(usExs[i].exercise.exerciseId)
                                ? RaisedButton(
                                    onPressed: () {
                                      widget.challenge.exercises.remove(usExs[i].exercise.exerciseId);
                                      setState(() {});
                                    },
                                    color: Theme.of(context).accentColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10.0),
                                      // side: BorderSide(color: Colors.red)
                                    ),
                                    child: Text(
                                      "remove Exercise",
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  )
                                : RaisedButton(
                                    onPressed: () {
                                      widget.challenge.exercises.putIfAbsent(
                                          usExs[i].exercise.exerciseId, () => ChallengeExercise.fromExercise(usExs[i].exercise, widget.challenge.challengeId));
                                      setState(() {});
                                    },
                                    color: Theme.of(context).accentColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10.0),
                                      // side: BorderSide(color: Colors.red)
                                    ),
                                    child: Text(
                                      "add Exercise",
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ),
                          ]),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              usExs[i].dailyAllowance == 0 ? Container() : Text("${usExs[i].dailyAllowance} ${usExs[i].unit} per day is/are not counted."),
                              usExs[i].weeklyAllowance == 0 ? Container() : Text("${usExs[i].weeklyAllowance} ${usExs[i].unit} per week is/are not counted."),
                              usExs[i].maxPointsDay == 0 ? Container() : Text("Maximum of ${usExs[i].maxPointsDay} points per day with this exercise"),
                              usExs[i].maxPointsWeek == 0 ? Container() : Text("Maximum of ${usExs[i].maxPointsWeek} points per week with this exercise"),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _createChallenge,
          icon: _isLoading ? CircularProgressIndicator() : Icon(Icons.add),
          label: _isLoading ? CircularProgressIndicator() : Text("Create challenge"),
        ),
      ),
    );
  }
}
