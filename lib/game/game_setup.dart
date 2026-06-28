import 'game_state.dart';

class GameSetupFaction {
  const GameSetupFaction({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.raceId,
    required this.controlMode,
    required this.difficulty,
    required this.traitIds,
    this.aiPersonality = Faction.aiPersonalityAdaptive,
  });

  final String id;
  final String name;
  final int colorValue;
  final String raceId;
  final String controlMode;
  final String difficulty;
  final String aiPersonality;
  final List<String> traitIds;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'colorValue': colorValue,
      'raceId': raceId,
      'controlMode': controlMode,
      'difficulty': difficulty,
      'aiPersonality': aiPersonality,
      'traitIds': traitIds,
    };
  }

  static GameSetupFaction fromJson(Map<String, dynamic> json) {
    return GameSetupFaction(
      id: json['id'] as String,
      name: json['name'] as String,
      colorValue: _readSetupInt(json['colorValue']),
      raceId:
          json['raceId'] as String? ?? _legacySetupRaceId(json['id'] as String),
      controlMode: json['controlMode'] as String,
      difficulty: json['difficulty'] as String,
      aiPersonality: _knownSetupAiPersonalityOrDefault(
        json['aiPersonality'] as String?,
      ),
      traitIds: (json['traitIds'] as List<dynamic>? ?? const <dynamic>[])
          .map((traitId) => traitId as String)
          .toList(),
    );
  }
}

class GameSetup {
  const GameSetup({
    required this.mapSize,
    required this.planetType,
    required this.factions,
    this.worldSeed = 0,
    this.startingDiplomacy = OpenDeadlockGame.diplomacyStatusWar,
    this.victoryCondition = OpenDeadlockGame.victoryConditionAny,
    this.startingIntel = startingIntelHomeRegion,
    this.startingResources = startingResourcesStandard,
  });

  static const String mapSizeSkirmish = 'skirmish';
  static const String mapSizeStandard = 'standard';
  static const String mapSizeFrontier = 'frontier';
  static const String planetTypeTerran = 'terran';
  static const String planetTypeVerdant = 'verdant';
  static const String planetTypeMineral = 'mineral';
  static const String planetTypeAncient = 'ancient';
  static const String startingIntelClassicFog = 'classic';
  static const String startingIntelHomeRegion = 'home';
  static const String startingIntelFullMap = 'full';
  static const String startingResourcesScarce = 'scarce';
  static const String startingResourcesStandard = 'standard';
  static const String startingResourcesAbundant = 'abundant';
  static const List<String> mapSizes = <String>[
    mapSizeSkirmish,
    mapSizeStandard,
    mapSizeFrontier,
  ];
  static const List<String> planetTypes = <String>[
    planetTypeTerran,
    planetTypeVerdant,
    planetTypeMineral,
    planetTypeAncient,
  ];
  static const List<String> startingIntelOptions = <String>[
    startingIntelClassicFog,
    startingIntelHomeRegion,
    startingIntelFullMap,
  ];
  static const List<String> startingResourceOptions = <String>[
    startingResourcesScarce,
    startingResourcesStandard,
    startingResourcesAbundant,
  ];

  final String mapSize;
  final String planetType;
  final int worldSeed;
  final String startingDiplomacy;
  final String victoryCondition;
  final String startingIntel;
  final String startingResources;
  final List<GameSetupFaction> factions;

  static GameSetup standard() {
    return const GameSetup(
      mapSize: mapSizeStandard,
      planetType: planetTypeTerran,
      startingDiplomacy: OpenDeadlockGame.diplomacyStatusWar,
      victoryCondition: OpenDeadlockGame.victoryConditionAny,
      startingIntel: startingIntelHomeRegion,
      startingResources: startingResourcesStandard,
      factions: <GameSetupFaction>[
        GameSetupFaction(
          id: 'humans',
          name: 'Human Assembly',
          colorValue: 0xFF2F80ED,
          raceId: 'human',
          controlMode: Faction.controlLocal,
          difficulty: Faction.difficultyNormal,
          aiPersonality: Faction.aiPersonalityResearcher,
          traitIds: <String>['scholars', 'traders'],
        ),
        GameSetupFaction(
          id: 'rebels',
          name: 'Tarth Legion',
          colorValue: 0xFFB83232,
          raceId: 'tarth',
          controlMode: Faction.controlComputer,
          difficulty: Faction.difficultyNormal,
          aiPersonality: Faction.aiPersonalityConqueror,
          traitIds: <String>['industrialists', 'militarists'],
        ),
      ],
    );
  }

