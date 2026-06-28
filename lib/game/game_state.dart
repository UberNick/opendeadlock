class ResourceStockpile {
  const ResourceStockpile({
    required this.food,
    required this.industry,
    required this.research,
    required this.credits,
  });

  final int food;
  final int industry;
  final int research;
  final int credits;

  ResourceStockpile operator +(ResourceStockpile other) {
    return ResourceStockpile(
      food: food + other.food,
      industry: industry + other.industry,
      research: research + other.research,
      credits: credits + other.credits,
    );
  }

  ResourceStockpile copyWith({
    int? food,
    int? industry,
    int? research,
    int? credits,
  }) {
    return ResourceStockpile(
      food: food ?? this.food,
      industry: industry ?? this.industry,
      research: research ?? this.research,
      credits: credits ?? this.credits,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'food': food,
      'industry': industry,
      'research': research,
      'credits': credits,
    };
  }

  static ResourceStockpile fromJson(Map<String, dynamic> json) {
    return ResourceStockpile(
      food: _readInt(json['food']),
      industry: _readInt(json['industry']),
      research: _readInt(json['research']),
      credits: _readInt(json['credits']),
    );
  }
}

class FactionTrait {
  const FactionTrait({
    required this.id,
    required this.name,
    required this.description,
    this.foodBonus = 0,
    this.industryBonus = 0,
    this.researchBonus = 0,
    this.creditBonus = 0,
    this.preferredConstruction,
    this.preferredResearch,
  });

  final String id;
  final String name;
  final String description;
  final int foodBonus;
  final int industryBonus;
  final int researchBonus;
  final int creditBonus;
  final String? preferredConstruction;
  final String? preferredResearch;
}

class RaceProfile {
  const RaceProfile({
    required this.id,
    required this.name,
    required this.description,
    this.foodBonus = 0,
    this.industryBonus = 0,
    this.researchBonus = 0,
    this.creditBonus = 0,
    this.constructionBonus = 0,
    this.populationGrowthBonus = 0,
    this.attackBonus = 0,
    this.moraleFloor = 0,
    this.revealsMap = false,
    this.preferredConstruction,
    this.preferredResearch,
  });

  final String id;
  final String name;
  final String description;
  final int foodBonus;
  final int industryBonus;
  final int researchBonus;
  final int creditBonus;
  final int constructionBonus;
  final int populationGrowthBonus;
  final int attackBonus;
  final int moraleFloor;
  final bool revealsMap;
  final String? preferredConstruction;
  final String? preferredResearch;
}

class Faction {
  const Faction({
    required this.id,
    required this.name,
    required this.colorValue,
    required bool isComputer,
    required this.resources,
    this.raceId = 'human',
    String? controlMode,
    this.difficulty = difficultyNormal,
    this.taxPolicy = taxPolicyBalanced,
    this.aiPersonality = aiPersonalityAdaptive,
    this.researchProject = 'Hydroponics',
    this.completedResearch = const <String>[],
    this.traitIds = const <String>[],
  }) : controlMode =
            controlMode ?? (isComputer ? controlComputer : controlLocal);

  static const String controlLocal = 'local';
  static const String controlComputer = 'computer';
  static const String controlRemote = 'remote';
  static const String difficultyEasy = 'easy';
  static const String difficultyNormal = 'normal';
  static const String difficultyHard = 'hard';
  static const String taxPolicyRelief = 'relief';
  static const String taxPolicyBalanced = 'balanced';
  static const String taxPolicyHigh = 'high';
  static const String taxPolicyEmergency = 'emergency';
  static const String aiPersonalityAdaptive = 'adaptive';
  static const String aiPersonalityExpansionist = 'expansionist';
  static const String aiPersonalityConqueror = 'conqueror';
  static const String aiPersonalityResearcher = 'researcher';
  static const String aiPersonalityTrader = 'trader';
  static const List<String> controlModes = <String>[
    controlLocal,
    controlComputer,
    controlRemote,
  ];
  static const List<String> difficultyLevels = <String>[
    difficultyEasy,
    difficultyNormal,
    difficultyHard,
  ];
  static const List<String> taxPolicies = <String>[
    taxPolicyRelief,
    taxPolicyBalanced,
    taxPolicyHigh,
    taxPolicyEmergency,
  ];
  static const List<String> aiPersonalities = <String>[
    aiPersonalityAdaptive,
    aiPersonalityExpansionist,
    aiPersonalityConqueror,
    aiPersonalityResearcher,
    aiPersonalityTrader,
  ];

  final String id;
  final String name;
  final int colorValue;
  final String raceId;
  final String controlMode;
  final String difficulty;
  final String taxPolicy;
  final String aiPersonality;
  final ResourceStockpile resources;
  final String researchProject;
  final List<String> completedResearch;
  final List<String> traitIds;

  bool get isComputer {
    return controlMode == controlComputer;
  }

  bool get isLocal {
    return controlMode == controlLocal;
  }

  bool get isRemote {
    return controlMode == controlRemote;
  }

  static bool isKnownControlMode(String controlMode) {
    return controlModes.contains(controlMode);
  }

  static bool isKnownDifficulty(String difficulty) {
    return difficultyLevels.contains(difficulty);
  }

  static bool isKnownTaxPolicy(String taxPolicy) {
    return taxPolicies.contains(taxPolicy);
  }

  static bool isKnownAiPersonality(String aiPersonality) {
    return aiPersonalities.contains(aiPersonality);
  }

  static String controlModeLabelFor(String controlMode) {
    if (controlMode == controlLocal) {
      return 'Local';
    }
    if (controlMode == controlComputer) {
      return 'AI';
    }
    if (controlMode == controlRemote) {
      return 'Remote';
    }
    return controlMode;
  }

  static String difficultyLabelFor(String difficulty) {
    if (difficulty == difficultyEasy) {
      return 'Easy';
    }
    if (difficulty == difficultyNormal) {
      return 'Normal';
    }
    if (difficulty == difficultyHard) {
      return 'Hard';
    }
    return difficulty;
  }

  static String taxPolicyLabelFor(String taxPolicy) {
    if (taxPolicy == taxPolicyRelief) {
      return 'Relief';
    }
    if (taxPolicy == taxPolicyBalanced) {
      return 'Balanced';
    }
    if (taxPolicy == taxPolicyHigh) {
      return 'High';
    }
    if (taxPolicy == taxPolicyEmergency) {
      return 'Emergency';
    }
    return taxPolicy;
  }

  static String taxPolicyDescriptionFor(String taxPolicy) {
    if (taxPolicy == taxPolicyRelief) {
      return '-2 credits, +2 morale.';
    }
    if (taxPolicy == taxPolicyBalanced) {
      return 'No tax pressure.';
    }
    if (taxPolicy == taxPolicyHigh) {
      return '+3 credits, -2 morale.';
    }
    if (taxPolicy == taxPolicyEmergency) {
      return '+5 credits, -5 morale.';
    }
    return 'Unknown policy.';
  }

  static String aiPersonalityLabelFor(String aiPersonality) {
    if (aiPersonality == aiPersonalityExpansionist) {
      return 'Expansionist';
    }
    if (aiPersonality == aiPersonalityConqueror) {
      return 'Conqueror';
    }
    if (aiPersonality == aiPersonalityResearcher) {
      return 'Researcher';
    }
    if (aiPersonality == aiPersonalityTrader) {
      return 'Trader';
    }
    if (aiPersonality == aiPersonalityAdaptive) {
      return 'Adaptive';
    }
    return aiPersonality;
  }

  static String aiPersonalityDescriptionFor(String aiPersonality) {
    if (aiPersonality == aiPersonalityExpansionist) {
      return 'Prioritizes growth, scouts, and claimable sectors.';
    }
    if (aiPersonality == aiPersonalityConqueror) {
      return 'Prioritizes military infrastructure and offensive openings.';
    }
    if (aiPersonality == aiPersonalityResearcher) {
      return 'Prioritizes research labs, science focus, and research projects.';
    }
    if (aiPersonality == aiPersonalityTrader) {
      return 'Prioritizes revenue, stable taxes, and trade-friendly diplomacy.';
    }
    if (aiPersonality == aiPersonalityAdaptive) {
      return 'Balances economy, research, military, and local conditions.';
    }
    return 'Unknown AI profile.';
  }

  Faction copyWith({
    ResourceStockpile? resources,
    String? raceId,
    bool? isComputer,
    String? controlMode,
    String? difficulty,
    String? taxPolicy,
    String? aiPersonality,
    String? researchProject,
    List<String>? completedResearch,
    List<String>? traitIds,
  }) {
    return Faction(
      id: id,
      name: name,
      colorValue: colorValue,
      raceId: raceId ?? this.raceId,
      isComputer: isComputer ?? this.isComputer,
      controlMode:
          controlMode ?? (isComputer == null ? this.controlMode : null),
      difficulty: difficulty ?? this.difficulty,
      taxPolicy: taxPolicy ?? this.taxPolicy,
      aiPersonality: aiPersonality ?? this.aiPersonality,
      resources: resources ?? this.resources,
      researchProject: researchProject ?? this.researchProject,
      completedResearch: completedResearch ?? this.completedResearch,
      traitIds: traitIds ?? this.traitIds,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'colorValue': colorValue,
      'raceId': raceId,
      'isComputer': isComputer,
      'controlMode': controlMode,
      'difficulty': difficulty,
      'taxPolicy': taxPolicy,
      'aiPersonality': aiPersonality,
      'resources': resources.toJson(),
      'researchProject': researchProject,
      'completedResearch': completedResearch,
      'traitIds': traitIds,
    };
  }

  static Faction fromJson(Map<String, dynamic> json) {
    return Faction(
      id: json['id'] as String,
      name: json['name'] as String,
      colorValue: _readInt(json['colorValue']),
      raceId:
          json['raceId'] as String? ?? _legacyRaceIdFor(json['id'] as String),
      isComputer: json['isComputer'] as bool? ?? false,
      controlMode: json['controlMode'] as String?,
      difficulty: json['difficulty'] as String? ?? difficultyNormal,
      taxPolicy: json['taxPolicy'] as String? ?? taxPolicyBalanced,
      aiPersonality:
          _knownAiPersonalityOrDefault(json['aiPersonality'] as String?),
      resources:
          ResourceStockpile.fromJson(json['resources'] as Map<String, dynamic>),
      researchProject: json['researchProject'] as String? ?? 'Hydroponics',
      completedResearch:
          (json['completedResearch'] as List<dynamic>? ?? const <dynamic>[])
              .map((research) => research as String)
              .toList(),
      traitIds: (json['traitIds'] as List<dynamic>? ?? const <dynamic>[])
          .map((traitId) => traitId as String)
          .toList(),
    );
  }
}

String _knownAiPersonalityOrDefault(String? aiPersonality) {
  if (aiPersonality != null && Faction.isKnownAiPersonality(aiPersonality)) {
    return aiPersonality;
  }
  return Faction.aiPersonalityAdaptive;
}

class TileYield {
  const TileYield({
    required this.food,
    required this.industry,
    required this.research,
  });

  final int food;
  final int industry;
  final int research;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'food': food,
      'industry': industry,
      'research': research,
    };
  }

  static TileYield fromJson(Map<String, dynamic> json) {
    return TileYield(
      food: _readInt(json['food']),
      industry: _readInt(json['industry']),
      research: _readInt(json['research']),
    );
  }
}

class SectorAssignment {
  const SectorAssignment({
    required this.x,
    required this.y,
  });

  final int x;
  final int y;

  bool matches(int targetX, int targetY) {
    return x == targetX && y == targetY;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'x': x,
      'y': y,
    };
  }

  static SectorAssignment fromJson(Map<String, dynamic> json) {
    return SectorAssignment(
      x: _readInt(json['x']),
      y: _readInt(json['y']),
    );
  }
}

class PlanetTile {
  const PlanetTile({
    required this.x,
    required this.y,
    required this.terrain,
    required this.yields,
    this.ownerId,
    this.colonyId,
    this.explored = true,
    this.exploredBy = const <String>[],
  });

  final int x;
  final int y;
  final String terrain;
  final TileYield yields;
  final String? ownerId;
  final String? colonyId;
  final bool explored;
  final List<String> exploredBy;

  PlanetTile copyWith({
    String? ownerId,
    String? colonyId,
    bool? explored,
    List<String>? exploredBy,
  }) {
    return PlanetTile(
      x: x,
      y: y,
      terrain: terrain,
      yields: yields,
      ownerId: ownerId ?? this.ownerId,
      colonyId: colonyId ?? this.colonyId,
      explored: explored ?? this.explored,
      exploredBy: exploredBy ?? this.exploredBy,
    );
  }

  bool isExploredBy(String factionId) {
    return exploredBy.isEmpty ? explored : exploredBy.contains(factionId);
  }

  PlanetTile revealTo(String factionId) {
    if (exploredBy.contains(factionId)) {
      return copyWith(explored: true);
    }
    return copyWith(
      explored: true,
      exploredBy: <String>[
        ...exploredBy,
        factionId,
      ],
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'x': x,
      'y': y,
      'terrain': terrain,
      'yields': yields.toJson(),
      'ownerId': ownerId,
      'colonyId': colonyId,
      'explored': explored,
      'exploredBy': exploredBy,
    };
  }

  static PlanetTile fromJson(Map<String, dynamic> json) {
    return PlanetTile(
      x: _readInt(json['x']),
      y: _readInt(json['y']),
      terrain: json['terrain'] as String,
      yields: TileYield.fromJson(json['yields'] as Map<String, dynamic>),
      ownerId: json['ownerId'] as String?,
      colonyId: json['colonyId'] as String?,
      explored: json['explored'] as bool? ?? true,
      exploredBy: (json['exploredBy'] as List<dynamic>? ?? const <dynamic>[])
          .map((factionId) => factionId as String)
          .toList(),
    );
  }
}

class Colony {
  const Colony({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.x,
    required this.y,
    required this.population,
    required this.morale,
    required this.construction,
    required this.storedIndustry,
    required this.completedBuildings,
    this.focus = OpenDeadlockGame.colonyFocusBalanced,
    this.assignedSectors = const <SectorAssignment>[],
  });

  final String id;
  final String name;
  final String ownerId;
  final int x;
  final int y;
  final int population;
  final int morale;
  final String construction;
  final int storedIndustry;
  final List<String> completedBuildings;
  final String focus;
  final List<SectorAssignment> assignedSectors;

  Colony copyWith({
    String? ownerId,
    int? population,
    int? morale,
    String? construction,
    int? storedIndustry,
    List<String>? completedBuildings,
    String? focus,
    List<SectorAssignment>? assignedSectors,
  }) {
    return Colony(
      id: id,
      name: name,
      ownerId: ownerId ?? this.ownerId,
      x: x,
      y: y,
      population: population ?? this.population,
      morale: morale ?? this.morale,
      construction: construction ?? this.construction,
      storedIndustry: storedIndustry ?? this.storedIndustry,
      completedBuildings: completedBuildings ?? this.completedBuildings,
      focus: focus ?? this.focus,
      assignedSectors: assignedSectors ?? this.assignedSectors,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'ownerId': ownerId,
      'x': x,
      'y': y,
      'population': population,
      'morale': morale,
      'construction': construction,
      'storedIndustry': storedIndustry,
      'completedBuildings': completedBuildings,
      'focus': focus,
      'assignedSectors':
          assignedSectors.map((assignment) => assignment.toJson()).toList(),
    };
  }

  static Colony fromJson(Map<String, dynamic> json) {
    return Colony(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['ownerId'] as String,
      x: _readInt(json['x']),
      y: _readInt(json['y']),
      population: _readInt(json['population']),
      morale: _readInt(json['morale']),
      construction: json['construction'] as String,
      storedIndustry: _readInt(json['storedIndustry']),
      completedBuildings:
          (json['completedBuildings'] as List<dynamic>? ?? const <dynamic>[])
              .map((building) => building as String)
              .toList(),
      focus: json['focus'] as String? ?? OpenDeadlockGame.colonyFocusBalanced,
      assignedSectors:
          (json['assignedSectors'] as List<dynamic>? ?? const <dynamic>[])
              .map((assignment) =>
                  SectorAssignment.fromJson(assignment as Map<String, dynamic>))
              .toList(),
    );
  }
}

class ColonyProduction {
  const ColonyProduction({
    required this.output,
    required this.constructionWork,
    required this.foodDemand,
    required this.foodBalance,
    required this.housingCapacity,
    required this.buildingUpkeep,
    required this.populationChange,
    required this.moraleChange,
    required this.nextPopulation,
    required this.nextMorale,
    required this.willCompleteConstruction,
    required this.workedSectors,
    required this.assignedSectorCapacity,
    required this.workedYields,
    required this.moraleOutputAdjustment,
    required this.riotIndustryLoss,
  });

  final ResourceStockpile output;
  final int constructionWork;
  final int foodDemand;
  final int foodBalance;
  final int housingCapacity;
  final int buildingUpkeep;
  final int populationChange;
  final int moraleChange;
  final int nextPopulation;
  final int nextMorale;
  final bool willCompleteConstruction;
  final int workedSectors;
  final int assignedSectorCapacity;
  final TileYield workedYields;
  final ResourceStockpile moraleOutputAdjustment;
  final int riotIndustryLoss;

  bool get isStarving {
    return foodBalance < 0;
  }

  bool get willGrow {
    return populationChange > 0;
  }

  bool get isAtHousingCapacity {
    return nextPopulation >= housingCapacity;
  }

  bool get isInUnrest {
    return moraleOutputAdjustment.food < 0 ||
        moraleOutputAdjustment.industry < 0 ||
        moraleOutputAdjustment.research < 0 ||
        moraleOutputAdjustment.credits < 0;
  }

  bool get isRioting {
    return riotIndustryLoss > 0;
  }
}

class FactionWorldSummary {
  const FactionWorldSummary({
    required this.factionId,
    required this.factionName,
    required this.colorValue,
    required this.controlMode,
    required this.raceName,
    required this.colonyCount,
    required this.totalColonyCount,
    required this.unitCount,
    required this.controlledSectors,
    required this.exploredSectors,
    required this.totalPopulation,
    required this.projectedProduction,
    required this.atWarCount,
    required this.visibleEnemyColonies,
    required this.coreResearchCompleted,
    required this.coreResearchTotal,
    required this.isDefeated,
  });

  final String factionId;
  final String factionName;
  final int colorValue;
  final String controlMode;
  final String raceName;
  final int colonyCount;
  final int totalColonyCount;
  final int unitCount;
  final int controlledSectors;
  final int exploredSectors;
  final int totalPopulation;
  final ResourceStockpile projectedProduction;
  final int atWarCount;
  final int visibleEnemyColonies;
  final int coreResearchCompleted;
  final int coreResearchTotal;
  final bool isDefeated;

  int get victorySharePercent {
    if (totalColonyCount <= 0) {
      return 0;
    }
    return (colonyCount * 100) ~/ totalColonyCount;
  }

  bool get hasConquestVictory {
    return totalColonyCount > 0 && colonyCount == totalColonyCount;
  }

  String get victoryProgressLabel {
    return '$colonyCount/$totalColonyCount colonies';
  }

  int get scienceVictorySharePercent {
    if (coreResearchTotal <= 0) {
      return 0;
    }
    return (coreResearchCompleted * 100) ~/ coreResearchTotal;
  }

  bool get hasScienceVictory {
    return coreResearchTotal > 0 && coreResearchCompleted == coreResearchTotal;
  }

  String get scienceVictoryProgressLabel {
    return '$coreResearchCompleted/$coreResearchTotal research';
  }
}

class FactionScore {
  const FactionScore({
    required this.factionId,
    required this.factionName,
    required this.colorValue,
    required this.controlMode,
    required this.raceName,
    required this.isDefeated,
    required this.colonyScore,
    required this.sectorScore,
    required this.populationScore,
    required this.militaryScore,
    required this.scienceScore,
    required this.reserveScore,
  });

  final String factionId;
  final String factionName;
  final int colorValue;
  final String controlMode;
  final String raceName;
  final bool isDefeated;
  final int colonyScore;
  final int sectorScore;
  final int populationScore;
  final int militaryScore;
  final int scienceScore;
  final int reserveScore;

  int get total {
    return colonyScore +
        sectorScore +
        populationScore +
        militaryScore +
        scienceScore +
        reserveScore;
  }
}

class Unit {
  const Unit({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.type,
    required this.x,
    required this.y,
    required this.movesRemaining,
    this.health = 5,
  });

  final String id;
  final String name;
  final String ownerId;
  final String type;
  final int x;
  final int y;
  final int movesRemaining;
  final int health;

  Unit copyWith({
    int? x,
    int? y,
    int? movesRemaining,
    int? health,
  }) {
    return Unit(
      id: id,
      name: name,
      ownerId: ownerId,
      type: type,
      x: x ?? this.x,
      y: y ?? this.y,
      movesRemaining: movesRemaining ?? this.movesRemaining,
      health: health ?? this.health,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'ownerId': ownerId,
      'type': type,
      'x': x,
      'y': y,
      'movesRemaining': movesRemaining,
      'health': health,
    };
  }

  static Unit fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    return Unit(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['ownerId'] as String,
      type: type,
      x: _readInt(json['x']),
      y: _readInt(json['y']),
      movesRemaining: _readInt(json['movesRemaining']),
      health: json['health'] == null
          ? _maxHealthForUnitType(type)
          : _readInt(json['health']),
    );
  }
}

class UnitCombatPreview {
  const UnitCombatPreview({
    required this.attacker,
    required this.defender,
    required this.attackDamage,
    required this.counterDamage,
    required this.attackerHealth,
    required this.defenderHealth,
    required this.attackerSurvives,
    required this.defenderSurvives,
  });

  final Unit attacker;
  final Unit defender;
  final int attackDamage;
  final int counterDamage;
  final int attackerHealth;
  final int defenderHealth;
  final bool attackerSurvives;
  final bool defenderSurvives;
}

class ColonyAssaultPreview {
  const ColonyAssaultPreview({
    required this.attacker,
    required this.colony,
    required this.attackPower,
    required this.defensePower,
    required this.counterDamage,
    required this.attackerHealth,
    required this.attackerSurvives,
    required this.colonyCaptured,
    required this.population,
    required this.morale,
  });

  final Unit attacker;
  final Colony colony;
  final int attackPower;
  final int defensePower;
  final int counterDamage;
  final int attackerHealth;
  final bool attackerSurvives;
  final bool colonyCaptured;
  final int population;
  final int morale;
}

class TurnReport {
  const TurnReport({
    required this.title,
    required this.message,
    this.category = categoryGeneral,
    this.details = const <String, String>{},
  });

  static const String categoryGeneral = 'general';
  static const String categoryBattle = 'battle';
  static const String categoryTactical = 'tactical';

  final String title;
  final String message;
  final String category;
  final Map<String, String> details;

  bool get isBattle {
    return category == categoryBattle;
  }

  bool get isTactical {
    return category == categoryBattle || category == categoryTactical;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'message': message,
      'category': category,
      'details': details,
    };
  }

  static TurnReport fromJson(Map<String, dynamic> json) {
    return TurnReport(
      title: json['title'] as String,
      message: json['message'] as String,
      category: json['category'] as String? ?? categoryGeneral,
      details: (json['details'] as Map<String, dynamic>? ??
              const <String, dynamic>{})
          .map((key, value) => MapEntry(key, value.toString())),
    );
  }
}

class DiplomacyRelation {
  const DiplomacyRelation({
    required this.factionAId,
    required this.factionBId,
    required this.status,
  });

  final String factionAId;
  final String factionBId;
  final String status;

  factory DiplomacyRelation.between({
    required String factionId,
    required String targetFactionId,
    required String status,
  }) {
    if (factionId.compareTo(targetFactionId) <= 0) {
      return DiplomacyRelation(
        factionAId: factionId,
        factionBId: targetFactionId,
        status: status,
      );
    }
    return DiplomacyRelation(
      factionAId: targetFactionId,
      factionBId: factionId,
      status: status,
    );
  }

  bool matches(String factionId, String targetFactionId) {
    return (factionAId == factionId && factionBId == targetFactionId) ||
        (factionAId == targetFactionId && factionBId == factionId);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'factionAId': factionAId,
      'factionBId': factionBId,
      'status': status,
    };
  }

  static DiplomacyRelation fromJson(Map<String, dynamic> json) {
    return DiplomacyRelation.between(
      factionId: json['factionAId'] as String,
      targetFactionId: json['factionBId'] as String,
      status: json['status'] as String,
    );
  }
}

class _IntelScanTarget {
  const _IntelScanTarget({
    required this.colony,
    required this.tiles,
  });

  final Colony colony;
  final List<PlanetTile> tiles;
}

class FactionSabotageTarget {
  const FactionSabotageTarget({
    required this.colonyId,
    required this.colonyName,
    required this.storedIndustry,
    required this.damage,
  });

  final String colonyId;
  final String colonyName;
  final int storedIndustry;
  final int damage;
}

class CommandRecord {
  const CommandRecord({
    required this.turn,
    required this.factionId,
    required this.command,
  });

  final int turn;
  final String factionId;
  final GameCommand command;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'turn': turn,
      'factionId': factionId,
      'command': command.toJson(),
    };
  }

  static CommandRecord fromJson(Map<String, dynamic> json) {
    return CommandRecord(
      turn: _readInt(json['turn']),
      factionId: json['factionId'] as String,
      command: GameCommand.fromJson(json['command'] as Map<String, dynamic>),
    );
  }
}

abstract class GameCommand {
  String get type;
  String get factionId;

  OpenDeadlockGame apply(OpenDeadlockGame game);
  Map<String, dynamic> toJson();

