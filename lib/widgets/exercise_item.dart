import 'dart:math';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/exercises.dart';
import '../providers/user.dart';
import '../misc/functions.dart' as funcs;
import '../misc/user_exercise.dart';
import '../misc/exercise.dart';
import '../misc/decimalInputFormatter.dart';
// import '../views/edit_workout.dart';

class ExerciseItem extends StatefulWidget {
  final UserExercise userExercise;
  const ExerciseItem({
    @required Key key,
    @required this.userExercise,
  }) : super(key: key);

  @override
  _ExerciseItemState createState() => _ExerciseItemState();
}

class _ExerciseItemState extends State<ExerciseItem> {
  bool _expanded = false;
  bool _isInit = true;
  // bool _isVisible = true;
  final _titleFocusNode = FocusNode();
  final _noteFocusNode = FocusNode();
  // final _descriptionFocusNode = FocusNode();
  final _unitFocusNode = FocusNode();
  final _pointsFocusNode = FocusNode();
  final _maxPointsDayFocusNode = FocusNode();
  final _weeklyAllowanceFocusNode = FocusNode();
  // final _form = GlobalKey<FormState>(); // Used for note?
  final _formActions = GlobalKey<FormState>();
  bool _exerciseVisible;
  double _points;
  double _maxPointsDay;
  double _weeklyAllowance;
  String _note;
  String _title;
  String _unit;

  @override
  void didChangeDependencies() {
    if (_isInit) {
      // _exerciseVisible
      _exerciseVisible = widget.userExercise.isVisible;
      _points = widget.userExercise.points;
      _maxPointsDay = widget.userExercise.maxPointsDay;
      _weeklyAllowance = widget.userExercise.weeklyAllowance;
      _note = widget.userExercise.note;
      _title = widget.userExercise.exercise.title;
      _unit = widget.userExercise.exercise.unit;
    }
    _isInit = false;
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _noteFocusNode.dispose();
    _titleFocusNode.dispose();
    _unitFocusNode.dispose();
    _pointsFocusNode.dispose();
    _maxPointsDayFocusNode.dispose();
    _weeklyAllowanceFocusNode.dispose();
    // _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveExercise() async {
    final isValid = _formActions.currentState.validate();
    _formActions.currentState.save();
    if (!isValid || _points == 0 || _maxPointsDay < 0 || _weeklyAllowance < 0 || _title == "") {
      return;
    }
    if (widget.userExercise.exercise.title == "") {
      // creating new exercise + userExercise
      Exercise ex = Exercise(_title, _note, _unit, _points,
          maxPointsDay: _maxPointsDay,
          weeklyAllowance: _weeklyAllowance,
          localId: funcs.getRandomString(30),
          latestEdit: DateTime.now(),
          userId: Provider.of<User>(context, listen: false).userId);
      UserExercise usEx = UserExercise.fromExercise(ex);
      Provider.of<Exercises>(context, listen: false).addExercise(ex, saveAndNotifyIfChanged: false);
      Provider.of<Exercises>(context, listen: false).addUserExercise(usEx, saveAndNotifyIfChanged: true);
      Provider.of<Exercises>(context, listen: false).cleanEmptyExercises();
    } else {
      //updating existing UserExercise
      Provider.of<Exercises>(context, listen: false).updateUserExercise(widget.userExercise.localId,
          weeklyAllowance: _weeklyAllowance, note: _note, points: _points, isVisible: _exerciseVisible, maxPointsDay: _maxPointsDay);
    }
  }

