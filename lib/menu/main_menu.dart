import 'package:OpenDeadlock/menu/menu_title_bar.dart';
import 'package:flutter/material.dart';

import 'dev_menu.dart';

class MainMenu extends StatelessWidget {
  MainMenu({Key? key, required this.title}) : super(key: key);
  final String title;

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
                child: Column(children: [
                  MenuTitleBar(title: title),
                  SizedBox(height: 20),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 20),
                    Column(
                      children: [
                        Image.asset('assets/images/galliusiv.png'),
                      ],
                    ),
                    SizedBox(width: 20),
                    Column(children: [
                      Column(
                        children: [
                          ElevatedButton(
                            onPressed: null,
                            style: ElevatedButton.styleFrom(
                                minimumSize: Size(125, 35)),
                            child: Text("Quick Start"),
                          ),
                          SizedBox(height: 5),
                          ElevatedButton(
                            onPressed: null,
                            style: ElevatedButton.styleFrom(
                                minimumSize: Size(125, 35)),
                            child: Text("Tutorial"),
                          ),
                          SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: null,
                            style: ElevatedButton.styleFrom(
                                minimumSize: Size(125, 35)),
                            child: const Text("New Game"),
                          ),
                          SizedBox(height: 5),
                          ElevatedButton(
                            onPressed: null,
                            style: ElevatedButton.styleFrom(
                                minimumSize: Size(125, 35)),
                            child: Text("Load Game"),
                          ),
                          SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => DevMenu(title: "Developer Menu")),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                                minimumSize: Size(125, 35)),
                            child: Text("Developer Menu"),
                          ),
                        ],
                      ),
                    ]),
                    SizedBox(width: 20),
                  ]),
                  SizedBox(height: 20),
                ]))
          ],
        ),
      )),
    );
  }
}
