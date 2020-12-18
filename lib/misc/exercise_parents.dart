abstract class ExerciseParent {
  String localId;
  double points;
  double maxPointsDay;
  double maxPointsWeek;
  double dailyAllowance;
  double weeklyAllowance; //deducted from number
}

abstract class ExerciseParents {
  Map<String, ExerciseParent> exercises = {};

  ExerciseParent getExercise(exerciseId) {
    return (exercises[exerciseId]);
  }
}
