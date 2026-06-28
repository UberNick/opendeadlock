import 'dart:convert';

import 'package:OpenDeadlock/game/game_codec.dart';
import 'package:OpenDeadlock/game/game_replay.dart';
import 'package:OpenDeadlock/game/game_saves.dart';
import 'package:OpenDeadlock/game/game_setup.dart';
import 'package:OpenDeadlock/game/game_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('sample game starts with a selected-player colony', () {
    final game = OpenDeadlockGame.sample();

    expect(game.turn, 1);
    expect(game.width, 8);
    expect(game.height, 6);
    expect(game.activeFaction.name, 'Human Assembly');
    expect(game.colonyAt(2, 2)!.name, 'New Haven');
    expect(game.unitAt(3, 1)!.name, 'Survey Team');
    expect(game.unitById('human-scout').movesRemaining,
        OpenDeadlockGame.maxMovesFor('scout'));
    expect(game.activeFaction.raceId, 'human');
    expect(game.factionById('rebels')!.raceId, 'tarth');
    expect(game.activeFaction.controlMode, Faction.controlLocal);
    expect(game.factionById('rebels')!.controlMode, Faction.controlComputer);
    expect(game.activeFaction.difficulty, Faction.difficultyNormal);
    expect(game.factionById('rebels')!.difficulty, Faction.difficultyNormal);
    expect(game.areAtWar('humans', 'rebels'), isTrue);
    expect(game.sessionId, 'sample-skirmish');
  });

  test('endTurn advances production and stores a report', () {
    final game = OpenDeadlockGame.sample();
    final next = game.endTurn();

    expect(next.turn, 2);
    expect(next.activeFaction.resources.food,
        greaterThan(game.activeFaction.resources.food));
    expect(next.activeFaction.resources.industry,
        greaterThan(game.activeFaction.resources.industry));
    expect(next.activeFaction.resources.research,
        greaterThan(game.activeFaction.resources.research));
    expect(next.reports.first.title, 'Turn 2 begins');
  });

  test('game state can round-trip through json', () {
    final game = OpenDeadlockGame.sample()
        .applyCommand(
          const SetColonyFocusCommand(
            factionId: 'humans',
            colonyId: 'new-haven',
            focus: OpenDeadlockGame.colonyFocusIndustry,
          ),
        )
        .applyCommand(
          const SetColonySectorAssignmentCommand(
            factionId: 'humans',
            colonyId: 'new-haven',
            x: 2,
            y: 1,
            assigned: true,
          ),
        )
        .endTurn();
    final restored = OpenDeadlockGame.fromJson(game.toJson());

    expect(restored.turn, game.turn);
    expect(restored.sessionId, game.sessionId);
    expect(restored.activeFaction.resources.food,
        game.activeFaction.resources.food);
    expect(restored.tiles.length, game.tiles.length);
    expect(restored.colonies.first.storedIndustry,
        game.colonies.first.storedIndustry);
    expect(restored.colonies.first.completedBuildings,
        game.colonies.first.completedBuildings);
    expect(restored.colonies.first.focus, game.colonies.first.focus);
    expect(restored.colonies.first.assignedSectors.length,
        game.colonies.first.assignedSectors.length);
    expect(
        restored.units.first.movesRemaining, game.units.first.movesRemaining);
    expect(restored.units.first.health, game.units.first.health);
    expect(restored.tileAt(2, 2).exploredBy, game.tileAt(2, 2).exploredBy);
    expect(restored.activeFaction.researchProject,
        game.activeFaction.researchProject);
    expect(restored.activeFaction.completedResearch,
        game.activeFaction.completedResearch);
    expect(restored.activeFaction.traitIds, game.activeFaction.traitIds);
    expect(restored.activeFaction.controlMode, game.activeFaction.controlMode);
    expect(restored.activeFaction.difficulty, game.activeFaction.difficulty);
    expect(restored.activeFaction.taxPolicy, game.activeFaction.taxPolicy);
    expect(
        restored.activeFaction.aiPersonality, game.activeFaction.aiPersonality);
    expect(restored.diplomacy.length, game.diplomacy.length);
    expect(restored.diplomacyStatusBetween('humans', 'rebels'),
        game.diplomacyStatusBetween('humans', 'rebels'));
    expect(restored.commandHistory.length, game.commandHistory.length);
    expect(restored.reports.first.title, game.reports.first.title);
  });

  test('preferred assignable sectors fill open colony work slots', () {
    final game = OpenDeadlockGame.sample();
    final colony = game.colonyById('new-haven');
    final sectors = game.preferredAssignableSectorsFor(colony);

    expect(sectors, isNotEmpty);
    expect(sectors.length,
        lessThanOrEqualTo(OpenDeadlockGame.assignedSectorCapacityFor(colony)));
    for (final sector in sectors) {
      expect(
        game.canAssignColonySector(
          colony.id,
          sector.x,
          sector.y,
          factionId: colony.ownerId,
        ),
        isTrue,
      );
    }

    final firstSector = sectors.first;
    final assigned = game.setColonySectorAssignment(
      colony.id,
      firstSector.x,
      firstSector.y,
      true,
      factionId: colony.ownerId,
    );
    final updatedColony = assigned.colonyById(colony.id);
    final updatedSectors =
        assigned.preferredAssignableSectorsFor(updatedColony);

    expect(
      updatedSectors.any(
        (sector) => sector.x == firstSector.x && sector.y == firstSector.y,
      ),
      isFalse,
    );
    expect(updatedSectors.length, lessThan(sectors.length));
  });

  test('legacy faction json defaults to the first research project', () {
    final json = OpenDeadlockGame.sample().toJson();
    final factions = json['factions'] as List<dynamic>;
    for (final factionJson in factions.cast<Map<String, dynamic>>()) {
      factionJson.remove('researchProject');
      factionJson.remove('completedResearch');
      factionJson.remove('traitIds');
      factionJson.remove('raceId');
      factionJson.remove('controlMode');
      factionJson.remove('difficulty');
      factionJson.remove('taxPolicy');
      factionJson.remove('aiPersonality');
    }
    final tiles = json['tiles'] as List<dynamic>;
    for (final tileJson in tiles.cast<Map<String, dynamic>>()) {
      tileJson.remove('exploredBy');
    }
    final colonies = json['colonies'] as List<dynamic>;
    for (final colonyJson in colonies.cast<Map<String, dynamic>>()) {
      colonyJson.remove('focus');
      colonyJson.remove('assignedSectors');
    }
    json.remove('diplomacy');
    json.remove('sessionId');
    final restored = OpenDeadlockGame.fromJson(json);

    expect(restored.sessionId, 'legacy-8-6-humans-rebels');
    expect(restored.activeFaction.researchProject, 'Hydroponics');
    expect(restored.activeFaction.completedResearch, isEmpty);
    expect(restored.activeFaction.traitIds, isEmpty);
    expect(restored.activeFaction.raceId, 'human');
    expect(restored.activeFaction.controlMode, Faction.controlLocal);
    expect(restored.activeFaction.difficulty, Faction.difficultyNormal);
    expect(
        restored.factionById('rebels')!.controlMode, Faction.controlComputer);
    expect(
        restored.factionById('rebels')!.difficulty, Faction.difficultyNormal);
    expect(restored.activeFaction.taxPolicy, Faction.taxPolicyBalanced);
    expect(
        restored.factionById('rebels')!.taxPolicy, Faction.taxPolicyBalanced);
    expect(restored.activeFaction.aiPersonality, Faction.aiPersonalityAdaptive);
    expect(restored.factionById('rebels')!.aiPersonality,
        Faction.aiPersonalityAdaptive);
    expect(restored.factionById('rebels')!.raceId, 'tarth');
    expect(restored.tileAt(2, 2).isExploredBy('humans'), isTrue);
    expect(restored.colonyById('new-haven').focus,
        OpenDeadlockGame.colonyFocusBalanced);
    expect(restored.colonyById('new-haven').assignedSectors, isEmpty);
    expect(restored.diplomacy, isEmpty);
    expect(restored.areAtWar('humans', 'rebels'), isTrue);
  });

  test('game setup can round-trip and build a configured new game', () {
    const setup = GameSetup(
      mapSize: GameSetup.mapSizeFrontier,
      planetType: GameSetup.planetTypeAncient,
      factions: <GameSetupFaction>[
        GameSetupFaction(
          id: 'humans',
          name: 'Human',
          colorValue: 0xFF2F80ED,
          raceId: 'human',
          controlMode: Faction.controlLocal,
          difficulty: Faction.difficultyNormal,
          aiPersonality: Faction.aiPersonalityResearcher,
          traitIds: <String>['agrarian', 'scholars'],
        ),
        GameSetupFaction(
          id: 'rebels',
          name: 'Tarth',
          colorValue: 0xFFB83232,
          raceId: 'tarth',
          controlMode: Faction.controlComputer,
          difficulty: Faction.difficultyHard,
          aiPersonality: Faction.aiPersonalityConqueror,
          traitIds: <String>['industrialists', 'militarists'],
        ),
        GameSetupFaction(
          id: 'traders',
          name: "Re'Lu",
          colorValue: 0xFFD9A441,
          raceId: 'relu',
          controlMode: Faction.controlRemote,
          difficulty: Faction.difficultyEasy,
          aiPersonality: Faction.aiPersonalityTrader,
          traitIds: <String>['agrarian', 'traders'],
        ),
        GameSetupFaction(
          id: 'maug',
          name: 'Maug',
          colorValue: 0xFF7D5FB2,
          raceId: 'maug',
          controlMode: Faction.controlComputer,
          difficulty: Faction.difficultyNormal,
          aiPersonality: Faction.aiPersonalityResearcher,
          traitIds: <String>['scholars', 'industrialists'],
        ),
      ],
    );
    final restored = GameSetup.fromJson(setup.toJson());
    final game = restored.buildGame();

    expect(restored.mapSize, GameSetup.mapSizeFrontier);
    expect(restored.planetType, GameSetup.planetTypeAncient);
    expect(GameSetup.traitLabelFor('agrarian'), 'Agrarian');
    expect(GameSetup.raceLabelFor('relu'), "Re'Lu");
    expect(
      GameSetup.raceDescriptionFor('relu'),
      'Secretive scouts with broad planetary awareness.',
    );
    expect(
      GameSetup.raceEffectSummaryFor('relu'),
      '+1 research per colony; reveals full map; prefers Scout Patrol; '
      'prioritizes Xenoarchaeology.',
    );
    expect(
      GameSetup.traitEffectSummaryFor(<String>['scholars', 'traders']),
      'Scholars: +1 research per colony; prefers Research Lab; '
      'prioritizes Xenoarchaeology. Traders: +2 credits per colony; '
      'prioritizes Future Studies.',
    );
    expect(GameSetup.mapSizeLabelFor(restored.mapSize), 'Frontier');
    expect(GameSetup.planetTypeLabelFor(restored.planetType), 'Ancient Ruins');
    expect(GameSetup.sectorCountFor(restored.mapSize), 96);
    expect(
      GameSetup.mapSizeSummaryFor(restored.mapSize),
      '12 x 8 sectors (96 total)',
    );
    expect(
      GameSetup.planetTypeDescriptionFor(restored.planetType),
      'Ruins-heavy world. Every sector gains +1 research.',
    );
    expect(game.width, 12);
    expect(game.height, 8);
    expect(game.sessionId, 'setup-frontier-ancient-humans-rebels-traders-maug');
    expect(game.tileAt(0, 0).terrain, 'ruins');
    expect(game.tileAt(0, 0).yields.research, 4);
    expect(game.activeFactionId, 'humans');
    expect(game.factions.length, 4);
    expect(
        game.factionById('humans')!.traitIds, <String>['agrarian', 'scholars']);
    expect(game.factionById('humans')!.raceId, 'human');
    expect(game.factionById('rebels')!.raceId, 'tarth');
    expect(game.factionById('traders')!.raceId, 'relu');
    expect(game.factionById('maug')!.raceId, 'maug');
    expect(game.factionById('rebels')!.difficulty, Faction.difficultyHard);
    expect(game.factionById('rebels')!.aiPersonality,
        Faction.aiPersonalityConqueror);
    expect(game.factionById('traders')!.aiPersonality,
        Faction.aiPersonalityTrader);
    expect(game.factionById('traders')!.isRemote, isTrue);
    expect(game.factionById('maug')!.isComputer, isTrue);
    expect(game.colonies.length, 4);
    expect(game.units.length, 4);
    expect(game.diplomacy.length, 6);
    expect(game.areAtWar('humans', 'rebels'), isTrue);
    expect(game.areAtWar('humans', 'traders'), isTrue);
    expect(game.areAtWar('humans', 'maug'), isTrue);
    expect(game.areAtWar('rebels', 'traders'), isTrue);
    expect(game.areAtWar('traders', 'maug'), isTrue);
    expect(game.commandHistory, isEmpty);
    expect(game.reports.first.title, 'Planetfall complete');

    final traderCapital = game.colonyById('traders-capital');
    expect(game.tileAt(traderCapital.x, traderCapital.y).ownerId, 'traders');
    expect(
        game.tileAt(traderCapital.x, traderCapital.y).isExploredBy('traders'),
        isTrue);
    expect(game.tiles.every((tile) => tile.isExploredBy('traders')), isTrue);
    expect(game.worldSummaryFor('traders').exploredSectors, game.tiles.length);
  });

  test('game setup world seed changes generated terrain deterministically', () {
    final base = GameSetup.standard();
    final classic = base.buildGame(sessionId: 'classic');
    final seededSetup = GameSetup(
      mapSize: base.mapSize,
      planetType: base.planetType,
      worldSeed: 7,
      factions: base.factions,
    );
    final restoredSetup = GameSetup.fromJson(seededSetup.toJson());
    final seededA = restoredSetup.buildGame();
    final seededB = restoredSetup.buildGame();

    String terrainSignature(OpenDeadlockGame game) {
      return game.tiles.map((tile) => tile.terrain).join('|');
    }

    expect(restoredSetup.worldSeed, 7);
    expect(seededA.sessionId, 'setup-standard-terran-seed7-humans-rebels');
    expect(terrainSignature(seededA), terrainSignature(seededB));
    expect(terrainSignature(seededA), isNot(terrainSignature(classic)));
    expect(seededA.tileAt(0, 0).terrain, 'ridge');
    for (final colony in seededA.colonies) {
      expect(seededA.tileAt(colony.x, colony.y).terrain, isNot('water'));
    }
  });

  test('game setup can start factions at peace or alliance', () {
    const peaceSetup = GameSetup(
      mapSize: GameSetup.mapSizeStandard,
      planetType: GameSetup.planetTypeTerran,
      startingDiplomacy: OpenDeadlockGame.diplomacyStatusPeace,
      factions: <GameSetupFaction>[
        GameSetupFaction(
          id: 'humans',
          name: 'Human',
          colorValue: 0xFF2F80ED,
          raceId: 'human',
          controlMode: Faction.controlLocal,
          difficulty: Faction.difficultyNormal,
          traitIds: <String>['scholars'],
        ),
        GameSetupFaction(
          id: 'rebels',
          name: 'Tarth',
          colorValue: 0xFFB83232,
          raceId: 'tarth',
          controlMode: Faction.controlComputer,
          difficulty: Faction.difficultyNormal,
          traitIds: <String>['militarists'],
        ),
      ],
    );
    final restoredPeace = GameSetup.fromJson(peaceSetup.toJson());
    final peaceGame = restoredPeace.buildGame();

    expect(
        restoredPeace.startingDiplomacy, OpenDeadlockGame.diplomacyStatusPeace);
    expect(GameSetup.startingDiplomacyLabelFor(restoredPeace.startingDiplomacy),
        'Peace');
    expect(
      GameSetup.startingDiplomacyDescriptionFor(
        restoredPeace.startingDiplomacy,
      ),
      'All factions begin at peace and may trade.',
    );
    expect(peaceGame.sessionId, 'setup-standard-terran-peace-humans-rebels');
    expect(peaceGame.diplomacyStatusBetween('humans', 'rebels'),
        OpenDeadlockGame.diplomacyStatusPeace);
    expect(peaceGame.areAtWar('humans', 'rebels'), isFalse);
    expect(peaceGame.reports.first.message,
        contains('Starting relations: Peace.'));

    final allianceGame = GameSetup(
      mapSize: peaceSetup.mapSize,
      planetType: peaceSetup.planetType,
      startingDiplomacy: OpenDeadlockGame.diplomacyStatusAlliance,
      factions: peaceSetup.factions,
    ).buildGame();

    expect(
        allianceGame.sessionId, 'setup-standard-terran-alliance-humans-rebels');
    expect(allianceGame.areAllied('humans', 'rebels'), isTrue);
  });

  test('game setup rejects invalid generated games', () {
    expect(
      () => const GameSetup(
        mapSize: 'tiny',
        planetType: GameSetup.planetTypeTerran,
        factions: <GameSetupFaction>[],
      ).buildGame(),
      throwsArgumentError,
    );
    expect(
      () => const GameSetup(
        mapSize: GameSetup.mapSizeStandard,
        planetType: GameSetup.planetTypeTerran,
        worldSeed: -1,
        factions: <GameSetupFaction>[],
      ).buildGame(),
      throwsArgumentError,
    );
    expect(
      () => const GameSetup(
        mapSize: GameSetup.mapSizeStandard,
        planetType: 'gas',
        factions: <GameSetupFaction>[],
      ).buildGame(),
      throwsArgumentError,
    );
    expect(
      () => const GameSetup(
        mapSize: GameSetup.mapSizeStandard,
        planetType: GameSetup.planetTypeTerran,
        startingDiplomacy: 'vendetta',
        factions: <GameSetupFaction>[
          GameSetupFaction(
            id: 'humans',
            name: 'The Chosen',
            colorValue: 0xFF2F80ED,
            raceId: 'human',
            controlMode: Faction.controlLocal,
            difficulty: Faction.difficultyNormal,
            traitIds: <String>[],
          ),
          GameSetupFaction(
            id: 'rebels',
            name: 'Crimson Pact',
            colorValue: 0xFFB83232,
            raceId: 'tarth',
            controlMode: Faction.controlComputer,
            difficulty: Faction.difficultyNormal,
            traitIds: <String>['industrialists'],
          ),
        ],
      ).buildGame(),
      throwsArgumentError,
    );
    expect(
      () => const GameSetup(
        mapSize: GameSetup.mapSizeStandard,
        planetType: GameSetup.planetTypeTerran,
        factions: <GameSetupFaction>[
          GameSetupFaction(
            id: 'humans',
            name: 'The Chosen',
            colorValue: 0xFF2F80ED,
            raceId: 'human',
            controlMode: Faction.controlLocal,
            difficulty: Faction.difficultyNormal,
            traitIds: <String>[],
          ),
        ],
      ).buildGame(),
      throwsArgumentError,
    );
    expect(
      () => const GameSetup(
        mapSize: GameSetup.mapSizeStandard,
        planetType: GameSetup.planetTypeTerran,
        factions: <GameSetupFaction>[
          GameSetupFaction(
            id: 'humans',
            name: 'The Chosen',
            colorValue: 0xFF2F80ED,
            raceId: 'human',
            controlMode: Faction.controlLocal,
            difficulty: Faction.difficultyNormal,
            traitIds: <String>[],
          ),
          GameSetupFaction(
            id: 'humans',
            name: 'Duplicate',
            colorValue: 0xFFB83232,
            raceId: 'tarth',
            controlMode: Faction.controlComputer,
            difficulty: Faction.difficultyNormal,
            traitIds: <String>[],
          ),
        ],
      ).buildGame(),
      throwsArgumentError,
    );
    expect(
      () => const GameSetup(
        mapSize: GameSetup.mapSizeStandard,
        planetType: GameSetup.planetTypeTerran,
        factions: <GameSetupFaction>[
          GameSetupFaction(
            id: 'humans',
            name: 'The Chosen',
            colorValue: 0xFF2F80ED,
            raceId: 'human',
            controlMode: Faction.controlLocal,
            difficulty: Faction.difficultyNormal,
            traitIds: <String>['scholars', 'scholars'],
          ),
          GameSetupFaction(
            id: 'rebels',
            name: 'Crimson Pact',
            colorValue: 0xFFB83232,
            raceId: 'tarth',
            controlMode: Faction.controlComputer,
            difficulty: Faction.difficultyNormal,
            traitIds: <String>['industrialists'],
          ),
        ],
      ).buildGame(),
      throwsArgumentError,
    );
    expect(
      () => const GameSetup(
        mapSize: GameSetup.mapSizeStandard,
        planetType: GameSetup.planetTypeTerran,
        factions: <GameSetupFaction>[
          GameSetupFaction(
            id: 'humans',
            name: 'The Chosen',
            colorValue: 0xFF2F80ED,
            raceId: 'human',
            controlMode: Faction.controlLocal,
            difficulty: Faction.difficultyNormal,
            traitIds: <String>['unknown'],
          ),
          GameSetupFaction(
            id: 'rebels',
            name: 'Crimson Pact',
            colorValue: 0xFFB83232,
            raceId: 'tarth',
            controlMode: Faction.controlComputer,
            difficulty: Faction.difficultyNormal,
            traitIds: <String>['industrialists'],
          ),
        ],
      ).buildGame(),
      throwsArgumentError,
    );
    expect(
      () => const GameSetup(
        mapSize: GameSetup.mapSizeStandard,
        planetType: GameSetup.planetTypeTerran,
        factions: <GameSetupFaction>[
          GameSetupFaction(
            id: 'humans',
            name: 'The Chosen',
            colorValue: 0xFF2F80ED,
            raceId: 'unknown',
            controlMode: Faction.controlLocal,
            difficulty: Faction.difficultyNormal,
            traitIds: <String>[],
          ),
          GameSetupFaction(
            id: 'rebels',
            name: 'Crimson Pact',
            colorValue: 0xFFB83232,
            raceId: 'tarth',
            controlMode: Faction.controlComputer,
            difficulty: Faction.difficultyNormal,
            traitIds: <String>['industrialists'],
          ),
        ],
      ).buildGame(),
      throwsArgumentError,
    );
    expect(
      () => const GameSetup(
        mapSize: GameSetup.mapSizeStandard,
        planetType: GameSetup.planetTypeTerran,
        factions: <GameSetupFaction>[
          GameSetupFaction(
            id: 'humans',
            name: 'The Chosen',
            colorValue: 0xFF2F80ED,
            raceId: 'human',
            controlMode: Faction.controlLocal,
            difficulty: Faction.difficultyNormal,
            traitIds: <String>[],
          ),
          GameSetupFaction(
            id: 'rebels',
            name: 'Crimson Pact',
            colorValue: 0xFFB83232,
            raceId: 'tarth',
            controlMode: Faction.controlComputer,
            difficulty: Faction.difficultyNormal,
            aiPersonality: 'erratic',
            traitIds: <String>['industrialists'],
          ),
        ],
      ).buildGame(),
      throwsArgumentError,
    );
  });

  test('game snapshots can round-trip through versioned codec', () {
    final game = OpenDeadlockGame.sample().applyCommand(
      const EndTurnCommand(factionId: 'humans'),
    );
    final encoded = GameCodec.encodeGame(game);
    final root = jsonDecode(encoded) as Map<String, dynamic>;
    final restored = GameCodec.decodeGame(GameCodec.encodeGame(game));

    expect(root['kind'], GameCodec.snapshotKind);
    expect(root['commandCount'], game.commandHistory.length);
    expect(restored.turn, game.turn);
    expect(restored.colonyAt(6, 3)!.construction, 'Barracks');
    expect(restored.commandHistory.length, game.commandHistory.length);
    expect(
        restored.commandHistory.first.command.type, EndTurnCommand.commandType);
    expect(restored.reports.first.title, game.reports.first.title);
  });

  test('turn reports can round-trip battle metadata', () {
    const report = TurnReport(
      title: 'Survey Team attacked Pact Recon',
      message: 'Survey Team dealt 2 damage.',
      category: TurnReport.categoryBattle,
      details: <String, String>{
        'kind': 'unit',
        'attackerId': 'human-scout',
        'defenderId': 'rebel-scout',
        'attackDamage': '2',
      },
    );
    final restored = TurnReport.fromJson(report.toJson());

    expect(restored.isBattle, isTrue);
    expect(restored.category, TurnReport.categoryBattle);
    expect(restored.details['kind'], 'unit');
    expect(restored.details['attackDamage'], '2');
  });

  test('save slots encode metadata with a restorable snapshot', () {
    final game = OpenDeadlockGame.sample().applyCommand(
      const EndTurnCommand(factionId: 'humans'),
    );
    final updatedAt = DateTime.utc(2026, 6, 28, 2, 55);
    final slot = GameSaveArchive.slotFromGame(
      game,
      slotId: 'mobile',
      name: 'Phone campaign',
      updatedAt: updatedAt,
    );
    final restored =
        GameSaveArchive.decodeSlot(GameSaveArchive.encodeSlot(slot));
    final restoredGame = restored.decodeGame();

    expect(restored.slotId, 'mobile');
    expect(restored.name, 'Phone campaign');
    expect(restored.sessionId, game.sessionId);
    expect(restored.updatedAtIso8601, '2026-06-28T02:55:00.000Z');
    expect(restored.turn, game.turn);
    expect(restored.activeFactionName, game.activeFaction.name);
    expect(restored.commandCount, game.commandHistory.length);
    expect(restored.stateFingerprint, GameCodec.fingerprintGame(game));
    expect(GameReplay.hasSameState(restoredGame, game), isTrue);
  });

  test('local save store persists, orders, loads, and deletes save slots',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final store = GameSaveStore(preferences);
    final firstGame = OpenDeadlockGame.sample();
    final secondGame = firstGame.applyCommand(
      const EndTurnCommand(factionId: 'humans'),
    );
    final manualSlotId = GameSaveStore.createManualSlotId(
      now: DateTime.utc(2026, 6, 28, 2, 49),
    );

    await store.saveGame(
      firstGame,
      slotId: manualSlotId,
      updatedAt: DateTime.utc(2026, 6, 28, 2, 50),
    );
    await store.saveGame(
      secondGame,
      slotId: 'second',
      updatedAt: DateTime.utc(2026, 6, 28, 3),
    );
    final slots = await store.loadSlots();
    final loadedGame = await store.loadGame('second');
    final removed = await store.deleteSlot(manualSlotId);
    final remainingSlots = await store.loadSlots();

    expect(
        manualSlotId.startsWith('${GameSaveStore.manualSlotPrefix}-'), isTrue);
    expect(slots.map((slot) => slot.slotId), <String>[
      'second',
      manualSlotId,
    ]);
    expect(slots.first.name, 'Turn 2 - Human Assembly');
    expect(loadedGame, isNotNull);
    expect(GameReplay.hasSameState(loadedGame!, secondGame), isTrue);
    expect(removed, isTrue);
    expect(remainingSlots.map((slot) => slot.slotId), <String>['second']);
  });

  test('autosave slot is replaced and can be loaded as the latest game',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final store = GameSaveStore(preferences);
    final firstGame = OpenDeadlockGame.sample();
    final secondGame = firstGame.applyCommand(
      const EndTurnCommand(factionId: 'humans'),
    );

    await store.saveGame(
      firstGame,
      slotId: GameSaveStore.autosaveSlotId,
      updatedAt: DateTime.utc(2026, 6, 28, 3, 10),
    );
    await store.saveGame(
      secondGame,
      slotId: GameSaveStore.autosaveSlotId,
      updatedAt: DateTime.utc(2026, 6, 28, 3, 11),
    );
    final slots = await store.loadSlots();
    final latestSlot = await store.loadLatestSlot();
    final latestGame = await store.loadLatestGame();

    expect(slots.length, 1);
    expect(slots.single.slotId, GameSaveStore.autosaveSlotId);
    expect(slots.single.commandCount, secondGame.commandHistory.length);
    expect(latestSlot!.stateFingerprint, GameCodec.fingerprintGame(secondGame));
    expect(latestGame, isNotNull);
    expect(GameReplay.hasSameState(latestGame!, secondGame), isTrue);
  });

  test('colony projects complete into persistent buildings', () {
    final game = OpenDeadlockGame.sample().endTurn().endTurn();
    final colony = game.colonyAt(2, 2)!;

    expect(colony.completedBuildings, contains('Colony Hub'));
    expect(colony.construction, 'Research Lab');
    expect(colony.storedIndustry, 1);
    expect(game.reports.first.title, 'New Haven: Colony Hub completed');
  });

  test('scout patrol completion creates a new scout unit', () {
    final queued = OpenDeadlockGame.sample().applyCommand(
      const SetColonyConstructionCommand(
        factionId: 'humans',
        colonyId: 'new-haven',
        construction: 'Scout Patrol',
      ),
    );
    final game = queued.endTurn().endTurn().endTurn();
    final scout = game.unitAt(2, 2);

    expect(scout, isNotNull);
    expect(scout!.ownerId, 'humans');
    expect(scout.type, 'scout');
    expect(scout.movesRemaining, OpenDeadlockGame.maxMovesFor('scout'));
    expect(game.colonyAt(2, 2)!.construction, 'Scout Patrol');
    expect(game.colonyAt(2, 2)!.completedBuildings,
        isNot(contains('Scout Patrol')));
    expect(game.reports.first.title, 'New Haven: Scout Patrol completed');
  });

  test('infantry company completion creates a new infantry unit', () {
    final sample = OpenDeadlockGame.sample();
    final ready = sample.copyWith(
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'new-haven') {
          return colony;
        }
        return colony.copyWith(
          construction: 'Infantry Company',
          storedIndustry: OpenDeadlockGame.buildCostFor('Infantry Company') - 1,
          completedBuildings: const <String>['Barracks'],
        );
      }).toList(),
    );
    final game = ready.endTurn();
    final infantry = game.unitAt(2, 2);

    expect(infantry, isNotNull);
    expect(infantry!.ownerId, 'humans');
    expect(infantry.type, 'infantry');
    expect(infantry.health, OpenDeadlockGame.maxHealthFor('infantry'));
    expect(infantry.movesRemaining, 1);
    expect(game.colonyAt(2, 2)!.construction, 'Infantry Company');
    expect(game.colonyAt(2, 2)!.completedBuildings,
        isNot(contains('Infantry Company')));
    expect(game.reports.first.title, 'New Haven: Infantry Company completed');
  });

  test('armor company completion creates a new armor unit', () {
    final sample = OpenDeadlockGame.sample();
    final ready = sample.copyWith(
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'new-haven') {
          return colony;
        }
        return colony.copyWith(
          construction: 'Armor Company',
          storedIndustry: OpenDeadlockGame.buildCostFor('Armor Company') - 1,
          completedBuildings: const <String>['Barracks', 'Factory'],
        );
      }).toList(),
    );
    final game = ready.endTurn();
    final armor = game.unitAt(2, 2);

    expect(armor, isNotNull);
    expect(armor!.ownerId, 'humans');
    expect(armor.type, 'armor');
    expect(armor.health, OpenDeadlockGame.maxHealthFor('armor'));
    expect(armor.movesRemaining, OpenDeadlockGame.maxMovesFor('armor'));
    expect(OpenDeadlockGame.attackFor('armor'), 6);
    expect(OpenDeadlockGame.defenseFor('armor'), 3);
    expect(game.colonyAt(2, 2)!.construction, 'Armor Company');
    expect(game.colonyAt(2, 2)!.completedBuildings,
        isNot(contains('Armor Company')));
    expect(game.reports.first.title, 'New Haven: Armor Company completed');
  });

  test('movement rules expose unit allowances and terrain costs', () {
    expect(OpenDeadlockGame.maxMovesFor('scout'), 2);
    expect(OpenDeadlockGame.maxMovesFor('infantry'), 1);
    expect(OpenDeadlockGame.maxMovesFor('armor'), 1);
    expect(OpenDeadlockGame.movementCostForTerrain('plains'), 1);
    expect(OpenDeadlockGame.movementCostForTerrain('ruins'), 1);
    expect(OpenDeadlockGame.movementCostForTerrain('forest'), 2);
    expect(OpenDeadlockGame.movementCostForTerrain('ridge'), 2);
    expect(OpenDeadlockGame.isTerrainPassable('water'), isFalse);
    expect(() => OpenDeadlockGame.movementCostForTerrain('water'),
        throwsArgumentError);
  });

  test('damaged units can recover by spending movement', () {
    final sample = OpenDeadlockGame.sample();
    final damaged = sample.copyWith(
      units: sample.units.map((unit) {
        if (unit.id != 'human-scout') {
          return unit;
        }
        return unit.copyWith(health: 2);
      }).toList(),
    );
    final recovered = damaged.applyCommand(
      const RecoverUnitCommand(
        factionId: 'humans',
        unitId: 'human-scout',
      ),
    );
    final scout = recovered.unitById('human-scout');

    expect(scout.health, 3);
    expect(scout.movesRemaining, 0);
    expect(recovered.commandHistory.last.command.type,
        RecoverUnitCommand.commandType);
    expect(recovered.reports.first.title, 'Survey Team recovered');
  });

  test('unit recovery rejects invalid orders', () {
    final sample = OpenDeadlockGame.sample();
    final noMoves = sample.copyWith(
      units: sample.units.map((unit) {
        if (unit.id != 'human-scout') {
          return unit;
        }
        return unit.copyWith(health: 2, movesRemaining: 0);
      }).toList(),
    );

    expect(
      () => sample.applyCommand(
        const RecoverUnitCommand(
          factionId: 'humans',
          unitId: 'human-scout',
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => noMoves.applyCommand(
        const RecoverUnitCommand(
          factionId: 'humans',
          unitId: 'human-scout',
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => sample.recoverUnit('human-scout', factionId: 'rebels'),
      throwsArgumentError,
    );
  });

  test('player can change a colony construction order', () {
    final game = OpenDeadlockGame.sample();
    final updated = game.applyCommand(
      const SetColonyConstructionCommand(
        factionId: 'humans',
        colonyId: 'new-haven',
        construction: 'Factory',
      ),
    );

    expect(updated.colonyAt(2, 2)!.construction, 'Factory');
    expect(updated.colonyAt(2, 2)!.storedIndustry, 0);
    expect(updated.commandHistory.length, 1);
    expect(updated.commandHistory.first.factionId, 'humans');
    expect(updated.commandHistory.first.command.type,
        SetColonyConstructionCommand.commandType);
    expect(updated.reports.first.title, 'Build order changed');
  });

  test('player can spend credits to rush colony construction', () {
    final queued = OpenDeadlockGame.sample().applyCommand(
      const SetColonyConstructionCommand(
        factionId: 'humans',
        colonyId: 'new-haven',
        construction: 'Factory',
      ),
    );
    final creditsBefore = queued.factionById('humans')!.resources.credits;
    final rushed = queued.applyCommand(
      const RushConstructionCommand(
        factionId: 'humans',
        colonyId: 'new-haven',
        industry: 5,
      ),
    );

    expect(rushed.colonyById('new-haven').storedIndustry, 5);
    expect(
      rushed.factionById('humans')!.resources.credits,
      creditsBefore - OpenDeadlockGame.rushConstructionCostFor(5),
    );
    expect(rushed.commandHistory.last.command.type,
        RushConstructionCommand.commandType);
    expect(rushed.reports.first.title, 'Rush order funded');
  });

  test('player can set colony production focus', () {
    final game = OpenDeadlockGame.sample();
    final baseline = game.colonyProductionFor(game.colonyById('new-haven'));

    final industry = game.applyCommand(
      const SetColonyFocusCommand(
        factionId: 'humans',
        colonyId: 'new-haven',
        focus: OpenDeadlockGame.colonyFocusIndustry,
      ),
    );
    final colony = industry.colonyById('new-haven');
    final projection = industry.colonyProductionFor(colony);

    expect(OpenDeadlockGame.colonyFocusLabelFor(colony.focus), 'Industry');
    expect(projection.output.food, baseline.output.food - 1);
    expect(projection.output.industry, baseline.output.industry + 2);
    expect(projection.output.research, baseline.output.research);
    expect(projection.output.credits, baseline.output.credits);
    expect(projection.constructionWork, baseline.constructionWork + 2);
    expect(industry.commandHistory.last.command.type,
        SetColonyFocusCommand.commandType);
    expect(industry.reports.first.title, 'Colony focus changed');

    final revenue = game.applyCommand(
      const SetColonyFocusCommand(
        factionId: 'humans',
        colonyId: 'new-haven',
        focus: OpenDeadlockGame.colonyFocusRevenue,
      ),
    );
    final revenueProjection =
        revenue.colonyProductionFor(revenue.colonyById('new-haven'));

    expect(revenueProjection.output.research, baseline.output.research - 1);
    expect(revenueProjection.output.credits, baseline.output.credits + 3);
  });

  test('colony focus rejects unknown or hostile orders', () {
    final game = OpenDeadlockGame.sample();

    expect(
      () => game.applyCommand(
        const SetColonyFocusCommand(
          factionId: 'humans',
          colonyId: 'new-haven',
          focus: 'luxury',
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => game.setColonyFocus(
        'new-haven',
        OpenDeadlockGame.colonyFocusResearch,
        factionId: 'rebels',
      ),
      throwsArgumentError,
    );
  });

  test('player can assign controlled sectors to colony production', () {
    final game = OpenDeadlockGame.sample();
    final before = game.colonyProductionFor(game.colonyById('new-haven'));

    final assigned = game.applyCommand(
      const SetColonySectorAssignmentCommand(
        factionId: 'humans',
        colonyId: 'new-haven',
        x: 2,
        y: 1,
        assigned: true,
      ),
    );
    final colony = assigned.colonyById('new-haven');
    final projection = assigned.colonyProductionFor(colony);
    final next = assigned.endTurn();

    expect(before.workedSectors, 1);
    expect(before.workedYields.food, 2);
    expect(before.workedYields.industry, 2);
    expect(before.workedYields.research, 0);
    expect(colony.assignedSectors.length, 1);
    expect(assigned.assignedColonyForSector(2, 1)!.id, 'new-haven');
    expect(projection.workedSectors, 2);
    expect(projection.assignedSectorCapacity, 4);
    expect(projection.workedYields.food, 2);
    expect(projection.workedYields.industry, 3);
    expect(projection.workedYields.research, 3);
    expect(projection.output.food, 7);
    expect(projection.output.industry, 8);
    expect(projection.output.research, 6);
    expect(next.colonyById('new-haven').storedIndustry, 18);
    expect(assigned.commandHistory.last.command.type,
        SetColonySectorAssignmentCommand.commandType);
    expect(assigned.reports.first.title, 'Sector assigned');

    final released = assigned.applyCommand(
      const SetColonySectorAssignmentCommand(
        factionId: 'humans',
        colonyId: 'new-haven',
        x: 2,
        y: 1,
        assigned: false,
      ),
    );

    expect(released.colonyById('new-haven').assignedSectors, isEmpty);
    expect(released.assignedColonyForSector(2, 1), isNull);
    expect(released.reports.first.title, 'Sector released');
  });

  test('sector assignment rejects invalid work sectors', () {
    final game = OpenDeadlockGame.sample();
    final farClaim = game.copyWith(
      tiles: game.tiles.map((tile) {
        if (tile.x == 7 && tile.y == 5) {
          return tile.copyWith(ownerId: 'humans').revealTo('humans');
        }
        return tile;
      }).toList(),
    );

    expect(
      () => game.applyCommand(
        const SetColonySectorAssignmentCommand(
          factionId: 'humans',
          colonyId: 'new-haven',
          x: 3,
          y: 0,
          assigned: true,
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => game.applyCommand(
        const SetColonySectorAssignmentCommand(
          factionId: 'humans',
          colonyId: 'new-haven',
          x: 6,
          y: 3,
          assigned: true,
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => farClaim.applyCommand(
        const SetColonySectorAssignmentCommand(
          factionId: 'humans',
          colonyId: 'new-haven',
          x: 7,
          y: 5,
          assigned: true,
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => game.setColonySectorAssignment(
        'new-haven',
        2,
        1,
        true,
        factionId: 'rebels',
      ),
      throwsArgumentError,
    );
  });

  test('rush construction rejects invalid spending orders', () {
    final queued = OpenDeadlockGame.sample().applyCommand(
      const SetColonyConstructionCommand(
        factionId: 'humans',
        colonyId: 'new-haven',
        construction: 'Factory',
      ),
    );
    final poor = queued.copyWith(
      factions: queued.factions.map((faction) {
        if (faction.id != 'humans') {
          return faction;
        }
        return faction.copyWith(
          resources: faction.resources.copyWith(credits: 1),
        );
      }).toList(),
    );

    expect(
      () => queued.applyCommand(
        const RushConstructionCommand(
          factionId: 'humans',
          colonyId: 'new-haven',
          industry: 23,
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => poor.applyCommand(
        const RushConstructionCommand(
          factionId: 'humans',
          colonyId: 'new-haven',
          industry: 1,
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => queued.rushConstruction(
        'new-haven',
        1,
        factionId: 'rebels',
      ),
      throwsArgumentError,
    );
  });

  test('player can change a faction research project', () {
    final game = OpenDeadlockGame.sample();
    final updated = game.applyCommand(
      const SetResearchProjectCommand(
        factionId: 'humans',
        researchProject: 'Defense Grid',
      ),
    );

    expect(updated.activeFaction.researchProject, 'Defense Grid');
    expect(updated.commandHistory.length, 1);
    expect(updated.commandHistory.first.command.type,
        SetResearchProjectCommand.commandType);
    expect(updated.reports.first.title, 'Research project changed');
  });

  test('player can spend credits to fund research', () {
    final game = OpenDeadlockGame.sample();
    final creditsBefore = game.factionById('humans')!.resources.credits;
    final updated = game.applyCommand(
      const FundResearchCommand(
        factionId: 'humans',
        research: 4,
      ),
    );
    final humans = updated.factionById('humans')!;

    expect(humans.resources.research, 4);
    expect(
      humans.resources.credits,
      creditsBefore - OpenDeadlockGame.fundResearchCostFor(4),
    );
    expect(updated.commandHistory.last.command.type,
        FundResearchCommand.commandType);
    expect(updated.reports.first.title, 'Research funded');
  });

  test('fund research rejects invalid spending orders', () {
    final game = OpenDeadlockGame.sample();
    final poor = game.copyWith(
      factions: game.factions.map((faction) {
        if (faction.id != 'humans') {
          return faction;
        }
        return faction.copyWith(
          resources: faction.resources.copyWith(credits: 2),
        );
      }).toList(),
    );

    expect(
      () => game.applyCommand(
        const FundResearchCommand(
          factionId: 'humans',
          research: 11,
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => poor.applyCommand(
        const FundResearchCommand(
          factionId: 'humans',
          research: 1,
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => game.fundResearch('missing', 1),
      throwsArgumentError,
    );
  });

  test('player can change faction control mode', () {
    final game = OpenDeadlockGame.sample();
    final updated = game.applyCommand(
      const SetFactionControlCommand(
        factionId: 'rebels',
        controlMode: Faction.controlRemote,
      ),
    );

    expect(updated.factionById('rebels')!.isRemote, isTrue);
    expect(updated.factionById('rebels')!.isComputer, isFalse);
    expect(updated.commandHistory.length, 1);
    expect(updated.commandHistory.first.command.type,
        SetFactionControlCommand.commandType);
    expect(updated.reports.first.title, 'Faction control changed');
  });

  test('player can change faction difficulty', () {
    final game = OpenDeadlockGame.sample();
    final updated = game.applyCommand(
      const SetFactionDifficultyCommand(
        factionId: 'rebels',
        difficulty: Faction.difficultyHard,
      ),
    );

    expect(updated.factionById('rebels')!.difficulty, Faction.difficultyHard);
    expect(updated.commandHistory.length, 1);
    expect(updated.commandHistory.first.command.type,
        SetFactionDifficultyCommand.commandType);
    expect(updated.reports.first.title, 'Faction difficulty changed');
  });

  test('player can change faction tax policy', () {
    final game = OpenDeadlockGame.sample();
    final baseline = game.colonyProductionFor(game.colonyById('new-haven'));
    final updated = game.applyCommand(
      const SetFactionTaxPolicyCommand(
        factionId: 'humans',
        taxPolicy: Faction.taxPolicyHigh,
      ),
    );
    final projection = updated.colonyProductionFor(
      updated.colonyById('new-haven'),
    );
    final next = updated.endTurn();

    expect(updated.activeFaction.taxPolicy, Faction.taxPolicyHigh);
    expect(projection.output.credits, baseline.output.credits + 3);
    expect(projection.moraleChange, baseline.moraleChange - 2);
    expect(next.colonyById('new-haven').morale,
        game.colonyById('new-haven').morale - 2);
    expect(
        next.factionById('humans')!.resources.credits,
        game.factionById('humans')!.resources.credits +
            projection.output.credits);
    expect(updated.commandHistory.first.command.type,
        SetFactionTaxPolicyCommand.commandType);
    expect(updated.reports.first.title, 'Tax policy changed');
  });

  test('tax policy rejects unknown policies', () {
    final game = OpenDeadlockGame.sample();

    expect(
      () => game.applyCommand(
        const SetFactionTaxPolicyCommand(
          factionId: 'humans',
          taxPolicy: 'confiscation',
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => game.applyCommand(
        const SetFactionTaxPolicyCommand(
          factionId: 'missing',
          taxPolicy: Faction.taxPolicyRelief,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('player can change diplomacy status', () {
    final game = OpenDeadlockGame.sample();
    final updated = game.applyCommand(
      const SetDiplomacyStatusCommand(
        factionId: 'humans',
        targetFactionId: 'rebels',
        status: OpenDeadlockGame.diplomacyStatusPeace,
      ),
    );

    expect(updated.areAtWar('humans', 'rebels'), isFalse);
    expect(updated.diplomacyStatusBetween('rebels', 'humans'),
        OpenDeadlockGame.diplomacyStatusPeace);
    expect(updated.commandHistory.length, 1);
    expect(updated.commandHistory.first.command.type,
        SetDiplomacyStatusCommand.commandType);
    expect(updated.reports.first.title, 'Diplomacy changed');

    final war = updated.applyCommand(
      const SetDiplomacyStatusCommand(
        factionId: 'humans',
        targetFactionId: 'rebels',
        status: OpenDeadlockGame.diplomacyStatusWar,
      ),
    );

    expect(war.areAtWar('humans', 'rebels'), isTrue);
    expect(war.commandHistory.length, 2);

    final alliance = war.applyCommand(
      const SetDiplomacyStatusCommand(
        factionId: 'humans',
        targetFactionId: 'rebels',
        status: OpenDeadlockGame.diplomacyStatusAlliance,
      ),
    );

    expect(war.tileAt(6, 3).isExploredBy('humans'), isFalse);
    expect(war.tileAt(2, 2).isExploredBy('rebels'), isFalse);
    expect(alliance.areAtWar('humans', 'rebels'), isFalse);
    expect(alliance.diplomacyStatusBetween('humans', 'rebels'),
        OpenDeadlockGame.diplomacyStatusAlliance);
    expect(alliance.tileAt(6, 3).isExploredBy('humans'), isTrue);
    expect(alliance.tileAt(2, 2).isExploredBy('rebels'), isTrue);
    expect(alliance.worldSummaryFor('humans').visibleEnemyColonies, 1);
    expect(alliance.worldSummaryFor('rebels').visibleEnemyColonies, 1);
    expect(alliance.allianceSharedSectorCountFor('humans', 'rebels'),
        greaterThan(0));
    expect(alliance.commandHistory.length, 3);
    expect(alliance.reports.first.message,
        'Human Assembly and Tarth Legion are now allied.');
  });

  test('alliances share newly explored sectors at turn advance', () {
    final allied = OpenDeadlockGame.sample().applyCommand(
      const SetDiplomacyStatusCommand(
        factionId: 'humans',
        targetFactionId: 'rebels',
        status: OpenDeadlockGame.diplomacyStatusAlliance,
      ),
    );

    expect(allied.tileAt(4, 1).isExploredBy('humans'), isFalse);
    expect(allied.tileAt(4, 1).isExploredBy('rebels'), isFalse);

    final moved = allied.applyCommand(
      const MoveUnitCommand(
        factionId: 'humans',
        unitId: 'human-scout',
        x: 4,
        y: 1,
      ),
    );

    expect(moved.tileAt(4, 1).isExploredBy('humans'), isTrue);
    expect(moved.tileAt(4, 1).isExploredBy('rebels'), isFalse);

    final next = moved.endTurn();

    expect(next.tileAt(4, 1).isExploredBy('humans'), isTrue);
    expect(next.tileAt(4, 1).isExploredBy('rebels'), isTrue);
    expect(next.allianceSharedSectorCountFor('humans', 'rebels'),
        moved.allianceSharedSectorCountFor('humans', 'rebels') + 1);
  });

  test('live visibility hides remembered enemy units outside sensor range', () {
    final sample = OpenDeadlockGame.sample();
    final rememberedContact = sample.copyWith(
      tiles: sample.tiles.map((tile) {
        if (tile.x == 5 && tile.y == 3) {
          return tile.revealTo('humans');
        }
        return tile;
      }).toList(),
    );

    expect(rememberedContact.tileAt(5, 3).isExploredBy('humans'), isTrue);
    expect(rememberedContact.isSectorVisibleTo('humans', 5, 3), isFalse);
    expect(rememberedContact.visibleUnitAt('humans', 5, 3), isNull);
    expect(rememberedContact.visibleEnemyUnitCountFor('humans'), 0);
    expect(OpenDeadlockGame.visionRadiusForUnit('scout'), 2);

    final scoutNearby = rememberedContact.copyWith(
      units: rememberedContact.units.map((unit) {
        if (unit.id == 'human-scout') {
          return unit.copyWith(x: 4, y: 3);
        }
        return unit;
      }).toList(),
    );

    expect(scoutNearby.isSectorVisibleTo('humans', 5, 3), isTrue);
    expect(scoutNearby.visibleUnitAt('humans', 5, 3)!.id, 'rebel-scout');
    expect(scoutNearby.visibleEnemyUnitCountFor('humans'), 1);
  });

  test('allied sensors share live unit contacts', () {
    final allied = OpenDeadlockGame.sample().applyCommand(
      const SetDiplomacyStatusCommand(
        factionId: 'humans',
        targetFactionId: 'rebels',
        status: OpenDeadlockGame.diplomacyStatusAlliance,
      ),
    );

    expect(allied.areAllied('humans', 'rebels'), isTrue);
    expect(allied.visibleUnitAt('humans', 5, 3)!.id, 'rebel-scout');
    expect(allied.visibleEnemyUnitCountFor('humans'), 0);
  });

  test('peace treaties produce trade credits', () {
    final peace = OpenDeadlockGame.sample().applyCommand(
      const SetDiplomacyStatusCommand(
        factionId: 'humans',
        targetFactionId: 'rebels',
        status: OpenDeadlockGame.diplomacyStatusPeace,
      ),
    );
    final colonyOutput =
        peace.colonyProductionFor(peace.colonyById('new-haven')).output;
    final projected = peace.worldSummaryFor('humans').projectedProduction;
    final next = peace.endTurn();

    expect(peace.peaceTreatyCountFor('humans'), 1);
    expect(peace.treatyTradeCreditsFor('humans', 'rebels'), 2);
    expect(peace.tradeIncomeFor('humans').credits, 2);
    expect(projected.credits, colonyOutput.credits + 2);
    expect(
      next.factionById('humans')!.resources.credits,
      peace.factionById('humans')!.resources.credits + colonyOutput.credits + 2,
    );

    final alliance = peace.applyCommand(
      const SetDiplomacyStatusCommand(
        factionId: 'humans',
        targetFactionId: 'rebels',
        status: OpenDeadlockGame.diplomacyStatusAlliance,
      ),
    );
    final allianceProjected =
        alliance.worldSummaryFor('humans').projectedProduction;
    final allianceNext = alliance.endTurn();

    expect(alliance.peaceTreatyCountFor('humans'), 0);
    expect(alliance.treatyTradeCreditsFor('humans', 'rebels'), 4);
    expect(alliance.tradeIncomeFor('humans').credits, 4);
    expect(allianceProjected.credits, colonyOutput.credits + 4);
    expect(
      allianceNext.factionById('humans')!.resources.credits,
      alliance.factionById('humans')!.resources.credits +
          colonyOutput.credits +
          4,
    );
  });

  test('intel scans reveal hidden rival colony sectors for credits', () {
    final game = OpenDeadlockGame.sample();

    expect(game.tileAt(6, 3).isExploredBy('humans'), isFalse);
    expect(game.worldSummaryFor('humans').visibleEnemyColonies, 0);
    expect(game.intelScanRevealableSectorCountFor('humans', 'rebels'), 5);

    final scanned = game.applyCommand(
      const ScanFactionIntelCommand(
        factionId: 'humans',
        targetFactionId: 'rebels',
      ),
    );

    expect(scanned.tileAt(6, 3).isExploredBy('humans'), isTrue);
    expect(scanned.tileAt(5, 3).isExploredBy('humans'), isTrue);
    expect(scanned.worldSummaryFor('humans').visibleEnemyColonies, 1);
    expect(scanned.intelScanRevealableSectorCountFor('humans', 'rebels'), 0);
    expect(scanned.factionById('humans')!.resources.credits,
        game.factionById('humans')!.resources.credits - 6);
    expect(scanned.commandHistory.single.command.type,
        ScanFactionIntelCommand.commandType);
    expect(scanned.reports.first.title, 'Intel scan complete');
    expect(
      scanned.reports.first.message,
      'Human Assembly scanned Tarth Legion and revealed 5 sector(s) near Redoubt for 6 credits.',
    );
  });

  test('intel scans reject low budgets and stale targets', () {
    final sample = OpenDeadlockGame.sample();
    final lowBudget = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id != 'humans') {
          return faction;
        }
        return faction.copyWith(
          resources: faction.resources.copyWith(credits: 5),
        );
      }).toList(),
    );

    expect(
      () => lowBudget.applyCommand(
        const ScanFactionIntelCommand(
          factionId: 'humans',
          targetFactionId: 'rebels',
        ),
      ),
      throwsArgumentError,
    );

    final scanned = sample.applyCommand(
      const ScanFactionIntelCommand(
        factionId: 'humans',
        targetFactionId: 'rebels',
      ),
    );

    expect(
      () => scanned.applyCommand(
        const ScanFactionIntelCommand(
          factionId: 'humans',
          targetFactionId: 'rebels',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('sabotage damages visible enemy construction for credits', () {
    final game = OpenDeadlockGame.sample().applyCommand(
      const ScanFactionIntelCommand(
        factionId: 'humans',
        targetFactionId: 'rebels',
      ),
    );
    final target = game.sabotageTargetFor('humans', 'rebels');

    expect(target, isNotNull);
    expect(target!.colonyName, 'Redoubt');
    expect(target.storedIndustry, 4);
    expect(target.damage, 4);

    final sabotaged = game.applyCommand(
      const SabotageColonyCommand(
        factionId: 'humans',
        targetFactionId: 'rebels',
      ),
    );

    expect(sabotaged.colonyById('redoubt').storedIndustry, 0);
    expect(
      sabotaged.factionById('humans')!.resources.credits,
      game.factionById('humans')!.resources.credits -
          OpenDeadlockGame.sabotageCreditCost,
    );
    expect(sabotaged.sabotageTargetFor('humans', 'rebels'), isNull);
    expect(sabotaged.commandHistory.last.command.type,
        SabotageColonyCommand.commandType);
    expect(sabotaged.reports.first.title, 'Sabotage complete');
    expect(
      sabotaged.reports.first.message,
      'Human Assembly sabotaged Redoubt, destroying 4 stored industry for 10 credits.',
    );
  });

  test('security buildings and defense grid reduce sabotage damage', () {
    final sample = OpenDeadlockGame.sample();
    final secured = sample.copyWith(
      tiles: sample.tiles.map((tile) {
        if (tile.x == 6 && tile.y == 3) {
          return tile.revealTo('humans');
        }
        return tile;
      }).toList(),
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'redoubt') {
          return colony;
        }
        return colony.copyWith(
          storedIndustry: 12,
          completedBuildings: const <String>['Militia Post'],
        );
      }).toList(),
    );
    final target = secured.sabotageTargetFor('humans', 'rebels');

    expect(
        secured.sabotageProtectionForColony(secured.colonyById('redoubt')), 2);
    expect(secured.sabotageDamageForColony(secured.colonyById('redoubt')), 6);
    expect(target, isNotNull);
    expect(target!.damage, 6);

    final sabotaged = secured.applyCommand(
      const SabotageColonyCommand(
        factionId: 'humans',
        targetFactionId: 'rebels',
      ),
    );

    expect(sabotaged.colonyById('redoubt').storedIndustry, 6);
    expect(sabotaged.reports.first.details['protection'], '2');

    final hardened = secured.copyWith(
      factions: secured.factions.map((faction) {
        if (faction.id != 'rebels') {
          return faction;
        }
        return faction.copyWith(
          completedResearch: const <String>['Defense Grid'],
        );
      }).toList(),
      colonies: secured.colonies.map((colony) {
        if (colony.id != 'redoubt') {
          return colony;
        }
        return colony.copyWith(
          completedBuildings: const <String>['Militia Post', 'Barracks'],
        );
      }).toList(),
    );

    expect(hardened.sabotageProtectionForColony(hardened.colonyById('redoubt')),
        8);
    expect(hardened.sabotageDamageForColony(hardened.colonyById('redoubt')), 0);
    expect(hardened.sabotageTargetFor('humans', 'rebels'), isNull);
  });

  test('sabotage rejects peace, low budgets, and hidden targets', () {
    final sample = OpenDeadlockGame.sample();
    final visible = sample.copyWith(
      tiles: sample.tiles.map((tile) {
        if (tile.x == 6 && tile.y == 3) {
          return tile.revealTo('humans');
        }
        return tile;
      }).toList(),
    );
    final lowBudget = visible.copyWith(
      factions: visible.factions.map((faction) {
        if (faction.id != 'humans') {
          return faction;
        }
        return faction.copyWith(
          resources: faction.resources.copyWith(
            credits: OpenDeadlockGame.sabotageCreditCost - 1,
          ),
        );
      }).toList(),
    );
    final peace = visible.applyCommand(
      const SetDiplomacyStatusCommand(
        factionId: 'humans',
        targetFactionId: 'rebels',
        status: OpenDeadlockGame.diplomacyStatusPeace,
      ),
    );

    expect(sample.sabotageTargetFor('humans', 'rebels'), isNull);
    expect(visible.sabotageTargetFor('humans', 'rebels')!.damage, 4);
    expect(
      () => sample.applyCommand(
        const SabotageColonyCommand(
          factionId: 'humans',
          targetFactionId: 'rebels',
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => lowBudget.applyCommand(
        const SabotageColonyCommand(
          factionId: 'humans',
          targetFactionId: 'rebels',
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => peace.applyCommand(
        const SabotageColonyCommand(
          factionId: 'humans',
          targetFactionId: 'rebels',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('military strength counts units and colony defenses', () {
    final game = OpenDeadlockGame.sample();

    expect(game.militaryStrengthFor('humans'), 14);
    expect(game.militaryStrengthFor('rebels'), 15);
    expect(() => game.militaryStrengthFor('missing'), throwsArgumentError);
  });

  test('faction scores rank strategic progress', () {
    final game = OpenDeadlockGame.sample();
    final humans = game.factionScoreFor('humans');
    final rebels = game.factionScoreFor('rebels');
    final scores = game.factionScores();

    expect(humans.factionName, 'Human Assembly');
    expect(humans.raceName, 'Human');
    expect(humans.controlMode, Faction.controlLocal);
    expect(humans.colonyScore, 50);
    expect(humans.sectorScore, 32);
    expect(humans.populationScore, 25);
    expect(humans.militaryScore, 42);
    expect(humans.scienceScore, 0);
    expect(humans.reserveScore, 6);
    expect(humans.total, 155);

    expect(rebels.total, 143);
    expect(scores.map((score) => score.factionId), <String>[
      'humans',
      'rebels',
    ]);
    expect(() => game.factionScoreFor('missing'), throwsArgumentError);
  });

  test('research projects complete and improve later colony output', () {
    final sample = OpenDeadlockGame.sample();
    final ready = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id != 'humans') {
          return faction;
        }
        return faction.copyWith(
          resources: faction.resources.copyWith(
            research: OpenDeadlockGame.researchCostFor('Hydroponics') - 2,
          ),
        );
      }).toList(),
    );

    final completed = ready.endTurn();
    final humans = completed.factionById('humans')!;
    final nextTurn = completed.endTurn();
    final foodDelta =
        nextTurn.factionById('humans')!.resources.food - humans.resources.food;

    expect(humans.completedResearch, contains('Hydroponics'));
    expect(humans.researchProject, 'Industrial Automation');
    expect(humans.resources.research, 1);
    expect(completed.reports.first.title,
        'Human Assembly: Hydroponics researched');
    expect(completed.reports.first.message,
        contains('Next project queued: Industrial Automation.'));
    expect(foodDelta, 9);
  });

  test('core research completion wins a science victory', () {
    final sample = OpenDeadlockGame.sample();
    final almostFinished = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id != 'humans') {
          return faction;
        }
        return faction.copyWith(
          completedResearch: const <String>[
            'Hydroponics',
            'Industrial Automation',
            'Xenoarchaeology',
          ],
          researchProject: 'Defense Grid',
        );
      }).toList(),
    );
    final projectedResearch = almostFinished
        .colonyProductionFor(almostFinished.colonyById('new-haven'))
        .output
        .research;
    final ready = almostFinished.copyWith(
      factions: almostFinished.factions.map((faction) {
        if (faction.id != 'humans') {
          return faction;
        }
        return faction.copyWith(
          resources: faction.resources.copyWith(
            research: OpenDeadlockGame.researchCostFor('Defense Grid') -
                projectedResearch,
          ),
        );
      }).toList(),
    );

    final winner = ready.endTurn();
    final humans = winner.factionById('humans')!;

    expect(humans.completedResearch,
        containsAll(OpenDeadlockGame.coreResearchOptions));
    expect(humans.researchProject, 'Future Studies');
    expect(winner.winningFactionId, 'humans');
    expect(winner.winningVictoryType, OpenDeadlockGame.victoryTypeScience);
    expect(winner.winningVictoryMessage,
        'Human Assembly completed every core research project.');
    expect(winner.isGameOver, isTrue);
    expect(winner.reports.first.title, 'Human Assembly wins');
    expect(winner.reports.first.message,
        'Human Assembly completed every core research project.');
    expect(
      winner.reports.where((report) => report.title == 'Human Assembly wins'),
      hasLength(1),
    );
  });

  test('faction traits add production bonuses', () {
    final sample = OpenDeadlockGame.sample();
    final next = sample.endTurn();
    final humans = next.factionById('humans')!;
    final rebels = next.factionById('rebels')!;

    expect(OpenDeadlockGame.traitSummaryFor(humans), 'Scholars, Traders');
    expect(
        humans.resources.research -
            sample.factionById('humans')!.resources.research,
        3);
    expect(
        humans.resources.credits -
            sample.factionById('humans')!.resources.credits,
        9);
    expect(
        rebels.resources.industry -
            sample.factionById('rebels')!.resources.industry,
        8);
  });

  test('colony production projection reports output and support needs', () {
    final game = OpenDeadlockGame.sample();
    final colony = game.colonyById('new-haven');
    final projection = game.colonyProductionFor(colony);

    expect(projection.output.food, 7);
    expect(projection.output.industry, 7);
    expect(projection.output.research, 3);
    expect(projection.output.credits, 9);
    expect(projection.constructionWork, 7);
    expect(projection.foodDemand, 6);
    expect(projection.foodBalance, 1);
    expect(projection.housingCapacity, 8);
    expect(projection.buildingUpkeep, 0);
    expect(projection.populationChange, 1);
    expect(projection.moraleChange, 0);
    expect(projection.nextPopulation, 6);
    expect(projection.nextMorale, 72);
    expect(projection.willGrow, isTrue);
    expect(projection.isAtHousingCapacity, isFalse);
    expect(projection.isStarving, isFalse);
    expect(projection.willCompleteConstruction, isFalse);
  });

  test('housing capacity caps growth until housing is completed', () {
    final sample = OpenDeadlockGame.sample();
    final capped = sample.copyWith(
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'new-haven') {
          return colony;
        }
        return colony.copyWith(
          population: OpenDeadlockGame.basePopulationCapacity,
          construction: 'Housing',
          storedIndustry: OpenDeadlockGame.buildCostFor('Housing') - 1,
        );
      }).toList(),
    );
    final cappedColony = capped.colonyById('new-haven');
    final cappedProjection = capped.colonyProductionFor(cappedColony);
    final upgraded = capped.endTurn();
    final upgradedColony = upgraded.colonyById('new-haven');
    final upgradedProjection = upgraded.colonyProductionFor(upgradedColony);

    expect(OpenDeadlockGame.populationCapacityFor(cappedColony), 8);
    expect(cappedProjection.foodBalance, greaterThan(0));
    expect(cappedProjection.populationChange, 0);
    expect(cappedProjection.nextPopulation, 8);
    expect(cappedProjection.isAtHousingCapacity, isTrue);
    expect(cappedProjection.willCompleteConstruction, isTrue);
    expect(upgradedColony.completedBuildings, contains('Housing'));
    expect(OpenDeadlockGame.populationCapacityFor(upgradedColony), 12);
    expect(upgradedColony.population, 8);
    expect(upgradedProjection.populationChange, 1);
    expect(upgradedProjection.nextPopulation, 9);
    expect(upgraded.reports.first.title, 'New Haven: Housing completed');
    expect(upgraded.reports.first.message,
        'Population capacity increased. Next project queued: Research Lab.');
  });

  test('construction summaries report cost upkeep output and requirements', () {
    expect(
      OpenDeadlockGame.constructionSummaryFor('Apartment Complex'),
      'Cost 18 industry / Upkeep 1 credit / '
      'Produces +4 population capacity / Requires Housing',
    );
    expect(
      OpenDeadlockGame.constructionSummaryFor('Armor Company'),
      'Cost 30 industry / Upkeep 0 credits / '
      'Produces Armor unit / Requires Barracks and Factory',
    );
    expect(OpenDeadlockGame.constructionRequirementFor('Farm Dome'), 'None');
    expect(
      OpenDeadlockGame.constructionProducesDescriptionFor('Research Lab'),
      '+4 research from the colony',
    );
    expect(
      OpenDeadlockGame.constructionProducesDescriptionFor('Militia Post'),
      '+2 colony defense and +2 sabotage protection',
    );
    expect(
      OpenDeadlockGame.constructionProducesDescriptionFor('Barracks'),
      '+3 colony defense, +3 sabotage protection, and infantry training',
    );
    expect(
      OpenDeadlockGame.researchDescriptionFor('Defense Grid'),
      '+2 defense and +3 sabotage protection for controlled colonies.',
    );
    expect(
      () => OpenDeadlockGame.constructionSummaryFor('Orbital Elevator'),
      throwsArgumentError,
    );
  });

  test('residential tiers extend capacity behind prerequisites', () {
    final sample = OpenDeadlockGame.sample();
    final colony = sample.colonyById('new-haven');

    expect(
      OpenDeadlockGame.isConstructionAvailableFor(colony, 'Apartment Complex'),
      isFalse,
    );
    expect(
      () => sample.setColonyConstruction('new-haven', 'Apartment Complex'),
      throwsArgumentError,
    );

    final housed = sample.copyWith(
      colonies: sample.colonies.map((currentColony) {
        if (currentColony.id != 'new-haven') {
          return currentColony;
        }
        return currentColony.copyWith(
          completedBuildings: const <String>['Housing'],
        );
      }).toList(),
    );
    final housedColony = housed.colonyById('new-haven');

    expect(OpenDeadlockGame.populationCapacityFor(housedColony), 12);
    expect(
      OpenDeadlockGame.isConstructionAvailableFor(
          housedColony, 'Apartment Complex'),
      isTrue,
    );
    expect(
      OpenDeadlockGame.isConstructionAvailableFor(
          housedColony, 'Luxury Housing'),
      isFalse,
    );

    final ready = housed.copyWith(
      colonies: housed.colonies.map((currentColony) {
        if (currentColony.id != 'new-haven') {
          return currentColony;
        }
        return currentColony.copyWith(
          population: 12,
          construction: 'Apartment Complex',
          storedIndustry:
              OpenDeadlockGame.buildCostFor('Apartment Complex') - 1,
        );
      }).toList(),
    );
    final upgraded = ready.endTurn();
    final upgradedColony = upgraded.colonyById('new-haven');

    expect(upgradedColony.completedBuildings, contains('Apartment Complex'));
    expect(OpenDeadlockGame.populationCapacityFor(upgradedColony), 16);
    expect(OpenDeadlockGame.buildingUpkeepFor(upgradedColony), 1);
    expect(
      OpenDeadlockGame.isConstructionAvailableFor(
          upgradedColony, 'Luxury Housing'),
      isTrue,
    );
    expect(
        upgraded.reports.first.title, 'New Haven: Apartment Complex completed');
    expect(upgraded.reports.first.message,
        'Population capacity increased. Next project queued: Research Lab.');
  });

  test('completed buildings charge upkeep against colony credits', () {
    final sample = OpenDeadlockGame.sample();
    final maintained = sample.copyWith(
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'new-haven') {
          return colony;
        }
        return colony.copyWith(
          completedBuildings: const <String>[
            'Factory',
            'Research Lab',
            'Barracks',
          ],
        );
      }).toList(),
    );
    final baseline = sample.colonyProductionFor(sample.colonyById('new-haven'));
    final colony = maintained.colonyById('new-haven');
    final projection = maintained.colonyProductionFor(colony);
    final next = maintained.endTurn();

    expect(OpenDeadlockGame.buildingUpkeepFor(colony), 3);
    expect(projection.buildingUpkeep, 3);
    expect(projection.output.credits, baseline.output.credits - 3);
    expect(
      next.factionById('humans')!.resources.credits,
      maintained.factionById('humans')!.resources.credits +
          projection.output.credits,
    );
  });

  test('low morale colonies enter unrest and lose output', () {
    final sample = OpenDeadlockGame.sample();
    final unrestGame = sample.copyWith(
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'new-haven') {
          return colony;
        }
        return colony.copyWith(morale: 24);
      }).toList(),
    );
    final baseline = sample.colonyProductionFor(sample.colonyById('new-haven'));
    final colony = unrestGame.colonyById('new-haven');
    final projection = unrestGame.colonyProductionFor(colony);
    final next = unrestGame.endTurn();

    expect(OpenDeadlockGame.isColonyInUnrest(colony), isTrue);
    expect(OpenDeadlockGame.colonyStabilityLabelFor(colony), 'Unrest');
    expect(projection.isInUnrest, isTrue);
    expect(projection.moraleOutputAdjustment.industry, -2);
    expect(projection.moraleOutputAdjustment.research, -1);
    expect(projection.moraleOutputAdjustment.credits, -2);
    expect(projection.output.food, baseline.output.food);
    expect(projection.output.industry, baseline.output.industry - 2);
    expect(projection.output.research, baseline.output.research - 1);
    expect(projection.output.credits, baseline.output.credits - 4);
    expect(
      next.reports.any((report) => report.title == 'New Haven: unrest'),
      isTrue,
    );
  });

  test('severe unrest riots damage stored construction progress', () {
    final sample = OpenDeadlockGame.sample();
    final riotGame = sample.copyWith(
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'new-haven') {
          return colony;
        }
        return colony.copyWith(morale: 10);
      }).toList(),
    );
    final colony = riotGame.colonyById('new-haven');
    final projection = riotGame.colonyProductionFor(colony);
    final next = riotGame.endTurn();
    final nextColony = next.colonyById('new-haven');

    expect(OpenDeadlockGame.isColonyInCriticalUnrest(colony), isTrue);
    expect(OpenDeadlockGame.isColonyRioting(colony), isTrue);
    expect(OpenDeadlockGame.colonyStabilityLabelFor(colony), 'Riot');
    expect(projection.isRioting, isTrue);
    expect(projection.riotIndustryLoss, 4);
    expect(projection.willCompleteConstruction, isFalse);
    expect(nextColony.storedIndustry, 11);
    expect(
      next.reports.any((report) =>
          report.title == 'New Haven: riots' &&
          report.message.contains('destroyed 4 stored industry')),
      isTrue,
    );
  });

  test('security buildings suppress riot construction damage', () {
    final sample = OpenDeadlockGame.sample();
    final guardedGame = sample.copyWith(
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'new-haven') {
          return colony;
        }
        return colony.copyWith(
          morale: 10,
          completedBuildings: const <String>['Militia Post'],
        );
      }).toList(),
    );
    final colony = guardedGame.colonyById('new-haven');
    final projection = guardedGame.colonyProductionFor(colony);
    final next = guardedGame.endTurn();

    expect(OpenDeadlockGame.isColonyInCriticalUnrest(colony), isTrue);
    expect(OpenDeadlockGame.isColonyRiotSuppressed(colony), isTrue);
    expect(OpenDeadlockGame.isColonyRioting(colony), isFalse);
    expect(OpenDeadlockGame.colonyStabilityLabelFor(colony), 'Suppressed');
    expect(projection.isInUnrest, isTrue);
    expect(projection.isRioting, isFalse);
    expect(projection.riotIndustryLoss, 0);
    expect(next.colonyById('new-haven').storedIndustry, 15);
    expect(
      next.reports.any((report) => report.title == 'New Haven: riots'),
      isFalse,
    );
  });

  test('world summaries aggregate faction intelligence', () {
    final game = OpenDeadlockGame.sample();
    final humans = game.worldSummaryFor('humans');
    final rebels = game.worldSummaryFor('rebels');
    final summaries = game.worldSummaries();

    expect(summaries.length, 2);
    expect(humans.factionName, 'Human Assembly');
    expect(humans.raceName, 'Human');
    expect(humans.controlMode, Faction.controlLocal);
    expect(humans.colonyCount, 1);
    expect(humans.totalColonyCount, 2);
    expect(humans.victoryProgressLabel, '1/2 colonies');
    expect(humans.victorySharePercent, 50);
    expect(humans.hasConquestVictory, isFalse);
    expect(humans.isDefeated, isFalse);
    expect(humans.coreResearchCompleted, 0);
    expect(humans.coreResearchTotal, 4);
    expect(humans.scienceVictoryProgressLabel, '0/4 research');
    expect(humans.scienceVictorySharePercent, 0);
    expect(humans.hasScienceVictory, isFalse);
    expect(humans.unitCount, 1);
    expect(humans.controlledSectors, 16);
    expect(humans.exploredSectors, 24);
    expect(humans.totalPopulation, 5);
    expect(humans.projectedProduction.food, 7);
    expect(humans.projectedProduction.industry, 7);
    expect(humans.projectedProduction.research, 3);
    expect(humans.projectedProduction.credits, 9);
    expect(humans.atWarCount, 1);
    expect(humans.visibleEnemyColonies, 0);
    expect(rebels.colonyCount, 1);
    expect(rebels.totalColonyCount, 2);
    expect(rebels.victoryProgressLabel, '1/2 colonies');
    expect(rebels.unitCount, 1);
    expect(rebels.controlledSectors, 12);
    expect(rebels.visibleEnemyColonies, 0);
    expect(() => game.worldSummaryFor('missing'), throwsArgumentError);
  });

  test('world summaries mark defeated factions', () {
    final game = _eliminationBattleFixture().applyCommand(
      const MoveUnitCommand(
        factionId: 'humans',
        unitId: 'human-scout',
        x: 6,
        y: 3,
      ),
    );
    final rebels = game.worldSummaryFor('rebels');
    final traders = game.worldSummaryFor('traders');

    expect(game.isGameOver, isFalse);
    expect(rebels.isDefeated, isTrue);
    expect(rebels.colonyCount, 0);
    expect(rebels.unitCount, 0);
    expect(traders.isDefeated, isFalse);
  });

  test('faction scores sort defeated factions after live factions', () {
    final game = _eliminationBattleFixture().applyCommand(
      const MoveUnitCommand(
        factionId: 'humans',
        unitId: 'human-scout',
        x: 6,
        y: 3,
      ),
    );
    final wealthyDefeated = game.copyWith(
      factions: game.factions.map((faction) {
        if (faction.id != 'rebels') {
          return faction;
        }
        return faction.copyWith(
          resources: faction.resources.copyWith(credits: 2000),
        );
      }).toList(),
    );
    final rebelScore = wealthyDefeated.factionScoreFor('rebels');
    final traderScore = wealthyDefeated.factionScoreFor('traders');
    final scores = wealthyDefeated.factionScores();

    expect(rebelScore.isDefeated, isTrue);
    expect(traderScore.isDefeated, isFalse);
    expect(rebelScore.total, greaterThan(traderScore.total));
    expect(scores.last.factionId, 'rebels');
  });

  test('world summaries report conquest victory progress', () {
    final sample = OpenDeadlockGame.sample();
    final conquered = sample.copyWith(
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'redoubt') {
          return colony;
        }
        return colony.copyWith(ownerId: 'humans');
      }).toList(),
    );
    final humans = conquered.worldSummaryFor('humans');
    final rebels = conquered.worldSummaryFor('rebels');

    expect(conquered.winningFactionId, 'humans');
    expect(humans.colonyCount, 2);
    expect(humans.totalColonyCount, 2);
    expect(humans.victoryProgressLabel, '2/2 colonies');
    expect(humans.victorySharePercent, 100);
    expect(humans.hasConquestVictory, isTrue);
    expect(humans.hasScienceVictory, isFalse);
    expect(rebels.victoryProgressLabel, '0/2 colonies');
    expect(rebels.victorySharePercent, 0);
    expect(rebels.hasConquestVictory, isFalse);
  });

  test('food shortages reduce population and morale', () {
    final sample = OpenDeadlockGame.sample();
    final shortage = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id != 'humans') {
          return faction;
        }
        return faction.copyWith(traitIds: const <String>[]);
      }).toList(),
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'new-haven') {
          return colony;
        }
        return Colony(
          id: colony.id,
          name: colony.name,
          ownerId: colony.ownerId,
          x: 4,
          y: 0,
          population: 5,
          morale: 50,
          construction: 'Factory',
          storedIndustry: 0,
          completedBuildings: const <String>[],
        );
      }).toList(),
    );
    final projection = shortage.colonyProductionFor(
      shortage.colonyById('new-haven'),
    );
    final next = shortage.endTurn();
    final colony = next.colonyById('new-haven');

    expect(shortage.tileAt(4, 0).terrain, 'ruins');
    expect(projection.foodDemand, 6);
    expect(projection.foodBalance, -1);
    expect(projection.populationChange, -1);
    expect(projection.moraleChange, -8);
    expect(projection.nextPopulation, 4);
    expect(projection.nextMorale, 42);
    expect(projection.isStarving, isTrue);
    expect(colony.population, 4);
    expect(colony.morale, 42);
    expect(next.reports.first.title, 'New Haven: food shortage');
    expect(next.reports.first.message, contains('exceeded output by 1'));
  });

  test('race profiles add production and construction behavior', () {
    final sample = OpenDeadlockGame.sample();
    final chchtGame = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id != 'humans') {
          return faction;
        }
        return faction.copyWith(
          raceId: 'chcht',
          traitIds: const <String>[],
        );
      }).toList(),
    );
    final humanGame = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id != 'humans') {
          return faction;
        }
        return faction.copyWith(traitIds: const <String>[]);
      }).toList(),
    );

    final chcht = chchtGame.endTurn();
    final human = humanGame.endTurn();
    final chchtFaction = chcht.factionById('humans')!;
    final humanFaction = human.factionById('humans')!;

    expect(chcht.colonyById('new-haven').population, 7);
    expect(human.colonyById('new-haven').population, 6);
    expect(chcht.colonyById('new-haven').storedIndustry, 20);
    expect(human.colonyById('new-haven').storedIndustry, 17);
    expect(chchtFaction.resources.food - humanFaction.resources.food, 1);
    expect(
        chchtFaction.resources.industry - humanFaction.resources.industry, 1);
  });

  test('cyth colonies keep a high morale floor', () {
    final sample = OpenDeadlockGame.sample();
    final cythGame = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id != 'humans') {
          return faction;
        }
        return faction.copyWith(raceId: 'cyth');
      }).toList(),
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'new-haven') {
          return colony;
        }
        return colony.copyWith(morale: 20);
      }).toList(),
    );

    final next = cythGame.endTurn();

    expect(next.colonyById('new-haven').morale, 80);
  });

  test('tarth units gain a race attack bonus', () {
    final sample = OpenDeadlockGame.sample();
    final tarthAttacker = sample.copyWith(
      activeFactionId: 'rebels',
      units: <Unit>[
        sample.unitById('human-scout').copyWith(x: 3, y: 1),
        sample.unitById('rebel-scout').copyWith(x: 4, y: 1),
      ],
    );
    final baselineAttacker = tarthAttacker.copyWith(
      factions: tarthAttacker.factions.map((faction) {
        if (faction.id != 'rebels') {
          return faction;
        }
        return faction.copyWith(raceId: 'human');
      }).toList(),
    );

    final tarthResult = tarthAttacker.applyCommand(
      const MoveUnitCommand(
        factionId: 'rebels',
        unitId: 'rebel-scout',
        x: 3,
        y: 1,
      ),
    );
    final baselineResult = baselineAttacker.applyCommand(
      const MoveUnitCommand(
        factionId: 'rebels',
        unitId: 'rebel-scout',
        x: 3,
        y: 1,
      ),
    );

    expect(tarthResult.unitById('human-scout').health, 2);
    expect(baselineResult.unitById('human-scout').health, 3);
  });

  test('computer difficulty adjusts AI production for computer factions', () {
    final sample = OpenDeadlockGame.sample();
    final normal = sample.endTurn();
    final hard = sample
        .copyWith(
          factions: sample.factions.map((faction) {
            if (faction.id == 'rebels') {
              return faction.copyWith(difficulty: Faction.difficultyHard);
            }
            return faction;
          }).toList(),
        )
        .endTurn();
    final easy = sample
        .copyWith(
          factions: sample.factions.map((faction) {
            if (faction.id == 'rebels') {
              return faction.copyWith(difficulty: Faction.difficultyEasy);
            }
            return faction;
          }).toList(),
        )
        .endTurn();
    final hardLocal = sample
        .copyWith(
          factions: sample.factions.map((faction) {
            if (faction.id == 'humans') {
              return faction.copyWith(difficulty: Faction.difficultyHard);
            }
            return faction;
          }).toList(),
        )
        .endTurn();

    final normalRebels = normal.factionById('rebels')!;
    final hardRebels = hard.factionById('rebels')!;
    final easyRebels = easy.factionById('rebels')!;

    expect(hardRebels.resources.industry - normalRebels.resources.industry, 1);
    expect(hardRebels.resources.research - normalRebels.resources.research, 1);
    expect(hardRebels.resources.credits - normalRebels.resources.credits, 1);
    expect(normalRebels.resources.industry - easyRebels.resources.industry, 1);
    expect(normalRebels.resources.research - easyRebels.resources.research, 1);
    expect(normalRebels.resources.credits - easyRebels.resources.credits, 1);
    expect(hardLocal.factionById('humans')!.resources.industry,
        normal.factionById('humans')!.resources.industry);
  });

  test('defense grid increases controlled colony defense', () {
    final sample = OpenDeadlockGame.sample();
    final upgraded = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id != 'humans') {
          return faction;
        }
        return faction.copyWith(
          completedResearch: const <String>['Defense Grid'],
        );
      }).toList(),
    );
    final colony = upgraded.colonyAt(2, 2)!;

    expect(upgraded.colonyDefenseForColony(colony),
        OpenDeadlockGame.colonyDefenseFor(colony) + 2);
  });

  test('commands can round-trip through json', () {
    const command = SetColonyConstructionCommand(
      factionId: 'humans',
      colonyId: 'new-haven',
      construction: 'Research Lab',
    );
    final restored =
        GameCommand.fromJson(command.toJson()) as SetColonyConstructionCommand;

    expect(restored.type, SetColonyConstructionCommand.commandType);
    expect(restored.factionId, command.factionId);
    expect(restored.colonyId, command.colonyId);
    expect(restored.construction, command.construction);

    const rushCommand = RushConstructionCommand(
      factionId: 'humans',
      colonyId: 'new-haven',
      industry: 4,
    );
    final restoredRush =
        GameCommand.fromJson(rushCommand.toJson()) as RushConstructionCommand;
    expect(restoredRush.type, RushConstructionCommand.commandType);
    expect(restoredRush.factionId, rushCommand.factionId);
    expect(restoredRush.colonyId, rushCommand.colonyId);
    expect(restoredRush.industry, rushCommand.industry);

    const focusCommand = SetColonyFocusCommand(
      factionId: 'humans',
      colonyId: 'new-haven',
      focus: OpenDeadlockGame.colonyFocusResearch,
    );
    final restoredFocus =
        GameCommand.fromJson(focusCommand.toJson()) as SetColonyFocusCommand;
    expect(restoredFocus.type, SetColonyFocusCommand.commandType);
    expect(restoredFocus.factionId, focusCommand.factionId);
    expect(restoredFocus.colonyId, focusCommand.colonyId);
    expect(restoredFocus.focus, focusCommand.focus);

    const sectorCommand = SetColonySectorAssignmentCommand(
      factionId: 'humans',
      colonyId: 'new-haven',
      x: 2,
      y: 1,
      assigned: true,
    );
    final restoredSector = GameCommand.fromJson(
      sectorCommand.toJson(),
    ) as SetColonySectorAssignmentCommand;
    expect(restoredSector.type, SetColonySectorAssignmentCommand.commandType);
    expect(restoredSector.factionId, sectorCommand.factionId);
    expect(restoredSector.colonyId, sectorCommand.colonyId);
    expect(restoredSector.x, sectorCommand.x);
    expect(restoredSector.y, sectorCommand.y);
    expect(restoredSector.assigned, isTrue);

    const researchCommand = SetResearchProjectCommand(
      factionId: 'humans',
      researchProject: 'Industrial Automation',
    );
    final restoredResearch = GameCommand.fromJson(researchCommand.toJson())
        as SetResearchProjectCommand;
    expect(restoredResearch.type, SetResearchProjectCommand.commandType);
    expect(restoredResearch.factionId, researchCommand.factionId);
    expect(restoredResearch.researchProject, researchCommand.researchProject);

    const fundResearchCommand = FundResearchCommand(
      factionId: 'humans',
      research: 3,
    );
    final restoredFundResearch = GameCommand.fromJson(
      fundResearchCommand.toJson(),
    ) as FundResearchCommand;
    expect(restoredFundResearch.type, FundResearchCommand.commandType);
    expect(restoredFundResearch.factionId, fundResearchCommand.factionId);
    expect(restoredFundResearch.research, fundResearchCommand.research);

    const controlCommand = SetFactionControlCommand(
      factionId: 'rebels',
      controlMode: Faction.controlRemote,
    );
    final restoredControl = GameCommand.fromJson(controlCommand.toJson())
        as SetFactionControlCommand;
    expect(restoredControl.type, SetFactionControlCommand.commandType);
    expect(restoredControl.factionId, controlCommand.factionId);
    expect(restoredControl.controlMode, controlCommand.controlMode);

    const difficultyCommand = SetFactionDifficultyCommand(
      factionId: 'rebels',
      difficulty: Faction.difficultyHard,
    );
    final restoredDifficulty = GameCommand.fromJson(
      difficultyCommand.toJson(),
    ) as SetFactionDifficultyCommand;
    expect(restoredDifficulty.type, SetFactionDifficultyCommand.commandType);
    expect(restoredDifficulty.factionId, difficultyCommand.factionId);
    expect(restoredDifficulty.difficulty, difficultyCommand.difficulty);

    const taxPolicyCommand = SetFactionTaxPolicyCommand(
      factionId: 'humans',
      taxPolicy: Faction.taxPolicyRelief,
    );
    final restoredTaxPolicy = GameCommand.fromJson(
      taxPolicyCommand.toJson(),
    ) as SetFactionTaxPolicyCommand;
    expect(restoredTaxPolicy.type, SetFactionTaxPolicyCommand.commandType);
    expect(restoredTaxPolicy.factionId, taxPolicyCommand.factionId);
    expect(restoredTaxPolicy.taxPolicy, taxPolicyCommand.taxPolicy);

    const diplomacyCommand = SetDiplomacyStatusCommand(
      factionId: 'humans',
      targetFactionId: 'rebels',
      status: OpenDeadlockGame.diplomacyStatusPeace,
    );
    final restoredDiplomacy = GameCommand.fromJson(
      diplomacyCommand.toJson(),
    ) as SetDiplomacyStatusCommand;
    expect(restoredDiplomacy.type, SetDiplomacyStatusCommand.commandType);
    expect(restoredDiplomacy.factionId, diplomacyCommand.factionId);
    expect(restoredDiplomacy.targetFactionId, diplomacyCommand.targetFactionId);
    expect(restoredDiplomacy.status, diplomacyCommand.status);

    const scanCommand = ScanFactionIntelCommand(
      factionId: 'humans',
      targetFactionId: 'rebels',
    );
    final restoredScan = GameCommand.fromJson(
      scanCommand.toJson(),
    ) as ScanFactionIntelCommand;
    expect(restoredScan.type, ScanFactionIntelCommand.commandType);
    expect(restoredScan.factionId, scanCommand.factionId);
    expect(restoredScan.targetFactionId, scanCommand.targetFactionId);

    const sabotageCommand = SabotageColonyCommand(
      factionId: 'humans',
      targetFactionId: 'rebels',
    );
    final restoredSabotage = GameCommand.fromJson(
      sabotageCommand.toJson(),
    ) as SabotageColonyCommand;
    expect(restoredSabotage.type, SabotageColonyCommand.commandType);
    expect(restoredSabotage.factionId, sabotageCommand.factionId);
    expect(restoredSabotage.targetFactionId, sabotageCommand.targetFactionId);

    const moveCommand = MoveUnitCommand(
      factionId: 'humans',
      unitId: 'human-scout',
      x: 4,
      y: 1,
    );
    final restoredMove =
        GameCommand.fromJson(moveCommand.toJson()) as MoveUnitCommand;
    expect(restoredMove.type, MoveUnitCommand.commandType);
    expect(restoredMove.unitId, moveCommand.unitId);
    expect(restoredMove.x, moveCommand.x);
    expect(restoredMove.y, moveCommand.y);

    const recoverCommand = RecoverUnitCommand(
      factionId: 'humans',
      unitId: 'human-scout',
    );
    final restoredRecover =
        GameCommand.fromJson(recoverCommand.toJson()) as RecoverUnitCommand;
    expect(restoredRecover.type, RecoverUnitCommand.commandType);
    expect(restoredRecover.factionId, recoverCommand.factionId);
    expect(restoredRecover.unitId, recoverCommand.unitId);

    const foundCommand = FoundColonyCommand(
      factionId: 'humans',
      unitId: 'human-scout',
      colonyId: 'humans-outpost-4-1',
      name: 'Outpost 5-2',
    );
    final restoredFound =
        GameCommand.fromJson(foundCommand.toJson()) as FoundColonyCommand;
    expect(restoredFound.type, FoundColonyCommand.commandType);
    expect(restoredFound.unitId, foundCommand.unitId);
    expect(restoredFound.colonyId, foundCommand.colonyId);
    expect(restoredFound.name, foundCommand.name);

    const endTurnCommand = EndTurnCommand(factionId: 'humans');
    final restoredEndTurn =
        GameCommand.fromJson(endTurnCommand.toJson()) as EndTurnCommand;
    expect(restoredEndTurn.type, EndTurnCommand.commandType);
    expect(restoredEndTurn.factionId, endTurnCommand.factionId);

    const runComputerTurnCommand = RunComputerTurnCommand(factionId: 'rebels');
    final restoredRunComputerTurn =
        GameCommand.fromJson(runComputerTurnCommand.toJson())
            as RunComputerTurnCommand;
    expect(restoredRunComputerTurn.type, RunComputerTurnCommand.commandType);
    expect(restoredRunComputerTurn.factionId, runComputerTurnCommand.factionId);
  });

  test('command batches can round-trip through versioned codec', () {
    const commands = <GameCommand>[
      SetColonyConstructionCommand(
        factionId: 'humans',
        colonyId: 'new-haven',
        construction: 'Factory',
      ),
      MoveUnitCommand(
        factionId: 'humans',
        unitId: 'human-scout',
        x: 4,
        y: 1,
      ),
      FoundColonyCommand(
        factionId: 'humans',
        unitId: 'human-scout',
        colonyId: 'humans-outpost-4-1',
        name: 'Outpost 5-2',
      ),
      EndTurnCommand(factionId: 'humans'),
    ];
    final encoded = GameCodec.encodeCommands(commands);
    final root = jsonDecode(encoded) as Map<String, dynamic>;
    final restored = GameCodec.decodeCommands(encoded);

    expect(root['kind'], GameCodec.commandsKind);
    expect(root['commandCount'], 4);
    expect(restored.length, 4);
    final command = restored.first as SetColonyConstructionCommand;
    expect(command.factionId, 'humans');
    expect(command.colonyId, 'new-haven');
    expect(command.construction, 'Factory');
    final moveCommand = restored[1] as MoveUnitCommand;
    expect(moveCommand.unitId, 'human-scout');
    expect(moveCommand.x, 4);
    expect(moveCommand.y, 1);
    final foundCommand = restored[2] as FoundColonyCommand;
    expect(foundCommand.colonyId, 'humans-outpost-4-1');
    final endTurnCommand = restored[3] as EndTurnCommand;
    expect(endTurnCommand.factionId, 'humans');
  });

  test('share codes round-trip snapshots invites and order packages', () {
    final initial = OpenDeadlockGame.sample(sessionId: 'share-code');
    final source = initial.applyCommand(
      const MoveUnitCommand(
        factionId: 'humans',
        unitId: 'human-scout',
        x: 4,
        y: 1,
      ),
    );
    final snapshot = GameCodec.encodeGame(source);
    final snapshotCode = GameCodec.encodeShareCode(snapshot);
    final restoredSnapshot = GameCodec.decodeGame(snapshotCode);

    expect(GameCodec.isShareCode(snapshotCode), isTrue);
    expect(snapshotCode.startsWith(GameCodec.shareCodePrefix), isTrue);
    expect(snapshotCode.contains('{'), isFalse);
    expect(GameCodec.decodeShareCode(snapshot), snapshot);
    expect(GameReplay.hasSameState(restoredSnapshot, source), isTrue);

    final invite = GameCodec.encodeGameInvite(
      source.copyWith(
        factions: source.factions.map((faction) {
          if (faction.id == 'rebels') {
            return faction.copyWith(controlMode: Faction.controlRemote);
          }
          return faction;
        }).toList(),
      ),
      hostFactionId: 'humans',
      invitedFactionId: 'rebels',
    );
    final inviteCode = GameCodec.encodeShareCode(invite);
    final decodedInvite = GameCodec.decodeGameInvite(inviteCode);
    final invitedGame = GameCodec.decodeInvitedGame(inviteCode);

    expect(inviteCode.length, lessThan(invite.length));
    expect(decodedInvite.invitedFactionId, 'rebels');
    expect(invitedGame.factionById('rebels')!.isLocal, isTrue);

    final package = GameCodec.encodeCommandPackage(source);
    final packageCode = GameCodec.encodeShareCode(package);
    final decodedPackage = GameCodec.decodeCommandPackage(packageCode);
    final synced = GameCodec.applyCommandPackage(initial, decodedPackage);

    expect(decodedPackage.sessionId, source.sessionId);
    expect(decodedPackage.commands.length, source.commandHistory.length);
    expect(GameReplay.hasSameState(synced, source), isTrue);
  });

  test('multiplayer invites remap the invited faction to local control', () {
    final sample = OpenDeadlockGame.sample(sessionId: 'invite-session');
    final source = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id == 'rebels') {
          return faction.copyWith(controlMode: Faction.controlRemote);
        }
        return faction;
      }).toList(),
    );
    final encoded = GameCodec.encodeGameInvite(
      source,
      hostFactionId: 'humans',
      invitedFactionId: 'rebels',
    );
    final root = jsonDecode(encoded) as Map<String, dynamic>;
    final invite = GameCodec.decodeGameInvite(encoded);
    final joined = GameCodec.decodeInvitedGame(encoded);

    expect(root['kind'], GameCodec.inviteKind);
    expect(root['sessionId'], 'invite-session');
    expect(root['hostFactionId'], 'humans');
    expect(root['invitedFactionId'], 'rebels');
    expect(invite.invitedFactionName, 'Tarth Legion');
    expect(joined.sessionId, source.sessionId);
    expect(joined.factionById('rebels')!.isLocal, isTrue);
    expect(joined.factionById('humans')!.isRemote, isTrue);
    expect(
      GameCodec.fingerprintGame(joined),
      GameCodec.fingerprintGame(source),
    );
    expect(GameReplay.hasSameState(joined, source), isFalse);
  });

  test('order packages verify across invited player perspectives', () {
    final sample = OpenDeadlockGame.sample(sessionId: 'invite-sync');
    final source = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id == 'rebels') {
          return faction.copyWith(controlMode: Faction.controlRemote);
        }
        return faction;
      }).toList(),
    );
    final joined = GameCodec.decodeInvitedGame(
      GameCodec.encodeGameInvite(
        source,
        hostFactionId: 'humans',
        invitedFactionId: 'rebels',
      ),
    );
    final hostAfter = source.applyCommand(
      const MoveUnitCommand(
        factionId: 'humans',
        unitId: 'human-scout',
        x: 4,
        y: 1,
      ),
    );
    final package = GameCodec.decodeCommandPackage(
      GameCodec.encodeCommandPackage(hostAfter),
    );
    final preview = GameCodec.previewCommandPackage(joined, package);
    final synced = GameCodec.applyCommandPackage(joined, package);

    expect(preview.resultActiveControlMode, Faction.controlRemote);
    expect(preview.handoffLabel, 'Waiting for sync | Turn 1 | Human Assembly');
    expect(GameCodec.fingerprintGame(synced),
        GameCodec.fingerprintGame(hostAfter));
    expect(synced.factionById('rebels')!.isLocal, isTrue);
    expect(synced.factionById('humans')!.isRemote, isTrue);
    expect(synced.unitAt(4, 1)!.id, 'human-scout');
  });

  test('multiplayer invites reject tampered snapshots', () {
    final encoded = GameCodec.encodeGameInvite(
      OpenDeadlockGame.sample(sessionId: 'invite-tamper'),
      invitedFactionId: 'rebels',
    );
    final root = jsonDecode(encoded) as Map<String, dynamic>;
    root['stateFingerprint'] = '00000000';

    expect(
      () => GameCodec.decodeGameInvite(jsonEncode(root)),
      throwsArgumentError,
    );
  });

  test('order packages include sync metadata and command suffixes', () {
    final game = OpenDeadlockGame.sample()
        .applyCommand(
          const MoveUnitCommand(
            factionId: 'humans',
            unitId: 'human-scout',
            x: 4,
            y: 1,
          ),
        )
        .applyCommand(
          const SetColonyConstructionCommand(
            factionId: 'humans',
            colonyId: 'new-haven',
            construction: 'Factory',
          ),
        );
    final encoded = GameCodec.encodeCommandPackage(game, fromCommandIndex: 1);
    final root = jsonDecode(encoded) as Map<String, dynamic>;
    final package = GameCodec.decodeCommandPackage(encoded);

    expect(root['kind'], GameCodec.commandPackageKind);
    expect(root['sessionId'], game.sessionId);
    expect(root['exportedByFactionId'], 'humans');
    expect(root['baseCommandCount'], 1);
    expect(root['commandCount'], 2);
    expect(root['turn'], game.turn);
    expect(root['activeFactionId'], game.activeFactionId);
    expect(root['activeFactionName'], game.activeFaction.name);
    expect(
      root['baseCommandFingerprint'],
      GameCodec.fingerprintCommands(
        game.commandHistory.take(1).map((record) => record.command),
      ),
    );
    expect(
      root['commandFingerprint'],
      GameCodec.fingerprintCommands(
        game.commandHistory.map((record) => record.command),
      ),
    );
    expect(root['stateFingerprint'], GameCodec.fingerprintGame(game));
    expect(package.sessionId, game.sessionId);
    expect(package.exportedByFactionId, 'humans');
    expect(package.baseCommandCount, 1);
    expect(package.commandCount, 2);
    expect(package.turn, game.turn);
    expect(package.activeFactionId, game.activeFactionId);
    expect(package.activeFactionName, game.activeFaction.name);
    expect(package.baseCommandFingerprint, root['baseCommandFingerprint']);
    expect(package.commandFingerprint, root['commandFingerprint']);
    expect(package.commands.length, 1);
    final command = package.commands.single as SetColonyConstructionCommand;
    expect(command.construction, 'Factory');
  });

  test('order package previews distinguish new and duplicate orders', () {
    final initial = OpenDeadlockGame.sample(sessionId: 'preview-sync');
    final current = initial.applyCommand(
      const MoveUnitCommand(
        factionId: 'humans',
        unitId: 'human-scout',
        x: 4,
        y: 1,
      ),
    );
    final package =
        GameCodec.decodeCommandPackage(GameCodec.encodeCommandPackage(current));
    final firstPreview = GameCodec.previewCommandPackage(initial, package);
    final synced = GameCodec.applyCommandPackage(initial, package);
    final duplicatePreview = GameCodec.previewCommandPackage(synced, package);

    expect(firstPreview.sessionId, 'preview-sync');
    expect(firstPreview.exportedByFactionId, 'humans');
    expect(firstPreview.exportedByFactionName, 'Human Assembly');
    expect(firstPreview.baseCommandCount, 0);
    expect(firstPreview.localCommandCount, 0);
    expect(firstPreview.commandCount, 1);
    expect(firstPreview.overlapCommandCount, 0);
    expect(firstPreview.newCommandCount, 1);
    expect(firstPreview.hasNewCommands, isTrue);
    expect(firstPreview.summaryLabel, '1 new order from Human Assembly');
    expect(firstPreview.resultTurn, current.turn);
    expect(firstPreview.resultActiveFactionId, current.activeFactionId);
    expect(firstPreview.resultActiveFactionName, current.activeFaction.name);
    expect(firstPreview.resultActiveControlMode, Faction.controlLocal);
    expect(firstPreview.resultLabel, 'Turn 1 | Human Assembly');
    expect(firstPreview.handoffLabel, 'Your turn | Turn 1 | Human Assembly');
    expect(duplicatePreview.localCommandCount, 1);
    expect(duplicatePreview.overlapCommandCount, 1);
    expect(duplicatePreview.newCommandCount, 0);
    expect(duplicatePreview.hasNewCommands, isFalse);
    expect(duplicatePreview.summaryLabel, 'No new orders from Human Assembly');
  });

  test('order packages synchronize deterministic command history', () {
    final initial = OpenDeadlockGame.sample();
    final current = initial
        .applyCommand(
          const MoveUnitCommand(
            factionId: 'humans',
            unitId: 'human-scout',
            x: 4,
            y: 1,
          ),
        )
        .applyCommand(
          const EndTurnCommand(factionId: 'humans'),
        );
    final package =
        GameCodec.decodeCommandPackage(GameCodec.encodeCommandPackage(current));
    final synced = GameCodec.applyCommandPackage(initial, package);
    final syncedAgain = GameCodec.applyCommandPackage(synced, package);

    expect(GameReplay.hasSameState(synced, current), isTrue);
    expect(GameReplay.hasSameState(syncedAgain, current), isTrue);
    expect(syncedAgain.commandHistory.length, current.commandHistory.length);
  });

  test('order packages reject divergent command history', () {
    final initial = OpenDeadlockGame.sample();
    final source = initial.applyCommand(
      const MoveUnitCommand(
        factionId: 'humans',
        unitId: 'human-scout',
        x: 4,
        y: 1,
      ),
    );
    final divergent = initial.applyCommand(
      const SetColonyConstructionCommand(
        factionId: 'humans',
        colonyId: 'new-haven',
        construction: 'Factory',
      ),
    );
    final package =
        GameCodec.decodeCommandPackage(GameCodec.encodeCommandPackage(source));

    expect(() => GameCodec.applyCommandPackage(divergent, package),
        throwsArgumentError);
  });

  test('order packages reject mismatched sessions', () {
    final initial = OpenDeadlockGame.sample(sessionId: 'session-a');
    final source = initial.applyCommand(
      const MoveUnitCommand(
        factionId: 'humans',
        unitId: 'human-scout',
        x: 4,
        y: 1,
      ),
    );
    final otherSession = OpenDeadlockGame.sample(sessionId: 'session-b');
    final package =
        GameCodec.decodeCommandPackage(GameCodec.encodeCommandPackage(source));

    expect(() => GameCodec.applyCommandPackage(otherSession, package),
        throwsArgumentError);
  });

  test('order packages reject tampered final fingerprints', () {
    final initial = OpenDeadlockGame.sample();
    final source = initial.applyCommand(
      const MoveUnitCommand(
        factionId: 'humans',
        unitId: 'human-scout',
        x: 4,
        y: 1,
      ),
    );
    final root = jsonDecode(GameCodec.encodeCommandPackage(source))
        as Map<String, dynamic>;
    root['stateFingerprint'] = '00000000';
    final package = GameCodec.decodeCommandPackage(jsonEncode(root));

    expect(() => GameCodec.applyCommandPackage(initial, package),
        throwsArgumentError);
  });

  test('order packages reject tampered turn resolution metadata', () {
    final initial = OpenDeadlockGame.sample();
    final source = initial.applyCommand(
      const EndTurnCommand(factionId: 'humans'),
    );
    final root = jsonDecode(GameCodec.encodeCommandPackage(source))
        as Map<String, dynamic>;

    root['turn'] = source.turn + 1;
    expect(
      () => GameCodec.applyCommandPackage(
        initial,
        GameCodec.decodeCommandPackage(jsonEncode(root)),
      ),
      throwsArgumentError,
    );

    root['turn'] = source.turn;
    root['activeFactionId'] =
        source.activeFactionId == 'humans' ? 'rebels' : 'humans';
    expect(
      () => GameCodec.applyCommandPackage(
        initial,
        GameCodec.decodeCommandPackage(jsonEncode(root)),
      ),
      throwsArgumentError,
    );
  });

  test('model rejects out-of-turn player orders', () {
    final game = OpenDeadlockGame.sample();

    expect(
      () => game.applyCommand(
        const SetColonyConstructionCommand(
          factionId: 'rebels',
          colonyId: 'redoubt',
          construction: 'Factory',
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => game.applyCommand(
        const SetResearchProjectCommand(
          factionId: 'rebels',
          researchProject: 'Defense Grid',
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => game.applyCommand(
        const MoveUnitCommand(
          factionId: 'rebels',
          unitId: 'rebel-scout',
          x: 4,
          y: 3,
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => game.applyCommand(
        const FoundColonyCommand(
          factionId: 'rebels',
          unitId: 'rebel-scout',
          colonyId: 'rebels-outpost-5-3',
          name: 'Outpost 6-4',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('order packages reject out-of-turn remote orders', () {
    final game = OpenDeadlockGame.sample();
    const package = CommandPackage(
      sessionId: 'sample-skirmish',
      exportedByFactionId: 'rebels',
      baseCommandCount: 0,
      commandCount: 1,
      baseCommandFingerprint: '',
      commandFingerprint: '',
      stateFingerprint: 'ignored',
      commands: <GameCommand>[
        MoveUnitCommand(
          factionId: 'rebels',
          unitId: 'rebel-scout',
          x: 4,
          y: 3,
        ),
      ],
    );

    expect(() => GameCodec.applyCommandPackage(game, package),
        throwsArgumentError);
  });

  test('player can move a scout and claim neutral ground', () {
    final game = OpenDeadlockGame.sample();
    expect(game.tileAt(4, 1).isExploredBy('humans'), isFalse);
    expect(game.tileAt(4, 1).isExploredBy('rebels'), isFalse);
    expect(
        OpenDeadlockGame.movementCostForTerrain(game.tileAt(4, 1).terrain), 2);

    final updated = game.applyCommand(
      const MoveUnitCommand(
        factionId: 'humans',
        unitId: 'human-scout',
        x: 4,
        y: 1,
      ),
    );

    expect(updated.unitAt(4, 1)!.id, 'human-scout');
    expect(updated.unitAt(4, 1)!.movesRemaining, 0);
    expect(updated.tileAt(4, 1).ownerId, 'humans');
    expect(updated.tileAt(4, 1).explored, isTrue);
    expect(updated.tileAt(4, 1).isExploredBy('humans'), isTrue);
    expect(updated.tileAt(4, 1).isExploredBy('rebels'), isFalse);
    expect(updated.commandHistory.single.command.type,
        MoveUnitCommand.commandType);
    expect(updated.reports.first.title, 'Survey Team moved');
  });

  test('peace allows movement through controlled empty sectors', () {
    final sample = OpenDeadlockGame.sample();
    final passageSector = sample.copyWith(
      tiles: sample.tiles.map((tile) {
        if (tile.x != 4 || tile.y != 1) {
          return tile;
        }
        return tile.copyWith(
          ownerId: 'rebels',
          explored: true,
          exploredBy: const <String>['humans', 'rebels'],
        );
      }).toList(),
    );
    final peace = passageSector.applyCommand(
      const SetDiplomacyStatusCommand(
        factionId: 'humans',
        targetFactionId: 'rebels',
        status: OpenDeadlockGame.diplomacyStatusPeace,
      ),
    );
    final updated = peace.applyCommand(
      const MoveUnitCommand(
        factionId: 'humans',
        unitId: 'human-scout',
        x: 4,
        y: 1,
      ),
    );

    expect(
        passageSector.canFactionTraverseSector(
            'humans', passageSector.tileAt(4, 1)),
        isFalse);
    expect(
        peace.canFactionTraverseSector('humans', peace.tileAt(4, 1)), isTrue);
    expect(updated.unitAt(4, 1)!.id, 'human-scout');
    expect(updated.tileAt(4, 1).ownerId, 'rebels');
    expect(updated.tileAt(4, 1).isExploredBy('humans'), isTrue);
    expect(updated.reports.first.title, 'Survey Team moved');
  });

  test('war blocks movement into controlled empty sectors', () {
    final sample = OpenDeadlockGame.sample();
    final game = sample.copyWith(
      tiles: sample.tiles.map((tile) {
        if (tile.x != 4 || tile.y != 1) {
          return tile;
        }
        return tile.copyWith(
          ownerId: 'rebels',
          explored: true,
          exploredBy: const <String>['humans', 'rebels'],
        );
      }).toList(),
    );

    expect(game.canFactionTraverseSector('humans', game.tileAt(4, 1)), isFalse);
    expect(
      () => game.applyCommand(
        const MoveUnitCommand(
          factionId: 'humans',
          unitId: 'human-scout',
          x: 4,
          y: 1,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('scouts can spend movement across multiple low-cost sectors', () {
    final game = OpenDeadlockGame.sample();
    expect(game.tileAt(2, 1).terrain, 'ruins');
    expect(game.tileAt(3, 1).terrain, 'plains');

    final firstMove = game.applyCommand(
      const MoveUnitCommand(
        factionId: 'humans',
        unitId: 'human-scout',
        x: 2,
        y: 1,
      ),
    );
    final secondMove = firstMove.applyCommand(
      const MoveUnitCommand(
        factionId: 'humans',
        unitId: 'human-scout',
        x: 3,
        y: 1,
      ),
    );

    expect(firstMove.unitById('human-scout').movesRemaining, 1);
    expect(secondMove.unitById('human-scout').x, 3);
    expect(secondMove.unitById('human-scout').movesRemaining, 0);
    expect(secondMove.commandHistory.length, 2);
  });

  test('infantry cannot enter high-cost terrain without enough movement', () {
    final sample = OpenDeadlockGame.sample();
    final infantryGame = sample.copyWith(
      units: <Unit>[
        const Unit(
          id: 'human-infantry',
          name: 'Human Infantry',
          ownerId: 'humans',
          type: 'infantry',
          x: 3,
          y: 1,
          movesRemaining: 1,
          health: 8,
        ),
        sample.unitById('rebel-scout'),
      ],
    );

    expect(infantryGame.tileAt(4, 1).terrain, 'forest');
    expect(
      () => infantryGame.applyCommand(
        const MoveUnitCommand(
          factionId: 'humans',
          unitId: 'human-infantry',
          x: 4,
          y: 1,
        ),
      ),
      throwsArgumentError,
    );

    final moved = infantryGame.applyCommand(
      const MoveUnitCommand(
        factionId: 'humans',
        unitId: 'human-infantry',
        x: 2,
        y: 1,
      ),
    );
    expect(moved.unitById('human-infantry').movesRemaining, 0);
  });

  test('unit attacks adjacent enemy and both units can survive', () {
    final sample = OpenDeadlockGame.sample();
    final game = sample.copyWith(
      units: <Unit>[
        sample.unitById('human-scout').copyWith(x: 4, y: 3),
        sample.unitById('rebel-scout').copyWith(x: 5, y: 3),
      ],
    );
    final updated = game.applyCommand(
      const MoveUnitCommand(
        factionId: 'humans',
        unitId: 'human-scout',
        x: 5,
        y: 3,
      ),
    );

    expect(updated.unitById('human-scout').x, 4);
    expect(updated.unitById('human-scout').health, 2);
    expect(updated.unitById('human-scout').movesRemaining, 0);
    expect(updated.unitById('rebel-scout').health, 3);
    expect(updated.unitById('rebel-scout').movesRemaining, 0);
    expect(updated.tileAt(5, 3).ownerId, 'rebels');
    expect(updated.reports.first.title, 'Survey Team attacked Pact Recon');
    expect(updated.reports.first.isBattle, isTrue);
    expect(updated.reports.first.details['kind'], 'unit');
    expect(updated.reports.first.details['attackerId'], 'human-scout');
    expect(updated.reports.first.details['defenderId'], 'rebel-scout');
    expect(updated.reports.first.details['attackDamage'], '2');
    expect(updated.reports.first.details['counterDamage'], '3');
    expect(updated.reports.first.details['attackerHealth'], '2');
    expect(updated.reports.first.details['defenderHealth'], '3');
  });

  test('unit combat preview matches deterministic combat damage', () {
    final sample = OpenDeadlockGame.sample();
    final game = sample.copyWith(
      units: <Unit>[
        sample.unitById('human-scout').copyWith(x: 4, y: 3),
        sample.unitById('rebel-scout').copyWith(x: 5, y: 3),
      ],
    );
    final preview = game.previewUnitCombat(
      game.unitById('human-scout'),
      game.unitById('rebel-scout'),
    );

    expect(preview.attackDamage, 2);
    expect(preview.counterDamage, 3);
    expect(preview.attackerHealth, 2);
    expect(preview.defenderHealth, 3);
    expect(preview.attackerSurvives, isTrue);
    expect(preview.defenderSurvives, isTrue);
  });

  test('peace prevents unit combat', () {
    final sample = OpenDeadlockGame.sample();
    final game = sample.copyWith(
      units: <Unit>[
        sample.unitById('human-scout').copyWith(x: 4, y: 3),
        sample.unitById('rebel-scout').copyWith(x: 5, y: 3),
      ],
    ).applyCommand(
      const SetDiplomacyStatusCommand(
        factionId: 'humans',
        targetFactionId: 'rebels',
        status: OpenDeadlockGame.diplomacyStatusPeace,
      ),
    );

    expect(
      () => game.applyCommand(
        const MoveUnitCommand(
          factionId: 'humans',
          unitId: 'human-scout',
          x: 5,
          y: 3,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('unit captures a sector after defeating its defender', () {
    final sample = OpenDeadlockGame.sample();
    final game = sample.copyWith(
      units: <Unit>[
        sample.unitById('human-scout').copyWith(x: 4, y: 3),
        sample.unitById('rebel-scout').copyWith(x: 5, y: 3, health: 2),
      ],
    );
    final updated = game.applyCommand(
      const MoveUnitCommand(
        factionId: 'humans',
        unitId: 'human-scout',
        x: 5,
        y: 3,
      ),
    );

    expect(updated.unitAt(5, 3)!.id, 'human-scout');
    expect(updated.unitById('human-scout').health, 5);
    expect(updated.tileAt(5, 3).ownerId, 'humans');
    expect(updated.units.where((unit) => unit.id == 'rebel-scout'), isEmpty);
    expect(updated.reports.first.title, 'Survey Team defeated Pact Recon');
  });

  test('colony assault can be repelled by defenses', () {
    final sample = OpenDeadlockGame.sample();
    final game = sample.copyWith(
      units: <Unit>[
        sample.unitById('human-scout').copyWith(x: 5, y: 3),
      ],
    );
    final updated = game.applyCommand(
      const MoveUnitCommand(
        factionId: 'humans',
        unitId: 'human-scout',
        x: 6,
        y: 3,
      ),
    );
    final colony = updated.colonyAt(6, 3)!;

    expect(OpenDeadlockGame.colonyDefenseFor(sample.colonyAt(6, 3)!), 5);
    expect(updated.unitById('human-scout').x, 5);
    expect(updated.unitById('human-scout').health, 1);
    expect(updated.unitById('human-scout').movesRemaining, 0);
    expect(colony.ownerId, 'rebels');
    expect(colony.morale, lessThan(sample.colonyAt(6, 3)!.morale));
    expect(updated.tileAt(6, 3).ownerId, 'rebels');
    expect(updated.reports.first.title, 'Redoubt repelled Survey Team');
    expect(updated.reports.first.isBattle, isTrue);
    expect(updated.reports.first.details['kind'], 'colony');
    expect(updated.reports.first.details['colonyId'], 'redoubt');
    expect(updated.reports.first.details['colonyCaptured'], 'false');
  });

  test('colony assault preview reports capture and survival outcome', () {
    final sample = OpenDeadlockGame.sample();
    final weakenedColonies = sample.colonies.map((colony) {
      if (colony.id != 'redoubt') {
        return colony;
      }
      return colony.copyWith(population: 1, morale: 20);
    }).toList();
    final game = sample.copyWith(
      colonies: weakenedColonies,
      units: <Unit>[
        sample.unitById('human-scout').copyWith(x: 5, y: 3),
      ],
    );
    final preview = game.previewColonyAssault(
      game.unitById('human-scout'),
      game.colonyById('redoubt'),
    );

    expect(preview.attackPower, 5);
    expect(preview.defensePower, 3);
    expect(preview.counterDamage, 1);
    expect(preview.attackerHealth, 4);
    expect(preview.attackerSurvives, isTrue);
    expect(preview.colonyCaptured, isTrue);
    expect(preview.population, 1);
    expect(preview.morale, 45);
  });

  test('peace prevents colony assaults', () {
    final sample = OpenDeadlockGame.sample();
    final weakenedColonies = sample.colonies.map((colony) {
      if (colony.id != 'redoubt') {
        return colony;
      }
      return colony.copyWith(population: 1, morale: 20);
    }).toList();
    final game = sample.copyWith(
      colonies: weakenedColonies,
      units: <Unit>[
        sample.unitById('human-scout').copyWith(x: 5, y: 3),
      ],
    ).applyCommand(
      const SetDiplomacyStatusCommand(
        factionId: 'humans',
        targetFactionId: 'rebels',
        status: OpenDeadlockGame.diplomacyStatusPeace,
      ),
    );

    expect(
      () => game.applyCommand(
        const MoveUnitCommand(
          factionId: 'humans',
          unitId: 'human-scout',
          x: 6,
          y: 3,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('colony assault captures weakened colonies', () {
    final sample = OpenDeadlockGame.sample();
    final weakenedColonies = sample.colonies.map((colony) {
      if (colony.id != 'redoubt') {
        return colony;
      }
      return colony.copyWith(population: 1, morale: 20);
    }).toList();
    final game = sample.copyWith(
      colonies: weakenedColonies,
      units: <Unit>[
        sample.unitById('human-scout').copyWith(x: 5, y: 3),
      ],
    );
    final updated = game.applyCommand(
      const MoveUnitCommand(
        factionId: 'humans',
        unitId: 'human-scout',
        x: 6,
        y: 3,
      ),
    );
    final colony = updated.colonyAt(6, 3)!;

    expect(colony.ownerId, 'humans');
    expect(colony.population, 1);
    expect(colony.morale, 45);
    expect(colony.storedIndustry, 0);
    expect(updated.tileAt(6, 3).ownerId, 'humans');
    expect(updated.unitAt(6, 3)!.id, 'human-scout');
    expect(updated.unitById('human-scout').health, 4);
    expect(updated.commandHistory.single.command.type,
        MoveUnitCommand.commandType);
    expect(updated.winningFactionId, 'humans');
    expect(updated.winningFaction!.name, 'Human Assembly');
    expect(updated.isGameOver, isTrue);
    expect(updated.reports.first.title, 'Human Assembly wins');
    expect(updated.reports[1].title, 'Survey Team captured Redoubt');
    expect(updated.reports[1].isBattle, isTrue);
    expect(updated.reports[1].details['kind'], 'colony');
    expect(updated.reports[1].details['colonyCaptured'], 'true');
    expect(updated.reports[1].details['population'], '1');
    expect(updated.reports[1].details['morale'], '45');
    expect(updated.reports[1].details['capturedAssignedSectors'], '0');
    expect(updated.reports[2].title, 'Tarth Legion defeated');
    expect(updated.reports[2].message,
        'Tarth Legion has no colonies or units remaining.');
  });

  test('colony capture transfers assigned work sectors', () {
    final sample = OpenDeadlockGame.sample();
    final game = sample.copyWith(
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'redoubt') {
          return colony;
        }
        return colony.copyWith(
          population: 4,
          morale: 20,
          assignedSectors: const <SectorAssignment>[
            SectorAssignment(x: 6, y: 4),
          ],
        );
      }).toList(),
      units: <Unit>[
        const Unit(
          id: 'human-armor',
          name: 'Human Armor',
          ownerId: 'humans',
          type: 'armor',
          x: 5,
          y: 3,
          movesRemaining: 2,
          health: 10,
        ),
      ],
    );

    final updated = game.applyCommand(
      const MoveUnitCommand(
        factionId: 'humans',
        unitId: 'human-armor',
        x: 6,
        y: 3,
      ),
    );
    final capturedColony = updated.colonyById('redoubt');
    final production = updated.colonyProductionFor(capturedColony);

    expect(game.tileAt(6, 4).ownerId, 'rebels');
    expect(capturedColony.ownerId, 'humans');
    expect(capturedColony.assignedSectors.single.matches(6, 4), isTrue);
    expect(updated.tileAt(6, 4).ownerId, 'humans');
    expect(updated.tileAt(6, 4).isExploredBy('humans'), isTrue);
    expect(updated.assignedColonyForSector(6, 4)!.id, 'redoubt');
    expect(production.workedSectors, 2);
    expect(updated.reports[1].details['capturedAssignedSectors'], '1');
  });

  test('eliminating a faction reports defeat without ending the game', () {
    final game = _eliminationBattleFixture();
    final updated = game.applyCommand(
      const MoveUnitCommand(
        factionId: 'humans',
        unitId: 'human-scout',
        x: 6,
        y: 3,
      ),
    );

    expect(updated.isGameOver, isFalse);
    expect(updated.isFactionDefeated('rebels'), isTrue);
    expect(updated.factionHasPresence('traders'), isTrue);
    expect(updated.reports.first.title, 'Survey Team captured Redoubt');
    expect(updated.reports[1].title, 'Tarth Legion defeated');
    expect(updated.reports[1].message,
        'Tarth Legion has no colonies or units remaining.');

    final next = updated.applyCommand(
      const EndTurnCommand(factionId: 'humans'),
    );

    expect(next.activeFactionId, 'traders');
    expect(
      next.reports.where((report) => report.title == 'Tarth Legion defeated'),
      hasLength(1),
    );
  });

  test('game over rejects later commands and stops turn advancement', () {
    final sample = OpenDeadlockGame.sample();
    final weakenedColonies = sample.colonies.map((colony) {
      if (colony.id != 'redoubt') {
        return colony;
      }
      return colony.copyWith(population: 1, morale: 20);
    }).toList();
    final game = sample.copyWith(
      colonies: weakenedColonies,
      units: <Unit>[
        sample.unitById('human-scout').copyWith(x: 5, y: 3),
      ],
    );
    final winner = game.applyCommand(
      const MoveUnitCommand(
        factionId: 'humans',
        unitId: 'human-scout',
        x: 6,
        y: 3,
      ),
    );

    expect(
      () => winner.applyCommand(const EndTurnCommand(factionId: 'humans')),
      throwsArgumentError,
    );
    expect(winner.advanceTurn(), same(winner));
  });

  test('computer victory during end turn is reported once', () {
    final sample = OpenDeadlockGame.sample();
    final weakenedColonies = sample.colonies.map((colony) {
      if (colony.id != 'new-haven') {
        return colony;
      }
      return colony.copyWith(population: 1, morale: 20);
    }).toList();
    final game = sample.copyWith(
      colonies: weakenedColonies,
      units: <Unit>[
        sample.unitById('rebel-scout').copyWith(x: 3, y: 2),
      ],
    );
    final winner = game.applyCommand(
      const EndTurnCommand(factionId: 'humans'),
    );

    expect(winner.winningFactionId, 'rebels');
    expect(winner.isGameOver, isTrue);
    expect(winner.commandHistory.length, 1);
    expect(
        winner.commandHistory.single.command.type, EndTurnCommand.commandType);
    expect(winner.reports.first.title, 'Tarth Legion wins');
    expect(
      winner.reports.where((report) => report.title == 'Tarth Legion wins'),
      hasLength(1),
    );
  });

  test('turn advancement skips defeated factions', () {
    final game = _defeatedMiddleFactionFixture();
    final next = game.applyCommand(
      const EndTurnCommand(factionId: 'humans'),
    );

    expect(game.factionHasPresence('humans'), isTrue);
    expect(game.factionHasPresence('rebels'), isFalse);
    expect(game.isFactionDefeated('rebels'), isTrue);
    expect(game.factionHasPresence('traders'), isTrue);
    expect(game.isGameOver, isFalse);
    expect(next.activeFactionId, 'traders');
    expect(next.turn, 1);
    expect(next.commandHistory.single.command.type, EndTurnCommand.commandType);
  });

  test('turn advancement skips defeated factions when round wraps', () {
    final game = _defeatedMiddleFactionFixture().copyWith(
      activeFactionId: 'traders',
    );
    final next = game.applyCommand(
      const EndTurnCommand(factionId: 'traders'),
    );

    expect(next.activeFactionId, 'humans');
    expect(next.turn, 2);
    expect(next.colonyById('new-haven').storedIndustry,
        greaterThan(game.colonyById('new-haven').storedIndustry));
    expect(next.commandHistory.single.command.type, EndTurnCommand.commandType);
  });

  test('player can found a colony with a scout on controlled ground', () {
    final moved = OpenDeadlockGame.sample().applyCommand(
      const MoveUnitCommand(
        factionId: 'humans',
        unitId: 'human-scout',
        x: 4,
        y: 1,
      ),
    );
    final updated = moved.applyCommand(
      const FoundColonyCommand(
        factionId: 'humans',
        unitId: 'human-scout',
        colonyId: 'humans-outpost-4-1',
        name: 'Outpost 5-2',
      ),
    );

    expect(updated.colonyAt(4, 1)!.id, 'humans-outpost-4-1');
    expect(updated.colonyAt(4, 1)!.population, 1);
    expect(updated.tileAt(4, 1).colonyId, 'humans-outpost-4-1');
    expect(updated.unitAt(4, 1), isNull);
    expect(updated.commandHistory.length, 2);
    expect(updated.commandHistory.last.command.type,
        FoundColonyCommand.commandType);
    expect(updated.reports.first.title, 'Outpost 5-2 founded');
  });

  test('founding rejects invalid colony sites', () {
    final game = OpenDeadlockGame.sample();

    expect(
      () => game.applyCommand(
        const FoundColonyCommand(
          factionId: 'rebels',
          unitId: 'human-scout',
          colonyId: 'bad-outpost',
          name: 'Bad Outpost',
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => game.applyCommand(
        const FoundColonyCommand(
          factionId: 'humans',
          unitId: 'human-scout',
          colonyId: 'new-haven',
          name: 'Duplicate',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('movement rejects illegal targets', () {
    final game = OpenDeadlockGame.sample();

    expect(
      () => game.applyCommand(
        const MoveUnitCommand(
          factionId: 'rebels',
          unitId: 'human-scout',
          x: 4,
          y: 1,
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => game.applyCommand(
        const MoveUnitCommand(
          factionId: 'humans',
          unitId: 'human-scout',
          x: 4,
          y: 2,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('turn advancement resets moves by unit type', () {
    final sample = OpenDeadlockGame.sample();
    final spent = sample.copyWith(
      units: <Unit>[
        sample.unitById('human-scout').copyWith(movesRemaining: 0),
        const Unit(
          id: 'human-infantry',
          name: 'Human Infantry',
          ownerId: 'humans',
          type: 'infantry',
          x: 2,
          y: 1,
          movesRemaining: 0,
          health: 8,
        ),
        const Unit(
          id: 'human-armor',
          name: 'Human Armor',
          ownerId: 'humans',
          type: 'armor',
          x: 2,
          y: 3,
          movesRemaining: 0,
          health: 10,
        ),
        sample.unitById('rebel-scout').copyWith(movesRemaining: 0),
      ],
    );
    final next = spent.endTurn();

    expect(next.unitById('human-scout').movesRemaining,
        OpenDeadlockGame.maxMovesFor('scout'));
    expect(next.unitById('rebel-scout').movesRemaining,
        OpenDeadlockGame.maxMovesFor('scout'));
    expect(next.unitById('human-infantry').movesRemaining,
        OpenDeadlockGame.maxMovesFor('infantry'));
    expect(next.unitById('human-armor').movesRemaining,
        OpenDeadlockGame.maxMovesFor('armor'));
  });

  test('construction orders reject unknown targets', () {
    final game = OpenDeadlockGame.sample();

    expect(() => game.setColonyConstruction('missing', 'Factory'),
        throwsArgumentError);
    expect(() => game.setColonyConstruction('new-haven', 'Orbital Elevator'),
        throwsArgumentError);
    expect(() => game.setColonyConstruction('new-haven', 'Infantry Company'),
        throwsArgumentError);
    expect(() => game.setColonyConstruction('new-haven', 'Armor Company'),
        throwsArgumentError);
    expect(
      () => game
          .endTurn()
          .endTurn()
          .setColonyConstruction('new-haven', 'Colony Hub'),
      throwsArgumentError,
    );
    expect(
      () => game.applyCommand(
        const SetColonyConstructionCommand(
          factionId: 'rebels',
          colonyId: 'new-haven',
          construction: 'Factory',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('computer factions plan deterministic construction commands', () {
    final game = OpenDeadlockGame.sample();
    final commands = game.planComputerCommands();

    expect(commands.length, 8);
    final researchCommand = commands.first as SetResearchProjectCommand;
    expect(researchCommand.factionId, 'rebels');
    expect(researchCommand.researchProject, 'Defense Grid');
    final scanCommand = commands.whereType<ScanFactionIntelCommand>().single;
    expect(scanCommand.factionId, 'rebels');
    expect(scanCommand.targetFactionId, 'humans');
    final sabotageCommand = commands.whereType<SabotageColonyCommand>().single;
    expect(sabotageCommand.factionId, 'rebels');
    expect(sabotageCommand.targetFactionId, 'humans');
    final focusCommand = commands.whereType<SetColonyFocusCommand>().single;
    expect(focusCommand.factionId, 'rebels');
    expect(focusCommand.colonyId, 'redoubt');
    expect(focusCommand.focus, OpenDeadlockGame.colonyFocusIndustry);
    expect(commands.whereType<SetColonySectorAssignmentCommand>().length, 3);

    expect(commands.whereType<FoundColonyCommand>(), isEmpty);
    final moveCommand = commands.whereType<MoveUnitCommand>().single;
    expect(moveCommand.factionId, 'rebels');
    expect(moveCommand.unitId, 'rebel-scout');
    expect(_distance(moveCommand.x, moveCommand.y, 2, 2),
        lessThan(_distance(5, 3, 2, 2)));
  });

  test('computer scouts avoid founding cramped outposts', () {
    final sample = OpenDeadlockGame.sample();
    final game = sample.copyWith(
      activeFactionId: 'rebels',
      factions: sample.factions.map((faction) {
        if (faction.id != 'rebels') {
          return faction;
        }
        return faction.copyWith(
          raceId: 'human',
          aiPersonality: Faction.aiPersonalityAdaptive,
          traitIds: const <String>[],
        );
      }).toList(),
      tiles: sample.tiles.map((tile) {
        if (tile.x == 5 && tile.y == 3) {
          return _testTile(
            tile,
            terrain: 'ruins',
            yields: const TileYield(food: 5, industry: 5, research: 5),
            ownerId: 'rebels',
            exploredBy: const <String>['rebels'],
          );
        }
        return tile;
      }).toList(),
      units: <Unit>[
        sample.unitById('rebel-scout').copyWith(x: 5, y: 3),
      ],
    );
    final commands = game.planComputerCommandsFor('rebels');

    expect(
        _distance(
            5, 3, game.colonyById('redoubt').x, game.colonyById('redoubt').y),
        1);
    expect(commands.whereType<FoundColonyCommand>(), isEmpty);
  });

  test('computer scouts found colonies on valuable frontier sites', () {
    final sample = OpenDeadlockGame.sample();
    final game = sample.copyWith(
      activeFactionId: 'rebels',
      tiles: sample.tiles.map((tile) {
        if (tile.x == 4 && tile.y == 5) {
          return _testTile(
            tile,
            terrain: 'plains',
            yields: const TileYield(food: 3, industry: 3, research: 2),
            ownerId: 'rebels',
            exploredBy: const <String>['rebels'],
          );
        }
        return tile;
      }).toList(),
      units: <Unit>[
        sample.unitById('rebel-scout').copyWith(x: 4, y: 5),
      ],
    );
    final commands = game.planComputerCommandsFor('rebels');
    final foundCommand = commands.whereType<FoundColonyCommand>().single;
    final updated = game.applyCommand(foundCommand);

    expect(
        _distance(
            4, 5, game.colonyById('redoubt').x, game.colonyById('redoubt').y),
        4);
    expect(foundCommand.factionId, 'rebels');
    expect(foundCommand.unitId, 'rebel-scout');
    expect(foundCommand.colonyId, 'rebels-outpost-4-5');
    expect(foundCommand.name, 'Outpost 5-6');
    expect(updated.colonyAt(4, 5)!.ownerId, 'rebels');
  });

  test('computer scouts move toward viable expansion sites', () {
    final sample = OpenDeadlockGame.sample();
    final game = sample.copyWith(
      activeFactionId: 'rebels',
      tiles: sample.tiles.map((tile) {
        if (tile.x == 5 && tile.y == 4) {
          return _testTile(
            tile,
            terrain: 'plains',
            yields: const TileYield(food: 8, industry: 8, research: 8),
            ownerId: 'rebels',
            exploredBy: const <String>['rebels'],
          );
        }
        if (tile.x == 4 && tile.y == 5) {
          return _testTile(
            tile,
            terrain: 'plains',
            yields: const TileYield(food: 3, industry: 3, research: 2),
            exploredBy: const <String>['rebels'],
          );
        }
        if ((tile.x == 4 && tile.y == 3) || (tile.x == 3 && tile.y == 4)) {
          return _testTile(
            tile,
            terrain: 'water',
            yields: tile.yields,
            exploredBy: const <String>['rebels'],
          );
        }
        return tile;
      }).toList(),
      units: <Unit>[
        sample.unitById('rebel-scout').copyWith(x: 4, y: 4),
      ],
      diplomacy: const <DiplomacyRelation>[
        DiplomacyRelation(
          factionAId: 'humans',
          factionBId: 'rebels',
          status: OpenDeadlockGame.diplomacyStatusPeace,
        ),
      ],
    );
    final commands = game.planComputerCommandsFor('rebels');
    final moveCommand = commands.whereType<MoveUnitCommand>().single;

    expect(
        _distance(
            5, 4, game.colonyById('redoubt').x, game.colonyById('redoubt').y),
        2);
    expect(
        _distance(
            4, 5, game.colonyById('redoubt').x, game.colonyById('redoubt').y),
        4);
    expect(moveCommand.factionId, 'rebels');
    expect(moveCommand.unitId, 'rebel-scout');
    expect(moveCommand.x, 4);
    expect(moveCommand.y, 5);
  });

  test('computer factions scan when wartime targets are hidden', () {
    final game = OpenDeadlockGame.sample().copyWith(activeFactionId: 'rebels');
    final commands = game.planComputerCommandsFor('rebels');
    final scanCommand = commands.whereType<ScanFactionIntelCommand>().single;
    final updated = game.applyCommands(<GameCommand>[scanCommand]);

    expect(game.tileAt(2, 2).isExploredBy('rebels'), isFalse);
    expect(scanCommand.factionId, 'rebels');
    expect(scanCommand.targetFactionId, 'humans');
    expect(updated.tileAt(2, 2).isExploredBy('rebels'), isTrue);
    expect(updated.worldSummaryFor('rebels').visibleEnemyColonies, 1);
  });

  test('computer factions do not scan when wartime targets are known', () {
    final game = _strategicMovementFixture();
    final scanCommands = game
        .planComputerCommandsFor('rebels')
        .whereType<ScanFactionIntelCommand>();

    expect(game.tileAt(2, 2).isExploredBy('rebels'), isTrue);
    expect(scanCommands, isEmpty);
  });

  test('faction traits guide computer construction preferences', () {
    final sample = OpenDeadlockGame.sample();
    final scholarOpponent = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id != 'rebels') {
          return faction;
        }
        return faction.copyWith(
          raceId: 'human',
          aiPersonality: Faction.aiPersonalityAdaptive,
          traitIds: const <String>['scholars'],
        );
      }).toList(),
    );
    final commands = scholarOpponent.planComputerCommands();
    final constructionCommand =
        commands.whereType<SetColonyConstructionCommand>().single;

    expect(constructionCommand.factionId, 'rebels');
    expect(constructionCommand.colonyId, 'redoubt');
    expect(constructionCommand.construction, 'Research Lab');
  });

  test('computer colonies prioritize militia when visible enemies approach',
      () {
    final sample = OpenDeadlockGame.sample();
    final threatenedScholar = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id != 'rebels') {
          return faction;
        }
        return faction.copyWith(
          raceId: 'human',
          aiPersonality: Faction.aiPersonalityAdaptive,
          traitIds: const <String>['scholars'],
        );
      }).toList(),
      units: <Unit>[
        sample.unitById('human-scout').copyWith(x: 5, y: 3),
      ],
    );
    final commands = threatenedScholar.planComputerCommandsFor('rebels');
    final constructionCommand =
        commands.whereType<SetColonyConstructionCommand>().single;

    expect(threatenedScholar.tileAt(5, 3).isExploredBy('rebels'), isTrue);
    expect(constructionCommand.factionId, 'rebels');
    expect(constructionCommand.colonyId, 'redoubt');
    expect(constructionCommand.construction, 'Militia Post');
  });

  test('computer colonies harden exposed construction against sabotage', () {
    final exposed = _sabotageExposedScholarOpponent();
    final commands = exposed.planComputerCommandsFor('rebels');
    final constructionCommand =
        commands.whereType<SetColonyConstructionCommand>().single;

    expect(exposed.tileAt(6, 3).isExploredBy('humans'), isTrue);
    expect(exposed.sabotageDamageForColony(exposed.colonyById('redoubt')), 8);
    expect(constructionCommand.factionId, 'rebels');
    expect(constructionCommand.colonyId, 'redoubt');
    expect(constructionCommand.construction, 'Militia Post');
  });

  test('computer colonies continue security hardening against sabotage', () {
    final exposed = _sabotageExposedScholarOpponent(
      completedBuildings: const <String>['Militia Post'],
    );
    final commands = exposed.planComputerCommandsFor('rebels');
    final constructionCommand =
        commands.whereType<SetColonyConstructionCommand>().single;

    expect(exposed.sabotageDamageForColony(exposed.colonyById('redoubt')), 6);
    expect(constructionCommand.factionId, 'rebels');
    expect(constructionCommand.colonyId, 'redoubt');
    expect(constructionCommand.construction, 'Barracks');
  });

  test('computer colonies resume normal builds when sabotage is fully blocked',
      () {
    final hardened = _sabotageExposedScholarOpponent(
      construction: 'Scout Patrol',
      completedBuildings: const <String>['Militia Post', 'Barracks'],
      completedResearch: const <String>['Defense Grid'],
    );
    final commands = hardened.planComputerCommandsFor('rebels');
    final constructionCommand =
        commands.whereType<SetColonyConstructionCommand>().single;

    expect(hardened.sabotageDamageForColony(hardened.colonyById('redoubt')), 0);
    expect(constructionCommand.factionId, 'rebels');
    expect(constructionCommand.colonyId, 'redoubt');
    expect(constructionCommand.construction, 'Research Lab');
  });

  test('computer colonies train infantry when threatened after barracks', () {
    final sample = OpenDeadlockGame.sample();
    final fortified = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id != 'rebels') {
          return faction;
        }
        return faction.copyWith(
          raceId: 'human',
          aiPersonality: Faction.aiPersonalityAdaptive,
          traitIds: const <String>['scholars'],
        );
      }).toList(),
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'redoubt') {
          return colony;
        }
        return colony.copyWith(
          construction: 'Research Lab',
          completedBuildings: const <String>['Militia Post', 'Barracks'],
        );
      }).toList(),
      units: <Unit>[
        sample.unitById('human-scout').copyWith(x: 5, y: 3),
      ],
    );
    final commands = fortified.planComputerCommandsFor('rebels');
    final constructionCommand =
        commands.whereType<SetColonyConstructionCommand>().single;

    expect(constructionCommand.factionId, 'rebels');
    expect(constructionCommand.colonyId, 'redoubt');
    expect(constructionCommand.construction, 'Infantry Company');
  });

  test('computer colonies prioritize riot suppression buildings', () {
    final sample = OpenDeadlockGame.sample();
    final riotingOpponent = sample.copyWith(
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'redoubt') {
          return colony;
        }
        return colony.copyWith(
          morale: 10,
          construction: 'Farm Dome',
        );
      }).toList(),
    );
    final commands = riotingOpponent.planComputerCommands();
    final constructionCommand =
        commands.whereType<SetColonyConstructionCommand>().single;

    expect(constructionCommand.factionId, 'rebels');
    expect(constructionCommand.colonyId, 'redoubt');
    expect(constructionCommand.construction, 'Militia Post');
  });

  test('computer factions build housing at population capacity', () {
    final sample = OpenDeadlockGame.sample();
    final capped = sample.copyWith(
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'redoubt') {
          return colony;
        }
        return colony.copyWith(
          population: OpenDeadlockGame.basePopulationCapacity,
        );
      }).toList(),
    );
    final commands = capped.planComputerCommands();
    final constructionCommand =
        commands.whereType<SetColonyConstructionCommand>().single;

    expect(constructionCommand.factionId, 'rebels');
    expect(constructionCommand.colonyId, 'redoubt');
    expect(constructionCommand.construction, 'Housing');
  });

  test('computer factions upgrade housing tiers at expanded capacity', () {
    final sample = OpenDeadlockGame.sample();
    final capped = sample.copyWith(
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'redoubt') {
          return colony;
        }
        return colony.copyWith(
          population: OpenDeadlockGame.basePopulationCapacity +
              OpenDeadlockGame.housingPopulationCapacityBonus,
          completedBuildings: const <String>['Housing'],
        );
      }).toList(),
    );
    final commands = capped.planComputerCommands();
    final constructionCommand =
        commands.whereType<SetColonyConstructionCommand>().single;

    expect(constructionCommand.factionId, 'rebels');
    expect(constructionCommand.colonyId, 'redoubt');
    expect(constructionCommand.construction, 'Apartment Complex');
  });

  test('militarist computer colonies build infantry after barracks', () {
    final sample = OpenDeadlockGame.sample();
    final militarist = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id != 'rebels') {
          return faction;
        }
        return faction.copyWith(
          raceId: 'human',
          aiPersonality: Faction.aiPersonalityAdaptive,
          traitIds: const <String>['militarists'],
        );
      }).toList(),
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'redoubt') {
          return colony;
        }
        return colony.copyWith(
          construction: 'Scout Patrol',
          completedBuildings: const <String>['Militia Post', 'Barracks'],
        );
      }).toList(),
    );
    final commands = militarist.planComputerCommands();
    final constructionCommand =
        commands.whereType<SetColonyConstructionCommand>().single;

    expect(constructionCommand.factionId, 'rebels');
    expect(constructionCommand.colonyId, 'redoubt');
    expect(constructionCommand.construction, 'Infantry Company');
  });

  test('militarist computer colonies build armor after factory and barracks',
      () {
    final sample = OpenDeadlockGame.sample();
    final militarist = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id != 'rebels') {
          return faction;
        }
        return faction.copyWith(
          raceId: 'human',
          aiPersonality: Faction.aiPersonalityAdaptive,
          traitIds: const <String>['militarists'],
        );
      }).toList(),
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'redoubt') {
          return colony;
        }
        return colony.copyWith(
          construction: 'Scout Patrol',
          completedBuildings: const <String>[
            'Militia Post',
            'Barracks',
            'Factory',
          ],
        );
      }).toList(),
    );
    final commands = militarist.planComputerCommands();
    final constructionCommand =
        commands.whereType<SetColonyConstructionCommand>().single;

    expect(constructionCommand.factionId, 'rebels');
    expect(constructionCommand.colonyId, 'redoubt');
    expect(constructionCommand.construction, 'Armor Company');
  });

  test('computer factions choose focus for colony needs', () {
    final sample = OpenDeadlockGame.sample();
    final starving = sample.copyWith(
      activeFactionId: 'rebels',
      factions: sample.factions.map((faction) {
        if (faction.id != 'rebels') {
          return faction;
        }
        return faction.copyWith(
          raceId: 'human',
          traitIds: const <String>[],
        );
      }).toList(),
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'redoubt') {
          return colony;
        }
        return Colony(
          id: colony.id,
          name: colony.name,
          ownerId: colony.ownerId,
          x: 4,
          y: 0,
          population: 5,
          morale: colony.morale,
          construction: colony.construction,
          storedIndustry: colony.storedIndustry,
          completedBuildings: colony.completedBuildings,
          focus: colony.focus,
          assignedSectors: colony.assignedSectors,
        );
      }).toList(),
      units: sample.units.map((unit) {
        if (unit.ownerId != 'rebels') {
          return unit;
        }
        return unit.copyWith(movesRemaining: 0);
      }).toList(),
    );
    final commands = starving.planComputerCommandsFor('rebels');
    final focusCommand = commands.whereType<SetColonyFocusCommand>().single;

    expect(focusCommand.factionId, 'rebels');
    expect(focusCommand.colonyId, 'redoubt');
    expect(focusCommand.focus, OpenDeadlockGame.colonyFocusGrowth);
  });

  test('fast-growth race AI prioritizes growth focus while fed', () {
    final sample = OpenDeadlockGame.sample();
    final chchtOpponent = sample.copyWith(
      activeFactionId: 'rebels',
      factions: sample.factions.map((faction) {
        if (faction.id != 'rebels') {
          return faction;
        }
        return faction.copyWith(
          raceId: 'chcht',
          aiPersonality: Faction.aiPersonalityAdaptive,
          traitIds: const <String>[],
        );
      }).toList(),
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'redoubt') {
          return colony;
        }
        return colony.copyWith(
          construction: 'Factory',
          storedIndustry: 0,
          focus: OpenDeadlockGame.colonyFocusBalanced,
        );
      }).toList(),
      units: sample.units.map((unit) {
        if (unit.ownerId != 'rebels') {
          return unit;
        }
        return unit.copyWith(movesRemaining: 0);
      }).toList(),
    );
    final projection =
        chchtOpponent.colonyProductionFor(chchtOpponent.colonyById('redoubt'));
    final commands = chchtOpponent.planComputerCommandsFor('rebels');
    final focusCommand = commands.whereType<SetColonyFocusCommand>().single;

    expect(projection.foodBalance, greaterThan(0));
    expect(projection.populationChange, 2);
    expect(focusCommand.factionId, 'rebels');
    expect(focusCommand.colonyId, 'redoubt');
    expect(focusCommand.focus, OpenDeadlockGame.colonyFocusGrowth);
  });

  test('fast-growth race AI does not force growth at population capacity', () {
    final sample = OpenDeadlockGame.sample();
    final cappedChcht = sample.copyWith(
      activeFactionId: 'rebels',
      factions: sample.factions.map((faction) {
        if (faction.id != 'rebels') {
          return faction;
        }
        return faction.copyWith(
          raceId: 'chcht',
          aiPersonality: Faction.aiPersonalityAdaptive,
          traitIds: const <String>[],
        );
      }).toList(),
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'redoubt') {
          return colony;
        }
        return colony.copyWith(
          population: OpenDeadlockGame.basePopulationCapacity,
          construction: 'Factory',
          storedIndustry: 0,
          focus: OpenDeadlockGame.colonyFocusBalanced,
        );
      }).toList(),
      units: sample.units.map((unit) {
        if (unit.ownerId != 'rebels') {
          return unit;
        }
        return unit.copyWith(movesRemaining: 0);
      }).toList(),
    );
    final projection =
        cappedChcht.colonyProductionFor(cappedChcht.colonyById('redoubt'));
    final commands = cappedChcht.planComputerCommandsFor('rebels');
    final constructionCommand =
        commands.whereType<SetColonyConstructionCommand>().single;
    final focusCommand = commands.whereType<SetColonyFocusCommand>().single;

    expect(projection.populationChange, 0);
    expect(constructionCommand.construction, 'Housing');
    expect(focusCommand.focus, isNot(OpenDeadlockGame.colonyFocusGrowth));
  });

  test('computer factions adjust tax policy for reserves and morale', () {
    final sample = OpenDeadlockGame.sample();
    final lowCredits = sample.copyWith(
      activeFactionId: 'rebels',
      factions: sample.factions.map((faction) {
        if (faction.id != 'rebels') {
          return faction;
        }
        return faction.copyWith(
          resources: faction.resources.copyWith(credits: 3),
        );
      }).toList(),
      units: sample.units.map((unit) {
        if (unit.ownerId != 'rebels') {
          return unit;
        }
        return unit.copyWith(movesRemaining: 0);
      }).toList(),
    );
    final highTaxCommand = lowCredits
        .planComputerCommandsFor('rebels')
        .whereType<SetFactionTaxPolicyCommand>()
        .single;

    expect(highTaxCommand.factionId, 'rebels');
    expect(highTaxCommand.taxPolicy, Faction.taxPolicyHigh);

    final lowMorale = sample.copyWith(
      activeFactionId: 'rebels',
      factions: sample.factions.map((faction) {
        if (faction.id != 'rebels') {
          return faction;
        }
        return faction.copyWith(taxPolicy: Faction.taxPolicyHigh);
      }).toList(),
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'redoubt') {
          return colony;
        }
        return colony.copyWith(morale: 28);
      }).toList(),
      units: sample.units.map((unit) {
        if (unit.ownerId != 'rebels') {
          return unit;
        }
        return unit.copyWith(movesRemaining: 0);
      }).toList(),
    );
    final reliefCommand = lowMorale
        .planComputerCommandsFor('rebels')
        .whereType<SetFactionTaxPolicyCommand>()
        .single;

    expect(reliefCommand.factionId, 'rebels');
    expect(reliefCommand.taxPolicy, Faction.taxPolicyRelief);
  });

  test('computer factions offer peace when under pressure', () {
    final sample = OpenDeadlockGame.sample();
    final pressured = sample.copyWith(
      activeFactionId: 'rebels',
      factions: sample.factions.map((faction) {
        if (faction.id != 'rebels') {
          return faction;
        }
        return faction.copyWith(
          resources: faction.resources.copyWith(credits: 3),
        );
      }).toList(),
      units: sample.units.map((unit) {
        if (unit.ownerId != 'rebels') {
          return unit;
        }
        return unit.copyWith(movesRemaining: 0);
      }).toList(),
    );
    final peaceCommand = pressured
        .planComputerCommandsFor('rebels')
        .whereType<SetDiplomacyStatusCommand>()
        .single;
    final updated = pressured.applyCommands(<GameCommand>[peaceCommand]);

    expect(peaceCommand.factionId, 'rebels');
    expect(peaceCommand.targetFactionId, 'humans');
    expect(peaceCommand.status, OpenDeadlockGame.diplomacyStatusPeace);
    expect(updated.areAtWar('humans', 'rebels'), isFalse);
    expect(updated.tradeIncomeFor('rebels').credits, 2);
  });

  test('aggressive computer factions break peace with a military advantage',
      () {
    final sample = OpenDeadlockGame.sample();
    final superior = sample.copyWith(
      activeFactionId: 'rebels',
      diplomacy: const <DiplomacyRelation>[
        DiplomacyRelation(
          factionAId: 'humans',
          factionBId: 'rebels',
          status: OpenDeadlockGame.diplomacyStatusPeace,
        ),
      ],
      units: <Unit>[
        ...sample.units,
        const Unit(
          id: 'rebel-armor',
          name: 'Pact Armor',
          ownerId: 'rebels',
          type: 'armor',
          x: 5,
          y: 2,
          movesRemaining: 1,
          health: 10,
        ),
      ],
    );
    final warCommand = superior
        .planComputerCommandsFor('rebels')
        .whereType<SetDiplomacyStatusCommand>()
        .single;
    final updated = superior.applyCommands(<GameCommand>[warCommand]);

    expect(superior.areAtWar('humans', 'rebels'), isFalse);
    expect(superior.militaryStrengthFor('rebels'),
        greaterThan(superior.militaryStrengthFor('humans') + 8));
    expect(warCommand.factionId, 'rebels');
    expect(warCommand.targetFactionId, 'humans');
    expect(warCommand.status, OpenDeadlockGame.diplomacyStatusWar);
    expect(updated.areAtWar('humans', 'rebels'), isTrue);
  });

  test('faction traits guide computer research preferences', () {
    final sample = OpenDeadlockGame.sample();
    final scholarOpponent = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id != 'rebels') {
          return faction;
        }
        return faction.copyWith(
          raceId: 'human',
          aiPersonality: Faction.aiPersonalityAdaptive,
          traitIds: const <String>['scholars'],
        );
      }).toList(),
    );
    final commands = scholarOpponent.planComputerCommands();
    final researchCommand = commands.first as SetResearchProjectCommand;

    expect(researchCommand.factionId, 'rebels');
    expect(researchCommand.researchProject, 'Xenoarchaeology');
  });

  test('computer research prioritizes defense grid for exposed colonies', () {
    final exposed = _sabotageExposedScholarOpponent();
    final commands = exposed.planComputerCommandsFor('rebels');
    final researchCommand =
        commands.whereType<SetResearchProjectCommand>().single;

    expect(exposed.tileAt(6, 3).isExploredBy('humans'), isTrue);
    expect(exposed.sabotageDamageForColony(exposed.colonyById('redoubt')), 8);
    expect(researchCommand.factionId, 'rebels');
    expect(researchCommand.researchProject, 'Defense Grid');
  });

  test('computer research returns to traits after sabotage is fully blocked',
      () {
    final hardened = _sabotageExposedScholarOpponent(
      completedBuildings: const <String>['Militia Post', 'Barracks'],
      completedResearch: const <String>['Defense Grid'],
    );
    final commands = hardened.planComputerCommandsFor('rebels');
    final researchCommand =
        commands.whereType<SetResearchProjectCommand>().single;

    expect(hardened.sabotageDamageForColony(hardened.colonyById('redoubt')), 0);
    expect(researchCommand.factionId, 'rebels');
    expect(researchCommand.researchProject, 'Xenoarchaeology');
  });

  test('race profiles guide computer research preferences', () {
    final sample = OpenDeadlockGame.sample();
    final maugOpponent = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id != 'rebels') {
          return faction;
        }
        return faction.copyWith(
          raceId: 'maug',
          aiPersonality: Faction.aiPersonalityAdaptive,
          traitIds: const <String>[],
        );
      }).toList(),
    );
    final commands = maugOpponent.planComputerCommands();
    final researchCommand = commands.first as SetResearchProjectCommand;

    expect(researchCommand.factionId, 'rebels');
    expect(researchCommand.researchProject, 'Industrial Automation');
  });

  test('researcher personality overrides race and trait AI priorities', () {
    final sample = OpenDeadlockGame.sample();
    final researcher = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id != 'rebels') {
          return faction;
        }
        return faction.copyWith(
          raceId: 'tarth',
          aiPersonality: Faction.aiPersonalityResearcher,
          traitIds: const <String>['militarists'],
        );
      }).toList(),
    );
    final commands = researcher.planComputerCommands();
    final researchCommand = commands.first as SetResearchProjectCommand;
    final constructionCommand =
        commands.whereType<SetColonyConstructionCommand>().single;

    expect(researchCommand.factionId, 'rebels');
    expect(researchCommand.researchProject, 'Xenoarchaeology');
    expect(constructionCommand.factionId, 'rebels');
    expect(constructionCommand.construction, 'Research Lab');
  });

  test('trader personality favors peace, revenue, and economy builds', () {
    final sample = OpenDeadlockGame.sample();
    final trader = sample.copyWith(
      activeFactionId: 'rebels',
      factions: sample.factions.map((faction) {
        if (faction.id != 'rebels') {
          return faction;
        }
        return faction.copyWith(
          raceId: 'human',
          aiPersonality: Faction.aiPersonalityTrader,
          traitIds: const <String>[],
        );
      }).toList(),
      units: sample.units.map((unit) {
        if (unit.ownerId != 'rebels') {
          return unit;
        }
        return unit.copyWith(movesRemaining: 0);
      }).toList(),
    );
    final commands = trader.planComputerCommandsFor('rebels');
    final peaceCommand = commands.whereType<SetDiplomacyStatusCommand>().single;
    final taxCommand = commands.whereType<SetFactionTaxPolicyCommand>().single;
    final focusCommand = commands.whereType<SetColonyFocusCommand>().single;
    final constructionCommand =
        commands.whereType<SetColonyConstructionCommand>().single;

    expect(peaceCommand.targetFactionId, 'humans');
    expect(peaceCommand.status, OpenDeadlockGame.diplomacyStatusPeace);
    expect(taxCommand.taxPolicy, Faction.taxPolicyRelief);
    expect(focusCommand.focus, OpenDeadlockGame.colonyFocusRevenue);
    expect(constructionCommand.construction, 'Farm Dome');
  });

  test('trader personality upgrades peace to alliance for trade', () {
    final sample = OpenDeadlockGame.sample();
    final trader = sample.copyWith(
      activeFactionId: 'rebels',
      diplomacy: const <DiplomacyRelation>[
        DiplomacyRelation(
          factionAId: 'humans',
          factionBId: 'rebels',
          status: OpenDeadlockGame.diplomacyStatusPeace,
        ),
      ],
      factions: sample.factions.map((faction) {
        if (faction.id != 'rebels') {
          return faction;
        }
        return faction.copyWith(
          aiPersonality: Faction.aiPersonalityTrader,
          resources: faction.resources.copyWith(credits: 8),
        );
      }).toList(),
      units: sample.units.map((unit) {
        if (unit.ownerId != 'rebels') {
          return unit;
        }
        return unit.copyWith(movesRemaining: 0);
      }).toList(),
    );

    final allianceCommand = trader
        .planComputerCommandsFor('rebels')
        .whereType<SetDiplomacyStatusCommand>()
        .single;
    final updated = trader.applyCommands(<GameCommand>[allianceCommand]);

    expect(allianceCommand.factionId, 'rebels');
    expect(allianceCommand.targetFactionId, 'humans');
    expect(allianceCommand.status, OpenDeadlockGame.diplomacyStatusAlliance);
    expect(updated.diplomacyStatusBetween('humans', 'rebels'),
        OpenDeadlockGame.diplomacyStatusAlliance);
    expect(updated.tradeIncomeFor('rebels').credits, 4);
  });

  test('conqueror personality breaks peace with a narrow advantage', () {
    final sample = OpenDeadlockGame.sample();
    OpenDeadlockGame fixture({
      required String aiPersonality,
      required List<String> traitIds,
    }) {
      return sample.copyWith(
        activeFactionId: 'rebels',
        diplomacy: const <DiplomacyRelation>[
          DiplomacyRelation(
            factionAId: 'humans',
            factionBId: 'rebels',
            status: OpenDeadlockGame.diplomacyStatusPeace,
          ),
        ],
        factions: sample.factions.map((faction) {
          if (faction.id != 'rebels') {
            return faction;
          }
          return faction.copyWith(
            raceId: 'human',
            aiPersonality: aiPersonality,
            traitIds: traitIds,
          );
        }).toList(),
        units: <Unit>[
          sample.unitById('human-scout'),
          sample.unitById('rebel-scout'),
          const Unit(
            id: 'rebel-infantry',
            name: 'Pact Infantry',
            ownerId: 'rebels',
            type: 'infantry',
            x: 5,
            y: 2,
            movesRemaining: 0,
            health: 1,
          ),
        ],
      );
    }

    final adaptiveMilitarist = fixture(
      aiPersonality: Faction.aiPersonalityAdaptive,
      traitIds: const <String>['militarists'],
    );
    final conqueror = fixture(
      aiPersonality: Faction.aiPersonalityConqueror,
      traitIds: const <String>[],
    );
    final adaptiveDiplomacy = adaptiveMilitarist
        .planComputerCommandsFor('rebels')
        .whereType<SetDiplomacyStatusCommand>();
    final warCommand = conqueror
        .planComputerCommandsFor('rebels')
        .whereType<SetDiplomacyStatusCommand>()
        .single;

    expect(
      adaptiveMilitarist.militaryStrengthFor('rebels') -
          adaptiveMilitarist.militaryStrengthFor('humans'),
      7,
    );
    expect(adaptiveDiplomacy, isEmpty);
    expect(warCommand.targetFactionId, 'humans');
    expect(warCommand.status, OpenDeadlockGame.diplomacyStatusWar);
  });

  test('computer research preference skips completed trait projects', () {
    final sample = OpenDeadlockGame.sample();
    final industrialOpponent = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id != 'rebels') {
          return faction;
        }
        return faction.copyWith(
          completedResearch: const <String>['Industrial Automation'],
          researchProject: 'Industrial Automation',
        );
      }).toList(),
    );
    final commands = industrialOpponent.planComputerCommands();
    final researchCommand = commands.first as SetResearchProjectCommand;

    expect(researchCommand.factionId, 'rebels');
    expect(researchCommand.researchProject, 'Defense Grid');
  });

  test('computer factions fund research when credits can finish it', () {
    final sample = OpenDeadlockGame.sample();
    final game = sample.copyWith(
      activeFactionId: 'rebels',
      factions: sample.factions.map((faction) {
        if (faction.id != 'rebels') {
          return faction;
        }
        return faction.copyWith(
          researchProject: 'Defense Grid',
          resources: faction.resources.copyWith(research: 13, credits: 9),
        );
      }).toList(),
      units: sample.units.map((unit) {
        if (unit.ownerId != 'rebels') {
          return unit;
        }
        return unit.copyWith(movesRemaining: 0);
      }).toList(),
    );
    final commands = game.planComputerCommandsFor('rebels');
    final fundCommand = commands.whereType<FundResearchCommand>().single;
    final updated = game.applyCommands(commands);
    final rebels = updated.factionById('rebels')!;

    expect(fundCommand.factionId, 'rebels');
    expect(fundCommand.research, 3);
    expect(rebels.resources.research, 16);
    expect(rebels.resources.credits, 0);
    expect(
      updated.commandHistory.any(
        (record) => record.command.type == FundResearchCommand.commandType,
      ),
      isTrue,
    );
  });

  test('computer factions do not fund research already finishing naturally',
      () {
    final sample = OpenDeadlockGame.sample();
    final game = sample.copyWith(
      activeFactionId: 'rebels',
      factions: sample.factions.map((faction) {
        if (faction.id != 'rebels') {
          return faction;
        }
        return faction.copyWith(
          researchProject: 'Defense Grid',
          resources: faction.resources.copyWith(research: 14, credits: 6),
        );
      }).toList(),
      units: sample.units.map((unit) {
        if (unit.ownerId != 'rebels') {
          return unit;
        }
        return unit.copyWith(movesRemaining: 0);
      }).toList(),
    );
    final commands = game.planComputerCommandsFor('rebels');

    expect(commands.whereType<FundResearchCommand>(), isEmpty);
  });

  test('computer factions rush construction when credits can finish it', () {
    final sample = OpenDeadlockGame.sample();
    final game = sample.copyWith(
      activeFactionId: 'rebels',
      factions: sample.factions.map((faction) {
        if (faction.id != 'rebels') {
          return faction;
        }
        return faction.copyWith(
          researchProject: 'Defense Grid',
          resources: faction.resources.copyWith(credits: 24),
        );
      }).toList(),
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'redoubt') {
          return colony;
        }
        return colony.copyWith(storedIndustry: 10);
      }).toList(),
      units: sample.units.map((unit) {
        if (unit.ownerId != 'rebels') {
          return unit;
        }
        return unit.copyWith(movesRemaining: 0);
      }).toList(),
    );
    final commands = game.planComputerCommandsFor('rebels');
    final rushCommand = commands.whereType<RushConstructionCommand>().single;
    final updated = game.applyCommands(commands);

    expect(rushCommand.factionId, 'rebels');
    expect(rushCommand.colonyId, 'redoubt');
    expect(rushCommand.industry, 12);
    expect(updated.colonyById('redoubt').storedIndustry, 22);
    expect(updated.factionById('rebels')!.resources.credits, 0);
    expect(
      updated.commandHistory.any(
        (record) => record.command.type == RushConstructionCommand.commandType,
      ),
      isTrue,
    );
  });

  test('computer factions do not rush construction finishing naturally', () {
    final sample = OpenDeadlockGame.sample();
    final game = sample.copyWith(
      activeFactionId: 'rebels',
      factions: sample.factions.map((faction) {
        if (faction.id != 'rebels') {
          return faction;
        }
        return faction.copyWith(
          researchProject: 'Defense Grid',
          resources: faction.resources.copyWith(credits: 24),
        );
      }).toList(),
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'redoubt') {
          return colony;
        }
        return colony.copyWith(storedIndustry: 14);
      }).toList(),
      units: sample.units.map((unit) {
        if (unit.ownerId != 'rebels') {
          return unit;
        }
        return unit.copyWith(movesRemaining: 0);
      }).toList(),
    );
    final commands = game.planComputerCommandsFor('rebels');

    expect(commands.whereType<RushConstructionCommand>(), isEmpty);
  });

  test('computer factions prioritize adjacent attacks', () {
    final sample = OpenDeadlockGame.sample();
    final game = sample.copyWith(
      units: <Unit>[
        sample.unitById('human-scout').copyWith(x: 5, y: 2),
        sample.unitById('rebel-scout').copyWith(x: 5, y: 3),
      ],
    );
    final commands = game.planComputerCommands();
    final attackCommand = commands.whereType<MoveUnitCommand>().single;

    expect(attackCommand.factionId, 'rebels');
    expect(attackCommand.unitId, 'rebel-scout');
    expect(attackCommand.x, 5);
    expect(attackCommand.y, 2);
  });

  test('computer factions prefer high value decisive attacks', () {
    final sample = OpenDeadlockGame.sample();
    final game = sample.copyWith(
      activeFactionId: 'rebels',
      tiles: sample.tiles.map((tile) {
        final isCombatSector = (tile.x == 4 && tile.y == 2) ||
            (tile.x == 4 && tile.y == 3) ||
            (tile.x == 5 && tile.y == 3);
        if (!isCombatSector) {
          return tile;
        }
        return PlanetTile(
          x: tile.x,
          y: tile.y,
          terrain: 'plains',
          yields: const TileYield(food: 3, industry: 1, research: 0),
          ownerId: tile.ownerId,
          explored: true,
          exploredBy: const <String>['humans', 'rebels'],
        );
      }).toList(),
      units: const <Unit>[
        Unit(
          id: 'human-scout',
          name: 'Human Scout',
          ownerId: 'humans',
          type: 'scout',
          x: 4,
          y: 2,
          movesRemaining: 2,
          health: 2,
        ),
        Unit(
          id: 'human-armor',
          name: 'Human Armor',
          ownerId: 'humans',
          type: 'armor',
          x: 5,
          y: 3,
          movesRemaining: 1,
          health: 4,
        ),
        Unit(
          id: 'rebel-armor',
          name: 'Tarth Armor',
          ownerId: 'rebels',
          type: 'armor',
          x: 4,
          y: 3,
          movesRemaining: 1,
          health: 10,
        ),
      ],
    );
    final commands = game.planComputerCommandsFor('rebels');
    final attackCommand = commands.whereType<MoveUnitCommand>().single;
    final updated = game.applyCommands(<GameCommand>[attackCommand]);

    expect(attackCommand.factionId, 'rebels');
    expect(attackCommand.unitId, 'rebel-armor');
    expect(attackCommand.x, 5);
    expect(attackCommand.y, 3);
    expect(updated.unitAt(5, 3)!.id, 'rebel-armor');
    expect(updated.units.where((unit) => unit.id == 'human-armor'), isEmpty);
    expect(updated.units.where((unit) => unit.id == 'human-scout'), isNotEmpty);
  });

  test('computer factions attack units defending hostile colonies', () {
    final sample = OpenDeadlockGame.sample();
    final game = sample.copyWith(
      activeFactionId: 'rebels',
      units: <Unit>[
        sample
            .unitById('human-scout')
            .copyWith(x: 2, y: 2, health: 3, movesRemaining: 2),
        sample.unitById('rebel-scout').copyWith(x: 2, y: 3),
      ],
    );
    final commands = game.planComputerCommandsFor('rebels');
    final attackCommand = commands.whereType<MoveUnitCommand>().singleWhere(
          (command) => command.unitId == 'rebel-scout',
        );
    final updated = game.applyCommands(<GameCommand>[attackCommand]);

    expect(attackCommand.factionId, 'rebels');
    expect(attackCommand.x, 2);
    expect(attackCommand.y, 2);
    expect(updated.units.where((unit) => unit.id == 'human-scout'), isEmpty);
    expect(updated.unitById('rebel-scout').x, 2);
    expect(updated.unitById('rebel-scout').y, 3);
    expect(updated.colonyById('new-haven').ownerId, 'humans');
    expect(updated.reports.first.title, 'Pact Recon defeated Survey Team');
    expect(updated.reports.first.details['kind'], 'unit');
  });

  test('computer factions skip adjacent attacks they cannot afford to enter',
      () {
    final sample = OpenDeadlockGame.sample();
    final game = sample.copyWith(
      activeFactionId: 'rebels',
      units: const <Unit>[
        Unit(
          id: 'human-scout',
          name: 'Human Scout',
          ownerId: 'humans',
          type: 'scout',
          x: 4,
          y: 1,
          movesRemaining: 2,
        ),
        Unit(
          id: 'rebel-infantry',
          name: 'Tarth Infantry',
          ownerId: 'rebels',
          type: 'infantry',
          x: 3,
          y: 1,
          movesRemaining: 1,
          health: 4,
        ),
      ],
    );
    final commands = game.planComputerCommandsFor('rebels');

    expect(game.tileAt(4, 1).terrain, 'forest');
    expect(
        commands.whereType<MoveUnitCommand>().where((command) {
          return command.unitId == 'rebel-infantry' &&
              command.x == 4 &&
              command.y == 1;
        }),
        isEmpty);
    expect(commands.whereType<RecoverUnitCommand>().single.unitId,
        'rebel-infantry');
  });

  test('computer factions recover damaged units before ordinary movement', () {
    final sample = OpenDeadlockGame.sample();
    final game = sample.copyWith(
      activeFactionId: 'rebels',
      units: <Unit>[
        sample.unitById('human-scout'),
        sample
            .unitById('rebel-scout')
            .copyWith(x: 6, y: 3, health: 2, movesRemaining: 2),
      ],
    );
    final commands = game.planComputerCommandsFor('rebels');
    final recoverCommand = commands.whereType<RecoverUnitCommand>().single;
    final updated = game.applyCommands(commands);
    final scout = updated.unitById('rebel-scout');

    expect(recoverCommand.factionId, 'rebels');
    expect(recoverCommand.unitId, 'rebel-scout');
    expect(scout.health, 3);
    expect(scout.movesRemaining, 0);
    expect(
      updated.commandHistory.any(
        (record) => record.command.type == RecoverUnitCommand.commandType,
      ),
      isTrue,
    );
  });

  test('computer factions attack before recovering damaged units', () {
    final sample = OpenDeadlockGame.sample();
    final game = sample.copyWith(
      units: <Unit>[
        sample.unitById('human-scout').copyWith(x: 5, y: 2),
        sample
            .unitById('rebel-scout')
            .copyWith(x: 5, y: 3, health: 3, movesRemaining: 2),
      ],
    );
    final commands = game.planComputerCommandsFor('rebels');
    final recoverCommands = commands.whereType<RecoverUnitCommand>();
    final attackCommand = commands.whereType<MoveUnitCommand>().last;
    final preview = game.previewUnitCombat(
      game.unitById('rebel-scout'),
      game.unitById('human-scout'),
    );

    expect(recoverCommands, isEmpty);
    expect(preview.attackerSurvives, isTrue);
    expect(preview.attackerHealth, 1);
    expect(attackCommand.unitId, 'rebel-scout');
    expect(attackCommand.x, 5);
    expect(attackCommand.y, 2);
  });

  test('cautious computer factions recover instead of desperate attacks', () {
    final sample = OpenDeadlockGame.sample();
    OpenDeadlockGame fixture({
      String difficulty = Faction.difficultyNormal,
      List<String> traitIds = const <String>[],
    }) {
      return sample.copyWith(
        activeFactionId: 'rebels',
        tiles: sample.tiles.map((tile) {
          if ((tile.x == 6 && tile.y == 2) || (tile.x == 6 && tile.y == 3)) {
            return _testTile(
              tile,
              terrain: 'plains',
              yields: tile.yields,
              ownerId: tile.ownerId,
              colonyId: tile.colonyId,
              exploredBy: const <String>['humans', 'rebels'],
            );
          }
          return tile;
        }).toList(),
        factions: sample.factions.map((faction) {
          if (faction.id != 'rebels') {
            return faction;
          }
          return faction.copyWith(
            raceId: 'human',
            aiPersonality: Faction.aiPersonalityAdaptive,
            difficulty: difficulty,
            traitIds: traitIds,
          );
        }).toList(),
        units: <Unit>[
          sample.unitById('human-scout').copyWith(x: 6, y: 2),
          sample
              .unitById('rebel-scout')
              .copyWith(x: 6, y: 3, health: 3, movesRemaining: 2),
        ],
      );
    }

    final game = fixture();
    final commands = game.planComputerCommandsFor('rebels');
    final attacks = commands.whereType<MoveUnitCommand>().where((command) {
      return command.unitId == 'rebel-scout' &&
          command.x == 6 &&
          command.y == 2;
    });
    final recoverCommand = commands.whereType<RecoverUnitCommand>().single;
    final preview = game.previewUnitCombat(
      game.unitById('rebel-scout'),
      game.unitById('human-scout'),
    );

    expect(preview.attackerSurvives, isTrue);
    expect(preview.defenderSurvives, isTrue);
    expect(preview.attackerHealth, 1);
    expect(attacks, isEmpty);
    expect(recoverCommand.unitId, 'rebel-scout');

    final hardCommands = fixture(difficulty: Faction.difficultyHard)
        .planComputerCommandsFor('rebels');
    final hardAttack = hardCommands.whereType<MoveUnitCommand>().singleWhere(
          (command) =>
              command.unitId == 'rebel-scout' &&
              command.x == 6 &&
              command.y == 2,
        );
    expect(hardAttack.factionId, 'rebels');
    expect(hardCommands.whereType<RecoverUnitCommand>(), isEmpty);

    final easyCommands = fixture(
      difficulty: Faction.difficultyEasy,
      traitIds: const <String>['militarists'],
    ).planComputerCommandsFor('rebels');
    final easyAttacks = easyCommands.whereType<MoveUnitCommand>().where(
          (command) =>
              command.unitId == 'rebel-scout' &&
              command.x == 6 &&
              command.y == 2,
        );
    expect(easyAttacks, isEmpty);
    expect(easyCommands.whereType<RecoverUnitCommand>().single.unitId,
        'rebel-scout');
  });

  test('computer factions avoid attacks against peaceful factions', () {
    final sample = OpenDeadlockGame.sample();
    final game = sample.copyWith(
      units: <Unit>[
        sample.unitById('human-scout').copyWith(x: 5, y: 2),
        sample.unitById('rebel-scout').copyWith(x: 5, y: 3),
      ],
    ).applyCommand(
      const SetDiplomacyStatusCommand(
        factionId: 'humans',
        targetFactionId: 'rebels',
        status: OpenDeadlockGame.diplomacyStatusPeace,
      ),
    );
    final commands = game.planComputerCommands();
    final attacks = commands.whereType<MoveUnitCommand>().where((command) {
      return command.unitId == 'rebel-scout' &&
          command.x == 5 &&
          command.y == 2;
    });

    expect(attacks, isEmpty);
  });

  test('computer factions move toward known wartime targets', () {
    final game = _strategicMovementFixture();
    final moveCommand =
        game.planComputerCommands().whereType<MoveUnitCommand>().single;

    expect(moveCommand.factionId, 'rebels');
    expect(moveCommand.unitId, 'rebel-scout');
    expect(_distance(moveCommand.x, moveCommand.y, 2, 2),
        lessThan(_distance(4, 4, 2, 2)));
    expect(moveCommand.x == 4 && moveCommand.y == 5, isFalse);
  });

  test('computer factions defend threatened colonies before distant targets',
      () {
    final sample = OpenDeadlockGame.sample();
    final game = sample.copyWith(
      activeFactionId: 'rebels',
      tiles: sample.tiles.map((tile) {
        if (tile.x == 2 && tile.y == 2) {
          return tile.revealTo('rebels');
        }
        if (tile.x == 3 && tile.y == 3) {
          return _testTile(
            tile,
            terrain: 'ruins',
            yields: const TileYield(food: 0, industry: 1, research: 3),
          );
        }
        if (tile.x == 4 && tile.y == 3) {
          return _testTile(
            tile,
            terrain: 'plains',
            yields: const TileYield(food: 3, industry: 1, research: 0),
          );
        }
        if (tile.x == 5 && tile.y == 3) {
          return _testTile(
            tile,
            terrain: 'plains',
            yields: const TileYield(food: 3, industry: 1, research: 0),
            ownerId: 'rebels',
            exploredBy: const <String>['rebels'],
          );
        }
        return tile;
      }).toList(),
      units: <Unit>[
        sample.unitById('human-scout').copyWith(x: 6, y: 4),
        sample.unitById('rebel-scout').copyWith(x: 4, y: 3),
      ],
    );
    final commands = game.planComputerCommandsFor('rebels');
    final moveCommand = commands.whereType<MoveUnitCommand>().singleWhere(
          (command) => command.unitId == 'rebel-scout',
        );

    expect(game.tileAt(2, 2).isExploredBy('rebels'), isTrue);
    expect(
        game.isUnitVisibleTo('rebels', game.unitById('human-scout')), isTrue);
    expect(
        _distance(
            6, 4, game.colonyById('redoubt').x, game.colonyById('redoubt').y),
        1);
    expect(moveCommand.factionId, 'rebels');
    expect(
      _distance(moveCommand.x, moveCommand.y, 6, 4),
      lessThan(_distance(4, 3, 6, 4)),
    );
    expect(moveCommand.x == 3 && moveCommand.y == 3, isFalse);
  });

  test('computer factions garrison threatened colonies over rich sectors', () {
    final sample = OpenDeadlockGame.sample();
    final game = sample.copyWith(
      activeFactionId: 'rebels',
      tiles: sample.tiles.map((tile) {
        if (tile.x == 5 && tile.y == 3) {
          return _testTile(
            tile,
            terrain: 'plains',
            yields: const TileYield(food: 3, industry: 1, research: 0),
            exploredBy: const <String>['rebels'],
          );
        }
        if (tile.x == 5 && tile.y == 4) {
          return _testTile(
            tile,
            terrain: 'ruins',
            yields: const TileYield(food: 8, industry: 8, research: 8),
            exploredBy: const <String>['rebels'],
          );
        }
        return tile;
      }).toList(),
      units: <Unit>[
        sample.unitById('human-scout').copyWith(x: 6, y: 4),
        sample.unitById('rebel-scout').copyWith(x: 5, y: 3),
      ],
    );
    final commands = game.planComputerCommandsFor('rebels');
    final moveCommand = commands.whereType<MoveUnitCommand>().singleWhere(
          (command) => command.unitId == 'rebel-scout',
        );

    expect(game.colonyById('redoubt').x, 6);
    expect(game.colonyById('redoubt').y, 3);
    expect(game.tileAt(5, 4).yields.industry, 8);
    expect(
        game.isUnitVisibleTo('rebels', game.unitById('human-scout')), isTrue);
    expect(moveCommand.factionId, 'rebels');
    expect(moveCommand.x, 6);
    expect(moveCommand.y, 3);
  });

  test('computer factions ignore stale unit contacts outside live vision', () {
    final sample = OpenDeadlockGame.sample();
    final game = sample.copyWith(
      activeFactionId: 'rebels',
      factions: sample.factions.map((faction) {
        if (faction.id != 'rebels') {
          return faction;
        }
        return faction.copyWith(
          resources: faction.resources.copyWith(credits: 0),
        );
      }).toList(),
      tiles: sample.tiles.map((tile) {
        if (tile.x == 5 && tile.y == 3) {
          return _testTile(
            tile,
            terrain: 'plains',
            yields: const TileYield(food: 3, industry: 1, research: 0),
            ownerId: 'rebels',
            exploredBy: const <String>['rebels'],
          );
        }
        if (tile.x == 5 && tile.y == 4) {
          return _testTile(
            tile,
            terrain: 'ruins',
            yields: const TileYield(food: 8, industry: 8, research: 8),
            exploredBy: const <String>['rebels'],
          );
        }
        return tile;
      }).toList(),
      units: <Unit>[
        sample.unitById('human-scout').copyWith(x: 6, y: 5),
        sample.unitById('rebel-scout').copyWith(x: 5, y: 3),
      ],
    );
    final commands = game.planComputerCommandsFor('rebels');
    final moveCommand = commands.whereType<MoveUnitCommand>().singleWhere(
          (command) => command.unitId == 'rebel-scout',
        );

    expect(game.tileAt(6, 5).isExploredBy('rebels'), isTrue);
    expect(
        game.isUnitVisibleTo('rebels', game.unitById('human-scout')), isFalse);
    expect(moveCommand.factionId, 'rebels');
    expect(moveCommand.x, 5);
    expect(moveCommand.y, 4);
  });

  test('computer unit planning avoids stale occupied destinations', () {
    final sample = OpenDeadlockGame.sample();
    PlanetTile replaceTile(
      PlanetTile tile, {
      required String terrain,
      required TileYield yields,
      String? ownerId,
      String? colonyId,
    }) {
      return PlanetTile(
        x: tile.x,
        y: tile.y,
        terrain: terrain,
        yields: yields,
        ownerId: ownerId,
        colonyId: colonyId,
        explored: tile.explored,
        exploredBy: tile.exploredBy,
      );
    }

    final game = sample.copyWith(
      activeFactionId: 'rebels',
      tiles: sample.tiles.map((tile) {
        final isTarget = tile.x == 5 && tile.y == 4;
        final isBlockedNeighbor = (tile.x == 5 && tile.y == 2) ||
            (tile.x == 6 && tile.y == 3) ||
            (tile.x == 4 && tile.y == 3) ||
            (tile.x == 6 && tile.y == 5) ||
            (tile.x == 4 && tile.y == 5);
        final isScoutStart =
            (tile.x == 5 && tile.y == 3) || (tile.x == 5 && tile.y == 5);
        if (isTarget) {
          return replaceTile(
            tile,
            terrain: 'plains',
            yields: const TileYield(food: 9, industry: 9, research: 9),
          );
        }
        if (isBlockedNeighbor) {
          return replaceTile(
            tile,
            terrain: 'water',
            yields: tile.yields,
          );
        }
        if (isScoutStart) {
          return replaceTile(
            tile,
            terrain: 'plains',
            yields: tile.yields,
          );
        }
        return tile;
      }).toList(growable: false),
      units: <Unit>[
        sample.unitById('human-scout'),
        sample.unitById('rebel-scout').copyWith(x: 5, y: 3),
        const Unit(
          id: 'rebel-scout-2',
          name: 'Second Scout',
          ownerId: 'rebels',
          type: 'scout',
          x: 5,
          y: 5,
          movesRemaining: 2,
        ),
      ],
    );

    final commands = game.planComputerCommandsFor('rebels');
    final moveCommands = commands.whereType<MoveUnitCommand>().toList();
    final updated = game.applyCommands(commands);

    expect(moveCommands.length, 1);
    expect(moveCommands.single.x, 5);
    expect(moveCommands.single.y, 4);
    expect(updated.unitAt(5, 4)!.ownerId, 'rebels');
    expect(updated.commandHistory.length, commands.length);
  });

  test('computer factions do not pursue peaceful targets', () {
    final game = _strategicMovementFixture(peaceful: true);
    final moveCommand =
        game.planComputerCommands().whereType<MoveUnitCommand>().single;

    expect(moveCommand.factionId, 'rebels');
    expect(moveCommand.unitId, 'rebel-scout');
    expect(moveCommand.x, 4);
    expect(moveCommand.y, 5);
  });

  test('computer factions can plan adjacent colony assaults', () {
    final sample = OpenDeadlockGame.sample();
    final weakenedColonies = sample.colonies.map((colony) {
      if (colony.id != 'new-haven') {
        return colony;
      }
      return colony.copyWith(population: 1, morale: 20);
    }).toList();
    final game = sample.copyWith(
      colonies: weakenedColonies,
      units: <Unit>[
        sample.unitById('rebel-scout').copyWith(x: 2, y: 3),
      ],
    );
    final commands = game.planComputerCommands();
    final assaultCommand = commands.last as MoveUnitCommand;

    expect(assaultCommand.factionId, 'rebels');
    expect(assaultCommand.unitId, 'rebel-scout');
    expect(assaultCommand.x, 2);
    expect(assaultCommand.y, 2);
  });

  test('computer factions prefer captures over low value adjacent attacks', () {
    final sample = OpenDeadlockGame.sample();
    final weakenedColonies = sample.colonies.map((colony) {
      if (colony.id != 'new-haven') {
        return colony;
      }
      return colony.copyWith(population: 1, morale: 20);
    }).toList();
    final game = sample.copyWith(
      activeFactionId: 'rebels',
      tiles: sample.tiles.map((tile) {
        final isCombatSector = (tile.x == 2 && tile.y == 2) ||
            (tile.x == 2 && tile.y == 3) ||
            (tile.x == 3 && tile.y == 3);
        if (!isCombatSector) {
          return tile;
        }
        return _testTile(
          tile,
          terrain: 'plains',
          yields: tile.yields,
          ownerId: tile.ownerId,
          colonyId: tile.colonyId,
          exploredBy: const <String>['humans', 'rebels'],
        );
      }).toList(),
      colonies: weakenedColonies,
      units: <Unit>[
        sample.unitById('human-scout').copyWith(
              x: 3,
              y: 3,
              health: 1,
              movesRemaining: 2,
            ),
        sample.unitById('rebel-scout').copyWith(x: 2, y: 3),
      ],
    );
    final commands = game.planComputerCommandsFor('rebels');
    final assaultCommand = commands.whereType<MoveUnitCommand>().singleWhere(
          (command) => command.unitId == 'rebel-scout',
        );
    final updated = game.applyCommand(assaultCommand);

    expect(
      game
          .previewColonyAssault(
            game.unitById('rebel-scout'),
            game.colonyById('new-haven'),
          )
          .colonyCaptured,
      isTrue,
    );
    expect(assaultCommand.factionId, 'rebels');
    expect(assaultCommand.x, 2);
    expect(assaultCommand.y, 2);
    expect(updated.colonyById('new-haven').ownerId, 'rebels');
    expect(updated.units.where((unit) => unit.id == 'human-scout'), isNotEmpty);
  });

  test('computer factions avoid suicidal colony assaults', () {
    final sample = OpenDeadlockGame.sample();
    final game = sample.copyWith(
      activeFactionId: 'rebels',
      units: <Unit>[
        sample
            .unitById('rebel-scout')
            .copyWith(x: 2, y: 3, health: 2, movesRemaining: 2),
      ],
    );
    final commands = game.planComputerCommandsFor('rebels');
    final assaults = commands.whereType<MoveUnitCommand>().where((command) {
      return command.unitId == 'rebel-scout' &&
          command.x == 2 &&
          command.y == 2;
    });
    final recoverCommand = commands.whereType<RecoverUnitCommand>().single;

    expect(
        game
            .previewColonyAssault(
              game.unitById('rebel-scout'),
              game.colonyById('new-haven'),
            )
            .colonyCaptured,
        isFalse);
    expect(assaults, isEmpty);
    expect(recoverCommand.unitId, 'rebel-scout');
  });

  test('computer factions soften fortified colonies with durable units', () {
    final sample = OpenDeadlockGame.sample();
    final game = sample.copyWith(
      activeFactionId: 'rebels',
      factions: sample.factions.map((faction) {
        if (faction.id != 'humans') {
          return faction;
        }
        return faction.copyWith(
          completedResearch: const <String>['Defense Grid'],
        );
      }).toList(),
      tiles: sample.tiles.map((tile) {
        if (tile.x == 2 && tile.y == 2) {
          return _testTile(
            tile,
            terrain: 'plains',
            yields: tile.yields,
            ownerId: 'humans',
            colonyId: 'new-haven',
            exploredBy: const <String>['humans', 'rebels'],
          );
        }
        return tile;
      }).toList(),
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'new-haven') {
          return colony;
        }
        return colony.copyWith(
          population: 12,
          morale: 80,
          completedBuildings: const <String>['Militia Post', 'Barracks'],
        );
      }).toList(),
      units: const <Unit>[
        Unit(
          id: 'rebel-armor',
          name: 'Pact Armor',
          ownerId: 'rebels',
          type: 'armor',
          x: 3,
          y: 2,
          movesRemaining: 1,
          health: 10,
        ),
      ],
    );
    final preview = game.previewColonyAssault(
      game.unitById('rebel-armor'),
      game.colonyById('new-haven'),
    );
    final commands = game.planComputerCommandsFor('rebels');
    final assaultCommand = commands.whereType<MoveUnitCommand>().single;
    final updated = game.applyCommand(assaultCommand);

    expect(preview.colonyCaptured, isFalse);
    expect(preview.attackerSurvives, isTrue);
    expect(preview.attackerHealth, 6);
    expect(preview.morale, 45);
    expect(assaultCommand.factionId, 'rebels');
    expect(assaultCommand.unitId, 'rebel-armor');
    expect(assaultCommand.x, 2);
    expect(assaultCommand.y, 2);
    expect(updated.colonyById('new-haven').ownerId, 'humans');
    expect(updated.colonyById('new-haven').morale, 45);
    expect(updated.unitById('rebel-armor').x, 3);
    expect(updated.unitById('rebel-armor').health, 6);
    expect(updated.reports.first.title, 'New Haven repelled Pact Armor');
    expect(
      updated.reports.first.details,
      containsPair('previousPopulation', '12'),
    );
    expect(updated.reports.first.details, containsPair('previousMorale', '80'));
    expect(updated.reports.first.details, containsPair('populationDelta', '0'));
    expect(updated.reports.first.details, containsPair('moraleDelta', '-35'));
  });

  test('computer factions avoid colony assaults against peaceful factions', () {
    final sample = OpenDeadlockGame.sample();
    final weakenedColonies = sample.colonies.map((colony) {
      if (colony.id != 'new-haven') {
        return colony;
      }
      return colony.copyWith(population: 1, morale: 20);
    }).toList();
    final game = sample.copyWith(
      colonies: weakenedColonies,
      units: <Unit>[
        sample.unitById('rebel-scout').copyWith(x: 2, y: 3),
      ],
    ).applyCommand(
      const SetDiplomacyStatusCommand(
        factionId: 'humans',
        targetFactionId: 'rebels',
        status: OpenDeadlockGame.diplomacyStatusPeace,
      ),
    );
    final commands = game.planComputerCommands();
    final assaults = commands.whereType<MoveUnitCommand>().where((command) {
      return command.unitId == 'rebel-scout' &&
          command.x == 2 &&
          command.y == 2;
    });

    expect(assaults, isEmpty);
  });

  test('advanceTurn applies computer commands before production', () {
    final game = OpenDeadlockGame.sample();
    final next = game.advanceTurn();

    expect(next.turn, 2);
    expect(next.activeFactionId, 'humans');
    expect(next.colonyAt(6, 3)!.construction, 'Barracks');
    expect(next.factionById('rebels')!.researchProject, 'Defense Grid');
    expect(next.colonyAt(5, 3), isNull);
    expect(next.unitAt(4, 3)!.id, 'rebel-scout');
    expect(next.colonyById('redoubt').assignedSectors.length, 3);
    expect(next.commandHistory.length, 8);
    expect(
      next.commandHistory.any(
        (record) => record.command.type == FoundColonyCommand.commandType,
      ),
      isFalse,
    );
    expect(
      next.commandHistory.any(
        (record) => record.command.type == MoveUnitCommand.commandType,
      ),
      isTrue,
    );
    expect(
      next.commandHistory.any(
        (record) => record.command.type == ScanFactionIntelCommand.commandType,
      ),
      isTrue,
    );
    expect(
      next.commandHistory.any(
        (record) => record.command.type == SabotageColonyCommand.commandType,
      ),
      isTrue,
    );
    expect(next.reports.first.title, 'Human Assembly is ready');
    expect(next.reports[1].title, 'Computer opponents issued orders');
  });

  test('run computer turn command advances an active AI seat', () {
    final game = OpenDeadlockGame.sample().copyWith(
      activeFactionId: 'rebels',
    );
    final next = game.applyCommand(
      const RunComputerTurnCommand(factionId: 'rebels'),
    );
    final replayed = GameReplay.replay(game, next.commandHistory);

    expect(next.turn, 2);
    expect(next.activeFactionId, 'humans');
    expect(next.colonyAt(5, 3), isNull);
    expect(next.unitAt(4, 3)!.id, 'rebel-scout');
    expect(next.commandHistory.length, 1);
    expect(
      next.commandHistory.single.command.type,
      RunComputerTurnCommand.commandType,
    );
    expect(next.reports.first.title, 'Human Assembly is ready');
    expect(next.reports[1].title, 'Computer opponents issued orders');
    expect(GameReplay.hasSameState(replayed.game, next), isTrue);
  });

  test('remote factions wait for synced orders instead of automated AI turns',
      () {
    final sample = OpenDeadlockGame.sample();
    final remoteSeat = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id == 'rebels') {
          return faction.copyWith(controlMode: Faction.controlRemote);
        }
        return faction;
      }).toList(),
    );
    final restoredRemoteSeat = OpenDeadlockGame.fromJson(remoteSeat.toJson());
    final rebelsTurn = remoteSeat.applyCommand(
      const EndTurnCommand(factionId: 'humans'),
    );
    final nextRound = rebelsTurn.applyCommand(
      const EndTurnCommand(factionId: 'rebels'),
    );

    expect(restoredRemoteSeat.factionById('rebels')!.isRemote, isTrue);
    expect(rebelsTurn.turn, 1);
    expect(rebelsTurn.activeFactionId, 'rebels');
    expect(rebelsTurn.activeFactionCanIssueLocalOrders, isFalse);
    expect(rebelsTurn.colonyAt(6, 3)!.construction, 'Barracks');
    expect(rebelsTurn.colonyAt(5, 3), isNull);
    expect(rebelsTurn.commandHistory.length, 1);

    expect(nextRound.turn, 2);
    expect(nextRound.activeFactionId, 'humans');
    expect(nextRound.commandHistory.length, 2);
    expect(nextRound.reports.first.title, 'Human Assembly is ready');
  });

  test('human factions rotate before a full production round resolves', () {
    final sample = OpenDeadlockGame.sample();
    final hotseat = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id == 'rebels') {
          return faction.copyWith(isComputer: false);
        }
        return faction;
      }).toList(),
    );
    final restoredHotseat = OpenDeadlockGame.fromJson(hotseat.toJson());
    final rebelsTurn = hotseat.applyCommand(
      const EndTurnCommand(factionId: 'humans'),
    );
    final nextRound = rebelsTurn.applyCommand(
      const EndTurnCommand(factionId: 'rebels'),
    );

    expect(restoredHotseat.factionById('rebels')!.isComputer, isFalse);
    expect(rebelsTurn.turn, 1);
    expect(rebelsTurn.activeFactionId, 'rebels');
    expect(rebelsTurn.colonyAt(2, 2)!.storedIndustry,
        hotseat.colonyAt(2, 2)!.storedIndustry);
    expect(rebelsTurn.reports.first.title, 'Tarth Legion is ready');

    expect(nextRound.turn, 2);
    expect(nextRound.activeFactionId, 'humans');
    expect(nextRound.colonyAt(2, 2)!.storedIndustry,
        greaterThan(hotseat.colonyAt(2, 2)!.storedIndustry));
    expect(nextRound.commandHistory.length, 2);
    expect(nextRound.reports.first.title, 'Human Assembly is ready');
  });

  test('end turn command creates a replayable command history', () {
    final initial = OpenDeadlockGame.sample();
    final next = initial.applyCommand(
      const EndTurnCommand(factionId: 'humans'),
    );
    final replayed = GameReplay.replay(initial, next.commandHistory);

    expect(next.turn, 2);
    expect(next.commandHistory.length, 1);
    expect(next.commandHistory.last.command.type, EndTurnCommand.commandType);
    expect(replayed.steps.length, next.commandHistory.length);
    expect(GameReplay.hasSameState(replayed.game, next), isTrue);
  });
}

