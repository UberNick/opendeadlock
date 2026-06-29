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
const String _musicPreferenceKey = 'opendeadlock.music_enabled';
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
  bool musicEnabled = true;
  String? lastSyncStatus;
  final List<_SyncLedgerEntry> syncLedgerEntries = <_SyncLedgerEntry>[];

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
              musicEnabled: musicEnabled,
              onToggleMusic: _toggleMusic,
              onToggleHotseat: _toggleHotseatMode,
              canUndoLastOrder: _canUndoLastOrder,
              onUndoLastOrder: _undoLastOrder,
              onEndTurn: _requestEndTurn,
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
                    syncLedgerEntries: syncLedgerEntries,
                    soundEffectsEnabled: soundEffectsEnabled,
                    musicEnabled: musicEnabled,
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
                    onSelectUnit: (unit) {
                      setState(() {
                        selectedX = unit.x;
                        selectedY = unit.y;
                        selectedUnitId = unit.id;
                      });
                    },
                    onSelectSector: _handleTileSelected,
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
                    onCopyOrders: _copyOrdersToClipboard,
                    onExportOrdersFile: _exportOrdersToFile,
                    onApplyOrders: _applyOrdersFromClipboard,
                    onImportOrdersFile: _importOrdersFromFile,
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
      final storedMusic = store.preferences.getBool(_musicPreferenceKey);
      if (!mounted) {
        return;
      }
      setState(() {
        saveStore = store;
        latestSaveSlot = latestSlot;
        soundEffectsEnabled = storedSoundEffects ?? true;
        musicEnabled = storedMusic ?? true;
        if (widget.resumeLatestSave && loadedGame != null) {
          game = loadedGame;
          orderExportBaseCommandCount = loadedGame.commandHistory.length;
          syncLedgerEntries.clear();
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

  Future<void> _requestEndTurn() async {
    if (!game.activeFactionCanIssueLocalOrders) {
      return;
    }

    final review = _turnReviewSummaryFor(game, orderExportBaseCommandCount);
    if (review.needsConfirmation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _EndTurnReviewDialog(review: review),
      );
      if (confirmed != true || !mounted) {
        return;
      }
    }

    _endTurn();
  }

  void _endTurn() {
    _replaceGame(
      game.applyCommand(
        EndTurnCommand(factionId: game.activeFactionId),
      ),
      undoable: true,
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

  Future<void> _toggleMusic() async {
    final enabled = !musicEnabled;
    setState(() {
      musicEnabled = enabled;
    });
    try {
      final store = await _ensureSaveStore();
      await store.preferences.setBool(_musicPreferenceKey, enabled);
    } on Object catch (error) {
      debugPrint('Could not save music preference: $error');
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
        content: Text(enabled ? 'Music enabled' : 'Music paused'),
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
        syncLedgerEntries.clear();
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
          syncLedgerEntries.clear();
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
          syncLedgerEntries.clear();
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
      final ledgerEntry = _SyncLedgerEntry.fromPackage(
        preview: preview,
        package: package,
        source: successPrefix == 'Imported' ? 'Imported File' : 'Typed Code',
        status: syncStatus,
      );
      _replaceGame(
        updatedGame,
        afterSet: (_) {
          orderExportBaseCommandCount = updatedGame.commandHistory.length;
          lastSyncStatus = syncStatus;
          syncLedgerEntries.insert(0, ledgerEntry);
          if (syncLedgerEntries.length > 4) {
            syncLedgerEntries.removeRange(4, syncLedgerEntries.length);
          }
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
      final preparedInvite = _createInviteForFaction(factionId);
      final confirmed = await _showInvitePreviewDialog(
        preparedInvite.invite,
        title: 'Review Invite',
        confirmLabel: 'Copy Invite',
        confirmIcon: Icons.content_copy,
      );
      if (confirmed != true || !mounted) {
        return;
      }
      await Clipboard.setData(
        ClipboardData(text: GameCodec.encodeShareCode(preparedInvite.encoded)),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Invite code copied for ${preparedInvite.invite.invitedFactionName}')),
      );
    } on Object catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not copy invite: $error')),
      );
    }
  }

  Future<void> _exportInviteForFaction(String factionId) async {
    try {
      final preparedInvite = _createInviteForFaction(factionId);
      final confirmed = await _showInvitePreviewDialog(
        preparedInvite.invite,
        title: 'Review Invite',
        confirmLabel: 'Save Invite',
        confirmIcon: Icons.save_alt,
      );
      if (confirmed != true || !mounted) {
        return;
      }
      final fileName = _inviteFileName(preparedInvite.invite);
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
        content: GameCodec.encodeShareCode(preparedInvite.encoded),
        fileName: fileName,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Invite file saved for ${preparedInvite.invite.invitedFactionName}')),
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

  _PreparedInvite _createInviteForFaction(String factionId) {
    final invitedFaction = game.factionById(factionId);
    if (invitedFaction == null) {
      throw ArgumentError('Unknown faction: $factionId.');
    }
    final hostFaction = game.factions.firstWhere(
      (faction) => faction.isLocal,
      orElse: () => game.activeFaction,
    );
    final encoded = GameCodec.encodeGameInvite(
      game,
      hostFactionId: hostFaction.id,
      invitedFactionId: factionId,
    );
    return _PreparedInvite(
      encoded: encoded,
      invite: GameCodec.decodeGameInvite(encoded),
    );
  }

  Future<bool?> _showInvitePreviewDialog(
    GameInvite invite, {
    required String title,
    required String confirmLabel,
    required IconData confirmIcon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => _InvitePreviewDialog(
        title: title,
        confirmLabel: confirmLabel,
        confirmIcon: confirmIcon,
        invite: invite,
      ),
    );
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

class _PreparedInvite {
  const _PreparedInvite({
    required this.encoded,
    required this.invite,
  });

  final String encoded;
  final GameInvite invite;
}

class _SyncLedgerEntry {
  const _SyncLedgerEntry({
    required this.source,
    required this.sender,
    required this.status,
    required this.orders,
    required this.handoff,
    required this.baseCommandFingerprint,
    required this.resultStateFingerprint,
  });

  factory _SyncLedgerEntry.fromPackage({
    required CommandPackagePreview preview,
    required CommandPackage package,
    required String source,
    required String status,
  }) {
    return _SyncLedgerEntry(
      source: source,
      sender: preview.exportedByFactionName,
      status: status,
      orders: preview.newCommandCount,
      handoff: preview.handoffLabel,
      baseCommandFingerprint: package.baseCommandFingerprint,
      resultStateFingerprint: preview.stateFingerprint,
    );
  }

  final String source;
  final String sender;
  final String status;
  final int orders;
  final String handoff;
  final String baseCommandFingerprint;
  final String resultStateFingerprint;
}

class _InvitePreviewDialog extends StatelessWidget {
  const _InvitePreviewDialog({
    Key? key,
    required this.title,
    required this.confirmLabel,
    required this.confirmIcon,
    required this.invite,
  }) : super(key: key);

  final String title;
  final String confirmLabel;
  final IconData confirmIcon;
  final GameInvite invite;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF202B34),
      title: Text(
        title,
        style: const TextStyle(color: Color(0xFFF4F7FA)),
      ),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invite ${invite.invitedFactionName} to session ${_shortSessionId(invite.sessionId)}',
              style: const TextStyle(
                color: Color(0xFFF4F7FA),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _DetailRow(label: 'Host', value: invite.hostFactionName),
            _DetailRow(label: 'Guest', value: invite.invitedFactionName),
            _DetailRow(label: 'Session', value: invite.sessionId),
            _DetailRow(
              label: 'Commands',
              value: '${invite.commandCount} in snapshot',
            ),
            _DetailRow(label: 'State', value: invite.stateFingerprint),
            const SizedBox(height: 8),
            const Text(
              'The guest will load a local perspective where this faction is playable and the host is remote.',
              style: TextStyle(color: Color(0xFFE9EEF2)),
            ),
          ],
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
              _DetailRow(
                label: 'Share With',
                value: _commandPackageRecipientLabelFor(game, package),
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
              _DetailRow(
                label: 'Base State',
                value: _shortFingerprint(package.baseCommandFingerprint),
              ),
              _DetailRow(
                label: 'Result State',
                value: _shortFingerprint(package.stateFingerprint),
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

class _CommandBarMenuSelection {
  const _CommandBarMenuSelection(
    this.action, {
    this.factionId,
  });

  final _CommandBarAction action;
  final String? factionId;
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
    required this.musicEnabled,
    required this.onToggleMusic,
    required this.onToggleHotseat,
    required this.canUndoLastOrder,
    required this.onUndoLastOrder,
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
  final bool musicEnabled;
  final VoidCallback onToggleMusic;
  final VoidCallback onToggleHotseat;
  final bool canUndoLastOrder;
  final VoidCallback onUndoLastOrder;
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
                        _undoButton(),
                        const SizedBox(width: 2),
                        _soundButton(),
                        const SizedBox(width: 2),
                        _musicButton(),
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
                    _undoButton(),
                    const SizedBox(width: 4),
                    _soundButton(),
                    const SizedBox(width: 4),
                    _musicButton(),
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

  Widget _undoButton() {
    return IconButton(
      tooltip: 'Undo last order',
      color: Colors.white,
      disabledColor: const Color(0xFF6B7784),
      icon: const Icon(Icons.undo),
      onPressed: canUndoLastOrder ? onUndoLastOrder : null,
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

  Widget _musicButton() {
    return IconButton(
      tooltip: musicEnabled ? 'Pause music' : 'Resume music',
      color: Colors.white,
      icon: Icon(musicEnabled ? Icons.music_note : Icons.music_off),
      onPressed: onToggleMusic,
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
    final remoteInviteFactions = _remoteInviteFactions();
    return PopupMenuButton<_CommandBarMenuSelection>(
      tooltip: 'Sync',
      color: const Color(0xFF202B34),
      icon: const Icon(Icons.sync_alt, color: Colors.white),
      onSelected: (selection) => _handleMenuAction(context, selection),
      itemBuilder: (context) => <PopupMenuEntry<_CommandBarMenuSelection>>[
        const PopupMenuItem<_CommandBarMenuSelection>(
          value: _CommandBarMenuSelection(_CommandBarAction.saveLocal),
          child: _SyncMenuItem(icon: Icons.save, label: 'Save Local'),
        ),
        PopupMenuItem<_CommandBarMenuSelection>(
          value: const _CommandBarMenuSelection(_CommandBarAction.loadLocal),
          enabled: latestSaveSlot != null,
          child:
              const _SyncMenuItem(icon: Icons.folder_open, label: 'Load Local'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<_CommandBarMenuSelection>(
          value: _CommandBarMenuSelection(_CommandBarAction.copySnapshot),
          child:
              _SyncMenuItem(icon: Icons.content_copy, label: 'Copy Snapshot'),
        ),
        const PopupMenuItem<_CommandBarMenuSelection>(
          value: _CommandBarMenuSelection(_CommandBarAction.exportSnapshotFile),
          child:
              _SyncMenuItem(icon: Icons.save_alt, label: 'Save Snapshot File'),
        ),
        const PopupMenuItem<_CommandBarMenuSelection>(
          value: _CommandBarMenuSelection(_CommandBarAction.loadSnapshot),
          child: _SyncMenuItem(icon: Icons.upload_file, label: 'Load Snapshot'),
        ),
        const PopupMenuItem<_CommandBarMenuSelection>(
          value: _CommandBarMenuSelection(_CommandBarAction.importSnapshotFile),
          child: _SyncMenuItem(
              icon: Icons.drive_folder_upload, label: 'Import Snapshot File'),
        ),
        if (remoteInviteFactions.isNotEmpty) ...[
          const PopupMenuDivider(),
          ..._inviteMenuEntries(remoteInviteFactions),
        ],
        const PopupMenuItem<_CommandBarMenuSelection>(
          value: _CommandBarMenuSelection(_CommandBarAction.loadInvite),
          child:
              _SyncMenuItem(icon: Icons.person_add_alt_1, label: 'Load Invite'),
        ),
        const PopupMenuItem<_CommandBarMenuSelection>(
          value: _CommandBarMenuSelection(_CommandBarAction.importInviteFile),
          child: _SyncMenuItem(
              icon: Icons.drive_folder_upload, label: 'Import Invite File'),
        ),
        const PopupMenuItem<_CommandBarMenuSelection>(
          value: _CommandBarMenuSelection(_CommandBarAction.copyOrders),
          child: _SyncMenuItem(icon: Icons.ios_share, label: 'Copy Orders'),
        ),
        const PopupMenuItem<_CommandBarMenuSelection>(
          value: _CommandBarMenuSelection(_CommandBarAction.exportOrdersFile),
          child:
              _SyncMenuItem(icon: Icons.save_alt, label: 'Export Orders File'),
        ),
        const PopupMenuItem<_CommandBarMenuSelection>(
          value: _CommandBarMenuSelection(_CommandBarAction.applyOrders),
          child: _SyncMenuItem(
              icon: Icons.playlist_add_check, label: 'Apply Orders'),
        ),
        const PopupMenuItem<_CommandBarMenuSelection>(
          value: _CommandBarMenuSelection(_CommandBarAction.importOrdersFile),
          child: _SyncMenuItem(
              icon: Icons.drive_folder_upload, label: 'Import Orders File'),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<_CommandBarMenuSelection>(
          value:
              const _CommandBarMenuSelection(_CommandBarAction.toggleHotseat),
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

  List<PopupMenuEntry<_CommandBarMenuSelection>> _inviteMenuEntries(
    List<Faction> remoteFactions,
  ) {
    final singleInvite = remoteFactions.length == 1;
    return remoteFactions.expand((faction) {
      final copyLabel =
          singleInvite ? 'Copy Invite' : 'Copy Invite: ${faction.name}';
      final saveLabel =
          singleInvite ? 'Save Invite' : 'Save Invite: ${faction.name}';
      return <PopupMenuEntry<_CommandBarMenuSelection>>[
        PopupMenuItem<_CommandBarMenuSelection>(
          value: _CommandBarMenuSelection(
            _CommandBarAction.copyInvite,
            factionId: faction.id,
          ),
          child: _SyncMenuItem(
            icon: Icons.person_add_alt_1,
            label: copyLabel,
          ),
        ),
        PopupMenuItem<_CommandBarMenuSelection>(
          value: _CommandBarMenuSelection(
            _CommandBarAction.exportInviteFile,
            factionId: faction.id,
          ),
          child: _SyncMenuItem(
            icon: Icons.save_alt,
            label: saveLabel,
          ),
        ),
      ];
    }).toList();
  }

  void _handleMenuAction(
    BuildContext context,
    _CommandBarMenuSelection selection,
  ) {
    final action = selection.action;
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
      final factionId = selection.factionId;
      if (factionId != null) {
        onCopyInvite(factionId);
      }
      return;
    }
    if (action == _CommandBarAction.exportInviteFile) {
      final factionId = selection.factionId;
      if (factionId != null) {
        onExportInvite(factionId);
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

  List<Faction> _remoteInviteFactions() {
    if (!game.activeFactionCanIssueLocalOrders) {
      return const <Faction>[];
    }
    return game.factions.where((faction) => faction.isRemote).toList();
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
        final actionTooltip = _actionTooltipFor(tile, selectedUnit, actionHint);

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
          actionTooltip: actionTooltip,
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

  String? _actionTooltipFor(
    PlanetTile tile,
    Unit? selectedUnit,
    _TileActionHint actionHint,
  ) {
    if (selectedUnit == null || actionHint == _TileActionHint.none) {
      return null;
    }
    if (actionHint == _TileActionHint.move) {
      return 'Move to sector ${tile.x + 1}, ${tile.y + 1} '
          '(${OpenDeadlockGame.movementCostForTerrain(tile.terrain)} move)';
    }
    if (actionHint == _TileActionHint.attack) {
      final defender = game.visibleUnitAt(game.activeFactionId, tile.x, tile.y);
      if (defender == null || defender.ownerId == selectedUnit.ownerId) {
        return null;
      }
      final preview = game.previewUnitCombat(selectedUnit, defender);
      return 'Attack ${defender.name}: '
          '${_unitCombatPreviewValueFor(selectedUnit, defender, preview)}';
    }
    final targetColony = game.colonyAt(tile.x, tile.y);
    if (targetColony == null || targetColony.ownerId == selectedUnit.ownerId) {
      return null;
    }
    final preview = game.previewColonyAssault(selectedUnit, targetColony);
    return 'Assault ${targetColony.name}: '
        '${_colonyAssaultPreviewValueFor(selectedUnit, preview)}';
  }

  int _manhattanDistance(int ax, int ay, int bx, int by) {
    return _absolute(ax - bx) + _absolute(ay - by);
  }

  int _absolute(int value) {
    return value < 0 ? -value : value;
  }
}

enum _TileActionHint { none, move, attack, assault }

String _unitOrderKeyNameFor(_TileActionHint hint) {
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
    required this.actionTooltip,
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
  final String? actionTooltip;
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
    final textureAsset = isKnown ? _terrainTextureAssetFor(tile.terrain) : null;
    final displayedUnit = isKnown ? unit : null;

    final tileButton = InkWell(
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
            if (textureAsset != null)
              Positioned.fill(
                child: Image.asset(
                  textureAsset,
                  key: ValueKey<String>('terrain-texture-${tile.x}-${tile.y}'),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.low,
                  excludeFromSemantics: true,
                ),
              ),
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
                  hasTexture: textureAsset != null,
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
            if (isKnown && displayedUnit == null)
              Align(
                alignment: Alignment.bottomRight,
                child: Tooltip(
                  message: _terrainLabel(tile.terrain),
                  child: Container(
                    key: ValueKey<String>('terrain-badge-${tile.x}-${tile.y}'),
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
            if (displayedUnit != null)
              Align(
                alignment: hasColony ? Alignment.bottomRight : Alignment.center,
                child: Tooltip(
                  message: _unitMarkerTooltip(displayedUnit),
                  child: Container(
                    key: ValueKey<String>('unit-marker-${displayedUnit.id}'),
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
                    child: Icon(
                      _iconForUnitType(displayedUnit.type),
                      key: ValueKey<String>(
                        'unit-icon-${displayedUnit.type}-${tile.x}-${tile.y}',
                      ),
                      size: isSelectedUnit ? 16 : 14,
                      color: const Color(0xFF111418),
                    ),
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
    );

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: Colors.transparent,
        child: actionTooltip == null
            ? tileButton
            : Tooltip(
                message: actionTooltip!,
                child: tileButton,
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

  String? _terrainTextureAssetFor(String terrain) {
    if (terrain == 'plains') {
      return 'assets/images/terrain/plains.png';
    }
    if (terrain == 'forest') {
      return 'assets/images/terrain/forest.png';
    }
    if (terrain == 'ridge') {
      return 'assets/images/terrain/ridge.png';
    }
    if (terrain == 'water') {
      return 'assets/images/terrain/water.png';
    }
    if (terrain == 'ruins') {
      return 'assets/images/terrain/ruins.png';
    }
    return null;
  }

  IconData _iconForUnitType(String unitType) {
    if (unitType == 'infantry') {
      return Icons.security;
    }
    if (unitType == 'armor') {
      return Icons.local_shipping;
    }
    return Icons.explore;
  }

  String _unitMarkerTooltip(Unit unit) {
    return '${unit.name} | ${_unitTypeLabel(unit.type)} | '
        '${unit.health}/${OpenDeadlockGame.maxHealthFor(unit.type)} health | '
        '${unit.movesRemaining}/${OpenDeadlockGame.maxMovesFor(unit.type)} moves';
  }

  String _unitTypeLabel(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value.substring(0, 1).toUpperCase() + value.substring(1);
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
    required this.hasTexture,
  });

  final String terrain;
  final TileYield yields;
  final bool isExplored;
  final bool isVisible;
  final Color? ownerColor;
  final _MapOverlayMode overlayMode;
  final bool isSelected;
  final bool hasTexture;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final isKnown = isExplored || isVisible;
    final baseColor =
        isKnown ? _terrainBaseColor(terrain) : const Color(0xFF050607);
    final accentColor =
        isKnown ? _terrainAccentColor(terrain) : const Color(0xFF151A1F);

    canvas.drawRect(
      rect,
      Paint()
        ..color = hasTexture && isKnown
            ? baseColor.withValues(alpha: 0.28)
            : baseColor,
    );
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
        oldDelegate.isSelected != isSelected ||
        oldDelegate.hasTexture != hasTexture;
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
    required this.syncLedgerEntries,
    required this.soundEffectsEnabled,
    required this.musicEnabled,
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
    required this.onSelectUnit,
    required this.onSelectSector,
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
    required this.onCopyOrders,
    required this.onExportOrdersFile,
    required this.onApplyOrders,
    required this.onImportOrdersFile,
    required this.canUndoLastOrder,
    required this.onUndoLastOrder,
  }) : super(key: key);

  final OpenDeadlockGame game;
  final SavedGameSlot? latestSaveSlot;
  final int orderExportBaseCommandCount;
  final String? lastSyncStatus;
  final List<_SyncLedgerEntry> syncLedgerEntries;
  final bool soundEffectsEnabled;
  final bool musicEnabled;
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
  final void Function(Unit unit) onSelectUnit;
  final void Function(int x, int y) onSelectSector;
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
  final Future<void> Function() onCopyOrders;
  final Future<void> Function() onExportOrdersFile;
  final Future<void> Function() onApplyOrders;
  final Future<void> Function() onImportOrdersFile;
  final bool canUndoLastOrder;
  final VoidCallback onUndoLastOrder;

  @override
  Widget build(BuildContext context) {
    final owner = game.factionById(tile.ownerId);
    final canIssueLocalOrders = game.activeFactionCanIssueLocalOrders;
    final newsGroups = _newsGroupsFor(game);
    final tacticalReports = _tacticalReports(game);
    final latestBattleReport = _latestBattleReport(game);
    final assignedColony =
        isExplored ? game.assignedColonyForSector(tile.x, tile.y) : null;
    final activeColonies = game.colonies
        .where((currentColony) => currentColony.ownerId == game.activeFactionId)
        .toList(growable: false);
    final activeUnits = game.units
        .where((currentUnit) => currentUnit.ownerId == game.activeFactionId)
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
            _VictoryCutsceneDetail(game: game),
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
            _DetailRow(
              label: 'Terrain',
              value: OpenDeadlockGame.terrainLabelFor(tile.terrain),
            ),
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
            const SizedBox(height: 4),
            _TerrainCatalogDetail(activeTerrain: tile.terrain),
          ],
          if (latestBattleReport != null) ...[
            const SizedBox(height: 12),
            _LatestBattleDetail(report: latestBattleReport),
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
            if (unit!.ownerId == game.activeFactionId) ...[
              const SizedBox(height: 12),
              _UnitOrdersDetail(
                game: game,
                unit: unit!,
                onSelectSector: onSelectSector,
              ),
            ],
          ],
          if (activeUnits.isNotEmpty) ...[
            const SizedBox(height: 18),
            _UnitRosterDetail(
              units: activeUnits,
              selectedUnitId:
                  unit?.ownerId == game.activeFactionId ? unit?.id : null,
              onSelectUnit: onSelectUnit,
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
          _AudioSettingsDetail(
            soundEffectsEnabled: soundEffectsEnabled,
            musicEnabled: musicEnabled,
          ),
          const SizedBox(height: 18),
          _FactionEconomyDetail(game: game, faction: game.activeFaction),
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
          _IntelOperationsDetail(
            game: game,
            faction: game.activeFaction,
            canEdit: canIssueLocalOrders,
            onIntelScan: onIntelScan,
            onSabotage: onSabotage,
          ),
          const SizedBox(height: 18),
          _TradeRoutesDetail(game: game, faction: game.activeFaction),
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
            syncLedgerEntries: syncLedgerEntries,
            onCopyInvite: onCopyInvite,
            onExportInvite: onExportInvite,
            onApplyOrders: onApplyOrders,
            onImportOrdersFile: onImportOrdersFile,
          ),
          if (game.activeFaction.isComputer && !game.isGameOver) ...[
            const SizedBox(height: 18),
            _ComputerOrdersDetail(game: game),
          ],
          const SizedBox(height: 18),
          _PendingOrdersDetail(
            game: game,
            fromCommandIndex: orderExportBaseCommandCount,
            onCopyOrders: onCopyOrders,
            onExportOrdersFile: onExportOrdersFile,
            canUndoLastOrder: canUndoLastOrder,
            onUndoLastOrder: onUndoLastOrder,
          ),
          const SizedBox(height: 18),
          _ReplayTimelineDetail(game: game),
          const SizedBox(height: 18),
          _CombatReadinessDetail(game: game),
          if (newsGroups.isNotEmpty) ...[
            const SizedBox(height: 18),
            _NewsSummaryDetail(groups: newsGroups),
          ],
          if (tacticalReports.isNotEmpty) ...[
            const SizedBox(height: 18),
            _TacticalLogDetail(reports: tacticalReports),
          ],
          if (game.reports.isNotEmpty) ...[
            const SizedBox(height: 18),
            _StrategicArchiveDetail(reports: game.reports),
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
          const SizedBox(height: 18),
          _TurnChecklistDetail(
            game: game,
            activeColonies: activeColonies,
            orderExportBaseCommandCount: orderExportBaseCommandCount,
          ),
          if (activeColonies.isNotEmpty) ...[
            const SizedBox(height: 18),
            _TurnForecastDetail(
              game: game,
              colonies: activeColonies,
              onSelectColony: onSelectColony,
            ),
          ],
          const SizedBox(height: 18),
          _StrategicAdvisorDetail(
            game: game,
            colonies: activeColonies,
            units: activeUnits,
            onSelectColony: onSelectColony,
            onSelectUnit: onSelectUnit,
          ),
          const SizedBox(height: 18),
          _VictoryPathsDetail(game: game),
          if (activeUnits.isNotEmpty) ...[
            const SizedBox(height: 18),
            _ExpansionPlannerDetail(
              game: game,
              units: activeUnits,
              selectedUnitId:
                  unit?.ownerId == game.activeFactionId ? unit?.id : null,
              onSelectUnit: onSelectUnit,
              onSelectSector: onSelectSector,
            ),
          ],
          const SizedBox(height: 18),
          _OpponentIntelDetail(game: game),
        ],
      ),
    );
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

  TurnReport? _latestBattleReport(OpenDeadlockGame source) {
    for (final report in source.reports) {
      if (report.isBattle) {
        return report;
      }
    }
    return null;
  }
}

class _TerrainCatalogDetail extends StatelessWidget {
  const _TerrainCatalogDetail({
    Key? key,
    required this.activeTerrain,
  }) : super(key: key);

  final String activeTerrain;

  @override
  Widget build(BuildContext context) {
    final activeLabel = OpenDeadlockGame.terrainLabelFor(activeTerrain);

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF31404C)),
          ),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: Material(
            type: MaterialType.transparency,
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 2),
              collapsedIconColor: const Color(0xFFE9EEF2),
              iconColor: const Color(0xFFE9EEF2),
              title: const Row(
                children: [
                  Icon(Icons.map, color: Color(0xFFE9EEF2), size: 17),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Terrain Catalog',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFFF4F7FA),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                '${OpenDeadlockGame.terrainTypes.length} terrain types / '
                '$activeLabel selected',
                style: const TextStyle(
                  color: Color(0xFFB9C5CE),
                  fontSize: 12,
                ),
              ),
              children: [
                ...OpenDeadlockGame.terrainTypes.map(
                  (terrain) => _TerrainCatalogRow(
                    terrain: terrain,
                    isActive: terrain == activeTerrain,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TerrainCatalogRow extends StatelessWidget {
  const _TerrainCatalogRow({
    Key? key,
    required this.terrain,
    required this.isActive,
  }) : super(key: key);

  final String terrain;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final yields = OpenDeadlockGame.terrainYieldFor(terrain);
    final passable = OpenDeadlockGame.isTerrainPassable(terrain);
    final label = OpenDeadlockGame.terrainLabelFor(terrain);
    final color = isActive ? const Color(0xFFCCD6A6) : const Color(0xFFE9EEF2);
    final movement = passable
        ? '${OpenDeadlockGame.movementCostForTerrain(terrain)} move'
        : 'Blocked';

    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              passable ? Icons.directions_walk : Icons.block,
              color: color,
              size: 14,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label - ${isActive ? 'Selected' : 'Available'}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${yields.food} food / ${yields.industry} industry / '
                  '${yields.research} research / $movement',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB9C5CE),
                    fontSize: 12,
                  ),
                ),
                Text(
                  OpenDeadlockGame.terrainDescriptionFor(terrain),
                  overflow: TextOverflow.ellipsis,
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

class _VictoryCutsceneDetail extends StatefulWidget {
  const _VictoryCutsceneDetail({
    Key? key,
    required this.game,
  }) : super(key: key);

  final OpenDeadlockGame game;

  @override
  State<_VictoryCutsceneDetail> createState() => _VictoryCutsceneDetailState();
}

class _VictoryCutsceneDetailState extends State<_VictoryCutsceneDetail> {
  int _sceneIndex = 0;

  @override
  Widget build(BuildContext context) {
    final beats = _victoryCutsceneBeatsFor(widget.game);
    final sceneCount = beats.length;
    final clampedSceneIndex = _sceneIndex.clamp(0, sceneCount - 1);
    if (clampedSceneIndex != _sceneIndex) {
      _sceneIndex = clampedSceneIndex;
    }
    final canGoBack = _sceneIndex > 0;
    final canGoForward = _sceneIndex < sceneCount - 1;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2830),
        border: Border.all(color: const Color(0xFF55616C)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.movie_creation, color: Color(0xFFE9EEF2), size: 19),
              SizedBox(width: 8),
              Text(
                'Victory Cutscene',
                style: TextStyle(
                  color: Color(0xFFF4F7FA),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _CutscenePlaybackPanel(
            sceneNumber: _sceneIndex + 1,
            sceneCount: sceneCount,
            beat: beats[_sceneIndex],
            canGoForward: canGoForward,
            onPrevious: canGoBack
                ? () {
                    setState(() {
                      _sceneIndex -= 1;
                    });
                  }
                : null,
            onNext: canGoForward
                ? () {
                    setState(() {
                      _sceneIndex += 1;
                    });
                  }
                : null,
            onReplay: _sceneIndex > 0
                ? () {
                    setState(() {
                      _sceneIndex = 0;
                    });
                  }
                : null,
          ),
          const SizedBox(height: 8),
          ...beats.asMap().entries.map(
                (entry) => _CutsceneBeatRow(
                  index: entry.key + 1,
                  beat: entry.value,
                ),
              ),
        ],
      ),
    );
  }
}

class _CutscenePlaybackPanel extends StatelessWidget {
  const _CutscenePlaybackPanel({
    Key? key,
    required this.sceneNumber,
    required this.sceneCount,
    required this.beat,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
    required this.onReplay,
  }) : super(key: key);

  final int sceneNumber;
  final int sceneCount;
  final String beat;
  final bool canGoForward;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onReplay;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('victory-cutscene-player'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF26333C),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF43515B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.play_circle, color: Color(0xFFD9B66F), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Scene $sceneNumber/$sceneCount',
                  style: const TextStyle(
                    color: Color(0xFFFFF5D6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Previous Scene',
                icon: const Icon(Icons.chevron_left),
                color: const Color(0xFFE9EEF2),
                onPressed: onPrevious,
              ),
              IconButton(
                tooltip: canGoForward ? 'Next Scene' : 'Final Scene',
                icon: const Icon(Icons.chevron_right),
                color: const Color(0xFFE9EEF2),
                onPressed: onNext,
              ),
              IconButton(
                tooltip: 'Replay Cutscene',
                icon: const Icon(Icons.replay),
                color: const Color(0xFFE9EEF2),
                onPressed: onReplay,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            beat,
            key: ValueKey<String>('cutscene-scene-$sceneNumber'),
            style: const TextStyle(
              color: Color(0xFFE9EEF2),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _CutsceneBeatRow extends StatelessWidget {
  const _CutsceneBeatRow({
    Key? key,
    required this.index,
    required this.beat,
  }) : super(key: key);

  final int index;
  final String beat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 22,
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
            child: Text(
              beat,
              style: const TextStyle(color: Color(0xFFE9EEF2)),
            ),
          ),
        ],
      ),
    );
  }
}

List<String> _victoryCutsceneBeatsFor(OpenDeadlockGame game) {
  final winnerName = game.winningFaction?.name ?? 'The winning faction';
  final victoryType = game.winningVictoryType;
  if (victoryType == OpenDeadlockGame.victoryTypeScience) {
    return <String>[
      '$winnerName uplinks the final discovery from every research lab.',
      'The colony network powers ancient vaults across the planet.',
      'Exploration gives way to a new era of planetary mastery.',
    ];
  }
  if (victoryType == OpenDeadlockGame.victoryTypeConquest) {
    return <String>[
      '$winnerName banners rise over the last contested colony.',
      'Rival command channels fall silent across the sector grid.',
      'The planet unifies under one command.',
    ];
  }
  if (victoryType == OpenDeadlockGame.victoryTypeScore) {
    return <String>[
      '$winnerName closes the final council tally with the strongest score.',
      'Colonies, sectors, science, military, and reserves are audited.',
      'The planetary charter confirms the leading faction.',
    ];
  }
  return <String>[
    '$winnerName reaches the closing sequence.',
    'The final reports are gathered.',
    'A new planetary chapter begins.',
  ];
}

class _TurnChecklistDetail extends StatelessWidget {
  const _TurnChecklistDetail({
    Key? key,
    required this.game,
    required this.activeColonies,
    required this.orderExportBaseCommandCount,
  }) : super(key: key);

  final OpenDeadlockGame game;
  final List<Colony> activeColonies;
  final int orderExportBaseCommandCount;

  @override
  Widget build(BuildContext context) {
    final review = _turnReviewSummaryFor(game, orderExportBaseCommandCount);

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
              const Icon(Icons.checklist, color: Color(0xFFE9EEF2), size: 19),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Turn Checklist',
                  style: TextStyle(
                    color: Color(0xFFF4F7FA),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                _stateLabel(review.pendingOrderCount),
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
            label: 'Action',
            value: _actionLabel(
              review.pendingOrderCount,
              review.movableUnits,
              review.colonyWarningCount,
            ),
          ),
          _DetailRow(
            label: 'Unsent',
            value: review.pendingOrderCount == 0
                ? 'No unsent orders'
                : _countLabel(review.pendingOrderCount, 'order', 'orders',
                    suffix: 'ready to send'),
          ),
          _DetailRow(
            label: 'Units',
            value: review.movableUnits == 0
                ? 'No units can move'
                : _countLabel(review.movableUnits, 'unit', 'units',
                    suffix: 'can still move'),
          ),
          _DetailRow(
            label: 'Colonies',
            value: review.colonyWarningCount == 0
                ? _countLabel(
                    activeColonies.length, 'stable colony', 'stable colonies')
                : _countLabel(
                    review.colonyWarningCount,
                    'colony warning',
                    'colony warnings',
                  ),
          ),
          _DetailRow(
            label: 'Builds',
            value: review.completingBuildCount == 0
                ? 'No builds complete next turn'
                : _countLabel(review.completingBuildCount, 'build', 'builds',
                    suffix: 'complete next turn'),
          ),
          _DetailRow(
            label: 'Research',
            value: _researchProgressLabel(game.activeFaction),
          ),
          _DetailRow(
            label: 'Review',
            value: _reviewLabel(
              movableUnits: review.movableUnits,
              colonyWarningCount: review.colonyWarningCount,
              stalledBuildCount: review.stalledBuildCount,
              fundableResearch: review.fundableResearch,
            ),
          ),
        ],
      ),
    );
  }

  String _stateLabel(int pendingOrderCount) {
    if (game.isGameOver) {
      return 'Complete';
    }
    if (game.activeFaction.isRemote) {
      return 'Waiting';
    }
    if (game.activeFaction.isComputer) {
      return 'AI';
    }
    if (pendingOrderCount > 0) {
      return 'Handoff';
    }
    return 'Planning';
  }

  String _actionLabel(
    int pendingOrderCount,
    int movableUnits,
    int colonyWarningCount,
  ) {
    if (game.isGameOver) {
      return 'Review victory and start a new game';
    }
    if (game.activeFaction.isRemote) {
      return 'Import orders from ${game.activeFaction.name}';
    }
    if (game.activeFaction.isComputer) {
      return 'Run AI for ${game.activeFaction.name}';
    }
    if (!game.activeFactionCanIssueLocalOrders) {
      return 'No local actions available';
    }
    if (pendingOrderCount > 0) {
      return 'Send ${_countLabel(pendingOrderCount, 'order', 'orders')} or keep planning';
    }
    if (movableUnits > 0) {
      return 'Move or recover ${_countLabel(movableUnits, 'unit', 'units')}';
    }
    if (colonyWarningCount > 0) {
      return 'Review ${_countLabel(colonyWarningCount, 'colony warning', 'colony warnings')}';
    }
    return 'End turn when ready';
  }

  String _reviewLabel({
    required int movableUnits,
    required int colonyWarningCount,
    required int stalledBuildCount,
    required int fundableResearch,
  }) {
    if (game.isGameOver) {
      return 'Victory complete';
    }
    if (game.activeFaction.isRemote) {
      return 'Await synced order package';
    }
    if (game.activeFaction.isComputer) {
      return 'Automated turn ready';
    }

    final items = <String>[];
    if (movableUnits > 0) {
      items.add(_countLabel(movableUnits, 'unit idle', 'units idle'));
    }
    if (colonyWarningCount > 0) {
      items.add(_countLabel(
        colonyWarningCount,
        'colony warning',
        'colony warnings',
      ));
    }
    if (stalledBuildCount > 0) {
      items.add(_countLabel(
        stalledBuildCount,
        'stalled build',
        'stalled builds',
      ));
    }
    if (fundableResearch > 0) {
      items.add('Fund $fundableResearch research');
    }

    return items.isEmpty ? 'No blockers found' : items.join(' | ');
  }

  String _researchProgressLabel(Faction faction) {
    if (!OpenDeadlockGame.researchOptions.contains(faction.researchProject)) {
      return 'No active project';
    }
    final cost = OpenDeadlockGame.researchCostFor(faction.researchProject);
    final stored = _clampInt(faction.resources.research, 0, cost);
    final remaining = cost - stored;
    if (remaining <= 0) {
      return '${faction.researchProject} ready';
    }
    return '${faction.researchProject} $stored/$cost, $remaining left';
  }
}

class _TurnForecastDetail extends StatelessWidget {
  const _TurnForecastDetail({
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
    final projections = <_TurnForecastItem>[
      for (final colony in colonies)
        _TurnForecastItem(
          colony: colony,
          projection: game.colonyProductionFor(colony),
        ),
    ];
    final output = _totalOutputFor(projections);
    final trade = game.tradeIncomeFor(game.activeFactionId);
    final netOutput = output + trade;
    final nextStores = game.activeFaction.resources + netOutput;
    final completing = projections
        .where((item) => item.projection.willCompleteConstruction)
        .toList(growable: false);
    final growth = projections
        .where((item) => item.projection.populationChange != 0)
        .toList(growable: false);
    final morale = projections
        .where((item) => item.projection.moraleChange != 0)
        .toList(growable: false);
    final warnings = projections
        .where((item) => _hasForecastWarning(item.projection))
        .toList(growable: false);
    final highlights = _highlightsFor(
      completing: completing,
      growth: growth,
      morale: morale,
      warnings: warnings,
    );

    return Container(
      key: const ValueKey<String>('turn-forecast'),
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
              const Icon(Icons.timeline, color: Color(0xFFE9EEF2), size: 19),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Turn Forecast',
                  style: TextStyle(
                    color: Color(0xFFF4F7FA),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                warnings.isEmpty ? 'Stable' : '${warnings.length} risks',
                style: const TextStyle(
                  color: Color(0xFF9FB0BE),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DetailRow(label: 'Net Output', value: _resourceLine(netOutput)),
          _DetailRow(label: 'After Turn', value: _resourceLine(nextStores)),
          _DetailRow(
            label: 'Builds',
            value: completing.isEmpty
                ? 'No builds complete'
                : _countLabel(
                    completing.length,
                    'build completes',
                    'builds complete',
                  ),
          ),
          _DetailRow(
            label: 'Population',
            value: _populationForecastLabel(growth),
          ),
          _DetailRow(
            label: 'Morale',
            value: morale.isEmpty
                ? 'No morale changes'
                : _countLabel(
                    morale.length,
                    'colony changes',
                    'colonies change',
                  ),
          ),
          if (highlights.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...highlights.map(
              (item) => _TurnForecastRow(
                item: item,
                onSelect: () => onSelectColony(item.colony),
              ),
            ),
          ],
        ],
      ),
    );
  }

  ResourceStockpile _totalOutputFor(List<_TurnForecastItem> items) {
    var output = const ResourceStockpile(
      food: 0,
      industry: 0,
      research: 0,
      credits: 0,
    );
    for (final item in items) {
      output = output + item.projection.output;
    }
    return output;
  }

  List<_TurnForecastItem> _highlightsFor({
    required List<_TurnForecastItem> completing,
    required List<_TurnForecastItem> growth,
    required List<_TurnForecastItem> morale,
    required List<_TurnForecastItem> warnings,
  }) {
    final highlights = <_TurnForecastItem>[];
    void addItems(List<_TurnForecastItem> items) {
      for (final item in items) {
        if (!highlights.any((current) => current.colony.id == item.colony.id)) {
          highlights.add(item);
        }
      }
    }

    addItems(warnings);
    addItems(completing);
    addItems(growth);
    addItems(morale);
    if (highlights.length > 4) {
      return highlights.take(4).toList(growable: false);
    }
    return highlights;
  }

  bool _hasForecastWarning(ColonyProduction projection) {
    return projection.isStarving ||
        projection.isRioting ||
        projection.hasMaintenanceShortfall ||
        projection.isInUnrest;
  }

  String _resourceLine(ResourceStockpile stockpile) {
    return '${stockpile.food} food / ${stockpile.industry} ind / '
        '${stockpile.research} res / ${stockpile.credits} cred';
  }

  String _populationForecastLabel(List<_TurnForecastItem> growth) {
    if (growth.isEmpty) {
      return 'No population changes';
    }
    var delta = 0;
    for (final item in growth) {
      delta += item.projection.populationChange;
    }
    return '${_signedInt(delta)} across ${_countLabel(growth.length, 'colony', 'colonies')}';
  }
}

class _TurnForecastItem {
  const _TurnForecastItem({
    required this.colony,
    required this.projection,
  });

  final Colony colony;
  final ColonyProduction projection;
}

class _TurnForecastRow extends StatelessWidget {
  const _TurnForecastRow({
    Key? key,
    required this.item,
    required this.onSelect,
  }) : super(key: key);

  final _TurnForecastItem item;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          icon: Icon(_iconFor(item.projection)),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.colony.name,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _summaryFor(item),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          onPressed: onSelect,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFE9EEF2),
            alignment: Alignment.centerLeft,
          ),
        ),
      ),
    );
  }

  IconData _iconFor(ColonyProduction projection) {
    if (projection.isRioting ||
        projection.isStarving ||
        projection.hasMaintenanceShortfall ||
        projection.isInUnrest) {
      return Icons.warning_amber;
    }
    if (projection.willCompleteConstruction) {
      return Icons.construction;
    }
    if (projection.populationChange != 0) {
      return Icons.groups;
    }
    return Icons.timeline;
  }

  String _summaryFor(_TurnForecastItem item) {
    final projection = item.projection;
    final parts = <String>[];
    if (projection.isStarving) {
      parts.add('food ${_signedInt(projection.foodBalance)}');
    }
    if (projection.isRioting) {
      parts.add('riot -${projection.riotIndustryLoss} industry');
    }
    if (projection.hasMaintenanceShortfall) {
      parts.add('upkeep -${projection.maintenanceShortfall} credits');
    }
    if (projection.willCompleteConstruction) {
      parts.add('${item.colony.construction} completes');
    }
    if (projection.populationChange != 0) {
      parts.add('pop ${_signedInt(projection.populationChange)}');
    }
    if (projection.moraleChange != 0) {
      parts.add('morale ${_signedInt(projection.moraleChange)}');
    }
    if (parts.isEmpty) {
      parts.add('stable');
    }
    return parts.join(' | ');
  }
}

class _StrategicAdvisorDetail extends StatelessWidget {
  const _StrategicAdvisorDetail({
    Key? key,
    required this.game,
    required this.colonies,
    required this.units,
    required this.onSelectColony,
    required this.onSelectUnit,
  }) : super(key: key);

  final OpenDeadlockGame game;
  final List<Colony> colonies;
  final List<Unit> units;
  final void Function(Colony colony) onSelectColony;
  final void Function(Unit unit) onSelectUnit;

  @override
  Widget build(BuildContext context) {
    final items = _advisorItems().take(5).toList(growable: false);
    final colonyRiskCount = _colonyRiskCount();
    final readyUnits =
        units.where((unit) => unit.movesRemaining > 0).toList(growable: false);
    final woundedUnits = units
        .where((unit) => unit.health < OpenDeadlockGame.maxHealthFor(unit.type))
        .toList(growable: false);
    final warCount = game.factions
        .where((faction) =>
            faction.id != game.activeFactionId &&
            game.areAtWar(game.activeFactionId, faction.id))
        .length;

    return Container(
      key: const ValueKey<String>('strategic-advisor'),
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
              const Icon(Icons.assistant_direction,
                  color: Color(0xFFE9EEF2), size: 19),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Strategic Advisor',
                  style: TextStyle(
                    color: Color(0xFFF4F7FA),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                items.isEmpty ? 'Ready' : '${items.length} actions',
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
            label: 'Top Action',
            value: items.isEmpty ? 'No urgent actions' : items.first.title,
          ),
          _DetailRow(
            label: 'Colonies',
            value: colonyRiskCount == 0
                ? _countLabel(
                    colonies.length, 'stable colony', 'stable colonies')
                : _countLabel(
                    colonyRiskCount,
                    'colony risk',
                    'colony risks',
                  ),
          ),
          _DetailRow(
            label: 'Units',
            value:
                '${readyUnits.length} ready / ${woundedUnits.length} wounded',
          ),
          _DetailRow(
            label: 'Diplomacy',
            value: warCount == 0
                ? 'No active wars'
                : _countLabel(warCount, 'active war', 'active wars'),
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...items.map(
              (item) => _StrategicAdvisorRow(
                item: item,
                onPressed: _onPressedFor(item),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<_StrategicAdvisorItem> _advisorItems() {
    final items = <_StrategicAdvisorItem>[];
    for (final colony in colonies) {
      final projection = game.colonyProductionFor(colony);
      if (projection.isStarving) {
        items.add(
          _StrategicAdvisorItem(
            priority: 100,
            icon: Icons.restaurant,
            title: 'Fix food at ${colony.name}',
            detail: 'Food ${_signedInt(projection.foodBalance)} next turn',
            colony: colony,
          ),
        );
      } else if (projection.isRioting) {
        items.add(
          _StrategicAdvisorItem(
            priority: 95,
            icon: Icons.warning_amber,
            title: 'Stabilize ${colony.name}',
            detail: 'Riots destroy ${projection.riotIndustryLoss} industry',
            colony: colony,
          ),
        );
      } else if (projection.hasMaintenanceShortfall) {
        items.add(
          _StrategicAdvisorItem(
            priority: 90,
            icon: Icons.account_balance_wallet,
            title: 'Cover upkeep at ${colony.name}',
            detail: '${projection.maintenanceShortfall} credits short',
            colony: colony,
          ),
        );
      } else if (projection.isInUnrest || projection.moraleChange < 0) {
        items.add(
          _StrategicAdvisorItem(
            priority: 80,
            icon: Icons.mood_bad,
            title: 'Ease morale at ${colony.name}',
            detail: 'Morale ${_signedInt(projection.moraleChange)} next turn',
            colony: colony,
          ),
        );
      } else if (projection.willCompleteConstruction) {
        items.add(
          _StrategicAdvisorItem(
            priority: 55,
            icon: Icons.construction,
            title: '${colony.construction} finishes at ${colony.name}',
            detail: 'Plan the next build order',
            colony: colony,
          ),
        );
      }
    }

    for (final unit in units) {
      final maxHealth = OpenDeadlockGame.maxHealthFor(unit.type);
      if (unit.health < maxHealth && unit.movesRemaining > 0) {
        items.add(
          _StrategicAdvisorItem(
            priority: 70,
            icon: Icons.healing,
            title: 'Recover ${unit.name}',
            detail:
                '${unit.health}/$maxHealth HP, ${unit.movesRemaining} moves',
            unit: unit,
          ),
        );
      } else if (unit.movesRemaining > 0) {
        items.add(
          _StrategicAdvisorItem(
            priority: 45,
            icon: Icons.near_me,
            title: 'Move ${unit.name}',
            detail:
                '${unit.movesRemaining}/${OpenDeadlockGame.maxMovesFor(unit.type)} moves at ${unit.x + 1}, ${unit.y + 1}',
            unit: unit,
          ),
        );
      }
    }

    final researchItem = _researchAdvisorItem();
    if (researchItem != null) {
      items.add(researchItem);
    }
    items.addAll(_diplomacyAdvisorItems());

    items.sort((a, b) {
      final priorityComparison = b.priority.compareTo(a.priority);
      if (priorityComparison != 0) {
        return priorityComparison;
      }
      return a.title.compareTo(b.title);
    });
    return items;
  }

  int _colonyRiskCount() {
    var count = 0;
    for (final colony in colonies) {
      final projection = game.colonyProductionFor(colony);
      if (projection.isStarving ||
          projection.isRioting ||
          projection.hasMaintenanceShortfall ||
          projection.isInUnrest ||
          projection.moraleChange < 0) {
        count += 1;
      }
    }
    return count;
  }

  _StrategicAdvisorItem? _researchAdvisorItem() {
    final faction = game.activeFaction;
    if (!OpenDeadlockGame.researchOptions.contains(faction.researchProject)) {
      return null;
    }
    final cost = OpenDeadlockGame.researchCostFor(faction.researchProject);
    final remaining = cost - faction.resources.research;
    if (remaining <= 0 || faction.resources.credits <= 0) {
      return null;
    }
    return _StrategicAdvisorItem(
      priority: 35,
      icon: Icons.science,
      title: 'Fund ${faction.researchProject}',
      detail:
          '$remaining research left, ${faction.resources.credits} credits available',
    );
  }

  List<_StrategicAdvisorItem> _diplomacyAdvisorItems() {
    final items = <_StrategicAdvisorItem>[];
    for (final faction in game.factions) {
      if (faction.id == game.activeFactionId ||
          !game.areAtWar(game.activeFactionId, faction.id)) {
        continue;
      }
      items.add(
        _StrategicAdvisorItem(
          priority: 25,
          icon: Icons.handshake,
          title: 'Review war with ${faction.name}',
          detail: 'Peace or alliance can reopen treaty trade',
        ),
      );
    }
    return items;
  }

  VoidCallback? _onPressedFor(_StrategicAdvisorItem item) {
    final colony = item.colony;
    if (colony != null) {
      return () => onSelectColony(colony);
    }
    final unit = item.unit;
    if (unit != null) {
      return () => onSelectUnit(unit);
    }
    return null;
  }
}

class _StrategicAdvisorItem {
  const _StrategicAdvisorItem({
    required this.priority,
    required this.icon,
    required this.title,
    required this.detail,
    this.colony,
    this.unit,
  });

  final int priority;
  final IconData icon;
  final String title;
  final String detail;
  final Colony? colony;
  final Unit? unit;
}

class _StrategicAdvisorRow extends StatelessWidget {
  const _StrategicAdvisorRow({
    Key? key,
    required this.item,
    required this.onPressed,
  }) : super(key: key);

  final _StrategicAdvisorItem item;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          icon: Icon(item.icon),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.detail,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFE9EEF2),
            disabledForegroundColor: const Color(0xFF9FB0BE),
            alignment: Alignment.centerLeft,
          ),
        ),
      ),
    );
  }
}

class _EndTurnReviewDialog extends StatelessWidget {
  const _EndTurnReviewDialog({
    Key? key,
    required this.review,
  }) : super(key: key);

  final _TurnReviewSummary review;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF202B34),
      title: const Text(
        'Review before ending turn',
        style: TextStyle(color: Color(0xFFF4F7FA)),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'These items may still need attention:',
              style: TextStyle(color: Color(0xFFE9EEF2)),
            ),
            const SizedBox(height: 12),
            ...review.warningLabels.map(
              (label) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber,
                      color: Color(0xFFF2C38B),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(color: Color(0xFFE9EEF2)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Review More'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.skip_next),
          label: const Text('End Turn Anyway'),
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
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
          _DetailRow(label: 'Race Effects', value: _raceEffectSummaryFor(race)),
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
          _DetailRow(
            label: 'Build Priorities',
            value: _personalityBuildPrioritySummaryFor(faction.aiPersonality),
          ),
          _DetailRow(
            label: 'Research Priorities',
            value:
                _personalityResearchPrioritySummaryFor(faction.aiPersonality),
          ),
          _DetailRow(
            label: 'Diplomacy Bias',
            value: _personalityDiplomacyBiasFor(faction.aiPersonality),
          ),
          _DetailRow(
            label: 'Economy Bias',
            value: _personalityEconomyBiasFor(faction.aiPersonality),
          ),
          _DetailRow(
            label: 'Tactical Bias',
            value: _personalityTacticalBiasFor(faction.aiPersonality),
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
          const SizedBox(height: 8),
          _RaceCatalogDetail(activeRaceId: faction.raceId),
        ],
      ),
    );
  }
}

class _RaceCatalogDetail extends StatelessWidget {
  const _RaceCatalogDetail({
    Key? key,
    required this.activeRaceId,
  }) : super(key: key);

  final String activeRaceId;

  @override
  Widget build(BuildContext context) {
    final races = OpenDeadlockGame.raceProfiles();
    final activeRace = OpenDeadlockGame.raceProfileForId(activeRaceId);

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFF31404C)),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 2),
            collapsedIconColor: const Color(0xFFE9EEF2),
            iconColor: const Color(0xFFE9EEF2),
            title: const Row(
              children: [
                Icon(Icons.diversity_3, color: Color(0xFFE9EEF2), size: 17),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Race Catalog',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFFF4F7FA),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              '${races.length} races / ${activeRace.name} active',
              style: const TextStyle(
                color: Color(0xFFB9C5CE),
                fontSize: 12,
              ),
            ),
            children: [
              ...races.map(
                (race) => _RaceCatalogRow(
                  race: race,
                  isActive: race.id == activeRaceId,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaceCatalogRow extends StatelessWidget {
  const _RaceCatalogRow({
    Key? key,
    required this.race,
    required this.isActive,
  }) : super(key: key);

  final RaceProfile race;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFFCCD6A6) : const Color(0xFFE9EEF2);
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              isActive ? Icons.play_circle : Icons.radio_button_unchecked,
              color: color,
              size: 14,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${race.name} - ${isActive ? 'Active' : 'Available'}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _raceEffectSummaryFor(race),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB9C5CE),
                    fontSize: 12,
                  ),
                ),
                Text(
                  race.description,
                  overflow: TextOverflow.ellipsis,
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

String _personalityBuildPrioritySummaryFor(String aiPersonality) {
  if (aiPersonality == Faction.aiPersonalityConqueror) {
    return 'Barracks, infantry, factories, armor, militia';
  }
  if (aiPersonality == Faction.aiPersonalityExpansionist) {
    return 'Scouts, colony hubs, farm domes';
  }
  if (aiPersonality == Faction.aiPersonalityResearcher) {
    return 'Research labs, factories';
  }
  if (aiPersonality == Faction.aiPersonalityTrader) {
    return 'Farm domes, factories, scouts';
  }
  return 'Adapts to shortages, threats, and local colony needs';
}

String _personalityResearchPrioritySummaryFor(String aiPersonality) {
  if (aiPersonality == Faction.aiPersonalityConqueror) {
    return 'Defense Grid, Industrial Automation';
  }
  if (aiPersonality == Faction.aiPersonalityExpansionist) {
    return 'Hydroponics, Industrial Automation';
  }
  if (aiPersonality == Faction.aiPersonalityResearcher) {
    return 'Xenoarchaeology, Industrial Automation';
  }
  if (aiPersonality == Faction.aiPersonalityTrader) {
    return 'Hydroponics, Industrial Automation, Future Studies';
  }
  return 'Adapts to race, traits, and unfinished projects';
}

String _personalityDiplomacyBiasFor(String aiPersonality) {
  if (aiPersonality == Faction.aiPersonalityConqueror) {
    return 'Breaks peace with smaller military advantage';
  }
  if (aiPersonality == Faction.aiPersonalityTrader) {
    return 'Seeks peace and trade alliances when credits are tight';
  }
  if (aiPersonality == Faction.aiPersonalityExpansionist) {
    return 'Fights when expansion lanes are blocked';
  }
  if (aiPersonality == Faction.aiPersonalityResearcher) {
    return 'Avoids distractions while funding science';
  }
  return 'Responds to pressure, threats, and opportunity';
}

String _personalityEconomyBiasFor(String aiPersonality) {
  if (aiPersonality == Faction.aiPersonalityConqueror) {
    return 'Works industry sectors and military infrastructure';
  }
  if (aiPersonality == Faction.aiPersonalityExpansionist) {
    return 'Works food sectors and accepts lower colony-site scores';
  }
  if (aiPersonality == Faction.aiPersonalityResearcher) {
    return 'Funds research earlier and favors science focus';
  }
  if (aiPersonality == Faction.aiPersonalityTrader) {
    return 'Uses revenue focus and tax relief to protect morale';
  }
  return 'Balances shortages, morale, and production needs';
}

String _personalityTacticalBiasFor(String aiPersonality) {
  if (aiPersonality == Faction.aiPersonalityConqueror) {
    return 'Prioritizes combat units and offensive targets';
  }
  if (aiPersonality == Faction.aiPersonalityExpansionist) {
    return 'Prioritizes scouts, colony hubs, and claimable sectors';
  }
  if (aiPersonality == Faction.aiPersonalityResearcher) {
    return 'Defends research tempo and sabotage exposure';
  }
  if (aiPersonality == Faction.aiPersonalityTrader) {
    return 'Protects trade economy before escalating fights';
  }
  return 'Chooses targets from local threat and reward scores';
}

String _raceEffectSummaryFor(RaceProfile race) {
  final effects = <String>[];
  _appendSignedRaceEffect(effects, race.foodBonus, 'food per colony');
  _appendSignedRaceEffect(effects, race.industryBonus, 'industry per colony');
  _appendSignedRaceEffect(effects, race.researchBonus, 'research per colony');
  _appendSignedRaceEffect(effects, race.creditBonus, 'credits per colony');
  _appendSignedRaceEffect(
    effects,
    race.constructionBonus,
    'construction progress per colony',
  );
  _appendSignedRaceEffect(
    effects,
    race.populationGrowthBonus,
    'population growth',
  );
  _appendSignedRaceEffect(effects, race.attackBonus, 'unit attack');
  if (race.moraleFloor > 0) {
    effects.add('morale floor ${race.moraleFloor}');
  }
  if (race.revealsMap) {
    effects.add('reveals full map');
  }
  if (race.preferredConstruction != null) {
    effects.add('prefers ${race.preferredConstruction}');
  }
  if (race.preferredResearch != null) {
    effects.add('prioritizes ${race.preferredResearch}');
  }
  if (effects.isEmpty) {
    return 'No special modifiers';
  }
  return effects.join('; ');
}

void _appendSignedRaceEffect(
  List<String> effects,
  int value,
  String label,
) {
  if (value == 0) {
    return;
  }
  final sign = value > 0 ? '+' : '';
  effects.add('$sign$value $label');
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

class _AudioSettingsDetail extends StatelessWidget {
  const _AudioSettingsDetail({
    Key? key,
    required this.soundEffectsEnabled,
    required this.musicEnabled,
  }) : super(key: key);

  final bool soundEffectsEnabled;
  final bool musicEnabled;

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
              Icon(Icons.volume_up, color: Color(0xFFE9EEF2), size: 19),
              SizedBox(width: 8),
              Text(
                'Audio',
                style: TextStyle(
                  color: Color(0xFFF4F7FA),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DetailRow(
            label: 'Effects',
            value: soundEffectsEnabled ? 'Enabled' : 'Muted',
          ),
          _DetailRow(
            label: 'Music',
            value: musicEnabled ? 'Enabled' : 'Paused',
          ),
          _DetailRow(
            label: 'Cues',
            value: 'Orders, saves, sync, music, turn actions',
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
        projection.isRioting ||
        projection.hasMaintenanceShortfall;
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
        projection.isRioting ||
        projection.hasMaintenanceShortfall;
  }

  String _statusLabel() {
    if (projection.isRioting) {
      return 'Status: riot damage active';
    }
    if (projection.isStarving) {
      return 'Status: food shortage ${_signedInt(projection.foodBalance)}';
    }
    if (projection.hasMaintenanceShortfall) {
      return 'Status: upkeep shortfall -${projection.maintenanceShortfall} credits';
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

class _FactionEconomyDetail extends StatelessWidget {
  const _FactionEconomyDetail({
    Key? key,
    required this.game,
    required this.faction,
  }) : super(key: key);

  final OpenDeadlockGame game;
  final Faction faction;

  @override
  Widget build(BuildContext context) {
    final summary = game.worldSummaryFor(faction.id);
    final colonies = game.colonies
        .where((colony) => colony.ownerId == faction.id)
        .toList(growable: false);
    final projections =
        colonies.map((colony) => game.colonyProductionFor(colony)).toList();
    final tradeIncome = game.tradeIncomeFor(faction.id);
    final warningCount =
        projections.where((projection) => _hasColonyWarning(projection)).length;
    final maintenanceShortfall = projections.fold<int>(
      0,
      (total, projection) => total + projection.maintenanceShortfall,
    );
    final completingBuildCount = projections
        .where((projection) => projection.willCompleteConstruction)
        .length;
    final stalledBuildCount = projections
        .where((projection) =>
            projection.constructionWork <= 0 &&
            !projection.willCompleteConstruction)
        .length;
    final moralePressureCount = projections
        .where((projection) =>
            projection.moraleChange < 0 ||
            projection.isInUnrest ||
            projection.isRioting)
        .length;

    return Container(
      key: const ValueKey<String>('faction-economy'),
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
                'Faction Economy',
                style: TextStyle(
                  color: Color(0xFFF4F7FA),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DetailRow(
            label: 'Treasury',
            value: '${faction.resources.credits} credits',
          ),
          _DetailRow(
            label: 'Next Output',
            value: _resourceLine(summary.projectedProduction),
          ),
          _DetailRow(
            label: 'Trade',
            value: tradeIncome.credits == 0
                ? 'No treaty income'
                : '+${tradeIncome.credits} credits / turn',
          ),
          _DetailRow(
            label: 'Colonies',
            value:
                '${colonies.length} active | ${warningCount == 0 ? 'no warnings' : '$warningCount warnings'}',
          ),
          _DetailRow(
            label: 'Upkeep',
            value: maintenanceShortfall == 0
                ? 'Covered'
                : '$maintenanceShortfall credit shortfall',
          ),
          _DetailRow(
            label: 'Builds',
            value:
                '$completingBuildCount completing | $stalledBuildCount stalled',
          ),
          _DetailRow(
            label: 'Morale',
            value: moralePressureCount == 0
                ? 'Stable'
                : '$moralePressureCount under pressure',
          ),
          _DetailRow(label: 'Research', value: _researchLabel()),
        ],
      ),
    );
  }

  String _resourceLine(ResourceStockpile stockpile) {
    return '${stockpile.food} food / ${stockpile.industry} ind / '
        '${stockpile.research} res / ${stockpile.credits} cred';
  }

  String _researchLabel() {
    if (!OpenDeadlockGame.researchOptions.contains(faction.researchProject)) {
      return 'No active project';
    }
    final cost = OpenDeadlockGame.researchCostFor(faction.researchProject);
    final remaining = cost - faction.resources.research;
    if (remaining <= 0) {
      return '${faction.researchProject} ready';
    }
    final fundable = _fundableResearchFor(faction);
    if (fundable > 0) {
      return 'Fund $fundable of $remaining remaining';
    }
    return '${faction.resources.research}/$cost ${faction.researchProject}';
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
    if (victoryType == OpenDeadlockGame.victoryTypeScore) {
      return 'Score';
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
    if (victoryType == OpenDeadlockGame.victoryTypeScore) {
      return 'Held the highest score when the turn limit expired';
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

class _VictoryPathsDetail extends StatelessWidget {
  const _VictoryPathsDetail({
    Key? key,
    required this.game,
  }) : super(key: key);

  final OpenDeadlockGame game;

  @override
  Widget build(BuildContext context) {
    final summariesByFactionId = <String, FactionWorldSummary>{
      for (final summary in game.worldSummaries()) summary.factionId: summary,
    };
    final scores = game.factionScores();

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
              Icon(Icons.emoji_events, color: Color(0xFFE9EEF2), size: 19),
              SizedBox(width: 8),
              Text(
                'Victory Paths',
                style: TextStyle(
                  color: Color(0xFFF4F7FA),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DetailRow(
            label: 'Condition',
            value: OpenDeadlockGame.victoryConditionLabelFor(
              game.victoryCondition,
            ),
          ),
          _DetailRow(
            label: 'Conquest Path',
            value: _isConquestEnabled ? 'Enabled' : 'Disabled',
          ),
          _DetailRow(
            label: 'Science Path',
            value: _isScienceEnabled ? 'Enabled' : 'Disabled',
          ),
          _DetailRow(
            label: 'Score Limit',
            value: game.scoreTurnLimit <= 0
                ? 'Off'
                : 'Turn ${game.scoreTurnLimit}',
          ),
          const SizedBox(height: 8),
          for (final score in scores)
            _VictoryPathRow(
              score: score,
              summary: summariesByFactionId[score.factionId]!,
              showConquest: _isConquestEnabled,
              showScience: _isScienceEnabled,
              showScoreDeadline: game.scoreTurnLimit > 0,
            ),
        ],
      ),
    );
  }

  bool get _isConquestEnabled {
    return game.victoryCondition == OpenDeadlockGame.victoryConditionAny ||
        game.victoryCondition == OpenDeadlockGame.victoryConditionConquest;
  }

  bool get _isScienceEnabled {
    return game.victoryCondition == OpenDeadlockGame.victoryConditionAny ||
        game.victoryCondition == OpenDeadlockGame.victoryConditionScience;
  }
}

class _VictoryPathRow extends StatelessWidget {
  const _VictoryPathRow({
    Key? key,
    required this.score,
    required this.summary,
    required this.showConquest,
    required this.showScience,
    required this.showScoreDeadline,
  }) : super(key: key);

  final FactionScore score;
  final FactionWorldSummary summary;
  final bool showConquest;
  final bool showScience;
  final bool showScoreDeadline;

  @override
  Widget build(BuildContext context) {
    final segments = <String>[];
    if (summary.isDefeated) {
      segments.add('Defeated');
    }
    if (showConquest) {
      segments.add(
        'Conquest ${summary.victoryProgressLabel} / ${summary.victorySharePercent}%',
      );
    }
    if (showScience) {
      segments.add(
        'Science ${summary.scienceVictoryProgressLabel} / ${summary.scienceVictorySharePercent}%',
      );
    }
    segments.add('Score ${score.total} pts');
    if (showScoreDeadline) {
      segments.add('Deadline active');
    }

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
                  score.factionName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE9EEF2),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  segments.join(' | '),
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
    final factionsById = <String, Faction>{
      for (final faction in game.factions) faction.id: faction,
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
              faction: factionsById[scores[index].factionId]!,
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
    required this.faction,
  }) : super(key: key);

  final FactionScore score;
  final int rank;
  final FactionWorldSummary summary;
  final Faction faction;

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
                Text(
                  'Score: Colonies ${score.colonyScore} | Sectors ${score.sectorScore} | Population ${score.populationScore} | Military ${score.militaryScore} | Science ${score.scienceScore} | Reserves ${score.reserveScore}',
                  style: const TextStyle(
                    color: Color(0xFFB9C5CE),
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Profile ${Faction.aiPersonalityLabelFor(faction.aiPersonality)} | Traits ${OpenDeadlockGame.traitSummaryFor(faction)}',
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

class _OpponentIntelDetail extends StatelessWidget {
  const _OpponentIntelDetail({
    Key? key,
    required this.game,
  }) : super(key: key);

  final OpenDeadlockGame game;

  @override
  Widget build(BuildContext context) {
    final rivals = game.factions
        .where((faction) => faction.id != game.activeFactionId)
        .toList(growable: false);
    final activeStrength = game.militaryStrengthFor(game.activeFactionId);
    final activeScore = game.factionScoreFor(game.activeFactionId).total;
    final wars = rivals
        .where((faction) => game.areAtWar(game.activeFactionId, faction.id))
        .length;
    final visibleEnemyUnits = game.visibleEnemyUnitCountFor(
      game.activeFactionId,
    );
    final knownEnemyColonies = _knownEnemyColonyCount();

    return Container(
      key: const ValueKey<String>('opponent-intel'),
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
              const Icon(Icons.radar, color: Color(0xFFE9EEF2), size: 19),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Opponent Intel',
                  style: TextStyle(
                    color: Color(0xFFF4F7FA),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                rivals.isEmpty ? 'Clear' : '${rivals.length} rivals',
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
            label: 'Posture',
            value: wars == 0
                ? 'No active wars'
                : _countLabel(wars, 'active war', 'active wars'),
          ),
          _DetailRow(
            label: 'Contact',
            value:
                '$visibleEnemyUnits visible units / $knownEnemyColonies known colonies',
          ),
          _DetailRow(label: 'Our Power', value: '$activeStrength strength'),
          _DetailRow(label: 'Our Score', value: '$activeScore pts'),
          if (rivals.isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'No rival factions in this scenario.',
              style: TextStyle(color: Color(0xFFE9EEF2)),
            ),
          ] else ...[
            const SizedBox(height: 8),
            ...rivals.map(
              (faction) => _OpponentIntelRow(
                game: game,
                faction: faction,
                activeStrength: activeStrength,
                activeScore: activeScore,
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _knownEnemyColonyCount() {
    var count = 0;
    for (final colony in game.colonies) {
      if (!game.areAtWar(game.activeFactionId, colony.ownerId)) {
        continue;
      }
      if (game.tileAt(colony.x, colony.y).isExploredBy(game.activeFactionId)) {
        count += 1;
      }
    }
    return count;
  }
}

class _OpponentIntelRow extends StatelessWidget {
  const _OpponentIntelRow({
    Key? key,
    required this.game,
    required this.faction,
    required this.activeStrength,
    required this.activeScore,
  }) : super(key: key);

  final OpenDeadlockGame game;
  final Faction faction;
  final int activeStrength;
  final int activeScore;

  @override
  Widget build(BuildContext context) {
    final status =
        game.diplomacyStatusBetween(game.activeFactionId, faction.id);
    final summary = game.worldSummaryFor(faction.id);
    final score = game.factionScoreFor(faction.id);
    final strength = game.militaryStrengthFor(faction.id);
    final visibleUnits = _visibleUnitCount();
    final knownColonies = _knownColonyCount();
    final tradeCredits =
        game.treatyTradeCreditsFor(game.activeFactionId, faction.id);
    final profile = Faction.aiPersonalityLabelFor(faction.aiPersonality);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFF34424D), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: Color(faction.colorValue),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  faction.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE9EEF2),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${OpenDeadlockGame.diplomacyStatusLabelFor(status)} | ${_threatLabel(strength)} | ${score.total} pts',
                  style: const TextStyle(
                    color: Color(0xFFD7DEE5),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$visibleUnits visible units / $knownColonies known colonies / ${summary.unitCount} total units',
                  style: const TextStyle(
                    color: Color(0xFFB9C5CE),
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Strength $strength vs $activeStrength | Score ${_signedInt(score.total - activeScore)}',
                  style: const TextStyle(
                    color: Color(0xFFB9C5CE),
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Profile $profile | ${_stanceHint(status, strength, tradeCredits)}',
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

  int _visibleUnitCount() {
    var count = 0;
    for (final unit in game.units) {
      if (unit.ownerId == faction.id &&
          game.isUnitVisibleTo(game.activeFactionId, unit)) {
        count += 1;
      }
    }
    return count;
  }

  int _knownColonyCount() {
    var count = 0;
    for (final colony in game.colonies) {
      if (colony.ownerId == faction.id &&
          game.tileAt(colony.x, colony.y).isExploredBy(game.activeFactionId)) {
        count += 1;
      }
    }
    return count;
  }

  String _threatLabel(int strength) {
    if (strength > activeStrength) {
      return 'stronger threat';
    }
    if (strength < activeStrength) {
      return 'weaker threat';
    }
    return 'matched threat';
  }

  String _stanceHint(String status, int strength, int tradeCredits) {
    if (status == OpenDeadlockGame.diplomacyStatusAlliance) {
      return tradeCredits > 0
          ? 'preserve +$tradeCredits trade'
          : 'preserve shared intel';
    }
    if (status == OpenDeadlockGame.diplomacyStatusPeace) {
      return tradeCredits > 0
          ? 'trade +$tradeCredits credits'
          : 'peace blocks attacks';
    }
    if (strength > activeStrength) {
      return 'avoid exposed fights';
    }
    if (strength < activeStrength) {
      return 'press military advantage';
    }
    return 'scout before committing';
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

class _IntelOperationsDetail extends StatelessWidget {
  const _IntelOperationsDetail({
    Key? key,
    required this.game,
    required this.faction,
    required this.canEdit,
    required this.onIntelScan,
    required this.onSabotage,
  }) : super(key: key);

  final OpenDeadlockGame game;
  final Faction faction;
  final bool canEdit;
  final void Function(String targetFactionId) onIntelScan;
  final void Function(String targetFactionId) onSabotage;

  @override
  Widget build(BuildContext context) {
    final scanTarget = _bestIntelScanTargetFor(game, faction);
    final sabotageTarget = _bestSabotageOperationFor(game, faction);
    final hasScanBudget =
        faction.resources.credits >= OpenDeadlockGame.intelScanCreditCost;
    final hasSabotageBudget =
        faction.resources.credits >= OpenDeadlockGame.sabotageCreditCost;
    final scanTargetId =
        canEdit && hasScanBudget ? scanTarget?.faction.id : null;
    final sabotageTargetId =
        canEdit && hasSabotageBudget ? sabotageTarget?.faction.id : null;

    return Container(
      key: const ValueKey<String>('intel-operations'),
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
              Icon(Icons.radar, color: Color(0xFFE9EEF2), size: 19),
              SizedBox(width: 8),
              Text(
                'Intel Operations',
                style: TextStyle(
                  color: Color(0xFFF4F7FA),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DetailRow(
            label: 'Credits',
            value:
                '${faction.resources.credits} available | scan ${OpenDeadlockGame.intelScanCreditCost} / sabotage ${OpenDeadlockGame.sabotageCreditCost}',
          ),
          _DetailRow(
            label: 'Best Scan',
            value: scanTarget == null
                ? 'Intel up to date'
                : '${scanTarget.faction.name}: ${scanTarget.revealableSectors} hidden sectors',
          ),
          _DetailRow(
            label: 'Best Sabotage',
            value: sabotageTarget == null
                ? 'No visible wartime construction'
                : '${sabotageTarget.target.colonyName}: ${sabotageTarget.target.damage} industry damage',
          ),
          _DetailRow(
            label: 'Security',
            value: sabotageTarget == null
                ? 'No target selected'
                : _sabotageProtectionLabel(sabotageTarget.protection),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.radar, size: 18),
                label: const Text('Scan Best Target'),
                onPressed: scanTargetId == null
                    ? null
                    : () => onIntelScan(scanTargetId),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE9EEF2),
                  side: const BorderSide(color: Color(0xFF55616C)),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.construction, size: 18),
                label: const Text('Sabotage Best Target'),
                onPressed: sabotageTargetId == null
                    ? null
                    : () => onSabotage(sabotageTargetId),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE9EEF2),
                  side: const BorderSide(color: Color(0xFF55616C)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IntelScanOperation {
  const _IntelScanOperation({
    required this.faction,
    required this.revealableSectors,
  });

  final Faction faction;
  final int revealableSectors;
}

class _SabotageOperation {
  const _SabotageOperation({
    required this.faction,
    required this.target,
    required this.protection,
  });

  final Faction faction;
  final FactionSabotageTarget target;
  final int protection;
}

class _TradeRoutesDetail extends StatelessWidget {
  const _TradeRoutesDetail({
    Key? key,
    required this.game,
    required this.faction,
  }) : super(key: key);

  final OpenDeadlockGame game;
  final Faction faction;

  @override
  Widget build(BuildContext context) {
    final routes = game.factions.where((otherFaction) {
      if (otherFaction.id == faction.id) {
        return false;
      }
      return game.treatyTradeCreditsFor(faction.id, otherFaction.id) > 0;
    }).toList(growable: false);
    final totalTrade = game.tradeIncomeFor(faction.id).credits;
    final routeLabel = routes.length == 1 ? 'route' : 'routes';

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
              Icon(Icons.local_shipping, color: Color(0xFFE9EEF2), size: 19),
              SizedBox(width: 8),
              Text(
                'Trade Routes',
                style: TextStyle(
                  color: Color(0xFFF4F7FA),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DetailRow(
            label: 'Income',
            value:
                '+$totalTrade credits / turn from ${routes.length} $routeLabel',
          ),
          if (routes.isEmpty)
            const Text(
              'Make peace or alliance treaties to open treaty trade.',
              style: TextStyle(color: Color(0xFFB9C5CE), fontSize: 12),
            )
          else
            ...routes.map(
              (otherFaction) {
                final status =
                    game.diplomacyStatusBetween(faction.id, otherFaction.id);
                final tradeCredits =
                    game.treatyTradeCreditsFor(faction.id, otherFaction.id);
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      Text(
                        '${OpenDeadlockGame.diplomacyStatusLabelFor(status)} +$tradeCredits',
                        style: const TextStyle(
                          color: Color(0xFFCCD6A6),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
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
          const SizedBox(height: 8),
          _ResearchCatalogDetail(faction: faction),
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

class _ResearchCatalogDetail extends StatelessWidget {
  const _ResearchCatalogDetail({
    Key? key,
    required this.faction,
  }) : super(key: key);

  final Faction faction;

  @override
  Widget build(BuildContext context) {
    final items = OpenDeadlockGame.researchOptions
        .map((project) => _ResearchCatalogItem.forProject(faction, project))
        .toList(growable: false);
    final nextCount = items
        .where((item) => item.status == _ResearchCatalogStatus.next)
        .length;
    final currentCount = items
        .where((item) => item.status == _ResearchCatalogStatus.current)
        .length;
    final completeCount = items
        .where((item) => item.status == _ResearchCatalogStatus.complete)
        .length;
    final repeatableCount = items
        .where((item) => item.status == _ResearchCatalogStatus.repeatable)
        .length;

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFF31404C)),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 2),
            collapsedIconColor: const Color(0xFFE9EEF2),
            iconColor: const Color(0xFFE9EEF2),
            title: const Row(
              children: [
                Icon(Icons.science, color: Color(0xFFE9EEF2), size: 17),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Research Catalog',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFFF4F7FA),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              'Options: $nextCount next / $currentCount current / '
              '$completeCount complete / $repeatableCount repeatable',
              style: const TextStyle(
                color: Color(0xFFB9C5CE),
                fontSize: 12,
              ),
            ),
            children: [
              ...items.map((item) => _ResearchCatalogRow(item: item)),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ResearchCatalogStatus { next, current, complete, repeatable }

class _ResearchCatalogItem {
  const _ResearchCatalogItem({
    required this.project,
    required this.status,
    required this.cost,
    required this.fullFundCost,
    required this.description,
  });

  final String project;
  final _ResearchCatalogStatus status;
  final int cost;
  final int fullFundCost;
  final String description;

  static _ResearchCatalogItem forProject(Faction faction, String project) {
    final cost = OpenDeadlockGame.researchCostFor(project);
    return _ResearchCatalogItem(
      project: project,
      status: _statusFor(faction, project),
      cost: cost,
      fullFundCost: OpenDeadlockGame.fundResearchCostFor(cost),
      description: OpenDeadlockGame.researchDescriptionFor(project),
    );
  }

  static _ResearchCatalogStatus _statusFor(Faction faction, String project) {
    if (faction.researchProject == project) {
      return _ResearchCatalogStatus.current;
    }
    if (OpenDeadlockGame.isCompletedResearch(faction, project)) {
      return _ResearchCatalogStatus.complete;
    }
    if (OpenDeadlockGame.isRepeatableResearch(project)) {
      return _ResearchCatalogStatus.repeatable;
    }
    return _ResearchCatalogStatus.next;
  }
}

class _ResearchCatalogRow extends StatelessWidget {
  const _ResearchCatalogRow({
    Key? key,
    required this.item,
  }) : super(key: key);

  final _ResearchCatalogItem item;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(_statusIcon(), color: color, size: 14),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.project} - ${_statusLabel()}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${item.cost} research / ${item.fullFundCost} credits from empty',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB9C5CE),
                    fontSize: 12,
                  ),
                ),
                Text(
                  item.description,
                  overflow: TextOverflow.ellipsis,
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

  Color _statusColor() {
    if (item.status == _ResearchCatalogStatus.current) {
      return const Color(0xFFCCD6A6);
    }
    if (item.status == _ResearchCatalogStatus.complete) {
      return const Color(0xFF82CBA8);
    }
    if (item.status == _ResearchCatalogStatus.repeatable) {
      return const Color(0xFFB7A6D6);
    }
    return const Color(0xFFE9EEF2);
  }

  IconData _statusIcon() {
    if (item.status == _ResearchCatalogStatus.current) {
      return Icons.play_circle;
    }
    if (item.status == _ResearchCatalogStatus.complete) {
      return Icons.check_circle;
    }
    if (item.status == _ResearchCatalogStatus.repeatable) {
      return Icons.all_inclusive;
    }
    return Icons.radio_button_unchecked;
  }

  String _statusLabel() {
    if (item.status == _ResearchCatalogStatus.current) {
      return 'Current';
    }
    if (item.status == _ResearchCatalogStatus.complete) {
      return 'Complete';
    }
    if (item.status == _ResearchCatalogStatus.repeatable) {
      return 'Repeatable';
    }
    return 'Next';
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
    required this.syncLedgerEntries,
    required this.onCopyInvite,
    required this.onExportInvite,
    required this.onApplyOrders,
    required this.onImportOrdersFile,
  }) : super(key: key);

  final OpenDeadlockGame game;
  final SavedGameSlot? latestSaveSlot;
  final int orderExportBaseCommandCount;
  final String? lastSyncStatus;
  final List<_SyncLedgerEntry> syncLedgerEntries;
  final Future<void> Function(String factionId) onCopyInvite;
  final Future<void> Function(String factionId) onExportInvite;
  final Future<void> Function() onApplyOrders;
  final Future<void> Function() onImportOrdersFile;

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
            label: 'Transport',
            value: _syncTransportLabel(
              hasRemoteFactions: hasRemoteFactions,
              hasComputerFactions: hasComputerFactions,
            ),
          ),
          _DetailRow(
            label: 'Integrity',
            value: _syncIntegrityLabel(hasRemoteFactions: hasRemoteFactions),
          ),
          _DetailRow(
            label: 'Local Role',
            value: _syncLocalRoleLabel(game),
          ),
          _DetailRow(
            label: 'Remote Seats',
            value: _remoteSeatLabel(remoteFactions),
          ),
          _DetailRow(
            label: 'Package Flow',
            value: _syncPackageFlowLabel(
              game: game,
              pendingOrderCount: pendingOrderCount,
              hasRemoteFactions: hasRemoteFactions,
            ),
          ),
          const SizedBox(height: 8),
          _SyncHandoffChecklistDetail(
            game: game,
            pendingOrderCount: pendingOrderCount,
            remoteFactions: remoteFactions,
          ),
          _DetailRow(
            label: 'Last Sync',
            value: lastSyncStatus ?? 'No packages applied this session',
          ),
          if (syncLedgerEntries.isNotEmpty) ...[
            const SizedBox(height: 8),
            _SyncLedgerDetail(entries: syncLedgerEntries),
          ],
          _DetailRow(
            label: 'Save',
            value: latestSaveSlot == null
                ? 'No local save'
                : '${latestSaveSlot!.name} (${latestSaveSlot!.stateFingerprint})',
          ),
          _DetailRow(label: 'Commands', value: '${game.commandHistory.length}'),
          _DetailRow(label: 'State', value: fingerprint),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.playlist_add_check, size: 18),
                label: const Text('Apply Orders'),
                onPressed: () {
                  onApplyOrders();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE9EEF2),
                  side: const BorderSide(color: Color(0xFF55616C)),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.drive_folder_upload, size: 18),
                label: const Text('Import Orders File'),
                onPressed: () {
                  onImportOrdersFile();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE9EEF2),
                  side: const BorderSide(color: Color(0xFF55616C)),
                ),
              ),
            ],
          ),
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

class _SyncHandoffChecklistDetail extends StatelessWidget {
  const _SyncHandoffChecklistDetail({
    Key? key,
    required this.game,
    required this.pendingOrderCount,
    required this.remoteFactions,
  }) : super(key: key);

  final OpenDeadlockGame game;
  final int pendingOrderCount;
  final List<Faction> remoteFactions;

  @override
  Widget build(BuildContext context) {
    final items = _syncHandoffChecklistFor(
      game: game,
      pendingOrderCount: pendingOrderCount,
      remoteFactions: remoteFactions,
    );

    return Column(
      key: const ValueKey<String>('sync-handoff-checklist'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.checklist, color: Color(0xFFD9B66F), size: 18),
            SizedBox(width: 8),
            Text(
              'Handoff Checklist',
              style: TextStyle(
                color: Color(0xFFFFF5D6),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.radio_button_checked,
                    size: 12,
                    color: Color(0xFFCCD6A6),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      color: Color(0xFFE9EEF2),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SyncLedgerDetail extends StatelessWidget {
  const _SyncLedgerDetail({
    Key? key,
    required this.entries,
  }) : super(key: key);

  final List<_SyncLedgerEntry> entries;

  @override
  Widget build(BuildContext context) {
    final latest = entries.first;
    final orderLabel =
        latest.orders == 1 ? '1 order' : '${latest.orders} orders';

    return Container(
      key: const ValueKey<String>('sync-ledger'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF26333C),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF43515B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.receipt_long, color: Color(0xFFD9B66F), size: 18),
              SizedBox(width: 8),
              Text(
                'Sync Ledger',
                style: TextStyle(
                  color: Color(0xFFFFF5D6),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _DetailRow(label: 'Source', value: latest.source),
          _DetailRow(label: 'Status', value: latest.status),
          _DetailRow(label: 'Sender', value: latest.sender),
          _DetailRow(label: 'Received', value: orderLabel),
          _DetailRow(label: 'Handoff', value: latest.handoff),
          _DetailRow(
            label: 'Base Cmd',
            value: _shortFingerprint(latest.baseCommandFingerprint),
          ),
          _DetailRow(
            label: 'Result State',
            value: _shortFingerprint(latest.resultStateFingerprint),
          ),
          if (entries.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${entries.length - 1} earlier sync ${entries.length == 2 ? 'entry' : 'entries'} this session',
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

class _PendingOrdersDetail extends StatelessWidget {
  const _PendingOrdersDetail({
    Key? key,
    required this.game,
    required this.fromCommandIndex,
    required this.onCopyOrders,
    required this.onExportOrdersFile,
    required this.canUndoLastOrder,
    required this.onUndoLastOrder,
  }) : super(key: key);

  final OpenDeadlockGame game;
  final int fromCommandIndex;
  final Future<void> Function() onCopyOrders;
  final Future<void> Function() onExportOrdersFile;
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
      key: const ValueKey<String>('pending-orders'),
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: const Text('Copy Orders'),
                  onPressed: () {
                    onCopyOrders();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE9EEF2),
                    side: const BorderSide(color: Color(0xFF55616C)),
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.save_alt, size: 18),
                  label: const Text('Export Orders File'),
                  onPressed: () {
                    onExportOrdersFile();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE9EEF2),
                    side: const BorderSide(color: Color(0xFF55616C)),
                  ),
                ),
              ],
            ),
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
          _DetailRow(
            label: 'Plan',
            value: _aiPlanBreakdownFor(game, plannedCommands),
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
                category: _aiPlanCategoryFor(game, entry.value),
                summary: _commandSummaryFor(game, entry.value),
                reason: _aiPlanReasonFor(game, entry.value),
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

class _ReplayTimelineDetail extends StatelessWidget {
  const _ReplayTimelineDetail({
    Key? key,
    required this.game,
  }) : super(key: key);

  final OpenDeadlockGame game;

  @override
  Widget build(BuildContext context) {
    final records = game.commandHistory;
    final recentStart = records.length > 6 ? records.length - 6 : 0;
    final recentRecords = records.skip(recentStart).toList();
    final lastRecord = records.isEmpty ? null : records.last;
    final commandFingerprint = GameCodec.fingerprintCommands(
      records.map((record) => record.command),
    );
    final stateFingerprint = GameCodec.fingerprintGame(game);
    final replayWindow = records.isEmpty
        ? 'No commands'
        : 'Commands ${recentStart + 1}-${records.length}';

    return Container(
      key: const ValueKey<String>('replay-timeline'),
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
              const Icon(Icons.history, color: Color(0xFFE9EEF2), size: 19),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Replay Timeline',
                  style: TextStyle(
                    color: Color(0xFFF4F7FA),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                records.length == 1
                    ? '1 command'
                    : '${records.length} commands',
                style: const TextStyle(
                  color: Color(0xFF9FB0BE),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DetailRow(label: 'Turn', value: '${game.turn}'),
          _DetailRow(label: 'Active', value: game.activeFaction.name),
          _DetailRow(
            label: 'Last Actor',
            value: lastRecord == null
                ? 'No commands recorded'
                : _factionNameFor(game, lastRecord.factionId),
          ),
          _DetailRow(label: 'Replay Window', value: replayWindow),
          _DetailRow(
            label: 'Command Hash',
            value: _shortFingerprint(commandFingerprint),
          ),
          _DetailRow(
            label: 'State Hash',
            value: _shortFingerprint(stateFingerprint),
          ),
          const _DetailRow(
            label: 'Audit',
            value: 'Snapshot + command log',
          ),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'No replay commands have been recorded yet.',
                style: TextStyle(color: Color(0xFFE9EEF2)),
              ),
            )
          else ...[
            const SizedBox(height: 6),
            ...recentRecords.asMap().entries.map((entry) {
              final index = recentStart + entry.key + 1;
              final record = entry.value;
              return _ReplayTimelineLine(
                index: index,
                record: record,
                factionName: _factionNameFor(game, record.factionId),
                summary: _commandSummaryFor(game, record.command),
              );
            }),
          ],
          if (records.length > recentRecords.length)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '+${records.length - recentRecords.length} earlier replay commands',
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

class _ReplayTimelineLine extends StatelessWidget {
  const _ReplayTimelineLine({
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
                color: Color(0xFFCCD6A6),
                fontWeight: FontWeight.bold,
                fontSize: 12,
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
                  style: const TextStyle(
                    color: Color(0xFFE9EEF2),
                    fontWeight: FontWeight.w600,
                  ),
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
    required this.category,
    required this.summary,
    required this.reason,
  }) : super(key: key);

  final int index;
  final String factionName;
  final String category;
  final String summary;
  final String reason;

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
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    reason,
                    style: const TextStyle(
                      color: Color(0xFFB8C6D1),
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _PlanCategoryChip(label: category),
                    Text(
                      'AI Plan | $factionName',
                      style: const TextStyle(
                        color: Color(0xFF9FB0BE),
                        fontSize: 12,
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
  }
}

class _PlanCategoryChip extends StatelessWidget {
  const _PlanCategoryChip({
    Key? key,
    required this.label,
  }) : super(key: key);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF313B44),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF55616C)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFCCD6A6),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
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

const List<String> _aiPlanCategoryOrder = <String>[
  'Combat',
  'Tactical',
  'Diplomacy',
  'Research',
  'Economy',
  'Expansion',
  'Movement',
  'Recovery',
  'Setup',
  'Turn',
  'Other',
];

String _aiPlanBreakdownFor(
  OpenDeadlockGame game,
  List<GameCommand> commands,
) {
  if (commands.isEmpty) {
    return 'No planned orders';
  }

  final counts = <String, int>{};
  for (final command in commands) {
    final category = _aiPlanCategoryFor(game, command);
    counts[category] = (counts[category] ?? 0) + 1;
  }

  return _aiPlanCategoryOrder
      .where((category) => counts.containsKey(category))
      .map((category) => '$category ${counts[category]}')
      .join(' / ');
}

String _aiPlanCategoryFor(OpenDeadlockGame game, GameCommand command) {
  if (command is MoveUnitCommand) {
    final ownerId = _unitOwnerIdFor(game, command.unitId) ?? command.factionId;
    final defender = game.unitAt(command.x, command.y);
    if (defender != null &&
        defender.ownerId != ownerId &&
        game.areAtWar(ownerId, defender.ownerId)) {
      return 'Combat';
    }
    final targetColony = game.colonyAt(command.x, command.y);
    if (targetColony != null &&
        targetColony.ownerId != ownerId &&
        game.areAtWar(ownerId, targetColony.ownerId)) {
      return 'Combat';
    }
    return 'Movement';
  }
  if (command is ScanFactionIntelCommand || command is SabotageColonyCommand) {
    return 'Tactical';
  }
  if (command is SetDiplomacyStatusCommand) {
    return 'Diplomacy';
  }
  if (command is SetResearchProjectCommand || command is FundResearchCommand) {
    return 'Research';
  }
  if (command is SetColonyConstructionCommand ||
      command is RushConstructionCommand ||
      command is SetColonyFocusCommand ||
      command is SetColonySectorAssignmentCommand ||
      command is SetFactionTaxPolicyCommand) {
    return 'Economy';
  }
  if (command is FoundColonyCommand) {
    return 'Expansion';
  }
  if (command is RecoverUnitCommand) {
    return 'Recovery';
  }
  if (command is SetFactionControlCommand ||
      command is SetFactionDifficultyCommand) {
    return 'Setup';
  }
  if (command is EndTurnCommand || command is RunComputerTurnCommand) {
    return 'Turn';
  }
  return 'Other';
}

String? _unitOwnerIdFor(OpenDeadlockGame game, String unitId) {
  for (final unit in game.units) {
    if (unit.id == unitId) {
      return unit.ownerId;
    }
  }
  return null;
}

String _aiPlanReasonFor(OpenDeadlockGame game, GameCommand command) {
  final faction = game.factionById(command.factionId);
  final profile = faction == null
      ? 'AI'
      : Faction.aiPersonalityLabelFor(faction.aiPersonality);

  if (command is SetDiplomacyStatusCommand) {
    return _diplomacyPlanReasonFor(game, command, profile);
  }
  if (command is SetResearchProjectCommand) {
    return 'Research effect: ${OpenDeadlockGame.researchDescriptionFor(command.researchProject)}';
  }
  if (command is FundResearchCommand) {
    final faction = game.factionById(command.factionId);
    final project = faction?.researchProject ?? 'current project';
    return 'Uses credits to close the $project research gap.';
  }
  if (command is SetFactionTaxPolicyCommand) {
    return 'Policy effect: ${Faction.taxPolicyDescriptionFor(command.taxPolicy)}';
  }
  if (command is SetColonyConstructionCommand) {
    return 'Build target: ${OpenDeadlockGame.constructionProducesDescriptionFor(command.construction)}.';
  }
  if (command is RushConstructionCommand) {
    final cost = OpenDeadlockGame.rushConstructionCostFor(command.industry);
    return 'Spends $cost credits to add ${command.industry} industry now.';
  }
  if (command is SetColonyFocusCommand) {
    return 'Focus effect: ${OpenDeadlockGame.colonyFocusDescriptionFor(command.focus)}';
  }
  if (command is SetColonySectorAssignmentCommand) {
    final tile = game.tileAt(command.x, command.y);
    return command.assigned
        ? 'Works ${_tileYieldLabel(tile.yields)} before the next turn.'
        : 'Frees this worked sector for reassignment.';
  }
  if (command is ScanFactionIntelCommand) {
    final revealable = game.intelScanRevealableSectorCountFor(
      command.factionId,
      command.targetFactionId,
    );
    return 'Reveals $revealable hidden sector(s) before tactical planning.';
  }
  if (command is SabotageColonyCommand) {
    final target =
        game.sabotageTargetFor(command.factionId, command.targetFactionId);
    if (target == null) {
      return 'Looks for visible enemy construction to disrupt.';
    }
    return 'Targets ${target.colonyName} for ${target.damage} stored industry damage.';
  }
  if (command is MoveUnitCommand) {
    if (_aiPlanCategoryFor(game, command) == 'Combat') {
      return 'Attacks an adjacent wartime target.';
    }
    return 'Moves toward expansion, defense, or known wartime contact.';
  }
  if (command is RecoverUnitCommand) {
    return 'Restores health instead of taking a low-value action.';
  }
  if (command is FoundColonyCommand) {
    return 'Claims a viable frontier site for expansion.';
  }
  return '';
}

String _diplomacyPlanReasonFor(
  OpenDeadlockGame game,
  SetDiplomacyStatusCommand command,
  String profile,
) {
  final currentStatus = game.diplomacyStatusBetween(
    command.factionId,
    command.targetFactionId,
  );
  final currentTrade =
      game.treatyTradeCreditsFor(command.factionId, command.targetFactionId);
  final projectedTrade = _projectedTradeCreditsForStatus(
    game,
    command.factionId,
    command.status,
  );
  final tradeDelta = projectedTrade - currentTrade;

  if (command.status == OpenDeadlockGame.diplomacyStatusAlliance) {
    if (tradeDelta > 0) {
      return '$profile profile expects +$tradeDelta credits/turn and shared map intel.';
    }
    return '$profile profile wants shared map intel.';
  }
  if (command.status == OpenDeadlockGame.diplomacyStatusPeace &&
      currentStatus == OpenDeadlockGame.diplomacyStatusWar) {
    if (tradeDelta > 0) {
      return '$profile profile lowers war pressure and adds +$tradeDelta credits/turn.';
    }
    return '$profile profile lowers war pressure.';
  }
  if (command.status == OpenDeadlockGame.diplomacyStatusWar) {
    final strengthDelta = game.militaryStrengthFor(command.factionId) -
        game.militaryStrengthFor(command.targetFactionId);
    if (strengthDelta > 0) {
      return '$profile profile sees +$strengthDelta military strength before attacking.';
    }
    return '$profile profile is willing to reopen hostilities.';
  }
  return '$profile profile changes relations from '
      '${OpenDeadlockGame.diplomacyStatusLabelFor(currentStatus)} to '
      '${OpenDeadlockGame.diplomacyStatusLabelFor(command.status)}.';
}

int _projectedTradeCreditsForStatus(
  OpenDeadlockGame game,
  String factionId,
  String status,
) {
  final colonyCount = game.worldSummaryFor(factionId).colonyCount;
  return colonyCount * game.tradeCreditsPerColonyForStatus(status);
}

String _tileYieldLabel(TileYield yields) {
  return '${yields.food} food / ${yields.industry} industry / ${yields.research} research';
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

String _commandPackageRecipientLabelFor(
  OpenDeadlockGame game,
  CommandPackage package,
) {
  final recipients = game.factions
      .where((faction) =>
          faction.isRemote && faction.id != package.exportedByFactionId)
      .map((faction) => faction.name)
      .toList(growable: false);
  if (recipients.isEmpty) {
    return 'Manual handoff';
  }
  if (recipients.length <= 2) {
    return recipients.join(', ');
  }
  return '${recipients.take(2).join(', ')} +${recipients.length - 2}';
}

String _shortFingerprint(String fingerprint) {
  if (fingerprint.isEmpty) {
    return 'Unavailable';
  }
  return _shortSessionId(fingerprint);
}

String _shortSessionId(String sessionId) {
  if (sessionId.length <= 16) {
    return sessionId;
  }
  return '${sessionId.substring(0, 8)}...${sessionId.substring(sessionId.length - 5)}';
}

class _TurnReviewSummary {
  const _TurnReviewSummary({
    required this.pendingOrderCount,
    required this.movableUnits,
    required this.colonyWarningCount,
    required this.completingBuildCount,
    required this.stalledBuildCount,
    required this.fundableResearch,
  });

  final int pendingOrderCount;
  final int movableUnits;
  final int colonyWarningCount;
  final int completingBuildCount;
  final int stalledBuildCount;
  final int fundableResearch;

  bool get needsConfirmation {
    return pendingOrderCount > 0 ||
        movableUnits > 0 ||
        colonyWarningCount > 0 ||
        stalledBuildCount > 0 ||
        fundableResearch > 0;
  }

  List<String> get warningLabels {
    final labels = <String>[];
    if (pendingOrderCount > 0) {
      labels.add(_countLabel(
        pendingOrderCount,
        'unsent order',
        'unsent orders',
        suffix: 'ready to send',
      ));
    }
    if (movableUnits > 0) {
      labels.add(_countLabel(
        movableUnits,
        'unit can still move',
        'units can still move',
      ));
    }
    if (colonyWarningCount > 0) {
      labels.add(_countLabel(
        colonyWarningCount,
        'colony warning',
        'colony warnings',
      ));
    }
    if (stalledBuildCount > 0) {
      labels.add(_countLabel(
        stalledBuildCount,
        'stalled build',
        'stalled builds',
      ));
    }
    if (fundableResearch > 0) {
      labels.add('Fund $fundableResearch research');
    }
    return labels;
  }
}

_TurnReviewSummary _turnReviewSummaryFor(
  OpenDeadlockGame game,
  int orderExportBaseCommandCount,
) {
  final activeColonies = game.colonies
      .where((colony) => colony.ownerId == game.activeFactionId)
      .toList(growable: false);
  final pendingOrderCount =
      _pendingOrderCountFor(game, orderExportBaseCommandCount);
  final movableUnits = game.units
      .where((unit) =>
          unit.ownerId == game.activeFactionId && unit.movesRemaining > 0)
      .length;
  final colonyWarningCount = activeColonies
      .where((colony) => _hasColonyWarning(game.colonyProductionFor(colony)))
      .length;
  final completingBuildCount = activeColonies
      .where(
          (colony) => game.colonyProductionFor(colony).willCompleteConstruction)
      .length;
  final stalledBuildCount = activeColonies.where((colony) {
    final projection = game.colonyProductionFor(colony);
    return projection.constructionWork <= 0 &&
        !projection.willCompleteConstruction;
  }).length;

  return _TurnReviewSummary(
    pendingOrderCount: pendingOrderCount,
    movableUnits: movableUnits,
    colonyWarningCount: colonyWarningCount,
    completingBuildCount: completingBuildCount,
    stalledBuildCount: stalledBuildCount,
    fundableResearch: _fundableResearchFor(game.activeFaction),
  );
}

bool _hasColonyWarning(ColonyProduction projection) {
  return projection.isStarving ||
      projection.isInUnrest ||
      projection.isRioting ||
      projection.hasMaintenanceShortfall;
}

int _fundableResearchFor(Faction faction) {
  if (!OpenDeadlockGame.researchOptions.contains(faction.researchProject)) {
    return 0;
  }
  final cost = OpenDeadlockGame.researchCostFor(faction.researchProject);
  final remaining = cost - faction.resources.research;
  if (remaining <= 0) {
    return 0;
  }
  final affordable =
      faction.resources.credits ~/ OpenDeadlockGame.researchCreditCostPerPoint;
  return affordable < remaining ? affordable : remaining;
}

int _clampInt(int value, int minimum, int maximum) {
  if (value < minimum) {
    return minimum;
  }
  if (value > maximum) {
    return maximum;
  }
  return value;
}

String _countLabel(
  int count,
  String singular,
  String plural, {
  String? suffix,
}) {
  final label = '$count ${count == 1 ? singular : plural}';
  return suffix == null ? label : '$label $suffix';
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

String _syncTransportLabel({
  required bool hasRemoteFactions,
  required bool hasComputerFactions,
}) {
  if (hasRemoteFactions) {
    return 'Invite and order packages';
  }
  if (hasComputerFactions) {
    return 'Local AI turns';
  }
  return 'Same-device hotseat';
}

String _syncIntegrityLabel({required bool hasRemoteFactions}) {
  return hasRemoteFactions ? 'State fingerprints verified' : 'Local state only';
}

String _syncLocalRoleLabel(OpenDeadlockGame game) {
  if (game.activeFaction.isRemote) {
    return 'Host waiting for remote player';
  }
  if (game.activeFactionCanIssueLocalOrders) {
    return 'Local player can issue orders';
  }
  if (game.activeFaction.isComputer) {
    return 'Computer faction can run locally';
  }
  return 'Observer';
}

String _remoteSeatLabel(List<Faction> remoteFactions) {
  if (remoteFactions.isEmpty) {
    return 'None';
  }
  return remoteFactions.map((faction) => faction.name).join(', ');
}

String _syncPackageFlowLabel({
  required OpenDeadlockGame game,
  required int pendingOrderCount,
  required bool hasRemoteFactions,
}) {
  if (!hasRemoteFactions) {
    return 'No package exchange needed';
  }
  if (game.activeFaction.isRemote) {
    return 'Apply incoming orders to continue';
  }
  if (pendingOrderCount > 0) {
    return 'Share outgoing orders with remote seats';
  }
  return 'Share invites or import remote orders';
}

_IntelScanOperation? _bestIntelScanTargetFor(
  OpenDeadlockGame game,
  Faction faction,
) {
  _IntelScanOperation? best;
  for (final otherFaction in game.factions) {
    if (otherFaction.id == faction.id) {
      continue;
    }
    final revealableSectors = game.intelScanRevealableSectorCountFor(
      faction.id,
      otherFaction.id,
    );
    if (revealableSectors <= 0) {
      continue;
    }
    final operation = _IntelScanOperation(
      faction: otherFaction,
      revealableSectors: revealableSectors,
    );
    if (best == null ||
        operation.revealableSectors > best.revealableSectors ||
        (operation.revealableSectors == best.revealableSectors &&
            operation.faction.name.compareTo(best.faction.name) < 0)) {
      best = operation;
    }
  }
  return best;
}

_SabotageOperation? _bestSabotageOperationFor(
  OpenDeadlockGame game,
  Faction faction,
) {
  _SabotageOperation? best;
  for (final otherFaction in game.factions) {
    if (otherFaction.id == faction.id ||
        !game.areAtWar(faction.id, otherFaction.id)) {
      continue;
    }
    final target = game.sabotageTargetFor(faction.id, otherFaction.id);
    if (target == null) {
      continue;
    }
    final protection =
        game.sabotageProtectionForColony(game.colonyById(target.colonyId));
    final operation = _SabotageOperation(
      faction: otherFaction,
      target: target,
      protection: protection,
    );
    if (best == null ||
        operation.target.damage > best.target.damage ||
        (operation.target.damage == best.target.damage &&
            operation.target.colonyName.compareTo(best.target.colonyName) <
                0)) {
      best = operation;
    }
  }
  return best;
}

String _sabotageProtectionLabel(int protection) {
  if (protection <= 0) {
    return 'No protection';
  }
  return '$protection sabotage protection';
}

List<String> _syncHandoffChecklistFor({
  required OpenDeadlockGame game,
  required int pendingOrderCount,
  required List<Faction> remoteFactions,
}) {
  if (remoteFactions.isEmpty) {
    if (game.activeFaction.isComputer) {
      return <String>[
        'Run ${game.activeFaction.name} AI locally.',
        'Review the turn report before the next local player acts.',
      ];
    }
    return <String>[
      'Use the same device for each local faction turn.',
      'Save locally before passing the device.',
    ];
  }

  final remoteSeatNames = _remoteSeatLabel(remoteFactions);
  final items = <String>[
    'Share invites with $remoteSeatNames.',
  ];
  if (game.activeFaction.isRemote) {
    items.add('Import orders from ${game.activeFaction.name}.');
  } else if (game.activeFaction.isComputer) {
    items.add('Run ${game.activeFaction.name} AI before sending updates.');
  } else if (pendingOrderCount > 0) {
    final orderLabel = pendingOrderCount == 1
        ? '1 local order'
        : '$pendingOrderCount local orders';
    items.add('Copy or export $orderLabel for remote seats.');
  } else if (game.activeFactionCanIssueLocalOrders) {
    items.add('Issue local orders or end the turn.');
  } else {
    items.add('Wait for the next synced handoff.');
  }
  items.add('Verify the state hash after each imported package.');
  return items;
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

class _LatestBattleDetail extends StatelessWidget {
  const _LatestBattleDetail({
    Key? key,
    required this.report,
  }) : super(key: key);

  final TurnReport report;

  @override
  Widget build(BuildContext context) {
    final details = report.details;
    final kind = details['kind'];

    return Container(
      key: const ValueKey<String>('latest-battle-summary'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF27231F),
        border: Border.all(color: const Color(0xFF7A6345)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                kind == 'colony' ? Icons.location_city : Icons.gps_fixed,
                color: const Color(0xFFF0DEC2),
                size: 19,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Latest Battle',
                  style: TextStyle(
                    color: Color(0xFFF4F7FA),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_hasBattleSector(details))
                Text(
                  _battleSectorLabel(details),
                  style: const TextStyle(
                    color: Color(0xFFB9C5CE),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            report.title,
            style: const TextStyle(
              color: Color(0xFFFFF5D6),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          if (kind == 'unit') ...[
            _DetailRow(label: 'Damage', value: _battleUnitDamageLabel(details)),
            _DetailRow(label: 'Health', value: _battleUnitHealthLabel(details)),
            _DetailRow(
              label: 'Outcome',
              value: _battleUnitOutcomeLabel(details),
            ),
          ] else if (kind == 'colony') ...[
            _DetailRow(
              label: 'Assault',
              value: _battleColonyAssaultLabel(details),
            ),
            if (_battleHasColonyDamageDetails(details))
              _DetailRow(
                label: 'Damage',
                value: _battleColonyDamageLabel(details),
              ),
            _DetailRow(
              label: 'Colony',
              value: _battleColonyStatusLabel(details),
            ),
            _DetailRow(
              label: 'Outcome',
              value: _battleColonyOutcomeLabel(details),
            ),
          ] else
            _DetailRow(label: 'Report', value: report.message),
          const SizedBox(height: 4),
          Text(
            report.message,
            style: const TextStyle(color: Color(0xFFB9C5CE), fontSize: 12),
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

class _StrategicArchiveDetail extends StatelessWidget {
  const _StrategicArchiveDetail({
    Key? key,
    required this.reports,
  }) : super(key: key);

  final List<TurnReport> reports;

  @override
  Widget build(BuildContext context) {
    final recentReports = reports.take(20).toList(growable: false);
    final categoryCounts = <String, int>{};
    for (final report in recentReports) {
      final label = _newsCategoryLabelFor(report);
      categoryCounts[label] = (categoryCounts[label] ?? 0) + 1;
    }
    final highlights = <_ArchiveHighlight>[
      _ArchiveHighlight.forCategory(
        label: 'Combat',
        report: _latestReportWhere(
          recentReports,
          (report) => report.isBattle,
        ),
      ),
      _ArchiveHighlight.forCategory(
        label: 'Economy',
        report: _latestReportWhere(
          recentReports,
          (report) => _newsCategoryLabelFor(report) == 'Economy',
        ),
      ),
      _ArchiveHighlight.forCategory(
        label: 'Research',
        report: _latestReportWhere(
          recentReports,
          (report) => _newsCategoryLabelFor(report) == 'Research',
        ),
      ),
      _ArchiveHighlight.forCategory(
        label: 'Diplomacy',
        report: _latestReportWhere(
          recentReports,
          (report) => _newsCategoryLabelFor(report) == 'Diplomacy',
        ),
      ),
    ].where((highlight) => highlight.report != null).toList(growable: false);

    return Container(
      key: const ValueKey<String>('strategic-archive'),
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
              const Icon(Icons.history_edu, color: Color(0xFFE9EEF2), size: 19),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Strategic Archive',
                  style: TextStyle(
                    color: Color(0xFFF4F7FA),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${recentReports.length} recent',
                style: const TextStyle(
                  color: Color(0xFF9FB0BE),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DetailRow(label: 'Latest', value: recentReports.first.title),
          _DetailRow(
            label: 'Categories',
            value: _categorySummary(categoryCounts),
          ),
          if (highlights.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...highlights.map(
              (highlight) => _ArchiveHighlightRow(highlight: highlight),
            ),
          ],
          const SizedBox(height: 6),
          ...recentReports.take(4).map(
                (report) => _ArchiveReportLine(report: report),
              ),
        ],
      ),
    );
  }

  String _categorySummary(Map<String, int> categoryCounts) {
    if (categoryCounts.isEmpty) {
      return 'No reports';
    }
    return categoryCounts.entries
        .take(4)
        .map((entry) => '${entry.key} ${entry.value}')
        .join(' / ');
  }

  TurnReport? _latestReportWhere(
    List<TurnReport> source,
    bool Function(TurnReport report) test,
  ) {
    for (final report in source) {
      if (test(report)) {
        return report;
      }
    }
    return null;
  }
}

class _ArchiveHighlight {
  const _ArchiveHighlight({
    required this.label,
    required this.report,
  });

  final String label;
  final TurnReport? report;

  static _ArchiveHighlight forCategory({
    required String label,
    required TurnReport? report,
  }) {
    return _ArchiveHighlight(label: label, report: report);
  }
}

class _ArchiveHighlightRow extends StatelessWidget {
  const _ArchiveHighlightRow({
    Key? key,
    required this.highlight,
  }) : super(key: key);

  final _ArchiveHighlight highlight;

  @override
  Widget build(BuildContext context) {
    final report = highlight.report!;
    final category = _newsCategoryLabelFor(report);
    final style = _newsCategoryStyleFor(category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(style.icon, color: style.color, size: 15),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '${highlight.label}: ${report.title}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFE9EEF2),
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

class _ArchiveReportLine extends StatelessWidget {
  const _ArchiveReportLine({
    Key? key,
    required this.report,
  }) : super(key: key);

  final TurnReport report;

  @override
  Widget build(BuildContext context) {
    final category = _newsCategoryLabelFor(report);
    final style = _newsCategoryStyleFor(category);

    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: style.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '$category: ${report.title}',
              overflow: TextOverflow.ellipsis,
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
            _DetailRow(label: 'Damage', value: _battleUnitDamageLabel(details)),
            _DetailRow(label: 'Health', value: _battleUnitHealthLabel(details)),
            _DetailRow(
              label: 'Outcome',
              value: _battleUnitOutcomeLabel(details),
            ),
          ] else if (kind == 'colony') ...[
            _DetailRow(
              label: 'Assault',
              value: _battleColonyAssaultLabel(details),
            ),
            if (_battleHasColonyDamageDetails(details))
              _DetailRow(
                label: 'Damage',
                value: _battleColonyDamageLabel(details),
              ),
            _DetailRow(
              label: 'Colony',
              value: _battleColonyStatusLabel(details),
            ),
            _DetailRow(
              label: 'Outcome',
              value: _battleColonyOutcomeLabel(details),
            ),
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
}

bool _hasBattleSector(Map<String, String> details) {
  return int.tryParse(details['x'] ?? '') != null &&
      int.tryParse(details['y'] ?? '') != null;
}

String _battleSectorLabel(Map<String, String> details) {
  return 'Sector ${_readDetailInt(details, 'x') + 1}, '
      '${_readDetailInt(details, 'y') + 1}';
}

String _battleUnitDamageLabel(Map<String, String> details) {
  final attackerName = _battleDetailOrFallback(
    details,
    'attackerName',
    'Attacker',
  );
  final defenderName = _battleDetailOrFallback(
    details,
    'defenderName',
    'Defender',
  );
  return '$attackerName ${_battleDetailOrFallback(details, 'attackDamage', '0')} / '
      '$defenderName ${_battleDetailOrFallback(details, 'counterDamage', '0')}';
}

String _battleUnitHealthLabel(Map<String, String> details) {
  final attackerName = _battleDetailOrFallback(
    details,
    'attackerName',
    'Attacker',
  );
  final defenderName = _battleDetailOrFallback(
    details,
    'defenderName',
    'Defender',
  );
  return '$attackerName ${_battleDetailOrFallback(details, 'attackerHealth', '0')} / '
      '$defenderName ${_battleDetailOrFallback(details, 'defenderHealth', '0')}';
}

String _battleUnitOutcomeLabel(Map<String, String> details) {
  final attackerName = _battleDetailOrFallback(
    details,
    'attackerName',
    'Attacker',
  );
  final defenderName = _battleDetailOrFallback(
    details,
    'defenderName',
    'Defender',
  );
  final attackerStatus =
      details['attackerSurvived'] == 'true' ? 'survived' : 'destroyed';
  final defenderStatus =
      details['defenderSurvived'] == 'true' ? 'survived' : 'destroyed';
  return '$attackerName $attackerStatus / $defenderName $defenderStatus';
}

String _battleColonyAssaultLabel(Map<String, String> details) {
  return '${_battleDetailOrFallback(details, 'attackPower', '0')} attack vs '
      '${_battleDetailOrFallback(details, 'defensePower', '0')} defense';
}

bool _battleHasColonyDamageDetails(Map<String, String> details) {
  return _battleHasDetailInt(details, 'populationDelta') ||
      _battleHasDetailInt(details, 'moraleDelta') ||
      (_battleHasDetailInt(details, 'previousPopulation') &&
          _battleHasDetailInt(details, 'population')) ||
      (_battleHasDetailInt(details, 'previousMorale') &&
          _battleHasDetailInt(details, 'morale'));
}

String _battleColonyDamageLabel(Map<String, String> details) {
  final populationDelta = _battleColonyDeltaFor(
    details,
    deltaKey: 'populationDelta',
    previousKey: 'previousPopulation',
    currentKey: 'population',
  );
  final moraleDelta = _battleColonyDeltaFor(
    details,
    deltaKey: 'moraleDelta',
    previousKey: 'previousMorale',
    currentKey: 'morale',
  );
  return '${_signedInt(populationDelta)} pop / '
      '${_signedInt(moraleDelta)} morale';
}

int _battleColonyDeltaFor(
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

String _battleColonyStatusLabel(Map<String, String> details) {
  return '${_battleDetailOrFallback(details, 'population', '0')} pop / '
      '${_battleDetailOrFallback(details, 'morale', '0')} morale';
}

String _battleColonyOutcomeLabel(Map<String, String> details) {
  final attackerName = _battleDetailOrFallback(
    details,
    'attackerName',
    'Attacker',
  );
  final colonyName = _battleDetailOrFallback(
    details,
    'colonyName',
    'Colony',
  );
  final captured = details['colonyCaptured'] == 'true';
  final attackerStatus =
      details['attackerSurvived'] == 'true' ? 'survived' : 'destroyed';
  return captured
      ? '$attackerName captured $colonyName'
      : '$colonyName held / $attackerName $attackerStatus';
}

String _battleDetailOrFallback(
  Map<String, String> details,
  String key,
  String fallback,
) {
  final value = details[key];
  return value == null || value.isEmpty ? fallback : value;
}

bool _battleHasDetailInt(Map<String, String> details, String key) {
  return int.tryParse(details[key] ?? '') != null;
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

class _UnitOrderOption {
  const _UnitOrderOption({
    required this.tile,
    required this.hint,
    required this.label,
    required this.description,
  });

  final PlanetTile tile;
  final _TileActionHint hint;
  final String label;
  final String description;
}

class _UnitOrdersDetail extends StatelessWidget {
  const _UnitOrdersDetail({
    Key? key,
    required this.game,
    required this.unit,
    required this.onSelectSector,
  }) : super(key: key);

  final OpenDeadlockGame game;
  final Unit unit;
  final void Function(int x, int y) onSelectSector;

  @override
  Widget build(BuildContext context) {
    final orders = _availableOrders();

    return Container(
      key: const ValueKey<String>('unit-orders'),
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
              Icon(Icons.flag, color: Color(0xFFE9EEF2), size: 19),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Unit Orders',
                  style: TextStyle(
                    color: Color(0xFFF4F7FA),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (orders.isEmpty)
            Text(
              unit.movesRemaining <= 0
                  ? 'No movement remaining.'
                  : 'No adjacent legal orders.',
              style: const TextStyle(color: Color(0xFFE9EEF2)),
            )
          else
            ...orders.map(
              (order) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: ValueKey<String>(
                      'unit-order-${_unitOrderKeyNameFor(order.hint)}-${order.tile.x}-${order.tile.y}',
                    ),
                    icon: Icon(_iconForOrder(order.hint)),
                    label: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            order.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            order.description,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    onPressed: () => onSelectSector(order.tile.x, order.tile.y),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<_UnitOrderOption> _availableOrders() {
    if (!game.activeFactionCanIssueLocalOrders ||
        unit.ownerId != game.activeFactionId ||
        unit.movesRemaining <= 0) {
      return const <_UnitOrderOption>[];
    }

    final orders = <_UnitOrderOption>[];
    const offsets = <List<int>>[
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
      final isKnown = tile.isExploredBy(game.activeFactionId) ||
          game.isSectorVisibleTo(game.activeFactionId, x, y);
      if (!isKnown || !OpenDeadlockGame.isTerrainPassable(tile.terrain)) {
        continue;
      }
      final moveCost = OpenDeadlockGame.movementCostForTerrain(tile.terrain);
      if (unit.movesRemaining < moveCost) {
        continue;
      }

      final occupyingUnit = game.visibleUnitAt(game.activeFactionId, x, y);
      if (occupyingUnit != null && occupyingUnit.id != unit.id) {
        if (occupyingUnit.ownerId == unit.ownerId ||
            !game.areAtWar(unit.ownerId, occupyingUnit.ownerId)) {
          continue;
        }
        final preview = game.previewUnitCombat(unit, occupyingUnit);
        orders.add(
          _UnitOrderOption(
            tile: tile,
            hint: _TileActionHint.attack,
            label: 'Attack ${occupyingUnit.name}',
            description:
                _unitCombatPreviewValueFor(unit, occupyingUnit, preview),
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
        orders.add(
          _UnitOrderOption(
            tile: tile,
            hint: _TileActionHint.assault,
            label: 'Assault ${targetColony.name}',
            description: _colonyAssaultPreviewValueFor(unit, preview),
          ),
        );
        continue;
      }

      if (!game.canFactionTraverseSector(unit.ownerId, tile)) {
        continue;
      }
      orders.add(
        _UnitOrderOption(
          tile: tile,
          hint: _TileActionHint.move,
          label: 'Move to ${x + 1}, ${y + 1}',
          description:
              '${OpenDeadlockGame.terrainLabelFor(tile.terrain)} / $moveCost move',
        ),
      );
    }

    return orders;
  }

  IconData _iconForOrder(_TileActionHint hint) {
    if (hint == _TileActionHint.attack) {
      return Icons.gps_fixed;
    }
    if (hint == _TileActionHint.assault) {
      return Icons.warning_amber;
    }
    return Icons.directions;
  }
}

class _UnitRosterDetail extends StatelessWidget {
  const _UnitRosterDetail({
    Key? key,
    required this.units,
    required this.selectedUnitId,
    required this.onSelectUnit,
  }) : super(key: key);

  final List<Unit> units;
  final String? selectedUnitId;
  final void Function(Unit unit) onSelectUnit;

  @override
  Widget build(BuildContext context) {
    final readyCount = units.where((unit) => unit.movesRemaining > 0).length;
    final woundedCount = units
        .where((unit) => unit.health < OpenDeadlockGame.maxHealthFor(unit.type))
        .length;

    return Container(
      key: const ValueKey<String>('unit-roster'),
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
              const Icon(Icons.groups_2, color: Color(0xFFE9EEF2), size: 19),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Unit Roster',
                  style: TextStyle(
                    color: Color(0xFFF4F7FA),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${units.length} total',
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
            label: 'Readiness',
            value: '$readyCount ready / $woundedCount wounded',
          ),
          const SizedBox(height: 4),
          ...units.map(
            (unit) => _UnitRosterRow(
              unit: unit,
              isSelected: unit.id == selectedUnitId,
              onSelect: () => onSelectUnit(unit),
            ),
          ),
          const SizedBox(height: 8),
          _UnitCatalogDetail(activeUnitType: _activeUnitType),
        ],
      ),
    );
  }

  String? get _activeUnitType {
    if (selectedUnitId == null) {
      return null;
    }
    for (final unit in units) {
      if (unit.id == selectedUnitId) {
        return unit.type;
      }
    }
    return null;
  }
}

class _ExpansionPlannerDetail extends StatelessWidget {
  const _ExpansionPlannerDetail({
    Key? key,
    required this.game,
    required this.units,
    required this.selectedUnitId,
    required this.onSelectUnit,
    required this.onSelectSector,
  }) : super(key: key);

  final OpenDeadlockGame game;
  final List<Unit> units;
  final String? selectedUnitId;
  final void Function(Unit unit) onSelectUnit;
  final void Function(int x, int y) onSelectSector;

  @override
  Widget build(BuildContext context) {
    final scoutUnits =
        units.where((unit) => unit.type == 'scout').toList(growable: false);
    final readyScouts =
        scoutUnits.where((unit) => _canFoundFrom(unit)).toList(growable: false);
    final candidateSites = _candidateSites().take(3).toList(growable: false);

    return Container(
      key: const ValueKey<String>('expansion-planner'),
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
              const Icon(Icons.explore, color: Color(0xFFE9EEF2), size: 19),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Expansion Planner',
                  style: TextStyle(
                    color: Color(0xFFF4F7FA),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                _stateLabel(readyScouts.length, candidateSites.length),
                style: const TextStyle(
                  color: Color(0xFF9FB0BE),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DetailRow(label: 'Scouts', value: _scoutLabel(scoutUnits.length)),
          _DetailRow(
            label: 'Ready Sites',
            value: candidateSites.isEmpty
                ? 'No owned empty sectors'
                : '${candidateSites.length} best sectors listed',
          ),
          if (readyScouts.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Ready to Found',
              style: TextStyle(
                color: Color(0xFFF4F7FA),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            ...readyScouts.map(
              (unit) => _ExpansionUnitRow(
                unit: unit,
                selected: unit.id == selectedUnitId,
                onSelect: () => onSelectUnit(unit),
              ),
            ),
          ],
          if (candidateSites.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Best Sites',
              style: TextStyle(
                color: Color(0xFFF4F7FA),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            ...candidateSites.map(
              (site) => _ExpansionSiteRow(
                site: site,
                onSelect: () => onSelectSector(site.tile.x, site.tile.y),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Text(
              'Scout into owned empty ground before founding a new outpost.',
              style: TextStyle(color: Color(0xFFE9EEF2)),
            ),
          ],
        ],
      ),
    );
  }

  bool _canFoundFrom(Unit unit) {
    if (!game.activeFactionCanIssueLocalOrders ||
        unit.ownerId != game.activeFactionId ||
        unit.type != 'scout') {
      return false;
    }
    final tile = game.tileAt(unit.x, unit.y);
    return _isCandidateTile(tile);
  }

  List<_ExpansionSite> _candidateSites() {
    final sites = <_ExpansionSite>[];
    for (final tile in game.tiles) {
      if (!_isCandidateTile(tile)) {
        continue;
      }
      sites.add(
        _ExpansionSite(
          tile: tile,
          score: _siteScore(tile),
          nearestColonyDistance: _nearestOwnedColonyDistance(tile),
        ),
      );
    }
    sites.sort((a, b) {
      final scoreComparison = b.score.compareTo(a.score);
      if (scoreComparison != 0) {
        return scoreComparison;
      }
      final distanceComparison =
          b.nearestColonyDistance.compareTo(a.nearestColonyDistance);
      if (distanceComparison != 0) {
        return distanceComparison;
      }
      final yComparison = a.tile.y.compareTo(b.tile.y);
      if (yComparison != 0) {
        return yComparison;
      }
      return a.tile.x.compareTo(b.tile.x);
    });
    return sites;
  }

  bool _isCandidateTile(PlanetTile tile) {
    final occupyingUnit = game.unitAt(tile.x, tile.y);
    return tile.ownerId == game.activeFactionId &&
        tile.isExploredBy(game.activeFactionId) &&
        OpenDeadlockGame.isTerrainPassable(tile.terrain) &&
        tile.colonyId == null &&
        game.colonyAt(tile.x, tile.y) == null &&
        (occupyingUnit == null ||
            occupyingUnit.ownerId == game.activeFactionId);
  }

  int _siteScore(PlanetTile tile) {
    final yields = tile.yields;
    final balancedYield = yields.food + yields.industry + yields.research;
    return (balancedYield * 10) + _nearestOwnedColonyDistance(tile);
  }

  int _nearestOwnedColonyDistance(PlanetTile tile) {
    final ownedColonies = game.colonies
        .where((colony) => colony.ownerId == game.activeFactionId)
        .toList(growable: false);
    if (ownedColonies.isEmpty) {
      return 0;
    }
    var bestDistance = 999;
    for (final colony in ownedColonies) {
      final distance = (colony.x - tile.x).abs() + (colony.y - tile.y).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
      }
    }
    return bestDistance;
  }

  String _stateLabel(int readyScoutCount, int siteCount) {
    if (readyScoutCount > 0) {
      return '$readyScoutCount ready';
    }
    if (siteCount > 0) {
      return '$siteCount sites';
    }
    return 'Scout';
  }

  String _scoutLabel(int scoutCount) {
    if (scoutCount == 0) {
      return 'No active scouts';
    }
    final readyCount = units.where(_canFoundFrom).length;
    if (readyCount == 0) {
      return '$scoutCount scouting / none ready';
    }
    return '$readyCount ready / $scoutCount scouting';
  }
}

class _ExpansionSite {
  const _ExpansionSite({
    required this.tile,
    required this.score,
    required this.nearestColonyDistance,
  });

  final PlanetTile tile;
  final int score;
  final int nearestColonyDistance;
}

class _ExpansionUnitRow extends StatelessWidget {
  const _ExpansionUnitRow({
    Key? key,
    required this.unit,
    required this.selected,
    required this.onSelect,
  }) : super(key: key);

  final Unit unit;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          icon: Icon(selected ? Icons.radio_button_checked : Icons.flag),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${unit.name} ready at ${unit.x + 1}, ${unit.y + 1}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          onPressed: onSelect,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFE9EEF2),
            alignment: Alignment.centerLeft,
          ),
        ),
      ),
    );
  }
}

class _ExpansionSiteRow extends StatelessWidget {
  const _ExpansionSiteRow({
    Key? key,
    required this.site,
    required this.onSelect,
  }) : super(key: key);

  final _ExpansionSite site;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final tile = site.tile;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          icon: const Icon(Icons.add_location_alt),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sector ${tile.x + 1}, ${tile.y + 1}',
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${OpenDeadlockGame.terrainLabelFor(tile.terrain)} | '
                  '${tile.yields.food} food / ${tile.yields.industry} ind / '
                  '${tile.yields.research} res | '
                  '${site.nearestColonyDistance} from colony',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          onPressed: onSelect,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFE9EEF2),
            alignment: Alignment.centerLeft,
          ),
        ),
      ),
    );
  }
}

class _UnitRosterRow extends StatelessWidget {
  const _UnitRosterRow({
    Key? key,
    required this.unit,
    required this.isSelected,
    required this.onSelect,
  }) : super(key: key);

  final Unit unit;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final maxHealth = OpenDeadlockGame.maxHealthFor(unit.type);
    final maxMoves = OpenDeadlockGame.maxMovesFor(unit.type);
    final wounded = unit.health < maxHealth;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.only(top: 8),
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
                      isSelected ? Icons.my_location : Icons.navigation,
                      size: 16,
                    ),
                    label: Text(
                      unit.name,
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
                '${unit.x + 1}, ${unit.y + 1}',
                style: const TextStyle(
                  color: Color(0xFF9FB0BE),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Text(
            '${OpenDeadlockGame.unitTypeLabelFor(unit.type)} | HP ${unit.health}/$maxHealth | Moves ${unit.movesRemaining}/$maxMoves',
            style: TextStyle(
              color:
                  wounded ? const Color(0xFFF2C38B) : const Color(0xFFB9C5CE),
              fontSize: 12,
              fontWeight: wounded ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitCatalogDetail extends StatelessWidget {
  const _UnitCatalogDetail({
    Key? key,
    required this.activeUnitType,
  }) : super(key: key);

  final String? activeUnitType;

  @override
  Widget build(BuildContext context) {
    final activeLabel = activeUnitType == null
        ? 'none selected'
        : '${OpenDeadlockGame.unitTypeLabelFor(activeUnitType!)} selected';

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFF31404C)),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 2),
            collapsedIconColor: const Color(0xFFE9EEF2),
            iconColor: const Color(0xFFE9EEF2),
            title: const Row(
              children: [
                Icon(Icons.shield, color: Color(0xFFE9EEF2), size: 17),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Unit Catalog',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFFF4F7FA),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              '${OpenDeadlockGame.unitTypes.length} unit types / $activeLabel',
              style: const TextStyle(
                color: Color(0xFFB9C5CE),
                fontSize: 12,
              ),
            ),
            children: [
              ...OpenDeadlockGame.unitTypes.map(
                (unitType) => _UnitCatalogRow(
                  unitType: unitType,
                  isActive: unitType == activeUnitType,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitCatalogRow extends StatelessWidget {
  const _UnitCatalogRow({
    Key? key,
    required this.unitType,
    required this.isActive,
  }) : super(key: key);

  final String unitType;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFFCCD6A6) : const Color(0xFFE9EEF2);
    final label = OpenDeadlockGame.unitTypeLabelFor(unitType);

    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              isActive ? Icons.play_circle : Icons.radio_button_unchecked,
              color: color,
              size: 14,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label - ${isActive ? 'Selected' : 'Available'}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${OpenDeadlockGame.maxHealthFor(unitType)} HP / '
                  '${OpenDeadlockGame.attackFor(unitType)} attack / '
                  '${OpenDeadlockGame.defenseFor(unitType)} defense / '
                  '${OpenDeadlockGame.maxMovesFor(unitType)} moves / '
                  '${OpenDeadlockGame.visionRadiusForUnit(unitType)} vision',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB9C5CE),
                    fontSize: 12,
                  ),
                ),
                Text(
                  OpenDeadlockGame.unitTypeDescriptionFor(unitType),
                  overflow: TextOverflow.ellipsis,
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
          _DetailRow(
            label: 'Type',
            value: OpenDeadlockGame.unitTypeLabelFor(unit.type),
          ),
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
              (preview) => _CombatPreviewDetail(preview: preview),
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
            attacker: _unitBattleStatsLabel(unit),
            target: _unitBattleStatsLabel(defender),
            aftermath: _unitCombatAftermathLabel(unit, defender, preview),
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
            attacker: _unitBattleStatsLabel(unit),
            target: _colonyBattleStatsLabel(game, targetColony),
            aftermath: _colonyAssaultAftermathLabel(unit, preview),
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
    return _unitCombatPreviewValueFor(unit, defender, preview);
  }

  String _colonyAssaultPreviewValue(ColonyAssaultPreview preview) {
    return _colonyAssaultPreviewValueFor(unit, preview);
  }
}

String _unitCombatPreviewValueFor(
  Unit attacker,
  Unit defender,
  UnitCombatPreview preview,
) {
  return 'Deal ${preview.attackDamage}, counter ${preview.counterDamage}, '
      'you ${preview.attackerHealth}/${OpenDeadlockGame.maxHealthFor(attacker.type)}, '
      'target ${preview.defenderHealth}/${OpenDeadlockGame.maxHealthFor(defender.type)}, '
      '${_unitCombatOutcomeLabel(preview)}, ${_riskLabelFor(
    attackerSurvives: preview.attackerSurvives,
    attackerHealth: preview.attackerHealth,
    maxHealth: OpenDeadlockGame.maxHealthFor(attacker.type),
    counterDamage: preview.counterDamage,
  )} risk';
}

String _colonyAssaultPreviewValueFor(
  Unit attacker,
  ColonyAssaultPreview preview,
) {
  return '${preview.attackPower} vs ${preview.defensePower}, '
      '${preview.colonyCaptured ? 'capture' : 'repelled'}, '
      'you ${preview.attackerHealth}/${OpenDeadlockGame.maxHealthFor(attacker.type)}, '
      '${preview.population} pop / ${preview.morale} morale, '
      '${_riskLabelFor(
    attackerSurvives: preview.attackerSurvives,
    attackerHealth: preview.attackerHealth,
    maxHealth: OpenDeadlockGame.maxHealthFor(attacker.type),
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

String _unitBattleStatsLabel(Unit unit) {
  return '${unit.name} | ${unit.type} | '
      '${unit.health}/${OpenDeadlockGame.maxHealthFor(unit.type)} HP | '
      '${OpenDeadlockGame.attackFor(unit.type)} atk / '
      '${OpenDeadlockGame.defenseFor(unit.type)} def';
}

String _colonyBattleStatsLabel(OpenDeadlockGame game, Colony colony) {
  return '${colony.name} | colony | ${colony.population} pop / '
      '${colony.morale} morale | ${game.colonyDefenseForColony(colony)} defense';
}

String _unitCombatAftermathLabel(
  Unit attacker,
  Unit defender,
  UnitCombatPreview preview,
) {
  return 'You ${preview.attackerHealth} HP | '
      'target ${preview.defenderHealth} HP | '
      '${_unitCombatOutcomeLabel(preview)} | '
      '${_riskLabelFor(
    attackerSurvives: preview.attackerSurvives,
    attackerHealth: preview.attackerHealth,
    maxHealth: OpenDeadlockGame.maxHealthFor(attacker.type),
    counterDamage: preview.counterDamage,
  )} risk';
}

String _colonyAssaultAftermathLabel(
  Unit attacker,
  ColonyAssaultPreview preview,
) {
  return 'You ${preview.attackerHealth} HP | '
      '${preview.population} pop / ${preview.morale} morale | '
      '${preview.colonyCaptured ? 'capture' : 'repelled'} | '
      '${_riskLabelFor(
    attackerSurvives: preview.attackerSurvives,
    attackerHealth: preview.attackerHealth,
    maxHealth: OpenDeadlockGame.maxHealthFor(attacker.type),
    counterDamage: preview.counterDamage,
  )} risk';
}

class _CombatReadinessDetail extends StatelessWidget {
  const _CombatReadinessDetail({
    Key? key,
    required this.game,
  }) : super(key: key);

  final OpenDeadlockGame game;

  @override
  Widget build(BuildContext context) {
    final factionId = game.activeFactionId;
    final faction = game.activeFaction;
    final ownedUnits =
        game.units.where((unit) => unit.ownerId == factionId).toList();
    final combatUnits =
        ownedUnits.where((unit) => unit.type != 'scout').toList();
    final readyUnits =
        ownedUnits.where((unit) => unit.movesRemaining > 0).toList();
    final woundedUnits = ownedUnits
        .where((unit) => unit.health < OpenDeadlockGame.maxHealthFor(unit.type))
        .toList();
    final visibleEnemyUnits = game.units
        .where(
          (unit) =>
              game.areAtWar(factionId, unit.ownerId) &&
              game.isUnitVisibleTo(factionId, unit),
        )
        .toList();
    final knownEnemyColonies = game.colonies
        .where(
          (colony) =>
              game.areAtWar(factionId, colony.ownerId) &&
              game.tileAt(colony.x, colony.y).isExploredBy(factionId),
        )
        .toList();
    final recentBattles =
        game.reports.where((report) => report.isBattle).length;
    final posture = visibleEnemyUnits.isNotEmpty
        ? 'Enemy contact'
        : knownEnemyColonies.isNotEmpty
            ? 'Known targets'
            : 'No visible battles';

    return Container(
      key: const ValueKey<String>('combat-readiness'),
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
              Icon(Icons.shield, color: Color(faction.colorValue), size: 19),
              const SizedBox(width: 8),
              const Text(
                'Combat Readiness',
                style: TextStyle(
                  color: Color(0xFFF4F7FA),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DetailRow(label: 'Posture', value: posture),
          _DetailRow(
            label: 'Strength',
            value: '${game.militaryStrengthFor(factionId)} power',
          ),
          _DetailRow(
            label: 'Units',
            value:
                '${ownedUnits.length} total / ${combatUnits.length} combat / ${readyUnits.length} ready',
          ),
          _DetailRow(
            label: 'Wounded',
            value: woundedUnits.isEmpty
                ? 'None'
                : woundedUnits
                    .map(
                      (unit) =>
                          '${unit.name} ${unit.health}/${OpenDeadlockGame.maxHealthFor(unit.type)}',
                    )
                    .join(', '),
          ),
          _DetailRow(
            label: 'Visible Enemies',
            value: visibleEnemyUnits.isEmpty
                ? 'None'
                : visibleEnemyUnits
                    .map(
                      (unit) => '${unit.name} at ${unit.x + 1}, ${unit.y + 1}',
                    )
                    .join(', '),
          ),
          _DetailRow(
            label: 'Known Enemy Colonies',
            value: knownEnemyColonies.isEmpty
                ? 'None'
                : knownEnemyColonies
                    .map(
                      (colony) =>
                          '${colony.name} at ${colony.x + 1}, ${colony.y + 1}',
                    )
                    .join(', '),
          ),
          _DetailRow(
            label: 'Recent Battles',
            value: recentBattles == 1 ? '1 logged' : '$recentBattles logged',
          ),
        ],
      ),
    );
  }
}

class _CombatPreviewRow {
  const _CombatPreviewRow({
    required this.label,
    required this.value,
    required this.attacker,
    required this.target,
    required this.aftermath,
  });

  final String label;
  final String value;
  final String attacker;
  final String target;
  final String aftermath;
}

class _CombatPreviewDetail extends StatelessWidget {
  const _CombatPreviewDetail({
    Key? key,
    required this.preview,
  }) : super(key: key);

  final _CombatPreviewRow preview;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF31404C)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preview.label,
                style: const TextStyle(
                  color: Color(0xFFE9EEF2),
                  fontWeight: FontWeight.bold,
                ),
              ),
              _DetailRow(label: 'Attacker', value: preview.attacker),
              _DetailRow(label: 'Target', value: preview.target),
              _DetailRow(label: 'Outcome', value: preview.aftermath),
              _DetailRow(label: 'Summary', value: preview.value),
            ],
          ),
        ),
      ),
    );
  }
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

class _ColonyOrdersDetail extends StatelessWidget {
  const _ColonyOrdersDetail({
    Key? key,
    required this.colony,
    required this.rushIndustry,
    required this.rushCost,
    required this.canRush,
    required this.bestSectorCount,
    required this.assignedSectorCount,
    required this.focusTargetCount,
    required this.buildTargetCount,
    required this.onRushConstruction,
    required this.onAssignBestSectors,
    required this.onReleaseAllSectors,
    required this.onApplyFocusToAll,
    required this.onApplyConstructionToAll,
  }) : super(key: key);

  final Colony colony;
  final int rushIndustry;
  final int rushCost;
  final bool canRush;
  final int bestSectorCount;
  final int assignedSectorCount;
  final int focusTargetCount;
  final int buildTargetCount;
  final VoidCallback onRushConstruction;
  final VoidCallback onAssignBestSectors;
  final VoidCallback onReleaseAllSectors;
  final VoidCallback onApplyFocusToAll;
  final VoidCallback onApplyConstructionToAll;

  @override
  Widget build(BuildContext context) {
    final hasAnyAction = canRush ||
        bestSectorCount > 0 ||
        assignedSectorCount > 0 ||
        focusTargetCount > 0 ||
        buildTargetCount > 0;

    return Container(
      key: const ValueKey<String>('colony-orders'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF26333C),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF43515B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.task_alt, color: Color(0xFFE9EEF2), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Colony Orders',
                  style: TextStyle(
                    color: Color(0xFFF4F7FA),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!hasAnyAction)
            const Text(
              'No immediate colony orders available.',
              style: TextStyle(color: Color(0xFFE9EEF2)),
            )
          else ...[
            _ColonyOrderButton(
              icon: Icons.flash_on,
              label: canRush
                  ? 'Rush Construction +$rushIndustry'
                  : 'Rush Construction',
              detail: canRush
                  ? '$rushCost credits for ${colony.construction}'
                  : 'Need credits and unfinished construction',
              enabled: canRush,
              onPressed: onRushConstruction,
            ),
            _ColonyOrderButton(
              icon: Icons.grid_view,
              label: bestSectorCount == 0
                  ? 'Assign Best Work'
                  : 'Assign Best Work x$bestSectorCount',
              detail: bestSectorCount == 0
                  ? 'No better legal sectors'
                  : 'Fill open work slots with best yields',
              enabled: bestSectorCount > 0,
              onPressed: onAssignBestSectors,
            ),
            _ColonyOrderButton(
              icon: Icons.grid_off,
              label: assignedSectorCount == 0
                  ? 'Release Worked Sectors'
                  : 'Release Worked Sectors x$assignedSectorCount',
              detail: assignedSectorCount == 0
                  ? 'No outlying sectors assigned'
                  : 'Clear current outlying assignments',
              enabled: assignedSectorCount > 0,
              onPressed: onReleaseAllSectors,
            ),
            _ColonyOrderButton(
              icon: Icons.tune,
              label:
                  'Copy ${OpenDeadlockGame.colonyFocusLabelFor(colony.focus)} Focus',
              detail: focusTargetCount == 0
                  ? 'All colonies already match'
                  : '$focusTargetCount eligible ${_colonyCountLabel(focusTargetCount)}',
              enabled: focusTargetCount > 0,
              onPressed: onApplyFocusToAll,
            ),
            _ColonyOrderButton(
              icon: Icons.playlist_add_check,
              label: 'Copy ${colony.construction} Build',
              detail: buildTargetCount == 0
                  ? 'No eligible colonies'
                  : '$buildTargetCount eligible ${_colonyCountLabel(buildTargetCount)}',
              enabled: buildTargetCount > 0,
              onPressed: onApplyConstructionToAll,
            ),
          ],
        ],
      ),
    );
  }

  String _colonyCountLabel(int count) {
    return count == 1 ? 'colony' : 'colonies';
  }
}

class _ColonyOrderButton extends StatelessWidget {
  const _ColonyOrderButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.detail,
    required this.enabled,
    required this.onPressed,
  }) : super(key: key);

  final IconData icon;
  final String label;
  final String detail;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: Icon(icon),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  detail,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          onPressed: enabled ? onPressed : null,
        ),
      ),
    );
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
    final bestSectors = game.preferredAssignableSectorsFor(colony);
    final assignedSectorCount = colony.assignedSectors.length;

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
                _FocusCatalogDetail(activeFocus: colony.focus),
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
          _FocusCatalogDetail(activeFocus: colony.focus),
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
          if (projection.hasMaintenanceShortfall)
            _DetailRow(
              label: 'Maintenance',
              value:
                  '${projection.maintenanceShortfall} credit shortfall, ${_signedInt(-projection.maintenanceShortfall * OpenDeadlockGame.buildingUpkeepShortfallMoralePenalty)} morale',
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
          _BuildCatalogDetail(colony: colony),
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
          if (canEdit) ...[
            const SizedBox(height: 8),
            _ColonyOrdersDetail(
              colony: colony,
              rushIndustry: rushIndustry,
              rushCost: rushCost,
              canRush: canRush,
              bestSectorCount: bestSectors.length,
              assignedSectorCount: assignedSectorCount,
              focusTargetCount: focusTargetCount,
              buildTargetCount: buildTargetCount,
              onRushConstruction: () =>
                  onRushConstruction(colony.id, rushIndustry),
              onAssignBestSectors: () => onAssignBestSectors(colony),
              onReleaseAllSectors: () => onReleaseAllSectors(colony),
              onApplyFocusToAll: () => onApplyFocusToAll(colony),
              onApplyConstructionToAll: () => onApplyConstructionToAll(colony),
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
    if (projection.hasMaintenanceShortfall) {
      drivers.add(
        'upkeep shortfall ${_signedInt(-projection.maintenanceShortfall * OpenDeadlockGame.buildingUpkeepShortfallMoralePenalty)}',
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

class _FocusCatalogDetail extends StatelessWidget {
  const _FocusCatalogDetail({
    Key? key,
    required this.activeFocus,
  }) : super(key: key);

  final String activeFocus;

  @override
  Widget build(BuildContext context) {
    final activeLabel = OpenDeadlockGame.colonyFocusLabelFor(activeFocus);

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF31404C)),
          ),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: Material(
            type: MaterialType.transparency,
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 2),
              collapsedIconColor: const Color(0xFFE9EEF2),
              iconColor: const Color(0xFFE9EEF2),
              title: const Row(
                children: [
                  Icon(Icons.tune, color: Color(0xFFE9EEF2), size: 17),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Focus Catalog',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFFF4F7FA),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                '${OpenDeadlockGame.colonyFocuses.length} options / '
                '$activeLabel active',
                style: const TextStyle(
                  color: Color(0xFFB9C5CE),
                  fontSize: 12,
                ),
              ),
              children: [
                ...OpenDeadlockGame.colonyFocuses.map(
                  (focus) => _FocusCatalogRow(
                    focus: focus,
                    isActive: focus == activeFocus,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusCatalogRow extends StatelessWidget {
  const _FocusCatalogRow({
    Key? key,
    required this.focus,
    required this.isActive,
  }) : super(key: key);

  final String focus;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFFCCD6A6) : const Color(0xFFE9EEF2);
    final label = OpenDeadlockGame.colonyFocusLabelFor(focus);
    final description = OpenDeadlockGame.colonyFocusDescriptionFor(focus);

    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              isActive ? Icons.play_circle : Icons.radio_button_unchecked,
              color: color,
              size: 14,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label - ${isActive ? 'Active' : 'Available'}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  description,
                  overflow: TextOverflow.ellipsis,
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

class _BuildCatalogDetail extends StatelessWidget {
  const _BuildCatalogDetail({
    Key? key,
    required this.colony,
  }) : super(key: key);

  final Colony colony;

  @override
  Widget build(BuildContext context) {
    final items = OpenDeadlockGame.constructionOptions
        .map((construction) => _BuildCatalogItem.forConstruction(
              colony,
              construction,
            ))
        .toList(growable: false);
    final availableCount = items
        .where((item) => item.status == _BuildCatalogStatus.available)
        .length;
    final completedCount = items
        .where((item) => item.status == _BuildCatalogStatus.completed)
        .length;
    final lockedCount =
        items.where((item) => item.status == _BuildCatalogStatus.locked).length;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF31404C)),
          ),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: Material(
            type: MaterialType.transparency,
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 2),
              collapsedIconColor: const Color(0xFFE9EEF2),
              iconColor: const Color(0xFFE9EEF2),
              title: const Row(
                children: [
                  Icon(Icons.account_tree, color: Color(0xFFE9EEF2), size: 17),
                  SizedBox(width: 7),
                  Text(
                    'Build Catalog',
                    style: TextStyle(
                      color: Color(0xFFF4F7FA),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              subtitle: _DetailRow(
                label: 'Options',
                value:
                    '$availableCount available / $completedCount completed / $lockedCount locked',
              ),
              children: [
                ...items.map((item) => _BuildCatalogRow(item: item)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _BuildCatalogStatus { available, completed, locked }

class _BuildCatalogItem {
  const _BuildCatalogItem({
    required this.construction,
    required this.status,
    required this.cost,
    required this.upkeep,
    required this.requirement,
    required this.produces,
  });

  final String construction;
  final _BuildCatalogStatus status;
  final int cost;
  final int upkeep;
  final String requirement;
  final String produces;

  static _BuildCatalogItem forConstruction(
    Colony colony,
    String construction,
  ) {
    final completed =
        OpenDeadlockGame.isCompletedConstruction(colony, construction);
    final available =
        OpenDeadlockGame.isConstructionAvailableFor(colony, construction);
    return _BuildCatalogItem(
      construction: construction,
      status: completed
          ? _BuildCatalogStatus.completed
          : available
              ? _BuildCatalogStatus.available
              : _BuildCatalogStatus.locked,
      cost: OpenDeadlockGame.buildCostFor(construction),
      upkeep: OpenDeadlockGame.constructionUpkeepFor(construction),
      requirement: OpenDeadlockGame.constructionRequirementFor(construction),
      produces:
          OpenDeadlockGame.constructionProducesDescriptionFor(construction),
    );
  }
}

class _BuildCatalogRow extends StatelessWidget {
  const _BuildCatalogRow({
    Key? key,
    required this.item,
  }) : super(key: key);

  final _BuildCatalogItem item;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(_statusIcon(), color: color, size: 14),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.construction} - ${_statusLabel()}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${item.cost} industry / ${item.upkeep} upkeep / Requires ${item.requirement}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB9C5CE),
                    fontSize: 12,
                  ),
                ),
                Text(
                  item.produces,
                  overflow: TextOverflow.ellipsis,
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

  Color _statusColor() {
    if (item.status == _BuildCatalogStatus.completed) {
      return const Color(0xFF82CBA8);
    }
    if (item.status == _BuildCatalogStatus.locked) {
      return const Color(0xFFF2C38B);
    }
    return const Color(0xFFE9EEF2);
  }

  IconData _statusIcon() {
    if (item.status == _BuildCatalogStatus.completed) {
      return Icons.check_circle;
    }
    if (item.status == _BuildCatalogStatus.locked) {
      return Icons.lock;
    }
    return Icons.radio_button_unchecked;
  }

  String _statusLabel() {
    if (item.status == _BuildCatalogStatus.completed) {
      return 'Completed';
    }
    if (item.status == _BuildCatalogStatus.locked) {
      return 'Locked';
    }
    return 'Available';
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
