import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/game_codec.dart';
import '../game/game_saves.dart';
import '../game/game_state.dart';

typedef TextFileWriter = Future<void> Function({
  required String path,
  required String content,
  required String fileName,
});

typedef TextFileReader = Future<String?> Function();

const List<XTypeGroup> _orderPackageFileTypes = <XTypeGroup>[
  XTypeGroup(
    label: 'OpenDeadlock order package',
    extensions: <String>['odorders', 'txt'],
    mimeTypes: <String>['text/plain'],
  ),
];

const List<XTypeGroup> _inviteFileTypes = <XTypeGroup>[
  XTypeGroup(
    label: 'OpenDeadlock invite',
    extensions: <String>['odinvite', 'txt'],
    mimeTypes: <String>['text/plain'],
  ),
];

const List<XTypeGroup> _snapshotFileTypes = <XTypeGroup>[
  XTypeGroup(
    label: 'OpenDeadlock snapshot',
    extensions: <String>['odsave', 'txt'],
    mimeTypes: <String>['text/plain'],
  ),
];

const String _soundEffectsPreferenceKey = 'opendeadlock.sound_effects_enabled';
const double _minimumMapZoomScale = 1.0;
const double _maximumMapZoomScale = 3.0;
const double _mapZoomStep = 0.5;
const int _mapZoomDivisions = 20;

Future<void> _writeTextFile({
  required String path,
  required String content,
  required String fileName,
}) async {
  final file = XFile.fromData(
    Uint8List.fromList(utf8.encode(content)),
    mimeType: 'text/plain',
    name: fileName,
  );
  await file.saveTo(path);
}

Future<String?> _readTextFile() async {
  final file = await openFile(
    acceptedTypeGroups: _orderPackageFileTypes,
    confirmButtonText: 'Open Orders',
  );
  if (file == null) {
    return null;
  }
  return file.readAsString();
}

Future<String?> _readSnapshotFile() async {
  final file = await openFile(
    acceptedTypeGroups: _snapshotFileTypes,
    confirmButtonText: 'Open Snapshot',
  );
  if (file == null) {
    return null;
  }
  return file.readAsString();
}

Future<String?> _readInviteFile() async {
  final file = await openFile(
    acceptedTypeGroups: _inviteFileTypes,
    confirmButtonText: 'Open Invite',
  );
  if (file == null) {
    return null;
  }
  return file.readAsString();
}

class GameScreen extends StatefulWidget {
  GameScreen({
    Key? key,
    OpenDeadlockGame? initialGame,
    this.resumeLatestSave = true,
    TextFileWriter? textFileWriter,
    TextFileReader? textFileReader,
    TextFileReader? snapshotFileReader,
    TextFileReader? inviteFileReader,
  })  : initialGame = initialGame ?? OpenDeadlockGame.sample(),
        textFileWriter = textFileWriter ?? _writeTextFile,
        textFileReader = textFileReader ?? _readTextFile,
        snapshotFileReader = snapshotFileReader ?? _readSnapshotFile,
        inviteFileReader = inviteFileReader ?? _readInviteFile,
        super(key: key);

  final OpenDeadlockGame initialGame;
  final bool resumeLatestSave;
  final TextFileWriter textFileWriter;
  final TextFileReader textFileReader;
  final TextFileReader snapshotFileReader;
  final TextFileReader inviteFileReader;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late OpenDeadlockGame game;
  int selectedX = 2;
  int selectedY = 2;
  String? selectedUnitId;
  GameSaveStore? saveStore;
  SavedGameSlot? latestSaveSlot;
  late int orderExportBaseCommandCount;
  final List<OpenDeadlockGame> undoStack = <OpenDeadlockGame>[];
  double mapZoomScale = _minimumMapZoomScale;
  _MapOverlayMode mapOverlayMode = _MapOverlayMode.terrain;
  bool soundEffectsEnabled = true;
  String? lastSyncStatus;

  @override
  void initState() {
    super.initState();
    game = widget.initialGame;
    orderExportBaseCommandCount = game.commandHistory.length;
    _loadSaveStore();
  }

  @override
  Widget build(BuildContext context) {
    final selectedTile = game.tileAt(selectedX, selectedY);
    final selectedTileExplored =
        selectedTile.isExploredBy(game.activeFactionId);
    final selectedTileVisible =
        game.isSectorVisibleTo(game.activeFactionId, selectedX, selectedY);
    final selectedTileKnown = selectedTileExplored || selectedTileVisible;
    final selectedColony =
        selectedTileExplored ? game.colonyAt(selectedX, selectedY) : null;
    final selectedUnit = selectedTileKnown
        ? game.visibleUnitAt(game.activeFactionId, selectedX, selectedY)
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF101418),
      body: SafeArea(
        child: Column(
          children: [
            _CommandBar(
              game: game,
              onBack: () => Navigator.pop(context),
              latestSaveSlot: latestSaveSlot,
              orderExportBaseCommandCount: orderExportBaseCommandCount,
              onSaveGame: _saveGameLocally,
              onLoadSavedGame: _loadSavedGame,
              onLoadSnapshot: _loadSnapshotFromClipboard,
              onExportSnapshotFile: _exportSnapshotToFile,
              onImportSnapshotFile: _importSnapshotFromFile,
              onLoadInvite: _loadInviteFromClipboard,
              onImportInviteFile: _importInviteFromFile,
              onCopyInvite: _copyInviteForFaction,
              onExportInvite: _exportInviteForFaction,
              onCopyOrders: _copyOrdersToClipboard,
              onExportOrdersFile: _exportOrdersToFile,
              onApplyOrders: _applyOrdersFromClipboard,
              onImportOrdersFile: _importOrdersFromFile,
              soundEffectsEnabled: soundEffectsEnabled,
              onToggleSoundEffects: _toggleSoundEffects,
              onToggleHotseat: _toggleHotseatMode,
              onEndTurn: () {
                _replaceGame(
                  game.applyCommand(
                    EndTurnCommand(factionId: game.activeFactionId),
                  ),
                  undoable: true,
                );
              },
              onRunComputerTurn: () {
                _replaceGame(
                  game.applyCommand(
                    RunComputerTurnCommand(factionId: game.activeFactionId),
                  ),
                  clearUndoStack: true,
                );
              },
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 760;
                  final map = _PlanetMap(
                    game: game,
                    selectedX: selectedX,
                    selectedY: selectedY,
                    selectedUnitId: selectedUnitId,
                    zoomScale: mapZoomScale,
                    overlayMode: mapOverlayMode,
                    onZoomChanged: (value) {
                      setState(() {
                        mapZoomScale = _clampMapZoomScale(value);
                      });
                    },
                    onOverlayChanged: (value) {
                      setState(() {
                        mapOverlayMode = value;
                      });
                    },
                    onSelected: (x, y) {
                      _handleTileSelected(x, y);
                    },
                  );
                  final detail = _SelectionPanel(
                    game: game,
                    latestSaveSlot: latestSaveSlot,
                    orderExportBaseCommandCount: orderExportBaseCommandCount,
                    lastSyncStatus: lastSyncStatus,
                    tile: selectedTile,
                    isExplored: selectedTileKnown,
                    colony: selectedColony,
                    unit: selectedUnit,
                    onFoundColony: (unit) {
                      final colonyId =
                          '${game.activeFactionId}-outpost-${unit.x}-${unit.y}-${game.turn}';
                      _replaceGame(
                        game.applyCommand(
                          FoundColonyCommand(
                            factionId: game.activeFactionId,
                            unitId: unit.id,
                            colonyId: colonyId,
                            name: 'Outpost ${unit.x + 1}-${unit.y + 1}',
                          ),
                        ),
                        afterSet: (_) {
                          selectedUnitId = null;
                        },
                        undoable: true,
                      );
                    },
                    onRecoverUnit: (unit) {
                      _replaceGame(
                        game.applyCommand(
                          RecoverUnitCommand(
                            factionId: game.activeFactionId,
                            unitId: unit.id,
                          ),
                        ),
                        undoable: true,
                      );
                    },
                    onConstructionChanged: (colonyId, construction) {
                      _replaceGame(
                        game.applyCommand(
                          SetColonyConstructionCommand(
                            factionId: game.activeFactionId,
                            colonyId: colonyId,
                            construction: construction,
                          ),
                        ),
                        undoable: true,
                      );
                    },
                    onRushConstruction: (colonyId, industry) {
                      _replaceGame(
                        game.applyCommand(
                          RushConstructionCommand(
                            factionId: game.activeFactionId,
                            colonyId: colonyId,
                            industry: industry,
                          ),
                        ),
                        undoable: true,
                      );
                    },
                    onFocusChanged: (colonyId, focus) {
                      _replaceGame(
                        game.applyCommand(
                          SetColonyFocusCommand(
                            factionId: game.activeFactionId,
                            colonyId: colonyId,
                            focus: focus,
                          ),
                        ),
                        undoable: true,
                      );
                    },
                    onApplyConstructionToAll: _applyConstructionToAllColonies,
                    onApplyFocusToAll: _applyFocusToAllColonies,
                    onAssignBestSectors: _assignBestSectorsForColony,
                    onReleaseAllSectors: _releaseAllSectorsForColony,
                    onSectorAssignmentChanged: (colonyId, tile, assigned) {
                      _replaceGame(
                        game.applyCommand(
                          SetColonySectorAssignmentCommand(
                            factionId: game.activeFactionId,
                            colonyId: colonyId,
                            x: tile.x,
                            y: tile.y,
                            assigned: assigned,
                          ),
                        ),
                        undoable: true,
                      );
                    },
                    onSelectColony: (colony) {
                      setState(() {
                        selectedX = colony.x;
                        selectedY = colony.y;
                        selectedUnitId = null;
                      });
                    },
                    onResearchChanged: (researchProject) {
                      _replaceGame(
                        game.applyCommand(
                          SetResearchProjectCommand(
                            factionId: game.activeFactionId,
                            researchProject: researchProject,
                          ),
                        ),
                        undoable: true,
                      );
                    },
                    onFundResearch: (research) {
                      _replaceGame(
                        game.applyCommand(
                          FundResearchCommand(
                            factionId: game.activeFactionId,
                            research: research,
                          ),
                        ),
                        undoable: true,
                      );
                    },
                    onFactionControlChanged: (factionId, controlMode) {
                      _replaceGame(
                        game.applyCommand(
                          SetFactionControlCommand(
                            factionId: factionId,
                            controlMode: controlMode,
                          ),
                        ),
                        afterSet: (updatedGame) {
                          if (!updatedGame.activeFaction.isLocal) {
                            selectedUnitId = null;
                          }
                        },
                        undoable: true,
                      );
                    },
                    onFactionDifficultyChanged: (factionId, difficulty) {
                      _replaceGame(
                        game.applyCommand(
                          SetFactionDifficultyCommand(
                            factionId: factionId,
                            difficulty: difficulty,
                          ),
                        ),
                        undoable: true,
                      );
                    },
                    onTaxPolicyChanged: (taxPolicy) {
                      _replaceGame(
                        game.applyCommand(
                          SetFactionTaxPolicyCommand(
                            factionId: game.activeFactionId,
                            taxPolicy: taxPolicy,
                          ),
                        ),
                        undoable: true,
                      );
                    },
                    onDiplomacyChanged: (targetFactionId, status) {
                      _replaceGame(
                        game.applyCommand(
                          SetDiplomacyStatusCommand(
                            factionId: game.activeFactionId,
                            targetFactionId: targetFactionId,
                            status: status,
                          ),
                        ),
                        undoable: true,
                      );
                    },
                    onIntelScan: (targetFactionId) {
                      _replaceGame(
                        game.applyCommand(
                          ScanFactionIntelCommand(
                            factionId: game.activeFactionId,
                            targetFactionId: targetFactionId,
                          ),
                        ),
                        undoable: true,
                      );
                    },
                    onSabotage: (targetFactionId) {
                      _replaceGame(
                        game.applyCommand(
                          SabotageColonyCommand(
                            factionId: game.activeFactionId,
                            targetFactionId: targetFactionId,
                          ),
                        ),
                        undoable: true,
                      );
                    },
                    onCopyInvite: _copyInviteForFaction,
                    onExportInvite: _exportInviteForFaction,
                    canUndoLastOrder: _canUndoLastOrder,
                    onUndoLastOrder: _undoLastOrder,
                  );

                  if (isCompact) {
                    final detailHeight = (constraints.maxHeight * 0.42)
                        .clamp(240.0, 420.0)
                        .toDouble();
                    return Column(
                      children: [
                        Expanded(child: map),
                        SizedBox(
                          height: detailHeight,
                          child: detail,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: map),
                      SizedBox(
                        width: 330,
                        child: detail,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadSaveStore() async {
    try {
      final store = await GameSaveStore.load();
      final latestSlot = await store.loadLatestSlot();
      final loadedGame = latestSlot == null ? null : latestSlot.decodeGame();
      final storedSoundEffects =
          store.preferences.getBool(_soundEffectsPreferenceKey);
      if (!mounted) {
        return;
      }
      setState(() {
        saveStore = store;
        latestSaveSlot = latestSlot;
        soundEffectsEnabled = storedSoundEffects ?? true;
        if (widget.resumeLatestSave && loadedGame != null) {
          game = loadedGame;
          orderExportBaseCommandCount = loadedGame.commandHistory.length;
          undoStack.clear();
          _selectDefaultTile(loadedGame);
        }
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load local saves: $error')),
      );
    }
  }

  Future<GameSaveStore> _ensureSaveStore() async {
    final existingStore = saveStore;
    if (existingStore != null) {
      return existingStore;
    }
    final store = await GameSaveStore.load();
    if (mounted) {
      setState(() {
        saveStore = store;
      });
    }
    return store;
  }

  void _replaceGame(
    OpenDeadlockGame updatedGame, {
    void Function(OpenDeadlockGame updatedGame)? afterSet,
    bool undoable = false,
    bool clearUndoStack = false,
  }) {
    final previousGame = game;
    final commandHistoryChanged =
        updatedGame.commandHistory.length != previousGame.commandHistory.length;
    setState(() {
      if (clearUndoStack) {
        undoStack.clear();
      } else if (undoable &&
          updatedGame.commandHistory.length >
              previousGame.commandHistory.length) {
        undoStack.add(previousGame);
      }
      game = updatedGame;
      afterSet?.call(updatedGame);
    });
    if (commandHistoryChanged) {
      _playUiSound();
    }
    _autosaveGame(updatedGame);
  }

  bool get _canUndoLastOrder {
    return undoStack.isNotEmpty &&
        game.commandHistory.length > orderExportBaseCommandCount;
  }

  void _undoLastOrder() {
    if (!_canUndoLastOrder) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pending local order to undo')),
      );
      return;
    }

    final undoneRecord = game.commandHistory.last;
    final undoneSummary = _commandSummaryFor(game, undoneRecord.command);
    final restoredGame = undoStack.removeLast();
    setState(() {
      game = restoredGame;
      final currentSelectedUnitId = selectedUnitId;
      selectedUnitId = currentSelectedUnitId != null &&
              _unitById(restoredGame, currentSelectedUnitId) != null
          ? currentSelectedUnitId
          : null;
    });
    _playUiSound();
    _autosaveGame(restoredGame);
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Undid $undoneSummary')),
    );
  }

  Future<void> _autosaveGame(OpenDeadlockGame source) async {
    try {
      final store = await _ensureSaveStore();
      final slot = await store.saveGame(
        source,
        slotId: GameSaveStore.autosaveSlotId,
      );
      if (!mounted) {
        return;
      }
      if (GameCodec.fingerprintGame(game) != slot.stateFingerprint) {
        return;
      }
      setState(() {
        latestSaveSlot = slot;
      });
    } on Object catch (error) {
      debugPrint('Autosave failed: $error');
    }
  }

  Future<void> _saveGameLocally() async {
    final defaultName = GameSaveArchive.defaultNameFor(game);
    final saveName = await _showSaveNameDialog(defaultName);
    if (saveName == null) {
      return;
    }

    try {
      final store = await _ensureSaveStore();
      final slot = await store.saveGame(
        game,
        slotId: GameSaveStore.createManualSlotId(),
        name: saveName.trim().isEmpty ? defaultName : saveName,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        latestSaveSlot = slot;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved ${slot.name} locally')),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save game: $error')),
      );
    }
  }

  Future<void> _toggleSoundEffects() async {
    final enabled = !soundEffectsEnabled;
    setState(() {
      soundEffectsEnabled = enabled;
    });
    try {
      final store = await _ensureSaveStore();
      await store.preferences.setBool(_soundEffectsPreferenceKey, enabled);
    } on Object catch (error) {
      debugPrint('Could not save sound preference: $error');
    }
    if (enabled) {
      _playUiSound(force: true);
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(enabled ? 'Sound effects enabled' : 'Sound effects muted'),
      ),
    );
  }

  void _playUiSound({bool force = false}) {
    if (!force && !soundEffectsEnabled) {
      return;
    }
    try {
      SystemSound.play(SystemSoundType.click).catchError((Object _) {});
    } on Object {
      // System sound is best-effort; some test/browser surfaces do not expose it.
    }
  }

  Future<void> _loadSavedGame() async {
    try {
      final store = await _ensureSaveStore();
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
      final latestSlot = await store.loadLatestSlot();
      if (mounted) {
        setState(() {
          latestSaveSlot = latestSlot;
        });
      }
      if (slot == null) {
        return;
      }
      final loadedGame = await store.loadGame(slot.slotId);
      if (loadedGame == null) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Local save is missing')),
        );
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        game = loadedGame;
        latestSaveSlot = slot;
        orderExportBaseCommandCount = loadedGame.commandHistory.length;
        lastSyncStatus = null;
        undoStack.clear();
        _selectDefaultTile(loadedGame);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loaded ${slot.name}')),
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

  Future<String?> _showSaveNameDialog(String defaultName) async {
    return showDialog<String>(
      context: context,
      builder: (context) => _SaveNameDialog(defaultName: defaultName),
    );
  }

  Future<String?> _showCodeInputDialog({
    required String title,
    required String label,
    required String actionLabel,
    required IconData actionIcon,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) => _CodeInputDialog(
        title: title,
        label: label,
        actionLabel: actionLabel,
        actionIcon: actionIcon,
      ),
    );
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
                child: slots.isEmpty
                    ? const Padding(
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
                          return _SaveSlotTile(
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

  Future<void> _loadSnapshotFromClipboard() async {
    final text = await _showCodeInputDialog(
      title: 'Load Snapshot',
      label: 'Snapshot Code',
      actionLabel: 'Load',
      actionIcon: Icons.upload_file,
    );
    if (text == null || text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No game snapshot code was provided')),
      );
      return;
    }

    await _loadSnapshotFromText(
      text,
      emptyMessage: 'No game snapshot code was provided',
      errorPrefix: 'Could not load snapshot',
      successMessage: 'Game snapshot loaded',
    );
  }

  Future<void> _importSnapshotFromFile() async {
    try {
      final text = await widget.snapshotFileReader();
      if (text == null) {
        return;
      }
      await _loadSnapshotFromText(
        text,
        emptyMessage: 'Selected snapshot file was empty',
        errorPrefix: 'Could not import snapshot file',
        successMessage: 'Snapshot file loaded',
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not import snapshot file: $error')),
      );
    }
  }

  Future<void> _loadSnapshotFromText(
    String text, {
    required String emptyMessage,
    required String errorPrefix,
    required String successMessage,
  }) async {
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(emptyMessage)),
      );
      return;
    }

    try {
      final loadedGame = GameCodec.decodeGame(text);
      _replaceGame(
        loadedGame,
        afterSet: (_) {
          orderExportBaseCommandCount = loadedGame.commandHistory.length;
          lastSyncStatus = null;
          undoStack.clear();
          _selectDefaultTile(loadedGame);
        },
        clearUndoStack: true,
      );
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$errorPrefix: $error')),
      );
    }
  }

  Future<void> _loadInviteFromClipboard() async {
    final text = await _showCodeInputDialog(
      title: 'Load Invite',
      label: 'Invite Code',
      actionLabel: 'Join',
      actionIcon: Icons.person_add_alt_1,
    );
    if (text == null || text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No invite code was provided')),
      );
      return;
    }

    await _loadInviteFromText(
      text,
      emptyMessage: 'No invite code was provided',
      errorPrefix: 'Could not load invite',
      successMessageForInvite: (invite) =>
          'Joined as ${invite.invitedFactionName}',
    );
  }

  Future<void> _importInviteFromFile() async {
    try {
      final text = await widget.inviteFileReader();
      if (text == null) {
        return;
      }
      await _loadInviteFromText(
        text,
        emptyMessage: 'Selected invite file was empty',
        errorPrefix: 'Could not import invite file',
        successMessageForInvite: (invite) =>
            'Invite file loaded: joined as ${invite.invitedFactionName}',
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not import invite file: $error')),
      );
    }
  }

