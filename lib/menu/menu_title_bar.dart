import 'package:flutter/material.dart';

class MainMenuTitleBar extends StatefulWidget {
  MainMenuTitleBar({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  _MainMenuTitleBarState createState() => _MainMenuTitleBarState();
}

class _MainMenuTitleBarState extends State<MainMenuTitleBar> {
  @override
  Widget build(BuildContext context) {
    return
        Container(
            color: Colors.blueGrey,
            child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(width: 10),
                  Text("OpenDeadlock"),
                  SizedBox(height: 30, width: 250),
                  Text("X"),
                  SizedBox(width: 10),
                ]));

  }
}