OpenDeadlockGame _defeatedMiddleFactionFixture() {
  final sample = OpenDeadlockGame.sample(sessionId: 'defeated-turn-order');
  const traders = Faction(
    id: 'traders',
    name: 'Trade Compact',
    colorValue: 0xFF2CB67D,
    raceId: 'uva_mosk',
    isComputer: false,
    resources:
        ResourceStockpile(food: 12, industry: 5, research: 0, credits: 9),
  );

  return sample.copyWith(
    factions: <Faction>[
      sample.factionById('humans')!,
      sample.factionById('rebels')!,
      traders,
    ],
    tiles: sample.tiles.map((tile) {
      if (tile.x == 6 && tile.y == 3) {
        return tile.copyWith(
          ownerId: 'traders',
          colonyId: 'trader-hold',
        );
      }
      return tile;
    }).toList(),
    colonies: <Colony>[
      sample.colonyById('new-haven'),
      const Colony(
        id: 'trader-hold',
        name: 'Trader Hold',
        ownerId: 'traders',
        x: 6,
        y: 3,
        population: 3,
        morale: 68,
        construction: 'Factory',
        storedIndustry: 6,
        completedBuildings: <String>[],
      ),
    ],
    units: <Unit>[
      sample.unitById('human-scout'),
    ],
  );
}

