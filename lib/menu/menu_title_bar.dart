import 'package:flutter/material.dart';

class MenuTitleBar extends StatelessWidget {
  MenuTitleBar({Key? key, required this.title}) : super(key: key);
  final String title;

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
                  Text(title),
                  SizedBox(height: 30, width: 220),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  SizedBox(width: 10),
                ]));

  }
}