  static GameCommand fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    if (type == SetColonyConstructionCommand.commandType) {
      return SetColonyConstructionCommand.fromJson(json);
    }
    if (type == RushConstructionCommand.commandType) {
      return RushConstructionCommand.fromJson(json);
    }
    if (type == SetColonyFocusCommand.commandType) {
      return SetColonyFocusCommand.fromJson(json);
    }
    if (type == SetColonySectorAssignmentCommand.commandType) {
      return SetColonySectorAssignmentCommand.fromJson(json);
    }
    if (type == SetResearchProjectCommand.commandType) {
      return SetResearchProjectCommand.fromJson(json);
    }
    if (type == FundResearchCommand.commandType) {
      return FundResearchCommand.fromJson(json);
    }
    if (type == SetFactionControlCommand.commandType) {
      return SetFactionControlCommand.fromJson(json);
    }
    if (type == SetFactionDifficultyCommand.commandType) {
      return SetFactionDifficultyCommand.fromJson(json);
    }
    if (type == SetFactionTaxPolicyCommand.commandType) {
      return SetFactionTaxPolicyCommand.fromJson(json);
    }
    if (type == SetDiplomacyStatusCommand.commandType) {
      return SetDiplomacyStatusCommand.fromJson(json);
    }
    if (type == ScanFactionIntelCommand.commandType) {
      return ScanFactionIntelCommand.fromJson(json);
    }
    if (type == SabotageColonyCommand.commandType) {
      return SabotageColonyCommand.fromJson(json);
    }
    if (type == MoveUnitCommand.commandType) {
      return MoveUnitCommand.fromJson(json);
    }
    if (type == RecoverUnitCommand.commandType) {
      return RecoverUnitCommand.fromJson(json);
    }
    if (type == FoundColonyCommand.commandType) {
      return FoundColonyCommand.fromJson(json);
    }
    if (type == EndTurnCommand.commandType) {
      return EndTurnCommand.fromJson(json);
    }
    if (type == RunComputerTurnCommand.commandType) {
      return RunComputerTurnCommand.fromJson(json);
    }
    throw ArgumentError('Unknown command type: $type.');
  }
}

class SetColonyConstructionCommand implements GameCommand {
  const SetColonyConstructionCommand({
    required this.factionId,
    required this.colonyId,
    required this.construction,
  });

  static const String commandType = 'set_colony_construction';

  @override
  final String factionId;
  final String colonyId;
  final String construction;

  @override
  String get type => commandType;

  @override
  OpenDeadlockGame apply(OpenDeadlockGame game) {
    return game.setColonyConstruction(
      colonyId,
      construction,
      factionId: factionId,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'factionId': factionId,
      'colonyId': colonyId,
      'construction': construction,
    };
  }

  static SetColonyConstructionCommand fromJson(Map<String, dynamic> json) {
    return SetColonyConstructionCommand(
      factionId: json['factionId'] as String,
      colonyId: json['colonyId'] as String,
      construction: json['construction'] as String,
    );
  }
}

class RushConstructionCommand implements GameCommand {
  const RushConstructionCommand({
    required this.factionId,
    required this.colonyId,
    required this.industry,
  });

  static const String commandType = 'rush_construction';

  @override
  final String factionId;
  final String colonyId;
  final int industry;

  @override
  String get type => commandType;

  @override
  OpenDeadlockGame apply(OpenDeadlockGame game) {
    return game.rushConstruction(
      colonyId,
      industry,
      factionId: factionId,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'factionId': factionId,
      'colonyId': colonyId,
      'industry': industry,
    };
  }

  static RushConstructionCommand fromJson(Map<String, dynamic> json) {
    return RushConstructionCommand(
      factionId: json['factionId'] as String,
      colonyId: json['colonyId'] as String,
      industry: _readInt(json['industry']),
    );
  }
}

class SetColonyFocusCommand implements GameCommand {
  const SetColonyFocusCommand({
    required this.factionId,
    required this.colonyId,
    required this.focus,
  });

  static const String commandType = 'set_colony_focus';

  @override
  final String factionId;
  final String colonyId;
  final String focus;

  @override
  String get type => commandType;

  @override
  OpenDeadlockGame apply(OpenDeadlockGame game) {
    return game.setColonyFocus(
      colonyId,
      focus,
      factionId: factionId,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'factionId': factionId,
      'colonyId': colonyId,
      'focus': focus,
    };
  }

  static SetColonyFocusCommand fromJson(Map<String, dynamic> json) {
    return SetColonyFocusCommand(
      factionId: json['factionId'] as String,
      colonyId: json['colonyId'] as String,
      focus: json['focus'] as String,
    );
  }
}

class SetColonySectorAssignmentCommand implements GameCommand {
  const SetColonySectorAssignmentCommand({
    required this.factionId,
    required this.colonyId,
    required this.x,
    required this.y,
    required this.assigned,
  });

  static const String commandType = 'set_colony_sector_assignment';

  @override
  final String factionId;
  final String colonyId;
  final int x;
  final int y;
  final bool assigned;

  @override
  String get type => commandType;

  @override
  OpenDeadlockGame apply(OpenDeadlockGame game) {
    return game.setColonySectorAssignment(
      colonyId,
      x,
      y,
      assigned,
      factionId: factionId,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'factionId': factionId,
      'colonyId': colonyId,
      'x': x,
      'y': y,
      'assigned': assigned,
    };
  }

  static SetColonySectorAssignmentCommand fromJson(Map<String, dynamic> json) {
    return SetColonySectorAssignmentCommand(
      factionId: json['factionId'] as String,
      colonyId: json['colonyId'] as String,
      x: _readInt(json['x']),
      y: _readInt(json['y']),
      assigned: json['assigned'] as bool? ?? true,
    );
  }
}

class SetResearchProjectCommand implements GameCommand {
  const SetResearchProjectCommand({
    required this.factionId,
    required this.researchProject,
  });

  static const String commandType = 'set_research_project';

  @override
  final String factionId;
  final String researchProject;

  @override
  String get type => commandType;

  @override
  OpenDeadlockGame apply(OpenDeadlockGame game) {
    return game.setResearchProject(
      factionId,
      researchProject,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'factionId': factionId,
      'researchProject': researchProject,
    };
  }

  static SetResearchProjectCommand fromJson(Map<String, dynamic> json) {
    return SetResearchProjectCommand(
      factionId: json['factionId'] as String,
      researchProject: json['researchProject'] as String,
    );
  }
}

class FundResearchCommand implements GameCommand {
  const FundResearchCommand({
    required this.factionId,
    required this.research,
  });

  static const String commandType = 'fund_research';

  @override
  final String factionId;
  final int research;

  @override
  String get type => commandType;

  @override
  OpenDeadlockGame apply(OpenDeadlockGame game) {
    return game.fundResearch(factionId, research);
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'factionId': factionId,
      'research': research,
    };
  }

  static FundResearchCommand fromJson(Map<String, dynamic> json) {
    return FundResearchCommand(
      factionId: json['factionId'] as String,
      research: _readInt(json['research']),
    );
  }
}

class SetFactionControlCommand implements GameCommand {
  const SetFactionControlCommand({
    required this.factionId,
    required this.controlMode,
  });

  static const String commandType = 'set_faction_control';

  @override
  final String factionId;
  final String controlMode;

  @override
  String get type => commandType;

  @override
  OpenDeadlockGame apply(OpenDeadlockGame game) {
    return game.setFactionControl(factionId, controlMode);
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'factionId': factionId,
      'controlMode': controlMode,
    };
  }

  static SetFactionControlCommand fromJson(Map<String, dynamic> json) {
    return SetFactionControlCommand(
      factionId: json['factionId'] as String,
      controlMode: json['controlMode'] as String,
    );
  }
}

class SetFactionDifficultyCommand implements GameCommand {
  const SetFactionDifficultyCommand({
    required this.factionId,
    required this.difficulty,
  });

  static const String commandType = 'set_faction_difficulty';

  @override
  final String factionId;
  final String difficulty;

  @override
  String get type => commandType;

  @override
  OpenDeadlockGame apply(OpenDeadlockGame game) {
    return game.setFactionDifficulty(factionId, difficulty);
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'factionId': factionId,
      'difficulty': difficulty,
    };
  }

  static SetFactionDifficultyCommand fromJson(Map<String, dynamic> json) {
    return SetFactionDifficultyCommand(
      factionId: json['factionId'] as String,
      difficulty: json['difficulty'] as String,
    );
  }
}

class SetFactionTaxPolicyCommand implements GameCommand {
  const SetFactionTaxPolicyCommand({
    required this.factionId,
    required this.taxPolicy,
  });

  static const String commandType = 'set_faction_tax_policy';

  @override
  final String factionId;
  final String taxPolicy;

  @override
  String get type => commandType;

  @override
  OpenDeadlockGame apply(OpenDeadlockGame game) {
    return game.setFactionTaxPolicy(factionId, taxPolicy);
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'factionId': factionId,
      'taxPolicy': taxPolicy,
    };
  }

  static SetFactionTaxPolicyCommand fromJson(Map<String, dynamic> json) {
    return SetFactionTaxPolicyCommand(
      factionId: json['factionId'] as String,
      taxPolicy: json['taxPolicy'] as String,
    );
  }
}

class SetDiplomacyStatusCommand implements GameCommand {
  const SetDiplomacyStatusCommand({
    required this.factionId,
    required this.targetFactionId,
    required this.status,
  });

  static const String commandType = 'set_diplomacy_status';

  @override
  final String factionId;
  final String targetFactionId;
  final String status;

  @override
  String get type => commandType;

  @override
  OpenDeadlockGame apply(OpenDeadlockGame game) {
    return game.setDiplomacyStatus(
      factionId,
      targetFactionId,
      status,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'factionId': factionId,
      'targetFactionId': targetFactionId,
      'status': status,
    };
  }

  static SetDiplomacyStatusCommand fromJson(Map<String, dynamic> json) {
    return SetDiplomacyStatusCommand(
      factionId: json['factionId'] as String,
      targetFactionId: json['targetFactionId'] as String,
      status: json['status'] as String,
    );
  }
}

class ScanFactionIntelCommand implements GameCommand {
  const ScanFactionIntelCommand({
    required this.factionId,
    required this.targetFactionId,
  });

  static const String commandType = 'scan_faction_intel';

  @override
  final String factionId;
  final String targetFactionId;

  @override
  String get type => commandType;

  @override
  OpenDeadlockGame apply(OpenDeadlockGame game) {
    return game.scanFactionIntel(factionId, targetFactionId);
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'factionId': factionId,
      'targetFactionId': targetFactionId,
    };
  }

  static ScanFactionIntelCommand fromJson(Map<String, dynamic> json) {
    return ScanFactionIntelCommand(
      factionId: json['factionId'] as String,
      targetFactionId: json['targetFactionId'] as String,
    );
  }
}

class SabotageColonyCommand implements GameCommand {
  const SabotageColonyCommand({
    required this.factionId,
    required this.targetFactionId,
  });

  static const String commandType = 'sabotage_colony';

  @override
  final String factionId;
  final String targetFactionId;

  @override
  String get type => commandType;

  @override
  OpenDeadlockGame apply(OpenDeadlockGame game) {
    return game.sabotageColony(factionId, targetFactionId);
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'factionId': factionId,
      'targetFactionId': targetFactionId,
    };
  }

  static SabotageColonyCommand fromJson(Map<String, dynamic> json) {
    return SabotageColonyCommand(
      factionId: json['factionId'] as String,
      targetFactionId: json['targetFactionId'] as String,
    );
  }
}

class MoveUnitCommand implements GameCommand {
  const MoveUnitCommand({
    required this.factionId,
    required this.unitId,
    required this.x,
    required this.y,
  });

  static const String commandType = 'move_unit';

  @override
  final String factionId;
  final String unitId;
  final int x;
  final int y;

  @override
  String get type => commandType;

  @override
  OpenDeadlockGame apply(OpenDeadlockGame game) {
    return game.moveUnit(
      unitId,
      x,
      y,
      factionId: factionId,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'factionId': factionId,
      'unitId': unitId,
      'x': x,
      'y': y,
    };
  }

  static MoveUnitCommand fromJson(Map<String, dynamic> json) {
    return MoveUnitCommand(
      factionId: json['factionId'] as String,
      unitId: json['unitId'] as String,
      x: _readInt(json['x']),
      y: _readInt(json['y']),
    );
  }
}

class RecoverUnitCommand implements GameCommand {
  const RecoverUnitCommand({
    required this.factionId,
    required this.unitId,
  });

  static const String commandType = 'recover_unit';

  @override
  final String factionId;
  final String unitId;

  @override
  String get type => commandType;

  @override
  OpenDeadlockGame apply(OpenDeadlockGame game) {
    return game.recoverUnit(
      unitId,
      factionId: factionId,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'factionId': factionId,
      'unitId': unitId,
    };
  }

  static RecoverUnitCommand fromJson(Map<String, dynamic> json) {
    return RecoverUnitCommand(
      factionId: json['factionId'] as String,
      unitId: json['unitId'] as String,
    );
  }
}

class FoundColonyCommand implements GameCommand {
  const FoundColonyCommand({
    required this.factionId,
    required this.unitId,
    required this.colonyId,
    required this.name,
  });

  static const String commandType = 'found_colony';

  @override
  final String factionId;
  final String unitId;
  final String colonyId;
  final String name;

  @override
  String get type => commandType;

  @override
  OpenDeadlockGame apply(OpenDeadlockGame game) {
    return game.foundColony(
      unitId,
      colonyId,
      name,
      factionId: factionId,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'factionId': factionId,
      'unitId': unitId,
      'colonyId': colonyId,
      'name': name,
    };
  }

  static FoundColonyCommand fromJson(Map<String, dynamic> json) {
    return FoundColonyCommand(
      factionId: json['factionId'] as String,
      unitId: json['unitId'] as String,
      colonyId: json['colonyId'] as String,
      name: json['name'] as String,
    );
  }
}

class EndTurnCommand implements GameCommand {
  const EndTurnCommand({
    required this.factionId,
  });

  static const String commandType = 'end_turn';

  @override
  final String factionId;

  @override
  String get type => commandType;

  @override
  OpenDeadlockGame apply(OpenDeadlockGame game) {
    if (game.activeFactionId != factionId) {
      throw ArgumentError('Faction $factionId cannot end the active turn.');
    }
    return game.advanceTurn(recordComputerCommands: false);
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'factionId': factionId,
    };
  }

  static EndTurnCommand fromJson(Map<String, dynamic> json) {
    return EndTurnCommand(
      factionId: json['factionId'] as String,
    );
  }
}

class RunComputerTurnCommand implements GameCommand {
  const RunComputerTurnCommand({
    required this.factionId,
  });

  static const String commandType = 'run_computer_turn';

  @override
  final String factionId;

  @override
  String get type => commandType;

  @override
  OpenDeadlockGame apply(OpenDeadlockGame game) {
    if (game.activeFactionId != factionId) {
      throw ArgumentError('Faction $factionId cannot run the active AI turn.');
    }
    if (!game.activeFaction.isComputer) {
      throw ArgumentError(
          '${game.activeFaction.name} is not computer controlled.');
    }
    return game.advanceComputerTurn(recordComputerCommands: false);
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'factionId': factionId,
    };
  }

  static RunComputerTurnCommand fromJson(Map<String, dynamic> json) {
    return RunComputerTurnCommand(
      factionId: json['factionId'] as String,
    );
  }
}

class OpenDeadlockGame {
  const OpenDeadlockGame({
    required this.sessionId,
    required this.turn,
    required this.width,
    required this.height,
    required this.activeFactionId,
    required this.factions,
    required this.tiles,
    required this.colonies,
    required this.units,
    required this.diplomacy,
    required this.commandHistory,
    required this.reports,
    this.victoryCondition = 'any',
    this.scoreTurnLimit = 0,
  });

  final String sessionId;
  final int turn;
  final int width;
  final int height;
  final String activeFactionId;
  final String victoryCondition;
  final int scoreTurnLimit;
  final List<Faction> factions;
  final List<PlanetTile> tiles;
  final List<Colony> colonies;
  final List<Unit> units;
  final List<DiplomacyRelation> diplomacy;
  final List<CommandRecord> commandHistory;
  final List<TurnReport> reports;

  static const List<String> constructionOptions = <String>[
    'Colony Hub',
    'Housing',
    'Apartment Complex',
    'Luxury Housing',
    'Farm Dome',
    'Factory',
    'Research Lab',
    'Scout Patrol',
    'Infantry Company',
    'Armor Company',
    'Militia Post',
    'Barracks',
  ];

  static const Map<String, int> constructionCosts = <String, int>{
    'Colony Hub': 24,
    'Housing': 10,
    'Apartment Complex': 18,
    'Luxury Housing': 28,
    'Farm Dome': 18,
    'Factory': 22,
    'Research Lab': 20,
    'Scout Patrol': 16,
    'Infantry Company': 20,
    'Armor Company': 30,
    'Militia Post': 18,
    'Barracks': 22,
  };

  static const Map<String, int> buildingUpkeepCosts = <String, int>{
    'Colony Hub': 0,
    'Housing': 0,
    'Apartment Complex': 1,
    'Luxury Housing': 2,
    'Farm Dome': 1,
    'Factory': 1,
    'Research Lab': 1,
    'Militia Post': 1,
    'Barracks': 1,
  };

  static const int rushCreditCostPerIndustry = 2;
  static const int basePopulationCapacity = 8;
  static const int housingPopulationCapacityBonus = 4;
  static const int apartmentPopulationCapacityBonus = 4;
  static const int luxuryHousingPopulationCapacityBonus = 4;
  static const Map<String, int> residentialCapacityBonuses = <String, int>{
    'Housing': housingPopulationCapacityBonus,
    'Apartment Complex': apartmentPopulationCapacityBonus,
    'Luxury Housing': luxuryHousingPopulationCapacityBonus,
  };
  static const int colonyWorkRange = 2;
  static const int colonyUnrestMoraleThreshold = 30;
  static const int colonyRiotMoraleThreshold = 15;
  static const int colonyRiotIndustryLoss = 4;
  static const List<String> colonyRiotSuppressionBuildings = <String>[
    'Militia Post',
    'Barracks',
  ];
  static const ResourceStockpile colonyUnrestProductionPenalty =
      ResourceStockpile(
    food: 0,
    industry: -2,
    research: -1,
    credits: -2,
  );
  static const String colonyFocusBalanced = 'balanced';
  static const String colonyFocusGrowth = 'growth';
  static const String colonyFocusIndustry = 'industry';
  static const String colonyFocusResearch = 'research';
  static const String colonyFocusRevenue = 'revenue';
  static const List<String> colonyFocuses = <String>[
    colonyFocusBalanced,
    colonyFocusGrowth,
    colonyFocusIndustry,
    colonyFocusResearch,
    colonyFocusRevenue,
  ];

  static const List<String> researchOptions = <String>[
    'Hydroponics',
    'Industrial Automation',
    'Xenoarchaeology',
    'Defense Grid',
    'Future Studies',
  ];

  static const Map<String, int> researchCosts = <String, int>{
    'Hydroponics': 10,
    'Industrial Automation': 12,
    'Xenoarchaeology': 14,
    'Defense Grid': 16,
    'Future Studies': 10,
  };

  static const int researchCreditCostPerPoint = 3;

  static const String diplomacyStatusWar = 'war';
  static const String diplomacyStatusPeace = 'peace';
  static const String diplomacyStatusAlliance = 'alliance';
  static const List<String> diplomacyStatuses = <String>[
    diplomacyStatusWar,
    diplomacyStatusPeace,
    diplomacyStatusAlliance,
  ];
  static const int treatyTradeCreditPerColony = 2;
  static const int allianceTradeCreditPerColony = 4;
  static const int intelScanCreditCost = 6;
  static const int intelScanRadius = 1;
  static const int sabotageCreditCost = 10;
  static const int sabotageIndustryDamage = 8;
  static const int militiaPostSabotageProtection = 2;
  static const int barracksSabotageProtection = 3;
  static const int defenseGridSabotageProtection = 3;

  static const String victoryTypeConquest = 'conquest';
  static const String victoryTypeScience = 'science';
  static const String victoryTypeScore = 'score';
  static const String victoryConditionAny = 'any';
  static const String victoryConditionConquest = victoryTypeConquest;
  static const String victoryConditionScience = victoryTypeScience;
  static const List<String> victoryConditions = <String>[
    victoryConditionAny,
    victoryConditionConquest,
    victoryConditionScience,
  ];

  static String victoryConditionLabelFor(String victoryCondition) {
    if (victoryCondition == victoryConditionAny) {
      return 'Any Victory';
    }
    if (victoryCondition == victoryConditionConquest) {
      return 'Conquest';
    }
    if (victoryCondition == victoryConditionScience) {
      return 'Science';
    }
    return victoryCondition;
  }

  static String diplomacyStatusLabelFor(String status) {
    if (status == diplomacyStatusWar) {
      return 'War';
    }
    if (status == diplomacyStatusPeace) {
      return 'Peace';
    }
    if (status == diplomacyStatusAlliance) {
      return 'Alliance';
    }
    return status;
  }

  static String _diplomacyStatusPhraseFor(String status) {
    if (status == diplomacyStatusWar) {
      return 'at war';
    }
    if (status == diplomacyStatusPeace) {
      return 'at peace';
    }
    if (status == diplomacyStatusAlliance) {
      return 'allied';
    }
    return status;
  }

  static const int unitRecoveryAmount = 1;
  static const int colonyVisionRadius = 1;
  static const Map<String, int> unitVisionRadii = <String, int>{
    'scout': 2,
    'infantry': 1,
    'armor': 1,
  };

  static int visionRadiusForUnit(String unitType) {
    return unitVisionRadii[unitType] ?? 1;
  }

  static const Map<String, FactionTrait> factionTraitCatalog =
      <String, FactionTrait>{
    'agrarian': FactionTrait(
      id: 'agrarian',
      name: 'Agrarian',
      description: '+1 food from every colony. Prefers Farm Dome projects.',
      foodBonus: 1,
      preferredConstruction: 'Farm Dome',
      preferredResearch: 'Hydroponics',
    ),
    'industrialists': FactionTrait(
      id: 'industrialists',
      name: 'Industrialists',
      description: '+1 industry from every colony. Prefers Factory projects.',
      industryBonus: 1,
      preferredConstruction: 'Factory',
      preferredResearch: 'Industrial Automation',
    ),
    'scholars': FactionTrait(
      id: 'scholars',
      name: 'Scholars',
      description:
          '+1 research from every colony. Prefers Research Lab projects.',
      researchBonus: 1,
      preferredConstruction: 'Research Lab',
      preferredResearch: 'Xenoarchaeology',
    ),
    'traders': FactionTrait(
      id: 'traders',
      name: 'Traders',
      description: '+2 credits from every colony.',
      creditBonus: 2,
      preferredResearch: 'Future Studies',
    ),
    'militarists': FactionTrait(
      id: 'militarists',
      name: 'Militarists',
      description: 'Prefers defensive infrastructure before civilian projects.',
      preferredConstruction: 'Militia Post',
      preferredResearch: 'Defense Grid',
    ),
  };

  static const Map<String, RaceProfile> raceCatalog = <String, RaceProfile>{
    'human': RaceProfile(
      id: 'human',
      name: 'Human',
      description: 'Flexible colonists with strong budget reserves.',
      creditBonus: 2,
    ),
    'chcht': RaceProfile(
      id: 'chcht',
      name: "ChCh't",
      description: 'Fast-growing builders that expand colonies quickly.',
      foodBonus: 1,
      industryBonus: 1,
      constructionBonus: 2,
      populationGrowthBonus: 1,
      preferredConstruction: 'Factory',
      preferredResearch: 'Industrial Automation',
    ),
    'cyth': RaceProfile(
      id: 'cyth',
      name: 'Cyth',
      description: 'Disciplined colonies with stable morale and research.',
      researchBonus: 1,
      moraleFloor: 80,
      preferredConstruction: 'Research Lab',
      preferredResearch: 'Xenoarchaeology',
    ),
    'maug': RaceProfile(
      id: 'maug',
      name: 'Maug',
      description: 'Technical specialists that accelerate research.',
      researchBonus: 2,
      constructionBonus: 1,
      preferredConstruction: 'Research Lab',
      preferredResearch: 'Industrial Automation',
    ),
    'relu': RaceProfile(
      id: 'relu',
      name: "Re'Lu",
      description: 'Secretive scouts with broad planetary awareness.',
      researchBonus: 1,
      revealsMap: true,
      preferredConstruction: 'Scout Patrol',
      preferredResearch: 'Xenoarchaeology',
    ),
    'tarth': RaceProfile(
      id: 'tarth',
      name: 'Tarth',
      description: 'Aggressive militarists with stronger ground attacks.',
      foodBonus: 1,
      attackBonus: 1,
      preferredConstruction: 'Barracks',
      preferredResearch: 'Defense Grid',
    ),
    'uva_mosk': RaceProfile(
      id: 'uva_mosk',
      name: 'Uva Mosk',
      description: 'Efficient extractors with broad economic output.',
      industryBonus: 1,
      creditBonus: 1,
      preferredConstruction: 'Factory',
      preferredResearch: 'Industrial Automation',
    ),
  };

  static List<RaceProfile> raceProfiles() {
    return raceCatalog.values.toList(growable: false);
  }

  static RaceProfile raceProfileForId(String raceId) {
    return raceCatalog[raceId] ?? raceCatalog['human']!;
  }

  static RaceProfile raceProfileFor(Faction faction) {
    return raceProfileForId(faction.raceId);
  }

  static String raceLabelFor(String raceId) {
    return raceProfileForId(raceId).name;
  }

  static List<FactionTrait> traitsFor(Faction faction) {
    final traits = <FactionTrait>[];
    for (final traitId in faction.traitIds) {
      final trait = factionTraitCatalog[traitId];
      if (trait != null) {
        traits.add(trait);
      }
    }
    return traits;
  }

  static String traitSummaryFor(Faction faction) {
    final traits = traitsFor(faction);
    if (traits.isEmpty) {
      return 'None';
    }
    return traits.map((trait) => trait.name).join(', ');
  }

  static int buildCostFor(String construction) {
    final cost = constructionCosts[construction];
    if (cost == null) {
      throw ArgumentError('Unknown construction option: $construction.');
    }
    return cost;
  }

  static int constructionUpkeepFor(String construction) {
    buildCostFor(construction);
    return buildingUpkeepCosts[construction] ?? 0;
  }