  static String mapSizeLabelFor(String mapSize) {
    if (mapSize == mapSizeSkirmish) {
      return 'Skirmish';
    }
    if (mapSize == mapSizeStandard) {
      return 'Standard';
    }
    if (mapSize == mapSizeFrontier) {
      return 'Frontier';
    }
    return mapSize;
  }

  static String planetTypeLabelFor(String planetType) {
    if (planetType == planetTypeTerran) {
      return 'Terran';
    }
    if (planetType == planetTypeVerdant) {
      return 'Verdant';
    }
    if (planetType == planetTypeMineral) {
      return 'Mineral Rich';
    }
    if (planetType == planetTypeAncient) {
      return 'Ancient Ruins';
    }
    return planetType;
  }

  static String startingIntelLabelFor(String startingIntel) {
    if (startingIntel == startingIntelClassicFog) {
      return 'Classic Fog';
    }
    if (startingIntel == startingIntelHomeRegion) {
      return 'Home Region';
    }
    if (startingIntel == startingIntelFullMap) {
      return 'Full Map';
    }
    return startingIntel;
  }

  static String startingResourcesLabelFor(String startingResources) {
    if (startingResources == startingResourcesScarce) {
      return 'Scarce Supplies';
    }
    if (startingResources == startingResourcesStandard) {
      return 'Standard Supplies';
    }
    if (startingResources == startingResourcesAbundant) {
      return 'Abundant Supplies';
    }
    return startingResources;
  }

  static int widthFor(String mapSize) {
    if (mapSize == mapSizeSkirmish) {
      return 8;
    }
    if (mapSize == mapSizeStandard) {
      return 10;
    }
    if (mapSize == mapSizeFrontier) {
      return 12;
    }
    throw ArgumentError('Unknown map size: $mapSize.');
  }

  static int heightFor(String mapSize) {
    if (mapSize == mapSizeSkirmish) {
      return 6;
    }
    if (mapSize == mapSizeStandard) {
      return 7;
    }
    if (mapSize == mapSizeFrontier) {
      return 8;
    }
    throw ArgumentError('Unknown map size: $mapSize.');
  }

  static int sectorCountFor(String mapSize) {
    return widthFor(mapSize) * heightFor(mapSize);
  }

  static String mapSizeSummaryFor(String mapSize) {
    final width = widthFor(mapSize);
    final height = heightFor(mapSize);
    return '$width x $height sectors (${sectorCountFor(mapSize)} total)';
  }

  static String planetTypeDescriptionFor(String planetType) {
    if (planetType == planetTypeTerran) {
      return 'Balanced plains, forests, ridges, water, and ruins.';
    }
    if (planetType == planetTypeVerdant) {
      return 'Forest-heavy world. Every sector gains +1 food.';
    }
    if (planetType == planetTypeMineral) {
      return 'Ridge-heavy world. Every sector gains +1 industry.';
    }
    if (planetType == planetTypeAncient) {
      return 'Ruins-heavy world. Every sector gains +1 research.';
    }
    throw ArgumentError('Unknown planet type: $planetType.');
  }

  static String startingDiplomacyLabelFor(String status) {
    return OpenDeadlockGame.diplomacyStatusLabelFor(status);
  }

  static String startingDiplomacyDescriptionFor(String status) {
    if (status == OpenDeadlockGame.diplomacyStatusWar) {
      return 'All factions begin at war.';
    }
    if (status == OpenDeadlockGame.diplomacyStatusPeace) {
      return 'All factions begin at peace and may trade.';
    }
    if (status == OpenDeadlockGame.diplomacyStatusAlliance) {
      return 'All factions begin allied with shared sensor coverage.';
    }
    throw ArgumentError('Unknown diplomacy status: $status.');
  }

  static String victoryConditionLabelFor(String victoryCondition) {
    return OpenDeadlockGame.victoryConditionLabelFor(victoryCondition);
  }

  static String victoryConditionDescriptionFor(String victoryCondition) {
    if (victoryCondition == OpenDeadlockGame.victoryConditionAny) {
      return 'Conquest or science can win the game.';
    }
    if (victoryCondition == OpenDeadlockGame.victoryConditionConquest) {
      return 'Only controlling every colony ends the game.';
    }
    if (victoryCondition == OpenDeadlockGame.victoryConditionScience) {
      return 'Only completing every core research project ends the game.';
    }
    throw ArgumentError('Unknown victory condition: $victoryCondition.');
  }

