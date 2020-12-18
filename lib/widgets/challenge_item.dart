import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../providers/challenge.dart' as ch;
// import '../views/edit_challenge.dart';

class ChallengeItem extends StatefulWidget {
  final ch.Challenge challenge;
  final String userId;

  const ChallengeItem({
    @required Key key,
    @required this.challenge,
    @required this.userId,
  }) : super(key: key);

  @override
  _ChallengeItemState createState() => _ChallengeItemState();
}

class _ChallengeItemState extends State<ChallengeItem> {
  var _expanded = false;
  ch.Challenge challenge;

  @override
  Widget build(BuildContext context) {
    // challenge = Provider.of<wo.Challenge>(context);
    challenge = widget.challenge;
    // _newAction.challengeId = challenge.localId;

    return Card(
      margin: EdgeInsets.all(5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(children: <Widget>[
        GestureDetector(
          onTap: () {
            // TODO: Route to challenge-view
          },
          child: ListTile(
            title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
              Text('  ${challenge.name}'),
              Text('${challenge.users.length} participants.')

              // Icon(
              //   widget.challenge.uploaded ? Icons.backup : Icons.autorenew,
              //   color: Theme.of(context).accentColor,
              // ),
            ]),
            trailing: challenge.users.containsKey(widget.userId) ? Text(" participating") : Text(" not participating"),
            subtitle: Container(
              // color: Theme.of(context).accentColor,
              padding: EdgeInsets.all(10),
              child: Row(
                children: <Widget>[Text("${challenge.minPoints} points per ${challenge.evalPeriod}"), Text("${challenge.exercises.length} exercises")],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