  Future<void> _loadInviteFromText(
    String text, {
    required String emptyMessage,
    required String errorPrefix,
    required String Function(GameInvite invite) successMessageForInvite,
  }) async {
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(emptyMessage)),
      );
      return;
    }

    try {
      final invite = GameCodec.decodeGameInvite(text);
      final loadedGame = GameCodec.decodeInvitedGame(text);
      _replaceGame(
        loadedGame,
        afterSet: (_) {
          orderExportBaseCommandCount = loadedGame.commandHistory.length;
          lastSyncStatus = null;
          undoStack.clear();
          _selectDefaultTile(loadedGame);
        },
        clearUndoStack: true,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessageForInvite(invite))),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$errorPrefix: $error')),
      );
    }
  }

  Future<void> _applyOrdersFromClipboard() async {
    final text = await _showCodeInputDialog(
      title: 'Apply Orders',
      label: 'Order Package Code',
      actionLabel: 'Apply',
      actionIcon: Icons.playlist_add_check,
    );
    if (text == null || text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No order package code was provided')),
      );
      return;
    }

    await _applyOrdersFromText(
      text,
      emptyMessage: 'No order package code was provided',
      errorPrefix: 'Could not apply orders',
      successPrefix: 'Applied',
    );
  }

  Future<void> _importOrdersFromFile() async {
    try {
      final text = await widget.textFileReader();
      if (text == null) {
        return;
      }
      await _applyOrdersFromText(
        text,
        emptyMessage: 'Selected order file was empty',
        errorPrefix: 'Could not import order file',
        successPrefix: 'Imported',
      );
    } on Object catch (error) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not import order file: $error')),
      );
    }
  }

  Future<void> _applyOrdersFromText(
    String text, {
    required String emptyMessage,
    required String errorPrefix,
    required String successPrefix,
  }) async {
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(emptyMessage)),
      );
      return;
    }

    try {
      final package = GameCodec.decodeCommandPackage(text);
      final preview = GameCodec.previewCommandPackage(game, package);
      final confirmed = await _showOrderPackagePreviewDialog(
        preview,
        package,
      );
      if (confirmed != true || !mounted) {
        return;
      }
      final updatedGame = GameCodec.applyCommandPackage(game, package);
      final syncStatus =
          '${preview.hasNewCommands ? '$successPrefix ${preview.summaryLabel}' : preview.summaryLabel}. '
          'Next: ${preview.handoffLabel}';
      _replaceGame(
        updatedGame,
        afterSet: (_) {
          orderExportBaseCommandCount = updatedGame.commandHistory.length;
          lastSyncStatus = syncStatus;
          undoStack.clear();
          final currentSelectedUnitId = selectedUnitId;
          selectedUnitId = currentSelectedUnitId != null &&
                  _unitById(updatedGame, currentSelectedUnitId) != null
              ? currentSelectedUnitId
              : null;
        },
        clearUndoStack: true,
      );
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(syncStatus),
        ),
      );
    } on Object catch (error) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$errorPrefix: $error')),
      );
    }
  }

  Future<bool?> _showOrderPackagePreviewDialog(
    CommandPackagePreview preview,
    CommandPackage package,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => _OrderPackagePreviewDialog(
        game: game,
        preview: preview,
        package: package,
      ),
    );
  }

  Future<bool?> _showCopyOrdersPreviewDialog(
    CommandPackage package,
    int fromCommandIndex, {
    required String title,
    required String confirmLabel,
    required IconData confirmIcon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => _CopyOrdersPreviewDialog(
        title: title,
        confirmLabel: confirmLabel,
        confirmIcon: confirmIcon,
        game: game,
        package: package,
        fromCommandIndex: fromCommandIndex,
      ),
    );
  }

  Future<void> _copyOrdersToClipboard() async {
    final fromCommandIndex = _clampedOrderExportBaseCommandCount();
    final orderPackage = _encodeCurrentOrderPackage(fromCommandIndex);
    final package = GameCodec.decodeCommandPackage(orderPackage);
    final confirmed = await _showCopyOrdersPreviewDialog(
      package,
      fromCommandIndex,
      title: 'Copy Orders',
      confirmLabel: 'Copy Code',
      confirmIcon: Icons.content_copy,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final orderLabel = package.commands.length == 1 ? 'order' : 'orders';

    await Clipboard.setData(
      ClipboardData(text: GameCodec.encodeShareCode(orderPackage)),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      orderExportBaseCommandCount = game.commandHistory.length;
      undoStack.clear();
    });
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          package.commands.isEmpty
              ? 'Order code copied: no new orders since last sync'
              : 'Order code copied: ${package.commands.length} new $orderLabel from ${game.activeFaction.name}',
        ),
      ),
    );
  }

  Future<void> _exportSnapshotToFile() async {
    try {
      final snapshot = GameCodec.encodeGame(game);
      final fileName = _snapshotFileName();
      final location = await getSaveLocation(
        acceptedTypeGroups: _snapshotFileTypes,
        suggestedName: fileName,
        confirmButtonText: 'Save Snapshot',
      );
      if (location == null) {
        return;
      }
      await widget.textFileWriter(
        path: location.path,
        content: GameCodec.encodeShareCode(snapshot),
        fileName: fileName,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Snapshot file saved')),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export snapshot file: $error')),
      );
    }
  }

  Future<void> _exportOrdersToFile() async {
    final fromCommandIndex = _clampedOrderExportBaseCommandCount();
    final orderPackage = _encodeCurrentOrderPackage(fromCommandIndex);
    final package = GameCodec.decodeCommandPackage(orderPackage);
    final confirmed = await _showCopyOrdersPreviewDialog(
      package,
      fromCommandIndex,
      title: 'Export Orders File',
      confirmLabel: 'Save File',
      confirmIcon: Icons.save_alt,
    );
    if (confirmed != true || !mounted) {
      return;
    }

    try {
      final location = await getSaveLocation(
        acceptedTypeGroups: _orderPackageFileTypes,
        suggestedName: _orderPackageFileName(package),
        confirmButtonText: 'Save Orders',
      );
      if (location == null) {
        return;
      }
      final shareCode = GameCodec.encodeShareCode(orderPackage);
      await widget.textFileWriter(
        path: location.path,
        content: shareCode,
        fileName: _orderPackageFileName(package),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        orderExportBaseCommandCount = game.commandHistory.length;
        undoStack.clear();
      });
      final orderLabel = package.commands.length == 1 ? 'order' : 'orders';
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            package.commands.isEmpty
                ? 'Order file saved: no new orders since last sync'
                : 'Order file saved: ${package.commands.length} new $orderLabel from ${game.activeFaction.name}',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export order file: $error')),
      );
    }
  }

  int _clampedOrderExportBaseCommandCount() {
    if (orderExportBaseCommandCount < 0) {
      return 0;
    }
    if (orderExportBaseCommandCount > game.commandHistory.length) {
      return game.commandHistory.length;
    }
    return orderExportBaseCommandCount;
  }

  String _encodeCurrentOrderPackage(int fromCommandIndex) {
    return GameCodec.encodeCommandPackage(
      game,
      fromCommandIndex: fromCommandIndex,
      exportedByFactionId: game.activeFactionId,
    );
  }

  String _orderPackageFileName(CommandPackage package) {
    final safeSession = _safeFilePart(package.sessionId);
    final safeFaction = _safeFilePart(package.exportedByFactionId);
    return 'opendeadlock-$safeSession-turn-${game.turn}-$safeFaction.odorders';
  }

  String _snapshotFileName() {
    final safeSession = _safeFilePart(game.sessionId);
    return 'opendeadlock-$safeSession-turn-${game.turn}-snapshot.odsave';
  }

  String _safeFilePart(String value) {
    final buffer = StringBuffer();
    for (final codeUnit in value.codeUnits) {
      final isDigit = codeUnit >= 48 && codeUnit <= 57;
      final isUpper = codeUnit >= 65 && codeUnit <= 90;
      final isLower = codeUnit >= 97 && codeUnit <= 122;
      if (isDigit || isUpper || isLower) {
        buffer.writeCharCode(codeUnit);
      } else if (buffer.isNotEmpty && !buffer.toString().endsWith('-')) {
        buffer.write('-');
      }
    }
    final sanitized = buffer.toString();
    if (sanitized.isEmpty) {
      return 'session';
    }
    return sanitized.length <= 32 ? sanitized : sanitized.substring(0, 32);
  }

  Future<void> _copyInviteForFaction(String factionId) async {
    try {
      final invitedFaction = game.factionById(factionId);
      if (invitedFaction == null) {
        throw ArgumentError('Unknown faction: $factionId.');
      }
      final hostFaction = game.factions.firstWhere(
        (faction) => faction.isLocal,
        orElse: () => game.activeFaction,
      );
      final invite = GameCodec.encodeGameInvite(
        game,
        hostFactionId: hostFaction.id,
        invitedFactionId: factionId,
      );
      await Clipboard.setData(
        ClipboardData(text: GameCodec.encodeShareCode(invite)),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Invite code copied for ${invitedFaction.name}')),
      );
    } on Object catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not copy invite: $error')),
      );
    }
  }

  Future<void> _exportInviteForFaction(String factionId) async {
    try {
      final invitedFaction = game.factionById(factionId);
      if (invitedFaction == null) {
        throw ArgumentError('Unknown faction: $factionId.');
      }
      final hostFaction = game.factions.firstWhere(
        (faction) => faction.isLocal,
        orElse: () => game.activeFaction,
      );
      final invite = GameCodec.encodeGameInvite(
        game,
        hostFactionId: hostFaction.id,
        invitedFactionId: factionId,
      );
      final decodedInvite = GameCodec.decodeGameInvite(invite);
      final fileName = _inviteFileName(decodedInvite);
      final location = await getSaveLocation(
        acceptedTypeGroups: _inviteFileTypes,
        suggestedName: fileName,
        confirmButtonText: 'Save Invite',
      );
      if (location == null) {
        return;
      }
      await widget.textFileWriter(
        path: location.path,
        content: GameCodec.encodeShareCode(invite),
        fileName: fileName,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invite file saved for ${invitedFaction.name}')),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export invite file: $error')),
      );
    }
  }

  String _inviteFileName(GameInvite invite) {
    final safeSession = _safeFilePart(invite.sessionId);
    final safeFaction = _safeFilePart(invite.invitedFactionId);
    return 'opendeadlock-$safeSession-invite-$safeFaction.odinvite';
  }

  void _selectDefaultTile(OpenDeadlockGame source) {
    if (source.colonies.isNotEmpty) {
      selectedX = source.colonies.first.x;
      selectedY = source.colonies.first.y;
    } else {
      selectedX = 0;
      selectedY = 0;
    }
    selectedUnitId = null;
  }

  void _toggleHotseatMode() {
    final enableHotseat = game.factions.any((faction) => faction.isComputer);
    _replaceGame(
      game.copyWith(
        factions: game.factions.map((faction) {
          return faction.copyWith(
              isComputer:
                  enableHotseat ? false : faction.id != game.factions.first.id);
        }).toList(),
        reports: <TurnReport>[
          TurnReport(
            title: enableHotseat ? 'Hotseat enabled' : 'AI opponents enabled',
            message: enableHotseat
                ? 'All factions now wait for local or synced player orders.'
                : 'Non-player factions will issue automated orders when their turn comes up.',
          ),
          ...game.reports,
        ],
      ),
      clearUndoStack: true,
    );
  }

  void _applyConstructionToAllColonies(Colony sourceColony) {
    final commands = _constructionCommandsForMatchingColonies(sourceColony);
    if (commands.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No eligible colonies can queue ${sourceColony.construction}',
          ),
        ),
      );
      return;
    }
    _replaceGame(game.applyCommands(commands), undoable: true);
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Queued ${sourceColony.construction} in ${commands.length} ${commands.length == 1 ? 'colony' : 'colonies'}',
        ),
      ),
    );
  }

  List<GameCommand> _constructionCommandsForMatchingColonies(
    Colony sourceColony,
  ) {
    if (sourceColony.ownerId != game.activeFactionId) {
      return const <GameCommand>[];
    }
    final commands = <GameCommand>[];
    for (final colony in game.colonies) {
      if (!_canCopyConstructionToColony(sourceColony, colony)) {
        continue;
      }
      commands.add(
        SetColonyConstructionCommand(
          factionId: game.activeFactionId,
          colonyId: colony.id,
          construction: sourceColony.construction,
        ),
      );
    }
    return commands;
  }

  bool _canCopyConstructionToColony(Colony sourceColony, Colony targetColony) {
    return targetColony.ownerId == game.activeFactionId &&
        targetColony.id != sourceColony.id &&
        targetColony.construction != sourceColony.construction &&
        !OpenDeadlockGame.isCompletedConstruction(
          targetColony,
          sourceColony.construction,
        ) &&
        OpenDeadlockGame.isConstructionAvailableFor(
          targetColony,
          sourceColony.construction,
        );
  }

  void _applyFocusToAllColonies(Colony sourceColony) {
    final commands = _focusCommandsForMatchingColonies(sourceColony);
    if (commands.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'All colonies already use ${OpenDeadlockGame.colonyFocusLabelFor(sourceColony.focus)} focus',
          ),
        ),
      );
      return;
    }
    _replaceGame(game.applyCommands(commands), undoable: true);
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Applied ${OpenDeadlockGame.colonyFocusLabelFor(sourceColony.focus)} focus to ${commands.length} ${commands.length == 1 ? 'colony' : 'colonies'}',
        ),
      ),
    );
  }

  void _assignBestSectorsForColony(Colony sourceColony) {
    if (sourceColony.ownerId != game.activeFactionId) {
      return;
    }
    final colony = game.colonyById(sourceColony.id);
    final sectors = game.preferredAssignableSectorsFor(colony);
    if (sectors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${colony.name} has no open work sectors'),
        ),
      );
      return;
    }
    final commands = sectors
        .map(
          (sector) => SetColonySectorAssignmentCommand(
            factionId: game.activeFactionId,
            colonyId: colony.id,
            x: sector.x,
            y: sector.y,
            assigned: true,
          ),
        )
        .toList();
    _replaceGame(game.applyCommands(commands), undoable: true);
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Assigned ${commands.length} ${commands.length == 1 ? 'sector' : 'sectors'} to ${colony.name}',
        ),
      ),
    );
  }

  void _releaseAllSectorsForColony(Colony sourceColony) {
    if (sourceColony.ownerId != game.activeFactionId) {
      return;
    }
    final colony = game.colonyById(sourceColony.id);
    if (colony.assignedSectors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${colony.name} has no assigned sectors')),
      );
      return;
    }
    final commands = colony.assignedSectors
        .map(
          (sector) => SetColonySectorAssignmentCommand(
            factionId: game.activeFactionId,
            colonyId: colony.id,
            x: sector.x,
            y: sector.y,
            assigned: false,
          ),
        )
        .toList();
    _replaceGame(game.applyCommands(commands), undoable: true);
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Released ${commands.length} ${commands.length == 1 ? 'sector' : 'sectors'} from ${colony.name}',
        ),
      ),
    );
  }

  List<GameCommand> _focusCommandsForMatchingColonies(Colony sourceColony) {
    if (sourceColony.ownerId != game.activeFactionId) {
      return const <GameCommand>[];
    }
    final commands = <GameCommand>[];
    for (final colony in game.colonies) {
      if (colony.ownerId != game.activeFactionId ||
          colony.id == sourceColony.id ||
          colony.focus == sourceColony.focus) {
        continue;
      }
      commands.add(
        SetColonyFocusCommand(
          factionId: game.activeFactionId,
          colonyId: colony.id,
          focus: sourceColony.focus,
        ),
      );
    }
    return commands;
  }

  Unit? _selectedUnit() {
    if (selectedUnitId == null) {
      return null;
    }
    for (final unit in game.units) {
      if (unit.id == selectedUnitId) {
        return unit;
      }
    }
    return null;
  }

  void _handleTileSelected(int x, int y) {
    final selectedUnit = _selectedUnit();
    final tappedTile = game.tileAt(x, y);
    final tappedUnit = (tappedTile.isExploredBy(game.activeFactionId) ||
            game.isSectorVisibleTo(game.activeFactionId, x, y))
        ? game.visibleUnitAt(game.activeFactionId, x, y)
        : null;

    if (!game.activeFactionCanIssueLocalOrders) {
      setState(() {
        selectedX = x;
        selectedY = y;
        selectedUnitId = null;
      });
      return;
    }

    if (tappedUnit != null && tappedUnit.ownerId == game.activeFactionId) {
      setState(() {
        selectedX = x;
        selectedY = y;
        selectedUnitId = tappedUnit.id;
      });
      return;
    }

    if (selectedUnit != null && (selectedUnit.x != x || selectedUnit.y != y)) {
      try {
        final updatedGame = game.applyCommand(
          MoveUnitCommand(
            factionId: game.activeFactionId,
            unitId: selectedUnit.id,
            x: x,
            y: y,
          ),
        );
        _replaceGame(
          updatedGame,
          afterSet: (_) {
            final updatedUnit = _unitById(updatedGame, selectedUnit.id);
            selectedX = updatedUnit == null ? x : updatedUnit.x;
            selectedY = updatedUnit == null ? y : updatedUnit.y;
            selectedUnitId = updatedUnit == null ? null : updatedUnit.id;
          },
          undoable: true,
        );
      } on ArgumentError catch (error) {
        setState(() {
          selectedX = x;
          selectedY = y;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message.toString())),
        );
      }
      return;
    }

    setState(() {
      selectedX = x;
      selectedY = y;
      selectedUnitId =
          tappedUnit != null && tappedUnit.ownerId == game.activeFactionId
              ? tappedUnit.id
              : null;
    });
  }

  Unit? _unitById(OpenDeadlockGame source, String unitId) {
    for (final unit in source.units) {
      if (unit.id == unitId) {
        return unit;
      }
    }
    return null;
  }
}

class _SaveNameDialog extends StatefulWidget {
  const _SaveNameDialog({
    Key? key,
    required this.defaultName,
  }) : super(key: key);

  final String defaultName;

  @override
  State<_SaveNameDialog> createState() => _SaveNameDialogState();
}

class _SaveNameDialogState extends State<_SaveNameDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.defaultName);
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
        'Save Game',
        style: TextStyle(color: Color(0xFFF4F7FA)),
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(color: Color(0xFFE9EEF2)),
        decoration: const InputDecoration(
          labelText: 'Name',
          labelStyle: TextStyle(color: Color(0xFF9FB0BE)),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF55616C)),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFCCD6A6)),
          ),
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.save),
          label: const Text('Save'),
          onPressed: () => Navigator.pop(context, controller.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFCCD6A6),
            foregroundColor: const Color(0xFF111418),
          ),
        ),
      ],
    );
  }
}

class _CodeInputDialog extends StatefulWidget {
  const _CodeInputDialog({
    Key? key,
    required this.title,
    required this.label,
    required this.actionLabel,
    required this.actionIcon,
  }) : super(key: key);

  final String title;
  final String label;
  final String actionLabel;
  final IconData actionIcon;

  @override
  State<_CodeInputDialog> createState() => _CodeInputDialogState();
}

class _CodeInputDialogState extends State<_CodeInputDialog> {
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
      title: Text(
        widget.title,
        style: const TextStyle(color: Color(0xFFF4F7FA)),
      ),
      content: SizedBox(
        width: 460,
        child: TextField(
          controller: controller,
          autofocus: true,
          minLines: 4,
          maxLines: 7,
          style: const TextStyle(color: Color(0xFFE9EEF2), fontSize: 12),
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: const TextStyle(color: Color(0xFF9FB0BE)),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF55616C)),
            ),
            focusedBorder: const OutlineInputBorder(
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
          icon: const Icon(Icons.content_paste),
          label: const Text('Paste'),
          onPressed: () async {
            final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
            final text = clipboardData?.text;
            if (text == null) {
              return;
            }
            controller.text = text.trim();
          },
        ),
        ElevatedButton.icon(
          icon: Icon(widget.actionIcon),
          label: Text(widget.actionLabel),
          onPressed: () => Navigator.pop(context, controller.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFCCD6A6),
            foregroundColor: const Color(0xFF111418),
          ),
        ),
      ],
    );
  }
}

class _OrderPackagePreviewDialog extends StatelessWidget {
  const _OrderPackagePreviewDialog({
    Key? key,
    required this.game,
    required this.preview,
    required this.package,
  }) : super(key: key);

  final OpenDeadlockGame game;
  final CommandPackagePreview preview;
  final CommandPackage package;

  @override
  Widget build(BuildContext context) {
    final incomingCommands =
        package.commands.skip(preview.overlapCommandCount).toList();

    return AlertDialog(
      backgroundColor: const Color(0xFF202B34),
      title: const Text(
        'Review Orders',
        style: TextStyle(color: Color(0xFFF4F7FA)),
      ),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preview.summaryLabel,
                style: const TextStyle(
                  color: Color(0xFFF4F7FA),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              _DetailRow(label: 'Sender', value: preview.exportedByFactionName),
              _DetailRow(label: 'Session', value: preview.sessionId),
              _DetailRow(
                label: 'Local',
                value: '${preview.localCommandCount} orders',
              ),
              _DetailRow(
                label: 'Package',
                value: '${preview.commandCount} orders',
              ),
              _DetailRow(label: 'Result', value: preview.resultLabel),
              _DetailRow(label: 'Handoff', value: preview.handoffLabel),
              _DetailRow(
                label: 'Overlap',
                value: '${preview.overlapCommandCount} orders',
              ),
              _DetailRow(
                  label: 'New', value: '${preview.newCommandCount} orders'),
              if (incomingCommands.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'No unapplied orders in this package.',
                    style: TextStyle(color: Color(0xFFE9EEF2)),
                  ),
                )
              else
                ...incomingCommands.take(6).toList().asMap().entries.map(
                  (entry) {
                    final commandIndex = package.baseCommandCount +
                        preview.overlapCommandCount +
                        entry.key +
                        1;
                    final command = entry.value;
                    return _IncomingOrderLine(
                      index: commandIndex,
                      command: command,
                      factionName: _factionNameFor(game, command.factionId),
                      summary: _commandSummaryFor(game, command),
                    );
                  },
                ),
              if (incomingCommands.length > 6)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '+${incomingCommands.length - 6} more orders',
                    style: const TextStyle(
                      color: Color(0xFF9FB0BE),
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          icon: Icon(preview.hasNewCommands
              ? Icons.playlist_add_check
              : Icons.check_circle_outline),
          label: Text(preview.hasNewCommands ? 'Apply Orders' : 'Close'),
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFCCD6A6),
            foregroundColor: const Color(0xFF111418),
          ),
        ),
      ],
    );
  }
}

class _CopyOrdersPreviewDialog extends StatelessWidget {
  const _CopyOrdersPreviewDialog({
    Key? key,
    required this.title,
    required this.confirmLabel,
    required this.confirmIcon,
    required this.game,
    required this.package,
    required this.fromCommandIndex,
  }) : super(key: key);

  final String title;
  final String confirmLabel;
  final IconData confirmIcon;
  final OpenDeadlockGame game;
  final CommandPackage package;
  final int fromCommandIndex;

  @override
  Widget build(BuildContext context) {
    final pendingRecords = game.commandHistory.skip(fromCommandIndex).toList();
    final orderLabel = package.commands.length == 1 ? 'order' : 'orders';
    final summary = package.commands.isEmpty
        ? 'No new orders since last sync'
        : '${package.commands.length} new $orderLabel from ${_factionNameFor(game, package.exportedByFactionId)}';

    return AlertDialog(
      backgroundColor: const Color(0xFF202B34),
      title: Text(
        title,
        style: const TextStyle(color: Color(0xFFF4F7FA)),
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary,
                style: const TextStyle(
                  color: Color(0xFFF4F7FA),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              _DetailRow(
                label: 'Sender',
                value: _factionNameFor(game, package.exportedByFactionId),
              ),
              _DetailRow(label: 'Session', value: package.sessionId),
              _DetailRow(
                label: 'Baseline',
                value: fromCommandIndex == 0
                    ? 'Game start'
                    : 'Command $fromCommandIndex',
              ),
              _DetailRow(
                label: 'Package',
                value: '${package.commandCount} orders',
              ),
              _DetailRow(
                label: 'Result',
                value: _commandPackageResultLabelFor(game, package),
              ),
              _DetailRow(
                label: 'Handoff',
                value: _commandPackageHandoffLabelFor(game, package),
              ),
              if (pendingRecords.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'This code will sync the current session but contains no new player orders.',
                    style: TextStyle(color: Color(0xFFE9EEF2)),
                  ),
                )
              else
                ...pendingRecords.take(6).toList().asMap().entries.map((entry) {
                  final recordIndex = fromCommandIndex + entry.key + 1;
                  return _PendingOrderLine(
                    index: recordIndex,
                    record: entry.value,
                    factionName: _factionNameFor(game, entry.value.factionId),
                    summary: _commandSummaryFor(game, entry.value.command),
                  );
                }),
              if (pendingRecords.length > 6)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '+${pendingRecords.length - 6} more orders',
                    style: const TextStyle(
                      color: Color(0xFF9FB0BE),
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          icon: Icon(confirmIcon),
          label: Text(confirmLabel),
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFCCD6A6),
            foregroundColor: const Color(0xFF111418),
          ),
        ),
      ],
    );
  }
}