  @override
  Widget build(BuildContext context) {
    // workout = Provider.of<wo.Workout>(context);
    // final double totalHeight = min(workout.actions.length * 45.0 + 100, 900);
    double totalHeight = 362;
    if (widget.userExercise.exercise.title == "") {
      // creating a new userExercise + Exercise
      totalHeight = 474;
    }
    return Form(
      key: _formActions,
      child: Card(
        margin: EdgeInsets.all(5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Dismissible(
          key: ValueKey(widget.userExercise.localId),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: 20),
            color: Theme.of(context).errorColor,
            child: Icon(
              Icons.delete,
              color: Colors.white,
              size: 40,
            ),
          ),
          onDismissed: (direction) {
            print("TODO: delete UserExercise");
            // Provider.of<wos.Workouts>(context, listen: false).deleteWorkout(workout.localId);
          },
          child: Column(children: <Widget>[
            GestureDetector(
              onTap: () {
                setState(() {
                  _expanded = !_expanded;
                });
              },
              child: ListTile(
                title: widget.userExercise.exercise.title == "" ? Text("New exercise") : Text('${widget.userExercise.title}'),
                trailing: IconButton(
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () {
                    setState(() {
                      _expanded = !_expanded;
                    });
                  },
                ),
              ),
            ),
            if (_expanded || widget.userExercise.exercise.title == "")
              Container(
                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 0),
                height: totalHeight,
                child: Column(
                  children: <Widget>[
                    Row(children: <Widget>[
                      Switch(
                          value: _exerciseVisible,
                          onChanged: (value) {
                            setState(() {
                              _exerciseVisible = value;
                            });
                          }),
                      Text("visible in workouts")
                    ]),
                    if (widget.userExercise.exercise.title == "")
                      Row(
                        // mainAxisAlignment: MainAxisAlignment.start,
                        // crossAxisAlignment: CrossAxisAlignment.baseline,
                        children: <Widget>[
                          Container(
                            width: MediaQuery.of(context).size.width * 0.2,
                            child: TextFormField(
                              autocorrect: true,
                              initialValue: "new Exercise",
                              // decoration: InputDecoration(labelText: 'Anzahl'),
                              focusNode: _titleFocusNode,
                              onSaved: (value) {
                                _title = value;
                              },
                              keyboardType: TextInputType.text,
                            ),
                          ),
                          Flexible(child: Text(" title of exercise. Must be unique and can't be changed afterwards. Can't be empty.")),
                        ],
                      ),
                    if (widget.userExercise.exercise.title == "")
                      Row(
                        // mainAxisAlignment: MainAxisAlignment.start,
                        // crossAxisAlignment: CrossAxisAlignment.baseline,
                        children: <Widget>[
                          Container(
                            width: MediaQuery.of(context).size.width * 0.2,
                            child: TextFormField(
                              autocorrect: true,
                              initialValue: "",
                              // decoration: InputDecoration(labelText: 'Anzahl'),
                              focusNode: _unitFocusNode,
                              onSaved: (value) {
                                _unit = value;
                              },
                              keyboardType: TextInputType.text,
                            ),
                          ),
                          Flexible(
                              child: Text(
                                  " unit in which the exercise is measured (e.g 'min' for minutes). If the exercise is counted (e.g. push-ups), leave it empty. Can't be changed later.")),
                        ],
                      ),
                    Row(
                      // mainAxisAlignment: MainAxisAlignment.start,
                      // crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Container(
                          width: MediaQuery.of(context).size.width * 0.2,
                          child: TextFormField(
                            autocorrect: false,
                            initialValue: _points.toString(),
                            // decoration: InputDecoration(labelText: 'points'),
                            focusNode: _pointsFocusNode,
                            validator: (value) {
                              try {
                                var val = double.parse(value);
                              } catch (e) {
                                return (e.toString());
                              }
                              return null;
                            },
                            onSaved: (value) {
                              _points = double.parse(value);
                            },
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [DecimalTextInputFormatter(decimalRange: 2)], // Only numbers can be entered
                          ),
                        ),
                        Flexible(
                          child: widget.userExercise.unit == "" ? Text(" points each") : Text(" points per " + widget.userExercise.unit),
                        ),
                      ],
                    ),
                    Row(
                      // mainAxisAlignment: MainAxisAlignment.start,
                      // crossAxisAlignment: CrossAxisAlignment.baseline,
                      children: <Widget>[
                        Container(
                          width: MediaQuery.of(context).size.width * 0.2,
                          child: TextFormField(
                            autocorrect: false,
                            initialValue: _maxPointsDay.toString(),
                            // decoration: InputDecoration(labelText: 'Anzahl'),
                            focusNode: _maxPointsDayFocusNode,
                            validator: (value) {
                              try {
                                var val = double.parse(value);
                              } catch (e) {
                                return (e.toString());
                              }
                              return null;
                            },
                            onSaved: (value) {
                              _maxPointsDay = double.parse(value);
                            },
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [DecimalTextInputFormatter(decimalRange: 2)], // Only numbers can be entered
                          ),
                        ),
                        Flexible(child: Text(" maximum amount of points per day. 0 means no maximum.")),
                      ],
                    ),
                    Row(
                      // mainAxisAlignment: MainAxisAlignment.start,
                      // crossAxisAlignment: CrossAxisAlignment.baseline,
                      children: <Widget>[
                        Container(
                          width: MediaQuery.of(context).size.width * 0.2,
                          child: TextFormField(
                            autocorrect: false,
                            initialValue: _weeklyAllowance.toString(),
                            // decoration: InputDecoration(labelText: 'Anzahl'),
                            focusNode: _weeklyAllowanceFocusNode,
                            validator: (value) {
                              try {
                                var val = double.parse(value);
                              } catch (e) {
                                return (e.toString());
                              }
                              return null;
                            },
                            onSaved: (value) {
                              _weeklyAllowance = double.parse(value);
                            },
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [DecimalTextInputFormatter(decimalRange: 2)], // Only numbers can be entered
                          ),
                        ),
                        Flexible(
                          child: widget.userExercise.unit == ""
                              ? Text(widget.userExercise.title + " per week don't count. Can't be negative.")
                              : Text(widget.userExercise.unit + " per week don't count. Can't be negative."),
                        ),
                      ],
                    ),
                    Text(""),
                    Text("Note (e.g. how to perform the exercise):"),
                    Container(
                        height: 90,
                        child: TextFormField(
                          autocorrect: true,
                          initialValue: _note,
                          // decoration: InputDecoration(labelText: 'Anzahl'),
                          focusNode: _noteFocusNode,
                          onSaved: (value) {
                            _note = value;
                          },
                          maxLines: 4,
                          keyboardType: TextInputType.multiline,
                        )),
                    Container(
                      width: MediaQuery.of(context).size.width * 0.4,
                      child: RaisedButton(
                        onPressed: _saveExercise,
                        color: Theme.of(context).accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          // side: BorderSide(color: Colors.red)
                        ),
                        child: Text(
                          "Save Changes",
                          style: TextStyle(color: Colors.white70),
                        ),
                        // Icon(
                        //   Icons.add_circle,
                        //   color: Colors.white70, //Theme.of(context).accentColor,
                        // ),
                      ),
                    ),
                    // note,
                  ],
                ),
              ),
          ]),
        ),
      ),
    );
    // ),
  }
}
