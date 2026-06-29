import 'package:flutter/material.dart';

class ComicPanel {
  const ComicPanel({
    required this.title,
    required this.caption,
    required this.detail,
    required this.icon,
  });

  final String title;
  final String caption;
  final String detail;
  final IconData icon;
}

class ComicViewerScreen extends StatefulWidget {
  const ComicViewerScreen({Key? key}) : super(key: key);

  @override
  State<ComicViewerScreen> createState() => _ComicViewerScreenState();
}

class _ComicViewerScreenState extends State<ComicViewerScreen> {
  static const List<ComicPanel> panels = <ComicPanel>[
    ComicPanel(
      title: 'A New World',
      caption: 'The colony ships descend over Gallius IV.',
      detail:
          'Each faction arrives with a fragile settlement, old rivalries, and a claim on the same hostile planet.',
      icon: Icons.public,
    ),
    ComicPanel(
      title: 'First Orders',
      caption: 'Scouts fan out while factories wake from cold storage.',
      detail:
          'Early choices decide whether the frontier becomes a research network, a trade compact, or a fortified march.',
      icon: Icons.explore,
    ),
    ComicPanel(
      title: 'Planetary Conquest',
      caption: 'Treaties, sabotage, science, and armor shape the endgame.',
      detail:
          'Victory can come through conquest, ancient discoveries, or the strongest score when the council closes the campaign.',
      icon: Icons.military_tech,
    ),
  ];

  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final panel = panels[selectedIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF101418),
      appBar: AppBar(
        backgroundColor: const Color(0xFF182027),
        foregroundColor: const Color(0xFFF4F7FA),
        title: const Text('Opening Comic'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final art = _ComicArt(panel: panel);
          final controls = _ComicControls(
            panels: panels,
            selectedIndex: selectedIndex,
            onSelected: (index) {
              setState(() {
                selectedIndex = index;
              });
            },
            onPrevious: selectedIndex == 0
                ? null
                : () {
                    setState(() {
                      selectedIndex -= 1;
                    });
                  },
            onNext: selectedIndex == panels.length - 1
                ? null
                : () {
                    setState(() {
                      selectedIndex += 1;
                    });
                  },
          );

          if (compact) {
            return Column(
              children: [
                Expanded(child: art),
                controls,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: art),
              SizedBox(width: 340, child: controls),
            ],
          );
        },
      ),
    );
  }
}

class _ComicArt extends StatelessWidget {
  const _ComicArt({
    Key? key,
    required this.panel,
  }) : super(key: key);

  final ComicPanel panel;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF101418),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    'assets/images/galliusiv.png',
                    fit: BoxFit.cover,
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x66101418),
                        Color(0xCC101418),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(panel.icon,
                            color: const Color(0xFFD9B66F), size: 34),
                        const SizedBox(height: 8),
                        Text(
                          panel.title,
                          style: const TextStyle(
                            color: Color(0xFFFFF5D6),
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          panel.caption,
                          style: const TextStyle(
                            color: Color(0xFFF4F7FA),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            panel.detail,
            style: const TextStyle(
              color: Color(0xFFE9EEF2),
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComicControls extends StatelessWidget {
  const _ComicControls({
    Key? key,
    required this.panels,
    required this.selectedIndex,
    required this.onSelected,
    required this.onPrevious,
    required this.onNext,
  }) : super(key: key);

  final List<ComicPanel> panels;
  final int selectedIndex;
  final void Function(int index) onSelected;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF182027),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Storyboard',
            style: TextStyle(
              color: Color(0xFFF4F7FA),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ...panels.asMap().entries.map(
            (entry) {
              final selected = entry.key == selectedIndex;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton.icon(
                  icon: Icon(entry.value.icon, size: 18),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(entry.value.title),
                  ),
                  onPressed: () => onSelected(entry.key),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    foregroundColor: selected
                        ? const Color(0xFF111418)
                        : const Color(0xFFE9EEF2),
                    backgroundColor: selected ? const Color(0xFFCCD6A6) : null,
                    side: BorderSide(
                      color: selected
                          ? const Color(0xFFCCD6A6)
                          : const Color(0xFF55616C),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Previous'),
                  onPressed: onPrevious,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE9EEF2),
                    side: const BorderSide(color: Color(0xFF55616C)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Next'),
                  onPressed: onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCCD6A6),
                    foregroundColor: const Color(0xFF111418),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