OpenDeadlockGame _eliminationBattleFixture() {
  final sample = OpenDeadlockGame.sample(sessionId: 'elimination-report');
  const traders = Faction(
    id: 'traders',
    name: 'Trade Compact',
    colorValue: 0xFF2CB67D,
    raceId: 'uva_mosk',
    isComputer: false,
    resources:
        ResourceStockpile(food: 12, industry: 5, research: 0, credits: 9),
  );

  return sample.copyWith(
    factions: <Faction>[
      sample.factionById('humans')!,
      sample.factionById('rebels')!,
      traders,
    ],
    tiles: sample.tiles.map((tile) {
      if (tile.x == 0 && tile.y == 0) {
        return tile.copyWith(
          ownerId: 'traders',
          colonyId: 'trader-hold',
          exploredBy: const <String>['humans', 'rebels', 'traders'],
        );
      }
      return tile;
    }).toList(),
    colonies: <Colony>[
      sample.colonyById('new-haven'),
      sample.colonyById('redoubt').copyWith(
            population: 1,
            morale: 20,
          ),
      const Colony(
        id: 'trader-hold',
        name: 'Trader Hold',
        ownerId: 'traders',
        x: 0,
        y: 0,
        population: 3,
        morale: 68,
        construction: 'Factory',
        storedIndustry: 6,
        completedBuildings: <String>[],
      ),
    ],
    units: <Unit>[
      sample.unitById('human-scout').copyWith(x: 5, y: 3),
    ],
  );
}