  static String constructionProducesDescriptionFor(String construction) {
    buildCostFor(construction);
    final residentialBonus = residentialCapacityBonuses[construction];
    if (residentialBonus != null) {
      return '+$residentialBonus population capacity';
    }
    if (construction == 'Colony Hub') {
      return '+2 credits from the colony';
    }
    if (construction == 'Farm Dome') {
      return '+3 food from the colony';
    }
    if (construction == 'Factory') {
      return '+3 industry from the colony';
    }
    if (construction == 'Research Lab') {
      return '+4 research from the colony';
    }
    if (construction == 'Militia Post') {
      return '+2 colony defense and +2 sabotage protection';
    }
    if (construction == 'Barracks') {
      return '+3 colony defense, +3 sabotage protection, and infantry training';
    }
    if (construction == 'Scout Patrol') {
      return 'Scout unit';
    }
    if (construction == 'Infantry Company') {
      return 'Infantry unit';
    }
    if (construction == 'Armor Company') {
      return 'Armor unit';
    }
    return 'No direct output';
  }

  static String constructionRequirementFor(String construction) {
    buildCostFor(construction);
    if (construction == 'Apartment Complex') {
      return 'Housing';
    }
    if (construction == 'Luxury Housing') {
      return 'Apartment Complex';
    }
    if (construction == 'Infantry Company') {
      return 'Barracks';
    }
    if (construction == 'Armor Company') {
      return 'Barracks and Factory';
    }
    return 'None';
  }

  static String constructionSummaryFor(String construction) {
    final cost = buildCostFor(construction);
    final upkeep = constructionUpkeepFor(construction);
    final produces = constructionProducesDescriptionFor(construction);
    final requirement = constructionRequirementFor(construction);
    return 'Cost $cost industry / Upkeep ${_creditLabel(upkeep)} / '
        'Produces $produces / Requires $requirement';
  }

  static int rushConstructionCostFor(int industry) {
    if (industry <= 0) {
      throw ArgumentError('Rush industry must be positive.');
    }
    return industry * rushCreditCostPerIndustry;
  }

  static int assignedSectorCapacityFor(Colony colony) {
    return _clampInt(colony.population - 1, 0, 6);
  }

  static int workSectorCapacityFor(Colony colony) {
    return 1 + assignedSectorCapacityFor(colony);
  }

  static int populationCapacityFor(Colony colony) {
    var capacity = basePopulationCapacity;
    for (final entry in residentialCapacityBonuses.entries) {
      if (colony.completedBuildings.contains(entry.key)) {
        capacity += entry.value;
      }
    }
    return capacity;
  }

  static int buildingUpkeepFor(Colony colony) {
    var upkeep = 0;
    for (final building in colony.completedBuildings) {
      upkeep += buildingUpkeepCosts[building] ?? 0;
    }
    return upkeep;
  }

  static bool isColonyInUnrest(Colony colony) {
    return colony.morale < colonyUnrestMoraleThreshold;
  }

  static bool isColonyInCriticalUnrest(Colony colony) {
    return colony.morale < colonyRiotMoraleThreshold;
  }

  static bool isColonyRiotSuppressed(Colony colony) {
    if (!isColonyInCriticalUnrest(colony)) {
      return false;
    }
    for (final building in colonyRiotSuppressionBuildings) {
      if (colony.completedBuildings.contains(building)) {
        return true;
      }
    }
    return false;
  }

  static bool isColonyRioting(Colony colony) {
    return isColonyInCriticalUnrest(colony) && !isColonyRiotSuppressed(colony);
  }

  static int colonyRiotIndustryLossFor(Colony colony) {
    return isColonyRioting(colony) ? colonyRiotIndustryLoss : 0;
  }

  static String colonyStabilityLabelFor(Colony colony) {
    if (isColonyRioting(colony)) {
      return 'Riot';
    }
    if (isColonyRiotSuppressed(colony)) {
      return 'Suppressed';
    }
    return isColonyInUnrest(colony) ? 'Unrest' : 'Stable';
  }

  static String colonyStabilityDescriptionFor(Colony colony) {
    if (isColonyRioting(colony)) {
      return '-2 industry, -1 research, -2 credits. '
          'Riots destroy $colonyRiotIndustryLoss stored industry.';
    }
    if (isColonyRiotSuppressed(colony)) {
      return '-2 industry, -1 research, -2 credits. '
          'Security buildings prevent riot damage.';
    }
    if (isColonyInUnrest(colony)) {
      return '-2 industry, -1 research, -2 credits.';
    }
    return 'No morale penalties.';
  }

  static bool isKnownColonyFocus(String focus) {
    return colonyFocuses.contains(focus);
  }

  static String colonyFocusLabelFor(String focus) {
    if (focus == colonyFocusBalanced) {
      return 'Balanced';
    }
    if (focus == colonyFocusGrowth) {
      return 'Growth';
    }
    if (focus == colonyFocusIndustry) {
      return 'Industry';
    }
    if (focus == colonyFocusResearch) {
      return 'Research';
    }
    if (focus == colonyFocusRevenue) {
      return 'Revenue';
    }
    return focus;
  }

  static String colonyFocusDescriptionFor(String focus) {
    if (focus == colonyFocusBalanced) {
      return 'No production bias.';
    }
    if (focus == colonyFocusGrowth) {
      return '+2 food, -1 industry.';
    }
    if (focus == colonyFocusIndustry) {
      return '+2 industry, -1 food.';
    }
    if (focus == colonyFocusResearch) {
      return '+2 research, -1 industry.';
    }
    if (focus == colonyFocusRevenue) {
      return '+3 credits, -1 research.';
    }
    return 'Unknown focus.';
  }

  static bool isRepeatableConstruction(String construction) {
    return construction == 'Scout Patrol' ||
        construction == 'Infantry Company' ||
        construction == 'Armor Company';
  }

  static bool isCompletedConstruction(Colony colony, String construction) {
    return !isRepeatableConstruction(construction) &&
        colony.completedBuildings.contains(construction);
  }

  static bool isConstructionAvailableFor(Colony colony, String construction) {
    if (construction == 'Apartment Complex') {
      return colony.completedBuildings.contains('Housing');
    }
    if (construction == 'Luxury Housing') {
      return colony.completedBuildings.contains('Apartment Complex');
    }
    if (construction == 'Infantry Company') {
      return colony.completedBuildings.contains('Barracks');
    }
    if (construction == 'Armor Company') {
      return colony.completedBuildings.contains('Barracks') &&
          colony.completedBuildings.contains('Factory');
    }
    return true;
  }

  static String unitTypeForConstruction(String construction) {
    if (construction == 'Scout Patrol') {
      return 'scout';
    }
    if (construction == 'Infantry Company') {
      return 'infantry';
    }
    if (construction == 'Armor Company') {
      return 'armor';
    }
    throw ArgumentError('$construction does not produce units.');
  }

  static String _constructionRequirementFor(String construction) {
    final requirement = constructionRequirementFor(construction);
    return requirement == 'None' ? 'the required infrastructure' : requirement;
  }

  static int researchCostFor(String researchProject) {
    final cost = researchCosts[researchProject];
    if (cost == null) {
      throw ArgumentError('Unknown research project: $researchProject.');
    }
    return cost;
  }

  static int fundResearchCostFor(int research) {
    if (research <= 0) {
      throw ArgumentError('Funded research must be positive.');
    }
    return research * researchCreditCostPerPoint;
  }

  static bool isRepeatableResearch(String researchProject) {
    return researchProject == 'Future Studies';
  }

  static List<String> get coreResearchOptions {
    return researchOptions
        .where((researchProject) => !isRepeatableResearch(researchProject))
        .toList(growable: false);
  }

  static bool isCompletedResearch(Faction faction, String researchProject) {
    return !isRepeatableResearch(researchProject) &&
        faction.completedResearch.contains(researchProject);
  }

  static int coreResearchCompletedFor(Faction faction) {
    var completed = 0;
    for (final researchProject in coreResearchOptions) {
      if (isCompletedResearch(faction, researchProject)) {
        completed += 1;
      }
    }
    return completed;
  }

  static bool hasScienceVictory(Faction faction) {
    return coreResearchCompletedFor(faction) == coreResearchOptions.length;
  }

  static String researchDescriptionFor(String researchProject) {
    if (researchProject == 'Hydroponics') {
      return '+1 food from every colony.';
    }
    if (researchProject == 'Industrial Automation') {
      return '+1 industry from every colony.';
    }
    if (researchProject == 'Xenoarchaeology') {
      return '+1 research from every colony.';
    }
    if (researchProject == 'Defense Grid') {
      return '+2 defense and +3 sabotage protection for controlled colonies.';
    }
    if (researchProject == 'Future Studies') {
      return 'Converts research into credits after the core tree is complete.';
    }
    throw ArgumentError('Unknown research project: $researchProject.');
  }

  static int maxHealthFor(String unitType) {
    return _maxHealthForUnitType(unitType);
  }

  static int attackFor(String unitType) {
    return _attackForUnitType(unitType);
  }

  static int defenseFor(String unitType) {
    return _defenseForUnitType(unitType);
  }

  static int maxMovesFor(String unitType) {
    return _maxMovesForUnitType(unitType);
  }

  static bool isTerrainPassable(String terrain) {
    return terrain != 'water';
  }

  static int movementCostForTerrain(String terrain) {
    if (terrain == 'water') {
      throw ArgumentError('Water sectors are not passable.');
    }
    return _movementCostForTerrain(terrain);
  }

  static int colonyDefenseFor(Colony colony) {
    return _colonyDefenseFor(colony);
  }

  int colonyDefenseForColony(Colony colony) {
    final baseDefense = _colonyDefenseFor(colony);
    return _hasResearch(colony.ownerId, 'Defense Grid')
        ? baseDefense + 2
        : baseDefense;
  }

  int sabotageProtectionForColony(Colony colony) {
    var protection = 0;
    if (colony.completedBuildings.contains('Militia Post')) {
      protection += militiaPostSabotageProtection;
    }
    if (colony.completedBuildings.contains('Barracks')) {
      protection += barracksSabotageProtection;
    }
    if (_hasResearch(colony.ownerId, 'Defense Grid')) {
      protection += defenseGridSabotageProtection;
    }
    return protection;
  }

  int sabotageDamageForColony(Colony colony) {
    return _sabotageDamageFor(colony);
  }

  ColonyProduction colonyProductionFor(Colony colony) {
    return _colonyProductionFor(colony, tileAt(colony.x, colony.y));
  }

  UnitCombatPreview previewUnitCombat(Unit attacker, Unit defender) {
    final attackDamage = _combatDamage(attacker, defender);
    final defenderHealth = defender.health - attackDamage;
    var attackerHealth = attacker.health;
    var counterDamage = 0;
    if (defenderHealth > 0) {
      counterDamage = _combatDamage(defender, attacker);
      attackerHealth -= counterDamage;
    }

    return UnitCombatPreview(
      attacker: attacker,
      defender: defender,
      attackDamage: attackDamage,
      counterDamage: counterDamage,
      attackerHealth: _clampInt(attackerHealth, 0, attacker.health),
      defenderHealth: _clampInt(defenderHealth, 0, defender.health),
      attackerSurvives: attackerHealth > 0,
      defenderSurvives: defenderHealth > 0,
    );
  }

  ColonyAssaultPreview previewColonyAssault(Unit attacker, Colony colony) {
    final attackPower = _unitAttackFor(attacker) + (attacker.health ~/ 2);
    final defensePower = colonyDefenseForColony(colony);
    final captured = attackPower > defensePower;
    final counterDamage = captured
        ? _clampInt(defensePower - _unitAttackFor(attacker), 1, 3)
        : _clampInt(defensePower - defenseFor(attacker.type), 1, 4);
    final attackerHealth = attacker.health - counterDamage;
    final attackerSurvived = attackerHealth > 0;
    final colonyCaptured = captured && attackerSurvived;
    final moraleLoss = _clampInt(attackPower * 8, 10, 35);
    final populationLoss = captured || attackPower >= defensePower ? 1 : 0;
    final updatedPopulation =
        _clampInt(colony.population - populationLoss, 1, 99);
    final updatedMorale =
        colonyCaptured ? 45 : _clampInt(colony.morale - moraleLoss, 0, 100);

    return ColonyAssaultPreview(
      attacker: attacker,
      colony: colony,
      attackPower: attackPower,
      defensePower: defensePower,
      counterDamage: counterDamage,
      attackerHealth: _clampInt(attackerHealth, 0, attacker.health),
      attackerSurvives: attackerSurvived,
      colonyCaptured: colonyCaptured,
      population: updatedPopulation,
      morale: _moraleForFaction(
        colonyCaptured ? attacker.ownerId : colony.ownerId,
        updatedMorale,
      ),
    );
  }

  List<PlanetTile> workedTilesFor(Colony colony) {
    return _workedTilesFor(colony, homeTile: tileAt(colony.x, colony.y));
  }

  Colony? assignedColonyForSector(int x, int y) {
    for (final colony in colonies) {
      for (final assignment in colony.assignedSectors) {
        if (assignment.matches(x, y)) {
          return colony;
        }
      }
    }
    return null;
  }

  bool isSectorAssignedToColony(Colony colony, int x, int y) {
    for (final assignment in colony.assignedSectors) {
      if (assignment.matches(x, y)) {
        return true;
      }
    }
    return false;
  }

  bool canAssignColonySector(
    String colonyId,
    int x,
    int y, {
    String? factionId,
  }) {
    try {
      final colony = colonyById(colonyId);
      _validateColonySectorAssignment(
        colony,
        x,
        y,
        factionId: factionId,
      );
      return true;
    } on ArgumentError {
      return false;
    } on StateError {
      return false;
    }
  }

  Colony? preferredColonyForSector(String factionId, int x, int y) {
    if (assignedColonyForSector(x, y) != null) {
      return null;
    }
    final candidates = <Colony>[];
    for (final colony in colonies) {
      if (colony.ownerId != factionId ||
          !canAssignColonySector(
            colony.id,
            x,
            y,
            factionId: factionId,
          )) {
        continue;
      }
      candidates.add(colony);
    }
    if (candidates.isEmpty) {
      return null;
    }
    candidates.sort((a, b) {
      final distanceComparison = _manhattanDistance(a.x, a.y, x, y)
          .compareTo(_manhattanDistance(b.x, b.y, x, y));
      if (distanceComparison != 0) {
        return distanceComparison;
      }
      return a.name.compareTo(b.name);
    });
    return candidates.first;
  }

  List<PlanetTile> preferredAssignableSectorsFor(
    Colony colony, {
    int? limit,
  }) {
    final openSlots =
        assignedSectorCapacityFor(colony) - colony.assignedSectors.length;
    if (openSlots <= 0) {
      return const <PlanetTile>[];
    }

    var resultLimit = limit == null || limit > openSlots ? openSlots : limit;
    if (resultLimit <= 0) {
      return const <PlanetTile>[];
    }

    final candidates = <PlanetTile>[];
    for (final tile in tiles) {
      if (isSectorAssignedToColony(colony, tile.x, tile.y)) {
        continue;
      }
      if (!canAssignColonySector(
        colony.id,
        tile.x,
        tile.y,
        factionId: colony.ownerId,
      )) {
        continue;
      }
      candidates.add(tile);
    }
    if (candidates.isEmpty) {
      return const <PlanetTile>[];
    }

    candidates.sort((a, b) {
      final scoreComparison = _sectorWorkScoreFor(colony, b)
          .compareTo(_sectorWorkScoreFor(colony, a));
      if (scoreComparison != 0) {
        return scoreComparison;
      }
      final distanceComparison =
          _manhattanDistance(colony.x, colony.y, a.x, a.y)
              .compareTo(_manhattanDistance(colony.x, colony.y, b.x, b.y));
      if (distanceComparison != 0) {
        return distanceComparison;
      }
      final yComparison = a.y.compareTo(b.y);
      return yComparison == 0 ? a.x.compareTo(b.x) : yComparison;
    });
    if (resultLimit > candidates.length) {
      resultLimit = candidates.length;
    }
    return candidates.take(resultLimit).toList();
  }

  List<FactionWorldSummary> worldSummaries() {
    return factions
        .map((faction) => worldSummaryFor(faction.id))
        .toList(growable: false);
  }

  List<FactionScore> factionScores() {
    final scores = factions
        .map((faction) => factionScoreFor(faction.id))
        .toList(growable: false);
    scores.sort((a, b) {
      if (a.isDefeated != b.isDefeated) {
        return a.isDefeated ? 1 : -1;
      }
      final totalComparison = b.total.compareTo(a.total);
      if (totalComparison != 0) {
        return totalComparison;
      }
      return a.factionName.compareTo(b.factionName);
    });
    return scores;
  }

  FactionScore factionScoreFor(String factionId) {
    final faction = factionById(factionId);
    if (faction == null) {
      throw ArgumentError('Unknown faction: $factionId.');
    }

    final summary = worldSummaryFor(factionId);
    return FactionScore(
      factionId: faction.id,
      factionName: faction.name,
      colorValue: faction.colorValue,
      controlMode: faction.controlMode,
      raceName: summary.raceName,
      isDefeated: summary.isDefeated,
      colonyScore: summary.colonyCount * 50,
      sectorScore: summary.controlledSectors * 2,
      populationScore: summary.totalPopulation * 5,
      militaryScore: militaryStrengthFor(factionId) * 3,
      scienceScore: summary.coreResearchCompleted * 30,
      reserveScore: faction.resources.credits ~/ 4,
    );
  }

  FactionWorldSummary worldSummaryFor(String factionId) {
    final faction = factionById(factionId);
    if (faction == null) {
      throw ArgumentError('Unknown faction: $factionId.');
    }

    var colonyCount = 0;
    var unitCount = 0;
    var controlledSectors = 0;
    var exploredSectors = 0;
    var totalPopulation = 0;
    var visibleEnemyColonies = 0;
    var projectedProduction = const ResourceStockpile(
      food: 0,
      industry: 0,
      research: 0,
      credits: 0,
    );

    for (final tile in tiles) {
      if (tile.ownerId == factionId) {
        controlledSectors += 1;
      }
      if (tile.isExploredBy(factionId)) {
        exploredSectors += 1;
        final tileColonyId = tile.colonyId;
        if (tileColonyId != null) {
          final colony = colonyById(tileColonyId);
          if (colony.ownerId != factionId) {
            visibleEnemyColonies += 1;
          }
        }
      }
    }

    for (final colony in colonies) {
      if (colony.ownerId != factionId) {
        continue;
      }
      colonyCount += 1;
      totalPopulation += colony.population;
      projectedProduction =
          projectedProduction + colonyProductionFor(colony).output;
    }

    for (final unit in units) {
      if (unit.ownerId == factionId) {
        unitCount += 1;
      }
    }
    projectedProduction = projectedProduction + tradeIncomeFor(factionId);

    var atWarCount = 0;
    for (final otherFaction in factions) {
      if (otherFaction.id != factionId &&
          areAtWar(factionId, otherFaction.id)) {
        atWarCount += 1;
      }
    }

    return FactionWorldSummary(
      factionId: faction.id,
      factionName: faction.name,
      colorValue: faction.colorValue,
      controlMode: faction.controlMode,
      raceName: raceProfileFor(faction).name,
      colonyCount: colonyCount,
      totalColonyCount: colonies.length,
      unitCount: unitCount,
      controlledSectors: controlledSectors,
      exploredSectors: exploredSectors,
      totalPopulation: totalPopulation,
      projectedProduction: projectedProduction,
      atWarCount: atWarCount,
      visibleEnemyColonies: visibleEnemyColonies,
      coreResearchCompleted: coreResearchCompletedFor(faction),
      coreResearchTotal: coreResearchOptions.length,
      isDefeated: colonyCount == 0 && unitCount == 0,
    );
  }

  Faction get activeFaction {
    return factions.firstWhere((faction) => faction.id == activeFactionId);
  }

  bool get activeFactionCanIssueLocalOrders {
    return !isGameOver &&
        activeFaction.isLocal &&
        _factionCanTakeTurn(activeFactionId);
  }

  bool factionHasPresence(String factionId) {
    if (factionById(factionId) == null) {
      throw ArgumentError('Unknown faction: $factionId.');
    }
    for (final colony in colonies) {
      if (colony.ownerId == factionId) {
        return true;
      }
    }
    for (final unit in units) {
      if (unit.ownerId == factionId) {
        return true;
      }
    }
    return false;
  }

  bool isFactionDefeated(String factionId) {
    return !factionHasPresence(factionId);
  }

  Set<String> _defeatedFactionIds() {
    final defeatedFactionIds = <String>{};
    for (final faction in factions) {
      if (!factionHasPresence(faction.id)) {
        defeatedFactionIds.add(faction.id);
      }
    }
    return defeatedFactionIds;
  }

  String? get conquestVictoryFactionId {
    if (colonies.isEmpty) {
      return null;
    }
    final ownerIds = <String>{};
    for (final colony in colonies) {
      ownerIds.add(colony.ownerId);
    }
    return ownerIds.length == 1 ? ownerIds.first : null;
  }

  String? get scienceVictoryFactionId {
    for (final faction in factions) {
      if (hasScienceVictory(faction)) {
        return faction.id;
      }
    }
    return null;
  }

  String? get scoreVictoryFactionId {
    if (scoreTurnLimit <= 0 || turn < scoreTurnLimit) {
      return null;
    }

    for (final score in factionScores()) {
      if (!score.isDefeated) {
        return score.factionId;
      }
    }
    return null;
  }

  String? get winningVictoryType {
    if (_allowsConquestVictory && conquestVictoryFactionId != null) {
      return victoryTypeConquest;
    }
    if (_allowsScienceVictory && scienceVictoryFactionId != null) {
      return victoryTypeScience;
    }
    if (scoreVictoryFactionId != null) {
      return victoryTypeScore;
    }
    return null;
  }

  bool get _allowsConquestVictory {
    return victoryCondition == victoryConditionAny ||
        victoryCondition == victoryConditionConquest;
  }

  bool get _allowsScienceVictory {
    return victoryCondition == victoryConditionAny ||
        victoryCondition == victoryConditionScience;
  }

  String? get winningFactionId {
    final victoryType = winningVictoryType;
    if (victoryType == victoryTypeConquest) {
      return conquestVictoryFactionId;
    }
    if (victoryType == victoryTypeScience) {
      return scienceVictoryFactionId;
    }
    if (victoryType == victoryTypeScore) {
      return scoreVictoryFactionId;
    }
    return null;
  }

  Faction? get winningFaction {
    return factionById(winningFactionId);
  }

  bool get isGameOver {
    return winningFactionId != null;
  }

  String get winningVictoryMessage {
    final winnerName = winningFaction?.name ?? 'A faction';
    final victoryType = winningVictoryType;
    if (victoryType == victoryTypeScience) {
      return '$winnerName completed every core research project.';
    }
    if (victoryType == victoryTypeConquest) {
      return '$winnerName controls every colony on the planet.';
    }
    if (victoryType == victoryTypeScore) {
      return '$winnerName has the highest score at turn $scoreTurnLimit.';
    }
    return 'No faction has won yet.';
  }

  OpenDeadlockGame _withVictoryReportIfNeeded(String? previousWinnerId) {
    final winnerId = winningFactionId;
    if (winnerId == null || winnerId == previousWinnerId) {
      return this;
    }

    final winner = factionById(winnerId);
    final winnerName = winner == null ? winnerId : winner.name;
    final victoryTitle = '$winnerName wins';
    final hasVictoryReport =
        reports.any((report) => report.title == victoryTitle);
    if (hasVictoryReport) {
      return this;
    }

    return copyWith(
      reports: <TurnReport>[
        TurnReport(
          title: victoryTitle,
          message: winningVictoryMessage,
        ),
        ...reports,
      ],
    );
  }

  OpenDeadlockGame _withDefeatReportsIfNeeded(
    Set<String> previouslyDefeatedFactionIds,
    int previousReportCount,
  ) {
    final defeatReports = <TurnReport>[];
    for (final faction in factions) {
      if (previouslyDefeatedFactionIds.contains(faction.id) ||
          factionHasPresence(faction.id)) {
        continue;
      }
      defeatReports.add(
        TurnReport(
          title: '${faction.name} defeated',
          message: '${faction.name} has no colonies or units remaining.',
        ),
      );
    }
    if (defeatReports.isEmpty) {
      return this;
    }

    var newReportCount = reports.length - previousReportCount;
    if (newReportCount < 0) {
      newReportCount = 0;
    }
    if (newReportCount > reports.length) {
      newReportCount = reports.length;
    }

    return copyWith(
      reports: <TurnReport>[
        ...reports.take(newReportCount),
        ...defeatReports,
        ...reports.skip(newReportCount),
      ],
    );
  }

  PlanetTile tileAt(int x, int y) {
    return tiles.firstWhere((tile) => tile.x == x && tile.y == y);
  }

  Colony? colonyAt(int x, int y) {
    for (final colony in colonies) {
      if (colony.x == x && colony.y == y) {
        return colony;
      }
    }
    return null;
  }

  Colony colonyById(String id) {
    return colonies.firstWhere((colony) => colony.id == id);
  }

  Unit? unitAt(int x, int y) {
    for (final unit in units) {
      if (unit.x == x && unit.y == y) {
        return unit;
      }
    }
    return null;
  }

  Unit? visibleUnitAt(String factionId, int x, int y) {
    for (final unit in units) {
      if (unit.x == x && unit.y == y && isUnitVisibleTo(factionId, unit)) {
        return unit;
      }
    }
    return null;
  }

  Unit unitById(String id) {
    return units.firstWhere((unit) => unit.id == id);
  }

  bool hasColonyId(String id) {
    for (final colony in colonies) {
      if (colony.id == id) {
        return true;
      }
    }
    return false;
  }

  Faction? factionById(String? id) {
    if (id == null) {
      return null;
    }
    for (final faction in factions) {
      if (faction.id == id) {
        return faction;
      }
    }
    return null;
  }

