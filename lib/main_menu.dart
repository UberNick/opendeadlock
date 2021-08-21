import 'package:flutter/material.dart';

class MainMenu extends StatefulWidget {
  MainMenu({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  _MainMenuState createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
       body: Center(
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Card(
               clipBehavior: Clip.antiAlias,
               color: Colors.grey,
               child:
               Padding(
                   padding: const EdgeInsets.all(16.0),
                   child: Row(
                       children: [
                         Column(
                             children: [
                               Image.asset('assets/images/galliusiv.png'),
                             ]
                         ),
                         Column(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Text("Quick Start"),
                             Text("Tutorial"),
                             Text("New Game"),
                             Text("Load Game"),
                             Text("Developer Menu"),
                           ]
                         ),
                       ]
                   )
               ),
             )
          ],
        ),
      ),
    );
  }
}