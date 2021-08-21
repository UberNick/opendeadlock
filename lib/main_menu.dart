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
          child: DefaultTextStyle(
        style: TextStyle(color: Colors.black),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Card(
                color: Colors.grey,
                child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Column(
                        children: [
                          Image.asset('assets/images/galliusiv.png'),
                        ],
                      ),
                      Column(children: [
                        Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(

                              children: [
                                ElevatedButton(
                                  onPressed: null,
                                  style: ElevatedButton.styleFrom(minimumSize: Size(125, 35)),
                                  child: Text("Quick Start"),
                                ),
                                SizedBox(height: 5),
                                ElevatedButton(
                                  onPressed: null,
                                  style: ElevatedButton.styleFrom(minimumSize: Size(125, 35)),
                                  child: Text("Tutorial"),
                                ),
                                SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: null,
                                  style: ElevatedButton.styleFrom(minimumSize: Size(125, 35)),
                                  child: const Text("New Game"),
                                ),
                                SizedBox(height: 5),
                                ElevatedButton(
                                  onPressed: null,
                                  style: ElevatedButton.styleFrom(minimumSize: Size(125, 35)),
                                  child: Text("Load Game"),
                                ),
                                SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(minimumSize: Size(125, 35)),
                                  child: Text("Developer Menu"),
                                ),
                              ],
                            ))
                      ])
                    ])))
          ],
        ),
      )),
    );
  }
}