  OpenDeadlockGame localPerspectiveFor(String factionId) {
    final invitedFaction = factionById(factionId);
    if (invitedFaction == null) {
      throw ArgumentError('Unknown faction: $factionId.');
    }

    return copyWith(
      factions: factions.map((faction) {
        if (faction.id == factionId) {
          return faction.copyWith(controlMode: Faction.controlLocal);
        }
        if (faction.isComputer) {
          return faction;
        }
        return faction.copyWith(controlMode: Faction.controlRemote);
      }).toList(),
    );
  }

  DiplomacyRelation? diplomacyBetween(
      String factionId, String targetFactionId) {
    for (final relation in diplomacy) {
      if (relation.matches(factionId, targetFactionId)) {
        return relation;
      }
    }
    return null;
  }

  String diplomacyStatusBetween(String factionId, String targetFactionId) {
    if (factionId == targetFactionId) {
      return diplomacyStatusPeace;
    }
    return diplomacyBetween(factionId, targetFactionId)?.status ??
        diplomacyStatusWar;
  }

  bool areAtWar(String factionId, String targetFactionId) {
    return factionId != targetFactionId &&
        diplomacyStatusBetween(factionId, targetFactionId) ==
            diplomacyStatusWar;
  }

  bool areAllied(String factionId, String targetFactionId) {
    return factionId != targetFactionId &&
        diplomacyStatusBetween(factionId, targetFactionId) ==
            diplomacyStatusAlliance;
  }

  bool canFactionTraverseSector(String factionId, PlanetTile tile) {
    final ownerId = tile.ownerId;
    if (ownerId == null || ownerId == factionId) {
      return true;
    }
    return !areAtWar(factionId, ownerId);
  }

  bool isSectorVisibleTo(String factionId, int x, int y) {
    if (factionById(factionId) == null) {
      throw ArgumentError('Unknown faction: $factionId.');
    }
    if (!_isInsideMap(x, y)) {
      throw ArgumentError('Target is outside the map: $x, $y.');
    }
    return _isSectorVisibleTo(factionId, x, y, <String>{});
  }

  bool isUnitVisibleTo(String factionId, Unit unit) {
    if (factionById(factionId) == null) {
      throw ArgumentError('Unknown faction: $factionId.');
    }
    if (unit.ownerId == factionId) {
      return true;
    }
    return isSectorVisibleTo(factionId, unit.x, unit.y);
  }

  List<Unit> visibleUnitsFor(String factionId) {
    if (factionById(factionId) == null) {
      throw ArgumentError('Unknown faction: $factionId.');
    }
    return units
        .where((unit) => isUnitVisibleTo(factionId, unit))
        .toList(growable: false);
  }

  int visibleEnemyUnitCountFor(String factionId) {
    if (factionById(factionId) == null) {
      throw ArgumentError('Unknown faction: $factionId.');
    }
    var count = 0;
    for (final unit in units) {
      if (areAtWar(factionId, unit.ownerId) &&
          isUnitVisibleTo(factionId, unit)) {
        count += 1;
      }
    }
    return count;
  }

  int allianceSharedSectorCountFor(String factionId, String targetFactionId) {
    if (factionById(factionId) == null) {
      throw ArgumentError('Unknown faction: $factionId.');
    }
    if (factionById(targetFactionId) == null) {
      throw ArgumentError('Unknown faction: $targetFactionId.');
    }
    if (factionId == targetFactionId ||
        diplomacyStatusBetween(factionId, targetFactionId) !=
            diplomacyStatusAlliance) {
      return 0;
    }

    var sharedSectorCount = 0;
    for (final tile in tiles) {
      if (tile.isExploredBy(factionId) && tile.isExploredBy(targetFactionId)) {
        sharedSectorCount += 1;
      }
    }
    return sharedSectorCount;
  }

  ResourceStockpile tradeIncomeFor(String factionId) {
    if (factionById(factionId) == null) {
      throw ArgumentError('Unknown faction: $factionId.');
    }
    var credits = 0;
    for (final otherFaction in factions) {
      if (otherFaction.id == factionId) {
        continue;
      }
      credits += treatyTradeCreditsFor(factionId, otherFaction.id);
    }
    return ResourceStockpile(
      food: 0,
      industry: 0,
      research: 0,
      credits: credits,
    );
  }

  int treatyTradeCreditsFor(String factionId, String targetFactionId) {
    if (factionById(factionId) == null) {
      throw ArgumentError('Unknown faction: $factionId.');
    }
    if (factionById(targetFactionId) == null) {
      throw ArgumentError('Unknown faction: $targetFactionId.');
    }
    if (factionId == targetFactionId) {
      return 0;
    }
    final status = diplomacyStatusBetween(factionId, targetFactionId);
    final creditsPerColony = tradeCreditsPerColonyForStatus(status);
    if (creditsPerColony <= 0) {
      return 0;
    }
    return _ownedColonyCount(factionId) * creditsPerColony;
  }

  int tradeCreditsPerColonyForStatus(String status) {
    if (status == diplomacyStatusPeace) {
      return treatyTradeCreditPerColony;
    }
    if (status == diplomacyStatusAlliance) {
      return allianceTradeCreditPerColony;
    }
    return 0;
  }

  int peaceTreatyCountFor(String factionId) {
    if (factionById(factionId) == null) {
      throw ArgumentError('Unknown faction: $factionId.');
    }
    var treatyCount = 0;
    for (final otherFaction in factions) {
      if (otherFaction.id != factionId &&
          diplomacyStatusBetween(factionId, otherFaction.id) ==
              diplomacyStatusPeace) {
        treatyCount += 1;
      }
    }
    return treatyCount;
  }

  int intelScanRevealableSectorCountFor(
      String factionId, String targetFactionId) {
    return _intelScanTargetFor(factionId, targetFactionId)?.tiles.length ?? 0;
  }

  FactionSabotageTarget? sabotageTargetFor(
    String factionId,
    String targetFactionId,
  ) {
    final faction = factionById(factionId);
    if (faction == null) {
      throw ArgumentError('Unknown faction: $factionId.');
    }
    final targetFaction = factionById(targetFactionId);
    if (targetFaction == null) {
      throw ArgumentError('Unknown faction: $targetFactionId.');
    }
    if (factionId == targetFactionId) {
      throw ArgumentError('A faction cannot sabotage itself.');
    }

    final candidates = colonies.where((colony) {
      return colony.ownerId == targetFactionId &&
          colony.storedIndustry > 0 &&
          _sabotageDamageFor(colony) > 0 &&
          tileAt(colony.x, colony.y).isExploredBy(factionId);
    }).toList();
    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((a, b) {
      final damageComparison =
          _sabotageDamageFor(b).compareTo(_sabotageDamageFor(a));
      if (damageComparison != 0) {
        return damageComparison;
      }
      final storedComparison = b.storedIndustry.compareTo(a.storedIndustry);
      if (storedComparison != 0) {
        return storedComparison;
      }
      return a.name.compareTo(b.name);
    });
    final colony = candidates.first;
    final damage = _sabotageDamageFor(colony);
    return FactionSabotageTarget(
      colonyId: colony.id,
      colonyName: colony.name,
      storedIndustry: colony.storedIndustry,
      damage: damage,
    );
  }

  int militaryStrengthFor(String factionId) {
    if (factionById(factionId) == null) {
      throw ArgumentError('Unknown faction: $factionId.');
    }

    var strength = 0;
    for (final unit in units) {
      if (unit.ownerId != factionId) {
        continue;
      }
      strength += _unitAttackFor(unit) + defenseFor(unit.type) + unit.health;
    }
    for (final colony in colonies) {
      if (colony.ownerId == factionId) {
        strength += colonyDefenseForColony(colony);
      }
    }
    return strength;
  }

  int _factionIndex(String factionId) {
    for (var index = 0; index < factions.length; index += 1) {
      if (factions[index].id == factionId) {
        return index;
      }
    }
    throw ArgumentError('Unknown faction: $factionId.');
  }

  OpenDeadlockGame copyWith({
    String? sessionId,
    int? turn,
    String? activeFactionId,
    String? victoryCondition,
    int? scoreTurnLimit,
    List<Faction>? factions,
    List<PlanetTile>? tiles,
    List<Colony>? colonies,
    List<Unit>? units,
    List<DiplomacyRelation>? diplomacy,
    List<CommandRecord>? commandHistory,
    List<TurnReport>? reports,
  }) {
    return OpenDeadlockGame(
      sessionId: sessionId ?? this.sessionId,
      turn: turn ?? this.turn,
      width: width,
      height: height,
      activeFactionId: activeFactionId ?? this.activeFactionId,
      victoryCondition: victoryCondition ?? this.victoryCondition,
      scoreTurnLimit: scoreTurnLimit ?? this.scoreTurnLimit,
      factions: factions ?? this.factions,
      tiles: tiles ?? this.tiles,
      colonies: colonies ?? this.colonies,
      units: units ?? this.units,
      diplomacy: diplomacy ?? this.diplomacy,
      commandHistory: commandHistory ?? this.commandHistory,
      reports: reports ?? this.reports,
    );
  }

  OpenDeadlockGame setColonyConstruction(
    String colonyId,
    String construction, {
    String? factionId,
  }) {
    if (!constructionOptions.contains(construction)) {
      throw ArgumentError('Unknown construction option: $construction.');
    }

    var foundColony = false;
    var changedOrder = false;
    final updatedColonies = colonies.map((colony) {
      if (colony.id != colonyId) {
        return colony;
      }
      foundColony = true;
      if (factionId != null && colony.ownerId != factionId) {
        throw ArgumentError(
            'Faction $factionId does not control colony $colonyId.');
      }
      if (colony.construction == construction) {
        return colony;
      }
      if (isCompletedConstruction(colony, construction)) {
        throw ArgumentError(
            '${colony.name} has already completed $construction.');
      }
      if (!isConstructionAvailableFor(colony, construction)) {
        throw ArgumentError(
            '${colony.name} must complete ${_constructionRequirementFor(construction)} before $construction.');
      }
      changedOrder = true;
      return colony.copyWith(
        construction: construction,
        storedIndustry: 0,
      );
    }).toList();

    if (!foundColony) {
      throw ArgumentError('Unknown colony: $colonyId.');
    }
    if (!changedOrder) {
      return this;
    }

    return copyWith(
      colonies: updatedColonies,
      reports: <TurnReport>[
        TurnReport(
          title: 'Build order changed',
          message: '$construction is now queued.',
        ),
        ...reports,
      ],
    );
  }

  OpenDeadlockGame rushConstruction(
    String colonyId,
    int industry, {
    String? factionId,
  }) {
    final creditCost = rushConstructionCostFor(industry);
    Colony? targetColony;
    for (final colony in colonies) {
      if (colony.id == colonyId) {
        targetColony = colony;
        break;
      }
    }
    if (targetColony == null) {
      throw ArgumentError('Unknown colony: $colonyId.');
    }

    final colony = targetColony;
    if (factionId != null && colony.ownerId != factionId) {
      throw ArgumentError(
          'Faction $factionId does not control colony $colonyId.');
    }
    final faction = factionById(colony.ownerId);
    if (faction == null) {
      throw ArgumentError('Unknown faction: ${colony.ownerId}.');
    }

    final buildCost = buildCostFor(colony.construction);
    final remainingIndustry = buildCost - colony.storedIndustry;
    if (remainingIndustry <= 0) {
      throw ArgumentError('${colony.name} already has enough stored industry.');
    }
    if (industry > remainingIndustry) {
      throw ArgumentError(
        '${colony.name} needs only $remainingIndustry more industry.',
      );
    }
    if (faction.resources.credits < creditCost) {
      throw ArgumentError(
        '${faction.name} needs $creditCost credits to rush $industry industry.',
      );
    }

    return copyWith(
      factions: factions.map((currentFaction) {
        if (currentFaction.id != faction.id) {
          return currentFaction;
        }
        return currentFaction.copyWith(
          resources: currentFaction.resources.copyWith(
            credits: currentFaction.resources.credits - creditCost,
          ),
        );
      }).toList(),
      colonies: colonies.map((currentColony) {
        if (currentColony.id != colonyId) {
          return currentColony;
        }
        return currentColony.copyWith(
          storedIndustry: currentColony.storedIndustry + industry,
        );
      }).toList(),
      reports: <TurnReport>[
        TurnReport(
          title: 'Rush order funded',
          message:
              '${colony.name} received $industry industry for $creditCost credits.',
        ),
        ...reports,
      ],
    );
  }

  OpenDeadlockGame setColonyFocus(
    String colonyId,
    String focus, {
    String? factionId,
  }) {
    if (!isKnownColonyFocus(focus)) {
      throw ArgumentError('Unknown colony focus: $focus.');
    }

    var foundColony = false;
    Colony? focusedColony;
    final updatedColonies = colonies.map((colony) {
      if (colony.id != colonyId) {
        return colony;
      }
      foundColony = true;
      if (factionId != null && colony.ownerId != factionId) {
        throw ArgumentError(
            'Faction $factionId does not control colony $colonyId.');
      }
      if (colony.focus == focus) {
        focusedColony = colony;
        return colony;
      }
      focusedColony = colony.copyWith(focus: focus);
      return focusedColony!;
    }).toList();

    if (!foundColony) {
      throw ArgumentError('Unknown colony: $colonyId.');
    }
    if (focusedColony == null || focusedColony!.focus != focus) {
      return this;
    }
    if (colonies.firstWhere((colony) => colony.id == colonyId).focus == focus) {
      return this;
    }

    final focusLabel = colonyFocusLabelFor(focus);
    return copyWith(
      colonies: updatedColonies,
      reports: <TurnReport>[
        TurnReport(
          title: 'Colony focus changed',
          message: '${focusedColony!.name} is now focused on $focusLabel.',
        ),
        ...reports,
      ],
    );
  }

  OpenDeadlockGame setColonySectorAssignment(
    String colonyId,
    int x,
    int y,
    bool assigned, {
    String? factionId,
  }) {
    Colony? targetColony;
    for (final colony in colonies) {
      if (colony.id == colonyId) {
        targetColony = colony;
        break;
      }
    }
    if (targetColony == null) {
      throw ArgumentError('Unknown colony: $colonyId.');
    }

    final colony = targetColony;
    if (factionId != null && colony.ownerId != factionId) {
      throw ArgumentError(
          'Faction $factionId does not control colony $colonyId.');
    }

    final alreadyAssigned = isSectorAssignedToColony(colony, x, y);
    if (assigned) {
      _validateColonySectorAssignment(
        colony,
        x,
        y,
        factionId: factionId,
      );
      if (alreadyAssigned) {
        return this;
      }
    } else if (!alreadyAssigned) {
      return this;
    }

    final sectorLabel = '${x + 1}, ${y + 1}';
    return copyWith(
      colonies: colonies.map((currentColony) {
        if (currentColony.id != colony.id) {
          return currentColony;
        }
        if (assigned) {
          return currentColony.copyWith(
            assignedSectors: <SectorAssignment>[
              ...currentColony.assignedSectors,
              SectorAssignment(x: x, y: y),
            ],
          );
        }
        return currentColony.copyWith(
          assignedSectors: currentColony.assignedSectors
              .where((assignment) => !assignment.matches(x, y))
              .toList(),
        );
      }).toList(),
      reports: <TurnReport>[
        TurnReport(
          title: assigned ? 'Sector assigned' : 'Sector released',
          message: assigned
              ? '${colony.name} is now working sector $sectorLabel.'
              : '${colony.name} stopped working sector $sectorLabel.',
        ),
        ...reports,
      ],
    );
  }

  OpenDeadlockGame setResearchProject(
    String factionId,
    String researchProject,
  ) {
    if (!researchOptions.contains(researchProject)) {
      throw ArgumentError('Unknown research project: $researchProject.');
    }

    var foundFaction = false;
    var changedProject = false;
    final updatedFactions = factions.map((faction) {
      if (faction.id != factionId) {
        return faction;
      }
      foundFaction = true;
      if (isCompletedResearch(faction, researchProject)) {
        throw ArgumentError(
            '${faction.name} has already completed $researchProject.');
      }
      if (faction.researchProject == researchProject) {
        return faction;
      }
      changedProject = true;
      return faction.copyWith(researchProject: researchProject);
    }).toList();

    if (!foundFaction) {
      throw ArgumentError('Unknown faction: $factionId.');
    }
    if (!changedProject) {
      return this;
    }

    return copyWith(
      factions: updatedFactions,
      reports: <TurnReport>[
        TurnReport(
          title: 'Research project changed',
          message: '$researchProject is now the active research project.',
        ),
        ...reports,
      ],
    );
  }

  OpenDeadlockGame fundResearch(String factionId, int research) {
    final creditCost = fundResearchCostFor(research);
    var foundFaction = false;
    late Faction fundedFaction;

    final updatedFactions = factions.map((faction) {
      if (faction.id != factionId) {
        return faction;
      }
      foundFaction = true;
      if (!researchOptions.contains(faction.researchProject)) {
        throw ArgumentError(
            'Unknown research project: ${faction.researchProject}.');
      }
      if (isCompletedResearch(faction, faction.researchProject)) {
        throw ArgumentError(
            '${faction.name} has already completed ${faction.researchProject}.');
      }
      final remainingResearch =
          researchCostFor(faction.researchProject) - faction.resources.research;
      if (remainingResearch <= 0) {
        throw ArgumentError(
            '${faction.name} already has enough stored research.');
      }
      if (research > remainingResearch) {
        throw ArgumentError(
          '${faction.name} needs only $remainingResearch more research.',
        );
      }
      if (faction.resources.credits < creditCost) {
        throw ArgumentError(
          '${faction.name} needs $creditCost credits to fund $research research.',
        );
      }

      fundedFaction = faction.copyWith(
        resources: faction.resources.copyWith(
          research: faction.resources.research + research,
          credits: faction.resources.credits - creditCost,
        ),
      );
      return fundedFaction;
    }).toList();

    if (!foundFaction) {
      throw ArgumentError('Unknown faction: $factionId.');
    }

    return copyWith(
      factions: updatedFactions,
      reports: <TurnReport>[
        TurnReport(
          title: 'Research funded',
          message:
              '${fundedFaction.name} funded $research research toward ${fundedFaction.researchProject} for $creditCost credits.',
        ),
        ...reports,
      ],
    );
  }

  OpenDeadlockGame setFactionControl(String factionId, String controlMode) {
    if (!Faction.isKnownControlMode(controlMode)) {
      throw ArgumentError('Unknown faction control mode: $controlMode.');
    }

    var foundFaction = false;
    var changedControl = false;
    Faction? updatedFaction;
    final updatedFactions = factions.map((faction) {
      if (faction.id != factionId) {
        return faction;
      }
      foundFaction = true;
      if (faction.controlMode == controlMode) {
        updatedFaction = faction;
        return faction;
      }
      changedControl = true;
      updatedFaction = faction.copyWith(controlMode: controlMode);
      return updatedFaction!;
    }).toList();

    if (!foundFaction) {
      throw ArgumentError('Unknown faction: $factionId.');
    }
    if (!changedControl) {
      return this;
    }

    return copyWith(
      factions: updatedFactions,
      reports: <TurnReport>[
        TurnReport(
          title: 'Faction control changed',
          message:
              '${updatedFaction!.name} is now ${Faction.controlModeLabelFor(controlMode)} controlled.',
        ),
        ...reports,
      ],
    );
  }

  OpenDeadlockGame setFactionDifficulty(String factionId, String difficulty) {
    if (!Faction.isKnownDifficulty(difficulty)) {
      throw ArgumentError('Unknown faction difficulty: $difficulty.');
    }

    var foundFaction = false;
    var changedDifficulty = false;
    Faction? updatedFaction;
    final updatedFactions = factions.map((faction) {
      if (faction.id != factionId) {
        return faction;
      }
      foundFaction = true;
      if (faction.difficulty == difficulty) {
        updatedFaction = faction;
        return faction;
      }
      changedDifficulty = true;
      updatedFaction = faction.copyWith(difficulty: difficulty);
      return updatedFaction!;
    }).toList();

    if (!foundFaction) {
      throw ArgumentError('Unknown faction: $factionId.');
    }
    if (!changedDifficulty) {
      return this;
    }

    return copyWith(
      factions: updatedFactions,
      reports: <TurnReport>[
        TurnReport(
          title: 'Faction difficulty changed',
          message:
              '${updatedFaction!.name} is now ${Faction.difficultyLabelFor(difficulty)} difficulty.',
        ),
        ...reports,
      ],
    );
  }

  OpenDeadlockGame setFactionTaxPolicy(String factionId, String taxPolicy) {
    if (!Faction.isKnownTaxPolicy(taxPolicy)) {
      throw ArgumentError('Unknown tax policy: $taxPolicy.');
    }

    var foundFaction = false;
    var changedTaxPolicy = false;
    Faction? updatedFaction;
    final updatedFactions = factions.map((faction) {
      if (faction.id != factionId) {
        return faction;
      }
      foundFaction = true;
      if (faction.taxPolicy == taxPolicy) {
        updatedFaction = faction;
        return faction;
      }
      changedTaxPolicy = true;
      updatedFaction = faction.copyWith(taxPolicy: taxPolicy);
      return updatedFaction!;
    }).toList();

    if (!foundFaction) {
      throw ArgumentError('Unknown faction: $factionId.');
    }
    if (!changedTaxPolicy) {
      return this;
    }

    return copyWith(
      factions: updatedFactions,
      reports: <TurnReport>[
        TurnReport(
          title: 'Tax policy changed',
          message:
              '${updatedFaction!.name} tax policy is now ${Faction.taxPolicyLabelFor(taxPolicy)}.',
        ),
        ...reports,
      ],
    );
  }

  OpenDeadlockGame setDiplomacyStatus(
    String factionId,
    String targetFactionId,
    String status,
  ) {
    if (!diplomacyStatuses.contains(status)) {
      throw ArgumentError('Unknown diplomacy status: $status.');
    }
    final faction = factionById(factionId);
    if (faction == null) {
      throw ArgumentError('Unknown faction: $factionId.');
    }
    final targetFaction = factionById(targetFactionId);
    if (targetFaction == null) {
      throw ArgumentError('Unknown faction: $targetFactionId.');
    }
    if (factionId == targetFactionId) {
      throw ArgumentError('A faction cannot change diplomacy with itself.');
    }
    if (diplomacyStatusBetween(factionId, targetFactionId) == status) {
      return this;
    }

    final updatedDiplomacy = <DiplomacyRelation>[
      for (final relation in diplomacy)
        if (!relation.matches(factionId, targetFactionId)) relation,
      DiplomacyRelation.between(
        factionId: factionId,
        targetFactionId: targetFactionId,
        status: status,
      ),
    ];
    final statusLabel = _diplomacyStatusPhraseFor(status);
    final updatedTiles = status == diplomacyStatusAlliance
        ? _shareAllianceIntelBetween(tiles, factionId, targetFactionId)
        : tiles;

    return copyWith(
      diplomacy: updatedDiplomacy,
      tiles: updatedTiles,
      reports: <TurnReport>[
        TurnReport(
          title: 'Diplomacy changed',
          message:
              '${faction.name} and ${targetFaction.name} are now $statusLabel.',
        ),
        ...reports,
      ],
    );
  }

  OpenDeadlockGame scanFactionIntel(
    String factionId,
    String targetFactionId,
  ) {
    final faction = factionById(factionId);
    if (faction == null) {
      throw ArgumentError('Unknown faction: $factionId.');
    }
    final targetFaction = factionById(targetFactionId);
    if (targetFaction == null) {
      throw ArgumentError('Unknown faction: $targetFactionId.');
    }
    if (factionId == targetFactionId) {
      throw ArgumentError('A faction cannot scan itself.');
    }
    if (faction.resources.credits < intelScanCreditCost) {
      throw ArgumentError(
        '${faction.name} needs $intelScanCreditCost credits to scan ${targetFaction.name}.',
      );
    }

    final scanTarget = _intelScanTargetFor(factionId, targetFactionId);
    if (scanTarget == null) {
      throw ArgumentError(
        '${targetFaction.name} has no new colony intelligence to reveal.',
      );
    }

    return copyWith(
      factions: factions.map((currentFaction) {
        if (currentFaction.id != factionId) {
          return currentFaction;
        }
        return currentFaction.copyWith(
          resources: currentFaction.resources.copyWith(
            credits: currentFaction.resources.credits - intelScanCreditCost,
          ),
        );
      }).toList(),
      tiles: tiles.map((tile) {
        if (!_containsTile(scanTarget.tiles, tile.x, tile.y)) {
          return tile;
        }
        return tile.revealTo(factionId);
      }).toList(),
      reports: <TurnReport>[
        TurnReport(
          title: 'Intel scan complete',
          message:
              '${faction.name} scanned ${targetFaction.name} and revealed ${scanTarget.tiles.length} sector(s) near ${scanTarget.colony.name} for $intelScanCreditCost credits.',
          details: <String, String>{
            'kind': 'intel',
            'factionId': factionId,
            'targetFactionId': targetFactionId,
            'colonyId': scanTarget.colony.id,
            'revealedSectors': '${scanTarget.tiles.length}',
          },
        ),
        ...reports,
      ],
    );
  }

  OpenDeadlockGame sabotageColony(
    String factionId,
    String targetFactionId,
  ) {
    final faction = factionById(factionId);
    if (faction == null) {
      throw ArgumentError('Unknown faction: $factionId.');
    }
    final targetFaction = factionById(targetFactionId);
    if (targetFaction == null) {
      throw ArgumentError('Unknown faction: $targetFactionId.');
    }
    if (factionId == targetFactionId) {
      throw ArgumentError('A faction cannot sabotage itself.');
    }
    if (!areAtWar(factionId, targetFactionId)) {
      throw ArgumentError(
        '${faction.name} must be at war with ${targetFaction.name} to sabotage colonies.',
      );
    }
    if (faction.resources.credits < sabotageCreditCost) {
      throw ArgumentError(
        '${faction.name} needs $sabotageCreditCost credits to sabotage ${targetFaction.name}.',
      );
    }

    final target = sabotageTargetFor(factionId, targetFactionId);
    if (target == null) {
      throw ArgumentError(
        '${targetFaction.name} has no visible construction to sabotage.',
      );
    }
    final targetColony = colonyById(target.colonyId);
    final protection = sabotageProtectionForColony(targetColony);

    return copyWith(
      factions: factions.map((currentFaction) {
        if (currentFaction.id != factionId) {
          return currentFaction;
        }
        return currentFaction.copyWith(
          resources: currentFaction.resources.copyWith(
            credits: currentFaction.resources.credits - sabotageCreditCost,
          ),
        );
      }).toList(),
      colonies: colonies.map((colony) {
        if (colony.id != target.colonyId) {
          return colony;
        }
        return colony.copyWith(
          storedIndustry: colony.storedIndustry - target.damage,
        );
      }).toList(),
      reports: <TurnReport>[
        TurnReport(
          title: 'Sabotage complete',
          message:
              '${faction.name} sabotaged ${target.colonyName}, destroying ${target.damage} stored industry for $sabotageCreditCost credits.',
          category: TurnReport.categoryTactical,
          details: <String, String>{
            'kind': 'sabotage',
            'factionId': factionId,
            'targetFactionId': targetFactionId,
            'colonyId': target.colonyId,
            'colonyName': target.colonyName,
            'x': '${targetColony.x}',
            'y': '${targetColony.y}',
            'damage': '${target.damage}',
            'protection': '$protection',
          },
        ),
        ...reports,
      ],
    );
  }

