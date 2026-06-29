import 'package:OpenDeadlock/menu/menu_title_bar.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/game_codec.dart';
import '../game/game_saves.dart';
import '../gameplay/game_setup_screen.dart';
import '../gameplay/game_screen.dart';
import 'dev_menu.dart';

const String localReviewCommand =
    'flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8080';
const String localReviewUrl = 'http://127.0.0.1:8080/';

class MainMenu extends StatefulWidget {
  const MainMenu({
    Key? key,
    required this.title,
    this.joinFileReader,
  }) : super(key: key);

  final String title;
  final Future<String?> Function()? joinFileReader;

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.black),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Card(
                  color: Colors.grey,
                  child: Column(
                    children: [
                      MenuTitleBar(title: widget.title),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 20),
                          Column(
                            children: [
                              Image.asset('assets/images/galliusiv.png'),
                            ],
                          ),
                          const SizedBox(width: 20),
                          Column(
                            children: [
                              _MenuButton(
                                label: 'Continue',
                                onPressed: _continueLatestGame,
                              ),
                              const SizedBox(height: 5),
                              _MenuButton(
                                label: 'Quick Start',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => GameScreen(
                                        resumeLatestSave: false,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 5),
                              _MenuButton(
                                label: 'Join Game',
                                onPressed: _joinGameFromCode,
                              ),
                              const SizedBox(height: 10),
                              _MenuButton(
                                label: 'New Game',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const GameSetupScreen(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 5),
                              _MenuButton(
                                label: 'Load Game',
                                onPressed: _loadSavedGameFromMenu,
                              ),
                              const SizedBox(height: 10),
                              _MenuButton(
                                label: 'Developer Menu',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DevMenu(
                                        title: 'Developer Menu',
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 5),
                              _MenuButton(
                                label: 'Copy Review',
                                onPressed: _copyLocalReviewCommand,
                              ),
                              const SizedBox(height: 5),
                              _MenuButton(
                                label: 'Review Guide',
                                onPressed: _showLocalReviewGuide,
                              ),
                            ],
                          ),
                          const SizedBox(width: 20),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _joinGameFromCode() async {
    final source = await showDialog<String>(
      context: context,
      builder: (context) => _JoinGameDialog(
        onOpenFile: widget.joinFileReader ?? _readJoinGameFile,
      ),
    );
    if (source == null) {
      return;
    }
    if (source.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No invite or snapshot code was provided'),
        ),
      );
      return;
    }

    try {
      final game = GameCodec.decodeGameOrInvite(source);
      if (!mounted) {
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameScreen(
            initialGame: game,
            resumeLatestSave: false,
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not join game: $error')),
      );
    }
  }

  Future<void> _continueLatestGame() async {
    try {
      final store = await GameSaveStore.load();
      final game = await store.loadLatestGame();
      if (!mounted) {
        return;
      }
      if (game == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No local save found')),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameScreen(
            initialGame: game,
            resumeLatestSave: false,
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not continue local save: $error')),
      );
    }
  }

  Future<void> _copyLocalReviewCommand() async {
    await Clipboard.setData(
      const ClipboardData(text: localReviewCommand),
    );
    if (!mounted) {
      return;
    }
    _showMenuSnackBar('Copied local review command');
  }

  void _showLocalReviewGuide() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Local Review Guide'),
        content: const SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReviewGuideRow(
                label: 'URL',
                value: localReviewUrl,
              ),
              SizedBox(height: 10),
              _ReviewGuideRow(
                label: 'Command',
                value: localReviewCommand,
              ),
              SizedBox(height: 10),
              Text('First clicks'),
              SizedBox(height: 4),
              Text('Quick Start: playable map'),
              Text('New Game: setup and rules'),
              Text('Developer Menu: legacy screenshots'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: localReviewUrl),
              );
              Navigator.pop(context);
              _showMenuSnackBar('Copied local review URL');
            },
            child: const Text('Copy URL'),
          ),
          ElevatedButton(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: localReviewCommand),
              );
              Navigator.pop(context);
              _showMenuSnackBar('Copied local review command');
            },
            child: const Text('Copy Command'),
          ),
        ],
      ),
    );
  }

  void _showMenuSnackBar(String message) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _loadSavedGameFromMenu() async {
    try {
      final store = await GameSaveStore.load();
      final slots = await store.loadSlots();
      if (slots.isEmpty) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No local save found')),
        );
        return;
      }

      final slot = await _showLoadSlotDialog(store, slots);
      if (slot == null) {
        return;
      }
      final game = await store.loadGame(slot.slotId);
      if (!mounted) {
        return;
      }
      if (game == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Local save is missing')),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameScreen(
            initialGame: game,
            resumeLatestSave: false,
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load local save: $error')),
      );
    }
  }

  Future<SavedGameSlot?> _showLoadSlotDialog(
    GameSaveStore store,
    List<SavedGameSlot> initialSlots,
  ) async {
    return showDialog<SavedGameSlot>(
      context: context,
      builder: (context) {
        var slots = initialSlots;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF202B34),
              title: const Text(
                'Load Game',
                style: TextStyle(color: Color(0xFFF4F7FA)),
              ),
              contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              content: SizedBox(
                width: 440,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: slots.isEmpty
                      ? const Padding(
                          key: ValueKey<String>('load-save-empty'),
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'No local saves remain.',
                            style: TextStyle(color: Color(0xFFE9EEF2)),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: slots.length,
                          separatorBuilder: (_, __) => const Divider(
                            color: Color(0xFF313B44),
                            height: 1,
                          ),
                          itemBuilder: (context, index) {
                            final slot = slots[index];
                            return _MenuSaveSlotTile(
                              slot: slot,
                              onLoad: () => Navigator.pop(context, slot),
                              onDelete: () async {
                                await store.deleteSlot(slot.slotId);
                                final updatedSlots = await store.loadSlots();
                                if (!context.mounted) {
                                  return;
                                }
                                setDialogState(() {
                                  slots = updatedSlots;
                                });
                              },
                            );
                          },
                        ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ReviewGuideRow extends StatelessWidget {
  const _ReviewGuideRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        SelectableText(value),
      ],
    );
  }
}

const List<XTypeGroup> _joinGameFileTypes = <XTypeGroup>[
  XTypeGroup(
    label: 'OpenDeadlock invite or snapshot',
    extensions: <String>['odinvite', 'odsave', 'txt'],
    mimeTypes: <String>['text/plain'],
  ),
];

Future<String?> _readJoinGameFile() async {
  final file = await openFile(
    acceptedTypeGroups: _joinGameFileTypes,
    confirmButtonText: 'Open Game',
  );
  if (file == null) {
    return null;
  }
  return file.readAsString();
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    Key? key,
    required this.label,
    required this.onPressed,
  }) : super(key: key);

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(minimumSize: const Size(125, 35)),
      child: Text(label),
    );
  }
}