class _SaveSlotTile extends StatelessWidget {
  const _SaveSlotTile({
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

enum _CommandBarAction {
  saveLocal,
  loadLocal,
  copySnapshot,
  exportSnapshotFile,
  loadSnapshot,
  importSnapshotFile,
  copyInvite,
  exportInviteFile,
  loadInvite,
  importInviteFile,
  copyOrders,
  exportOrdersFile,
  applyOrders,
  importOrdersFile,
  toggleHotseat,
}

class _CommandBar extends StatelessWidget {
  const _CommandBar({
    Key? key,
    required this.game,
    required this.onBack,
    required this.latestSaveSlot,
    required this.orderExportBaseCommandCount,
    required this.onSaveGame,
    required this.onLoadSavedGame,
    required this.onLoadSnapshot,
    required this.onExportSnapshotFile,
    required this.onImportSnapshotFile,
    required this.onLoadInvite,
    required this.onImportInviteFile,
    required this.onCopyInvite,
    required this.onExportInvite,
    required this.onCopyOrders,
    required this.onExportOrdersFile,
    required this.onApplyOrders,
    required this.onImportOrdersFile,
    required this.soundEffectsEnabled,
    required this.onToggleSoundEffects,
    required this.onToggleHotseat,
    required this.onEndTurn,
    required this.onRunComputerTurn,
  }) : super(key: key);

  final OpenDeadlockGame game;
  final VoidCallback onBack;
  final SavedGameSlot? latestSaveSlot;
  final int orderExportBaseCommandCount;
  final Future<void> Function() onSaveGame;
  final Future<void> Function() onLoadSavedGame;
  final Future<void> Function() onLoadSnapshot;
  final Future<void> Function() onExportSnapshotFile;
  final Future<void> Function() onImportSnapshotFile;
  final Future<void> Function() onLoadInvite;
  final Future<void> Function() onImportInviteFile;
  final Future<void> Function(String factionId) onCopyInvite;
  final Future<void> Function(String factionId) onExportInvite;
  final Future<void> Function() onCopyOrders;
  final Future<void> Function() onExportOrdersFile;
  final Future<void> Function() onApplyOrders;
  final Future<void> Function() onImportOrdersFile;
  final bool soundEffectsEnabled;
  final VoidCallback onToggleSoundEffects;
  final VoidCallback onToggleHotseat;
  final VoidCallback onEndTurn;
  final VoidCallback onRunComputerTurn;

  @override
  Widget build(BuildContext context) {
    final hasComputerOpponents =
        game.factions.any((faction) => faction.isComputer);
    final activeControl =
        Faction.controlModeLabelFor(game.activeFaction.controlMode);
    final pendingOrderCount =
        _pendingOrderCountFor(game, orderExportBaseCommandCount);
    final syncActionLabel = _syncActionLabelFor(game, pendingOrderCount);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 620;
        return Container(
          color: const Color(0xFF1F2933),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: isCompact
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _backButton(),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _CompactTurnSummary(
                            game: game,
                            activeControl: activeControl,
                            syncActionLabel: syncActionLabel,
                          ),
                        ),
                        _syncMenu(context, hasComputerOpponents),
                        const SizedBox(width: 2),
                        _soundButton(),
                        const SizedBox(width: 4),
                        _compactEndTurnButton(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _statusChips(activeControl, syncActionLabel)
                            .map(
                              (chip) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: chip,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    _backButton(),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: _statusChips(activeControl, syncActionLabel),
                      ),
                    ),
                    _syncMenu(context, hasComputerOpponents),
                    const SizedBox(width: 4),
                    _soundButton(),
                    const SizedBox(width: 8),
                    _endTurnButton(),
                  ],
                ),
        );
      },
    );
  }

  Widget _backButton() {
    return IconButton(
      tooltip: 'Back',
      color: Colors.white,
      icon: const Icon(Icons.arrow_back),
      onPressed: onBack,
    );
  }

  Widget _soundButton() {
    return IconButton(
      tooltip:
          soundEffectsEnabled ? 'Mute sound effects' : 'Enable sound effects',
      color: Colors.white,
      icon: Icon(soundEffectsEnabled ? Icons.volume_up : Icons.volume_off),
      onPressed: onToggleSoundEffects,
    );
  }

  List<Widget> _statusChips(String activeControl, String syncActionLabel) {
    final resources = game.activeFaction.resources;
    return <Widget>[
      _StatusChip(icon: Icons.flag, label: 'Turn ${game.turn}'),
      _StatusChip(icon: Icons.person, label: game.activeFaction.name),
      _StatusChip(icon: Icons.manage_accounts, label: activeControl),
      _StatusChip(icon: _syncActionIconFor(game), label: syncActionLabel),
      _StatusChip(icon: Icons.grass, label: '${resources.food}'),
      _StatusChip(
          icon: Icons.precision_manufacturing, label: '${resources.industry}'),
      _StatusChip(icon: Icons.science, label: '${resources.research}'),
      _StatusChip(icon: Icons.payments, label: '${resources.credits}'),
      _StatusChip(
          icon: Icons.history, label: '${game.commandHistory.length} cmd'),
      _StatusChip(icon: Icons.tag, label: _shortSessionId(game.sessionId)),
      if (game.activeFaction.isRemote)
        const _StatusChip(icon: Icons.cloud_sync, label: 'Waiting for sync'),
      if (game.isGameOver)
        _StatusChip(
          icon: Icons.emoji_events,
          label: '${game.winningFaction?.name ?? 'Faction'} wins',
        ),
    ];
  }

  Widget _syncMenu(BuildContext context, bool hasComputerOpponents) {
    final singleRemoteFaction = _singleRemoteFaction();
    return PopupMenuButton<_CommandBarAction>(
      tooltip: 'Sync',
      color: const Color(0xFF202B34),
      icon: const Icon(Icons.sync_alt, color: Colors.white),
      onSelected: (action) => _handleMenuAction(context, action),
      itemBuilder: (context) => <PopupMenuEntry<_CommandBarAction>>[
        const PopupMenuItem<_CommandBarAction>(
          value: _CommandBarAction.saveLocal,
          child: _SyncMenuItem(icon: Icons.save, label: 'Save Local'),
        ),
        PopupMenuItem<_CommandBarAction>(
          value: _CommandBarAction.loadLocal,
          enabled: latestSaveSlot != null,
          child:
              const _SyncMenuItem(icon: Icons.folder_open, label: 'Load Local'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<_CommandBarAction>(
          value: _CommandBarAction.copySnapshot,
          child:
              _SyncMenuItem(icon: Icons.content_copy, label: 'Copy Snapshot'),
        ),
        const PopupMenuItem<_CommandBarAction>(
          value: _CommandBarAction.exportSnapshotFile,
          child:
              _SyncMenuItem(icon: Icons.save_alt, label: 'Save Snapshot File'),
        ),
        const PopupMenuItem<_CommandBarAction>(
          value: _CommandBarAction.loadSnapshot,
          child: _SyncMenuItem(icon: Icons.upload_file, label: 'Load Snapshot'),
        ),
        const PopupMenuItem<_CommandBarAction>(
          value: _CommandBarAction.importSnapshotFile,
          child: _SyncMenuItem(
              icon: Icons.drive_folder_upload, label: 'Import Snapshot File'),
        ),
        if (singleRemoteFaction != null) ...[
          const PopupMenuDivider(),
          PopupMenuItem<_CommandBarAction>(
            value: _CommandBarAction.copyInvite,
            child: _SyncMenuItem(
              icon: Icons.person_add_alt_1,
              label: 'Copy Invite',
            ),
          ),
          PopupMenuItem<_CommandBarAction>(
            value: _CommandBarAction.exportInviteFile,
            child: _SyncMenuItem(
              icon: Icons.save_alt,
              label: 'Save Invite',
            ),
          ),
        ],
        const PopupMenuItem<_CommandBarAction>(
          value: _CommandBarAction.loadInvite,
          child:
              _SyncMenuItem(icon: Icons.person_add_alt_1, label: 'Load Invite'),
        ),
        const PopupMenuItem<_CommandBarAction>(
          value: _CommandBarAction.importInviteFile,
          child: _SyncMenuItem(
              icon: Icons.drive_folder_upload, label: 'Import Invite File'),
        ),
        const PopupMenuItem<_CommandBarAction>(
          value: _CommandBarAction.copyOrders,
          child: _SyncMenuItem(icon: Icons.ios_share, label: 'Copy Orders'),
        ),
        const PopupMenuItem<_CommandBarAction>(
          value: _CommandBarAction.exportOrdersFile,
          child:
              _SyncMenuItem(icon: Icons.save_alt, label: 'Export Orders File'),
        ),
        const PopupMenuItem<_CommandBarAction>(
          value: _CommandBarAction.applyOrders,
          child: _SyncMenuItem(
              icon: Icons.playlist_add_check, label: 'Apply Orders'),
        ),
        const PopupMenuItem<_CommandBarAction>(
          value: _CommandBarAction.importOrdersFile,
          child: _SyncMenuItem(
              icon: Icons.drive_folder_upload, label: 'Import Orders File'),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<_CommandBarAction>(
          value: _CommandBarAction.toggleHotseat,
          enabled: !game.isGameOver,
          child: _SyncMenuItem(
            icon: hasComputerOpponents ? Icons.groups : Icons.smart_toy,
            label:
                hasComputerOpponents ? 'Enable Hotseat' : 'Enable AI Opponents',
          ),
        ),
      ],
    );
  }

  void _handleMenuAction(BuildContext context, _CommandBarAction action) {
    if (action == _CommandBarAction.saveLocal) {
      onSaveGame();
      return;
    }
    if (action == _CommandBarAction.loadLocal) {
      onLoadSavedGame();
      return;
    }
    if (action == _CommandBarAction.copySnapshot) {
      Clipboard.setData(
        ClipboardData(
          text: GameCodec.encodeShareCode(GameCodec.encodeGame(game)),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Game snapshot code copied')),
      );
      return;
    }
    if (action == _CommandBarAction.exportSnapshotFile) {
      onExportSnapshotFile();
      return;
    }
    if (action == _CommandBarAction.loadSnapshot) {
      onLoadSnapshot();
      return;
    }
    if (action == _CommandBarAction.importSnapshotFile) {
      onImportSnapshotFile();
      return;
    }
    if (action == _CommandBarAction.copyInvite) {
      final singleRemoteFaction = _singleRemoteFaction();
      if (singleRemoteFaction != null) {
        onCopyInvite(singleRemoteFaction.id);
      }
      return;
    }
    if (action == _CommandBarAction.exportInviteFile) {
      final singleRemoteFaction = _singleRemoteFaction();
      if (singleRemoteFaction != null) {
        onExportInvite(singleRemoteFaction.id);
      }
      return;
    }
    if (action == _CommandBarAction.loadInvite) {
      onLoadInvite();
      return;
    }
    if (action == _CommandBarAction.importInviteFile) {
      onImportInviteFile();
      return;
    }
    if (action == _CommandBarAction.copyOrders) {
      onCopyOrders();
      return;
    }
    if (action == _CommandBarAction.exportOrdersFile) {
      onExportOrdersFile();
      return;
    }
    if (action == _CommandBarAction.applyOrders) {
      onApplyOrders();
      return;
    }
    if (action == _CommandBarAction.importOrdersFile) {
      onImportOrdersFile();
      return;
    }
    if (action == _CommandBarAction.toggleHotseat) {
      onToggleHotseat();
    }
  }

  Faction? _singleRemoteFaction() {
    if (!game.activeFactionCanIssueLocalOrders) {
      return null;
    }
    final remoteFactions =
        game.factions.where((faction) => faction.isRemote).toList();
    return remoteFactions.length == 1 ? remoteFactions.single : null;
  }

  Widget _endTurnButton() {
    final isComputerTurn = game.activeFaction.isComputer && !game.isGameOver;
    return ElevatedButton.icon(
      icon: Icon(isComputerTurn ? Icons.smart_toy : Icons.skip_next),
      label: Text(isComputerTurn ? 'Run AI' : 'End Turn'),
      onPressed: isComputerTurn
          ? onRunComputerTurn
          : game.activeFactionCanIssueLocalOrders
              ? onEndTurn
              : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFCCD6A6),
        foregroundColor: const Color(0xFF111418),
        minimumSize: const Size(112, 42),
      ),
    );
  }

  Widget _compactEndTurnButton() {
    final isComputerTurn = game.activeFaction.isComputer && !game.isGameOver;
    return SizedBox(
      width: 48,
      height: 42,
      child: ElevatedButton(
        onPressed: isComputerTurn
            ? onRunComputerTurn
            : game.activeFactionCanIssueLocalOrders
                ? onEndTurn
                : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFCCD6A6),
          foregroundColor: const Color(0xFF111418),
          padding: EdgeInsets.zero,
        ),
        child: Icon(isComputerTurn ? Icons.smart_toy : Icons.skip_next),
      ),
    );
  }
}

class _CompactTurnSummary extends StatelessWidget {
  const _CompactTurnSummary({
    Key? key,
    required this.game,
    required this.activeControl,
    required this.syncActionLabel,
  }) : super(key: key);

  final OpenDeadlockGame game;
  final String activeControl;
  final String syncActionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 42),
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Turn ${game.turn}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFF4F7FA),
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${game.activeFaction.name} | $activeControl | $syncActionLabel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFB9C5CE),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncMenuItem extends StatelessWidget {
  const _SyncMenuItem({
    Key? key,
    required this.icon,
    required this.label,
  }) : super(key: key);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFE9EEF2), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFE9EEF2)),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    Key? key,
    required this.icon,
    required this.label,
  }) : super(key: key);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF313B44),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF55616C)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: const Color(0xFFE9EEF2)),
          const SizedBox(width: 6),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFE9EEF2),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

enum _MapOverlayMode { terrain, food, industry, research }

double _clampMapZoomScale(double value) {
  if (value < _minimumMapZoomScale) {
    return _minimumMapZoomScale;
  }
  if (value > _maximumMapZoomScale) {
    return _maximumMapZoomScale;
  }
  return value;
}

String _mapZoomScaleLabel(double value) {
  return '${_clampMapZoomScale(value).toStringAsFixed(1)}x';
}

String _mapOverlayNameFor(_MapOverlayMode mode) {
  if (mode == _MapOverlayMode.food) {
    return 'food';
  }
  if (mode == _MapOverlayMode.industry) {
    return 'industry';
  }
  if (mode == _MapOverlayMode.research) {
    return 'research';
  }
  return 'terrain';
}

String _mapOverlayTooltipFor(_MapOverlayMode mode) {
  if (mode == _MapOverlayMode.food) {
    return 'Food overlay';
  }
  if (mode == _MapOverlayMode.industry) {
    return 'Industry overlay';
  }
  if (mode == _MapOverlayMode.research) {
    return 'Research overlay';
  }
  return 'Terrain overlay';
}

IconData _mapOverlayIconFor(_MapOverlayMode mode) {
  if (mode == _MapOverlayMode.food) {
    return Icons.grass;
  }
  if (mode == _MapOverlayMode.industry) {
    return Icons.precision_manufacturing;
  }
  if (mode == _MapOverlayMode.research) {
    return Icons.science;
  }
  return Icons.public;
}

Color _mapOverlayColorFor(_MapOverlayMode mode) {
  if (mode == _MapOverlayMode.food) {
    return const Color(0xFF83D36A);
  }
  if (mode == _MapOverlayMode.industry) {
    return const Color(0xFFE0A650);
  }
  if (mode == _MapOverlayMode.research) {
    return const Color(0xFF73C9D4);
  }
  return const Color(0xFFE9EEF2);
}

int _resourceValueForOverlay(TileYield yields, _MapOverlayMode mode) {
  if (mode == _MapOverlayMode.food) {
    return yields.food;
  }
  if (mode == _MapOverlayMode.industry) {
    return yields.industry;
  }
  if (mode == _MapOverlayMode.research) {
    return yields.research;
  }
  return yields.food + yields.industry + yields.research;
}

double _resourceOverlayAlphaFor(int value) {
  if (value <= 0) {
    return 0.06;
  }
  final alpha = 0.10 + (value * 0.10);
  if (alpha > 0.48) {
    return 0.48;
  }
  return alpha;
}

class _MapOverlayControl extends StatelessWidget {
  const _MapOverlayControl({
    Key? key,
    required this.selectedMode,
    required this.onChanged,
  }) : super(key: key);

  final _MapOverlayMode selectedMode;
  final ValueChanged<_MapOverlayMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xCC202B34),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _MapOverlayMode.values
              .map((mode) => _overlayButtonFor(mode))
              .toList(),
        ),
      ),
    );
  }

  Widget _overlayButtonFor(_MapOverlayMode mode) {
    final isSelected = mode == selectedMode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Tooltip(
        message: _mapOverlayTooltipFor(mode),
        child: InkWell(
          key: ValueKey<String>('map-overlay-${_mapOverlayNameFor(mode)}'),
          borderRadius: BorderRadius.circular(5),
          onTap: () => onChanged(mode),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFE9EEF2)
                  : const Color(0xFF313B44),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFF6E05E)
                    : const Color(0xFF55616C),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Icon(
              _mapOverlayIconFor(mode),
              size: 18,
              color: isSelected
                  ? const Color(0xFF111418)
                  : const Color(0xFFE9EEF2),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapZoomControl extends StatelessWidget {
  const _MapZoomControl({
    Key? key,
    required this.zoomScale,
    required this.onChanged,
  }) : super(key: key);

  final double zoomScale;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final clampedScale = _clampMapZoomScale(zoomScale);
    final canZoomOut = clampedScale > _minimumMapZoomScale;
    final canZoomIn = clampedScale < _maximumMapZoomScale;

    return Material(
      color: const Color(0xCC202B34),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const ValueKey<String>('map-zoom-out'),
              tooltip: 'Zoom out',
              color: const Color(0xFFE9EEF2),
              icon: const Icon(Icons.zoom_out, size: 18),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(
                width: 32,
                height: 32,
              ),
              onPressed: canZoomOut
                  ? () => onChanged(clampedScale - _mapZoomStep)
                  : null,
            ),
            SizedBox(
              width: 86,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                    disabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                ),
                child: Slider(
                  key: const ValueKey<String>('map-zoom-slider'),
                  value: clampedScale,
                  min: _minimumMapZoomScale,
                  max: _maximumMapZoomScale,
                  divisions: _mapZoomDivisions,
                  label: _mapZoomScaleLabel(clampedScale),
                  activeColor: const Color(0xFFCCD6A6),
                  inactiveColor: const Color(0xFF55616C),
                  onChanged: onChanged,
                ),
              ),
            ),
            SizedBox(
              width: 34,
              child: Text(
                _mapZoomScaleLabel(clampedScale),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFE9EEF2),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey<String>('map-zoom-in'),
              tooltip: 'Zoom map',
              color: const Color(0xFFE9EEF2),
              icon: const Icon(Icons.zoom_in, size: 18),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(
                width: 32,
                height: 32,
              ),
              onPressed: canZoomIn
                  ? () => onChanged(clampedScale + _mapZoomStep)
                  : null,
            ),
            IconButton(
              key: const ValueKey<String>('map-fit-zoom'),
              tooltip: 'Fit map',
              color: const Color(0xFFE9EEF2),
              icon: const Icon(Icons.fit_screen, size: 18),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(
                width: 32,
                height: 32,
              ),
              onPressed:
                  canZoomOut ? () => onChanged(_minimumMapZoomScale) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanetMap extends StatelessWidget {
  const _PlanetMap({
    Key? key,
    required this.game,
    required this.selectedX,
    required this.selectedY,
    required this.selectedUnitId,
    required this.zoomScale,
    required this.overlayMode,
    required this.onZoomChanged,
    required this.onOverlayChanged,
    required this.onSelected,
  }) : super(key: key);

  final OpenDeadlockGame game;
  final int selectedX;
  final int selectedY;
  final String? selectedUnitId;
  final double zoomScale;
  final _MapOverlayMode overlayMode;
  final ValueChanged<double> onZoomChanged;
  final ValueChanged<_MapOverlayMode> onOverlayChanged;
  final void Function(int x, int y) onSelected;

  @override
  Widget build(BuildContext context) {
    final selectedUnit = _selectedUnit();

    return Container(
      color: const Color(0xFF111418),
      alignment: Alignment.center,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: _mapSurface(selectedUnit),
            ),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: _MapZoomControl(
              zoomScale: zoomScale,
              onChanged: onZoomChanged,
            ),
          ),
          Positioned(
            left: 10,
            top: 10,
            child: _MapOverlayControl(
              selectedMode: overlayMode,
              onChanged: onOverlayChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapSurface(Unit? selectedUnit) {
    final isZoomed = zoomScale > _minimumMapZoomScale;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!isZoomed) {
          return Center(
            child: AspectRatio(
              aspectRatio: game.width / game.height,
              child: _mapGrid(selectedUnit),
            ),
          );
        }

        final fittedTileExtent = _fittedTileExtentFor(constraints);
        final tileExtent = fittedTileExtent * zoomScale;
        return SingleChildScrollView(
          key: const ValueKey<String>('map-scroll-y'),
          child: SingleChildScrollView(
            key: const ValueKey<String>('map-scroll-x'),
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: game.width * tileExtent,
              height: game.height * tileExtent,
              child: _mapGrid(selectedUnit),
            ),
          ),
        );
      },
    );
  }

  double _fittedTileExtentFor(BoxConstraints constraints) {
    final widthExtent = constraints.maxWidth / game.width;
    final heightExtent = constraints.maxHeight / game.height;
    return widthExtent < heightExtent ? widthExtent : heightExtent;
  }

  Widget _mapGrid(Unit? selectedUnit) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: game.width,
        childAspectRatio: 1,
      ),
      itemCount: game.tiles.length,
      itemBuilder: (context, index) {
        final tile = game.tiles[index];
        final isExplored = tile.isExploredBy(game.activeFactionId);
        final isVisible =
            game.isSectorVisibleTo(game.activeFactionId, tile.x, tile.y);
        final isKnown = isExplored || isVisible;
        final isSelected = tile.x == selectedX && tile.y == selectedY;
        final colony = isExplored ? game.colonyAt(tile.x, tile.y) : null;
        final assignedColony =
            isExplored ? game.assignedColonyForSector(tile.x, tile.y) : null;
        final owner = isExplored ? game.factionById(tile.ownerId) : null;
        final unit = isKnown
            ? game.visibleUnitAt(game.activeFactionId, tile.x, tile.y)
            : null;
        final unitOwner = game.factionById(unit == null ? null : unit.ownerId);
        final assignedOwner = game.factionById(
          assignedColony == null ? null : assignedColony.ownerId,
        );
        final actionHint = _actionHintFor(tile, selectedUnit, isKnown);

        return _MapTileButton(
          tile: tile,
          isExplored: isExplored,
          isVisible: isVisible,
          ownerColor: owner == null ? null : Color(owner.colorValue),
          assignedColor:
              assignedOwner == null ? null : Color(assignedOwner.colorValue),
          overlayMode: overlayMode,
          unit: unit,
          unitColor: unitOwner == null ? null : Color(unitOwner.colorValue),
          hasColony: colony != null,
          isAssignedSector: assignedColony != null,
          isSelected: isSelected,
          isSelectedUnit: unit != null && unit.id == selectedUnitId,
          actionHint: actionHint,
          onTap: () => onSelected(tile.x, tile.y),
        );
      },
    );
  }

  Unit? _selectedUnit() {
    if (selectedUnitId == null) {
      return null;
    }
    for (final unit in game.units) {
      if (unit.id == selectedUnitId) {
        return unit;
      }
    }
    return null;
  }

  _TileActionHint _actionHintFor(
    PlanetTile tile,
    Unit? selectedUnit,
    bool isExplored,
  ) {
    if (selectedUnit == null ||
        !game.activeFactionCanIssueLocalOrders ||
        selectedUnit.ownerId != game.activeFactionId ||
        !isExplored ||
        selectedUnit.movesRemaining <= 0 ||
        (selectedUnit.x == tile.x && selectedUnit.y == tile.y)) {
      return _TileActionHint.none;
    }
    if (_manhattanDistance(selectedUnit.x, selectedUnit.y, tile.x, tile.y) !=
        1) {
      return _TileActionHint.none;
    }
    if (!OpenDeadlockGame.isTerrainPassable(tile.terrain)) {
      return _TileActionHint.none;
    }
    if (selectedUnit.movesRemaining <
        OpenDeadlockGame.movementCostForTerrain(tile.terrain)) {
      return _TileActionHint.none;
    }

    final occupyingUnit =
        game.visibleUnitAt(game.activeFactionId, tile.x, tile.y);
    if (occupyingUnit != null && occupyingUnit.id != selectedUnit.id) {
      if (occupyingUnit.ownerId == selectedUnit.ownerId) {
        return _TileActionHint.none;
      }
      return game.areAtWar(selectedUnit.ownerId, occupyingUnit.ownerId)
          ? _TileActionHint.attack
          : _TileActionHint.none;
    }

    final targetColony = game.colonyAt(tile.x, tile.y);
    if (targetColony != null && targetColony.ownerId != selectedUnit.ownerId) {
      return game.areAtWar(selectedUnit.ownerId, targetColony.ownerId)
          ? _TileActionHint.assault
          : _TileActionHint.none;
    }

    if (!game.canFactionTraverseSector(selectedUnit.ownerId, tile)) {
      return _TileActionHint.none;
    }
    return _TileActionHint.move;
  }

  int _manhattanDistance(int ax, int ay, int bx, int by) {
    return _absolute(ax - bx) + _absolute(ay - by);
  }

  int _absolute(int value) {
    return value < 0 ? -value : value;
  }
}