  OpenDeadlockGame recoverUnit(
    String unitId, {
    String? factionId,
  }) {
    Unit? targetUnit;
    for (final unit in units) {
      if (unit.id == unitId) {
        targetUnit = unit;
        break;
      }
    }
    if (targetUnit == null) {
      throw ArgumentError('Unknown unit: $unitId.');
    }

    final unit = targetUnit;
    if (factionId != null && unit.ownerId != factionId) {
      throw ArgumentError('Faction $factionId does not control unit $unitId.');
    }
    if (unit.movesRemaining <= 0) {
      throw ArgumentError('Unit $unitId has no moves remaining.');
    }

    final maxHealth = maxHealthFor(unit.type);
    if (unit.health >= maxHealth) {
      throw ArgumentError('${unit.name} is already at full health.');
    }

    final nextHealth =
        _clampInt(unit.health + unitRecoveryAmount, 0, maxHealth);
    final healthRestored = nextHealth - unit.health;

    return copyWith(
      units: units.map((currentUnit) {
        if (currentUnit.id != unitId) {
          return currentUnit;
        }
        return currentUnit.copyWith(
          health: nextHealth,
          movesRemaining: 0,
        );
      }).toList(),
      reports: <TurnReport>[
        TurnReport(
          title: '${unit.name} recovered',
          message:
              '${unit.name} restored $healthRestored health and used its remaining moves.',
        ),
        ...reports,
      ],
    );
  }

  OpenDeadlockGame moveUnit(
    String unitId,
    int x,
    int y, {
    String? factionId,
  }) {
    if (!_isInsideMap(x, y)) {
      throw ArgumentError('Target is outside the map: $x, $y.');
    }

    final targetTile = tileAt(x, y);
    if (!isTerrainPassable(targetTile.terrain)) {
      throw ArgumentError('Units cannot enter water sectors yet.');
    }

    Unit? movingUnit;
    for (final unit in units) {
      if (unit.id == unitId) {
        movingUnit = unit;
        break;
      }
    }
    if (movingUnit == null) {
      throw ArgumentError('Unknown unit: $unitId.');
    }
    if (factionId != null && movingUnit.ownerId != factionId) {
      throw ArgumentError('Faction $factionId does not control unit $unitId.');
    }
    if (movingUnit.movesRemaining <= 0) {
      throw ArgumentError('Unit $unitId has no moves remaining.');
    }
    final moveCost = movementCostForTerrain(targetTile.terrain);
    if (movingUnit.movesRemaining < moveCost) {
      throw ArgumentError(
        'Unit $unitId needs $moveCost move point(s) to enter ${targetTile.terrain}.',
      );
    }
    if (_manhattanDistance(movingUnit.x, movingUnit.y, x, y) != 1) {
      throw ArgumentError('Units can only move to adjacent sectors.');
    }

    final occupyingUnit = unitAt(x, y);
    if (occupyingUnit != null && occupyingUnit.id != unitId) {
      if (occupyingUnit.ownerId == movingUnit.ownerId) {
        throw ArgumentError('Target sector is already occupied.');
      }
      if (!areAtWar(movingUnit.ownerId, occupyingUnit.ownerId)) {
        throw ArgumentError(
            'Faction ${movingUnit.ownerId} is not at war with ${occupyingUnit.ownerId}.');
      }
      return _resolveUnitCombat(movingUnit, occupyingUnit, targetTile);
    }

    final targetColony = colonyAt(x, y);
    if (targetColony != null && targetColony.ownerId != movingUnit.ownerId) {
      if (!areAtWar(movingUnit.ownerId, targetColony.ownerId)) {
        throw ArgumentError(
            'Faction ${movingUnit.ownerId} is not at war with ${targetColony.ownerId}.');
      }
      return _resolveColonyAssault(movingUnit, targetColony, targetTile);
    }

    if (!canFactionTraverseSector(movingUnit.ownerId, targetTile)) {
      throw ArgumentError(
          'Units cannot enter enemy-controlled sectors without attacking.');
    }

    Unit? movedUnit;
    final updatedUnits = units.map((unit) {
      if (unit.id != unitId) {
        return unit;
      }

      movedUnit = unit.copyWith(
        x: x,
        y: y,
        movesRemaining: unit.movesRemaining - moveCost,
      );
      return movedUnit!;
    }).toList();

    final updatedTiles = tiles.map((tile) {
      if (tile.x != x || tile.y != y) {
        return tile;
      }
      return tile
          .copyWith(ownerId: tile.ownerId ?? movedUnit!.ownerId)
          .revealTo(movedUnit!.ownerId);
    }).toList();

    return copyWith(
      tiles: updatedTiles,
      units: updatedUnits,
      reports: <TurnReport>[
        TurnReport(
          title: '${movedUnit!.name} moved',
          message:
              'The unit moved to sector ${x + 1}, ${y + 1} and spent $moveCost move point(s).',
        ),
        ...reports,
      ],
    );
  }

  OpenDeadlockGame _resolveUnitCombat(
      Unit attacker, Unit defender, PlanetTile targetTile) {
    final preview = previewUnitCombat(attacker, defender);
    final canEnterTarget =
        targetTile.colonyId == null || targetTile.ownerId == attacker.ownerId;
    final sectorCaptured = preview.attackerSurvives &&
        !preview.defenderSurvives &&
        targetTile.colonyId == null;
    final updatedUnits = <Unit>[];
    for (final unit in units) {
      if (unit.id == attacker.id) {
        if (preview.attackerSurvives) {
          updatedUnits.add(
            unit.copyWith(
              x: preview.defenderSurvives || !canEnterTarget
                  ? unit.x
                  : targetTile.x,
              y: preview.defenderSurvives || !canEnterTarget
                  ? unit.y
                  : targetTile.y,
              movesRemaining: 0,
              health: preview.attackerHealth,
            ),
          );
        }
        continue;
      }
      if (unit.id == defender.id) {
        if (preview.defenderSurvives) {
          updatedUnits.add(
            unit.copyWith(
              movesRemaining: 0,
              health: preview.defenderHealth,
            ),
          );
        }
        continue;
      }
      updatedUnits.add(unit);
    }

    final updatedTiles = tiles.map((tile) {
      if (tile.x != targetTile.x || tile.y != targetTile.y) {
        return tile;
      }
      return tile
          .copyWith(
            ownerId: preview.defenderSurvives ||
                    !preview.attackerSurvives ||
                    targetTile.colonyId != null
                ? tile.ownerId
                : attacker.ownerId,
          )
          .revealTo(attacker.ownerId);
    }).toList();

    return copyWith(
      tiles: updatedTiles,
      colonies: sectorCaptured
          ? _coloniesWithoutAssignmentAt(targetTile.x, targetTile.y)
          : colonies,
      units: updatedUnits,
      reports: <TurnReport>[
        TurnReport(
          title: _combatTitle(
            attacker,
            defender,
            preview.attackerSurvives,
            preview.defenderSurvives,
          ),
          message: _combatMessage(
            attacker,
            defender,
            preview.attackDamage,
            preview.counterDamage,
            preview.attackerSurvives,
            preview.defenderSurvives,
          ),
          category: TurnReport.categoryBattle,
          details: <String, String>{
            'kind': 'unit',
            'attackerId': attacker.id,
            'attackerName': attacker.name,
            'attackerOwnerId': attacker.ownerId,
            'defenderId': defender.id,
            'defenderName': defender.name,
            'defenderOwnerId': defender.ownerId,
            'x': '${targetTile.x}',
            'y': '${targetTile.y}',
            'attackDamage': '${preview.attackDamage}',
            'counterDamage': '${preview.counterDamage}',
            'attackerHealth': '${preview.attackerHealth}',
            'defenderHealth': '${preview.defenderHealth}',
            'attackerSurvived': '${preview.attackerSurvives}',
            'defenderSurvived': '${preview.defenderSurvives}',
          },
        ),
        ...reports,
      ],
    );
  }

  int _combatDamage(Unit attacker, Unit defender) {
    final rawDamage = _unitAttackFor(attacker) - defenseFor(defender.type);
    return rawDamage < 1 ? 1 : rawDamage;
  }

  String _combatTitle(
    Unit attacker,
    Unit defender,
    bool attackerSurvived,
    bool defenderSurvived,
  ) {
    if (attackerSurvived && !defenderSurvived) {
      return '${attacker.name} defeated ${defender.name}';
    }
    if (!attackerSurvived && defenderSurvived) {
      return '${defender.name} repelled ${attacker.name}';
    }
    if (!attackerSurvived && !defenderSurvived) {
      return '${attacker.name} and ${defender.name} destroyed each other';
    }
    return '${attacker.name} attacked ${defender.name}';
  }

  String _combatMessage(
    Unit attacker,
    Unit defender,
    int attackDamage,
    int counterDamage,
    bool attackerSurvived,
    bool defenderSurvived,
  ) {
    final attackerStatus = attackerSurvived ? 'survived' : 'was destroyed';
    final defenderStatus = defenderSurvived ? 'survived' : 'was destroyed';
    if (counterDamage == 0) {
      return '${attacker.name} dealt $attackDamage damage. ${defender.name} $defenderStatus.';
    }
    return '${attacker.name} dealt $attackDamage damage and $attackerStatus. '
        '${defender.name} countered for $counterDamage damage and $defenderStatus.';
  }

  OpenDeadlockGame _resolveColonyAssault(
      Unit attacker, Colony colony, PlanetTile targetTile) {
    final preview = previewColonyAssault(attacker, colony);
    final capturedAssignedSectors = preview.colonyCaptured
        ? colony.assignedSectors
        : const <SectorAssignment>[];

    final updatedUnits = <Unit>[];
    for (final unit in units) {
      if (unit.id == attacker.id) {
        if (preview.attackerSurvives) {
          updatedUnits.add(
            unit.copyWith(
              x: preview.colonyCaptured ? targetTile.x : unit.x,
              y: preview.colonyCaptured ? targetTile.y : unit.y,
              movesRemaining: 0,
              health: preview.attackerHealth,
            ),
          );
        }
        continue;
      }
      updatedUnits.add(unit);
    }

    final updatedColonies = colonies.map((currentColony) {
      if (currentColony.id != colony.id) {
        return currentColony;
      }
      return currentColony.copyWith(
        ownerId:
            preview.colonyCaptured ? attacker.ownerId : currentColony.ownerId,
        population: preview.population,
        morale: preview.morale,
        storedIndustry:
            preview.colonyCaptured ? 0 : currentColony.storedIndustry,
      );
    }).toList();

    final updatedTiles = tiles.map((tile) {
      final isCapturedColonyTile =
          tile.x == targetTile.x && tile.y == targetTile.y;
      final isCapturedAssignedSector = preview.colonyCaptured &&
          _containsAssignment(capturedAssignedSectors, tile.x, tile.y);
      if (!isCapturedColonyTile && !isCapturedAssignedSector) {
        return tile;
      }
      return tile
          .copyWith(
              ownerId: preview.colonyCaptured ? attacker.ownerId : tile.ownerId)
          .revealTo(attacker.ownerId);
    }).toList();

    return copyWith(
      tiles: updatedTiles,
      colonies: updatedColonies,
      units: updatedUnits,
      reports: <TurnReport>[
        TurnReport(
          title: preview.colonyCaptured
              ? '${attacker.name} captured ${colony.name}'
              : '${colony.name} repelled ${attacker.name}',
          message: _colonyAssaultMessage(
            attacker,
            colony,
            preview.attackPower,
            preview.defensePower,
            preview.counterDamage,
            preview.attackerSurvives,
            preview.colonyCaptured,
          ),
          category: TurnReport.categoryBattle,
          details: <String, String>{
            'kind': 'colony',
            'attackerId': attacker.id,
            'attackerName': attacker.name,
            'attackerOwnerId': attacker.ownerId,
            'colonyId': colony.id,
            'colonyName': colony.name,
            'defenderOwnerId': colony.ownerId,
            'x': '${targetTile.x}',
            'y': '${targetTile.y}',
            'attackPower': '${preview.attackPower}',
            'defensePower': '${preview.defensePower}',
            'counterDamage': '${preview.counterDamage}',
            'attackerHealth': '${preview.attackerHealth}',
            'attackerSurvived': '${preview.attackerSurvives}',
            'colonyCaptured': '${preview.colonyCaptured}',
            'previousPopulation': '${colony.population}',
            'previousMorale': '${colony.morale}',
            'population': '${preview.population}',
            'morale': '${preview.morale}',
            'populationDelta': '${preview.population - colony.population}',
            'moraleDelta': '${preview.morale - colony.morale}',
            'capturedAssignedSectors': '${capturedAssignedSectors.length}',
          },
        ),
        ...reports,
      ],
    );
  }

  String _colonyAssaultMessage(
    Unit attacker,
    Colony colony,
    int attackPower,
    int defensePower,
    int counterDamage,
    bool attackerSurvived,
    bool colonyCaptured,
  ) {
    final attackerStatus = attackerSurvived ? 'survived' : 'was destroyed';
    if (colonyCaptured) {
      return '${attacker.name} overcame $defensePower defense with $attackPower assault power '
          'and took control of ${colony.name}.';
    }
    return '${attacker.name} pressed an assault with $attackPower power against $defensePower defense, '
        'took $counterDamage damage, and $attackerStatus.';
  }

  bool _containsAssignment(
    List<SectorAssignment> assignments,
    int x,
    int y,
  ) {
    for (final assignment in assignments) {
      if (assignment.matches(x, y)) {
        return true;
      }
    }
    return false;
  }

  OpenDeadlockGame foundColony(
    String unitId,
    String colonyId,
    String name, {
    String? factionId,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Colony name cannot be empty.');
    }
    if (hasColonyId(colonyId)) {
      throw ArgumentError('Colony id already exists: $colonyId.');
    }

    Unit? foundingUnit;
    for (final unit in units) {
      if (unit.id == unitId) {
        foundingUnit = unit;
        break;
      }
    }
    if (foundingUnit == null) {
      throw ArgumentError('Unknown unit: $unitId.');
    }
    if (factionId != null && foundingUnit.ownerId != factionId) {
      throw ArgumentError('Faction $factionId does not control unit $unitId.');
    }

    final unit = foundingUnit;
    final tile = tileAt(unit.x, unit.y);
    if (tile.terrain == 'water') {
      throw ArgumentError('Colonies cannot be founded on water sectors.');
    }
    if (tile.ownerId != unit.ownerId) {
      throw ArgumentError(
          'Colonies can only be founded on controlled sectors.');
    }
    if (tile.colonyId != null || colonyAt(tile.x, tile.y) != null) {
      throw ArgumentError('A colony already exists in this sector.');
    }

    final newColony = Colony(
      id: colonyId,
      name: name.trim(),
      ownerId: unit.ownerId,
      x: unit.x,
      y: unit.y,
      population: 1,
      morale: _startingMoraleForFaction(unit.ownerId),
      construction: 'Colony Hub',
      storedIndustry: 0,
      completedBuildings: const <String>[],
    );

    return copyWith(
      tiles: tiles.map((currentTile) {
        if (currentTile.x != tile.x || currentTile.y != tile.y) {
          return currentTile;
        }
        return currentTile
            .copyWith(
              ownerId: unit.ownerId,
              colonyId: colonyId,
            )
            .revealTo(unit.ownerId);
      }).toList(),
      colonies: <Colony>[
        ..._coloniesWithoutAssignmentAt(tile.x, tile.y),
        newColony,
      ],
      units: units.where((unit) => unit.id != unitId).toList(),
      reports: <TurnReport>[
        TurnReport(
          title: '${newColony.name} founded',
          message: '${unit.name} established a new colony.',
        ),
        ...reports,
      ],
    );
  }

  OpenDeadlockGame applyCommand(GameCommand command, {bool record = true}) {
    if (isGameOver) {
      throw ArgumentError('Game is over. $winningVictoryMessage');
    }
    if (_commandRequiresActiveFaction(command) &&
        command.factionId != activeFactionId) {
      throw ArgumentError(
        'Faction ${command.factionId} cannot issue ${command.type} orders '
        'while $activeFactionId is active.',
      );
    }

    final previousWinnerId = winningFactionId;
    final previouslyDefeatedFactionIds = _defeatedFactionIds();
    final previousReportCount = reports.length;
    final updatedGame = command
        .apply(this)
        ._withDefeatReportsIfNeeded(
          previouslyDefeatedFactionIds,
          previousReportCount,
        )
        ._withVictoryReportIfNeeded(previousWinnerId);
    if (!record) {
      return updatedGame;
    }
    return updatedGame.copyWith(
      commandHistory: <CommandRecord>[
        ...updatedGame.commandHistory,
        CommandRecord(
          turn: turn,
          factionId: command.factionId,
          command: command,
        ),
      ],
    );
  }

  bool _commandRequiresActiveFaction(GameCommand command) {
    return command is! SetFactionControlCommand &&
        command is! SetFactionDifficultyCommand;
  }

  OpenDeadlockGame applyCommands(Iterable<GameCommand> commands,
      {bool record = true}) {
    var updatedGame = this;
    for (final command in commands) {
      if (updatedGame.isGameOver) {
        break;
      }
      updatedGame = updatedGame.applyCommand(command, record: record);
    }
    return updatedGame;
  }

  List<GameCommand> planComputerCommands() {
    final commands = <GameCommand>[];
    for (final faction in factions) {
      if (!faction.isComputer) {
        continue;
      }
      commands.addAll(planComputerCommandsFor(faction.id));
    }
    return commands;
  }

  List<GameCommand> planComputerCommandsFor(String factionId) {
    if (isGameOver) {
      return const <GameCommand>[];
    }

    final faction = factionById(factionId);
    if (faction == null) {
      throw ArgumentError('Unknown faction: $factionId.');
    }
    if (!faction.isComputer) {
      return const <GameCommand>[];
    }

    var planningGame = this;
    final commands = <GameCommand>[];

    bool addPlannedCommand(GameCommand command) {
      if (planningGame.isGameOver) {
        return false;
      }
      try {
        planningGame = command.apply(planningGame);
        commands.add(command);
        return true;
      } on ArgumentError {
        return false;
      }
    }

    for (final diplomacyCommand
        in planningGame._preferredDiplomacyCommandsFor(faction)) {
      addPlannedCommand(diplomacyCommand);
    }
    final planningFaction = planningGame.factionById(faction.id)!;
    final preferredResearch =
        planningGame._preferredResearchForFaction(planningFaction);
    if (preferredResearch != planningFaction.researchProject) {
      addPlannedCommand(
        SetResearchProjectCommand(
          factionId: faction.id,
          researchProject: preferredResearch,
        ),
      );
    }
    final researchFunding = planningGame._researchFundingFor(faction.id);
    if (researchFunding != null) {
      addPlannedCommand(
        FundResearchCommand(
          factionId: faction.id,
          research: researchFunding,
        ),
      );
    }
    final preferredTaxPolicy = planningGame._preferredTaxPolicyFor(faction);
    if (preferredTaxPolicy != faction.taxPolicy) {
      addPlannedCommand(
        SetFactionTaxPolicyCommand(
          factionId: faction.id,
          taxPolicy: preferredTaxPolicy,
        ),
      );
    }

    for (final colony in colonies) {
      if (colony.ownerId != faction.id) {
        continue;
      }
      final planningColony = planningGame.colonyById(colony.id);
      final tile = planningGame.tileAt(planningColony.x, planningColony.y);
      final preferredConstruction = _preferredConstructionFor(
        planningColony,
        tile,
        faction,
        isThreatened: planningGame._isColonyThreatened(planningColony),
        isSabotageExposed:
            planningGame._isColonySabotageExposed(planningColony),
      );
      if (preferredConstruction == planningColony.construction) {
        continue;
      }
      addPlannedCommand(
        SetColonyConstructionCommand(
          factionId: faction.id,
          colonyId: colony.id,
          construction: preferredConstruction,
        ),
      );
    }
    for (final colony in colonies) {
      if (colony.ownerId != faction.id) {
        continue;
      }
      final planningColony = planningGame.colonyById(colony.id);
      final rushIndustry = planningGame._rushIndustryForColony(planningColony);
      if (rushIndustry == null) {
        continue;
      }
      addPlannedCommand(
        RushConstructionCommand(
          factionId: faction.id,
          colonyId: colony.id,
          industry: rushIndustry,
        ),
      );
    }
    for (final colony in colonies) {
      if (colony.ownerId != faction.id) {
        continue;
      }
      final planningColony = planningGame.colonyById(colony.id);
      final preferredFocus = planningGame._preferredFocusFor(
        planningColony,
        faction,
      );
      if (preferredFocus == planningColony.focus) {
        continue;
      }
      addPlannedCommand(
        SetColonyFocusCommand(
          factionId: faction.id,
          colonyId: colony.id,
          focus: preferredFocus,
        ),
      );
    }
    final intelScanCommand =
        planningGame._preferredIntelScanCommandFor(faction.id);
    if (intelScanCommand != null) {
      addPlannedCommand(intelScanCommand);
    }
    final sabotageCommand = planningGame._preferredSabotageCommandFor(faction);
    if (sabotageCommand != null) {
      addPlannedCommand(sabotageCommand);
    }
    for (final unit in units) {
      if (unit.ownerId != faction.id || unit.movesRemaining <= 0) {
        continue;
      }
      Unit planningUnit;
      try {
        planningUnit = planningGame.unitById(unit.id);
      } on StateError {
        continue;
      }
      if (planningUnit.movesRemaining <= 0) {
        continue;
      }
      final tacticalTarget = planningGame._preferredTacticalTargetFor(
        planningUnit,
      );
      if (tacticalTarget != null) {
        addPlannedCommand(
          MoveUnitCommand(
            factionId: faction.id,
            unitId: unit.id,
            x: tacticalTarget.x,
            y: tacticalTarget.y,
          ),
        );
        continue;
      }
      if (planningGame._shouldFoundColonyWith(planningUnit)) {
        final colonyId =
            '${faction.id}-outpost-${planningUnit.x}-${planningUnit.y}';
        if (!planningGame.hasColonyId(colonyId)) {
          addPlannedCommand(
            FoundColonyCommand(
              factionId: faction.id,
              unitId: unit.id,
              colonyId: colonyId,
              name: 'Outpost ${planningUnit.x + 1}-${planningUnit.y + 1}',
            ),
          );
          continue;
        }
      }
      if (planningGame._shouldRecoverUnit(planningUnit)) {
        addPlannedCommand(
          RecoverUnitCommand(
            factionId: faction.id,
            unitId: unit.id,
          ),
        );
        continue;
      }
      final target = planningGame._preferredMoveFor(planningUnit);
      if (target == null) {
        continue;
      }
      addPlannedCommand(
        MoveUnitCommand(
          factionId: faction.id,
          unitId: unit.id,
          x: target.x,
          y: target.y,
        ),
      );
    }
    final plannedColonies = planningGame.colonies.toList(growable: false);
    for (final colony in plannedColonies) {
      if (colony.ownerId != faction.id) {
        continue;
      }
      var assignmentAttempts = 0;
      while (assignmentAttempts < assignedSectorCapacityFor(colony)) {
        assignmentAttempts += 1;
        final planningColony = planningGame.colonyById(colony.id);
        final sector = planningGame._preferredAssignableSectorFor(
          planningColony,
        );
        if (sector == null) {
          break;
        }
        if (!addPlannedCommand(
          SetColonySectorAssignmentCommand(
            factionId: faction.id,
            colonyId: colony.id,
            x: sector.x,
            y: sector.y,
            assigned: true,
          ),
        )) {
          break;
        }
      }
    }
    return commands;
  }

  OpenDeadlockGame advanceTurn({bool recordComputerCommands = true}) {
    if (isGameOver) {
      return this;
    }

    return _advanceToNextFaction()._advancePastComputerTurns(
      recordComputerCommands: recordComputerCommands,
    );
  }

  OpenDeadlockGame advanceComputerTurn({bool recordComputerCommands = true}) {
    if (isGameOver) {
      return this;
    }
    if (!activeFaction.isComputer) {
      throw ArgumentError('${activeFaction.name} is not computer controlled.');
    }

    return _advancePastComputerTurns(
      recordComputerCommands: recordComputerCommands,
    );
  }

  OpenDeadlockGame _advancePastComputerTurns({
    required bool recordComputerCommands,
  }) {
    var updatedGame = this;
    var automatedCommandCount = 0;
    var automatedFactionCount = 0;

    while (!updatedGame.isGameOver &&
        updatedGame.activeFaction.isComputer &&
        automatedFactionCount < factions.length) {
      final computerCommands =
          updatedGame.planComputerCommandsFor(updatedGame.activeFactionId);
      automatedCommandCount += computerCommands.length;
      updatedGame = updatedGame.applyCommands(
        computerCommands,
        record: recordComputerCommands,
      );
      if (updatedGame.isGameOver) {
        break;
      }
      updatedGame = updatedGame._advanceToNextFaction();
      automatedFactionCount += 1;
    }

    if (updatedGame.isGameOver) {
      return updatedGame;
    }

    final newReports = <TurnReport>[
      TurnReport(
        title: '${updatedGame.activeFaction.name} is ready',
        message: 'Orders can now be issued for turn ${updatedGame.turn}.',
      ),
    ];
    if (automatedCommandCount > 0) {
      newReports.add(
        TurnReport(
          title: 'Computer opponents issued orders',
          message:
              '$automatedCommandCount automated order(s) were applied before the next player turn.',
        ),
      );
    }

    return updatedGame.copyWith(
      reports: <TurnReport>[
        ...newReports,
        ...updatedGame.reports,
      ],
    );
  }