  static String startingIntelDescriptionFor(String startingIntel) {
    if (startingIntel == startingIntelClassicFog) {
      return 'Only capitals and starting scouts are known.';
    }
    if (startingIntel == startingIntelHomeRegion) {
      return 'Each faction knows the sectors around its capital.';
    }
    if (startingIntel == startingIntelFullMap) {
      return 'Every faction starts with the whole planet revealed.';
    }
    throw ArgumentError('Unknown starting intel: $startingIntel.');
  }

  static String startingResourcesDescriptionFor(String startingResources) {
    if (startingResources == startingResourcesScarce) {
      return 'Low reserves make early construction and research tighter.';
    }
    if (startingResources == startingResourcesStandard) {
      return 'Balanced reserves for a normal opening.';
    }
    if (startingResources == startingResourcesAbundant) {
      return 'Extra reserves accelerate early builds and research.';
    }
    throw ArgumentError('Unknown starting resources: $startingResources.');
  }

  static List<String> traitOptions() {
    return OpenDeadlockGame.factionTraitCatalog.keys.toList(growable: false);
  }

  static List<String> raceOptions() {
    return OpenDeadlockGame.raceCatalog.keys.toList(growable: false);
  }

  static String raceLabelFor(String raceId) {
    return OpenDeadlockGame.raceLabelFor(raceId);
  }

  static String raceDescriptionFor(String raceId) {
    return _raceProfileForSetup(raceId).description;
  }

