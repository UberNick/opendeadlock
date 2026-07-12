import 'package:OpenDeadlock/menu/menu_title_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:file_selector/file_selector.dart';

import 'comic_viewer_screen.dart';
import 'legacy_reference_screen.dart';

class DevMenu extends StatefulWidget {
  DevMenu({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<DevMenu> createState() => _DevMenuState();
}

class _DevMenuState extends State<DevMenu> {
  static const String decoderSourcePath = "tools/src/decoder";
  static const String decoderBuildCommand =
      "cmake -S tools/src/decoder -B build/decoder && cmake --build build/decoder";
  static const String decodedAssetOutputPath = "build/decoded-assets";
  String? directory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: DefaultTextStyle(
              style: TextStyle(color: Colors.black),
              child: Card(
                color: Colors.grey,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MenuTitleBar(title: widget.title),
                      SizedBox(height: 20),
                      Row(children: [
                        Column(children: [Text("Platform: ")]),
                        SizedBox(width: 20),
                        Column(children: [Text(getPlatformType())])
                      ]),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: pickDeadlockDirectory,
                        style: ElevatedButton.styleFrom(
                            minimumSize: Size(125, 35)),
                        child: Text("Find Deadlock"),
                      ),
                      SizedBox(height: 5),
                      Row(children: [
                        Column(children: [Text("Directory: ")]),
                        SizedBox(width: 20),
                        Flexible(child: Text(directory ?? "(none)"))
                      ]),
                      SizedBox(height: 20),
                      _DecoderToolCard(
                        directory: directory,
                        onOpenGuide: openDecoderGuide,
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: openLegacyReferences,
                        style: ElevatedButton.styleFrom(
                            minimumSize: Size(125, 35)),
                        child: const Text("Legacy References"),
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: openComicViewer,
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String getPlatformType() {
    if (kIsWeb) {
      return "Web";
    } else if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return "Mobile";
    } else if (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows) {
      return "Desktop";
    }
    return "Unknown";
  }

  void pickDeadlockDirectory() {
    getDirectoryPath(
      confirmButtonText: "Choose",
    ).then((value) {
      setState(() {
        directory = value;
      });
    });
  }

  void openDecoderGuide() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Decoder Handoff"),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DecoderGuideRow(
                label: "Selected game",
                value: directory ?? "Choose the original Deadlock folder first",
              ),
              const _DecoderGuideRow(
                label: "Decoder source",
                value: decoderSourcePath,
              ),
              const _DecoderGuideRow(
                label: "Build command",
                value: decoderBuildCommand,
              ),
              const _DecoderGuideRow(
                label: "Decoded output",
                value: decodedAssetOutputPath,
              ),
              const SizedBox(height: 8),
              const Text(
                "Run the command from the repository root, then compare decoded art against Legacy References before promoting assets into the Flutter app.",
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void openLegacyReferences() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LegacyReferenceScreen(),
      ),
    );
  }

  void openComicViewer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ComicViewerScreen(),
      ),
    );
  }
}

class _DecoderToolCard extends StatelessWidget {
  const _DecoderToolCard({
    Key? key,
    required this.directory,
    required this.onOpenGuide,
  }) : super(key: key);

  final String? directory;
  final VoidCallback onOpenGuide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Decoder Tools",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          _DecoderGuideRow(
            label: "Game folder",
            value: directory ?? "Not selected",
          ),
          const _DecoderGuideRow(
            label: "Tool source",
            value: _DevMenuState.decoderSourcePath,
          ),
          const _DecoderGuideRow(
            label: "Output target",
            value: _DevMenuState.decodedAssetOutputPath,
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onOpenGuide,
            style: ElevatedButton.styleFrom(minimumSize: const Size(125, 35)),
            child: const Text("Decoder Guide"),
          ),
        ],
      ),
    );
  }
}

class _DecoderGuideRow extends StatelessWidget {
  const _DecoderGuideRow({
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
