import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../providers/challenge.dart' as challenge;
import '../providers/challenges.dart' as challenges;
import '../providers/challenge.dart';
import '../providers/user.dart';

import 'challenge_new.dart';

import '../widgets/app_drawer.dart';
import '../widgets/challenge_item.dart';

class ChallengesOverviewScreen extends StatefulWidget {
  static const routeName = '/challenge_overview';
  @override
  _ChallengesOverviewScreenState createState() => _ChallengesOverviewScreenState();
}

class _ChallengesOverviewScreenState extends State<ChallengesOverviewScreen> {
  var _isLoading = false;
  // RefreshController _refreshController = RefreshController(initialRefresh: false);

  Future<void> _onRefresh() async {
    // monitor network fetch
    print("Refreshing the challenges information");
    await Provider.of<challenges.Challenges>(context, listen: false).totalRefresh();
    // if failed,use refreshFailed()
    // _refreshController.refreshCompleted();
  }

  @override
  Widget build(BuildContext context) {
    print("building ChallengesOverviewScreen.");
    final challengesData = Provider.of<challenges.Challenges>(context);
    final List<challenge.Challenge> sortedChallenges = challengesData.allChallenges.values.toList();
    _isLoading = challengesData.loadingOnlineChallenges;

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
          : RefreshIndicator(
              onRefresh: _onRefresh,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Challenge newChallenge = Challenge.empty();
          Navigator.push(context, MaterialPageRoute(builder: (context) => CreateChallengeScreen(newChallenge)));
        },
        icon: Icon(Icons.add),
        label: Text("New Challenge"),
      ),
    );
  }
}
