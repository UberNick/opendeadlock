import 'package:flutter/material.dart';
import 'main_menu.dart';

void main() {
  runApp(OpenDeadlock());
}

class OpenDeadlock extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenDeadlock',
      theme: ThemeData(
        primarySwatch: Colors.grey,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: MainMenu(title: 'OpenDeadlock'),
    );
  }
}
