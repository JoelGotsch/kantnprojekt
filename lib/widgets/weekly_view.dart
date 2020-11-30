import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
// import 'package:charts_flutter/flutter.dart' as charts;

import '../misc/workouts_overview.dart';

class WeeklySummary extends StatelessWidget {
  final WorkoutOverviews wovs;
  WeeklySummary(this.wovs);

  @override
  Widget build(BuildContext context) {
    final DateTime today = DateTime.now();
    final DateTime initFirstDay = today.add(Duration(days: -5, hours: today.hour, minutes: today.minute, seconds: today.second));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Container(
        height: ((MediaQuery.of(context).size.height - 82) * 0.27 - 35),
        child: Card(
          // child: Expanded(
          child: SfCartesianChart(
            primaryXAxis: DateTimeAxis(
              enableAutoIntervalOnZooming: true,
              visibleMinimum: initFirstDay,
              visibleMaximum: today,
              intervalType: DateTimeIntervalType.days,
              interval: 1,
              labelAlignment: LabelAlignment.center,
              // interactiveTooltip: InteractiveTooltip()
            ),
            series: <LineSeries<WorkoutOverview, DateTime>>[
              LineSeries<WorkoutOverview, DateTime>(
                width: 5,
                dataSource: wovs.lastNDays(14),
                xValueMapper: (wo, _) => wo.date,
                yValueMapper: (wo, _) => wo.points,
              )
            ],
            trackballBehavior: TrackballBehavior(
              enable: true,
              activationMode: ActivationMode.singleTap,
            ),
            zoomPanBehavior: ZoomPanBehavior(enablePanning: true),
            palette: [Theme.of(context).primaryColor],
            // animate: true,
            // dataLabelSettings: DataLabelSettings(isVisible: true),
            // domainAxis: charts.OrdinalAxisSpec(renderSpec: charts.SmallTickRendererSpec(labelRotation: 60)),
          ),
          // ),
        ),
      ),
      Container(
        height: 35,
        child: Column(
          children: [
            Text(wovs.pointsCurrWeek().toStringAsFixed(1) + " points this week"),
            Text(wovs.pointsLastNDays(7).toStringAsFixed(1) + " points last 7 days"),
          ],
        ),
      )
    ]);
  }
}

// class WeeklySummary extends StatelessWidget {
//   _getSeriesData(Map<String, wo.Workout> workouts) {
//     print("recalculating workout overview..");
//     WorkoutOverviews wovs = WorkoutOverviews.calc(workouts);
//     List<charts.Series<WorkoutOverview, String>> series = [
//       charts.Series(
//         id: "WorkoutsOverview",
//         data: wovs.lastNDays(14),
//         domainFn: (WorkoutOverview series, _) => series.weekDayAbbrev,
//         measureFn: (WorkoutOverview series, _) => series.points,
//         // colorFn: (WorkoutOverview series, _) => Theme.of(context).accentColor,
//       )
//     ];
//     return series;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final Map<String, wo.Workout> workouts = Provider.of<wos.Workouts>(context).workouts;
//     return Card(
//       // child: Expanded(
//         child: charts.BarChart(
//           _getSeriesData(workouts),
//           animate: true,
//           domainAxis: charts.OrdinalAxisSpec(renderSpec: charts.SmallTickRendererSpec(labelRotation: 60)),
//         ),
//       // ),
//     );
//   }
// }
