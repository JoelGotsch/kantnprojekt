import 'dart:math';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';

import '../providers/workout.dart' as wo;
import '../providers/workouts.dart' as wos;
import '../providers/exercises.dart' as ex;
import '../misc/decimalInputFormatter.dart';
// import '../views/edit_workout.dart';

class WorkoutItem extends StatefulWidget {
  const WorkoutItem({
    @required Key key,
  }) : super(key: key);

  @override
  _WorkoutItemState createState() => _WorkoutItemState();
}

class _WorkoutItemState extends State<WorkoutItem> {
  var _expanded = false;
  var _isInit = true;
  final _noteFocusNode = FocusNode();
  final _numberFocusNode = FocusNode();
  // final _form = GlobalKey<FormState>(); // Used for note?
  final _formActions = GlobalKey<FormState>();
  wo.Workout workout;
  wo.Action _newAction = wo.Action("", "", 0, "", null);
  Map<String, ex.Exercise> _allExercises = {};
  ex.Exercise _chosenExercise;

  @override
  void didChangeDependencies() {
    // _editedWorkout = Provider.of<wo.Workout>(context, listen: false);
    if (_isInit) {
      workout = Provider.of<wo.Workout>(context, listen: false);
      // final workoutId = ModalRoute.of(context).settings.arguments as String;
      // print("workoutId in didChangeDeps: $workoutId");
      // if (workoutId != null) {
      //   // _editedWorkout = Provider.of<wos.Workouts>(context, listen: false)
      //   //     .byId(workoutId)
      //   //     .copy();
      //   print(_editedWorkout.localId);
      //   // _initValues = {
      //   //   'date': _editedWorkout.date,
      //   //   'note': _editedWorkout.note,
      //   // };
      // }
      try {
        _allExercises = Provider.of<wos.Workouts>(context, listen: false).exercises;
      } catch (e) {
        print("Couldn't load exercises in edit-workouts. " + e.toString());
      }
    }
    _isInit = false;
    // if (min(_editedWorkout.actions.length * 50.0 + 250, 900) != totalHeight) {
    //   setState(() {
    //     totalHeight = min(_editedWorkout.actions.length * 50.0 + 250, 900);
    //   });
    // }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _noteFocusNode.dispose();
    _numberFocusNode.dispose();
    // _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _addAction() async {
    final isValid = _formActions.currentState.validate();
    _formActions.currentState.save();
    if (!isValid || _chosenExercise == null || _newAction.number == 0) {
      return;
    }
    _newAction.exerciseId = _chosenExercise.exerciseId;
    _newAction.exercise = _chosenExercise;
    _newAction.workoutId = Provider.of<wo.Workout>(context, listen: false).localId;
    try {
      Provider.of<wos.Workouts>(context, listen: false).addAction(_newAction);
      // workout.addAction(_newAction);
      _newAction = wo.Action("", "", 0, "", null);
      _chosenExercise = null;
    } catch (error) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('An error occurred!'),
          content: Text('Something went wrong.'),
          actions: <Widget>[
            FlatButton(
              child: Text('Okay'),
              onPressed: () {
                Navigator.of(ctx).pop();
              },
            )
          ],
        ),
      );
    }
    // Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    workout = Provider.of<wo.Workout>(context);
    final double totalHeight = min(workout.actions.length * 45.0 + 100, 900);
    return Card(
      margin: EdgeInsets.all(5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Dismissible(
        key: ValueKey(workout.localId),
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
          Provider.of<wos.Workouts>(context, listen: false).deleteWorkout(workout.localId);
        },
        child: Column(children: <Widget>[
          GestureDetector(
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            child: ListTile(
              title: Text('${workout.points} points'),
              subtitle: GestureDetector(
                child: Container(
                  // color: Theme.of(context).accentColor,
                  padding: EdgeInsets.all(10),
                  child: Row(
                    children: <Widget>[
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
                        DateFormat('EEE, dd-MM-yyyy HH:mm').format(workout.date),
                      ),
                    ],
                  ),
                ),
                onTap: () {
                  DatePicker.showDateTimePicker(context,
                      currentTime: workout.date,
                      showTitleActions: true,
                      minTime: DateTime(2020, 1, 1),
                      maxTime: DateTime.now(),
                      onChanged: (date) {}, onConfirm: (date) {
                    setState(() {
                      workout.setDate(date);
                    });
                  }, locale: LocaleType.de);
                },
              ),
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
          if (_expanded)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 5, vertical: 0),
              height: totalHeight,
              child: Column(
                children: <Widget>[
                  Form(
                    key: _formActions,
                    child: Container(
                      height: 40,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Container(
                            width: MediaQuery.of(context).size.width * 0.3,
                            child: DropdownSearch<ex.Exercise>(
                                label: "Exercise",
                                showSearchBox: true,
                                // showSelectedItem: true,
                                selectedItem: _chosenExercise != null ? _chosenExercise : null,
                                items: _allExercises.values.toList(),
                                itemAsString: (ex.Exercise exercise) => exercise.title,
                                onChanged: (ex.Exercise exercise) {
                                  setState(() {
                                    _chosenExercise = exercise;
                                  });
                                }),
                          ),
                          Container(
                            width: MediaQuery.of(context).size.width * 0.2,
                            child: TextFormField(
                              autocorrect: false,
                              initialValue: "0",
                              // decoration: InputDecoration(labelText: 'Anzahl'),
                              focusNode: _numberFocusNode,
                              validator: (value) {
                                try {
                                  var val = double.parse(value);
                                } catch (e) {
                                  return (e.toString());
                                }
                                return null;
                              },
                              onSaved: (value) {
                                _newAction.number = double.parse(value);
                              },
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [DecimalTextInputFormatter(decimalRange: 2)], // Only numbers can be entered
                            ),
                          ),
                          Container(
                            width: MediaQuery.of(context).size.width * 0.1,
                            child: Text(_chosenExercise == null ? "" : _chosenExercise.unit),
                          ),
                          Container(
                            width: MediaQuery.of(context).size.width * 0.2,
                            child: RaisedButton(
                              onPressed: _addAction,
                              color: Theme.of(context).accentColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                // side: BorderSide(color: Colors.red)
                              ),
                              child: Icon(
                                Icons.add_circle,
                                color: Colors.white70, //Theme.of(context).accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    height: totalHeight - 100,
                    child: ListView.builder(
                        itemCount: workout.actions.length,
                        itemBuilder: (context, i) {
                          wo.Action action = workout.actions.values.toList()[i];
                          return (Dismissible(
                            key: ValueKey(action.actionId),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: EdgeInsets.only(right: 20),
                              color: Theme.of(context).errorColor,
                              child: Icon(
                                Icons.delete,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            onDismissed: (direction) {
                              Provider.of<wos.Workouts>(context, listen: false).deleteAction(action);
                            },
                            child: Card(
                              margin: EdgeInsets.all(5),
                              child: Container(
                                // height: 30,
                                margin: EdgeInsets.all(10),
                                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
                                  Text("${action.number} ${action.exercise.unit} ${action.exercise.title}"),
                                  Text("${action.points} points")
                                ]),

                                alignment: Alignment.center,
                              ),
                              elevation: 5,
                            ),
                          ));
                        }),
                  )
                ],
              ),
            ),
        ]),
      ),
      // ),
    );
  }
}