  OpenDeadlockGame _advanceToNextFaction() {
    if (isGameOver) {
      return this;
    }

    final currentIndex = _factionIndex(activeFactionId);
    var updatedGame = this;
    var roundAdvanced = false;
    for (var offset = 1; offset <= factions.length; offset += 1) {
      final nextIndex = (currentIndex + offset) % factions.length;
      final roundWrapped = currentIndex + offset >= factions.length;
      if (roundWrapped && !roundAdvanced) {
        updatedGame = updatedGame.endTurn();
        roundAdvanced = true;
        if (updatedGame.isGameOver) {
          return updatedGame;
        }
      }
      final nextFaction = updatedGame.factions[nextIndex];
      if (updatedGame._factionCanTakeTurn(nextFaction.id)) {
        return updatedGame.copyWith(activeFactionId: nextFaction.id);
      }
    }

    return updatedGame;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sessionId': sessionId,
      'turn': turn,
      'width': width,
      'height': height,
      'activeFactionId': activeFactionId,
      'victoryCondition': victoryCondition,
      'scoreTurnLimit': scoreTurnLimit,
      'factions': factions.map((faction) => faction.toJson()).toList(),
      'tiles': tiles.map((tile) => tile.toJson()).toList(),
      'colonies': colonies.map((colony) => colony.toJson()).toList(),
      'units': units.map((unit) => unit.toJson()).toList(),
      'diplomacy': diplomacy.map((relation) => relation.toJson()).toList(),
      'commandHistory':
          commandHistory.map((record) => record.toJson()).toList(),
      'reports': reports.map((report) => report.toJson()).toList(),
    };
  }

  static OpenDeadlockGame fromJson(Map<String, dynamic> json) {
    return OpenDeadlockGame(
      sessionId: json['sessionId'] as String? ?? _legacySessionIdFor(json),
      turn: _readInt(json['turn']),
      width: _readInt(json['width']),
      height: _readInt(json['height']),
      activeFactionId: json['activeFactionId'] as String,
      victoryCondition:
          _knownVictoryConditionOrDefault(json['victoryCondition'] as String?),
      scoreTurnLimit: _readScoreTurnLimit(json['scoreTurnLimit']),
      factions: (json['factions'] as List<dynamic>)
          .map((faction) => Faction.fromJson(faction as Map<String, dynamic>))
          .toList(),
      tiles: (json['tiles'] as List<dynamic>)
          .map((tile) => PlanetTile.fromJson(tile as Map<String, dynamic>))
          .toList(),
      colonies: (json['colonies'] as List<dynamic>)
          .map((colony) => Colony.fromJson(colony as Map<String, dynamic>))
          .toList(),
      units: (json['units'] as List<dynamic>)
          .map((unit) => Unit.fromJson(unit as Map<String, dynamic>))
          .toList(),
      diplomacy: (json['diplomacy'] as List<dynamic>? ?? const <dynamic>[])
          .map((relation) =>
              DiplomacyRelation.fromJson(relation as Map<String, dynamic>))
          .toList(),
      commandHistory:
          (json['commandHistory'] as List<dynamic>? ?? const <dynamic>[])
              .map((record) =>
                  CommandRecord.fromJson(record as Map<String, dynamic>))
              .toList(),
      reports: (json['reports'] as List<dynamic>)
          .map((report) => TurnReport.fromJson(report as Map<String, dynamic>))
          .toList(),
    );
  }

  OpenDeadlockGame endTurn() {
    final previousWinnerId = winningFactionId;
    if (isGameOver) {
      return this;
    }

    final production = <String, ResourceStockpile>{};
    final updatedColonies = <Colony>[];
    final createdUnits = <Unit>[];
    final newReports = <TurnReport>[];

    for (final faction in factions) {
      production[faction.id] = const ResourceStockpile(
        food: 0,
        industry: 0,
        research: 0,
        credits: 0,
      );
    }

    for (final colony in colonies) {
      final tile = tileAt(colony.x, colony.y);
      final colonyProduction = _colonyProductionFor(colony, tile);

      production[colony.ownerId] =
          production[colony.ownerId]! + colonyProduction.output;

      final buildCost = buildCostFor(colony.construction);
      final industryAfterWork = _storedIndustryAfterRiot(
            colony,
            colonyProduction.riotIndustryLoss,
            buildCost,
          ) +
          colonyProduction.constructionWork;
      final hasCompletedBuild = colonyProduction.willCompleteConstruction;
      final completedBuildings = <String>[
        ...colony.completedBuildings,
      ];
      final isRepeatableUnitBuild =
          isRepeatableConstruction(colony.construction);

      if (hasCompletedBuild &&
          !isRepeatableUnitBuild &&
          !completedBuildings.contains(colony.construction)) {
        completedBuildings.add(colony.construction);
      }
      if (hasCompletedBuild && isRepeatableUnitBuild) {
        final spawnTile = _spawnTileFor(colony, createdUnits);
        if (spawnTile != null) {
          final unitType = unitTypeForConstruction(colony.construction);
          createdUnits.add(
            Unit(
              id: '${colony.id}-$unitType-$turn',
              name: '${colony.name} ${_unitDisplayName(unitType)}',
              ownerId: colony.ownerId,
              type: unitType,
              x: spawnTile.x,
              y: spawnTile.y,
              movesRemaining: maxMovesFor(unitType),
              health: maxHealthFor(unitType),
            ),
          );
        }
      }
      final nextConstruction = hasCompletedBuild && !isRepeatableUnitBuild
          ? _nextConstructionAfterCompletion(
              colony,
              tile,
              completedBuildings,
              factionById(colony.ownerId),
            )
          : colony.construction;

      updatedColonies.add(
        colony.copyWith(
          population: colonyProduction.nextPopulation,
          morale: colonyProduction.nextMorale,
          construction: nextConstruction,
          storedIndustry: hasCompletedBuild
              ? industryAfterWork % buildCost
              : industryAfterWork,
          completedBuildings: completedBuildings,
        ),
      );

      if (hasCompletedBuild) {
        newReports.add(
          TurnReport(
            title: '${colony.name}: ${colony.construction} completed',
            message: _completionMessage(colony.construction, nextConstruction),
          ),
        );
      }
      if (colonyProduction.isStarving) {
        newReports.add(
          TurnReport(
            title: '${colony.name}: food shortage',
            message:
                'Food demand exceeded output by ${-colonyProduction.foodBalance}. '
                'Population changed by ${colonyProduction.populationChange} and morale changed by ${colonyProduction.moraleChange}.',
          ),
        );
      }
      if (colonyProduction.isRioting) {
        newReports.add(
          TurnReport(
            title: '${colony.name}: riots',
            message:
                'Severe unrest destroyed ${colonyProduction.riotIndustryLoss} stored industry. '
                'Build Militia Post or Barracks, lower taxes, or improve food to restore order.',
          ),
        );
      }
      if (colonyProduction.isInUnrest) {
        newReports.add(
          TurnReport(
            title: '${colony.name}: unrest',
            message:
                'Low morale reduced output by 2 industry, 1 research, and 2 credits.',
          ),
        );
      }
    }

    for (final faction in factions) {
      production[faction.id] =
          production[faction.id]! + tradeIncomeFor(faction.id);
    }

    final updatedFactions = <Faction>[];
    for (final faction in factions) {
      final factionWithProduction = faction.copyWith(
        resources: faction.resources + production[faction.id]!,
      );
      updatedFactions.add(
        _advanceResearchForFaction(factionWithProduction, newReports),
      );
    }

    return OpenDeadlockGame(
      sessionId: sessionId,
      turn: turn + 1,
      width: width,
      height: height,
      activeFactionId: activeFactionId,
      victoryCondition: victoryCondition,
      scoreTurnLimit: scoreTurnLimit,
      factions: updatedFactions,
      tiles: _tilesWithAllianceIntelShared(tiles),
      colonies: updatedColonies,
      units: <Unit>[
        ...units.map((unit) => unit.copyWith(
              movesRemaining: maxMovesFor(unit.type),
            )),
        ...createdUnits,
      ],
      diplomacy: diplomacy,
      commandHistory: commandHistory,
      reports: <TurnReport>[
        ...newReports,
        TurnReport(
          title: 'Turn ${turn + 1} begins',
          message: _productionSummary(production[activeFactionId]!),
        ),
        ...reports,
      ],
    )._withVictoryReportIfNeeded(previousWinnerId);
  }

  ColonyProduction _colonyProductionFor(Colony colony, PlanetTile tile) {
    final difficultyAdjustment =
        _difficultyProductionAdjustmentFor(colony.ownerId);
    final focusAdjustment = _focusProductionAdjustmentFor(colony.focus);
    final moraleAdjustment = _moraleProductionAdjustmentFor(colony);
    final taxCreditAdjustment = _taxCreditAdjustmentFor(colony.ownerId);
    final taxMoraleAdjustment = _taxMoraleAdjustmentFor(colony.ownerId);
    final workedTiles = _workedTilesFor(colony, homeTile: tile);
    final workedYields = _combinedYieldsFor(workedTiles);
    final food = _adjustedProduction(
        _foodYieldFor(colony, workedYields),
        difficultyAdjustment.food +
            focusAdjustment.food +
            moraleAdjustment.food);
    final industry = _adjustedProduction(
        _industryYieldFor(colony, workedYields),
        difficultyAdjustment.industry +
            focusAdjustment.industry +
            moraleAdjustment.industry);
    final research = _adjustedProduction(
        _researchYieldFor(colony, workedYields),
        difficultyAdjustment.research +
            focusAdjustment.research +
            moraleAdjustment.research);
    final grossCredits = _adjustedProduction(
        _creditYieldFor(colony),
        difficultyAdjustment.credits +
            focusAdjustment.credits +
            moraleAdjustment.credits +
            taxCreditAdjustment);
    final buildingUpkeep = buildingUpkeepFor(colony);
    final credits = _adjustedProduction(grossCredits, -buildingUpkeep);
    final constructionWork =
        industry + _raceProfileForFactionId(colony.ownerId).constructionBonus;
    final buildCost = buildCostFor(colony.construction);
    final riotIndustryLoss = colonyRiotIndustryLossFor(colony);
    final storedIndustryAfterRiot =
        _storedIndustryAfterRiot(colony, riotIndustryLoss, buildCost);
    final willCompleteConstruction =
        storedIndustryAfterRiot + constructionWork >= buildCost;
    final foodDemand = colony.population + 1;
    final foodBalance = food - foodDemand;
    final housingCapacity = populationCapacityFor(colony);
    final populationChange =
        _populationChangeFor(colony, foodBalance, housingCapacity);
    final moraleChange =
        _moraleChangeFor(foodBalance, willCompleteConstruction) +
            taxMoraleAdjustment;
    final nextPopulation =
        _clampInt(colony.population + populationChange, 1, 99);
    final nextMorale =
        _moraleForFaction(colony.ownerId, colony.morale + moraleChange);

    return ColonyProduction(
      output: ResourceStockpile(
        food: food,
        industry: industry,
        research: research,
        credits: credits,
      ),
      constructionWork: constructionWork,
      foodDemand: foodDemand,
      foodBalance: foodBalance,
      housingCapacity: housingCapacity,
      buildingUpkeep: buildingUpkeep,
      populationChange: populationChange,
      moraleChange: nextMorale - colony.morale,
      nextPopulation: nextPopulation,
      nextMorale: nextMorale,
      willCompleteConstruction: willCompleteConstruction,
      workedSectors: workedTiles.length,
      assignedSectorCapacity: assignedSectorCapacityFor(colony),
      workedYields: workedYields,
      moraleOutputAdjustment: moraleAdjustment,
      riotIndustryLoss: riotIndustryLoss,
    );
  }

  int _storedIndustryAfterRiot(
    Colony colony,
    int riotIndustryLoss,
    int buildCost,
  ) {
    return _clampInt(colony.storedIndustry - riotIndustryLoss, 0, buildCost);
  }

  List<PlanetTile> _workedTilesFor(Colony colony, {PlanetTile? homeTile}) {
    final tiles = <PlanetTile>[
      homeTile ?? tileAt(colony.x, colony.y),
    ];
    final capacity = assignedSectorCapacityFor(colony);
    var assignedWorked = 0;
    for (final assignment in colony.assignedSectors) {
      if (assignedWorked >= capacity ||
          !_isInsideMap(assignment.x, assignment.y)) {
        continue;
      }
      final tile = tileAt(assignment.x, assignment.y);
      if (!_canWorkAssignedSector(colony, tile)) {
        continue;
      }
      tiles.add(tile);
      assignedWorked += 1;
    }
    return tiles;
  }

  bool _canWorkAssignedSector(Colony colony, PlanetTile tile) {
    return tile.ownerId == colony.ownerId &&
        tile.colonyId == null &&
        colonyAt(tile.x, tile.y) == null &&
        isTerrainPassable(tile.terrain) &&
        _manhattanDistance(colony.x, colony.y, tile.x, tile.y) <=
            colonyWorkRange &&
        (tile.x != colony.x || tile.y != colony.y);
  }

  TileYield _combinedYieldsFor(List<PlanetTile> tiles) {
    var food = 0;
    var industry = 0;
    var research = 0;
    for (final tile in tiles) {
      food += tile.yields.food;
      industry += tile.yields.industry;
      research += tile.yields.research;
    }
    return TileYield(food: food, industry: industry, research: research);
  }

  RaceProfile _raceProfileForFactionId(String factionId) {
    final faction = factionById(factionId);
    if (faction == null) {
      return raceProfileForId('human');
    }
    return raceProfileFor(faction);
  }

  bool _isSectorVisibleTo(
    String factionId,
    int x,
    int y,
    Set<String> visitedFactionIds,
  ) {
    if (!visitedFactionIds.add(factionId)) {
      return false;
    }

    final faction = factionById(factionId);
    if (faction == null) {
      return false;
    }
    if (raceProfileFor(faction).revealsMap) {
      return true;
    }

    for (final colony in colonies) {
      if (colony.ownerId == factionId &&
          _manhattanDistance(colony.x, colony.y, x, y) <= colonyVisionRadius) {
        return true;
      }
    }

    for (final unit in units) {
      if (unit.ownerId == factionId &&
          _manhattanDistance(unit.x, unit.y, x, y) <=
              visionRadiusForUnit(unit.type)) {
        return true;
      }
    }

    for (final relation in diplomacy) {
      if (relation.status != diplomacyStatusAlliance) {
        continue;
      }
      final alliedFactionId = relation.factionAId == factionId
          ? relation.factionBId
          : relation.factionBId == factionId
              ? relation.factionAId
              : null;
      if (alliedFactionId != null &&
          _isSectorVisibleTo(alliedFactionId, x, y, visitedFactionIds)) {
        return true;
      }
    }

    return false;
  }

  int _populationChangeFor(
    Colony colony,
    int foodBalance,
    int housingCapacity,
  ) {
    if (foodBalance < 0) {
      return -1;
    }
    if (foodBalance == 0) {
      return 0;
    }
    if (colony.population >= housingCapacity) {
      return 0;
    }
    final growth =
        1 + _raceProfileForFactionId(colony.ownerId).populationGrowthBonus;
    return _clampInt(growth, 0, housingCapacity - colony.population);
  }

  int _moraleChangeFor(int foodBalance, bool willCompleteConstruction) {
    var moraleChange = willCompleteConstruction ? 2 : 0;
    if (foodBalance < 0) {
      moraleChange -= 8;
    }
    return moraleChange;
  }

  int _moraleForFaction(String factionId, int morale) {
    final moraleFloor = _raceProfileForFactionId(factionId).moraleFloor;
    return _clampInt(morale < moraleFloor ? moraleFloor : morale, 0, 100);
  }

  int _startingMoraleForFaction(String factionId) {
    return _moraleForFaction(factionId, 58);
  }

  int _unitAttackFor(Unit unit) {
    return attackFor(unit.type) +
        _raceProfileForFactionId(unit.ownerId).attackBonus;
  }

  int _foodYieldFor(Colony colony, TileYield workedYields) {
    return workedYields.food +
        colony.population +
        (_hasBuilding(colony, 'Farm Dome') ? 3 : 0) +
        (_hasResearch(colony.ownerId, 'Hydroponics') ? 1 : 0) +
        _raceProfileForFactionId(colony.ownerId).foodBonus +
        _traitBonusFor(colony.ownerId, (trait) => trait.foodBonus);
  }

  int _industryYieldFor(Colony colony, TileYield workedYields) {
    return workedYields.industry +
        colony.population +
        (_hasBuilding(colony, 'Factory') ? 3 : 0) +
        (_hasResearch(colony.ownerId, 'Industrial Automation') ? 1 : 0) +
        _raceProfileForFactionId(colony.ownerId).industryBonus +
        _traitBonusFor(colony.ownerId, (trait) => trait.industryBonus);
  }

  int _researchYieldFor(Colony colony, TileYield workedYields) {
    return workedYields.research +
        (colony.population ~/ 2) +
        (_hasBuilding(colony, 'Research Lab') ? 4 : 0) +
        (_hasResearch(colony.ownerId, 'Xenoarchaeology') ? 1 : 0) +
        _raceProfileForFactionId(colony.ownerId).researchBonus +
        _traitBonusFor(colony.ownerId, (trait) => trait.researchBonus);
  }

  int _creditYieldFor(Colony colony) {
    return 2 +
        (colony.morale ~/ 20) +
        (_hasBuilding(colony, 'Colony Hub') ? 2 : 0) +
        _raceProfileForFactionId(colony.ownerId).creditBonus +
        _traitBonusFor(colony.ownerId, (trait) => trait.creditBonus);
  }

  ResourceStockpile _difficultyProductionAdjustmentFor(String factionId) {
    final faction = factionById(factionId);
    if (faction == null || !faction.isComputer) {
      return const ResourceStockpile(
        food: 0,
        industry: 0,
        research: 0,
        credits: 0,
      );
    }
    if (faction.difficulty == Faction.difficultyHard) {
      return const ResourceStockpile(
        food: 0,
        industry: 1,
        research: 1,
        credits: 1,
      );
    }
    if (faction.difficulty == Faction.difficultyEasy) {
      return const ResourceStockpile(
        food: 0,
        industry: -1,
        research: -1,
        credits: -1,
      );
    }
    return const ResourceStockpile(
      food: 0,
      industry: 0,
      research: 0,
      credits: 0,
    );
  }

  ResourceStockpile _focusProductionAdjustmentFor(String focus) {
    if (focus == colonyFocusGrowth) {
      return const ResourceStockpile(
        food: 2,
        industry: -1,
        research: 0,
        credits: 0,
      );
    }
    if (focus == colonyFocusIndustry) {
      return const ResourceStockpile(
        food: -1,
        industry: 2,
        research: 0,
        credits: 0,
      );
    }
    if (focus == colonyFocusResearch) {
      return const ResourceStockpile(
        food: 0,
        industry: -1,
        research: 2,
        credits: 0,
      );
    }
    if (focus == colonyFocusRevenue) {
      return const ResourceStockpile(
        food: 0,
        industry: 0,
        research: -1,
        credits: 3,
      );
    }
    return const ResourceStockpile(
      food: 0,
      industry: 0,
      research: 0,
      credits: 0,
    );
  }

  ResourceStockpile _moraleProductionAdjustmentFor(Colony colony) {
    if (isColonyInUnrest(colony)) {
      return colonyUnrestProductionPenalty;
    }
    return const ResourceStockpile(
      food: 0,
      industry: 0,
      research: 0,
      credits: 0,
    );
  }

  int _taxCreditAdjustmentFor(String factionId) {
    final faction = factionById(factionId);
    if (faction == null || faction.taxPolicy == Faction.taxPolicyBalanced) {
      return 0;
    }
    if (faction.taxPolicy == Faction.taxPolicyRelief) {
      return -2;
    }
    if (faction.taxPolicy == Faction.taxPolicyHigh) {
      return 3;
    }
    if (faction.taxPolicy == Faction.taxPolicyEmergency) {
      return 5;
    }
    return 0;
  }

  int _taxMoraleAdjustmentFor(String factionId) {
    final faction = factionById(factionId);
    if (faction == null || faction.taxPolicy == Faction.taxPolicyBalanced) {
      return 0;
    }
    if (faction.taxPolicy == Faction.taxPolicyRelief) {
      return 2;
    }
    if (faction.taxPolicy == Faction.taxPolicyHigh) {
      return -2;
    }
    if (faction.taxPolicy == Faction.taxPolicyEmergency) {
      return -5;
    }
    return 0;
  }

  int _adjustedProduction(int base, int adjustment) {
    return _clampInt(base + adjustment, 0, 999);
  }

  bool _hasBuilding(Colony colony, String building) {
    return colony.completedBuildings.contains(building);
  }

  bool _hasResearch(String factionId, String researchProject) {
    final faction = factionById(factionId);
    return faction != null &&
        faction.completedResearch.contains(researchProject);
  }

  List<PlanetTile> _tilesWithAllianceIntelShared(List<PlanetTile> sourceTiles) {
    var updatedTiles = sourceTiles;
    for (final relation in diplomacy) {
      if (relation.status != diplomacyStatusAlliance) {
        continue;
      }
      updatedTiles = _shareAllianceIntelBetween(
        updatedTiles,
        relation.factionAId,
        relation.factionBId,
      );
    }
    return updatedTiles;
  }

  List<PlanetTile> _shareAllianceIntelBetween(
    List<PlanetTile> sourceTiles,
    String factionId,
    String targetFactionId,
  ) {
    return sourceTiles.map((tile) {
      final factionKnows = tile.isExploredBy(factionId);
      final targetKnows = tile.isExploredBy(targetFactionId);
      if (!factionKnows && !targetKnows) {
        return tile;
      }

      var updatedTile = tile;
      if (!factionKnows) {
        updatedTile = _revealTileTo(updatedTile, factionId);
      }
      if (!targetKnows) {
        updatedTile = _revealTileTo(updatedTile, targetFactionId);
      }
      return updatedTile;
    }).toList(growable: false);
  }

  PlanetTile _revealTileTo(PlanetTile tile, String factionId) {
    if (tile.isExploredBy(factionId)) {
      return tile;
    }
    return tile.revealTo(factionId);
  }

  _IntelScanTarget? _intelScanTargetFor(
    String factionId,
    String targetFactionId,
  ) {
    if (factionById(factionId) == null) {
      throw ArgumentError('Unknown faction: $factionId.');
    }
    if (factionById(targetFactionId) == null) {
      throw ArgumentError('Unknown faction: $targetFactionId.');
    }
    if (factionId == targetFactionId) {
      throw ArgumentError('A faction cannot scan itself.');
    }

    final candidateColonies = colonies
        .where((colony) => colony.ownerId == targetFactionId)
        .toList(growable: false);
    if (candidateColonies.isEmpty) {
      return null;
    }

    final sortedColonies = candidateColonies.toList();
    sortedColonies.sort((a, b) {
      final aVisible = tileAt(a.x, a.y).isExploredBy(factionId);
      final bVisible = tileAt(b.x, b.y).isExploredBy(factionId);
      if (aVisible != bVisible) {
        return aVisible ? 1 : -1;
      }
      final yComparison = a.y.compareTo(b.y);
      if (yComparison != 0) {
        return yComparison;
      }
      return a.x.compareTo(b.x);
    });

    for (final colony in sortedColonies) {
      final revealableTiles = _intelScanTilesAround(colony, factionId);
      if (revealableTiles.isNotEmpty) {
        return _IntelScanTarget(
          colony: colony,
          tiles: revealableTiles,
        );
      }
    }
    return null;
  }

  List<PlanetTile> _intelScanTilesAround(Colony colony, String factionId) {
    final revealableTiles = <PlanetTile>[];
    for (var y = colony.y - intelScanRadius;
        y <= colony.y + intelScanRadius;
        y += 1) {
      for (var x = colony.x - intelScanRadius;
          x <= colony.x + intelScanRadius;
          x += 1) {
        if (!_isInsideMap(x, y) ||
            _manhattanDistance(colony.x, colony.y, x, y) > intelScanRadius) {
          continue;
        }
        final tile = tileAt(x, y);
        if (!tile.isExploredBy(factionId)) {
          revealableTiles.add(tile);
        }
      }
    }
    return revealableTiles;
  }

  int _sabotageDamageFor(Colony colony) {
    final damage = _clampInt(
      sabotageIndustryDamage - sabotageProtectionForColony(colony),
      0,
      sabotageIndustryDamage,
    );
    return _clampInt(colony.storedIndustry, 0, damage);
  }

  bool _containsTile(List<PlanetTile> candidates, int x, int y) {
    for (final tile in candidates) {
      if (tile.x == x && tile.y == y) {
        return true;
      }
    }
    return false;
  }

  int _traitBonusFor(
    String factionId,
    int Function(FactionTrait trait) bonusForTrait,
  ) {
    final faction = factionById(factionId);
    if (faction == null) {
      return 0;
    }

    var total = 0;
    for (final trait in traitsFor(faction)) {
      total += bonusForTrait(trait);
    }
    return total;
  }

  void _validateColonySectorAssignment(
    Colony colony,
    int x,
    int y, {
    String? factionId,
  }) {
    if (factionId != null && colony.ownerId != factionId) {
      throw ArgumentError(
          'Faction $factionId does not control colony ${colony.id}.');
    }
    if (!_isInsideMap(x, y)) {
      throw ArgumentError('Sector is outside the map: $x, $y.');
    }
    if (x == colony.x && y == colony.y) {
      throw ArgumentError('${colony.name} already works its colony sector.');
    }

    final tile = tileAt(x, y);
    if (!isTerrainPassable(tile.terrain)) {
      throw ArgumentError('Colonies cannot work blocked terrain.');
    }
    if (tile.ownerId != colony.ownerId) {
      throw ArgumentError(
          '${colony.name} can only work sectors controlled by ${colony.ownerId}.');
    }
    if (tile.colonyId != null || colonyAt(x, y) != null) {
      throw ArgumentError(
          'A colony sector cannot be assigned as an outlying sector.');
    }
    if (_manhattanDistance(colony.x, colony.y, x, y) > colonyWorkRange) {
      throw ArgumentError(
          'Sector ${x + 1}, ${y + 1} is outside ${colony.name} work range.');
    }

    final assignedColony = assignedColonyForSector(x, y);
    if (assignedColony != null && assignedColony.id != colony.id) {
      throw ArgumentError(
          'Sector ${x + 1}, ${y + 1} is already assigned to ${assignedColony.name}.');
    }
    if (assignedColony == null &&
        colony.assignedSectors.length >= assignedSectorCapacityFor(colony)) {
      throw ArgumentError(
          '${colony.name} needs more population to work another sector.');
    }
  }

  Faction _advanceResearchForFaction(
    Faction faction,
    List<TurnReport> newReports,
  ) {
    var project = faction.researchProject;
    var completedResearch = <String>[
      ...faction.completedResearch,
    ];
    var resources = faction.resources;

    if (!researchOptions.contains(project) ||
        (completedResearch.contains(project) &&
            !isRepeatableResearch(project))) {
      project = _nextResearchProjectFor(faction);
    }

    final researchCost = researchCostFor(project);
    if (resources.research < researchCost) {
      return faction.copyWith(researchProject: project);
    }

    resources = resources.copyWith(research: resources.research - researchCost);
    if (isRepeatableResearch(project)) {
      resources = resources.copyWith(credits: resources.credits + 8);
    } else {
      completedResearch.add(project);
    }

    final completedFaction = faction.copyWith(
      resources: resources,
      completedResearch: completedResearch,
    );
    final nextProject = _nextResearchProjectFor(completedFaction);
    newReports.add(
      TurnReport(
        title: '${faction.name}: $project researched',
        message: _researchCompletionMessage(project, nextProject),
      ),
    );

    return completedFaction.copyWith(researchProject: nextProject);
  }

  PlanetTile? _spawnTileFor(Colony colony, List<Unit> createdUnits) {
    final offsets = const <List<int>>[
      <int>[0, 0],
      <int>[0, -1],
      <int>[1, 0],
      <int>[0, 1],
      <int>[-1, 0],
    ];

    for (final offset in offsets) {
      final x = colony.x + offset[0];
      final y = colony.y + offset[1];
      if (!_isInsideMap(x, y)) {
        continue;
      }
      final tile = tileAt(x, y);
      if (tile.terrain == 'water' || tile.ownerId != colony.ownerId) {
        continue;
      }
      if (unitAt(x, y) != null || _createdUnitAt(createdUnits, x, y) != null) {
        continue;
      }
      return tile;
    }
    return null;
  }

  Unit? _createdUnitAt(List<Unit> createdUnits, int x, int y) {
    for (final unit in createdUnits) {
      if (unit.x == x && unit.y == y) {
        return unit;
      }
    }
    return null;
  }

  String _completionMessage(String construction, String nextConstruction) {
    final nextProjectMessage = isRepeatableConstruction(construction)
        ? ''
        : ' Next project queued: $nextConstruction.';
    if (construction == 'Farm Dome') {
      return 'Food production increased.$nextProjectMessage';
    }
    if (construction == 'Factory') {
      return 'Industrial output increased.$nextProjectMessage';
    }
    if (construction == 'Research Lab') {
      return 'Research output increased.$nextProjectMessage';
    }
    if (residentialCapacityBonuses.containsKey(construction)) {
      return 'Population capacity increased.$nextProjectMessage';
    }
    if (construction == 'Scout Patrol') {
      return 'A new scout patrol is ready for orders.';
    }
    if (construction == 'Infantry Company') {
      return 'An infantry company is ready for deployment.';
    }
    if (construction == 'Armor Company') {
      return 'An armor company is ready for deployment.';
    }
    if (construction == 'Militia Post' || construction == 'Barracks') {
      return 'Local defenses improved.$nextProjectMessage';
    }
    return 'The colony completed a build order and gained morale.$nextProjectMessage';
  }

  static String _unitDisplayName(String unitType) {
    if (unitType == 'scout') {
      return 'Scout';
    }
    if (unitType == 'infantry') {
      return 'Infantry';
    }
    if (unitType == 'armor') {
      return 'Armor';
    }
    return 'Unit';
  }

  static String _nextResearchProjectFor(Faction faction) {
    for (final researchProject in researchOptions) {
      if (!isCompletedResearch(faction, researchProject)) {
        return researchProject;
      }
    }
    return 'Future Studies';
  }

  static String _preferredResearchFor(Faction faction) {
    for (final researchProject in _personalityResearchPrioritiesFor(faction)) {
      if (!isCompletedResearch(faction, researchProject)) {
        return researchProject;
      }
    }
    final racePreferredResearch = raceProfileFor(faction).preferredResearch;
    if (racePreferredResearch != null &&
        !isCompletedResearch(faction, racePreferredResearch)) {
      return racePreferredResearch;
    }
    for (final trait in traitsFor(faction)) {
      final preferredResearch = trait.preferredResearch;
      if (preferredResearch != null &&
          !isCompletedResearch(faction, preferredResearch)) {
        return preferredResearch;
      }
    }
    return _nextResearchProjectFor(faction);
  }

  String _preferredResearchForFaction(Faction faction) {
    if (!isCompletedResearch(faction, 'Defense Grid') &&
        _hasSabotageExposedColony(faction.id)) {
      return 'Defense Grid';
    }
    return _preferredResearchFor(faction);
  }

  bool _hasSabotageExposedColony(String factionId) {
    for (final colony in colonies) {
      if (colony.ownerId == factionId && _isColonySabotageExposed(colony)) {
        return true;
      }
    }
    return false;
  }

  static List<String> _personalityResearchPrioritiesFor(Faction faction) {
    if (faction.aiPersonality == Faction.aiPersonalityConqueror) {
      return const <String>['Defense Grid', 'Industrial Automation'];
    }
    if (faction.aiPersonality == Faction.aiPersonalityExpansionist) {
      return const <String>['Hydroponics', 'Industrial Automation'];
    }
    if (faction.aiPersonality == Faction.aiPersonalityResearcher) {
      return const <String>['Xenoarchaeology', 'Industrial Automation'];
    }
    if (faction.aiPersonality == Faction.aiPersonalityTrader) {
      return const <String>[
        'Hydroponics',
        'Industrial Automation',
        'Future Studies',
      ];
    }
    return const <String>[];
  }

  static String _researchCompletionMessage(
    String researchProject,
    String nextProject,
  ) {
    final nextProjectMessage = isRepeatableResearch(researchProject)
        ? ''
        : ' Next project queued: $nextProject.';
    if (researchProject == 'Hydroponics') {
      return 'Colony food output increased.$nextProjectMessage';
    }
    if (researchProject == 'Industrial Automation') {
      return 'Colony industrial output increased.$nextProjectMessage';
    }
    if (researchProject == 'Xenoarchaeology') {
      return 'Colony research output increased.$nextProjectMessage';
    }
    if (researchProject == 'Defense Grid') {
      return 'Controlled colonies gained defensive networks.$nextProjectMessage';
    }
    if (researchProject == 'Future Studies') {
      return 'Research was converted into additional budget reserves.';
    }
    return 'Research completed.$nextProjectMessage';
  }

  static String _preferredConstructionFor(
    Colony colony,
    PlanetTile tile,
    Faction? faction, {
    bool isThreatened = false,
    bool isSabotageExposed = false,
  }) {
    final candidates = <String>[];
    if (isColonyRioting(colony)) {
      candidates.addAll(colonyRiotSuppressionBuildings);
    }
    if (isSabotageExposed) {
      candidates.addAll(const <String>[
        'Militia Post',
        'Barracks',
      ]);
    }
    if (isThreatened) {
      candidates.addAll(const <String>[
        'Militia Post',
        'Barracks',
        'Infantry Company',
        'Armor Company',
      ]);
    }
    if (colony.population >= populationCapacityFor(colony)) {
      final residentialConstruction = _nextResidentialConstructionFor(colony);
      if (residentialConstruction != null) {
        candidates.add(residentialConstruction);
      }
    }
    if (faction != null) {
      candidates.addAll(_personalityConstructionPrioritiesFor(faction));
      final racePreferredConstruction =
          raceProfileFor(faction).preferredConstruction;
      if (racePreferredConstruction != null) {
        candidates.add(racePreferredConstruction);
        if (racePreferredConstruction == 'Barracks') {
          candidates.add('Armor Company');
          candidates.add('Infantry Company');
        }
      }
      for (final trait in traitsFor(faction)) {
        final preferredConstruction = trait.preferredConstruction;
        if (preferredConstruction != null) {
          candidates.add(preferredConstruction);
          if (preferredConstruction == 'Militia Post') {
            candidates.add('Barracks');
            candidates.add('Armor Company');
            candidates.add('Infantry Company');
          }
        }
      }
    }
    if (tile.yields.research >= 2) {
      candidates.add('Research Lab');
    }
    if (tile.yields.industry >= 3 || colony.population >= 6) {
      candidates.add('Factory');
    }
    if (tile.yields.food >= 3 || colony.population <= 4) {
      candidates.add('Farm Dome');
    }
    candidates.addAll(const <String>[
      'Militia Post',
      'Barracks',
      'Armor Company',
      'Infantry Company',
      'Colony Hub',
      'Housing',
      'Apartment Complex',
      'Luxury Housing',
      'Scout Patrol',
    ]);

    for (final construction in candidates) {
      if (!isCompletedConstruction(colony, construction) &&
          isConstructionAvailableFor(colony, construction)) {
        return construction;
      }
    }
    return 'Scout Patrol';
  }

  static String? _nextResidentialConstructionFor(Colony colony) {
    for (final construction in residentialCapacityBonuses.keys) {
      if (!isCompletedConstruction(colony, construction) &&
          isConstructionAvailableFor(colony, construction)) {
        return construction;
      }
    }
    return null;
  }

  static List<String> _personalityConstructionPrioritiesFor(Faction faction) {
    if (faction.aiPersonality == Faction.aiPersonalityConqueror) {
      return const <String>[
        'Barracks',
        'Infantry Company',
        'Factory',
        'Armor Company',
        'Militia Post',
      ];
    }
    if (faction.aiPersonality == Faction.aiPersonalityExpansionist) {
      return const <String>['Scout Patrol', 'Colony Hub', 'Farm Dome'];
    }
    if (faction.aiPersonality == Faction.aiPersonalityResearcher) {
      return const <String>['Research Lab', 'Factory'];
    }
    if (faction.aiPersonality == Faction.aiPersonalityTrader) {
      return const <String>['Farm Dome', 'Factory', 'Scout Patrol'];
    }
    return const <String>[];
  }

  static String _nextConstructionAfterCompletion(
    Colony colony,
    PlanetTile tile,
    List<String> completedBuildings,
    Faction? faction,
  ) {
    return _preferredConstructionFor(
      colony.copyWith(completedBuildings: completedBuildings),
      tile,
      faction,
    );
  }

  bool _isColonyThreatened(Colony colony) {
    for (final unit in units) {
      if (unit.ownerId == colony.ownerId ||
          !areAtWar(colony.ownerId, unit.ownerId)) {
        continue;
      }
      if (!isUnitVisibleTo(colony.ownerId, unit)) {
        continue;
      }
      if (_manhattanDistance(colony.x, colony.y, unit.x, unit.y) <= 2) {
        return true;
      }
    }
    return false;
  }

  bool _isColonySabotageExposed(Colony colony) {
    if (colony.storedIndustry <= 0 || sabotageDamageForColony(colony) <= 0) {
      return false;
    }

    final colonyTile = tileAt(colony.x, colony.y);
    for (final faction in factions) {
      if (faction.id == colony.ownerId ||
          !areAtWar(colony.ownerId, faction.id) ||
          !_factionCanTakeTurn(faction.id)) {
        continue;
      }
      if (colonyTile.isExploredBy(faction.id)) {
        return true;
      }
    }
    return false;
  }

  String _preferredFocusFor(Colony colony, Faction faction) {
    final projection = colonyProductionFor(colony);
    if (projection.foodBalance < 0) {
      return colonyFocusGrowth;
    }

    if (faction.aiPersonality == Faction.aiPersonalityExpansionist &&
        colony.population < 6) {
      return colonyFocusGrowth;
    }
    if (faction.aiPersonality == Faction.aiPersonalityTrader &&
        faction.resources.credits < 20) {
      return colonyFocusRevenue;
    }
    final raceProfile = raceProfileFor(faction);
    if (raceProfile.populationGrowthBonus > 0 &&
        projection.foodBalance > 0 &&
        colony.population < projection.housingCapacity) {
      return colonyFocusGrowth;
    }

    final remainingIndustry =
        buildCostFor(colony.construction) - colony.storedIndustry;
    if (remainingIndustry > projection.constructionWork &&
        !projection.willCompleteConstruction) {
      return colonyFocusIndustry;
    }

    final researchProject = faction.researchProject;
    if (researchOptions.contains(researchProject) &&
        !isCompletedResearch(faction, researchProject)) {
      final remainingResearch =
          researchCostFor(researchProject) - faction.resources.research;
      if (remainingResearch > projection.output.research ||
          faction.aiPersonality == Faction.aiPersonalityResearcher) {
        return colonyFocusResearch;
      }
    }

    if (faction.traitIds.contains('traders') || faction.resources.credits < 8) {
      return colonyFocusRevenue;
    }
    return colonyFocusBalanced;
  }

  String _preferredTaxPolicyFor(Faction faction) {
    final lowestMorale = _lowestColonyMoraleFor(faction.id);
    if (lowestMorale < 38) {
      return Faction.taxPolicyRelief;
    }
    if (faction.aiPersonality == Faction.aiPersonalityTrader &&
        lowestMorale < 68 &&
        faction.resources.credits >= 12) {
      return Faction.taxPolicyRelief;
    }
    if (faction.resources.credits < 6) {
      return Faction.taxPolicyHigh;
    }
    if (faction.resources.credits > 32 && lowestMorale < 64) {
      return Faction.taxPolicyRelief;
    }
    return Faction.taxPolicyBalanced;
  }

  List<SetDiplomacyStatusCommand> _preferredDiplomacyCommandsFor(
      Faction faction) {
    final lowestMorale = _lowestColonyMoraleFor(faction.id);
    final isUnderPressure = faction.resources.credits < 6 || lowestMorale < 35;
    final wantsTrade = faction.aiPersonality == Faction.aiPersonalityTrader &&
        faction.resources.credits < 24;

    final ownColonies = _ownedColonyCount(faction.id);
    final ownUnits = _ownedUnitCount(faction.id);
    final ownCombatUnits = _ownedCombatUnitCount(faction.id);
    final ownStrength = militaryStrengthFor(faction.id);
    final commands = <SetDiplomacyStatusCommand>[];
    for (final otherFaction in factions) {
      if (otherFaction.id == faction.id ||
          !_factionCanTakeTurn(otherFaction.id)) {
        continue;
      }
      final otherColonies = _ownedColonyCount(otherFaction.id);
      final otherUnits = _ownedUnitCount(otherFaction.id);
      final otherCombatUnits = _ownedCombatUnitCount(otherFaction.id);
      final status = diplomacyStatusBetween(faction.id, otherFaction.id);
      if ((isUnderPressure || wantsTrade) &&
          status == diplomacyStatusWar &&
          (wantsTrade ||
              otherColonies > ownColonies ||
              otherUnits >= ownUnits)) {
        commands.add(
          SetDiplomacyStatusCommand(
            factionId: faction.id,
            targetFactionId: otherFaction.id,
            status: diplomacyStatusPeace,
          ),
        );
      } else if (wantsTrade &&
          status == diplomacyStatusPeace &&
          ownColonies >= otherColonies) {
        commands.add(
          SetDiplomacyStatusCommand(
            factionId: faction.id,
            targetFactionId: otherFaction.id,
            status: diplomacyStatusAlliance,
          ),
        );
      } else if (!isUnderPressure &&
          status != diplomacyStatusWar &&
          _isAggressiveFaction(faction) &&
          ownColonies >= otherColonies &&
          ownUnits > otherUnits &&
          ownCombatUnits > otherCombatUnits &&
          ownStrength >=
              militaryStrengthFor(otherFaction.id) +
                  _warStrengthMarginFor(faction)) {
        commands.add(
          SetDiplomacyStatusCommand(
            factionId: faction.id,
            targetFactionId: otherFaction.id,
            status: diplomacyStatusWar,
          ),
        );
      }
    }
    return commands;
  }

  ScanFactionIntelCommand? _preferredIntelScanCommandFor(String factionId) {
    final faction = factionById(factionId);
    if (faction == null ||
        faction.resources.credits < intelScanCreditCost ||
        _hasKnownWartimeTargetFor(factionId)) {
      return null;
    }

    final candidates = <ScanFactionIntelCommand>[];
    for (final otherFaction in factions) {
      if (otherFaction.id == factionId ||
          !_factionCanTakeTurn(otherFaction.id) ||
          !areAtWar(factionId, otherFaction.id) ||
          intelScanRevealableSectorCountFor(factionId, otherFaction.id) <= 0) {
        continue;
      }
      candidates.add(
        ScanFactionIntelCommand(
          factionId: factionId,
          targetFactionId: otherFaction.id,
        ),
      );
    }
    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((a, b) {
      final revealComparison = intelScanRevealableSectorCountFor(
        a.factionId,
        b.targetFactionId,
      ).compareTo(
        intelScanRevealableSectorCountFor(
          a.factionId,
          a.targetFactionId,
        ),
      );
      if (revealComparison != 0) {
        return revealComparison;
      }
      return a.targetFactionId.compareTo(b.targetFactionId);
    });
    return candidates.first;
  }

  SabotageColonyCommand? _preferredSabotageCommandFor(Faction faction) {
    final planningFaction = factionById(faction.id);
    if (planningFaction == null ||
        !_isAggressiveFaction(planningFaction) ||
        planningFaction.resources.credits < sabotageCreditCost) {
      return null;
    }

    final candidates = <SabotageColonyCommand>[];
    for (final otherFaction in factions) {
      if (otherFaction.id == planningFaction.id ||
          !_factionCanTakeTurn(otherFaction.id) ||
          !areAtWar(planningFaction.id, otherFaction.id)) {
        continue;
      }
      final target = sabotageTargetFor(planningFaction.id, otherFaction.id);
      if (target == null || target.damage <= 0) {
        continue;
      }
      candidates.add(
        SabotageColonyCommand(
          factionId: planningFaction.id,
          targetFactionId: otherFaction.id,
        ),
      );
    }
    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((a, b) {
      final aTarget = sabotageTargetFor(a.factionId, a.targetFactionId)!;
      final bTarget = sabotageTargetFor(b.factionId, b.targetFactionId)!;
      final damageComparison = bTarget.damage.compareTo(aTarget.damage);
      if (damageComparison != 0) {
        return damageComparison;
      }
      return a.targetFactionId.compareTo(b.targetFactionId);
    });
    return candidates.first;
  }

  bool _hasKnownWartimeTargetFor(String factionId) {
    for (final colony in colonies) {
      if (colony.ownerId == factionId || !areAtWar(factionId, colony.ownerId)) {
        continue;
      }
      if (tileAt(colony.x, colony.y).isExploredBy(factionId)) {
        return true;
      }
    }
    for (final unit in units) {
      if (unit.ownerId == factionId || !areAtWar(factionId, unit.ownerId)) {
        continue;
      }
      if (isUnitVisibleTo(factionId, unit)) {
        return true;
      }
    }
    return false;
  }

  bool _isAggressiveFaction(Faction faction) {
    return faction.aiPersonality == Faction.aiPersonalityConqueror ||
        faction.traitIds.contains('militarists') ||
        raceProfileFor(faction).attackBonus > 0;
  }

  int _warStrengthMarginFor(Faction faction) {
    if (faction.aiPersonality == Faction.aiPersonalityConqueror) {
      return 4;
    }
    return 8;
  }

  int _lowestColonyMoraleFor(String factionId) {
    var lowestMorale = 100;
    for (final colony in colonies) {
      if (colony.ownerId == factionId && colony.morale < lowestMorale) {
        lowestMorale = colony.morale;
      }
    }
    return lowestMorale;
  }

  int _ownedColonyCount(String factionId) {
    var count = 0;
    for (final colony in colonies) {
      if (colony.ownerId == factionId) {
        count += 1;
      }
    }
    return count;
  }

  int _ownedUnitCount(String factionId) {
    var count = 0;
    for (final unit in units) {
      if (unit.ownerId == factionId) {
        count += 1;
      }
    }
    return count;
  }

  int _ownedCombatUnitCount(String factionId) {
    var count = 0;
    for (final unit in units) {
      if (unit.ownerId == factionId && unit.type != 'scout') {
        count += 1;
      }
    }
    return count;
  }

  PlanetTile? _preferredAssignableSectorFor(Colony colony) {
    final candidates = preferredAssignableSectorsFor(colony, limit: 1);
    return candidates.isEmpty ? null : candidates.first;
  }

  int _sectorWorkScoreFor(Colony colony, PlanetTile tile) {
    var score =
        (tile.yields.food + tile.yields.industry + tile.yields.research) * 4;
    if (colony.construction == 'Farm Dome') {
      score += tile.yields.food * 3;
    } else if (colony.construction == 'Factory' ||
        colony.construction == 'Barracks' ||
        colony.construction == 'Infantry Company') {
      score += tile.yields.industry * 3;
    } else if (colony.construction == 'Research Lab') {
      score += tile.yields.research * 3;
    }
    if (colony.focus == colonyFocusGrowth) {
      score += tile.yields.food * 4;
    } else if (colony.focus == colonyFocusIndustry) {
      score += tile.yields.industry * 4;
    } else if (colony.focus == colonyFocusResearch) {
      score += tile.yields.research * 4;
    }
    final faction = factionById(colony.ownerId);
    if (faction != null) {
      if (faction.aiPersonality == Faction.aiPersonalityExpansionist) {
        score += tile.yields.food * 3;
      } else if (faction.aiPersonality == Faction.aiPersonalityConqueror) {
        score += tile.yields.industry * 3;
      } else if (faction.aiPersonality == Faction.aiPersonalityResearcher) {
        score += tile.yields.research * 3;
      } else if (faction.aiPersonality == Faction.aiPersonalityTrader) {
        score += (tile.yields.food + tile.yields.industry) * 2;
      }
      if (faction.researchProject == 'Hydroponics') {
        score += tile.yields.food * 2;
      } else if (faction.researchProject == 'Industrial Automation') {
        score += tile.yields.industry * 2;
      } else if (faction.researchProject == 'Xenoarchaeology') {
        score += tile.yields.research * 2;
      }
    }
    score -= _manhattanDistance(colony.x, colony.y, tile.x, tile.y);
    return score;
  }

  PlanetTile? _preferredTacticalTargetFor(Unit unit) {
    final attackTarget = _preferredAttackFor(unit);
    final colonyAssaultTarget = _preferredColonyAssaultFor(unit);
    if (attackTarget == null) {
      return colonyAssaultTarget;
    }
    if (colonyAssaultTarget == null) {
      return attackTarget;
    }

    final attackScore = _unitAttackTacticalScoreFor(unit, attackTarget);
    final assaultScore =
        _colonyAssaultTacticalScoreFor(unit, colonyAssaultTarget);
    if (assaultScore > attackScore) {
      return colonyAssaultTarget;
    }
    return attackTarget;
  }

  PlanetTile? _preferredAttackFor(Unit unit) {
    final candidates = <PlanetTile>[];
    final offsets = const <List<int>>[
      <int>[0, -1],
      <int>[1, 0],
      <int>[0, 1],
      <int>[-1, 0],
    ];

    for (final offset in offsets) {
      final x = unit.x + offset[0];
      final y = unit.y + offset[1];
      if (!_isInsideMap(x, y)) {
        continue;
      }
      final targetUnit = visibleUnitAt(unit.ownerId, x, y);
      if (targetUnit == null || targetUnit.ownerId == unit.ownerId) {
        continue;
      }
      if (!areAtWar(unit.ownerId, targetUnit.ownerId)) {
        continue;
      }
      final tile = tileAt(x, y);
      if (!_canUnitEnterTile(unit, tile)) {
        continue;
      }
      if (!_shouldPlanAttack(unit, tile)) {
        continue;
      }
      final tileOwnerId = tile.ownerId;
      if (tile.colonyId != null &&
          tileOwnerId != null &&
          tileOwnerId != unit.ownerId &&
          !areAtWar(unit.ownerId, tileOwnerId)) {
        continue;
      }
      candidates.add(tile);
    }

    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((a, b) {
      final scoreComparison =
          _unitAttackScoreFor(unit, b).compareTo(_unitAttackScoreFor(unit, a));
      if (scoreComparison != 0) {
        return scoreComparison;
      }
      final aUnit = visibleUnitAt(unit.ownerId, a.x, a.y)!;
      final bUnit = visibleUnitAt(unit.ownerId, b.x, b.y)!;
      final valueComparison =
          _unitCombatValue(bUnit).compareTo(_unitCombatValue(aUnit));
      if (valueComparison != 0) {
        return valueComparison;
      }
      final healthComparison = aUnit.health.compareTo(bUnit.health);
      if (healthComparison != 0) {
        return healthComparison;
      }
      final yComparison = a.y.compareTo(b.y);
      return yComparison == 0 ? a.x.compareTo(b.x) : yComparison;
    });
    return candidates.first;
  }

  bool _shouldPlanAttack(Unit attacker, PlanetTile targetTile) {
    final defender =
        visibleUnitAt(attacker.ownerId, targetTile.x, targetTile.y);
    if (defender == null) {
      return false;
    }
    final preview = previewUnitCombat(attacker, defender);
    if (!preview.attackerSurvives) {
      if (!preview.defenderSurvives) {
        final valueMargin =
            _unitCombatValue(defender) - _unitCombatValue(attacker);
        return valueMargin >= _sacrificeValueMarginFor(attacker);
      }
      return false;
    }
    if (!preview.defenderSurvives) {
      return true;
    }

    final lowHealthAfterExchange = preview.attackerHealth <= 1 ||
        (preview.attackerHealth * 3) <= maxHealthFor(attacker.type);
    if (!lowHealthAfterExchange) {
      return true;
    }
    return _isBoldCombatant(attacker) &&
        preview.attackDamage >= preview.counterDamage;
  }

  bool _isBoldCombatant(Unit unit) {
    final faction = factionById(unit.ownerId);
    if (faction == null) {
      return false;
    }
    if (faction.difficulty == Faction.difficultyEasy) {
      return false;
    }
    if (faction.difficulty == Faction.difficultyHard) {
      return true;
    }
    return faction.aiPersonality == Faction.aiPersonalityConqueror ||
        faction.traitIds.contains('militarists') ||
        raceProfileFor(faction).attackBonus > 0;
  }

  int _sacrificeValueMarginFor(Unit unit) {
    final faction = factionById(unit.ownerId);
    if (faction != null && faction.difficulty == Faction.difficultyEasy) {
      return 8;
    }
    if (faction != null && faction.difficulty == Faction.difficultyHard) {
      return 0;
    }
    return _isBoldCombatant(unit) ? 0 : 4;
  }

  int _unitAttackScoreFor(Unit attacker, PlanetTile targetTile) {
    final defender = visibleUnitAt(
      attacker.ownerId,
      targetTile.x,
      targetTile.y,
    )!;
    final preview = previewUnitCombat(attacker, defender);
    final targetValue = _unitCombatValue(defender);
    var score = preview.attackDamage * 8;
    score -= preview.counterDamage * 5;
    if (preview.defenderSurvives) {
      score -= preview.defenderHealth * 2;
    } else {
      score += 80 + (targetValue * 4);
    }
    if (preview.attackerSurvives) {
      score += preview.attackerHealth * 2;
    } else {
      score -= 30;
    }
    return score;
  }

  int _unitAttackTacticalScoreFor(Unit attacker, PlanetTile targetTile) {
    final preview = previewUnitCombat(
      attacker,
      visibleUnitAt(attacker.ownerId, targetTile.x, targetTile.y)!,
    );
    var score = _unitAttackScoreFor(attacker, targetTile);
    if (!preview.defenderSurvives) {
      score += 40;
    }
    if (preview.attackerSurvives) {
      score += 20;
    }
    return score;
  }

  int _unitCombatValue(Unit unit) {
    return _unitAttackFor(unit) +
        defenseFor(unit.type) +
        maxHealthFor(unit.type);
  }

  PlanetTile? _preferredColonyAssaultFor(Unit unit) {
    final candidates = <PlanetTile>[];
    final offsets = const <List<int>>[
      <int>[0, -1],
      <int>[1, 0],
      <int>[0, 1],
      <int>[-1, 0],
    ];

    for (final offset in offsets) {
      final x = unit.x + offset[0];
      final y = unit.y + offset[1];
      if (!_isInsideMap(x, y) || visibleUnitAt(unit.ownerId, x, y) != null) {
        continue;
      }
      final colony = colonyAt(x, y);
      if (colony == null || colony.ownerId == unit.ownerId) {
        continue;
      }
      if (!areAtWar(unit.ownerId, colony.ownerId)) {
        continue;
      }
      final tile = tileAt(x, y);
      if (!_canUnitEnterTile(unit, tile)) {
        continue;
      }
      final preview = previewColonyAssault(unit, colony);
      if (!_shouldPlanColonyAssault(unit, colony, preview)) {
        continue;
      }
      candidates.add(tile);
    }

    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((a, b) {
      final scoreComparison = _colonyAssaultScoreFor(unit, b)
          .compareTo(_colonyAssaultScoreFor(unit, a));
      if (scoreComparison != 0) {
        return scoreComparison;
      }
      final aDefense = colonyDefenseFor(colonyAt(a.x, a.y)!);
      final bDefense = colonyDefenseFor(colonyAt(b.x, b.y)!);
      final defenseComparison = bDefense.compareTo(aDefense);
      if (defenseComparison != 0) {
        return defenseComparison;
      }
      final yComparison = a.y.compareTo(b.y);
      return yComparison == 0 ? a.x.compareTo(b.x) : yComparison;
    });
    return candidates.first;
  }

  bool _shouldPlanColonyAssault(
    Unit attacker,
    Colony colony,
    ColonyAssaultPreview preview,
  ) {
    if (preview.colonyCaptured) {
      return true;
    }
    if (!preview.attackerSurvives) {
      return false;
    }

    final moraleDamage = colony.morale - preview.morale;
    final populationDamage = colony.population - preview.population;
    final healthyAfterAssault =
        (preview.attackerHealth * 2) >= maxHealthFor(attacker.type);
    if (!healthyAfterAssault) {
      return false;
    }

    return populationDamage > 0 || moraleDamage >= 25;
  }

  int _colonyAssaultScoreFor(Unit attacker, PlanetTile targetTile) {
    final colony = colonyAt(targetTile.x, targetTile.y)!;
    final preview = previewColonyAssault(attacker, colony);
    var score = 100;
    if (preview.colonyCaptured) {
      score += 120;
    } else {
      score += (colony.morale - preview.morale) * 2;
      score += (colony.population - preview.population) * 40;
    }
    score += colonyDefenseFor(colony) * 5;
    score += colony.population * 8;
    score += preview.attackerHealth * 4;
    score -= preview.counterDamage * 5;
    return score;
  }

  int _colonyAssaultTacticalScoreFor(Unit attacker, PlanetTile targetTile) {
    final colony = colonyAt(targetTile.x, targetTile.y)!;
    final preview = previewColonyAssault(attacker, colony);
    var score = _colonyAssaultScoreFor(attacker, targetTile);
    if (preview.colonyCaptured) {
      score += 80;
    } else {
      score -= 50;
    }
    if (preview.attackerSurvives) {
      score += 20;
    }
    return score;
  }

  PlanetTile? _preferredMoveFor(Unit unit) {
    final candidates = <PlanetTile>[];
    final offsets = const <List<int>>[
      <int>[0, -1],
      <int>[1, 0],
      <int>[0, 1],
      <int>[-1, 0],
    ];

    for (final offset in offsets) {
      final x = unit.x + offset[0];
      final y = unit.y + offset[1];
      if (!_isInsideMap(x, y)) {
        continue;
      }
      final tile = tileAt(x, y);
      if (visibleUnitAt(unit.ownerId, x, y) != null ||
          !_canUnitEnterTile(unit, tile)) {
        continue;
      }
      if (!canFactionTraverseSector(unit.ownerId, tile)) {
        continue;
      }
      candidates.add(tile);
    }

    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((a, b) {
      final aScore = _movementScoreFor(unit, a);
      final bScore = _movementScoreFor(unit, b);
      return bScore.compareTo(aScore);
    });
    return candidates.first;
  }

  bool _canUnitEnterTile(Unit unit, PlanetTile tile) {
    return isTerrainPassable(tile.terrain) &&
        movementCostForTerrain(tile.terrain) <= unit.movesRemaining;
  }

  int _movementScoreFor(Unit unit, PlanetTile tile) {
    var score = 0;
    if (!tile.isExploredBy(unit.ownerId)) {
      score += 6;
    }
    if (tile.ownerId == null) {
      score += _unitOwnerPersonality(unit) == Faction.aiPersonalityExpansionist
          ? 8
          : 4;
    }
    score -= movementCostForTerrain(tile.terrain);
    score += tile.yields.food + tile.yields.industry + tile.yields.research;
    score += _expansionSiteProgressScoreFor(unit, tile);
    score += _colonyGarrisonScoreFor(unit, tile);
    score += _colonyDefenseProgressScoreFor(unit, tile);
    score += _wartimeTargetProgressScoreFor(unit, tile);
    return score;
  }

  String _unitOwnerPersonality(Unit unit) {
    return factionById(unit.ownerId)?.aiPersonality ??
        Faction.aiPersonalityAdaptive;
  }

  int _colonyGarrisonScoreFor(Unit unit, PlanetTile tile) {
    final colonyId = tile.colonyId;
    if (colonyId == null) {
      return 0;
    }
    final colony = colonyById(colonyId);
    if (colony.ownerId != unit.ownerId || !_isColonyThreatened(colony)) {
      return 0;
    }

    final threatDistance = _nearestVisibleColonyThreatDistance(
          unit.ownerId,
          tile.x,
          tile.y,
        ) ??
        8;
    return 36 + _clampInt(8 - threatDistance, 0, 8);
  }

  int _colonyDefenseProgressScoreFor(Unit unit, PlanetTile tile) {
    final currentDistance = _nearestVisibleColonyThreatDistance(
      unit.ownerId,
      unit.x,
      unit.y,
    );
    final candidateDistance = _nearestVisibleColonyThreatDistance(
      unit.ownerId,
      tile.x,
      tile.y,
    );
    if (currentDistance == null || candidateDistance == null) {
      return 0;
    }

    final progress = currentDistance - candidateDistance;
    final proximity = _clampInt(8 - candidateDistance, 0, 8);
    return (progress * 14) + proximity;
  }

  int? _nearestVisibleColonyThreatDistance(String factionId, int x, int y) {
    int? bestDistance;

    for (final unit in units) {
      if (unit.ownerId == factionId || !areAtWar(factionId, unit.ownerId)) {
        continue;
      }
      if (!isUnitVisibleTo(factionId, unit)) {
        continue;
      }
      if (!_isUnitThreateningColony(unit, factionId)) {
        continue;
      }
      final distance = _manhattanDistance(x, y, unit.x, unit.y);
      if (bestDistance == null || distance < bestDistance) {
        bestDistance = distance;
      }
    }

    return bestDistance;
  }

  bool _isUnitThreateningColony(Unit unit, String factionId) {
    for (final colony in colonies) {
      if (colony.ownerId == factionId &&
          _manhattanDistance(colony.x, colony.y, unit.x, unit.y) <= 2) {
        return true;
      }
    }
    return false;
  }

  int _wartimeTargetProgressScoreFor(Unit unit, PlanetTile tile) {
    final currentDistance = _nearestKnownWartimeTargetDistance(
      unit.ownerId,
      unit.x,
      unit.y,
    );
    final candidateDistance = _nearestKnownWartimeTargetDistance(
      unit.ownerId,
      tile.x,
      tile.y,
    );
    if (currentDistance == null || candidateDistance == null) {
      return 0;
    }

    final progress = currentDistance - candidateDistance;
    final proximity = _clampInt(8 - candidateDistance, 0, 8);
    return (progress * 8) + proximity;
  }

  int? _nearestKnownWartimeTargetDistance(String factionId, int x, int y) {
    int? bestDistance;

    void considerTarget(String ownerId, int targetX, int targetY) {
      if (!areAtWar(factionId, ownerId)) {
        return;
      }
      final targetTile = tileAt(targetX, targetY);
      if (!targetTile.isExploredBy(factionId)) {
        return;
      }
      final distance = _manhattanDistance(x, y, targetX, targetY);
      if (bestDistance == null || distance < bestDistance!) {
        bestDistance = distance;
      }
    }

    for (final colony in colonies) {
      if (colony.ownerId == factionId) {
        continue;
      }
      considerTarget(colony.ownerId, colony.x, colony.y);
    }
    for (final unit in units) {
      if (unit.ownerId == factionId) {
        continue;
      }
      if (isUnitVisibleTo(factionId, unit)) {
        considerTarget(unit.ownerId, unit.x, unit.y);
      }
    }

    return bestDistance;
  }

  bool _canFoundColonyWith(Unit unit) {
    final tile = tileAt(unit.x, unit.y);
    return tile.terrain != 'water' &&
        tile.ownerId == unit.ownerId &&
        tile.colonyId == null &&
        colonyAt(unit.x, unit.y) == null;
  }

  bool _shouldFoundColonyWith(Unit unit) {
    if (unit.type != 'scout' || !_canFoundColonyWith(unit)) {
      return false;
    }

    final tile = tileAt(unit.x, unit.y);
    final faction = factionById(unit.ownerId);
    return _isViableComputerColonySite(
      unit.ownerId,
      tile,
      faction,
      allowNeutral: false,
    );
  }

  int _expansionSiteProgressScoreFor(Unit unit, PlanetTile tile) {
    if (unit.type != 'scout' ||
        _nearestKnownWartimeTargetDistance(unit.ownerId, unit.x, unit.y) !=
            null) {
      return 0;
    }
    final faction = factionById(unit.ownerId);
    if (!_isViableComputerColonySite(
      unit.ownerId,
      tile,
      faction,
      allowNeutral: true,
    )) {
      return 0;
    }

    final surplusScore = _colonySiteScoreFor(unit.ownerId, tile) -
        _minimumColonySiteScoreFor(faction);
    final personalityBonus =
        faction?.aiPersonality == Faction.aiPersonalityExpansionist ? 8 : 0;
    return 12 + surplusScore + personalityBonus;
  }

  bool _isViableComputerColonySite(
    String factionId,
    PlanetTile tile,
    Faction? faction, {
    required bool allowNeutral,
  }) {
    if (!isTerrainPassable(tile.terrain) ||
        tile.colonyId != null ||
        colonyAt(tile.x, tile.y) != null) {
      return false;
    }
    if (tile.ownerId != factionId && (!allowNeutral || tile.ownerId != null)) {
      return false;
    }

    final nearestColonyDistance = _nearestOwnedColonyDistance(
      factionId,
      tile.x,
      tile.y,
    );
    final minimumSpacing =
        faction?.aiPersonality == Faction.aiPersonalityExpansionist ? 2 : 3;
    if (nearestColonyDistance != null &&
        nearestColonyDistance < minimumSpacing) {
      return false;
    }

    return _colonySiteScoreFor(factionId, tile) >=
        _minimumColonySiteScoreFor(faction);
  }

  int? _nearestOwnedColonyDistance(String factionId, int x, int y) {
    int? bestDistance;
    for (final colony in colonies) {
      if (colony.ownerId != factionId) {
        continue;
      }
      final distance = _manhattanDistance(x, y, colony.x, colony.y);
      if (bestDistance == null || distance < bestDistance) {
        bestDistance = distance;
      }
    }
    return bestDistance;
  }

  int _colonySiteScoreFor(String factionId, PlanetTile tile) {
    var score = _tileColonySiteScore(tile);
    for (final neighbor in _neighboringTiles(tile.x, tile.y)) {
      if (!isTerrainPassable(neighbor.terrain)) {
        continue;
      }
      if (neighbor.ownerId != null && neighbor.ownerId != factionId) {
        continue;
      }
      score += _tileColonySiteScore(neighbor) ~/ 2;
    }

    final faction = factionById(factionId);
    if (faction != null) {
      if (faction.aiPersonality == Faction.aiPersonalityExpansionist) {
        score += tile.yields.food * 3;
      } else if (faction.aiPersonality == Faction.aiPersonalityConqueror) {
        score += tile.yields.industry * 3;
      } else if (faction.aiPersonality == Faction.aiPersonalityResearcher) {
        score += tile.yields.research * 3;
      }
    }
    return score;
  }

  int _tileColonySiteScore(PlanetTile tile) {
    return (tile.yields.food * 5) +
        (tile.yields.industry * 5) +
        (tile.yields.research * 4);
  }

  int _minimumColonySiteScoreFor(Faction? faction) {
    if (faction?.aiPersonality == Faction.aiPersonalityExpansionist) {
      return 20;
    }
    return 24;
  }

  List<PlanetTile> _neighboringTiles(int x, int y) {
    final neighbors = <PlanetTile>[];
    const offsets = <List<int>>[
      <int>[0, -1],
      <int>[1, 0],
      <int>[0, 1],
      <int>[-1, 0],
    ];
    for (final offset in offsets) {
      final neighborX = x + offset[0];
      final neighborY = y + offset[1];
      if (_isInsideMap(neighborX, neighborY)) {
        neighbors.add(tileAt(neighborX, neighborY));
      }
    }
    return neighbors;
  }

  List<Colony> _coloniesWithoutAssignmentAt(int x, int y) {
    return colonies.map((colony) {
      final assignedSectors = colony.assignedSectors
          .where((assignment) => !assignment.matches(x, y))
          .toList();
      if (assignedSectors.length == colony.assignedSectors.length) {
        return colony;
      }
      return colony.copyWith(assignedSectors: assignedSectors);
    }).toList();
  }

  bool _shouldRecoverUnit(Unit unit) {
    return unit.movesRemaining > 0 && unit.health < maxHealthFor(unit.type);
  }

  bool _factionCanTakeTurn(String factionId) {
    return factionHasPresence(factionId);
  }

  int? _researchFundingFor(String factionId) {
    final faction = factionById(factionId);
    if (faction == null ||
        !researchOptions.contains(faction.researchProject) ||
        isCompletedResearch(faction, faction.researchProject)) {
      return null;
    }

    final researchCost = researchCostFor(faction.researchProject);
    final remainingResearch = researchCost - faction.resources.research;
    if (remainingResearch <= 0) {
      return null;
    }
    if (faction.resources.credits < fundResearchCostFor(remainingResearch)) {
      return null;
    }

    var projectedResearch = 0;
    for (final colony in colonies) {
      if (colony.ownerId == factionId) {
        projectedResearch += colonyProductionFor(colony).output.research;
      }
    }
    if (faction.resources.research + projectedResearch >= researchCost) {
      return null;
    }
    return remainingResearch;
  }

  int? _rushIndustryForColony(Colony colony) {
    final faction = factionById(colony.ownerId);
    if (faction == null) {
      return null;
    }

    final remainingIndustry =
        buildCostFor(colony.construction) - colony.storedIndustry;
    if (remainingIndustry <= 0) {
      return null;
    }
    if (faction.resources.credits <
        rushConstructionCostFor(remainingIndustry)) {
      return null;
    }
    if (colonyProductionFor(colony).willCompleteConstruction) {
      return null;
    }
    return remainingIndustry;
  }

  bool _isInsideMap(int x, int y) {
    return x >= 0 && y >= 0 && x < width && y < height;
  }

  int _manhattanDistance(int ax, int ay, int bx, int by) {
    return _absolute(ax - bx) + _absolute(ay - by);
  }

  static String _productionSummary(ResourceStockpile stockpile) {
    return '+${stockpile.food} food, +${stockpile.industry} industry, '
        '+${stockpile.research} research, +${stockpile.credits} credits.';
  }

  static int _clampInt(int value, int minimum, int maximum) {
    if (value < minimum) {
      return minimum;
    }
    if (value > maximum) {
      return maximum;
    }
    return value;
  }

  static OpenDeadlockGame sample({String sessionId = 'sample-skirmish'}) {
    const player = Faction(
      id: 'humans',
      name: 'Human Assembly',
      colorValue: 0xFF2F80ED,
      raceId: 'human',
      isComputer: false,
      resources:
          ResourceStockpile(food: 18, industry: 8, research: 0, credits: 24),
      traitIds: <String>['scholars', 'traders'],
    );
    const rival = Faction(
      id: 'rebels',
      name: 'Tarth Legion',
      colorValue: 0xFFB83232,
      raceId: 'tarth',
      isComputer: true,
      aiPersonality: Faction.aiPersonalityConqueror,
      resources:
          ResourceStockpile(food: 14, industry: 6, research: 0, credits: 18),
      traitIds: <String>['industrialists', 'militarists'],
    );

    final tiles = <PlanetTile>[];
    const terrainCycle = <String>[
      'plains',
      'forest',
      'ridge',
      'water',
      'ruins'
    ];
    const yields = <String, TileYield>{
      'plains': TileYield(food: 3, industry: 1, research: 0),
      'forest': TileYield(food: 2, industry: 2, research: 0),
      'ridge': TileYield(food: 1, industry: 3, research: 0),
      'water': TileYield(food: 2, industry: 0, research: 1),
      'ruins': TileYield(food: 0, industry: 1, research: 3),
    };

    const width = 8;
    const height = 6;
    for (var y = 0; y < height; y += 1) {
      for (var x = 0; x < width; x += 1) {
        final terrain = terrainCycle[(x + (y * 2)) % terrainCycle.length];
        String? ownerId;
        String? colonyId;
        if (x == 2 && y == 2) {
          ownerId = player.id;
          colonyId = 'new-haven';
        } else if (x == 6 && y == 3) {
          ownerId = rival.id;
          colonyId = 'redoubt';
        } else if (x <= 3 && y <= 3) {
          ownerId = player.id;
        } else if (x >= 5 && y >= 2) {
          ownerId = rival.id;
        }

        final exploredBy = <String>[];
        if (x <= 3) {
          exploredBy.add(player.id);
        }
        if (x >= 5) {
          exploredBy.add(rival.id);
        }
        if (ownerId != null && !exploredBy.contains(ownerId)) {
          exploredBy.add(ownerId);
        }

        tiles.add(
          PlanetTile(
            x: x,
            y: y,
            terrain: terrain,
            yields: yields[terrain]!,
            ownerId: ownerId,
            colonyId: colonyId,
            explored: exploredBy.isNotEmpty,
            exploredBy: exploredBy,
          ),
        );
      }
    }

    return OpenDeadlockGame(
      sessionId: sessionId,
      turn: 1,
      width: width,
      height: height,
      activeFactionId: player.id,
      victoryCondition: victoryConditionAny,
      factions: const <Faction>[player, rival],
      tiles: tiles,
      colonies: const <Colony>[
        Colony(
          id: 'new-haven',
          name: 'New Haven',
          ownerId: 'humans',
          x: 2,
          y: 2,
          population: 5,
          morale: 72,
          construction: 'Colony Hub',
          storedIndustry: 10,
          completedBuildings: <String>[],
        ),
        Colony(
          id: 'redoubt',
          name: 'Redoubt',
          ownerId: 'rebels',
          x: 6,
          y: 3,
          population: 4,
          morale: 61,
          construction: 'Barracks',
          storedIndustry: 4,
          completedBuildings: <String>[],
        ),
      ],
      units: const <Unit>[
        Unit(
          id: 'human-scout',
          name: 'Survey Team',
          ownerId: 'humans',
          type: 'scout',
          x: 3,
          y: 1,
          movesRemaining: 2,
        ),
        Unit(
          id: 'rebel-scout',
          name: 'Pact Recon',
          ownerId: 'rebels',
          type: 'scout',
          x: 5,
          y: 3,
          movesRemaining: 2,
        ),
      ],
      diplomacy: const <DiplomacyRelation>[
        DiplomacyRelation(
          factionAId: 'humans',
          factionBId: 'rebels',
          status: diplomacyStatusWar,
        ),
      ],
      commandHistory: const <CommandRecord>[],
      reports: const <TurnReport>[
        TurnReport(
          title: 'Survey complete',
          message: 'A small explored sector is ready for first-turn planning.',
        ),
      ],
    );
  }
}