enum _TileActionHint { none, move, attack, assault }

class _MapTileButton extends StatelessWidget {
  const _MapTileButton({
    Key? key,
    required this.tile,
    required this.isExplored,
    required this.isVisible,
    required this.ownerColor,
    required this.assignedColor,
    required this.overlayMode,
    required this.unit,
    required this.unitColor,
    required this.hasColony,
    required this.isAssignedSector,
    required this.isSelected,
    required this.isSelectedUnit,
    required this.actionHint,
    required this.onTap,
  }) : super(key: key);

  final PlanetTile tile;
  final bool isExplored;
  final bool isVisible;
  final Color? ownerColor;
  final Color? assignedColor;
  final _MapOverlayMode overlayMode;
  final Unit? unit;
  final Color? unitColor;
  final bool hasColony;
  final bool isAssignedSector;
  final bool isSelected;
  final bool isSelectedUnit;
  final _TileActionHint actionHint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isKnown = isExplored || isVisible;
    final borderColor = isSelected
        ? const Color(0xFFF6E05E)
        : _borderColorForActionHint(actionHint);
    final borderWidth = isSelected
        ? 3.0
        : actionHint == _TileActionHint.none
            ? 1.0
            : 2.0;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: borderWidth),
              borderRadius: BorderRadius.circular(5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    key: ValueKey<String>('terrain-${tile.x}-${tile.y}'),
                    painter: _TerrainTilePainter(
                      terrain: tile.terrain,
                      yields: tile.yields,
                      isExplored: isExplored,
                      isVisible: isVisible,
                      ownerColor: ownerColor,
                      overlayMode: overlayMode,
                      isSelected: isSelected,
                    ),
                  ),
                ),
                if (isKnown && overlayMode != _MapOverlayMode.terrain)
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      key: ValueKey<String>(
                        'resource-overlay-${_mapOverlayNameFor(overlayMode)}-${tile.x}-${tile.y}',
                      ),
                      width: 27,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.34),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _mapOverlayColorFor(overlayMode)
                              .withValues(alpha: 0.82),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${_resourceValueForOverlay(tile.yields, overlayMode)}',
                          style: const TextStyle(
                            color: Color(0xFFEFF4F8),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (isExplored && ownerColor != null)
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: ownerColor,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(5),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                if (isExplored && isAssignedSector)
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      key: ValueKey<String>('work-sector-${tile.x}-${tile.y}'),
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: assignedColor ?? const Color(0xFFE9EEF2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFF111418),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.grid_view,
                        size: 11,
                        color: Color(0xFF111418),
                      ),
                    ),
                  ),
                if (actionHint != _TileActionHint.none)
                  Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      key: ValueKey<String>(
                        'action-hint-${_nameForActionHint(actionHint)}-${tile.x}-${tile.y}',
                      ),
                      width: 19,
                      height: 19,
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _colorForActionHint(actionHint),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF111418),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        _iconForActionHint(actionHint),
                        size: 12,
                        color: const Color(0xFF111418),
                      ),
                    ),
                  ),
                if (isExplored && hasColony)
                  Center(
                    child: Icon(
                      Icons.location_city,
                      color: Colors.white.withValues(alpha: 0.92),
                      size: 24,
                    ),
                  ),
                if (isKnown && unit == null)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Tooltip(
                      message: _terrainLabel(tile.terrain),
                      child: Container(
                        key: ValueKey<String>(
                            'terrain-badge-${tile.x}-${tile.y}'),
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.32),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          _iconForTerrain(tile.terrain),
                          size: 13,
                          color: _iconColorForTerrain(tile.terrain),
                        ),
                      ),
                    ),
                  ),
                if (isKnown && unit != null)
                  Align(
                    alignment:
                        hasColony ? Alignment.bottomRight : Alignment.center,
                    child: Container(
                      width: isSelectedUnit ? 28 : 24,
                      height: isSelectedUnit ? 28 : 24,
                      decoration: BoxDecoration(
                        color: unitColor ?? const Color(0xFFE9EEF2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelectedUnit
                              ? const Color(0xFFF6E05E)
                              : Colors.white,
                          width: isSelectedUnit ? 3 : 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.explore,
                        size: 15,
                        color: Color(0xFF111418),
                      ),
                    ),
                  ),
                if (isKnown)
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 5, bottom: 4),
                      child: Text(
                        '${tile.yields.food}/${tile.yields.industry}/${tile.yields.research}',
                        style: const TextStyle(
                          color: Color(0xFFEFF4F8),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _borderColorForActionHint(_TileActionHint hint) {
    if (hint == _TileActionHint.move) {
      return const Color(0xFF8DD7A5);
    }
    if (hint == _TileActionHint.attack) {
      return const Color(0xFFE85D5D);
    }
    if (hint == _TileActionHint.assault) {
      return const Color(0xFFE6A44E);
    }
    return const Color(0xFF202A31);
  }

  Color _colorForActionHint(_TileActionHint hint) {
    if (hint == _TileActionHint.move) {
      return const Color(0xFF8DD7A5);
    }
    if (hint == _TileActionHint.attack) {
      return const Color(0xFFE85D5D);
    }
    return const Color(0xFFE6A44E);
  }

  IconData _iconForActionHint(_TileActionHint hint) {
    if (hint == _TileActionHint.move) {
      return Icons.arrow_forward;
    }
    if (hint == _TileActionHint.attack) {
      return Icons.gps_fixed;
    }
    return Icons.location_city;
  }

  String _nameForActionHint(_TileActionHint hint) {
    if (hint == _TileActionHint.move) {
      return 'move';
    }
    if (hint == _TileActionHint.attack) {
      return 'attack';
    }
    if (hint == _TileActionHint.assault) {
      return 'assault';
    }
    return 'none';
  }

  IconData _iconForTerrain(String terrain) {
    if (terrain == 'plains') {
      return Icons.grass;
    }
    if (terrain == 'forest') {
      return Icons.park;
    }
    if (terrain == 'ridge') {
      return Icons.terrain;
    }
    if (terrain == 'water') {
      return Icons.water;
    }
    if (terrain == 'ruins') {
      return Icons.account_balance;
    }
    return Icons.public;
  }

  Color _iconColorForTerrain(String terrain) {
    if (terrain == 'plains') {
      return const Color(0xFFD3E48E);
    }
    if (terrain == 'forest') {
      return const Color(0xFF8FD28B);
    }
    if (terrain == 'ridge') {
      return const Color(0xFFE0B27C);
    }
    if (terrain == 'water') {
      return const Color(0xFF9FD7EA);
    }
    if (terrain == 'ruins') {
      return const Color(0xFFD6C8F0);
    }
    return const Color(0xFFE9EEF2);
  }

  String _terrainLabel(String terrain) {
    if (terrain == 'plains') {
      return 'Plains';
    }
    if (terrain == 'forest') {
      return 'Forest';
    }
    if (terrain == 'ridge') {
      return 'Ridge';
    }
    if (terrain == 'water') {
      return 'Water';
    }
    if (terrain == 'ruins') {
      return 'Ruins';
    }
    if (terrain.isEmpty) {
      return terrain;
    }
    return '${terrain[0].toUpperCase()}${terrain.substring(1)}';
  }
}

class _TerrainTilePainter extends CustomPainter {
  const _TerrainTilePainter({
    required this.terrain,
    required this.yields,
    required this.isExplored,
    required this.isVisible,
    required this.ownerColor,
    required this.overlayMode,
    required this.isSelected,
  });

  final String terrain;
  final TileYield yields;
  final bool isExplored;
  final bool isVisible;
  final Color? ownerColor;
  final _MapOverlayMode overlayMode;
  final bool isSelected;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final isKnown = isExplored || isVisible;
    final baseColor =
        isKnown ? _terrainBaseColor(terrain) : const Color(0xFF050607);
    final accentColor =
        isKnown ? _terrainAccentColor(terrain) : const Color(0xFF151A1F);

    canvas.drawRect(rect, Paint()..color = baseColor);
    _drawShading(canvas, size, baseColor);
    if (isKnown) {
      _drawTerrainPattern(canvas, size, terrain, accentColor);
      if (overlayMode != _MapOverlayMode.terrain) {
        _drawResourceOverlay(canvas, size, yields, overlayMode);
      }
      if (ownerColor != null) {
        _drawOwnershipWash(canvas, size, ownerColor!);
      }
      if (!isVisible) {
        _drawMemoryFog(canvas, size);
      }
    } else {
      _drawFog(canvas, size);
    }
    if (isSelected) {
      _drawSelectedGlow(canvas, size);
    }
  }

  @override
  bool shouldRepaint(_TerrainTilePainter oldDelegate) {
    return oldDelegate.terrain != terrain ||
        oldDelegate.yields != yields ||
        oldDelegate.isExplored != isExplored ||
        oldDelegate.isVisible != isVisible ||
        oldDelegate.ownerColor != ownerColor ||
        oldDelegate.overlayMode != overlayMode ||
        oldDelegate.isSelected != isSelected;
  }

  static Color _terrainBaseColor(String terrain) {
    if (terrain == 'plains') {
      return const Color(0xFF587643);
    }
    if (terrain == 'forest') {
      return const Color(0xFF264F43);
    }
    if (terrain == 'ridge') {
      return const Color(0xFF756257);
    }
    if (terrain == 'water') {
      return const Color(0xFF28657D);
    }
    if (terrain == 'ruins') {
      return const Color(0xFF675682);
    }
    return const Color(0xFF575F66);
  }

  static Color _terrainAccentColor(String terrain) {
    if (terrain == 'plains') {
      return const Color(0xFF9AAE68);
    }
    if (terrain == 'forest') {
      return const Color(0xFF6FA06E);
    }
    if (terrain == 'ridge') {
      return const Color(0xFFC29D78);
    }
    if (terrain == 'water') {
      return const Color(0xFF79BCD1);
    }
    if (terrain == 'ruins') {
      return const Color(0xFFC2B1E3);
    }
    return const Color(0xFFAAB2BA);
  }

  void _drawShading(Canvas canvas, Size size, Color baseColor) {
    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), highlight);
    canvas.drawLine(Offset.zero, Offset(0, size.height), highlight);

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      shadow,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, size.height),
      shadow,
    );
  }

  void _drawTerrainPattern(
    Canvas canvas,
    Size size,
    String terrain,
    Color accentColor,
  ) {
    if (terrain == 'forest') {
      _drawForest(canvas, size, accentColor);
      return;
    }
    if (terrain == 'ridge') {
      _drawRidge(canvas, size, accentColor);
      return;
    }
    if (terrain == 'water') {
      _drawWater(canvas, size, accentColor);
      return;
    }
    if (terrain == 'ruins') {
      _drawRuins(canvas, size, accentColor);
      return;
    }
    _drawPlains(canvas, size, accentColor);
  }

  void _drawPlains(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.28)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    for (var y = size.height * 0.28; y < size.height; y += size.height * 0.28) {
      canvas.drawLine(
        Offset(size.width * 0.18, y),
        Offset(size.width * 0.82, y + size.height * 0.05),
        paint,
      );
    }
  }

  void _drawForest(Canvas canvas, Size size, Color color) {
    final paint = Paint()..color = color.withValues(alpha: 0.38);
    final trunks = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    final centers = <Offset>[
      Offset(size.width * 0.34, size.height * 0.42),
      Offset(size.width * 0.62, size.height * 0.34),
      Offset(size.width * 0.54, size.height * 0.66),
    ];
    for (final center in centers) {
      final path = Path()
        ..moveTo(center.dx, center.dy - size.height * 0.16)
        ..lineTo(center.dx - size.width * 0.12, center.dy + size.height * 0.10)
        ..lineTo(center.dx + size.width * 0.12, center.dy + size.height * 0.10)
        ..close();
      canvas.drawPath(path, paint);
      canvas.drawLine(
        Offset(center.dx, center.dy + size.height * 0.06),
        Offset(center.dx, center.dy + size.height * 0.18),
        trunks,
      );
    }
  }

  void _drawRidge(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.36)
      ..strokeWidth = 1.7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var x = -size.width * 0.2; x < size.width; x += size.width * 0.28) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.width * 0.48, 0),
        paint,
      );
    }
  }

  void _drawWater(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.38)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    for (var y = size.height * 0.30; y < size.height; y += size.height * 0.26) {
      final path = Path()..moveTo(size.width * 0.16, y);
      path.cubicTo(
        size.width * 0.34,
        y - size.height * 0.12,
        size.width * 0.48,
        y + size.height * 0.12,
        size.width * 0.66,
        y,
      );
      path.cubicTo(
        size.width * 0.76,
        y - size.height * 0.06,
        size.width * 0.84,
        y - size.height * 0.02,
        size.width * 0.92,
        y,
      );
      canvas.drawPath(path, paint);
    }
  }

  void _drawRuins(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final blocks = <Rect>[
      Rect.fromLTWH(
        size.width * 0.20,
        size.height * 0.26,
        size.width * 0.26,
        size.height * 0.22,
      ),
      Rect.fromLTWH(
        size.width * 0.46,
        size.height * 0.48,
        size.width * 0.30,
        size.height * 0.24,
      ),
    ];
    for (final block in blocks) {
      canvas.drawRect(block, paint);
    }
    canvas.drawLine(
      Offset(size.width * 0.22, size.height * 0.74),
      Offset(size.width * 0.82, size.height * 0.24),
      paint,
    );
  }

  void _drawOwnershipWash(Canvas canvas, Size size, Color color) {
    final paint = Paint()..color = color.withValues(alpha: 0.16);
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.62, size.height)
      ..lineTo(size.width, size.height * 0.42)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawResourceOverlay(
    Canvas canvas,
    Size size,
    TileYield yields,
    _MapOverlayMode mode,
  ) {
    final value = _resourceValueForOverlay(yields, mode);
    final alpha = _resourceOverlayAlphaFor(value);
    final color = _mapOverlayColorFor(mode);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = color.withValues(alpha: alpha),
    );
  }

  void _drawFog(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF313B44).withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (var x = -size.width; x < size.width * 2; x += size.width * 0.24) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.width, size.height),
        paint,
      );
    }
  }

  void _drawMemoryFog(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF050607).withValues(alpha: 0.28),
    );
    final paint = Paint()
      ..color = const Color(0xFFE9EEF2).withValues(alpha: 0.10)
      ..strokeWidth = 1;
    for (var x = -size.width; x < size.width * 2; x += size.width * 0.32) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.width, 0),
        paint,
      );
    }
  }

  void _drawSelectedGlow(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF6E05E).withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, paint);
  }
}

class _SelectionPanel extends StatelessWidget {
  const _SelectionPanel({
    Key? key,
    required this.game,
    required this.latestSaveSlot,
    required this.orderExportBaseCommandCount,
    required this.lastSyncStatus,
    required this.tile,
    required this.isExplored,
    required this.colony,
    required this.unit,
    required this.onFoundColony,
    required this.onRecoverUnit,
    required this.onConstructionChanged,
    required this.onRushConstruction,
    required this.onFocusChanged,
    required this.onApplyConstructionToAll,
    required this.onApplyFocusToAll,
    required this.onAssignBestSectors,
    required this.onReleaseAllSectors,
    required this.onSectorAssignmentChanged,
    required this.onSelectColony,
    required this.onResearchChanged,
    required this.onFundResearch,
    required this.onFactionControlChanged,
    required this.onFactionDifficultyChanged,
    required this.onTaxPolicyChanged,
    required this.onDiplomacyChanged,
    required this.onIntelScan,
    required this.onSabotage,
    required this.onCopyInvite,
    required this.onExportInvite,
    required this.canUndoLastOrder,
    required this.onUndoLastOrder,
  }) : super(key: key);

  final OpenDeadlockGame game;
  final SavedGameSlot? latestSaveSlot;
  final int orderExportBaseCommandCount;
  final String? lastSyncStatus;
  final PlanetTile tile;
  final bool isExplored;
  final Colony? colony;
  final Unit? unit;
  final void Function(Unit unit) onFoundColony;
  final void Function(Unit unit) onRecoverUnit;
  final void Function(String colonyId, String construction)
      onConstructionChanged;
  final void Function(String colonyId, int industry) onRushConstruction;
  final void Function(String colonyId, String focus) onFocusChanged;
  final void Function(Colony colony) onApplyConstructionToAll;
  final void Function(Colony colony) onApplyFocusToAll;
  final void Function(Colony colony) onAssignBestSectors;
  final void Function(Colony colony) onReleaseAllSectors;
  final void Function(String colonyId, PlanetTile tile, bool assigned)
      onSectorAssignmentChanged;
  final void Function(Colony colony) onSelectColony;
  final void Function(String researchProject) onResearchChanged;
  final void Function(int research) onFundResearch;
  final void Function(String factionId, String controlMode)
      onFactionControlChanged;
  final void Function(String factionId, String difficulty)
      onFactionDifficultyChanged;
  final void Function(String taxPolicy) onTaxPolicyChanged;
  final void Function(String targetFactionId, String status) onDiplomacyChanged;
  final void Function(String targetFactionId) onIntelScan;
  final void Function(String targetFactionId) onSabotage;
  final Future<void> Function(String factionId) onCopyInvite;
  final Future<void> Function(String factionId) onExportInvite;
  final bool canUndoLastOrder;
  final VoidCallback onUndoLastOrder;

