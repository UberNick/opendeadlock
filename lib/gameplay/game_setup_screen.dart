import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/game_codec.dart';
import '../game/game_setup.dart';
import '../game/game_state.dart';
import 'game_screen.dart';

class GameSetupScreen extends StatefulWidget {
  const GameSetupScreen({Key? key}) : super(key: key);

  @override
  State<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends State<GameSetupScreen> {
  static const String setupModeAi = 'ai';
  static const String setupModeHotseat = 'hotseat';
  static const String setupModeAsync = 'async';
  static const String setupModeCustom = 'custom';
  static const List<String> setupModes = <String>[
    setupModeAi,
    setupModeHotseat,
    setupModeAsync,
    setupModeCustom,
  ];

  String mapSize = GameSetup.mapSizeStandard;
  String planetType = GameSetup.planetTypeTerran;
  String setupMode = setupModeAi;
  String startingDiplomacy = OpenDeadlockGame.diplomacyStatusWar;
  String victoryCondition = OpenDeadlockGame.victoryConditionAny;
  late final TextEditingController worldSeedController;
  String playerRaceId = 'human';
  String playerAiPersonality = Faction.aiPersonalityResearcher;
  String playerPrimaryTrait = 'scholars';
  String playerSecondaryTrait = 'traders';
  String rivalRaceId = 'tarth';
  String rivalControlMode = Faction.controlComputer;
  String rivalDifficulty = Faction.difficultyNormal;
  String rivalAiPersonality = Faction.aiPersonalityConqueror;
  String rivalPrimaryTrait = 'industrialists';
  String rivalSecondaryTrait = 'militarists';
  bool includeThirdFaction = false;
  String thirdRaceId = 'uva_mosk';
  String thirdControlMode = Faction.controlComputer;
  String thirdDifficulty = Faction.difficultyNormal;
  String thirdAiPersonality = Faction.aiPersonalityTrader;
  String thirdPrimaryTrait = 'agrarian';
  String thirdSecondaryTrait = 'traders';
  bool includeFourthFaction = false;
  String fourthRaceId = 'maug';
  String fourthControlMode = Faction.controlComputer;
  String fourthDifficulty = Faction.difficultyNormal;
  String fourthAiPersonality = Faction.aiPersonalityResearcher;
  String fourthPrimaryTrait = 'scholars';
  String fourthSecondaryTrait = 'industrialists';

  @override
  void initState() {
    super.initState();
    worldSeedController = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    worldSeedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101418),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      color: Colors.white,
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'New Game',
                        style: TextStyle(
                          color: Color(0xFFF4F7FA),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SetupPanel(
                  title: 'Planet',
                  icon: Icons.public,
                  children: [
                    _SetupDropdown(
                      label: 'Map',
                      value: mapSize,
                      items: GameSetup.mapSizes,
                      labelFor: GameSetup.mapSizeLabelFor,
                      onChanged: (value) {
                        setState(() {
                          mapSize = value;
                        });
                      },
                    ),
                    _SetupDropdown(
                      label: 'Type',
                      value: planetType,
                      items: GameSetup.planetTypes,
                      labelFor: GameSetup.planetTypeLabelFor,
                      onChanged: (value) {
                        setState(() {
                          planetType = value;
                        });
                      },
                    ),
                    _SetupDropdown(
                      label: 'Mode',
                      value: setupMode,
                      items: setupModes,
                      labelFor: _setupModeLabelFor,
                      onChanged: (value) {
                        setState(() {
                          _selectSetupMode(value);
                        });
                      },
                    ),
                    _SetupDropdown(
                      label: 'Relations',
                      value: startingDiplomacy,
                      items: OpenDeadlockGame.diplomacyStatuses,
                      labelFor: GameSetup.startingDiplomacyLabelFor,
                      onChanged: (value) {
                        setState(() {
                          startingDiplomacy = value;
                        });
                      },
                    ),
                    _SetupDropdown(
                      label: 'Victory',
                      value: victoryCondition,
                      items: OpenDeadlockGame.victoryConditions,
                      labelFor: GameSetup.victoryConditionLabelFor,
                      onChanged: (value) {
                        setState(() {
                          victoryCondition = value;
                        });
                      },
                    ),
                    _SeedField(
                      controller: worldSeedController,
                      onRoll: _rollWorldSeed,
                    ),
                    _SetupReadout(
                      label: 'Size',
                      value: GameSetup.mapSizeSummaryFor(mapSize),
                    ),
                    _SetupReadout(
                      label: 'Bias',
                      value: GameSetup.planetTypeDescriptionFor(planetType),
                    ),
                    _SetupReadout(
                      label: 'Seats',
                      value: _setupModeDescriptionFor(setupMode),
                    ),
                    _SetupReadout(
                      label: 'Relations',
                      value: GameSetup.startingDiplomacyDescriptionFor(
                        startingDiplomacy,
                      ),
                    ),
                    _SetupReadout(
                      label: 'Victory',
                      value: GameSetup.victoryConditionDescriptionFor(
                        victoryCondition,
                      ),
                    ),
                    _SetupReadout(
                      label: 'Starts',
                      value: '${_factionCount()} starting colonies',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SetupPanel(
                  title: GameSetup.raceLabelFor(playerRaceId),
                  icon: Icons.person,
                  children: [
                    const _SetupReadout(label: 'Seat', value: 'Local'),
                    _PersonalityDropdown(
                      value: playerAiPersonality,
                      onChanged: (value) {
                        setState(() {
                          playerAiPersonality = value;
                        });
                      },
                    ),
                    _RaceDropdown(
                      label: 'Race',
                      value: playerRaceId,
                      onChanged: (value) {
                        setState(() {
                          playerRaceId = value;
                        });
                      },
                    ),
                    _TraitDropdown(
                      label: 'Trait 1',
                      value: playerPrimaryTrait,
                      blockedTraitId: playerSecondaryTrait,
                      onChanged: (value) {
                        setState(() {
                          playerPrimaryTrait = value;
                        });
                      },
                    ),
                    _TraitDropdown(
                      label: 'Trait 2',
                      value: playerSecondaryTrait,
                      blockedTraitId: playerPrimaryTrait,
                      onChanged: (value) {
                        setState(() {
                          playerSecondaryTrait = value;
                        });
                      },
                    ),
                    ..._factionReadouts(
                      playerRaceId,
                      playerPrimaryTrait,
                      playerSecondaryTrait,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SetupPanel(
                  title: GameSetup.raceLabelFor(rivalRaceId),
                  icon: Icons.smart_toy,
                  children: [
                    _RaceDropdown(
                      label: 'Race',
                      value: rivalRaceId,
                      onChanged: (value) {
                        setState(() {
                          rivalRaceId = value;
                        });
                      },
                    ),
                    _SetupDropdown(
                      label: 'Seat',
                      value: rivalControlMode,
                      items: const <String>[
                        Faction.controlComputer,
                        Faction.controlRemote,
                        Faction.controlLocal,
                      ],
                      labelFor: Faction.controlModeLabelFor,
                      onChanged: (value) {
                        setState(() {
                          rivalControlMode = value;
                          _syncSetupModeToSeats();
                        });
                      },
                    ),
                    _SetupDropdown(
                      label: 'Difficulty',
                      value: rivalDifficulty,
                      items: Faction.difficultyLevels,
                      labelFor: Faction.difficultyLabelFor,
                      onChanged: (value) {
                        setState(() {
                          rivalDifficulty = value;
                        });
                      },
                    ),
                    _PersonalityDropdown(
                      value: rivalAiPersonality,
                      onChanged: (value) {
                        setState(() {
                          rivalAiPersonality = value;
                        });
                      },
                    ),
                    _TraitDropdown(
                      label: 'Trait 1',
                      value: rivalPrimaryTrait,
                      blockedTraitId: rivalSecondaryTrait,
                      onChanged: (value) {
                        setState(() {
                          rivalPrimaryTrait = value;
                        });
                      },
                    ),
                    _TraitDropdown(
                      label: 'Trait 2',
                      value: rivalSecondaryTrait,
                      blockedTraitId: rivalPrimaryTrait,
                      onChanged: (value) {
                        setState(() {
                          rivalSecondaryTrait = value;
                        });
                      },
                    ),
                    ..._factionReadouts(
                      rivalRaceId,
                      rivalPrimaryTrait,
                      rivalSecondaryTrait,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SetupPanel(
                  title: GameSetup.raceLabelFor(thirdRaceId),
                  icon: Icons.account_balance,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Add faction',
                        style: TextStyle(color: Color(0xFFE9EEF2)),
                      ),
                      value: includeThirdFaction,
                      activeThumbColor: const Color(0xFFCCD6A6),
                      onChanged: (value) {
                        setState(() {
                          includeThirdFaction = value;
                          if (!includeThirdFaction) {
                            includeFourthFaction = false;
                          } else {
                            _applySetupModeToFactionSeats(setupMode);
                          }
                          _syncSetupModeToSeats();
                        });
                      },
                    ),
                    if (includeThirdFaction) ...[
                      _RaceDropdown(
                        label: 'Race',
                        value: thirdRaceId,
                        onChanged: (value) {
                          setState(() {
                            thirdRaceId = value;
                          });
                        },
                      ),
                      _SetupDropdown(
                        label: 'Seat',
                        value: thirdControlMode,
                        items: const <String>[
                          Faction.controlComputer,
                          Faction.controlRemote,
                          Faction.controlLocal,
                        ],
                        labelFor: Faction.controlModeLabelFor,
                        onChanged: (value) {
                          setState(() {
                            thirdControlMode = value;
                            _syncSetupModeToSeats();
                          });
                        },
                      ),
                      _SetupDropdown(
                        label: 'Difficulty',
                        value: thirdDifficulty,
                        items: Faction.difficultyLevels,
                        labelFor: Faction.difficultyLabelFor,
                        onChanged: (value) {
                          setState(() {
                            thirdDifficulty = value;
                          });
                        },
                      ),
                      _PersonalityDropdown(
                        value: thirdAiPersonality,
                        onChanged: (value) {
                          setState(() {
                            thirdAiPersonality = value;
                          });
                        },
                      ),
                      _TraitDropdown(
                        label: 'Trait 1',
                        value: thirdPrimaryTrait,
                        blockedTraitId: thirdSecondaryTrait,
                        onChanged: (value) {
                          setState(() {
                            thirdPrimaryTrait = value;
                          });
                        },
                      ),
                      _TraitDropdown(
                        label: 'Trait 2',
                        value: thirdSecondaryTrait,
                        blockedTraitId: thirdPrimaryTrait,
                        onChanged: (value) {
                          setState(() {
                            thirdSecondaryTrait = value;
                          });
                        },
                      ),
                      ..._factionReadouts(
                        thirdRaceId,
                        thirdPrimaryTrait,
                        thirdSecondaryTrait,
                      ),
                    ],
                  ],
                ),
                if (includeThirdFaction) ...[
                  const SizedBox(height: 12),
                  _SetupPanel(
                    title: GameSetup.raceLabelFor(fourthRaceId),
                    icon: Icons.shield,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Add faction',
                          style: TextStyle(color: Color(0xFFE9EEF2)),
                        ),
                        value: includeFourthFaction,
                        activeThumbColor: const Color(0xFFCCD6A6),
                        onChanged: (value) {
                          setState(() {
                            includeFourthFaction = value;
                            if (includeFourthFaction) {
                              _applySetupModeToFactionSeats(setupMode);
                            }
                            _syncSetupModeToSeats();
                          });
                        },
                      ),
                      if (includeFourthFaction) ...[
                        _RaceDropdown(
                          label: 'Race',
                          value: fourthRaceId,
                          onChanged: (value) {
                            setState(() {
                              fourthRaceId = value;
                            });
                          },
                        ),
                        _SetupDropdown(
                          label: 'Seat',
                          value: fourthControlMode,
                          items: const <String>[
                            Faction.controlComputer,
                            Faction.controlRemote,
                            Faction.controlLocal,
                          ],
                          labelFor: Faction.controlModeLabelFor,
                          onChanged: (value) {
                            setState(() {
                              fourthControlMode = value;
                              _syncSetupModeToSeats();
                            });
                          },
                        ),
                        _SetupDropdown(
                          label: 'Difficulty',
                          value: fourthDifficulty,
                          items: Faction.difficultyLevels,
                          labelFor: Faction.difficultyLabelFor,
                          onChanged: (value) {
                            setState(() {
                              fourthDifficulty = value;
                            });
                          },
                        ),
                        _PersonalityDropdown(
                          value: fourthAiPersonality,
                          onChanged: (value) {
                            setState(() {
                              fourthAiPersonality = value;
                            });
                          },
                        ),
                        _TraitDropdown(
                          label: 'Trait 1',
                          value: fourthPrimaryTrait,
                          blockedTraitId: fourthSecondaryTrait,
                          onChanged: (value) {
                            setState(() {
                              fourthPrimaryTrait = value;
                            });
                          },
                        ),
                        _TraitDropdown(
                          label: 'Trait 2',
                          value: fourthSecondaryTrait,
                          blockedTraitId: fourthPrimaryTrait,
                          onChanged: (value) {
                            setState(() {
                              fourthSecondaryTrait = value;
                            });
                          },
                        ),
                        ..._factionReadouts(
                          fourthRaceId,
                          fourthPrimaryTrait,
                          fourthSecondaryTrait,
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                    onPressed: _startGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCCD6A6),
                      foregroundColor: const Color(0xFF111418),
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

  void _startGame() {
    final setup = _setup();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(
          initialGame: setup.buildGame(sessionId: GameCodec.createSessionId()),
          resumeLatestSave: false,
        ),
      ),
    );
  }

  GameSetup _setup() {
    return GameSetup(
      mapSize: mapSize,
      planetType: planetType,
      worldSeed: _worldSeed(),
      startingDiplomacy: startingDiplomacy,
      victoryCondition: victoryCondition,
      factions: <GameSetupFaction>[
        GameSetupFaction(
          id: 'humans',
          name: GameSetup.raceLabelFor(playerRaceId),
          colorValue: 0xFF2F80ED,
          raceId: playerRaceId,
          controlMode: Faction.controlLocal,
          difficulty: Faction.difficultyNormal,
          aiPersonality: playerAiPersonality,
          traitIds: <String>[playerPrimaryTrait, playerSecondaryTrait],
        ),
        GameSetupFaction(
          id: 'rebels',
          name: GameSetup.raceLabelFor(rivalRaceId),
          colorValue: 0xFFB83232,
          raceId: rivalRaceId,
          controlMode: rivalControlMode,
          difficulty: rivalDifficulty,
          aiPersonality: rivalAiPersonality,
          traitIds: <String>[rivalPrimaryTrait, rivalSecondaryTrait],
        ),
        if (includeThirdFaction)
          GameSetupFaction(
            id: 'traders',
            name: GameSetup.raceLabelFor(thirdRaceId),
            colorValue: 0xFFD9A441,
            raceId: thirdRaceId,
            controlMode: thirdControlMode,
            difficulty: thirdDifficulty,
            aiPersonality: thirdAiPersonality,
            traitIds: <String>[thirdPrimaryTrait, thirdSecondaryTrait],
          ),
        if (includeThirdFaction && includeFourthFaction)
          GameSetupFaction(
            id: 'maug',
            name: GameSetup.raceLabelFor(fourthRaceId),
            colorValue: 0xFF7D5FB2,
            raceId: fourthRaceId,
            controlMode: fourthControlMode,
            difficulty: fourthDifficulty,
            aiPersonality: fourthAiPersonality,
            traitIds: <String>[fourthPrimaryTrait, fourthSecondaryTrait],
          ),
      ],
    );
  }

  int _worldSeed() {
    final trimmed = worldSeedController.text.trim();
    if (trimmed.isEmpty) {
      return 0;
    }
    return int.tryParse(trimmed) ?? 0;
  }

  void _rollWorldSeed() {
    setState(() {
      worldSeedController.text =
          '${DateTime.now().millisecondsSinceEpoch % 1000000}';
    });
  }

  int _factionCount() {
    return 2 + (includeThirdFaction ? 1 : 0) + (includeFourthFaction ? 1 : 0);
  }

  void _selectSetupMode(String mode) {
    setupMode = mode;
    _applySetupModeToFactionSeats(mode);
  }

  void _applySetupModeToFactionSeats(String mode) {
    final controlMode = _controlModeForSetupMode(mode);
    if (controlMode == null) {
      return;
    }
    rivalControlMode = controlMode;
    thirdControlMode = controlMode;
    fourthControlMode = controlMode;
  }

  void _syncSetupModeToSeats() {
    setupMode = _setupModeForCurrentSeats();
  }

  String _setupModeForCurrentSeats() {
    final activeSeats = <String>[
      rivalControlMode,
      if (includeThirdFaction) thirdControlMode,
      if (includeThirdFaction && includeFourthFaction) fourthControlMode,
    ];
    if (activeSeats.every((seat) => seat == Faction.controlComputer)) {
      return setupModeAi;
    }
    if (activeSeats.every((seat) => seat == Faction.controlLocal)) {
      return setupModeHotseat;
    }
    if (activeSeats.every((seat) => seat == Faction.controlRemote)) {
      return setupModeAsync;
    }
    return setupModeCustom;
  }

  static String? _controlModeForSetupMode(String mode) {
    if (mode == setupModeAi) {
      return Faction.controlComputer;
    }
    if (mode == setupModeHotseat) {
      return Faction.controlLocal;
    }
    if (mode == setupModeAsync) {
      return Faction.controlRemote;
    }
    return null;
  }

  static String _setupModeLabelFor(String mode) {
    if (mode == setupModeAi) {
      return 'AI Opponents';
    }
    if (mode == setupModeHotseat) {
      return 'Hotseat';
    }
    if (mode == setupModeAsync) {
      return 'Async Multiplayer';
    }
    if (mode == setupModeCustom) {
      return 'Custom Seats';
    }
    return mode;
  }

  String _setupModeDescriptionFor(String mode) {
    if (mode == setupModeAi) {
      return 'Rival factions run computer turns.';
    }
    if (mode == setupModeHotseat) {
      return 'Rival factions are local seats on this device.';
    }
    if (mode == setupModeAsync) {
      return 'Rival factions wait for invite and order packages.';
    }
    return 'Use each faction Seat dropdown.';
  }

  List<Widget> _factionReadouts(
    String raceId,
    String primaryTrait,
    String secondaryTrait,
  ) {
    return <Widget>[
      _SetupReadout(
        label: 'Race',
        value: GameSetup.raceDescriptionFor(raceId),
      ),
      _SetupReadout(
        label: 'Effects',
        value: GameSetup.raceEffectSummaryFor(raceId),
      ),
      _SetupReadout(
        label: 'Abilities',
        value: GameSetup.traitEffectSummaryFor(
          <String>[primaryTrait, secondaryTrait],
        ),
      ),
    ];
  }
}

class _SetupPanel extends StatelessWidget {
  const _SetupPanel({
    Key? key,
    required this.title,
    required this.icon,
    required this.children,
  }) : super(key: key);

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF202B34),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFFE9EEF2), size: 19),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFF4F7FA),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SetupDropdown extends StatelessWidget {
  const _SetupDropdown({
    Key? key,
    required this.label,
    required this.value,
    required this.items,
    required this.labelFor,
    required this.onChanged,
  }) : super(key: key);

  final String label;
  final String value;
  final List<String> items;
  final String Function(String value) labelFor;
  final void Function(String value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9FB0BE),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF202B34),
              iconEnabledColor: const Color(0xFFE9EEF2),
              style: const TextStyle(color: Color(0xFFE9EEF2)),
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(labelFor(item)),
                );
              }).toList(),
              onChanged: (selected) {
                if (selected == null) {
                  return;
                }
                onChanged(selected);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _RaceDropdown extends StatelessWidget {
  const _RaceDropdown({
    Key? key,
    required this.label,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  final String label;
  final String value;
  final void Function(String value) onChanged;

  @override
  Widget build(BuildContext context) {
    return _SetupDropdown(
      label: label,
      value: value,
      items: GameSetup.raceOptions(),
      labelFor: GameSetup.raceLabelFor,
      onChanged: onChanged,
    );
  }
}

class _PersonalityDropdown extends StatelessWidget {
  const _PersonalityDropdown({
    Key? key,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  final String value;
  final void Function(String value) onChanged;

  @override
  Widget build(BuildContext context) {
    return _SetupDropdown(
      label: 'Profile',
      value: value,
      items: Faction.aiPersonalities,
      labelFor: Faction.aiPersonalityLabelFor,
      onChanged: onChanged,
    );
  }
}

class _TraitDropdown extends StatelessWidget {
  const _TraitDropdown({
    Key? key,
    required this.label,
    required this.value,
    required this.blockedTraitId,
    required this.onChanged,
  }) : super(key: key);

  final String label;
  final String value;
  final String blockedTraitId;
  final void Function(String value) onChanged;

  @override
  Widget build(BuildContext context) {
    final items = GameSetup.traitOptions().where((traitId) {
      return traitId == value || traitId != blockedTraitId;
    }).toList();

    return _SetupDropdown(
      label: label,
      value: value,
      items: items,
      labelFor: GameSetup.traitLabelFor,
      onChanged: onChanged,
    );
  }
}

class _SeedField extends StatelessWidget {
  const _SeedField({
    Key? key,
    required this.controller,
    required this.onRoll,
  }) : super(key: key);

  final TextEditingController controller;
  final VoidCallback onRoll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(
            width: 92,
            child: Text(
              'Seed',
              style: TextStyle(
                color: Color(0xFF9FB0BE),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              key: const ValueKey<String>('world-seed-field'),
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: const TextStyle(color: Color(0xFFE9EEF2)),
              decoration: const InputDecoration(
                isDense: true,
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF55616C)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFCCD6A6)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Roll Seed',
            icon: const Icon(Icons.casino),
            color: const Color(0xFFE9EEF2),
            onPressed: onRoll,
          ),
        ],
      ),
    );
  }
}

class _SetupReadout extends StatelessWidget {
  const _SetupReadout({
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
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF9FB0BE),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              softWrap: true,
              style: const TextStyle(color: Color(0xFFE9EEF2)),
            ),
          ),
        ],
      ),
    );
  }
}
