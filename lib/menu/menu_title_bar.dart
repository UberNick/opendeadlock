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
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold),),
                  SizedBox(height: 30, width: 240),
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
