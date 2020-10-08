
import 'repository.dart';
import "data_classes.dart";
import 'package:rxdart/rxdart.dart';
// import 'package:kantnprojekt/resources/user_data_model.dart';

class UserBloc {
  final _repository = Repository();
  final _userGetter = PublishSubject<BackendUser>();

  Observable<BackendUser> get getUser => _userGetter.stream;

  registerUser(String username, String firstname, String lastname, String password, String email) async {
    BackendUser user = await _repository.registerUser(username, firstname, lastname, password, email);
    _userGetter.sink.add(user);
  }

  signinUser(String username, String password, String apiKey) async {
    BackendUser user = await _repository.signinUser(username, password, apiKey);
    _userGetter.sink.add(user);
  }

  dispose() {
    _userGetter.close();
  }
}

class WorkoutBloc {
  final _repository = Repository();
  final _workoutSubject = BehaviorSubject<List<Workout>>();
  String apiKey;
  DateTime startDate=DateTime.now();
  DateTime endDate=DateTime.now();

  var _workouts = <Workout>[];

  WorkoutBloc(String api_key) {
    this.apiKey = api_key;
    _updateWorkouts(api_key).then((_) {
      _workoutSubject.add(_workouts);
    });
  }


  Stream<List<Workout>> get getWorkouts => _workoutSubject.stream;

  Future<Null> _updateWorkouts(String apiKey) async {
    startDate=startDate.subtract(new Duration(days:7));
    _workouts = await _repository.getWorkouts(apiKey, startDate, endDate);
  }

}
final userBloc = UserBloc();