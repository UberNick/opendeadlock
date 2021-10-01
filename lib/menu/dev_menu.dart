import 'package:OpenDeadlock/menu/menu_title_bar.dart';
import 'package:flutter/material.dart';

class DevMenu extends StatelessWidget {
  DevMenu({Key? key, required this.title}) : super(key: key);
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
                    Column(children: [
                      Column(
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              print("foo");
                            },
                            style: ElevatedButton.styleFrom(
                                minimumSize: Size(125, 35)),
                            child: Text("Find Deadlock"),
                          ),
                          SizedBox(height: 5),
                          ElevatedButton(
                            onPressed: null,
                            style: ElevatedButton.styleFrom(
                                minimumSize: Size(125, 35)),
                            child: Text("Run Decoder"),
                          ),
                          SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: null,
                            style: ElevatedButton.styleFrom(
                                minimumSize: Size(125, 35)),
                            child: const Text("View Comic"),
                          ),
                          SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                                minimumSize: Size(125, 35)),
                            child: Text("Back"),
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