OpenDeadlockGame _sabotageExposedScholarOpponent({
  String construction = 'Research Lab',
  List<String> completedBuildings = const <String>[],
  List<String> completedResearch = const <String>[],
}) {
  final sample = OpenDeadlockGame.sample();
  return sample.copyWith(
    factions: sample.factions.map((faction) {
      if (faction.id != 'rebels') {
        return faction;
      }
      return faction.copyWith(
        raceId: 'human',
        aiPersonality: Faction.aiPersonalityAdaptive,
        completedResearch: completedResearch,
        traitIds: const <String>['scholars'],
      );
    }).toList(),
    tiles: sample.tiles.map((tile) {
      if (tile.x == 6 && tile.y == 3) {
        return tile.revealTo('humans');
      }
      return tile;
    }).toList(),
    colonies: sample.colonies.map((colony) {
      if (colony.id != 'redoubt') {
        return colony;
      }
      return colony.copyWith(
        construction: construction,
        storedIndustry: 10,
        completedBuildings: completedBuildings,
      );
    }).toList(),
  );
}

OpenDeadlockGame _strategicMovementFixture({bool peaceful = false}) {
  final sample = OpenDeadlockGame.sample();
  final tiles = sample.tiles.map((tile) {
    if (tile.x == 2 && tile.y == 2) {
      return tile.revealTo('rebels');
    }
    if (tile.x == 4 && tile.y == 3) {
      return _testTile(
        tile,
        terrain: 'plains',
        yields: const TileYield(food: 0, industry: 0, research: 0),
      );
    }
    if (tile.x == 4 && tile.y == 5) {
      return _testTile(
        tile,
        terrain: 'plains',
        yields: const TileYield(food: 3, industry: 3, research: 2),
      );
    }
    return tile;
  }).toList();

  return sample.copyWith(
    tiles: tiles,
    units: <Unit>[
      sample.unitById('rebel-scout').copyWith(
            x: 4,
            y: 4,
            movesRemaining: 2,
          ),
    ],
    diplomacy: <DiplomacyRelation>[
      DiplomacyRelation(
        factionAId: 'humans',
        factionBId: 'rebels',
        status: peaceful
            ? OpenDeadlockGame.diplomacyStatusPeace
            : OpenDeadlockGame.diplomacyStatusWar,
      ),
    ],
  );
}

PlanetTile _testTile(
  PlanetTile tile, {
  required String terrain,
  required TileYield yields,
  String? ownerId,
  String? colonyId,
  List<String> exploredBy = const <String>[],
}) {
  return PlanetTile(
    x: tile.x,
    y: tile.y,
    terrain: terrain,
    yields: yields,
    ownerId: ownerId,
    colonyId: colonyId,
    explored: exploredBy.isNotEmpty,
    exploredBy: exploredBy,
  );
}

int _distance(int ax, int ay, int bx, int by) {
  return (ax - bx).abs() + (ay - by).abs();
}
