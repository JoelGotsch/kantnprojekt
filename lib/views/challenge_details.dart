import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/challenge.dart';
import '../providers/challenges.dart';
import '../providers/user.dart';

import '../widgets/app_drawer.dart';

class ChallengeDetailScreen extends StatefulWidget {
  // static const routeName = '/challenge';
  final Challenge challenge;

  ChallengeDetailScreen(this.challenge);

  @override
  _ChallengeDetailScreenState createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  var _isLoading = false;

  @override
  Widget build(BuildContext context) {
    String userId = Provider.of<User>(context, listen: false).userId;

    print("building ChallengeDetailScreen.");

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Challenge " + widget.challenge.name,
          style: TextStyle(color: Colors.white70),
        ),
      ),
      drawer: AppDrawer(),
      body: ListView(children: <Widget>[
        Container(
          height: (MediaQuery.of(context).size.height - 82) * 0.27,
          child: widget.challenge.columnCharts(),
        ),
        Container(
            height: (MediaQuery.of(context).size.height - 82) * 0.73 - 70,
            width: MediaQuery.of(context).size.width * 0.99,
            padding: EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Flexible(
                  child: Text(
                      "The challenge starts on ${DateFormat("EEE, d MMM yyyy").format(widget.challenge.startDate)} and ends on ${DateFormat("EEE, d MMM yyyy").format(widget.challenge.endDate)}"),
                ),
                Flexible(child: Text("You need to reach ${widget.challenge.minPoints} points every ${widget.challenge.evalPeriod}.")),
                SizedBox(height: 10),
                Text("Description:"),
                Flexible(child: Text(widget.challenge.description)),
                SizedBox(height: 10),
                Text("Exercises:"),
                Container(
                  height: (MediaQuery.of(context).size.height - 82) * 0.73 - 240,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(7.0),
                    itemCount: widget.challenge.exercises.length,
                    itemBuilder: (ctx, i) => Card(
                      margin: EdgeInsets.all(5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
                          Text("${widget.challenge.exercises.values.toList()[i].title}"),
                          widget.challenge.exercises.values.toList()[i].unit == ""
                              ? Text("${widget.challenge.exercises.values.toList()[i].points} points per exercise")
                              : Text("${widget.challenge.exercises.values.toList()[i].points} points per ${widget.challenge.exercises.values.toList()[i].unit}")
                        ]),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            widget.challenge.exercises.values.toList()[i].dailyAllowance == 0
                                ? Container()
                                : Text(
                                    "${widget.challenge.exercises.values.toList()[i].dailyAllowance} ${widget.challenge.exercises.values.toList()[i].unit} per day is/are not counted."),
                            widget.challenge.exercises.values.toList()[i].weeklyAllowance == 0
                                ? Container()
                                : Text(
                                    "${widget.challenge.exercises.values.toList()[i].weeklyAllowance} ${widget.challenge.exercises.values.toList()[i].unit} per week is/are not counted."),
                            widget.challenge.exercises.values.toList()[i].maxPointsDay == 0
                                ? Container()
                                : Text("Maximum of ${widget.challenge.exercises.values.toList()[i].maxPointsDay} points per day with this exercise"),
                            widget.challenge.exercises.values.toList()[i].maxPointsWeek == 0
                                ? Container()
                                : Text("Maximum of ${widget.challenge.exercises.values.toList()[i].maxPointsWeek} points per week with this exercise"),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )),
      ]),
      floatingActionButton: widget.challenge.hasUser(userId)
          ? Container() // TODO: unfollow challenge!
          : FloatingActionButton.extended(
              onPressed: () async {
                String userId = Provider.of<User>(context, listen: false).userId;
                _isLoading = true;
                setState(() {});
                await Provider.of<Challenges>(context, listen: false).joinChallenge(widget.challenge, userId);
                _isLoading = false;
                setState(() {});
              },
              icon: _isLoading ? CircularProgressIndicator() : Icon(Icons.add),
              label: _isLoading ? CircularProgressIndicator() : Text("Join challenge"),
            ),
    );
  }
}