int _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  throw ArgumentError('Expected an integer-compatible value, got $value.');
}

int _readScoreTurnLimit(Object? value) {
  if (value == null) {
    return 0;
  }
  final limit = _readInt(value);
  if (limit < 0) {
    throw ArgumentError('Score turn limit cannot be negative.');
  }
  return limit;
}

String _legacySessionIdFor(Map<String, dynamic> json) {
  final width = _readInt(json['width']);
  final height = _readInt(json['height']);
  final factions = json['factions'] as List<dynamic>? ?? const <dynamic>[];
  final factionIds = <String>[];
  for (final faction in factions) {
    if (faction is Map<String, dynamic>) {
      factionIds.add(faction['id'] as String? ?? 'unknown');
    }
  }
  return 'legacy-$width-$height-${factionIds.join('-')}';
}

String _legacyRaceIdFor(String factionId) {
  if (factionId == 'rebels') {
    return 'tarth';
  }
  if (factionId == 'traders') {
    return 'uva_mosk';
  }
  return 'human';
}

String _knownVictoryConditionOrDefault(String? victoryCondition) {
  if (victoryCondition != null &&
      OpenDeadlockGame.victoryConditions.contains(victoryCondition)) {
    return victoryCondition;
  }
  return OpenDeadlockGame.victoryConditionAny;
}