  static String raceEffectSummaryFor(String raceId) {
    final race = _raceProfileForSetup(raceId);
    final effects = <String>[];
    _appendSignedEffect(effects, race.foodBonus, 'food per colony');
    _appendSignedEffect(effects, race.industryBonus, 'industry per colony');
    _appendSignedEffect(effects, race.researchBonus, 'research per colony');
    _appendSignedEffect(effects, race.creditBonus, 'credits per colony');
    _appendSignedEffect(
      effects,
      race.constructionBonus,
      'construction work per colony turn',
    );
    _appendSignedEffect(
      effects,
      race.populationGrowthBonus,
      'population growth when fed',
    );
    _appendSignedEffect(effects, race.attackBonus, 'unit attack');
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
      return 'No special bonuses.';
    }
    return _sentenceFromEffects(effects);
  }

  static String traitLabelFor(String traitId) {
    return OpenDeadlockGame.factionTraitCatalog[traitId]?.name ?? traitId;
  }

  static String traitEffectSummaryFor(List<String> traitIds) {
    if (traitIds.isEmpty) {
      return 'No selected abilities.';
    }
    return traitIds.map((traitId) {
      final trait = _traitForSetup(traitId);
      final effects = <String>[];
      _appendSignedEffect(effects, trait.foodBonus, 'food per colony');
      _appendSignedEffect(effects, trait.industryBonus, 'industry per colony');
      _appendSignedEffect(effects, trait.researchBonus, 'research per colony');
      _appendSignedEffect(effects, trait.creditBonus, 'credits per colony');
      if (trait.preferredConstruction != null) {
        effects.add('prefers ${trait.preferredConstruction}');
      }
      if (trait.preferredResearch != null) {
        effects.add('prioritizes ${trait.preferredResearch}');
      }
      if (effects.isEmpty) {
        return '${trait.name}: ${trait.description}';
      }
      return '${trait.name}: ${_sentenceFromEffects(effects)}';
    }).join(' ');
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'mapSize': mapSize,
      'planetType': planetType,
      'worldSeed': worldSeed,
      'startingDiplomacy': startingDiplomacy,
      'victoryCondition': victoryCondition,
      'startingIntel': startingIntel,
      'startingResources': startingResources,
      'factions': factions.map((faction) => faction.toJson()).toList(),
    };
  }

  static GameSetup fromJson(Map<String, dynamic> json) {
    return GameSetup(
      mapSize: json['mapSize'] as String,
      planetType: json['planetType'] as String? ?? planetTypeTerran,
      worldSeed:
          json['worldSeed'] == null ? 0 : _readSetupInt(json['worldSeed']),
      startingDiplomacy: json['startingDiplomacy'] as String? ??
          OpenDeadlockGame.diplomacyStatusWar,
      victoryCondition: json['victoryCondition'] as String? ??
          OpenDeadlockGame.victoryConditionAny,
      startingIntel:
          json['startingIntel'] as String? ?? startingIntelHomeRegion,
      startingResources:
          json['startingResources'] as String? ?? startingResourcesStandard,
      factions: (json['factions'] as List<dynamic>)
          .map((faction) =>
              GameSetupFaction.fromJson(faction as Map<String, dynamic>))
          .toList(),
    );
  }

  OpenDeadlockGame buildGame({String? sessionId}) {
    if (!mapSizes.contains(mapSize)) {
      throw ArgumentError('Unknown map size: $mapSize.');
    }
    if (!planetTypes.contains(planetType)) {
      throw ArgumentError('Unknown planet type: $planetType.');
    }
    if (worldSeed < 0) {
      throw ArgumentError('World seed cannot be negative.');
    }
    if (!OpenDeadlockGame.diplomacyStatuses.contains(startingDiplomacy)) {
      throw ArgumentError('Unknown starting diplomacy: $startingDiplomacy.');
    }
    if (!OpenDeadlockGame.victoryConditions.contains(victoryCondition)) {
      throw ArgumentError('Unknown victory condition: $victoryCondition.');
    }
    if (!startingIntelOptions.contains(startingIntel)) {
      throw ArgumentError('Unknown starting intel: $startingIntel.');
    }
    if (!startingResourceOptions.contains(startingResources)) {
      throw ArgumentError('Unknown starting resources: $startingResources.');
    }
    if (factions.length < 2 || factions.length > 4) {
      throw ArgumentError('New games require two to four factions.');
    }

    final width = widthFor(mapSize);
    final height = heightFor(mapSize);
    final homes = _homePositions(width, height, factions.length);
    final seenFactionIds = <String>{};
    final gameFactions = <Faction>[];
    final colonies = <Colony>[];
    final units = <Unit>[];
    final scoutPositionsByFactionId = <String, _SetupPoint>{};

    for (var index = 0; index < factions.length; index += 1) {
      final setupFaction = factions[index];
      if (!seenFactionIds.add(setupFaction.id)) {
        throw ArgumentError('Duplicate faction id: ${setupFaction.id}.');
      }
      if (!Faction.isKnownControlMode(setupFaction.controlMode)) {
        throw ArgumentError(
            'Unknown faction control mode: ${setupFaction.controlMode}.');
      }
      if (!Faction.isKnownDifficulty(setupFaction.difficulty)) {
        throw ArgumentError(
            'Unknown faction difficulty: ${setupFaction.difficulty}.');
      }
      if (!Faction.isKnownAiPersonality(setupFaction.aiPersonality)) {
        throw ArgumentError(
            'Unknown AI personality: ${setupFaction.aiPersonality}.');
      }
      if (!OpenDeadlockGame.raceCatalog.containsKey(setupFaction.raceId)) {
        throw ArgumentError('Unknown race: ${setupFaction.raceId}.');
      }
      final seenTraitIds = <String>{};
      for (final traitId in setupFaction.traitIds) {
        if (!OpenDeadlockGame.factionTraitCatalog.containsKey(traitId)) {
          throw ArgumentError('Unknown faction trait: $traitId.');
        }
        if (!seenTraitIds.add(traitId)) {
          throw ArgumentError(
              'Duplicate trait $traitId for faction ${setupFaction.id}.');
        }
      }
      final home = homes[index];
      gameFactions.add(
        Faction(
          id: setupFaction.id,
          name: setupFaction.name,
          colorValue: setupFaction.colorValue,
          raceId: setupFaction.raceId,
          isComputer: setupFaction.controlMode == Faction.controlComputer,
          controlMode: setupFaction.controlMode,
          difficulty: setupFaction.difficulty,
          aiPersonality: setupFaction.aiPersonality,
          resources: _startingResourcesFor(index, startingResources),
          traitIds: setupFaction.traitIds,
        ),
      );
      colonies.add(
        Colony(
          id: '${setupFaction.id}-capital',
          name: _capitalNameFor(setupFaction, index),
          ownerId: setupFaction.id,
          x: home.x,
          y: home.y,
          population: index == 0 ? 5 : 4,
          morale: index == 0 ? 72 : 64,
          construction: index == 0 ? 'Colony Hub' : 'Barracks',
          storedIndustry: index == 0 ? 10 : 4,
          completedBuildings: const <String>[],
        ),
      );
      final scout =
          _scoutPositionFor(home, width, height, planetType, worldSeed);
      scoutPositionsByFactionId[setupFaction.id] = scout;
      units.add(
        Unit(
          id: '${setupFaction.id}-scout',
          name: '${setupFaction.name} Scout',
          ownerId: setupFaction.id,
          type: 'scout',
          x: scout.x,
          y: scout.y,
          movesRemaining: OpenDeadlockGame.maxMovesFor('scout'),
        ),
      );
    }

    final tiles = <PlanetTile>[];
    for (var y = 0; y < height; y += 1) {
      for (var x = 0; x < width; x += 1) {
        var terrain = _terrainFor(x, y, planetType, worldSeed);
        String? ownerId;
        String? colonyId;
        final exploredBy = <String>[];
        var isHomeSector = false;

        for (var index = 0; index < factions.length; index += 1) {
          final faction = factions[index];
          final home = homes[index];
          final distance = _manhattanDistance(home.x, home.y, x, y);
          if (distance <= 2) {
            ownerId ??= terrain == 'water' ? null : faction.id;
          }
          if (_startingIntelRevealsTile(
            startingIntel,
            home,
            scoutPositionsByFactionId[faction.id]!,
            x,
            y,
          )) {
            exploredBy.add(faction.id);
          }
          if (home.x == x && home.y == y) {
            isHomeSector = true;
            ownerId = faction.id;
            colonyId = '${faction.id}-capital';
          }
        }
        if (isHomeSector && terrain == 'water') {
          terrain = _capitalTerrainFor(planetType);
        }

        tiles.add(
          PlanetTile(
            x: x,
            y: y,
            terrain: terrain,
            yields: _yieldsFor(terrain, planetType),
            ownerId: ownerId,
            colonyId: colonyId,
            explored: exploredBy.isNotEmpty,
            exploredBy: exploredBy,
          ),
        );
      }
    }

    final revealAllFactionIds = gameFactions
        .where((faction) => OpenDeadlockGame.raceProfileFor(faction).revealsMap)
        .map((faction) => faction.id)
        .toList();
    if (revealAllFactionIds.isNotEmpty) {
      for (var index = 0; index < tiles.length; index += 1) {
        var tile = tiles[index];
        for (final factionId in revealAllFactionIds) {
          tile = tile.revealTo(factionId);
        }
        tiles[index] = tile;
      }
    }

    return OpenDeadlockGame(
      sessionId: sessionId ?? _defaultSessionIdFor(this),
      turn: 1,
      width: width,
      height: height,
      activeFactionId: factions.first.id,
      victoryCondition: victoryCondition,
      factions: gameFactions,
      tiles: tiles,
      colonies: colonies,
      units: units,
      diplomacy: _initialDiplomacyFor(factions, startingDiplomacy),
      commandHistory: const <CommandRecord>[],
      reports: <TurnReport>[
        TurnReport(
          title: 'Planetfall complete',
          message:
              '${factions.length} factions have established starting colonies. '
              'Starting relations: ${startingDiplomacyLabelFor(startingDiplomacy)}. '
              'Victory condition: ${victoryConditionLabelFor(victoryCondition)}. '
              'Map intel: ${startingIntelLabelFor(startingIntel)}. '
              'Supplies: ${startingResourcesLabelFor(startingResources)}.',
        ),
      ],
    );
  }

  static String _defaultSessionIdFor(GameSetup setup) {
    final factionIds = setup.factions.map((faction) => faction.id).join('-');
    final diplomacySlug =
        setup.startingDiplomacy == OpenDeadlockGame.diplomacyStatusWar
            ? ''
            : '-${setup.startingDiplomacy}';
    final victorySlug =
        setup.victoryCondition == OpenDeadlockGame.victoryConditionAny
            ? ''
            : '-${setup.victoryCondition}';
    final intelSlug = setup.startingIntel == startingIntelHomeRegion
        ? ''
        : '-${setup.startingIntel}intel';
    final resourcesSlug = setup.startingResources == startingResourcesStandard
        ? ''
        : '-${setup.startingResources}res';
    if (setup.worldSeed != 0) {
      return 'setup-${setup.mapSize}-${setup.planetType}$diplomacySlug$victorySlug$intelSlug$resourcesSlug-seed${setup.worldSeed}-$factionIds';
    }
    return 'setup-${setup.mapSize}-${setup.planetType}$diplomacySlug$victorySlug$intelSlug$resourcesSlug-$factionIds';
  }

  static bool _startingIntelRevealsTile(
    String startingIntel,
    _SetupPoint home,
    _SetupPoint scout,
    int x,
    int y,
  ) {
    if (startingIntel == startingIntelFullMap) {
      return true;
    }
    if (startingIntel == startingIntelHomeRegion) {
      return _manhattanDistance(home.x, home.y, x, y) <= 2;
    }
    if (startingIntel == startingIntelClassicFog) {
      return (home.x == x && home.y == y) || (scout.x == x && scout.y == y);
    }
    throw ArgumentError('Unknown starting intel: $startingIntel.');
  }

  static List<DiplomacyRelation> _initialDiplomacyFor(
    List<GameSetupFaction> factions,
    String startingDiplomacy,
  ) {
    final relations = <DiplomacyRelation>[];
    for (var a = 0; a < factions.length; a += 1) {
      for (var b = a + 1; b < factions.length; b += 1) {
        relations.add(
          DiplomacyRelation.between(
            factionId: factions[a].id,
            targetFactionId: factions[b].id,
            status: startingDiplomacy,
          ),
        );
      }
    }
    return relations;
  }

  static ResourceStockpile _startingResourcesFor(
    int index,
    String startingResources,
  ) {
    if (startingResources == startingResourcesScarce) {
      if (index == 0) {
        return const ResourceStockpile(
          food: 12,
          industry: 4,
          research: 0,
          credits: 12,
        );
      }
      return const ResourceStockpile(
        food: 10,
        industry: 3,
        research: 0,
        credits: 9,
      );
    }
    if (startingResources == startingResourcesStandard && index == 0) {
      return const ResourceStockpile(
        food: 18,
        industry: 8,
        research: 0,
        credits: 24,
      );
    }
    if (startingResources == startingResourcesStandard) {
      return const ResourceStockpile(
        food: 14,
        industry: 6,
        research: 0,
        credits: 18,
      );
    }
    if (startingResources == startingResourcesAbundant) {
      if (index == 0) {
        return const ResourceStockpile(
          food: 28,
          industry: 14,
          research: 4,
          credits: 40,
        );
      }
      return const ResourceStockpile(
        food: 24,
        industry: 12,
        research: 4,
        credits: 34,
      );
    }
    throw ArgumentError('Unknown starting resources: $startingResources.');
  }

  static String _capitalNameFor(GameSetupFaction faction, int index) {
    if (faction.id == 'humans') {
      return 'New Haven';
    }
    if (faction.id == 'rebels') {
      return 'Redoubt';
    }
    if (faction.id == 'traders') {
      return 'Exchange';
    }
    return 'Capital ${index + 1}';
  }

  static List<_SetupPoint> _homePositions(
      int width, int height, int factionCount) {
    return <_SetupPoint>[
      _SetupPoint(2, _clampSetupInt(2, 1, height - 2)),
      _SetupPoint(width - 3, _clampSetupInt(height - 3, 1, height - 2)),
      _SetupPoint(width ~/ 2, height - 2),
      _SetupPoint(width ~/ 2, 1),
    ].take(factionCount).toList();
  }

  static _SetupPoint _scoutPositionFor(
    _SetupPoint home,
    int width,
    int height,
    String planetType,
    int worldSeed,
  ) {
    final candidates = <_SetupPoint>[
      _SetupPoint(home.x + 1, home.y),
      _SetupPoint(home.x, home.y - 1),
      _SetupPoint(home.x - 1, home.y),
      _SetupPoint(home.x, home.y + 1),
    ];
    for (final candidate in candidates) {
      if (candidate.x >= 0 &&
          candidate.y >= 0 &&
          candidate.x < width &&
          candidate.y < height &&
          _terrainFor(candidate.x, candidate.y, planetType, worldSeed) !=
              'water') {
        return candidate;
      }
    }
    return home;
  }

  static String _terrainFor(int x, int y, String planetType, int worldSeed) {
    const terranCycle = <String>[
      'plains',
      'forest',
      'ridge',
      'water',
      'ruins',
    ];
    const verdantCycle = <String>[
      'forest',
      'plains',
      'forest',
      'water',
      'plains',
    ];
    const mineralCycle = <String>[
      'ridge',
      'plains',
      'ridge',
      'forest',
      'water',
    ];
    const ancientCycle = <String>[
      'ruins',
      'plains',
      'ridge',
      'ruins',
      'forest',
    ];
    final terrainCycle = planetType == planetTypeVerdant
        ? verdantCycle
        : planetType == planetTypeMineral
            ? mineralCycle
            : planetType == planetTypeAncient
                ? ancientCycle
                : terranCycle;
    return terrainCycle[_terrainCycleIndexFor(
      x,
      y,
      worldSeed,
      terrainCycle.length,
    )];
  }

  static int _terrainCycleIndexFor(
    int x,
    int y,
    int worldSeed,
    int cycleLength,
  ) {
    final baseIndex = x + (y * 2);
    if (worldSeed == 0) {
      return baseIndex % cycleLength;
    }
    final xStep = (worldSeed % 3) + 1;
    final yStep = (worldSeed % 5) + 1;
    return (baseIndex + (worldSeed % cycleLength) + (x * xStep) + (y * yStep)) %
        cycleLength;
  }

  static String _capitalTerrainFor(String planetType) {
    if (planetType == planetTypeVerdant) {
      return 'forest';
    }
    if (planetType == planetTypeMineral) {
      return 'ridge';
    }
    if (planetType == planetTypeAncient) {
      return 'ruins';
    }
    return 'plains';
  }

  static TileYield _yieldsFor(String terrain, String planetType) {
    final baseYield = _baseYieldFor(terrain);
    if (planetType == planetTypeVerdant) {
      return TileYield(
        food: baseYield.food + 1,
        industry: baseYield.industry,
        research: baseYield.research,
      );
    }
    if (planetType == planetTypeMineral) {
      return TileYield(
        food: baseYield.food,
        industry: baseYield.industry + 1,
        research: baseYield.research,
      );
    }
    if (planetType == planetTypeAncient) {
      return TileYield(
        food: baseYield.food,
        industry: baseYield.industry,
        research: baseYield.research + 1,
      );
    }
    return baseYield;
  }

  static TileYield _baseYieldFor(String terrain) {
    if (terrain == 'plains') {
      return const TileYield(food: 3, industry: 1, research: 0);
    }
    if (terrain == 'forest') {
      return const TileYield(food: 2, industry: 2, research: 0);
    }
    if (terrain == 'ridge') {
      return const TileYield(food: 1, industry: 3, research: 0);
    }
    if (terrain == 'water') {
      return const TileYield(food: 2, industry: 0, research: 1);
    }
    if (terrain == 'ruins') {
      return const TileYield(food: 0, industry: 1, research: 3);
    }
    throw ArgumentError('Unknown terrain: $terrain.');
  }
}

