import 'package:OpenDeadlock/menu/menu_title_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:file_selector/file_selector.dart';

class DevMenu extends StatelessWidget {
  DevMenu({Key? key, required this.title}) : super(key: key);
  final String title;
  String? directory;

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
                          Row(
                            children: [
                              Column(
                                children: [
                                  Text("Platform: ")
                                ]
                              ),
                              SizedBox(width: 20),
                              Column(
                                children: [
                                  Text(getPlatformType())
                                ]
                              )
                            ]
                          ),
                          SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () {
                              pickDeadlockDirectory();
                            },
                            style: ElevatedButton.styleFrom(
                                minimumSize: Size(125, 35)),
                            child: Text("Find Deadlock"),
                          ),
                          SizedBox(height: 5),
                          Row(
                              children: [
                                Column(
                                    children: [
                                      Text("Directory: ")
                                    ]
                                ),
                                SizedBox(width: 20),
                                Column(
                                    children: [
                                      Text(directory ?? "(none)")
                                    ]
                                )
                              ]
                          ),
                          SizedBox(height: 20),
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

  String getPlatformType() {
    if (kIsWeb) {
      return "Web";
    } else if (Platform.isAndroid || Platform.isIOS) {
      return "Mobile";
    } else if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      return "Desktop";
    }
    return "Unknown";
  }

  void pickDeadlockDirectory() {
    getDirectoryPath(
      confirmButtonText: "Choose",
    ).then((value) {
      directory = value;
      // TODO refresh display
    });
  }
}