String _creditLabel(int credits) {
  return credits == 1 ? '1 credit' : '$credits credits';
}

int _absolute(int value) {
  if (value < 0) {
    return -value;
  }
  return value;
}

int _maxHealthForUnitType(String unitType) {
  if (unitType == 'scout') {
    return 5;
  }
  if (unitType == 'infantry') {
    return 8;
  }
  if (unitType == 'armor') {
    return 10;
  }
  return 5;
}

int _attackForUnitType(String unitType) {
  if (unitType == 'scout') {
    return 3;
  }
  if (unitType == 'infantry') {
    return 4;
  }
  if (unitType == 'armor') {
    return 6;
  }
  return 2;
}

int _defenseForUnitType(String unitType) {
  if (unitType == 'scout') {
    return 1;
  }
  if (unitType == 'infantry') {
    return 2;
  }
  if (unitType == 'armor') {
    return 3;
  }
  return 1;
}

int _maxMovesForUnitType(String unitType) {
  if (unitType == 'scout') {
    return 2;
  }
  if (unitType == 'infantry') {
    return 1;
  }
  if (unitType == 'armor') {
    return 1;
  }
  return 1;
}

int _movementCostForTerrain(String terrain) {
  if (terrain == 'plains' || terrain == 'ruins') {
    return 1;
  }
  if (terrain == 'forest' || terrain == 'ridge') {
    return 2;
  }
  throw ArgumentError('Unknown passable terrain: $terrain.');
}

int _colonyDefenseFor(Colony colony) {
  var defense = 3 + (colony.population ~/ 2);
  if (colony.completedBuildings.contains('Militia Post')) {
    defense += 2;
  }
  if (colony.completedBuildings.contains('Barracks')) {
    defense += 3;
  }
  return defense;
}