class _SetupPoint {
  const _SetupPoint(this.x, this.y);

  final int x;
  final int y;
}

int _readSetupInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  throw ArgumentError('Expected an integer-compatible value, got $value.');
}

String _legacySetupRaceId(String factionId) {
  if (factionId == 'rebels') {
    return 'tarth';
  }
  if (factionId == 'traders') {
    return 'uva_mosk';
  }
  return 'human';
}

String _knownSetupAiPersonalityOrDefault(String? aiPersonality) {
  if (aiPersonality != null && Faction.isKnownAiPersonality(aiPersonality)) {
    return aiPersonality;
  }
  return Faction.aiPersonalityAdaptive;
}

RaceProfile _raceProfileForSetup(String raceId) {
  final race = OpenDeadlockGame.raceCatalog[raceId];
  if (race == null) {
    throw ArgumentError('Unknown race: $raceId.');
  }
  return race;
}

FactionTrait _traitForSetup(String traitId) {
  final trait = OpenDeadlockGame.factionTraitCatalog[traitId];
  if (trait == null) {
    throw ArgumentError('Unknown faction trait: $traitId.');
  }
  return trait;
}

void _appendSignedEffect(List<String> effects, int amount, String label) {
  if (amount == 0) {
    return;
  }
  final sign = amount > 0 ? '+' : '';
  effects.add('$sign$amount $label');
}

String _sentenceFromEffects(List<String> effects) {
  return '${effects.join('; ')}.';
}

int _clampSetupInt(int value, int minimum, int maximum) {
  if (value < minimum) {
    return minimum;
  }
  if (value > maximum) {
    return maximum;
  }
  return value;
}

int _manhattanDistance(int ax, int ay, int bx, int by) {
  final dx = ax - bx;
  final dy = ay - by;
  return (dx < 0 ? -dx : dx) + (dy < 0 ? -dy : dy);
}
