import 'package:flutter/material.dart';
import 'package:kantnprojekt/providers/user.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../providers/challenge.dart' as challenge;
import '../providers/challenges.dart' as challenges;
import '../providers/exercises.dart';

import '../widgets/app_drawer.dart';
import '../widgets/challenge_item.dart';

import '../misc/user_exercise.dart';

class ChallengesOverviewScreen extends StatefulWidget {
  static const routeName = '/challenge_overview';
  @override
  _ChallengesOverviewScreenState createState() => _ChallengesOverviewScreenState();
}

class _ChallengesOverviewScreenState extends State<ChallengesOverviewScreen> {
  var _isLoading = false;
  RefreshController _refreshController = RefreshController(initialRefresh: false);

  void _onRefresh() async {
    // monitor network fetch
    await Provider.of<challenges.Challenges>(context, listen: false).totalRefresh();
    // if failed,use refreshFailed()
    _refreshController.refreshCompleted();
  }

  @override
  Widget build(BuildContext context) {
    print("building ChallengesOverviewScreen.");
    final challengesData = Provider.of<challenges.Challenges>(context);
    final List<challenge.Challenge> sortedChallenges = challengesData.allChallenges.values.toList();
    _isLoading = challengesData.loadingOnlineChallenges || sortedChallenges.length == 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Challenges",
          style: TextStyle(color: Colors.white70),
        ),
      ),
      drawer: AppDrawer(),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : SmartRefresher(
              enablePullDown: true,
              enablePullUp: false,
              header: WaterDropMaterialHeader(
                // Configure the default header indicator. If you have the same header indicator for each page, you need to set this
                // semanticsLabel: "Test",
                // distance: 200,
                backgroundColor: Theme.of(context).accentColor,
                color: Theme.of(context).accentColor,
              ),
              controller: _refreshController,
              onRefresh: _onRefresh,
              child: ListView(children: <Widget>[
                Container(
                  height: (MediaQuery.of(context).size.height - 82 - 100) * 0.73,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(7.0),
                    itemCount: sortedChallenges.length,
                    itemBuilder: (ctx, i) => ChangeNotifierProvider.value(
                      value: sortedChallenges[i],
                      child: ChallengeItem(
                        key: ValueKey(sortedChallenges[i].challengeId),
                        challenge: sortedChallenges[i],
                        userId: Provider.of<User>(context).userId,
                      ),
                    ),
                  ),
                ),
              ]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: route to challenge_new.dart - screen

          // String userId = Provider.of<User>(context, listen: false).userId;
          // wo.Challenge newChallenge = wo.Challenge.newWithUserId(userId);
          // Provider.of<wos.Challenges>(context, listen: false).addChallenge(newChallenge);
          // setState(() {});
        },
        icon: Icon(Icons.add),
        label: Text("New Challenge"),
      ),
    );
  }
}
