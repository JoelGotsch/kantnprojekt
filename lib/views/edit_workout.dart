import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kantnprojekt/providers/user.dart';
import 'package:provider/provider.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import 'package:flutter/services.dart'; // for FilteringTextInputFormatter
import 'package:dropdown_search/dropdown_search.dart'; // for dropdown of exerc.

import '../providers/workouts.dart' as wo;
import '../providers/exercises.dart' as ex;
import '../misc/functions.dart' as funcs;

class EditWorkoutScreen extends StatefulWidget {
  static const routeName = '/edit-workout';

  @override
  _EditWorkoutScreenState createState() => _EditWorkoutScreenState();
}

class _EditWorkoutScreenState extends State<EditWorkoutScreen> {
  final _noteFocusNode = FocusNode();
  final _numberFocusNode = FocusNode();
  final _form = GlobalKey<FormState>();
  final _formActions = GlobalKey<FormState>();
  wo.Workout _editedWorkout = wo.Workout.newWithUserId("");
  //TODO: Exercises as part of Workouts, created dynamically, no API needed.
  //this.exerciseId, this.workoutId, this.number, this.note, this.exercise:
  wo.Action _newAction = wo.Action("", "", 0, "", null);
  Map<String, ex.Exercise> _allExercises = {};
  ex.Exercise _chosenExercise;
  // var _initValues = {
  //   'date': DateTime.now(),
  //   'note': '',
  // };
  var _isInit = true;
  var _isLoading = false;

  @override
  void initState() {
    // _imageUrlFocusNode.addListener(_updateImageUrl);
    super.initState();
  }

  @override
  void didChangeDependencies() {
    if (_isInit) {
      final workoutId = ModalRoute.of(context).settings.arguments as String;
      print("workoutId in didChangeDeps: $workoutId");
      if (workoutId != null) {
        _editedWorkout = Provider.of<wo.Workouts>(context, listen: false)
            .byId(workoutId)
            .copy();
        print(_editedWorkout.localId);
        // _initValues = {
        //   'date': _editedWorkout.date,
        //   'note': _editedWorkout.note,
        // };
      }
      try {
        _allExercises =
            Provider.of<wo.Workouts>(context, listen: false).exercises;
      } catch (e) {
        print("Couldn't load exercises in edit-workouts. " + e.toString());
      }
    }
    _isInit = false;
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _noteFocusNode.dispose();
    _numberFocusNode.dispose();
    // _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    Provider.of<wo.Workouts>(context, listen: false).save();
    final isValid = _form.currentState.validate();
    if (!isValid) {
      return;
    }
    _form.currentState.save();
    setState(() {
      _isLoading = true;
    });
    try {
      _editedWorkout.userId = Provider.of<User>(context, listen: false).userId;
      Provider.of<wo.Workouts>(context, listen: false)
          .addWorkout(_editedWorkout);
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
    setState(() {
      _isLoading = false;
    });
    Navigator.of(context).pop();
    // Navigator.of(context).pop();
  }

  Future<void> _addAction() async {
    final isValid = _formActions.currentState.validate();
    if (!isValid || _chosenExercise != null || _newAction.number == 0) {
      return;
    }
    _newAction.exerciseId = _chosenExercise.exerciseId;
    _newAction.exercise = _chosenExercise;
    _formActions.currentState.save();
    setState(() {
      _isLoading = true;
    });
    try {
      _editedWorkout.addAction(_newAction);
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
    setState(() {
      _isLoading = false;
    });
    // Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Edit Workout'),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.save),
              onPressed: _saveForm,
            ),
          ],
        ),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(),
              )
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView(
                  children: <Widget>[
                    Container(
                      height: 150,
                      width: 1000,
                      child: Form(
                        key: _form,
                        child: Column(
                          children: <Widget>[
                            TextFormField(
                              initialValue: _editedWorkout.note,
                              decoration: InputDecoration(labelText: 'Notiz'),
                              maxLines: 3,
                              keyboardType: TextInputType.multiline,
                              focusNode: _noteFocusNode,
                              validator: (value) {
                                return null;
                              },
                              onSaved: (value) {
                                _editedWorkout.note = value;
                              },
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Text(DateFormat('EEE, dd-MM-yyyy hh:mm')
                                    .format(_editedWorkout.date)),
                                RaisedButton(
                                    onPressed: () {
                                      DatePicker.showDateTimePicker(context,
                                          currentTime: _editedWorkout.date,
                                          showTitleActions: true,
                                          minTime: DateTime(2018, 3, 5),
                                          maxTime: DateTime.now(),
                                          onChanged: (date) {},
                                          onConfirm: (date) {
                                        setState(() {
                                          _editedWorkout.setDate(date);
                                        });
                                      }, locale: LocaleType.de);
                                    },
                                    child: Text(
                                      'Set date',
                                      style: TextStyle(color: Colors.blue),
                                    )),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                    Container(
                      height: 60,
                      // width: 400,
                      child: Form(
                        key: _formActions,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>[
                            Container(
                              width: 50,
                              child: TextFormField(
                                autocorrect: false,
                                initialValue: "0",
                                decoration:
                                    InputDecoration(labelText: 'Anzahl'),
                                focusNode: _numberFocusNode,
                                validator: (value) {
                                  try {
                                    var val = int.parse(value);
                                  } catch (e) {
                                    return (e.toString());
                                  }
                                  return null;
                                },
                                onSaved: (value) {
                                  _newAction.number = int.parse(value);
                                },
                                keyboardType: TextInputType.number,
                                inputFormatters: <TextInputFormatter>[
                                  FilteringTextInputFormatter.digitsOnly
                                ], // Only numbers can be entered
                              ),
                            ),
                            Container(
                              width: 200,
                              child: DropdownSearch<ex.Exercise>(
                                  label: "Übung",
                                  items: _allExercises.values.toList(),
                                  itemAsString: (ex.Exercise exercise) =>
                                      exercise.title,
                                  onChanged: (ex.Exercise exercise) =>
                                      _chosenExercise = exercise),
                            ),
                            RaisedButton(
                              onPressed: _addAction,
                              child: Icon(Icons.add_circle),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                        height: 400,
                        child: ListView.builder(
                            itemCount: _editedWorkout.actions.length,
                            itemBuilder: (context, i) {
                              wo.Action action =
                                  _editedWorkout.actions.values.toList()[i];
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
                                  _editedWorkout.deleteAction(action.actionId);
                                },
                                child: Card(
                                  margin: EdgeInsets.all(5),
                                  child: Container(
                                    // height: 30,
                                    margin: EdgeInsets.all(10),
                                    child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: <Widget>[
                                          Text(
                                              "${action.number} ${action.exercise.unit} ${action.exercise.title}"),
                                          Text("${action.points} points")
                                        ]),

                                    alignment: Alignment.center,
                                  ),
                                  elevation: 5,
                                ),
                              ));
                            })),
                  ],
                ),
              ));
  }
}
