import 'package:flutter/material.dart';

class LegacyReferenceImage {
  const LegacyReferenceImage({
    required this.fileName,
    required this.title,
    required this.referenceUse,
    required this.dimensions,
  });

  final String fileName;
  final String title;
  final String referenceUse;
  final String dimensions;

  String get assetPath =>
      'docs/reference/legacy-screenshots/nick-2026-06-27/$fileName';
}

class LegacyReferenceScreen extends StatefulWidget {
  const LegacyReferenceScreen({Key? key}) : super(key: key);

  @override
  State<LegacyReferenceScreen> createState() => _LegacyReferenceScreenState();
}

class _LegacyReferenceScreenState extends State<LegacyReferenceScreen> {
  static const List<LegacyReferenceImage> references = <LegacyReferenceImage>[
    LegacyReferenceImage(
      fileName: 'Playing_Screen.png',
      title: 'Gameplay Screen',
      referenceUse: 'Gameplay map, command density, and side-panel layout',
      dimensions: '1024x768',
    ),
    LegacyReferenceImage(
      fileName: 'Playing_Full_Screen.png',
      title: 'Full Gameplay Screen',
      referenceUse: 'Full-screen planet view and HUD composition',
      dimensions: '1024x768',
    ),
    LegacyReferenceImage(
      fileName: 'Order_Screen.png',
      title: 'Order Screen',
      referenceUse: 'Turn orders, confirmation flow, and control grouping',
      dimensions: '1024x768',
    ),
    LegacyReferenceImage(
      fileName: 'Colony_Screen.png',
      title: 'Colony Screen',
      referenceUse: 'Colony management layout and resource presentation',
      dimensions: '1024x768',
    ),
    LegacyReferenceImage(
      fileName: 'Building_Screen.png',
      title: 'Building Screen',
      referenceUse: 'Construction choices and building detail layout',
      dimensions: '1024x768',
    ),
    LegacyReferenceImage(
      fileName: 'Race_Screen.png',
      title: 'Race Selection Screen',
      referenceUse: 'Race picker, portraits, and faction setup density',
      dimensions: '1024x768',
    ),
    LegacyReferenceImage(
      fileName: 'Options_Abilities.png',
      title: 'Abilities Options',
      referenceUse: 'Ability selection and option copy',
      dimensions: '639x359',
    ),
    LegacyReferenceImage(
      fileName: 'Options_Difficulty_Screen.png',
      title: 'Difficulty Screen',
      referenceUse: 'Difficulty selection and opponent setup',
      dimensions: '1024x768',
    ),
    LegacyReferenceImage(
      fileName: 'Planet_Screen.png',
      title: 'Planet Setup Screen',
      referenceUse: 'Planet setup flow and starting configuration',
      dimensions: '1024x768',
    ),
    LegacyReferenceImage(
      fileName: 'Planet_Type.png',
      title: 'Planet Type Detail',
      referenceUse: 'Planet selector controls and compact preview treatment',
      dimensions: '338x227',
    ),
    LegacyReferenceImage(
      fileName: 'Menu_Screen.png',
      title: 'Main Menu Screen',
      referenceUse: 'Landing navigation and menu proportions',
      dimensions: '1024x768',
    ),
    LegacyReferenceImage(
      fileName: 'Menu.png',
      title: 'Cropped Menu',
      referenceUse: 'Cropped main menu button styling and spacing',
      dimensions: '391x229',
    ),
    LegacyReferenceImage(
      fileName: 'Landing_Screen.png',
      title: 'Landing Screen',
      referenceUse: 'Opening presentation, title scale, and visual tone',
      dimensions: '1024x768',
    ),
    LegacyReferenceImage(
      fileName: 'Option_Screen.png',
      title: 'Options Screen',
      referenceUse: 'Full options layout and settings grouping',
      dimensions: '1024x768',
    ),
    LegacyReferenceImage(
      fileName: 'Options.png',
      title: 'Cropped Options',
      referenceUse: 'Compact option panel proportions and copy density',
      dimensions: '639x359',
    ),
    LegacyReferenceImage(
      fileName: 'Options_Difficulty.png',
      title: 'Cropped Difficulty Options',
      referenceUse: 'Difficulty selector scale and list treatment',
      dimensions: '545x225',
    ),
    LegacyReferenceImage(
      fileName: 'Inline_Screenshot_2026-06-27_18-00-48.png',
      title: 'Inline Menu Reference',
      referenceUse: 'Inline reference for menu flow and surrounding context',
      dimensions: '1706x1660',
    ),
    LegacyReferenceImage(
      fileName: 'Inline_Screenshot_2026-06-27_18-08-27.png',
      title: 'Inline Gameplay Reference',
      referenceUse: 'Inline reference for gameplay screen flow and context',
      dimensions: '1682x1770',
    ),
  ];

  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final selected = references[selectedIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF101418),
      appBar: AppBar(
        backgroundColor: const Color(0xFF182027),
        foregroundColor: const Color(0xFFF4F7FA),
        title: const Text('Legacy References'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final list = _ReferenceList(
            references: references,
            selectedIndex: selectedIndex,
            onSelected: (index) {
              setState(() {
                selectedIndex = index;
              });
            },
          );
          final preview = _ReferencePreview(reference: selected);

          if (compact) {
            return Column(
              children: [
                SizedBox(height: 260, child: list),
                Expanded(child: preview),
              ],
            );
          }

          return Row(
            children: [
              SizedBox(width: 320, child: list),
              Expanded(child: preview),
            ],
          );
        },
      ),
    );
  }
}

class _ReferenceList extends StatelessWidget {
  const _ReferenceList({
    Key? key,
    required this.references,
    required this.selectedIndex,
    required this.onSelected,
  }) : super(key: key);

  final List<LegacyReferenceImage> references;
  final int selectedIndex;
  final void Function(int index) onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF182027),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: references.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final reference = references[index];
          final selected = index == selectedIndex;
          return _ReferenceListTile(
            reference: reference,
            selected: selected,
            onTap: () => onSelected(index),
          );
        },
      ),
    );
  }
}

class _ReferenceListTile extends StatelessWidget {
  const _ReferenceListTile({
    Key? key,
    required this.reference,
    required this.selected,
    required this.onTap,
  }) : super(key: key);

  final LegacyReferenceImage reference;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF313B44) : const Color(0xFF202B34),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Icon(
                selected ? Icons.image_search : Icons.image_outlined,
                color: const Color(0xFFCCD6A6),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reference.title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFF4F7FA),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reference.dimensions,
                      style: const TextStyle(
                        color: Color(0xFFB9C5CE),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReferencePreview extends StatelessWidget {
  const _ReferencePreview({
    Key? key,
    required this.reference,
  }) : super(key: key);

  final LegacyReferenceImage reference;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          reference.title,
          style: const TextStyle(
            color: Color(0xFFF4F7FA),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _DetailRow(label: 'File', value: reference.fileName),
        _DetailRow(label: 'Use', value: reference.referenceUse),
        _DetailRow(label: 'Size', value: reference.dimensions),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            color: const Color(0xFF202B34),
            alignment: Alignment.center,
            child: Image.asset(
              reference.assetPath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'Reference image could not be loaded.',
                    style: TextStyle(color: Color(0xFFE9EEF2)),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 54,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9FB0BE),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFFE9EEF2)),
            ),
          ),
        ],
      ),
    );
  }
}