  @override
  Widget build(BuildContext context) {
    final owner = game.factionById(tile.ownerId);
    final canIssueLocalOrders = game.activeFactionCanIssueLocalOrders;
    final newsGroups = _newsGroupsFor(game);
    final tacticalReports = _tacticalReports(game);
    final assignedColony =
        isExplored ? game.assignedColonyForSector(tile.x, tile.y) : null;
    final activeColonies = game.colonies
        .where((currentColony) => currentColony.ownerId == game.activeFactionId)
        .toList(growable: false);
    final preferredColony = isExplored &&
            canIssueLocalOrders &&
            assignedColony == null
        ? game.preferredColonyForSector(game.activeFactionId, tile.x, tile.y)
        : null;

    return Container(
      color: const Color(0xFF182027),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (game.isGameOver) ...[
            _VictoryBanner(game: game),
            const SizedBox(height: 16),
            _PostGameStatsDetail(game: game),
            const SizedBox(height: 16),
          ],
          Text(
            colony == null
                ? 'Sector ${tile.x + 1}, ${tile.y + 1}'
                : colony!.name,
            style: const TextStyle(
              color: Color(0xFFF4F7FA),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (!isExplored)
            const _UnexploredSector()
          else ...[
            _DetailRow(label: 'Terrain', value: _titleCase(tile.terrain)),
            _DetailRow(
              label: 'Move Cost',
              value: OpenDeadlockGame.isTerrainPassable(tile.terrain)
                  ? '${OpenDeadlockGame.movementCostForTerrain(tile.terrain)}'
                  : 'Blocked',
            ),
            _DetailRow(
                label: 'Controller',
                value: owner == null ? 'Unclaimed' : owner.name),
            _DetailRow(
              label: 'Yield',
              value:
                  '${tile.yields.food} food / ${tile.yields.industry} industry / ${tile.yields.research} research',
            ),
          ],
          if (isExplored && unit != null) ...[
            const SizedBox(height: 12),
            _UnitDetail(
              game: game,
              unit: unit!,
              canFoundColony: _canFoundColony(owner, unit!),
              canRecover: _canRecoverUnit(unit!),
              onFoundColony: () => onFoundColony(unit!),
              onRecover: () => onRecoverUnit(unit!),
            ),
          ],
          const SizedBox(height: 18),
          if (isExplored)
            if (colony == null)
              _EmptySector(
                tile: tile,
                assignedColony: assignedColony,
                preferredColony: preferredColony,
                canEdit: canIssueLocalOrders,
                onAssign: preferredColony == null
                    ? null
                    : () => onSectorAssignmentChanged(
                          preferredColony.id,
                          tile,
                          true,
                        ),
                onUnassign: assignedColony == null ||
                        assignedColony.ownerId != game.activeFactionId
                    ? null
                    : () => onSectorAssignmentChanged(
                          assignedColony.id,
                          tile,
                          false,
                        ),
              )
            else
              _ColonyDetail(
                game: game,
                colony: colony!,
                canEdit: canIssueLocalOrders &&
                    colony!.ownerId == game.activeFactionId,
                onConstructionChanged: onConstructionChanged,
                onRushConstruction: onRushConstruction,
                onFocusChanged: onFocusChanged,
                onApplyConstructionToAll: onApplyConstructionToAll,
                onApplyFocusToAll: onApplyFocusToAll,
                onAssignBestSectors: onAssignBestSectors,
                onReleaseAllSectors: onReleaseAllSectors,
              ),
          if (activeColonies.length > 1) ...[
            const SizedBox(height: 18),
            _ColonyOverviewDetail(
              game: game,
              colonies: activeColonies,
              selectedColonyId:
                  colony?.ownerId == game.activeFactionId ? colony?.id : null,
              onSelectColony: onSelectColony,
            ),
          ],
          if (activeColonies.isNotEmpty) ...[
            const SizedBox(height: 18),
            _PendingBuildsDetail(
              game: game,
              colonies: activeColonies,
              onSelectColony: onSelectColony,
            ),
          ],
          const SizedBox(height: 18),
          _FactionTraitDetail(faction: game.activeFaction),
          const SizedBox(height: 18),
          _TaxPolicyDetail(
            faction: game.activeFaction,
            canEdit: canIssueLocalOrders,
            onTaxPolicyChanged: onTaxPolicyChanged,
          ),
          const SizedBox(height: 18),
          _WorldOverviewDetail(game: game),
          const SizedBox(height: 18),
          _FactionControlDetail(
            game: game,
            canEdit: !game.isGameOver,
            onFactionControlChanged: onFactionControlChanged,
            onFactionDifficultyChanged: onFactionDifficultyChanged,
          ),
          const SizedBox(height: 18),
          _DiplomacyDetail(
            game: game,
            faction: game.activeFaction,
            canEdit: canIssueLocalOrders,
            onDiplomacyChanged: onDiplomacyChanged,
            onIntelScan: onIntelScan,
            onSabotage: onSabotage,
          ),
          const SizedBox(height: 18),
          _ResearchDetail(
            faction: game.activeFaction,
            canEdit: canIssueLocalOrders,
            onResearchChanged: onResearchChanged,
            onFundResearch: onFundResearch,
          ),
          const SizedBox(height: 18),
          _SyncStatusDetail(
            game: game,
            latestSaveSlot: latestSaveSlot,
            orderExportBaseCommandCount: orderExportBaseCommandCount,
            lastSyncStatus: lastSyncStatus,
            onCopyInvite: onCopyInvite,
            onExportInvite: onExportInvite,
          ),
          if (game.activeFaction.isComputer && !game.isGameOver) ...[
            const SizedBox(height: 18),
            _ComputerOrdersDetail(game: game),
          ],
          const SizedBox(height: 18),
          _PendingOrdersDetail(
            game: game,
            fromCommandIndex: orderExportBaseCommandCount,
            canUndoLastOrder: canUndoLastOrder,
            onUndoLastOrder: onUndoLastOrder,
          ),
          if (newsGroups.isNotEmpty) ...[
            const SizedBox(height: 18),
            _NewsSummaryDetail(groups: newsGroups),
          ],
          if (tacticalReports.isNotEmpty) ...[
            const SizedBox(height: 18),
            _TacticalLogDetail(reports: tacticalReports),
          ],
          const SizedBox(height: 18),
          const Text(
            'Turn Log',
            style: TextStyle(
              color: Color(0xFFF4F7FA),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...game.reports.take(5).map((report) => _ReportLine(report: report)),
        ],
      ),
    );
  }

  String _titleCase(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value.substring(0, 1).toUpperCase() + value.substring(1);
  }

  bool _canFoundColony(Faction? owner, Unit unit) {
    return isExplored &&
        game.activeFactionCanIssueLocalOrders &&
        owner != null &&
        unit.ownerId == game.activeFactionId &&
        owner.id == game.activeFactionId &&
        tile.terrain != 'water' &&
        colony == null;
  }

  bool _canRecoverUnit(Unit unit) {
    return isExplored &&
        game.activeFactionCanIssueLocalOrders &&
        unit.ownerId == game.activeFactionId &&
        unit.movesRemaining > 0 &&
        unit.health < OpenDeadlockGame.maxHealthFor(unit.type);
  }

  List<TurnReport> _tacticalReports(OpenDeadlockGame source) {
    final tacticalReports = <TurnReport>[];
    for (final report in source.reports) {
      if (report.isTactical) {
        tacticalReports.add(report);
      }
    }
    return tacticalReports.take(4).toList(growable: false);
  }
}

class _VictoryBanner extends StatelessWidget {
  const _VictoryBanner({
    Key? key,
    required this.game,
  }) : super(key: key);

  final OpenDeadlockGame game;

  @override
  Widget build(BuildContext context) {
    final winnerName = game.winningFaction?.name ?? 'A faction';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF3B3320),
        border: Border.all(color: const Color(0xFFD9B66F)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.emoji_events, color: Color(0xFFD9B66F)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$winnerName wins',
                  style: const TextStyle(
                    color: Color(0xFFFFF5D6),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  game.winningVictoryMessage,
                  style: const TextStyle(color: Color(0xFFF0DEC2)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FactionTraitDetail extends StatelessWidget {
  const _FactionTraitDetail({
    Key? key,
    required this.faction,
  }) : super(key: key);

  final Faction faction;

  @override
  Widget build(BuildContext context) {
    final traits = OpenDeadlockGame.traitsFor(faction);
    final race = OpenDeadlockGame.raceProfileFor(faction);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF202B34),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.groups, color: Color(faction.colorValue), size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  faction.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFF4F7FA),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DetailRow(label: 'Race', value: race.name),
          _DetailRow(
            label: 'AI Profile',
            value: Faction.aiPersonalityLabelFor(faction.aiPersonality),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              Faction.aiPersonalityDescriptionFor(faction.aiPersonality),
              style: const TextStyle(color: Color(0xFFE9EEF2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              race.description,
              style: const TextStyle(color: Color(0xFFE9EEF2)),
            ),
          ),
          const SizedBox(height: 6),
          if (traits.isEmpty)
            const Text(
              'No faction traits.',
              style: TextStyle(color: Color(0xFFE9EEF2)),
            )
          else
            ...traits.map(
              (trait) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(
                        trait.name,
                        style: const TextStyle(
                          color: Color(0xFF9FB0BE),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        trait.description,
                        style: const TextStyle(color: Color(0xFFE9EEF2)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TaxPolicyDetail extends StatelessWidget {
  const _TaxPolicyDetail({
    Key? key,
    required this.faction,
    required this.canEdit,
    required this.onTaxPolicyChanged,
  }) : super(key: key);

  final Faction faction;
  final bool canEdit;
  final void Function(String taxPolicy) onTaxPolicyChanged;

  @override
  Widget build(BuildContext context) {
    final resources = faction.resources;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF202B34),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance, color: Color(0xFFE9EEF2), size: 19),
              SizedBox(width: 8),
              Text(
                'Economy',
                style: TextStyle(
                  color: Color(0xFFF4F7FA),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DetailRow(
            label: 'Stockpile',
            value:
                '${resources.food} food / ${resources.industry} ind / ${resources.research} res / ${resources.credits} cred',
          ),
          if (canEdit)
            _TaxPolicyDropdown(
              faction: faction,
              onTaxPolicyChanged: onTaxPolicyChanged,
            )
          else
            _DetailRow(
              label: 'Taxes',
              value: Faction.taxPolicyLabelFor(faction.taxPolicy),
            ),
          _DetailRow(
            label: 'Effect',
            value: Faction.taxPolicyDescriptionFor(faction.taxPolicy),
          ),
        ],
      ),
    );
  }
}

class _TaxPolicyDropdown extends StatelessWidget {
  const _TaxPolicyDropdown({
    Key? key,
    required this.faction,
    required this.onTaxPolicyChanged,
  }) : super(key: key);

  final Faction faction;
  final void Function(String taxPolicy) onTaxPolicyChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: 92,
            child: Text(
              'Taxes',
              style: TextStyle(
                  color: Color(0xFF9FB0BE), fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: Faction.isKnownTaxPolicy(faction.taxPolicy)
                    ? faction.taxPolicy
                    : Faction.taxPolicyBalanced,
                isExpanded: true,
                dropdownColor: const Color(0xFF202B34),
                iconEnabledColor: const Color(0xFFE9EEF2),
                style: const TextStyle(color: Color(0xFFE9EEF2)),
                items: Faction.taxPolicies.map((taxPolicy) {
                  return DropdownMenuItem<String>(
                    value: taxPolicy,
                    child: Text(
                      '${Faction.taxPolicyLabelFor(taxPolicy)} - ${Faction.taxPolicyDescriptionFor(taxPolicy)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null || value == faction.taxPolicy) {
                    return;
                  }
                  onTaxPolicyChanged(value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColonyOverviewDetail extends StatelessWidget {
  const _ColonyOverviewDetail({
    Key? key,
    required this.game,
    required this.colonies,
    required this.selectedColonyId,
    required this.onSelectColony,
  }) : super(key: key);

  final OpenDeadlockGame game;
  final List<Colony> colonies;
  final String? selectedColonyId;
  final void Function(Colony colony) onSelectColony;

  @override
  Widget build(BuildContext context) {
    final projections = <String, ColonyProduction>{
      for (final colony in colonies)
        colony.id: game.colonyProductionFor(colony),
    };
    final totalOutput = _totalOutputFor(projections.values);
    final warningCount = projections.values
        .where((projection) => _hasWarning(projection))
        .length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF202B34),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_city, color: Color(0xFFE9EEF2), size: 19),
              SizedBox(width: 8),
              Text(
                'Colonies',
                style: TextStyle(
                  color: Color(0xFFF4F7FA),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DetailRow(label: 'Count', value: '${colonies.length} active'),
          _DetailRow(
            label: 'Output',
            value:
                '${totalOutput.food} food / ${totalOutput.industry} ind / ${totalOutput.research} res / ${totalOutput.credits} cred',
          ),
          _DetailRow(
            label: 'Warnings',
            value: warningCount == 0 ? 'None' : '$warningCount need attention',
          ),
          for (var index = 0; index < colonies.length; index += 1)
            _ColonyOverviewRow(
              colony: colonies[index],
              projection: projections[colonies[index].id]!,
              isSelected: colonies[index].id == selectedColonyId,
              onSelect: () => onSelectColony(colonies[index]),
            ),
        ],
      ),
    );
  }

  ResourceStockpile _totalOutputFor(
    Iterable<ColonyProduction> projections,
  ) {
    var food = 0;
    var industry = 0;
    var research = 0;
    var credits = 0;
    for (final projection in projections) {
      food += projection.output.food;
      industry += projection.output.industry;
      research += projection.output.research;
      credits += projection.output.credits;
    }
    return ResourceStockpile(
      food: food,
      industry: industry,
      research: research,
      credits: credits,
    );
  }

  bool _hasWarning(ColonyProduction projection) {
    return projection.isStarving ||
        projection.isInUnrest ||
        projection.isRioting;
  }
}

class _ColonyOverviewRow extends StatelessWidget {
  const _ColonyOverviewRow({
    Key? key,
    required this.colony,
    required this.projection,
    required this.isSelected,
    required this.onSelect,
  }) : super(key: key);

  final Colony colony;
  final ColonyProduction projection;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.only(top: 10),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFF31404C)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: Icon(
                      isSelected ? Icons.my_location : Icons.location_on,
                      size: 16,
                    ),
                    label: Text(
                      colony.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: onSelect,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFCCD6A6),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Sector ${colony.x + 1}, ${colony.y + 1}',
                style: const TextStyle(
                  color: Color(0xFF9FB0BE),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Output ${projection.output.food} food / ${projection.output.industry} ind / ${projection.output.research} res / ${projection.output.credits} cred',
            style: const TextStyle(color: Color(0xFFE9EEF2), fontSize: 12),
          ),
          Text(
            'Focus ${OpenDeadlockGame.colonyFocusLabelFor(colony.focus)}',
            style: const TextStyle(color: Color(0xFFB9C5CE), fontSize: 12),
          ),
          Text(
            _buildLabel(),
            style: const TextStyle(color: Color(0xFFB9C5CE), fontSize: 12),
          ),
          Text(
            'Pop ${colony.population} -> ${projection.nextPopulation} (${_signedInt(projection.populationChange)}) | Morale ${colony.morale}% -> ${projection.nextMorale}% (${_signedInt(projection.moraleChange)})',
            style: const TextStyle(color: Color(0xFFB9C5CE), fontSize: 12),
          ),
          Text(
            _statusLabel(),
            style: TextStyle(
              color: _hasWarning()
                  ? const Color(0xFFF2C38B)
                  : const Color(0xFF9FB0BE),
              fontSize: 12,
              fontWeight: _hasWarning() ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  String _buildLabel() {
    final buildCost = OpenDeadlockGame.buildCostFor(colony.construction);
    final storedIndustry = _storedIndustryFor(buildCost);
    return 'Build ${colony.construction}: $storedIndustry/$buildCost ${_signedInt(projection.constructionWork)}, ${_buildEtaLabel(buildCost, storedIndustry)}';
  }

  int _storedIndustryFor(int buildCost) {
    if (colony.storedIndustry < 0) {
      return 0;
    }
    if (colony.storedIndustry > buildCost) {
      return buildCost;
    }
    return colony.storedIndustry;
  }

  String _buildEtaLabel(int buildCost, int storedIndustry) {
    if (projection.willCompleteConstruction || storedIndustry >= buildCost) {
      return 'complete this turn';
    }
    if (projection.constructionWork <= 0) {
      return 'stalled';
    }
    final remaining = buildCost - storedIndustry;
    final turns = (remaining + projection.constructionWork - 1) ~/
        projection.constructionWork;
    return '$turns ${turns == 1 ? 'turn' : 'turns'}';
  }

  bool _hasWarning() {
    return projection.isStarving ||
        projection.isInUnrest ||
        projection.isRioting;
  }

  String _statusLabel() {
    if (projection.isRioting) {
      return 'Status: riot damage active';
    }
    if (projection.isStarving) {
      return 'Status: food shortage ${_signedInt(projection.foodBalance)}';
    }
    if (projection.isInUnrest) {
      return 'Status: unrest penalties active';
    }
    if (projection.willGrow) {
      return 'Status: growing next turn';
    }
    if (projection.willCompleteConstruction) {
      return 'Status: build completes next turn';
    }
    return 'Status: stable';
  }
}

class _PendingBuildsDetail extends StatelessWidget {
  const _PendingBuildsDetail({
    Key? key,
    required this.game,
    required this.colonies,
    required this.onSelectColony,
  }) : super(key: key);

  final OpenDeadlockGame game;
  final List<Colony> colonies;
  final void Function(Colony colony) onSelectColony;

  @override
  Widget build(BuildContext context) {
    final items = colonies
        .map((colony) => _PendingBuildItem.forColony(game, colony))
        .toList();
    items.sort((a, b) {
      final turnComparison = a.sortTurns.compareTo(b.sortTurns);
      if (turnComparison != 0) {
        return turnComparison;
      }
      return a.colony.name.compareTo(b.colony.name);
    });
    final completingCount =
        items.where((item) => item.completesThisTurn).length;
    final nextItem = items.isEmpty ? null : items.first;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF202B34),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.fact_check, color: Color(0xFFE9EEF2), size: 19),
              SizedBox(width: 8),
              Text(
                'Pending Builds',
                style: TextStyle(
                  color: Color(0xFFF4F7FA),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DetailRow(label: 'Queued', value: '${items.length} builds'),
          _DetailRow(
            label: 'Finishing',
            value: completingCount == 0
                ? 'None this turn'
                : '$completingCount this turn',
          ),
          if (nextItem != null)
            _DetailRow(
              label: 'Next',
              value: '${nextItem.colony.name}: ${nextItem.statusLabel}',
            ),
          for (final item in items)
            _PendingBuildRow(
              item: item,
              onSelect: () => onSelectColony(item.colony),
            ),
        ],
      ),
    );
  }
}

class _PendingBuildItem {
  const _PendingBuildItem({
    required this.colony,
    required this.projection,
    required this.buildCost,
    required this.storedIndustry,
    required this.statusLabel,
    required this.sortTurns,
    required this.completesThisTurn,
  });

  final Colony colony;
  final ColonyProduction projection;
  final int buildCost;
  final int storedIndustry;
  final String statusLabel;
  final int sortTurns;
  final bool completesThisTurn;

  static _PendingBuildItem forColony(
    OpenDeadlockGame game,
    Colony colony,
  ) {
    final projection = game.colonyProductionFor(colony);
    final buildCost = OpenDeadlockGame.buildCostFor(colony.construction);
    final storedIndustry = _clampedStoredIndustry(colony, buildCost);
    final completesThisTurn =
        projection.willCompleteConstruction || storedIndustry >= buildCost;
    final turns = _turnsRemainingFor(
      buildCost: buildCost,
      storedIndustry: storedIndustry,
      constructionWork: projection.constructionWork,
      completesThisTurn: completesThisTurn,
    );
    return _PendingBuildItem(
      colony: colony,
      projection: projection,
      buildCost: buildCost,
      storedIndustry: storedIndustry,
      statusLabel: _statusLabelFor(
        turns: turns,
        completesThisTurn: completesThisTurn,
      ),
      sortTurns: turns ?? 100000,
      completesThisTurn: completesThisTurn,
    );
  }

  static int _clampedStoredIndustry(Colony colony, int buildCost) {
    if (colony.storedIndustry < 0) {
      return 0;
    }
    if (colony.storedIndustry > buildCost) {
      return buildCost;
    }
    return colony.storedIndustry;
  }

  static int? _turnsRemainingFor({
    required int buildCost,
    required int storedIndustry,
    required int constructionWork,
    required bool completesThisTurn,
  }) {
    if (completesThisTurn) {
      return 0;
    }
    if (constructionWork <= 0) {
      return null;
    }
    final remaining = buildCost - storedIndustry;
    return (remaining + constructionWork - 1) ~/ constructionWork;
  }

  static String _statusLabelFor({
    required int? turns,
    required bool completesThisTurn,
  }) {
    if (completesThisTurn || turns == 0) {
      return 'Completes this turn';
    }
    if (turns == null) {
      return 'Stalled';
    }
    return '$turns ${turns == 1 ? 'turn' : 'turns'}';
  }
}

class _PendingBuildRow extends StatelessWidget {
  const _PendingBuildRow({
    Key? key,
    required this.item,
    required this.onSelect,
  }) : super(key: key);

  final _PendingBuildItem item;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.only(top: 10),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFF31404C)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.location_on, size: 16),
                    label: Text(
                      item.colony.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: onSelect,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFCCD6A6),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                item.statusLabel,
                style: TextStyle(
                  color: item.completesThisTurn
                      ? const Color(0xFF82CBA8)
                      : const Color(0xFF9FB0BE),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${item.colony.construction}: ${item.storedIndustry}/${item.buildCost} industry (${_signedInt(item.projection.constructionWork)}/turn)',
            style: const TextStyle(color: Color(0xFFE9EEF2), fontSize: 12),
          ),
          Text(
            OpenDeadlockGame.constructionProducesDescriptionFor(
              item.colony.construction,
            ),
            style: const TextStyle(color: Color(0xFFB9C5CE), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PostGameStatsDetail extends StatelessWidget {
  const _PostGameStatsDetail({
    Key? key,
    required this.game,
  }) : super(key: key);

  final OpenDeadlockGame game;

  @override
  Widget build(BuildContext context) {
    final scores = game.factionScores();
    final summariesByFactionId = <String, FactionWorldSummary>{
      for (final summary in game.worldSummaries()) summary.factionId: summary,
    };
    final battleCount = game.reports.where((report) => report.isBattle).length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF202B34),
        border: Border.all(color: const Color(0xFF55616C)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.assessment, color: Color(0xFFE9EEF2), size: 19),
              SizedBox(width: 8),
              Text(
                'Post-game Stats',
                style: TextStyle(
                  color: Color(0xFFF4F7FA),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DetailRow(
            label: 'Winner',
            value: game.winningFaction?.name ?? 'Unknown',
          ),
          _DetailRow(
            label: 'Victory Type',
            value: _victoryTypeLabel(),
          ),
          _DetailRow(label: 'Final Turn', value: 'Turn ${game.turn}'),
          _DetailRow(
            label: 'Route',
            value: _victoryRouteLabel(),
          ),
          _DetailRow(
            label: 'Battles',
            value:
                '$battleCount ${battleCount == 1 ? 'battle' : 'battles'} logged',
          ),
          const SizedBox(height: 10),
          const Text(
            'Final Rankings',
            style: TextStyle(
              color: Color(0xFFF4F7FA),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          for (var index = 0; index < scores.length; index += 1)
            _PostGameFactionRow(
              rank: index + 1,
              score: scores[index],
              summary: summariesByFactionId[scores[index].factionId]!,
            ),
        ],
      ),
    );
  }

  String _victoryTypeLabel() {
    final victoryType = game.winningVictoryType;
    if (victoryType == OpenDeadlockGame.victoryTypeScience) {
      return 'Science';
    }
    if (victoryType == OpenDeadlockGame.victoryTypeConquest) {
      return 'Conquest';
    }
    return 'Undecided';
  }

  String _victoryRouteLabel() {
    final victoryType = game.winningVictoryType;
    if (victoryType == OpenDeadlockGame.victoryTypeScience) {
      return 'Research completed every core project';
    }
    if (victoryType == OpenDeadlockGame.victoryTypeConquest) {
      return 'Controlled every colony on the planet';
    }
    return 'No victory route completed';
  }
}

class _PostGameFactionRow extends StatelessWidget {
  const _PostGameFactionRow({
    Key? key,
    required this.rank,
    required this.score,
    required this.summary,
  }) : super(key: key);

  final int rank;
  final FactionScore score;
  final FactionWorldSummary summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: Color(score.colorValue),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$rank. ${score.factionName}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE9EEF2),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${score.total} pts | ${summary.victoryProgressLabel} | ${summary.totalPopulation} pop | ${summary.unitCount} units',
                  style: const TextStyle(
                    color: Color(0xFFD7DEE5),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Score Breakdown: Colonies ${score.colonyScore} | Sectors ${score.sectorScore} | Population ${score.populationScore} | Military ${score.militaryScore} | Science ${score.scienceScore} | Reserves ${score.reserveScore}',
                  style: const TextStyle(
                    color: Color(0xFFB9C5CE),
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Output: ${_resourceLine(summary.projectedProduction)} | Science ${summary.scienceVictoryProgressLabel}',
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
    );
  }

  String _resourceLine(ResourceStockpile stockpile) {
    return '${stockpile.food} food / ${stockpile.industry} ind / ${stockpile.research} res / ${stockpile.credits} cred';
  }
}

class _WorldOverviewDetail extends StatelessWidget {
  const _WorldOverviewDetail({
    Key? key,
    required this.game,
  }) : super(key: key);

  final OpenDeadlockGame game;

  @override
  Widget build(BuildContext context) {
    final activeSummary = game.worldSummaryFor(game.activeFactionId);
    final activeScore = game.factionScoreFor(game.activeFactionId);
    final scores = game.factionScores();
    final activeRankIndex =
        scores.indexWhere((score) => score.factionId == game.activeFactionId);
    final activeRank = activeRankIndex < 0 ? 0 : activeRankIndex + 1;
    final summariesByFactionId = <String, FactionWorldSummary>{
      for (final summary in game.worldSummaries()) summary.factionId: summary,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF202B34),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.public, color: Color(0xFFE9EEF2), size: 19),
              SizedBox(width: 8),
              Text(
                'World',
                style: TextStyle(
                  color: Color(0xFFF4F7FA),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DetailRow(
            label: 'Known',
            value:
                '${activeSummary.exploredSectors}/${game.tiles.length} sectors',
          ),
          _DetailRow(
            label: 'Output',
            value:
                '${activeSummary.projectedProduction.food} food / ${activeSummary.projectedProduction.industry} ind / ${activeSummary.projectedProduction.research} res / ${activeSummary.projectedProduction.credits} cred',
          ),
          _DetailRow(
            label: 'Threats',
            value:
                '${activeSummary.atWarCount} wars / ${activeSummary.visibleEnemyColonies} colonies seen',
          ),
          _DetailRow(
            label: 'Rank',
            value: '#$activeRank / ${scores.length} | ${activeScore.total} pts',
          ),
          _DetailRow(
            label: 'Victory',
            value:
                '${activeSummary.victoryProgressLabel} / ${activeSummary.victorySharePercent}%',
          ),
          _DetailRow(
            label: 'Science',
            value:
                '${activeSummary.scienceVictoryProgressLabel} / ${activeSummary.scienceVictorySharePercent}%',
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < scores.length; index += 1)
            _FactionScoreRow(
              score: scores[index],
              rank: index + 1,
              summary: summariesByFactionId[scores[index].factionId]!,
            ),
        ],
      ),
    );
  }
}

class _FactionScoreRow extends StatelessWidget {
  const _FactionScoreRow({
    Key? key,
    required this.score,
    required this.rank,
    required this.summary,
  }) : super(key: key);

  final FactionScore score;
  final int rank;
  final FactionWorldSummary summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: Color(score.colorValue),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  score.factionName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE9EEF2),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  summary.isDefeated
                      ? 'Defeated | ${score.total} pts'
                      : 'Rank $rank | ${score.total} pts',
                  style: const TextStyle(
                    color: Color(0xFFD7DEE5),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${summary.isDefeated ? 'Defeated | ' : ''}${summary.raceName} | ${summary.victoryProgressLabel} | ${summary.scienceVictoryProgressLabel} | ${summary.unitCount} units | ${summary.controlledSectors} sectors',
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
    );
  }
}

class _FactionControlDetail extends StatelessWidget {
  const _FactionControlDetail({
    Key? key,
    required this.game,
    required this.canEdit,
    required this.onFactionControlChanged,
    required this.onFactionDifficultyChanged,
  }) : super(key: key);

  final OpenDeadlockGame game;
  final bool canEdit;
  final void Function(String factionId, String controlMode)
      onFactionControlChanged;
  final void Function(String factionId, String difficulty)
      onFactionDifficultyChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF202B34),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.manage_accounts, color: Color(0xFFE9EEF2), size: 19),
              SizedBox(width: 8),
              Text(
                'Seats',
                style: TextStyle(
                  color: Color(0xFFF4F7FA),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...game.factions.map(
            (faction) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          color: Color(faction.colorValue),
                          size: 10,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            faction.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFFE9EEF2)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const SizedBox(
                          width: 72,
                          child: Text(
                            'Seat',
                            style: TextStyle(
                              color: Color(0xFF9FB0BE),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: faction.controlMode,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF202B34),
                              iconEnabledColor: const Color(0xFFE9EEF2),
                              iconDisabledColor: const Color(0xFF6D7C88),
                              style: const TextStyle(color: Color(0xFFE9EEF2)),
                              items: Faction.controlModes.map((controlMode) {
                                return DropdownMenuItem<String>(
                                  value: controlMode,
                                  child: Text(
                                    Faction.controlModeLabelFor(controlMode),
                                  ),
                                );
                              }).toList(),
                              onChanged: canEdit
                                  ? (value) {
                                      if (value == null ||
                                          value == faction.controlMode) {
                                        return;
                                      }
                                      onFactionControlChanged(
                                          faction.id, value);
                                    }
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const SizedBox(
                          width: 72,
                          child: Text(
                            'Difficulty',
                            style: TextStyle(
                              color: Color(0xFF9FB0BE),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: faction.difficulty,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF202B34),
                              iconEnabledColor: const Color(0xFFE9EEF2),
                              iconDisabledColor: const Color(0xFF6D7C88),
                              style: const TextStyle(color: Color(0xFFE9EEF2)),
                              items: Faction.difficultyLevels.map((difficulty) {
                                return DropdownMenuItem<String>(
                                  value: difficulty,
                                  child: Text(
                                    Faction.difficultyLabelFor(difficulty),
                                  ),
                                );
                              }).toList(),
                              onChanged: canEdit
                                  ? (value) {
                                      if (value == null ||
                                          value == faction.difficulty) {
                                        return;
                                      }
                                      onFactionDifficultyChanged(
                                          faction.id, value);
                                    }
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DiplomacyDetail extends StatelessWidget {
  const _DiplomacyDetail({
    Key? key,
    required this.game,
    required this.faction,
    required this.canEdit,
    required this.onDiplomacyChanged,
    required this.onIntelScan,
    required this.onSabotage,
  }) : super(key: key);

  final OpenDeadlockGame game;
  final Faction faction;
  final bool canEdit;
  final void Function(String targetFactionId, String status) onDiplomacyChanged;
  final void Function(String targetFactionId) onIntelScan;
  final void Function(String targetFactionId) onSabotage;

  @override
  Widget build(BuildContext context) {
    final otherFactions = game.factions
        .where((otherFaction) => otherFaction.id != faction.id)
        .toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF202B34),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.handshake, color: Color(0xFFE9EEF2), size: 19),
              SizedBox(width: 8),
              Text(
                'Diplomacy',
                style: TextStyle(
                  color: Color(0xFFF4F7FA),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (otherFactions.isEmpty)
            const Text(
              'No known rival factions.',
              style: TextStyle(color: Color(0xFFE9EEF2)),
            )
          else
            ...otherFactions.map(
              (otherFaction) {
                final status =
                    game.diplomacyStatusBetween(faction.id, otherFaction.id);
                final tradeCredits =
                    game.treatyTradeCreditsFor(faction.id, otherFaction.id);
                final ownStrength = game.militaryStrengthFor(faction.id);
                final rivalStrength = game.militaryStrengthFor(otherFaction.id);
                final scanSectors = game.intelScanRevealableSectorCountFor(
                  faction.id,
                  otherFaction.id,
                );
                final hasScanBudget = faction.resources.credits >=
                    OpenDeadlockGame.intelScanCreditCost;
                final canScan = canEdit && scanSectors > 0 && hasScanBudget;
                final sabotageTarget =
                    game.sabotageTargetFor(faction.id, otherFaction.id);
                final hasSabotageBudget = faction.resources.credits >=
                    OpenDeadlockGame.sabotageCreditCost;
                final canSabotage = canEdit &&
                    status == OpenDeadlockGame.diplomacyStatusWar &&
                    sabotageTarget != null &&
                    hasSabotageBudget;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.circle,
                            color: Color(otherFaction.colorValue),
                            size: 10,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              otherFaction.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFFE9EEF2)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 116,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: status,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF202B34),
                                iconEnabledColor: const Color(0xFFE9EEF2),
                                iconDisabledColor: const Color(0xFF6D7C88),
                                style:
                                    const TextStyle(color: Color(0xFFE9EEF2)),
                                items: OpenDeadlockGame.diplomacyStatuses
                                    .map((option) {
                                  return DropdownMenuItem<String>(
                                    value: option,
                                    child: Text(_statusLabel(option)),
                                  );
                                }).toList(),
                                onChanged: canEdit
                                    ? (value) {
                                        if (value == null || value == status) {
                                          return;
                                        }
                                        onDiplomacyChanged(
                                            otherFaction.id, value);
                                      }
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tradeCredits > 0
                                  ? 'Trade +$tradeCredits credits / turn'
                                  : 'No treaty trade',
                              style: const TextStyle(
                                color: Color(0xFF9FB0BE),
                                fontSize: 12,
                              ),
                            ),
                            if (status ==
                                OpenDeadlockGame.diplomacyStatusAlliance)
                              const Text(
                                'Alliance intel shared',
                                style: TextStyle(
                                  color: Color(0xFF9FB0BE),
                                  fontSize: 12,
                                ),
                              ),
                            Text(
                              'Strength $ownStrength vs $rivalStrength',
                              style: const TextStyle(
                                color: Color(0xFF9FB0BE),
                                fontSize: 12,
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _intelScanLabel(
                                      scanSectors,
                                      hasScanBudget,
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFF9FB0BE),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.radar, size: 16),
                                  label: const Text('Scan'),
                                  onPressed: canScan
                                      ? () => onIntelScan(otherFaction.id)
                                      : null,
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFCCD6A6),
                                    disabledForegroundColor:
                                        const Color(0xFF6D7C88),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _sabotageLabel(
                                      status,
                                      sabotageTarget,
                                      hasSabotageBudget,
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFF9FB0BE),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  icon:
                                      const Icon(Icons.construction, size: 16),
                                  label: const Text('Sabotage'),
                                  onPressed: canSabotage
                                      ? () => onSabotage(otherFaction.id)
                                      : null,
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFF2C38B),
                                    disabledForegroundColor:
                                        const Color(0xFF6D7C88),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    return OpenDeadlockGame.diplomacyStatusLabelFor(status);
  }

  String _intelScanLabel(int scanSectors, bool hasScanBudget) {
    if (scanSectors <= 0) {
      return 'Intel up to date';
    }
    if (!hasScanBudget) {
      return 'Intel scan needs ${OpenDeadlockGame.intelScanCreditCost} credits';
    }
    return 'Intel scan: $scanSectors sectors / ${OpenDeadlockGame.intelScanCreditCost} credits';
  }

  String _sabotageLabel(
    String status,
    FactionSabotageTarget? target,
    bool hasSabotageBudget,
  ) {
    if (status != OpenDeadlockGame.diplomacyStatusWar) {
      return 'Sabotage requires war';
    }
    if (target == null) {
      return 'No visible project to sabotage';
    }
    if (!hasSabotageBudget) {
      return 'Sabotage needs ${OpenDeadlockGame.sabotageCreditCost} credits';
    }
    return 'Sabotage ${target.colonyName}: ${target.damage} industry / ${OpenDeadlockGame.sabotageCreditCost} credits';
  }
}

class _ResearchDetail extends StatelessWidget {
  const _ResearchDetail({
    Key? key,
    required this.faction,
    required this.canEdit,
    required this.onResearchChanged,
    required this.onFundResearch,
  }) : super(key: key);

  final Faction faction;
  final bool canEdit;
  final void Function(String researchProject) onResearchChanged;
  final void Function(int research) onFundResearch;

  @override
  Widget build(BuildContext context) {
    final researchCost =
        OpenDeadlockGame.researchCostFor(faction.researchProject);
    final completedResearch = faction.completedResearch.isEmpty
        ? 'None'
        : faction.completedResearch.join(', ');
    final remainingResearch = researchCost - faction.resources.research;
    final affordableResearch = faction.resources.credits ~/
        OpenDeadlockGame.researchCreditCostPerPoint;
    final fundedResearch =
        _fundedResearchFor(remainingResearch, affordableResearch);
    final fundCost = fundedResearch <= 0
        ? 0
        : OpenDeadlockGame.fundResearchCostFor(fundedResearch);
    final canFund = canEdit && fundedResearch > 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF202B34),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.biotech, color: Color(0xFFE9EEF2), size: 19),
              SizedBox(width: 8),
              Text(
                'Research',
                style: TextStyle(
                  color: Color(0xFFF4F7FA),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (canEdit)
            _ResearchDropdown(
              faction: faction,
              onResearchChanged: onResearchChanged,
            )
          else
            _DetailRow(label: 'Project', value: faction.researchProject),
          _DetailRow(
            label: 'Stored',
            value: '${faction.resources.research}/$researchCost',
          ),
          _DetailRow(
            label: 'Effect',
            value: OpenDeadlockGame.researchDescriptionFor(
              faction.researchProject,
            ),
          ),
          _DetailRow(label: 'Completed', value: completedResearch),
          const SizedBox(height: 10),
          const Row(
            children: [
              Icon(Icons.account_tree, color: Color(0xFFE9EEF2), size: 18),
              SizedBox(width: 8),
              Text(
                'Tech Roadmap',
                style: TextStyle(
                  color: Color(0xFFF4F7FA),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ..._researchRoadmapFor(faction).map(
            (item) => _ResearchRoadmapRow(item: item),
          ),
          if (canEdit) ...[
            const SizedBox(height: 8),
            _DetailRow(
              label: 'Fund Cost',
              value:
                  '${OpenDeadlockGame.researchCreditCostPerPoint} credits / research',
            ),
            Tooltip(
              message: canFund
                  ? 'Buy $fundedResearch research for $fundCost credits'
                  : 'Need credits and unfinished research',
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.lightbulb),
                  label: Text(
                    canFund ? 'Fund +$fundedResearch' : 'Fund Research',
                  ),
                  onPressed:
                      canFund ? () => onFundResearch(fundedResearch) : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _fundedResearchFor(int remainingResearch, int affordableResearch) {
    final availableResearch = remainingResearch < affordableResearch
        ? remainingResearch
        : affordableResearch;
    if (availableResearch < 0) {
      return 0;
    }
    return availableResearch;
  }

  List<_ResearchRoadmapItem> _researchRoadmapFor(Faction faction) {
    final items = <_ResearchRoadmapItem>[];
    void addProject(String project) {
      if (items.any((item) => item.project == project)) {
        return;
      }
      items.add(_ResearchRoadmapItem.forProject(faction, project));
    }

    addProject(faction.researchProject);
    for (final project in OpenDeadlockGame.researchOptions) {
      if (project == faction.researchProject ||
          OpenDeadlockGame.isCompletedResearch(faction, project) ||
          OpenDeadlockGame.isRepeatableResearch(project)) {
        continue;
      }
      addProject(project);
    }
    for (final project in OpenDeadlockGame.researchOptions) {
      if (OpenDeadlockGame.isCompletedResearch(faction, project)) {
        addProject(project);
      }
    }
    for (final project in OpenDeadlockGame.researchOptions) {
      if (OpenDeadlockGame.isRepeatableResearch(project)) {
        addProject(project);
      }
    }
    return items;
  }
}

class _ResearchRoadmapItem {
  const _ResearchRoadmapItem({
    required this.project,
    required this.status,
    required this.progress,
    required this.description,
  });

  final String project;
  final String status;
  final String progress;
  final String description;

  static _ResearchRoadmapItem forProject(Faction faction, String project) {
    final cost = OpenDeadlockGame.researchCostFor(project);
    final isCompleted = OpenDeadlockGame.isCompletedResearch(faction, project);
    final isCurrent = faction.researchProject == project;
    final isRepeatable = OpenDeadlockGame.isRepeatableResearch(project);
    final storedResearch = isCurrent ? faction.resources.research : 0;
    final clampedResearch = isCompleted
        ? cost
        : storedResearch < cost
            ? storedResearch
            : cost;
    return _ResearchRoadmapItem(
      project: project,
      status: _statusFor(
        isCurrent: isCurrent,
        isCompleted: isCompleted,
        isRepeatable: isRepeatable,
      ),
      progress: '$clampedResearch/$cost',
      description: OpenDeadlockGame.researchDescriptionFor(project),
    );
  }

  static String _statusFor({
    required bool isCurrent,
    required bool isCompleted,
    required bool isRepeatable,
  }) {
    if (isCurrent) {
      return 'Current';
    }
    if (isCompleted) {
      return 'Complete';
    }
    if (isRepeatable) {
      return 'Repeatable';
    }
    return 'Next';
  }
}

class _ResearchRoadmapRow extends StatelessWidget {
  const _ResearchRoadmapRow({
    Key? key,
    required this.item,
  }) : super(key: key);

  final _ResearchRoadmapItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.only(top: 6),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFF31404C)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 92,
                child: Text(
                  item.status,
                  style: TextStyle(
                    color: _statusColor(item.status),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '${item.project} ${item.progress}',
                  style: const TextStyle(
                    color: Color(0xFFE9EEF2),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 92, top: 2),
            child: Text(
              item.description,
              style: const TextStyle(
                color: Color(0xFFB9C5CE),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    if (status == 'Current') {
      return const Color(0xFFCCD6A6);
    }
    if (status == 'Complete') {
      return const Color(0xFF82CBA8);
    }
    if (status == 'Repeatable') {
      return const Color(0xFFB7A6D6);
    }
    return const Color(0xFF9FB0BE);
  }
}

class _ResearchDropdown extends StatelessWidget {
  const _ResearchDropdown({
    Key? key,
    required this.faction,
    required this.onResearchChanged,
  }) : super(key: key);

  final Faction faction;
  final void Function(String researchProject) onResearchChanged;

  @override
  Widget build(BuildContext context) {
    final researchOptions = OpenDeadlockGame.researchOptions.where((option) {
      return option == faction.researchProject ||
          !OpenDeadlockGame.isCompletedResearch(faction, option);
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: 92,
            child: Text(
              'Project',
              style: TextStyle(
                  color: Color(0xFF9FB0BE), fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: faction.researchProject,
                isExpanded: true,
                dropdownColor: const Color(0xFF202B34),
                iconEnabledColor: const Color(0xFFE9EEF2),
                style: const TextStyle(color: Color(0xFFE9EEF2)),
                items: researchOptions.map((option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(
                      option,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  onResearchChanged(value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncStatusDetail extends StatelessWidget {
  const _SyncStatusDetail({
    Key? key,
    required this.game,
    required this.latestSaveSlot,
    required this.orderExportBaseCommandCount,
    required this.lastSyncStatus,
    required this.onCopyInvite,
    required this.onExportInvite,
  }) : super(key: key);

  final OpenDeadlockGame game;
  final SavedGameSlot? latestSaveSlot;
  final int orderExportBaseCommandCount;
  final String? lastSyncStatus;
  final Future<void> Function(String factionId) onCopyInvite;
  final Future<void> Function(String factionId) onExportInvite;

  @override
  Widget build(BuildContext context) {
    final fingerprint = GameCodec.fingerprintGame(game);
    final remoteFactions =
        game.factions.where((faction) => faction.isRemote).toList();
    final hasRemoteFactions = game.factions.any((faction) => faction.isRemote);
    final hasComputerFactions =
        game.factions.any((faction) => faction.isComputer);
    final pendingOrderCount =
        _pendingOrderCountFor(game, orderExportBaseCommandCount);
    final mode = hasRemoteFactions
        ? 'Async multiplayer'
        : hasComputerFactions
            ? 'AI assisted'
            : 'Hotseat';
    final syncAction = _syncActionLabelFor(game, pendingOrderCount);
    final turnState = game.activeFaction.isRemote
        ? 'Waiting for ${game.activeFaction.name} orders'
        : game.activeFactionCanIssueLocalOrders
            ? 'Local orders available'
            : game.isGameOver
                ? 'Game over'
                : 'Automated turn';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF202B34),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sync_alt, color: Color(0xFFE9EEF2), size: 19),
              SizedBox(width: 8),
              Text(
                'Sync',
                style: TextStyle(
                  color: Color(0xFFF4F7FA),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DetailRow(label: 'Mode', value: mode),
          _DetailRow(label: 'Session', value: _shortSessionId(game.sessionId)),
          _DetailRow(
            label: 'Active',
            value: Faction.controlModeLabelFor(game.activeFaction.controlMode),
          ),
          _DetailRow(label: 'Next', value: syncAction),
          _DetailRow(
            label: 'Unsent',
            value: pendingOrderCount == 1
                ? '1 order'
                : '$pendingOrderCount orders',
          ),
          _DetailRow(label: 'Turn State', value: turnState),
          _DetailRow(
            label: 'Last Sync',
            value: lastSyncStatus ?? 'No packages applied this session',
          ),
          _DetailRow(
            label: 'Save',
            value: latestSaveSlot == null
                ? 'No local save'
                : '${latestSaveSlot!.name} (${latestSaveSlot!.stateFingerprint})',
          ),
          _DetailRow(label: 'Commands', value: '${game.commandHistory.length}'),
          _DetailRow(label: 'State', value: fingerprint),
          if (remoteFactions.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Invites',
              style: TextStyle(
                color: Color(0xFFF4F7FA),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            ...remoteFactions.map(
              (faction) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      faction.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFE9EEF2),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.person_add_alt_1, size: 18),
                          label: const Text('Copy Invite'),
                          onPressed: () {
                            onCopyInvite(faction.id);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFE9EEF2),
                            side: const BorderSide(color: Color(0xFF55616C)),
                          ),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.save_alt, size: 18),
                          label: const Text('Save Invite'),
                          onPressed: () {
                            onExportInvite(faction.id);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFE9EEF2),
                            side: const BorderSide(color: Color(0xFF55616C)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingOrdersDetail extends StatelessWidget {
  const _PendingOrdersDetail({
    Key? key,
    required this.game,
    required this.fromCommandIndex,
    required this.canUndoLastOrder,
    required this.onUndoLastOrder,
  }) : super(key: key);

  final OpenDeadlockGame game;
  final int fromCommandIndex;
  final bool canUndoLastOrder;
  final VoidCallback onUndoLastOrder;

  @override
  Widget build(BuildContext context) {
    final startIndex = _clampedStartIndex();
    final pendingRecords = game.commandHistory.skip(startIndex).toList();
    final pendingLabel = pendingRecords.length == 1
        ? '1 pending'
        : '${pendingRecords.length} pending';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF202B34),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check, color: Color(0xFFE9EEF2), size: 19),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Pending Orders',
                  style: TextStyle(
                    color: Color(0xFFF4F7FA),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                pendingLabel,
                style: const TextStyle(
                  color: Color(0xFF9FB0BE),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DetailRow(
            label: 'Baseline',
            value: startIndex == 0 ? 'Game start' : 'Command $startIndex',
          ),
          if (pendingRecords.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.undo, size: 18),
                label: const Text('Undo Last Order'),
                onPressed: canUndoLastOrder ? onUndoLastOrder : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE9EEF2),
                  side: const BorderSide(color: Color(0xFF55616C)),
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
          ],
          if (pendingRecords.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'No orders since the sync baseline.',
                style: TextStyle(color: Color(0xFFE9EEF2)),
              ),
            )
          else
            ...pendingRecords.take(6).toList().asMap().entries.map((entry) {
              final recordIndex = startIndex + entry.key + 1;
              return _PendingOrderLine(
                index: recordIndex,
                record: entry.value,
                factionName: _factionNameFor(game, entry.value.factionId),
                summary: _commandSummaryFor(game, entry.value.command),
              );
            }),
          if (pendingRecords.length > 6)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '+${pendingRecords.length - 6} more orders',
                style: const TextStyle(
                  color: Color(0xFF9FB0BE),
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  int _clampedStartIndex() {
    return _clampedCommandIndex(game, fromCommandIndex);
  }
}

class _ComputerOrdersDetail extends StatelessWidget {
  const _ComputerOrdersDetail({
    Key? key,
    required this.game,
  }) : super(key: key);

  final OpenDeadlockGame game;

  @override
  Widget build(BuildContext context) {
    final faction = game.activeFaction;
    final plannedCommands = game.planComputerCommandsFor(faction.id);
    final plannedLabel = plannedCommands.length == 1
        ? '1 planned'
        : '${plannedCommands.length} planned';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF202B34),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smart_toy, color: Color(0xFFE9EEF2), size: 19),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AI Orders',
                  style: TextStyle(
                    color: Color(0xFFF4F7FA),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                plannedLabel,
                style: const TextStyle(
                  color: Color(0xFF9FB0BE),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DetailRow(label: 'Faction', value: faction.name),
          _DetailRow(
            label: 'Personality',
            value: Faction.aiPersonalityLabelFor(faction.aiPersonality),
          ),
          _DetailRow(
            label: 'Difficulty',
            value: Faction.difficultyLabelFor(faction.difficulty),
          ),
          if (plannedCommands.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'No automated orders are currently planned.',
                style: TextStyle(color: Color(0xFFE9EEF2)),
              ),
            )
          else
            ...plannedCommands.take(6).toList().asMap().entries.map((entry) {
              return _ComputerOrderLine(
                index: entry.key + 1,
                factionName: faction.name,
                summary: _commandSummaryFor(game, entry.value),
              );
            }),
          if (plannedCommands.length > 6)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '+${plannedCommands.length - 6} more orders',
                style: const TextStyle(
                  color: Color(0xFF9FB0BE),
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PendingOrderLine extends StatelessWidget {
  const _PendingOrderLine({
    Key? key,
    required this.index,
    required this.record,
    required this.factionName,
    required this.summary,
  }) : super(key: key);

  final int index;
  final CommandRecord record;
  final String factionName;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF313B44),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: Color(0xFFE9EEF2),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary,
                  style: const TextStyle(color: Color(0xFFE9EEF2)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Turn ${record.turn} | $factionName',
                  style: const TextStyle(
                    color: Color(0xFF9FB0BE),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComputerOrderLine extends StatelessWidget {
  const _ComputerOrderLine({
    Key? key,
    required this.index,
    required this.factionName,
    required this.summary,
  }) : super(key: key);

  final int index;
  final String factionName;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF313B44),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: Color(0xFFE9EEF2),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary,
                  style: const TextStyle(color: Color(0xFFE9EEF2)),
                ),
                const SizedBox(height: 2),
                Text(
                  'AI Plan | $factionName',
                  style: const TextStyle(
                    color: Color(0xFF9FB0BE),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomingOrderLine extends StatelessWidget {
  const _IncomingOrderLine({
    Key? key,
    required this.index,
    required this.command,
    required this.factionName,
    required this.summary,
  }) : super(key: key);

  final int index;
  final GameCommand command;
  final String factionName;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF313B44),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: Color(0xFFE9EEF2),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary,
                  style: const TextStyle(color: Color(0xFFE9EEF2)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Incoming | $factionName',
                  style: const TextStyle(
                    color: Color(0xFF9FB0BE),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _commandSummaryFor(OpenDeadlockGame game, GameCommand command) {
  if (command is SetColonyConstructionCommand) {
    return '${_colonyNameFor(game, command.colonyId)}: build ${command.construction}';
  }
  if (command is RushConstructionCommand) {
    return '${_colonyNameFor(game, command.colonyId)}: rush ${command.industry} industry';
  }
  if (command is SetColonyFocusCommand) {
    return '${_colonyNameFor(game, command.colonyId)}: focus ${OpenDeadlockGame.colonyFocusLabelFor(command.focus)}';
  }
  if (command is SetColonySectorAssignmentCommand) {
    final action = command.assigned ? 'assign' : 'release';
    return '${_colonyNameFor(game, command.colonyId)}: $action sector ${command.x + 1}, ${command.y + 1}';
  }
  if (command is SetResearchProjectCommand) {
    return 'Research: ${command.researchProject}';
  }
  if (command is FundResearchCommand) {
    return 'Fund ${command.research} research';
  }
  if (command is SetFactionControlCommand) {
    return '${_factionNameFor(game, command.factionId)}: control ${Faction.controlModeLabelFor(command.controlMode)}';
  }
  if (command is SetFactionDifficultyCommand) {
    return '${_factionNameFor(game, command.factionId)}: difficulty ${Faction.difficultyLabelFor(command.difficulty)}';
  }
  if (command is SetFactionTaxPolicyCommand) {
    return 'Taxes: ${Faction.taxPolicyLabelFor(command.taxPolicy)}';
  }
  if (command is SetDiplomacyStatusCommand) {
    return 'Diplomacy with ${_factionNameFor(game, command.targetFactionId)}: ${OpenDeadlockGame.diplomacyStatusLabelFor(command.status)}';
  }
  if (command is ScanFactionIntelCommand) {
    return 'Scan ${_factionNameFor(game, command.targetFactionId)} intel';
  }
  if (command is SabotageColonyCommand) {
    return 'Sabotage ${_factionNameFor(game, command.targetFactionId)}';
  }
  if (command is MoveUnitCommand) {
    return '${_unitNameFor(game, command.unitId)}: move to ${command.x + 1}, ${command.y + 1}';
  }
  if (command is RecoverUnitCommand) {
    return '${_unitNameFor(game, command.unitId)}: recover';
  }
  if (command is FoundColonyCommand) {
    return '${_unitNameFor(game, command.unitId)}: found ${command.name}';
  }
  if (command is EndTurnCommand) {
    return 'End ${_factionNameFor(game, command.factionId)} turn';
  }
  if (command is RunComputerTurnCommand) {
    return 'Run ${_factionNameFor(game, command.factionId)} AI turn';
  }
  return command.type;
}

String _colonyNameFor(OpenDeadlockGame game, String colonyId) {
  for (final colony in game.colonies) {
    if (colony.id == colonyId) {
      return colony.name;
    }
  }
  return colonyId;
}

String _unitNameFor(OpenDeadlockGame game, String unitId) {
  for (final unit in game.units) {
    if (unit.id == unitId) {
      return unit.name;
    }
  }
  return unitId;
}

String _factionNameFor(OpenDeadlockGame game, String factionId) {
  return game.factionById(factionId)?.name ?? factionId;
}

String _commandPackageResultLabelFor(
  OpenDeadlockGame game,
  CommandPackage package,
) {
  final turn = package.turn == 0 ? game.turn : package.turn;
  final factionName = package.activeFactionName.isNotEmpty
      ? package.activeFactionName
      : _factionNameFor(game, package.activeFactionId);
  final displayFactionName =
      factionName.isEmpty ? game.activeFaction.name : factionName;
  return 'Turn $turn | $displayFactionName';
}

String _commandPackageHandoffLabelFor(
  OpenDeadlockGame game,
  CommandPackage package,
) {
  final turn = package.turn == 0 ? game.turn : package.turn;
  final activeFactionId = package.activeFactionId.isEmpty
      ? game.activeFactionId
      : package.activeFactionId;
  final activeFaction = game.factionById(activeFactionId);
  final activeFactionName = package.activeFactionName.isNotEmpty
      ? package.activeFactionName
      : activeFaction?.name ?? game.activeFaction.name;
  return GameCodec.turnHandoffLabelFor(
    turn: turn,
    activeFactionName: activeFactionName,
    controlMode: activeFaction?.controlMode ?? game.activeFaction.controlMode,
  );
}

String _shortSessionId(String sessionId) {
  if (sessionId.length <= 16) {
    return sessionId;
  }
  return '${sessionId.substring(0, 8)}...${sessionId.substring(sessionId.length - 5)}';
}

int _pendingOrderCountFor(OpenDeadlockGame game, int fromCommandIndex) {
  final startIndex = _clampedCommandIndex(game, fromCommandIndex);
  return game.commandHistory.length - startIndex;
}

int _clampedCommandIndex(OpenDeadlockGame game, int fromCommandIndex) {
  if (fromCommandIndex < 0) {
    return 0;
  }
  if (fromCommandIndex > game.commandHistory.length) {
    return game.commandHistory.length;
  }
  return fromCommandIndex;
}

String _syncActionLabelFor(OpenDeadlockGame game, int pendingOrderCount) {
  if (game.isGameOver) {
    return 'Final state';
  }
  if (game.activeFaction.isRemote) {
    return 'Import orders';
  }
  if (game.activeFaction.isComputer) {
    return 'Run AI';
  }
  if (!game.activeFactionCanIssueLocalOrders) {
    return 'Waiting';
  }
  if (pendingOrderCount == 0) {
    return 'Issue orders';
  }
  if (pendingOrderCount == 1) {
    return 'Send 1 order';
  }
  return 'Send $pendingOrderCount orders';
}

IconData _syncActionIconFor(OpenDeadlockGame game) {
  if (game.isGameOver) {
    return Icons.emoji_events;
  }
  if (game.activeFaction.isRemote) {
    return Icons.cloud_download;
  }
  if (game.activeFaction.isComputer) {
    return Icons.smart_toy;
  }
  return Icons.ios_share;
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

int _readDetailInt(Map<String, String> details, String key) {
  return int.tryParse(details[key] ?? '0') ?? 0;
}

String _signedInt(int value) {
  if (value > 0) {
    return '+$value';
  }
  return '$value';
}

class _NewsGroup {
  const _NewsGroup({
    required this.label,
    required this.icon,
    required this.color,
    required this.reports,
  });

  final String label;
  final IconData icon;
  final Color color;
  final List<TurnReport> reports;
}

class _NewsCategoryStyle {
  const _NewsCategoryStyle({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;
}

List<_NewsGroup> _newsGroupsFor(OpenDeadlockGame game) {
  final groupedReports = <String, List<TurnReport>>{};
  for (final report in game.reports.take(12)) {
    final label = _newsCategoryLabelFor(report);
    groupedReports.putIfAbsent(label, () => <TurnReport>[]).add(report);
  }

  final groups = <_NewsGroup>[];
  for (final entry in groupedReports.entries.take(6)) {
    final style = _newsCategoryStyleFor(entry.key);
    groups.add(
      _NewsGroup(
        label: entry.key,
        icon: style.icon,
        color: style.color,
        reports: entry.value,
      ),
    );
  }
  return groups;
}

String _newsCategoryLabelFor(TurnReport report) {
  final title = report.title.toLowerCase();
  final message = report.message.toLowerCase();

  if (report.isBattle) {
    if (report.details['kind'] == 'colony' &&
        report.details['colonyCaptured'] != 'true') {
      return 'Defense';
    }
    return 'Attack';
  }
  if (title.contains(' wins') ||
      title.contains('defeated') ||
      title.contains('victory')) {
    return 'Victory';
  }
  if (title.contains('researched') ||
      title.contains('research') ||
      message.contains('research completed')) {
    return 'Research';
  }
  if (_isUnitProductionReport(title)) {
    return 'Unit Production';
  }
  if (title.contains(' completed')) {
    return 'Construction';
  }
  if (title.contains('food shortage') ||
      title.contains('riot') ||
      title.contains('unrest') ||
      message.contains('population changed') ||
      message.contains('morale')) {
    return 'Population & Morale';
  }
  if (title.contains('founded') || title.contains('outpost')) {
    return 'Expansion';
  }
  if (title.contains('diplomacy') ||
      title.contains('peace') ||
      title.contains('alliance') ||
      title.contains('war')) {
    return 'Diplomacy';
  }
  if (title.contains('tax') ||
      title.contains('rush') ||
      title.contains('funded') ||
      title.contains('turn ') ||
      message.contains('credits')) {
    return 'Economy';
  }
  if (title.contains('sabotage') ||
      title.contains('scan') ||
      title.contains('intel')) {
    return 'Intelligence';
  }
  return 'General';
}

bool _isUnitProductionReport(String lowerTitle) {
  return lowerTitle.contains('scout patrol completed') ||
      lowerTitle.contains('infantry company completed') ||
      lowerTitle.contains('armor company completed');
}

_NewsCategoryStyle _newsCategoryStyleFor(String label) {
  if (label == 'Attack') {
    return const _NewsCategoryStyle(
      icon: Icons.gps_fixed,
      color: Color(0xFFF0DEC2),
    );
  }
  if (label == 'Defense') {
    return const _NewsCategoryStyle(
      icon: Icons.shield,
      color: Color(0xFFB7D9F5),
    );
  }
  if (label == 'Construction') {
    return const _NewsCategoryStyle(
      icon: Icons.construction,
      color: Color(0xFFD9B66F),
    );
  }
  if (label == 'Unit Production') {
    return const _NewsCategoryStyle(
      icon: Icons.military_tech,
      color: Color(0xFFC4D7A2),
    );
  }
  if (label == 'Population & Morale') {
    return const _NewsCategoryStyle(
      icon: Icons.groups,
      color: Color(0xFFE9B8C3),
    );
  }
  if (label == 'Research') {
    return const _NewsCategoryStyle(
      icon: Icons.science,
      color: Color(0xFF9ED9D4),
    );
  }
  if (label == 'Expansion') {
    return const _NewsCategoryStyle(
      icon: Icons.public,
      color: Color(0xFFAFCBFF),
    );
  }
  if (label == 'Diplomacy') {
    return const _NewsCategoryStyle(
      icon: Icons.handshake,
      color: Color(0xFFD8C4F2),
    );
  }
  if (label == 'Economy') {
    return const _NewsCategoryStyle(
      icon: Icons.account_balance,
      color: Color(0xFFD8D18E),
    );
  }
  if (label == 'Intelligence') {
    return const _NewsCategoryStyle(
      icon: Icons.visibility,
      color: Color(0xFFB0D6C2),
    );
  }
  if (label == 'Victory') {
    return const _NewsCategoryStyle(
      icon: Icons.emoji_events,
      color: Color(0xFFFFD580),
    );
  }
  return const _NewsCategoryStyle(
    icon: Icons.info_outline,
    color: Color(0xFFE9EEF2),
  );
}

class _NewsSummaryDetail extends StatelessWidget {
  const _NewsSummaryDetail({
    Key? key,
    required this.groups,
  }) : super(key: key);

  final List<_NewsGroup> groups;

  @override
  Widget build(BuildContext context) {
    final reportCount = groups.fold<int>(
      0,
      (count, group) => count + group.reports.length,
    );
    final categoryLabel = groups.length == 1 ? 'category' : 'categories';
    final reportLabel = reportCount == 1 ? 'report' : 'reports';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF202B34),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.article, color: Color(0xFFE9EEF2), size: 19),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'News Summary',
                  style: TextStyle(
                    color: Color(0xFFF4F7FA),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  '${groups.length} $categoryLabel / $reportCount $reportLabel',
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: Color(0xFF9FB0BE),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...groups.map((group) => _NewsGroupSection(group: group)),
        ],
      ),
    );
  }
}

class _NewsGroupSection extends StatelessWidget {
  const _NewsGroupSection({
    Key? key,
    required this.group,
  }) : super(key: key);

  final _NewsGroup group;

  @override
  Widget build(BuildContext context) {
    final visibleReports = group.reports.take(2).toList();
    final hiddenCount = group.reports.length - visibleReports.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(group.icon, color: group.color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${group.label} (${group.reports.length})',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: group.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...visibleReports.map((report) => _NewsReportLine(report: report)),
          if (hiddenCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '+$hiddenCount more',
                style: const TextStyle(
                  color: Color(0xFF9FB0BE),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NewsReportLine extends StatelessWidget {
  const _NewsReportLine({
    Key? key,
    required this.report,
  }) : super(key: key);

  final TurnReport report;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 22, bottom: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            report.title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFE9EEF2),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            report.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFB9C5CE),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _TacticalLogDetail extends StatelessWidget {
  const _TacticalLogDetail({
    Key? key,
    required this.reports,
  }) : super(key: key);

  final List<TurnReport> reports;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF202B34),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gps_fixed, color: Color(0xFFF0DEC2), size: 19),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Tactical Log',
                  style: TextStyle(
                    color: Color(0xFFF4F7FA),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${reports.length} recent',
                style: const TextStyle(
                  color: Color(0xFF9FB0BE),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._buildEntries(),
        ],
      ),
    );
  }

  List<Widget> _buildEntries() {
    final entries = <Widget>[];
    for (var index = 0; index < reports.length; index += 1) {
      entries.add(
        _BattleLogEntry(
          report: reports[index],
          isLatest: index == 0,
        ),
      );
    }
    return entries;
  }
}

class _BattleLogEntry extends StatelessWidget {
  const _BattleLogEntry({
    Key? key,
    required this.report,
    required this.isLatest,
  }) : super(key: key);

  final TurnReport report;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    final details = report.details;
    final kind = details['kind'];

    return Container(
      padding: EdgeInsets.only(top: isLatest ? 0 : 10, bottom: 10),
      decoration: BoxDecoration(
        border: Border(
          top: isLatest
              ? BorderSide.none
              : const BorderSide(color: Color(0xFF313B44)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  kind == 'colony'
                      ? Icons.location_city
                      : kind == 'sabotage'
                          ? Icons.construction
                          : Icons.gps_fixed,
                  color: const Color(0xFFF0DEC2),
                  size: 15,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  report.title,
                  style: const TextStyle(
                    color: Color(0xFFE9EEF2),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (kind == 'unit') ...[
            _DetailRow(label: 'Damage', value: _unitDamageLabel(details)),
            _DetailRow(label: 'Health', value: _unitHealthLabel(details)),
            _DetailRow(label: 'Outcome', value: _unitOutcomeLabel(details)),
          ] else if (kind == 'colony') ...[
            _DetailRow(label: 'Assault', value: _colonyAssaultLabel(details)),
            if (_hasColonyDamageDetails(details))
              _DetailRow(label: 'Damage', value: _colonyDamageLabel(details)),
            _DetailRow(label: 'Colony', value: _colonyStatusLabel(details)),
            _DetailRow(label: 'Outcome', value: _colonyOutcomeLabel(details)),
          ] else if (kind == 'sabotage') ...[
            _DetailRow(label: 'Target', value: _sabotageTargetLabel(details)),
            _DetailRow(label: 'Damage', value: _sabotageDamageLabel(details)),
            _DetailRow(
                label: 'Security', value: _sabotageSecurityLabel(details)),
          ],
          _DetailRow(
            label: 'Sector',
            value:
                '${_readDetailInt(details, 'x') + 1}, ${_readDetailInt(details, 'y') + 1}',
          ),
          Text(
            report.message,
            style: const TextStyle(color: Color(0xFFB9C5CE), fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _unitDamageLabel(Map<String, String> details) {
    final attackerName = _detailOrFallback(details, 'attackerName', 'Attacker');
    final defenderName = _detailOrFallback(details, 'defenderName', 'Defender');
    return '$attackerName ${_detailOrFallback(details, 'attackDamage', '0')} / '
        '$defenderName ${_detailOrFallback(details, 'counterDamage', '0')}';
  }

  String _unitHealthLabel(Map<String, String> details) {
    final attackerName = _detailOrFallback(details, 'attackerName', 'Attacker');
    final defenderName = _detailOrFallback(details, 'defenderName', 'Defender');
    return '$attackerName ${_detailOrFallback(details, 'attackerHealth', '0')} / '
        '$defenderName ${_detailOrFallback(details, 'defenderHealth', '0')}';
  }

  String _unitOutcomeLabel(Map<String, String> details) {
    final attackerName = _detailOrFallback(details, 'attackerName', 'Attacker');
    final defenderName = _detailOrFallback(details, 'defenderName', 'Defender');
    final attackerStatus =
        details['attackerSurvived'] == 'true' ? 'survived' : 'destroyed';
    final defenderStatus =
        details['defenderSurvived'] == 'true' ? 'survived' : 'destroyed';
    return '$attackerName $attackerStatus / $defenderName $defenderStatus';
  }

  String _colonyAssaultLabel(Map<String, String> details) {
    return '${_detailOrFallback(details, 'attackPower', '0')} attack vs '
        '${_detailOrFallback(details, 'defensePower', '0')} defense';
  }

  bool _hasColonyDamageDetails(Map<String, String> details) {
    return _hasDetailInt(details, 'populationDelta') ||
        _hasDetailInt(details, 'moraleDelta') ||
        (_hasDetailInt(details, 'previousPopulation') &&
            _hasDetailInt(details, 'population')) ||
        (_hasDetailInt(details, 'previousMorale') &&
            _hasDetailInt(details, 'morale'));
  }

  String _colonyDamageLabel(Map<String, String> details) {
    final populationDelta = _colonyDeltaFor(
      details,
      deltaKey: 'populationDelta',
      previousKey: 'previousPopulation',
      currentKey: 'population',
    );
    final moraleDelta = _colonyDeltaFor(
      details,
      deltaKey: 'moraleDelta',
      previousKey: 'previousMorale',
      currentKey: 'morale',
    );
    return '${_signedInt(populationDelta)} pop / '
        '${_signedInt(moraleDelta)} morale';
  }

  int _colonyDeltaFor(
    Map<String, String> details, {
    required String deltaKey,
    required String previousKey,
    required String currentKey,
  }) {
    final explicitDelta = int.tryParse(details[deltaKey] ?? '');
    if (explicitDelta != null) {
      return explicitDelta;
    }
    return _readDetailInt(details, currentKey) -
        _readDetailInt(details, previousKey);
  }

  String _colonyStatusLabel(Map<String, String> details) {
    return '${_detailOrFallback(details, 'population', '0')} pop / '
        '${_detailOrFallback(details, 'morale', '0')} morale';
  }

  String _colonyOutcomeLabel(Map<String, String> details) {
    final attackerName = _detailOrFallback(details, 'attackerName', 'Attacker');
    final colonyName = _detailOrFallback(details, 'colonyName', 'Colony');
    final captured = details['colonyCaptured'] == 'true';
    final attackerStatus =
        details['attackerSurvived'] == 'true' ? 'survived' : 'destroyed';
    return captured
        ? '$attackerName captured $colonyName'
        : '$colonyName held / $attackerName $attackerStatus';
  }

  String _sabotageTargetLabel(Map<String, String> details) {
    return _detailOrFallback(details, 'colonyName', 'Colony');
  }

  String _sabotageDamageLabel(Map<String, String> details) {
    return '${_detailOrFallback(details, 'damage', '0')} stored industry';
  }

  String _sabotageSecurityLabel(Map<String, String> details) {
    final protection = _detailOrFallback(details, 'protection', '0');
    return protection == '0' ? 'No protection' : '$protection damage blocked';
  }

  String _detailOrFallback(
    Map<String, String> details,
    String key,
    String fallback,
  ) {
    final value = details[key];
    return value == null || value.isEmpty ? fallback : value;
  }

  bool _hasDetailInt(Map<String, String> details, String key) {
    return int.tryParse(details[key] ?? '') != null;
  }
}

class _UnexploredSector extends StatelessWidget {
  const _UnexploredSector();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF202B34),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        children: [
          Icon(Icons.visibility_off, color: Color(0xFFE9EEF2)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Unexplored sector. Move a unit here to reveal terrain and contacts.',
              style: TextStyle(color: Color(0xFFE9EEF2)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySector extends StatelessWidget {
  const _EmptySector({
    Key? key,
    required this.tile,
    required this.assignedColony,
    required this.preferredColony,
    required this.canEdit,
    required this.onAssign,
    required this.onUnassign,
  }) : super(key: key);

  final PlanetTile tile;
  final Colony? assignedColony;
  final Colony? preferredColony;
  final bool canEdit;
  final VoidCallback? onAssign;
  final VoidCallback? onUnassign;

  @override
  Widget build(BuildContext context) {
    final canSettle = tile.ownerId != null && tile.terrain != 'water';
    final isWorked = assignedColony != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF202B34),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                canSettle ? Icons.public : Icons.lock_outline,
                color: const Color(0xFFE9EEF2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  canSettle
                      ? 'Claimed ground suitable for expansion.'
                      : 'No colony operations available here.',
                  style: const TextStyle(color: Color(0xFFE9EEF2)),
                ),
              ),
            ],
          ),
          if (isWorked) ...[
            const SizedBox(height: 8),
            _DetailRow(label: 'Worked By', value: assignedColony!.name),
          ],
          if (canEdit && onAssign != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.grid_view),
                label: Text('Assign to ${preferredColony!.name}'),
                onPressed: onAssign,
              ),
            ),
          ] else if (canEdit && onUnassign != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.grid_off),
                label: const Text('Release Sector'),
                onPressed: onUnassign,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UnitDetail extends StatelessWidget {
  const _UnitDetail({
    Key? key,
    required this.game,
    required this.unit,
    required this.canFoundColony,
    required this.canRecover,
    required this.onFoundColony,
    required this.onRecover,
  }) : super(key: key);

  final OpenDeadlockGame game;
  final Unit unit;
  final bool canFoundColony;
  final bool canRecover;
  final VoidCallback onFoundColony;
  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context) {
    final combatPreviews = _combatPreviews();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF202B34),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(label: 'Unit', value: unit.name),
          _DetailRow(label: 'Type', value: _titleCase(unit.type)),
          _DetailRow(
            label: 'Health',
            value: '${unit.health}/${OpenDeadlockGame.maxHealthFor(unit.type)}',
          ),
          _DetailRow(
            label: 'Combat',
            value:
                '${OpenDeadlockGame.attackFor(unit.type)} attack / ${OpenDeadlockGame.defenseFor(unit.type)} defense',
          ),
          _DetailRow(
            label: 'Moves',
            value:
                '${unit.movesRemaining}/${OpenDeadlockGame.maxMovesFor(unit.type)}',
          ),
          if (combatPreviews.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Combat Preview',
              style: TextStyle(
                color: Color(0xFFF4F7FA),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            ...combatPreviews.map(
              (preview) => _DetailRow(
                label: preview.label,
                value: preview.value,
              ),
            ),
          ],
          if (canFoundColony) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_business),
                label: const Text('Found Colony'),
                onPressed: onFoundColony,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCCD6A6),
                  foregroundColor: const Color(0xFF111418),
                ),
              ),
            ),
          ],
          if (canRecover) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.healing),
                label: const Text('Recover Unit'),
                onPressed: onRecover,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<_CombatPreviewRow> _combatPreviews() {
    if (!game.activeFactionCanIssueLocalOrders ||
        unit.ownerId != game.activeFactionId ||
        unit.movesRemaining <= 0) {
      return const <_CombatPreviewRow>[];
    }

    final previews = <_CombatPreviewRow>[];
    final offsets = const <List<int>>[
      <int>[0, -1],
      <int>[1, 0],
      <int>[0, 1],
      <int>[-1, 0],
    ];

    for (final offset in offsets) {
      final x = unit.x + offset[0];
      final y = unit.y + offset[1];
      if (x < 0 || y < 0 || x >= game.width || y >= game.height) {
        continue;
      }
      final tile = game.tileAt(x, y);
      if (!tile.isExploredBy(game.activeFactionId) ||
          !OpenDeadlockGame.isTerrainPassable(tile.terrain) ||
          unit.movesRemaining <
              OpenDeadlockGame.movementCostForTerrain(tile.terrain)) {
        continue;
      }

      final defender = game.unitAt(x, y);
      if (defender != null && defender.ownerId != unit.ownerId) {
        if (!game.areAtWar(unit.ownerId, defender.ownerId)) {
          continue;
        }
        final preview = game.previewUnitCombat(unit, defender);
        previews.add(
          _CombatPreviewRow(
            label: 'Attack ${defender.name}',
            value: _unitCombatPreviewValue(defender, preview),
          ),
        );
        continue;
      }

      final targetColony = game.colonyAt(x, y);
      if (targetColony != null && targetColony.ownerId != unit.ownerId) {
        if (!game.areAtWar(unit.ownerId, targetColony.ownerId)) {
          continue;
        }
        final preview = game.previewColonyAssault(unit, targetColony);
        previews.add(
          _CombatPreviewRow(
            label: 'Assault ${targetColony.name}',
            value: _colonyAssaultPreviewValue(preview),
          ),
        );
      }
    }

    return previews;
  }

  String _unitCombatPreviewValue(
    Unit defender,
    UnitCombatPreview preview,
  ) {
    return 'Deal ${preview.attackDamage}, counter ${preview.counterDamage}, '
        'you ${preview.attackerHealth}/${OpenDeadlockGame.maxHealthFor(unit.type)}, '
        'target ${preview.defenderHealth}/${OpenDeadlockGame.maxHealthFor(defender.type)}, '
        '${_unitCombatOutcomeLabel(preview)}, ${_riskLabelFor(
      attackerSurvives: preview.attackerSurvives,
      attackerHealth: preview.attackerHealth,
      maxHealth: OpenDeadlockGame.maxHealthFor(unit.type),
      counterDamage: preview.counterDamage,
    )} risk';
  }

  String _colonyAssaultPreviewValue(ColonyAssaultPreview preview) {
    return '${preview.attackPower} vs ${preview.defensePower}, '
        '${preview.colonyCaptured ? 'capture' : 'repelled'}, '
        'you ${preview.attackerHealth}/${OpenDeadlockGame.maxHealthFor(unit.type)}, '
        '${preview.population} pop / ${preview.morale} morale, '
        '${_riskLabelFor(
      attackerSurvives: preview.attackerSurvives,
      attackerHealth: preview.attackerHealth,
      maxHealth: OpenDeadlockGame.maxHealthFor(unit.type),
      counterDamage: preview.counterDamage,
    )} risk';
  }

  String _unitCombatOutcomeLabel(UnitCombatPreview preview) {
    if (preview.attackerSurvives && !preview.defenderSurvives) {
      return 'target destroyed';
    }
    if (!preview.attackerSurvives && preview.defenderSurvives) {
      return 'unit lost';
    }
    if (!preview.attackerSurvives && !preview.defenderSurvives) {
      return 'mutual destruction';
    }
    return 'both survive';
  }

  String _riskLabelFor({
    required bool attackerSurvives,
    required int attackerHealth,
    required int maxHealth,
    required int counterDamage,
  }) {
    if (!attackerSurvives) {
      return 'lethal';
    }
    if (attackerHealth <= 1 || attackerHealth * 3 <= maxHealth) {
      return 'critical';
    }
    if (counterDamage > 0) {
      return 'damaged';
    }
    return 'low';
  }

  String _titleCase(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value.substring(0, 1).toUpperCase() + value.substring(1);
  }
}

class _CombatPreviewRow {
  const _CombatPreviewRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class _ColonyWorkPlanner extends StatelessWidget {
  const _ColonyWorkPlanner({
    Key? key,
    required this.game,
    required this.colony,
    required this.onAssignBestSectors,
    required this.onReleaseAllSectors,
  }) : super(key: key);

  final OpenDeadlockGame game;
  final Colony colony;
  final VoidCallback onAssignBestSectors;
  final VoidCallback onReleaseAllSectors;

  @override
  Widget build(BuildContext context) {
    final capacity = OpenDeadlockGame.assignedSectorCapacityFor(colony);
    final assignedCount = colony.assignedSectors.length;
    final openSlots = _nonNegative(capacity - assignedCount);
    final bestSectors = game.preferredAssignableSectorsFor(colony);
    final assignCount = bestSectors.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailRow(
          label: 'Work Planner',
          value: '$assignedCount/$capacity outlying assigned',
        ),
        _DetailRow(label: 'Open Slots', value: '$openSlots'),
        _DetailRow(
          label: 'Best Sectors',
          value: _bestSectorSummary(bestSectors),
        ),
        _BulkColonyActionButton(
          icon: Icons.grid_view,
          label: assignCount == 0
              ? 'Assign Best Sectors'
              : 'Assign $assignCount Best ${_sectorCountLabel(assignCount)}',
          enabled: assignCount > 0,
          onPressed: onAssignBestSectors,
        ),
        _BulkColonyActionButton(
          icon: Icons.grid_off,
          label: assignedCount == 0
              ? 'Release Worked Sectors'
              : 'Release $assignedCount Worked ${_sectorCountLabel(assignedCount)}',
          enabled: assignedCount > 0,
          onPressed: onReleaseAllSectors,
        ),
      ],
    );
  }

  String _bestSectorSummary(List<PlanetTile> sectors) {
    if (sectors.isEmpty) {
      return 'None';
    }
    final visibleSectors = sectors.take(3).map(_sectorYieldLabel).toList();
    if (sectors.length > visibleSectors.length) {
      visibleSectors.add('+${sectors.length - visibleSectors.length} more');
    }
    return visibleSectors.join(' | ');
  }

  String _sectorYieldLabel(PlanetTile tile) {
    return '${tile.x + 1}, ${tile.y + 1}: ${tile.yields.food}f/${tile.yields.industry}i/${tile.yields.research}r';
  }

  String _sectorCountLabel(int count) {
    return count == 1 ? 'Sector' : 'Sectors';
  }

  int _nonNegative(int value) {
    return value < 0 ? 0 : value;
  }
}

class _ColonyDetail extends StatelessWidget {
  const _ColonyDetail({
    Key? key,
    required this.game,
    required this.colony,
    required this.canEdit,
    required this.onConstructionChanged,
    required this.onRushConstruction,
    required this.onFocusChanged,
    required this.onApplyConstructionToAll,
    required this.onApplyFocusToAll,
    required this.onAssignBestSectors,
    required this.onReleaseAllSectors,
  }) : super(key: key);

  final OpenDeadlockGame game;
  final Colony colony;
  final bool canEdit;
  final void Function(String colonyId, String construction)
      onConstructionChanged;
  final void Function(String colonyId, int industry) onRushConstruction;
  final void Function(String colonyId, String focus) onFocusChanged;
  final void Function(Colony colony) onApplyConstructionToAll;
  final void Function(Colony colony) onApplyFocusToAll;
  final void Function(Colony colony) onAssignBestSectors;
  final void Function(Colony colony) onReleaseAllSectors;

  @override
  Widget build(BuildContext context) {
    final buildCost = OpenDeadlockGame.buildCostFor(colony.construction);
    final buildProgress = _progressValue(colony.storedIndustry, buildCost);
    final completedBuildings = colony.completedBuildings.isEmpty
        ? 'None'
        : colony.completedBuildings.join(', ');
    final projection = game.colonyProductionFor(colony);
    final ownerFaction = game.factionById(colony.ownerId);
    final grossCredits = projection.output.credits + projection.buildingUpkeep;
    final remainingWork = buildCost - colony.storedIndustry;
    final ownerCredits = ownerFaction?.resources.credits ?? 0;
    final affordableRush =
        ownerCredits ~/ OpenDeadlockGame.rushCreditCostPerIndustry;
    final rushIndustry = _rushIndustryFor(remainingWork, affordableRush);
    final rushCost = rushIndustry <= 0
        ? 0
        : OpenDeadlockGame.rushConstructionCostFor(rushIndustry);
    final canRush = canEdit && rushIndustry > 0;
    final focusTargetCount = _focusCopyTargetCount();
    final buildTargetCount = _constructionCopyTargetCount();
    final hasOtherOwnedColonies = _ownedColonyCount() > 1;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF202B34),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(
            label: 'Population',
            value: '${colony.population}/${projection.housingCapacity}',
          ),
          _DetailRow(label: 'Morale', value: '${colony.morale}%'),
          _DetailRow(
            label: 'Stability',
            value:
                '${OpenDeadlockGame.colonyStabilityLabelFor(colony)} - ${OpenDeadlockGame.colonyStabilityDescriptionFor(colony)}',
          ),
          if (projection.isRioting)
            _DetailRow(
              label: 'Riot Loss',
              value: '-${projection.riotIndustryLoss} stored industry / turn',
            )
          else if (OpenDeadlockGame.isColonyRiotSuppressed(colony))
            const _DetailRow(
              label: 'Riot Risk',
              value: 'Suppressed by security buildings',
            ),
          _DetailRow(
            label: 'Defense',
            value: '${game.colonyDefenseForColony(colony)}',
          ),
          _DetailRow(
            label: 'Security',
            value:
                '${game.sabotageProtectionForColony(colony)} sabotage protection',
          ),
          if (canEdit)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ColonyFocusDropdown(
                  colony: colony,
                  onFocusChanged: onFocusChanged,
                ),
                if (hasOtherOwnedColonies)
                  _BulkColonyActionButton(
                    icon: Icons.tune,
                    label:
                        'Apply ${OpenDeadlockGame.colonyFocusLabelFor(colony.focus)} focus to $focusTargetCount ${_colonyCountLabel(focusTargetCount)}',
                    enabled: focusTargetCount > 0,
                    onPressed: () => onApplyFocusToAll(colony),
                  ),
              ],
            )
          else
            _DetailRow(
              label: 'Focus',
              value: OpenDeadlockGame.colonyFocusLabelFor(colony.focus),
            ),
          _DetailRow(
            label: 'Output',
            value:
                '${projection.output.food} food / ${projection.output.industry} ind / ${projection.output.research} res / ${projection.output.credits} cred',
          ),
          _DetailRow(
            label: 'Upkeep',
            value: '${projection.buildingUpkeep} credits',
          ),
          _DetailRow(
            label: 'Income',
            value:
                '$grossCredits gross - ${projection.buildingUpkeep} upkeep = ${projection.output.credits} net',
          ),
          _DetailRow(
            label: 'Worked',
            value:
                '${projection.workedSectors}/${OpenDeadlockGame.workSectorCapacityFor(colony)} sectors',
          ),
          _DetailRow(
            label: 'Terrain Yield',
            value:
                '${projection.workedYields.food} food / ${projection.workedYields.industry} ind / ${projection.workedYields.research} res',
          ),
          if (canEdit)
            _ColonyWorkPlanner(
              game: game,
              colony: colony,
              onAssignBestSectors: () => onAssignBestSectors(colony),
              onReleaseAllSectors: () => onReleaseAllSectors(colony),
            ),
          _DetailRow(
            label: 'Food',
            value:
                '${_signedInt(projection.foodBalance)} after ${projection.foodDemand} demand',
          ),
          _DetailRow(
            label: 'Growth',
            value: _growthLabel(projection),
          ),
          _DetailRow(
            label: 'Morale Next',
            value:
                '${colony.morale}% -> ${projection.nextMorale}% (${_signedInt(projection.moraleChange)})',
          ),
          _DetailRow(
            label: 'Morale Drivers',
            value: _moraleDriversLabel(projection, ownerFaction),
          ),
          if (canEdit)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BuildOrderDropdown(
                  colony: colony,
                  onConstructionChanged: onConstructionChanged,
                ),
                if (hasOtherOwnedColonies)
                  _BulkColonyActionButton(
                    icon: Icons.playlist_add_check,
                    label:
                        'Queue ${colony.construction} in $buildTargetCount ${_colonyCountLabel(buildTargetCount)}',
                    enabled: buildTargetCount > 0,
                    onPressed: () => onApplyConstructionToAll(colony),
                  ),
              ],
            )
          else
            _DetailRow(label: 'Building', value: colony.construction),
          _DetailRow(
            label: 'Build Info',
            value: OpenDeadlockGame.constructionSummaryFor(
              colony.construction,
            ),
          ),
          _DetailRow(label: 'Completed', value: completedBuildings),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: buildProgress,
              minHeight: 10,
              backgroundColor: const Color(0xFF101418),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFCCD6A6)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${colony.storedIndustry}/$buildCost industry stored (+${projection.constructionWork})',
            style: const TextStyle(color: Color(0xFFCAD3DB), fontSize: 12),
          ),
          if (canEdit) ...[
            const SizedBox(height: 8),
            _DetailRow(
              label: 'Rush Cost',
              value:
                  '${OpenDeadlockGame.rushCreditCostPerIndustry} credits / industry',
            ),
            Tooltip(
              message: canRush
                  ? 'Buy $rushIndustry industry for $rushCost credits'
                  : 'Need credits and unfinished construction',
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.flash_on),
                  label: Text(
                    canRush ? 'Rush +$rushIndustry' : 'Rush Build',
                  ),
                  onPressed: canRush
                      ? () => onRushConstruction(colony.id, rushIndustry)
                      : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _rushIndustryFor(int remainingWork, int affordableIndustry) {
    final availableWork =
        remainingWork < affordableIndustry ? remainingWork : affordableIndustry;
    if (availableWork < 0) {
      return 0;
    }
    return availableWork;
  }

  int _ownedColonyCount() {
    var count = 0;
    for (final currentColony in game.colonies) {
      if (currentColony.ownerId == colony.ownerId) {
        count += 1;
      }
    }
    return count;
  }

  int _focusCopyTargetCount() {
    var count = 0;
    for (final targetColony in game.colonies) {
      if (targetColony.ownerId == colony.ownerId &&
          targetColony.id != colony.id &&
          targetColony.focus != colony.focus) {
        count += 1;
      }
    }
    return count;
  }

  int _constructionCopyTargetCount() {
    var count = 0;
    for (final targetColony in game.colonies) {
      if (_canCopyConstructionTo(targetColony)) {
        count += 1;
      }
    }
    return count;
  }

  bool _canCopyConstructionTo(Colony targetColony) {
    return targetColony.ownerId == colony.ownerId &&
        targetColony.id != colony.id &&
        targetColony.construction != colony.construction &&
        !OpenDeadlockGame.isCompletedConstruction(
          targetColony,
          colony.construction,
        ) &&
        OpenDeadlockGame.isConstructionAvailableFor(
          targetColony,
          colony.construction,
        );
  }

  String _colonyCountLabel(int count) {
    return count == 1 ? 'colony' : 'colonies';
  }

  String _growthLabel(ColonyProduction projection) {
    final growth =
        '${_signedInt(projection.populationChange)} pop / ${_signedInt(projection.moraleChange)} morale';
    if (projection.populationChange == 0 &&
        projection.foodBalance > 0 &&
        projection.isAtHousingCapacity) {
      return '$growth (housing cap)';
    }
    return growth;
  }

  String _moraleDriversLabel(
    ColonyProduction projection,
    Faction? ownerFaction,
  ) {
    final drivers = <String>[];
    if (projection.willCompleteConstruction) {
      drivers.add('build complete +2');
    }
    if (projection.foodBalance < 0) {
      drivers.add('food shortage -8');
    } else if (projection.foodBalance > 0) {
      drivers.add('food surplus stable');
    } else {
      drivers.add('food balanced');
    }
    final taxMorale = _taxMoraleDeltaFor(ownerFaction);
    if (taxMorale != 0 && ownerFaction != null) {
      drivers.add(
        '${_taxMoraleDriverNameFor(ownerFaction.taxPolicy)} ${_signedInt(taxMorale)}',
      );
    }
    if (projection.isRioting) {
      drivers.add('riots active');
    } else if (projection.isInUnrest) {
      drivers.add('unrest active');
    }
    return drivers.join(' / ');
  }

  String _taxMoraleDriverNameFor(String taxPolicy) {
    if (taxPolicy == Faction.taxPolicyRelief) {
      return 'tax relief';
    }
    if (taxPolicy == Faction.taxPolicyHigh) {
      return 'high taxes';
    }
    if (taxPolicy == Faction.taxPolicyEmergency) {
      return 'emergency taxes';
    }
    return Faction.taxPolicyLabelFor(taxPolicy).toLowerCase();
  }

  int _taxMoraleDeltaFor(Faction? ownerFaction) {
    if (ownerFaction == null) {
      return 0;
    }
    if (ownerFaction.taxPolicy == Faction.taxPolicyRelief) {
      return 2;
    }
    if (ownerFaction.taxPolicy == Faction.taxPolicyHigh) {
      return -2;
    }
    if (ownerFaction.taxPolicy == Faction.taxPolicyEmergency) {
      return -5;
    }
    return 0;
  }

  double _progressValue(int storedIndustry, int buildCost) {
    final progress = storedIndustry / buildCost;
    if (progress < 0) {
      return 0;
    }
    if (progress > 1) {
      return 1;
    }
    return progress;
  }
}

class _BulkColonyActionButton extends StatelessWidget {
  const _BulkColonyActionButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
  }) : super(key: key);

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 92, bottom: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: Icon(icon, size: 16),
          label: Text(label),
          onPressed: enabled ? onPressed : null,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFCCD6A6),
            disabledForegroundColor: const Color(0xFF6D7C88),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }
}

class _ColonyFocusDropdown extends StatelessWidget {
  const _ColonyFocusDropdown({
    Key? key,
    required this.colony,
    required this.onFocusChanged,
  }) : super(key: key);

  final Colony colony;
  final void Function(String colonyId, String focus) onFocusChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: 92,
            child: Text(
              'Focus',
              style: TextStyle(
                  color: Color(0xFF9FB0BE), fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: OpenDeadlockGame.isKnownColonyFocus(colony.focus)
                    ? colony.focus
                    : OpenDeadlockGame.colonyFocusBalanced,
                isExpanded: true,
                dropdownColor: const Color(0xFF202B34),
                iconEnabledColor: const Color(0xFFE9EEF2),
                style: const TextStyle(color: Color(0xFFE9EEF2)),
                items: OpenDeadlockGame.colonyFocuses.map((focus) {
                  return DropdownMenuItem<String>(
                    value: focus,
                    child: Text(
                      '${OpenDeadlockGame.colonyFocusLabelFor(focus)} - ${OpenDeadlockGame.colonyFocusDescriptionFor(focus)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null || value == colony.focus) {
                    return;
                  }
                  onFocusChanged(colony.id, value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BuildOrderDropdown extends StatelessWidget {
  const _BuildOrderDropdown({
    Key? key,
    required this.colony,
    required this.onConstructionChanged,
  }) : super(key: key);

  final Colony colony;
  final void Function(String colonyId, String construction)
      onConstructionChanged;

  @override
  Widget build(BuildContext context) {
    final buildOptions = OpenDeadlockGame.constructionOptions.where((option) {
      return option == colony.construction ||
          (!OpenDeadlockGame.isCompletedConstruction(colony, option) &&
              OpenDeadlockGame.isConstructionAvailableFor(colony, option));
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: 92,
            child: Text(
              'Building',
              style: TextStyle(
                  color: Color(0xFF9FB0BE), fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: colony.construction,
                isExpanded: true,
                dropdownColor: const Color(0xFF202B34),
                iconEnabledColor: const Color(0xFFE9EEF2),
                style: const TextStyle(color: Color(0xFFE9EEF2)),
                items: buildOptions.map((option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(
                      option,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  onConstructionChanged(colony.id, value);
                },
              ),
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                  color: Color(0xFF9FB0BE), fontWeight: FontWeight.w600),
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

class _ReportLine extends StatelessWidget {
  const _ReportLine({
    Key? key,
    required this.report,
  }) : super(key: key);

  final TurnReport report;

  @override
  Widget build(BuildContext context) {
    final titleColor =
        report.isBattle ? const Color(0xFFF0DEC2) : const Color(0xFFE9EEF2);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (report.isBattle) ...[
                const Icon(Icons.gps_fixed, color: Color(0xFFF0DEC2), size: 14),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: Text(
                  report.title,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            report.message,
            style: const TextStyle(color: Color(0xFFB9C5CE), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