class _JoinGameDialog extends StatefulWidget {
  const _JoinGameDialog({
    Key? key,
    required this.onOpenFile,
  }) : super(key: key);

  final Future<String?> Function() onOpenFile;

  @override
  State<_JoinGameDialog> createState() => _JoinGameDialogState();
}

class _JoinGameDialogState extends State<_JoinGameDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF202B34),
      title: const Text(
        'Join Game',
        style: TextStyle(color: Color(0xFFF4F7FA)),
      ),
      content: SizedBox(
        width: 440,
        child: TextField(
          controller: controller,
          minLines: 4,
          maxLines: 7,
          style: const TextStyle(color: Color(0xFFF4F7FA), fontSize: 12),
          decoration: const InputDecoration(
            labelText: 'Invite or Snapshot Code',
            labelStyle: TextStyle(color: Color(0xFFB9C5CE)),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF5C6A73)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFCCD6A6)),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton.icon(
          key: const ValueKey<String>('join-game-paste-code'),
          icon: const Icon(Icons.content_paste),
          label: const Text('Paste'),
          onPressed: _pasteClipboardCode,
        ),
        TextButton.icon(
          key: const ValueKey<String>('join-game-open-file'),
          icon: const Icon(Icons.folder_open),
          label: const Text('Open File'),
          onPressed: () async {
            final text = await widget.onOpenFile();
            if (!mounted) {
              return;
            }
            if (text == null) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No invite or snapshot file selected'),
                ),
              );
              return;
            }
            Navigator.pop(context, text);
          },
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.login),
          label: const Text('Join'),
          onPressed: () => Navigator.pop(context, controller.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFCCD6A6),
            foregroundColor: const Color(0xFF111418),
          ),
        ),
      ],
    );
  }

  Future<void> _pasteClipboardCode() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboardData?.text?.trim();
    if (text == null || text.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard has no invite or snapshot')),
      );
      return;
    }
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _MenuSaveSlotTile extends StatelessWidget {
  const _MenuSaveSlotTile({
    Key? key,
    required this.slot,
    required this.onLoad,
    required this.onDelete,
  }) : super(key: key);

  final SavedGameSlot slot;
  final VoidCallback onLoad;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final isAutosave = slot.slotId == GameSaveStore.autosaveSlotId;

    return ListTile(
      key: ValueKey<String>('load-save-slot-${slot.slotId}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Icon(
        isAutosave ? Icons.history : Icons.save,
        color: const Color(0xFFCCD6A6),
      ),
      title: Text(
        slot.name,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFF4F7FA),
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        'Turn ${slot.turn} | ${slot.activeFactionName} | '
        '${slot.commandCount} cmd | ${_formatSaveSlotTime(slot.updatedAtIso8601)}',
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xFFB9C5CE), fontSize: 12),
      ),
      onTap: onLoad,
      trailing: IconButton(
        key: ValueKey<String>('delete-save-slot-${slot.slotId}'),
        tooltip: 'Delete Save',
        icon: const Icon(Icons.delete_outline),
        color: const Color(0xFFE9A6A6),
        onPressed: () {
          onDelete();
        },
      ),
    );
  }
}

String _formatSaveSlotTime(String iso8601) {
  final parsed = DateTime.tryParse(iso8601);
  if (parsed == null) {
    return iso8601;
  }
  final local = parsed.toLocal();
  return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)} '
      '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}
