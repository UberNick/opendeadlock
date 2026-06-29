import 'dart:io';
import 'package:OpenDeadlock/game/game_codec.dart';
import 'package:OpenDeadlock/game/game_saves.dart';
import 'package:OpenDeadlock/game/game_state.dart';
import 'package:OpenDeadlock/gameplay/game_screen.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('game screen keeps primary controls usable on phone width',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: OpenDeadlockGame.sample(sessionId: 'mobile-layout'),
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byTooltip('Sync'), findsOneWidget);
    expect(find.byTooltip('Mute sound effects'), findsOneWidget);
    expect(find.byIcon(Icons.skip_next), findsOneWidget);
    expect(find.text('Turn 1'), findsWidgets);
    expect(find.textContaining('Human Assembly'), findsWidgets);
    expect(find.text('Issue orders'), findsOneWidget);

    await tester.tap(find.byTooltip('Sync'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Load Invite'), findsOneWidget);
  });

  testWidgets('mobile sync cue reports pending orders', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: OpenDeadlockGame.sample(sessionId: 'mobile-sync-cue'),
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Issue orders'), findsOneWidget);

    await tester.dragUntilVisible(
      find.textContaining('Balanced - No production bias.'),
      find.byType(ListView),
      const Offset(0, -260),
      maxIteration: 8,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Balanced - No production bias.'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('+2 industry, -1 food.').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Send 1 order'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Unsent'),
      find.byType(ListView),
      const Offset(0, -360),
      maxIteration: 12,
    );
    await tester.pumpAndSettle();

    expect(find.text('Next'), findsWidgets);
    expect(find.text('Send 1 order'), findsWidgets);
    expect(find.text('1 order'), findsOneWidget);
  });

  testWidgets('game screen summarizes turn checklist on phone width',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: OpenDeadlockGame.sample(sessionId: 'turn-checklist'),
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 24; i += 1) {
      if (find.text('Turn Checklist').evaluate().isNotEmpty) {
        break;
      }
      await tester.drag(find.byType(ListView).last, const Offset(0, -520));
      await tester.pumpAndSettle();
    }

    expect(tester.takeException(), isNull);
    expect(find.text('Turn Checklist'), findsOneWidget);
    expect(find.text('Planning'), findsOneWidget);
    expect(find.text('Move or recover 1 unit'), findsOneWidget);
    expect(find.text('No unsent orders'), findsOneWidget);
    expect(find.text('1 unit can still move'), findsOneWidget);
    expect(find.text('1 stable colony'), findsOneWidget);
    expect(find.text('No builds complete next turn'), findsOneWidget);
    expect(find.text('Hydroponics 0/10, 10 left'), findsOneWidget);
    expect(find.text('1 unit idle | Fund 8 research'), findsOneWidget);
  });

  testWidgets('end turn asks for review when checklist has open items',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: OpenDeadlockGame.sample(sessionId: 'end-review'),
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'End Turn'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Review before ending turn'), findsOneWidget);
    expect(find.text('1 unit can still move'), findsOneWidget);
    expect(find.text('Fund 8 research'), findsOneWidget);

    await tester.tap(find.text('Review More'));
    await tester.pumpAndSettle();

    expect(find.text('Review before ending turn'), findsNothing);
    expect(find.text('Turn 1'), findsWidgets);

    await tester.tap(find.widgetWithText(ElevatedButton, 'End Turn'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'End Turn Anyway'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Review before ending turn'), findsNothing);
    expect(find.text('Turn 2'), findsWidgets);
  });

  testWidgets('end turn advances directly when checklist is clear',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final sample = OpenDeadlockGame.sample(sessionId: 'end-review-clear');
    final clearTurn = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id != sample.activeFactionId) {
          return faction;
        }
        return faction.copyWith(
          resources: faction.resources.copyWith(credits: 0),
        );
      }).toList(),
      units: sample.units.map((unit) {
        if (unit.ownerId != sample.activeFactionId) {
          return unit;
        }
        return unit.copyWith(movesRemaining: 0);
      }).toList(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: clearTurn,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'End Turn'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Review before ending turn'), findsNothing);
    expect(find.text('Turn 2'), findsWidgets);
  });

  testWidgets('mobile sync cue reports remote and AI turns', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final sample = OpenDeadlockGame.sample(sessionId: 'mobile-sync-states');
    final remoteActive = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id != sample.activeFactionId) {
          return faction;
        }
        return faction.copyWith(
            isComputer: false, controlMode: Faction.controlRemote);
      }).toList(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: remoteActive,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Import orders'), findsOneWidget);

    final computerActive = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id != sample.activeFactionId) {
          return faction;
        }
        return faction.copyWith(isComputer: true);
      }).toList(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          key: UniqueKey(),
          initialGame: computerActive,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Run AI'), findsOneWidget);
  });

  testWidgets('game screen persists the sound effects toggle', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'opendeadlock.sound_effects_enabled': true,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: OpenDeadlockGame.sample(sessionId: 'sound-toggle'),
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Mute sound effects'), findsOneWidget);

    await tester.tap(find.byTooltip('Mute sound effects'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('opendeadlock.sound_effects_enabled'), isFalse);
    expect(find.byTooltip('Enable sound effects'), findsOneWidget);
    expect(find.text('Sound effects muted'), findsOneWidget);
  });

  testWidgets('map zoom uses continuous controls on phone width',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: OpenDeadlockGame.sample(sessionId: 'mobile-map-zoom'),
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final selectedTile = find.byKey(const ValueKey<String>('terrain-2-2'));
    final fittedSize = tester.getSize(selectedTile);

    expect(find.byTooltip('Zoom map'), findsOneWidget);
    expect(
        find.byKey(const ValueKey<String>('map-zoom-slider')), findsOneWidget);
    expect(find.text('1.0x'), findsOneWidget);

    await tester.tap(find.byTooltip('Zoom map'));
    await tester.pumpAndSettle();

    final zoomedSize = tester.getSize(selectedTile);
    expect(find.byTooltip('Fit map'), findsOneWidget);
    expect(find.text('1.5x'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('map-scroll-y')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('map-scroll-x')), findsOneWidget);
    expect(zoomedSize.width, greaterThan(fittedSize.width));

    await tester.tap(find.byTooltip('Zoom map'));
    await tester.pumpAndSettle();

    final furtherZoomedSize = tester.getSize(selectedTile);
    expect(find.text('2.0x'), findsOneWidget);
    expect(furtherZoomedSize.width, greaterThan(zoomedSize.width));

    await tester.tap(find.byTooltip('Fit map'));
    await tester.pumpAndSettle();

    final refittedSize = tester.getSize(selectedTile);
    expect(find.text('1.0x'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('map-scroll-y')), findsNothing);
    expect(refittedSize.width, fittedSize.width);

    await tester.tapAt(tester.getCenter(selectedTile));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('New Haven'), findsOneWidget);
  });

  testWidgets('map terrain is painted and remains tappable', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: OpenDeadlockGame.sample(sessionId: 'terrain-paint'),
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey<String>('terrain-2-2')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('terrain-texture-2-2')),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('terrain-badge-2-2')),
        findsOneWidget);
    expect(find.byTooltip('Forest'), findsWidgets);
    expect(find.byKey(const ValueKey<String>('terrain-3-1')), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);

    final scoutTile = find.byKey(const ValueKey<String>('terrain-3-1'));
    await tester.tapAt(tester.getCenter(scoutTile));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Survey Team'), findsOneWidget);
  });

  testWidgets('map unit markers distinguish unit types', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final sample = OpenDeadlockGame.sample(sessionId: 'unit-markers');
    final markerGame = sample.copyWith(
      units: <Unit>[
        sample.unitById('human-scout'),
        const Unit(
          id: 'human-infantry',
          name: 'Human Infantry',
          ownerId: 'humans',
          type: 'infantry',
          x: 4,
          y: 1,
          movesRemaining: 1,
          health: 6,
        ),
        const Unit(
          id: 'human-armor',
          name: 'Human Armor',
          ownerId: 'humans',
          type: 'armor',
          x: 5,
          y: 1,
          movesRemaining: 1,
          health: 10,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: markerGame,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey<String>('unit-marker-human-scout')),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('unit-marker-human-infantry')),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('unit-marker-human-armor')),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('unit-icon-scout-3-1')),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('unit-icon-infantry-4-1')),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('unit-icon-armor-5-1')),
        findsOneWidget);
    expect(
      find.byTooltip('Human Armor | Armor | 10/10 health | 1/1 moves'),
      findsOneWidget,
    );

    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey<String>('terrain-5-1'))),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Human Armor'), findsOneWidget);
    expect(find.text('Armor'), findsWidgets);
  });

  testWidgets('map can switch resource heat overlays', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: OpenDeadlockGame.sample(sessionId: 'resource-overlays'),
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('map-overlay-terrain')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey<String>('map-overlay-food')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('resource-overlay-food-2-2')),
        findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('map-overlay-food')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey<String>('resource-overlay-food-2-2')),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('terrain-2-2')), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey<String>('map-overlay-industry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('resource-overlay-food-2-2')),
        findsNothing);
    expect(find.byKey(const ValueKey<String>('resource-overlay-industry-2-2')),
        findsOneWidget);

    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey<String>('terrain-2-2'))),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('New Haven'), findsOneWidget);
  });

  testWidgets('map hides remembered enemy units outside live vision',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final sample = OpenDeadlockGame.sample(sessionId: 'live-visibility-ui');
    final rememberedContact = sample.copyWith(
      tiles: sample.tiles.map((tile) {
        if (tile.x == 5 && tile.y == 3) {
          return tile.revealTo('humans');
        }
        return tile;
      }).toList(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          key: const ValueKey<String>('remembered-contact-game'),
          initialGame: rememberedContact,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey<String>('terrain-5-3'))),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Pact Recon'), findsNothing);
    expect(find.text('Sector 6, 4'), findsOneWidget);

    final scoutNearby = rememberedContact.copyWith(
      units: rememberedContact.units.map((unit) {
        if (unit.id == 'human-scout') {
          return unit.copyWith(x: 4, y: 3);
        }
        return unit;
      }).toList(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          key: const ValueKey<String>('visible-contact-game'),
          initialGame: scoutNearby,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey<String>('terrain-5-3'))),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Pact Recon'), findsOneWidget);
  });

  testWidgets('game screen shows the active faction AI profile',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final sample = OpenDeadlockGame.sample(sessionId: 'profile-readout');
    final profiled = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id != 'humans') {
          return faction;
        }
        return faction.copyWith(aiPersonality: Faction.aiPersonalityResearcher);
      }).toList(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: profiled,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('AI Profile'),
      find.byType(ListView),
      const Offset(0, -260),
      maxIteration: 8,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('AI Profile'), findsOneWidget);
    expect(find.text('Researcher'), findsOneWidget);
    expect(
      find.text(
          'Prioritizes research labs, science focus, and research projects.'),
      findsOneWidget,
    );
  });

  testWidgets('world overview compares race profiles and traits',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final game = OpenDeadlockGame.sample(sessionId: 'world-profile-readout');
    final humanScore = game.factionScoreFor('humans');

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: game,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('World'),
      420,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 10,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('World'), findsOneWidget);
    expect(find.text('Human Assembly'), findsWidgets);
    expect(find.text('Tarth Legion'), findsWidgets);
    expect(
      find.text(
        'Score: Colonies ${humanScore.colonyScore} | Sectors ${humanScore.sectorScore} | Population ${humanScore.populationScore} | Military ${humanScore.militaryScore} | Science ${humanScore.scienceScore} | Reserves ${humanScore.reserveScore}',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Profile Adaptive | Traits Scholars, Traders'),
      findsOneWidget,
    );
    expect(
      find.text('Profile Conqueror | Traits Industrialists, Militarists'),
      findsOneWidget,
    );
  });

  testWidgets('game screen can assign a sector to colony production',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: OpenDeadlockGame.sample(sessionId: 'assign-sector-ui'),
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey<String>('terrain-2-1'))),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Assign to New Haven'),
        findsOneWidget);

    await tester
        .tap(find.widgetWithText(OutlinedButton, 'Assign to New Haven'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
        find.byKey(const ValueKey<String>('work-sector-2-1')), findsOneWidget);
    expect(find.text('Worked By'), findsOneWidget);
    expect(find.text('Release Sector'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Release Sector'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('work-sector-2-1')), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Assign to New Haven'),
        findsOneWidget);
  });

  testWidgets('game screen can bulk assign and release colony work sectors',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final game = OpenDeadlockGame.sample(sessionId: 'bulk-work-ui');
    final colony = game.colonyById('new-haven');
    final bestSectors = game.preferredAssignableSectorsFor(colony);
    final assignCount = bestSectors.length;
    final sectorLabel = assignCount == 1 ? 'Sector' : 'Sectors';
    final snackbarSectorLabel = assignCount == 1 ? 'sector' : 'sectors';
    final assignLabel = 'Assign $assignCount Best $sectorLabel';
    final releaseLabel = 'Release $assignCount Worked $sectorLabel';

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: game,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Work Planner'),
      300,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 10,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Work Planner'), findsOneWidget);
    expect(find.text('0/4 outlying assigned'), findsOneWidget);
    expect(find.widgetWithText(TextButton, assignLabel), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, assignLabel));
    await tester.pumpAndSettle();

    for (final sector in bestSectors) {
      expect(
        find.byKey(ValueKey<String>('work-sector-${sector.x}-${sector.y}')),
        findsOneWidget,
      );
    }
    expect(find.text('Assigned $assignCount $snackbarSectorLabel to New Haven'),
        findsOneWidget);

    await tester.scrollUntilVisible(
      find.text(releaseLabel),
      300,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 10,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, releaseLabel));
    await tester.pumpAndSettle();

    for (final sector in bestSectors) {
      expect(
        find.byKey(ValueKey<String>('work-sector-${sector.x}-${sector.y}')),
        findsNothing,
      );
    }
    expect(
      find.text('Released $assignCount $snackbarSectorLabel from New Haven'),
      findsOneWidget,
    );
  });

  testWidgets('game screen can change colony production focus', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: OpenDeadlockGame.sample(sessionId: 'focus-ui'),
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.textContaining('Balanced - No production bias.'), findsOneWidget);
    expect(find.text('7 food / 7 ind / 3 res / 9 cred'), findsOneWidget);

    await tester.tap(find.textContaining('Balanced - No production bias.'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('+2 industry, -1 food.').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Industry - +2 industry, -1 food.'),
        findsOneWidget);
    expect(find.text('6 food / 9 ind / 3 res / 9 cred'), findsOneWidget);
    expect(find.textContaining('(+9)'), findsOneWidget);
  });

  testWidgets('game screen shows colony income and morale forecasts',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final sample = OpenDeadlockGame.sample(sessionId: 'colony-forecast-ui');
    final game = sample.applyCommand(
      const SetFactionTaxPolicyCommand(
        factionId: 'humans',
        taxPolicy: Faction.taxPolicyHigh,
      ),
    );
    final colony = game.colonyById('new-haven');
    final projection = game.colonyProductionFor(colony);
    final grossCredits = projection.output.credits + projection.buildingUpkeep;

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: game,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text(
        '$grossCredits gross - ${projection.buildingUpkeep} upkeep = ${projection.output.credits} net',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        '${colony.morale}% -> ${projection.nextMorale}% (${projection.moraleChange > 0 ? '+' : ''}${projection.moraleChange})',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('high taxes -2'),
      findsOneWidget,
    );
  });

  testWidgets('game screen shows a multi-colony overview and jumps to colonies',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final sample = OpenDeadlockGame.sample(sessionId: 'multi-colony-ui');
    const secondColony = Colony(
      id: 'second-haven',
      name: 'Second Haven',
      ownerId: 'humans',
      x: 1,
      y: 2,
      population: 3,
      morale: 68,
      construction: 'Factory',
      storedIndustry: 6,
      completedBuildings: <String>[],
    );
    final game = sample.copyWith(
      tiles: sample.tiles.map((tile) {
        if (tile.x == secondColony.x && tile.y == secondColony.y) {
          return tile.copyWith(
            ownerId: secondColony.ownerId,
            colonyId: secondColony.id,
            explored: true,
            exploredBy: <String>[secondColony.ownerId],
          );
        }
        return tile;
      }).toList(),
      colonies: <Colony>[
        ...sample.colonies,
        secondColony,
      ],
    );
    final activeColonies = game.colonies
        .where((colony) => colony.ownerId == game.activeFactionId)
        .toList(growable: false);
    var totalFood = 0;
    var totalIndustry = 0;
    var totalResearch = 0;
    var totalCredits = 0;
    for (final colony in activeColonies) {
      final output = game.colonyProductionFor(colony).output;
      totalFood += output.food;
      totalIndustry += output.industry;
      totalResearch += output.research;
      totalCredits += output.credits;
    }
    final secondProjection = game.colonyProductionFor(secondColony);
    final secondTile = game.tileAt(secondColony.x, secondColony.y);
    final secondBuildCost =
        OpenDeadlockGame.buildCostFor(secondColony.construction);
    final secondBuildTurns = (secondBuildCost -
            secondColony.storedIndustry +
            secondProjection.constructionWork -
            1) ~/
        secondProjection.constructionWork;
    final secondBuildEta = secondProjection.willCompleteConstruction
        ? 'complete this turn'
        : '$secondBuildTurns ${secondBuildTurns == 1 ? 'turn' : 'turns'}';
    final secondPopulationChange = secondProjection.populationChange > 0
        ? '+${secondProjection.populationChange}'
        : '${secondProjection.populationChange}';
    final secondMoraleChange = secondProjection.moraleChange > 0
        ? '+${secondProjection.moraleChange}'
        : '${secondProjection.moraleChange}';

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: game,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Colonies'),
      420,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 10,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Colonies'), findsOneWidget);
    expect(find.text('2 active'), findsOneWidget);
    expect(
      find.text(
        '$totalFood food / $totalIndustry ind / $totalResearch res / $totalCredits cred',
      ),
      findsWidgets,
    );
    expect(find.text('Second Haven'), findsWidgets);
    expect(
      find.text(
        'Build Factory: ${secondColony.storedIndustry}/$secondBuildCost +${secondProjection.constructionWork}, $secondBuildEta',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Pop ${secondColony.population} -> ${secondProjection.nextPopulation} ($secondPopulationChange) | Morale ${secondColony.morale}% -> ${secondProjection.nextMorale}% ($secondMoraleChange)',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Second Haven').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Terrain'),
      -420,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 10,
    );
    await tester.pumpAndSettle();

    expect(find.text('Terrain'), findsOneWidget);
    expect(
      find.text(
        '${secondTile.yields.food} food / ${secondTile.yields.industry} industry / ${secondTile.yields.research} research',
      ),
      findsOneWidget,
    );
  });

  testWidgets('game screen applies colony build and focus to all colonies',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final sample = OpenDeadlockGame.sample(sessionId: 'bulk-colony-ui');
    const secondColony = Colony(
      id: 'second-haven',
      name: 'Second Haven',
      ownerId: 'humans',
      x: 1,
      y: 2,
      population: 3,
      morale: 68,
      construction: 'Factory',
      storedIndustry: 6,
      completedBuildings: <String>[],
      focus: OpenDeadlockGame.colonyFocusResearch,
    );
    final game = sample.copyWith(
      tiles: sample.tiles.map((tile) {
        if (tile.x == secondColony.x && tile.y == secondColony.y) {
          return tile.copyWith(
            ownerId: secondColony.ownerId,
            colonyId: secondColony.id,
            explored: true,
            exploredBy: <String>[secondColony.ownerId],
          );
        }
        return tile;
      }).toList(),
      colonies: <Colony>[
        ...sample.colonies,
        secondColony,
      ],
    );
    final afterBulkOrders = game.applyCommands(
      const <GameCommand>[
        SetColonyFocusCommand(
          factionId: 'humans',
          colonyId: 'second-haven',
          focus: OpenDeadlockGame.colonyFocusBalanced,
        ),
        SetColonyConstructionCommand(
          factionId: 'humans',
          colonyId: 'second-haven',
          construction: 'Colony Hub',
        ),
      ],
    );
    final updatedSecondColony = afterBulkOrders.colonyById(secondColony.id);
    final updatedProjection =
        afterBulkOrders.colonyProductionFor(updatedSecondColony);
    final updatedBuildCost =
        OpenDeadlockGame.buildCostFor(updatedSecondColony.construction);
    final updatedBuildTurns = (updatedBuildCost -
            updatedSecondColony.storedIndustry +
            updatedProjection.constructionWork -
            1) ~/
        updatedProjection.constructionWork;
    final updatedBuildEta = updatedProjection.willCompleteConstruction
        ? 'complete this turn'
        : '$updatedBuildTurns ${updatedBuildTurns == 1 ? 'turn' : 'turns'}';

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: game,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Apply Balanced focus to 1 colony'),
      240,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 8,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(TextButton, 'Apply Balanced focus to 1 colony'),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Queue Colony Hub in 1 colony'),
      240,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 8,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(TextButton, 'Queue Colony Hub in 1 colony'),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Colonies'),
      420,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 10,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Focus Balanced'), findsWidgets);
    expect(
      find.text(
        'Build Colony Hub: ${updatedSecondColony.storedIndustry}/$updatedBuildCost ${updatedProjection.constructionWork > 0 ? '+' : ''}${updatedProjection.constructionWork}, $updatedBuildEta',
      ),
      findsOneWidget,
    );
  });

  testWidgets('game screen summarizes pending colony builds', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final sample = OpenDeadlockGame.sample(sessionId: 'pending-builds-ui');
    final newHaven = sample.colonyById('new-haven');
    final newHavenProjection = sample.colonyProductionFor(newHaven);
    final newHavenBuildCost =
        OpenDeadlockGame.buildCostFor(newHaven.construction);
    final readyNewHaven = newHaven.copyWith(
      storedIndustry: newHavenBuildCost - newHavenProjection.constructionWork,
    );
    const secondColony = Colony(
      id: 'second-haven',
      name: 'Second Haven',
      ownerId: 'humans',
      x: 1,
      y: 2,
      population: 3,
      morale: 68,
      construction: 'Factory',
      storedIndustry: 6,
      completedBuildings: <String>[],
    );
    final game = sample.copyWith(
      tiles: sample.tiles.map((tile) {
        if (tile.x == secondColony.x && tile.y == secondColony.y) {
          return tile.copyWith(
            ownerId: secondColony.ownerId,
            colonyId: secondColony.id,
            explored: true,
            exploredBy: <String>[secondColony.ownerId],
          );
        }
        return tile;
      }).toList(),
      colonies: sample.colonies.map((colony) {
        if (colony.id == readyNewHaven.id) {
          return readyNewHaven;
        }
        return colony;
      }).followedBy(const <Colony>[secondColony]).toList(),
    );
    final readyProjection = game.colonyProductionFor(readyNewHaven);
    final secondProjection = game.colonyProductionFor(secondColony);
    final secondBuildCost =
        OpenDeadlockGame.buildCostFor(secondColony.construction);
    final secondTurns = (secondBuildCost -
            secondColony.storedIndustry +
            secondProjection.constructionWork -
            1) ~/
        secondProjection.constructionWork;

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: game,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Pending Builds'),
      420,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 12,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Pending Builds'), findsOneWidget);
    expect(find.text('2 builds'), findsOneWidget);
    expect(find.text('1 this turn'), findsOneWidget);
    expect(find.text('New Haven: Completes this turn'), findsOneWidget);
    expect(
      find.text(
        'Colony Hub: ${readyNewHaven.storedIndustry}/$newHavenBuildCost industry (+${readyProjection.constructionWork}/turn)',
      ),
      findsOneWidget,
    );
    expect(find.text('$secondTurns turns'), findsOneWidget);
    expect(
      find.text(
        'Factory: ${secondColony.storedIndustry}/$secondBuildCost industry (+${secondProjection.constructionWork}/turn)',
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('Completes this turn').last).dy,
      lessThan(tester.getTopLeft(find.text('$secondTurns turns')).dy),
    );
  });

  testWidgets('game screen shows colony unrest penalties', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final sample = OpenDeadlockGame.sample(sessionId: 'unrest-ui');
    final game = sample.copyWith(
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'new-haven') {
          return colony;
        }
        return colony.copyWith(morale: 24);
      }).toList(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: game,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('24%'), findsOneWidget);
    expect(
      find.text('Unrest - -2 industry, -1 research, -2 credits.'),
      findsOneWidget,
    );
    expect(find.text('7 food / 5 ind / 2 res / 5 cred'), findsOneWidget);
  });

  testWidgets('game screen shows maintenance shortfall warnings',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final game = _maintenanceShortfallGame();
    final projection = game.colonyProductionFor(game.colonyById('new-haven'));
    final grossCredits = projection.output.credits + projection.buildingUpkeep;

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: game,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text(
        '$grossCredits gross - ${projection.buildingUpkeep} upkeep = ${projection.output.credits} net',
      ),
      findsOneWidget,
    );
    expect(find.text('Maintenance'), findsOneWidget);
    expect(find.text('3 credit shortfall, -9 morale'), findsOneWidget);
    expect(find.textContaining('upkeep shortfall -9'), findsOneWidget);
  });

  testWidgets('game screen shows severe unrest riot damage', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final sample = OpenDeadlockGame.sample(sessionId: 'riot-ui');
    final game = sample.copyWith(
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'new-haven') {
          return colony;
        }
        return colony.copyWith(morale: 10);
      }).toList(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: game,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('10%'), findsOneWidget);
    expect(
      find.text(
        'Riot - -2 industry, -1 research, -2 credits. '
        'Riots destroy 4 stored industry.',
      ),
      findsOneWidget,
    );
    expect(find.text('Riot Loss'), findsOneWidget);
    expect(find.text('-4 stored industry / turn'), findsOneWidget);
  });

  testWidgets('game screen can change faction tax policy', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: OpenDeadlockGame.sample(sessionId: 'tax-policy-ui'),
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.textContaining('Balanced - No tax pressure.'),
      find.byType(ListView),
      const Offset(0, -260),
      maxIteration: 8,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Balanced - No tax pressure.').last);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('High - +3 credits, -2 morale.').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
        find.textContaining('High - +3 credits, -2 morale.'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('7 food / 7 ind / 3 res / 12 cred'),
      find.byType(ListView),
      const Offset(0, 360),
      maxIteration: 8,
    );
    await tester.pumpAndSettle();

    expect(find.text('7 food / 7 ind / 3 res / 12 cred'), findsOneWidget);
  });

  testWidgets('game screen can make peace and show treaty trade',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: OpenDeadlockGame.sample(sessionId: 'diplomacy-trade-ui'),
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('No treaty trade'),
      420,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 12,
    );
    await tester.pumpAndSettle();

    expect(find.text('Strength 14 vs 15'), findsOneWidget);
    expect(find.text('Intel scan: 5 sectors / 6 credits'), findsOneWidget);
    expect(find.text('No visible project to sabotage'), findsOneWidget);
    expect(find.text('Trade Routes'), findsOneWidget);
    expect(find.text('+0 credits / turn from 0 routes'), findsOneWidget);
    expect(
      find.text('Make peace or alliance treaties to open treaty trade.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Scan').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Intel up to date'), findsOneWidget);
    expect(
        find.text('Sabotage Redoubt: 4 industry / 10 credits'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Sabotage').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('No visible project to sabotage'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Tactical Log'),
      find.byType(ListView),
      const Offset(0, -320),
      maxIteration: 8,
    );
    await tester.pumpAndSettle();

    expect(find.text('Sabotage complete'), findsWidgets);
    expect(find.text('Target'), findsOneWidget);
    expect(find.text('Redoubt'), findsOneWidget);
    expect(find.text('4 stored industry'), findsOneWidget);
    expect(find.text('No protection'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('War'),
      -420,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 12,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('War').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Peace').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Trade +2 credits / turn'), findsOneWidget);
    expect(find.text('+2 credits / turn from 1 route'), findsOneWidget);
    expect(find.text('Peace +2'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Peace'),
      -420,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 12,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Peace').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alliance').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Trade +4 credits / turn'), findsOneWidget);
    expect(find.text('+4 credits / turn from 1 route'), findsOneWidget);
    expect(find.text('Alliance +4'), findsOneWidget);
    expect(find.text('Alliance intel shared'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('7 food / 7 ind / 3 res / 13 cred'),
      -420,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 12,
    );
    await tester.pumpAndSettle();

    expect(find.text('7 food / 7 ind / 3 res / 13 cred'), findsOneWidget);
  });

  testWidgets('game screen shows conquest victory progress', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame:
              OpenDeadlockGame.sample(sessionId: 'victory-progress-ui'),
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('1/2 colonies / 50%'),
      find.byType(ListView),
      const Offset(0, -260),
      maxIteration: 8,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Rank'), findsOneWidget);
    expect(find.text('#1 / 2 | 155 pts'), findsOneWidget);
    expect(find.text('Rank 1 | 155 pts'), findsOneWidget);
    expect(find.text('Rank 2 | 143 pts'), findsOneWidget);
    expect(find.text('Victory'), findsOneWidget);
    expect(find.text('1/2 colonies / 50%'), findsOneWidget);
    expect(find.text('Science'), findsOneWidget);
    expect(find.text('0/4 research / 0%'), findsOneWidget);
    expect(
      find.text('Human | 1/2 colonies | 0/4 research | 1 units | 16 sectors'),
      findsOneWidget,
    );
  });

  testWidgets('game screen shows configured victory paths', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final game = OpenDeadlockGame.sample(
      sessionId: 'victory-paths-ui',
    ).copyWith(
      victoryCondition: OpenDeadlockGame.victoryConditionScience,
      scoreTurnLimit: 20,
    );
    final activeScore = game.factionScoreFor(game.activeFactionId);
    final activeSummary = game.worldSummaryFor(game.activeFactionId);

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: game,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var scroll = 0; scroll < 20; scroll += 1) {
      if (find.text('Victory Paths').evaluate().isNotEmpty) {
        break;
      }
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -480));
      await tester.pumpAndSettle();
    }
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Victory Paths'), findsOneWidget);
    expect(find.text('Condition'), findsWidgets);
    expect(find.text('Science'), findsWidgets);
    expect(find.text('Conquest Path'), findsOneWidget);
    expect(find.text('Science Path'), findsOneWidget);
    expect(find.text('Disabled'), findsOneWidget);
    expect(find.text('Score Limit'), findsOneWidget);
    expect(find.text('Turn 20'), findsOneWidget);
    expect(find.text(activeScore.factionName), findsWidgets);
    expect(
      find.text(
        'Science ${activeSummary.scienceVictoryProgressLabel} / ${activeSummary.scienceVictorySharePercent}% | Score ${activeScore.total} pts | Deadline active',
      ),
      findsOneWidget,
    );
  });

  testWidgets('game screen marks defeated factions in world rankings',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: _defeatedWorldOverviewGame(),
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.textContaining('Defeated | Tarth'),
      420,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 12,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
        find.textContaining('Defeated | Tarth | 0/3 colonies'), findsOneWidget);
    expect(
        find.textContaining(RegExp(r'^Defeated \| \d+ pts$')), findsOneWidget);
    expect(find.textContaining('Defeated | '), findsWidgets);
  });

  testWidgets('game screen shows a science victory banner', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final sample = OpenDeadlockGame.sample(sessionId: 'science-victory-ui');
    final scienceWinner = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id != 'humans') {
          return faction;
        }
        return faction.copyWith(
          completedResearch: OpenDeadlockGame.coreResearchOptions,
          researchProject: 'Future Studies',
        );
      }).toList(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: scienceWinner,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Human Assembly wins'), findsWidgets);
    expect(
      find.text('Human Assembly completed every core research project.'),
      findsOneWidget,
    );
  });

  testWidgets('game screen shows post-game stats after victory',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final sample = OpenDeadlockGame.sample(sessionId: 'post-game-stats-ui');
    final scienceWinner = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id != 'humans') {
          return faction;
        }
        return faction.copyWith(
          completedResearch: OpenDeadlockGame.coreResearchOptions,
          researchProject: 'Future Studies',
        );
      }).toList(),
      reports: const <TurnReport>[
        TurnReport(
          title: 'Survey Team defeated Pact Recon',
          message: 'Survey Team won the final battle.',
          category: TurnReport.categoryBattle,
        ),
      ],
    );
    final scores = scienceWinner.factionScores();
    final winningScore = scores.firstWhere(
      (score) => score.factionId == scienceWinner.winningFactionId,
    );
    final winningSummary =
        scienceWinner.worldSummaryFor(winningScore.factionId);

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: scienceWinner,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Post-game Stats'), findsOneWidget);
    expect(find.text('Victory Type'), findsOneWidget);
    expect(find.text('Science'), findsWidgets);
    expect(find.text('Final Turn'), findsOneWidget);
    expect(find.text('Turn 1'), findsWidgets);
    expect(find.text('Research completed every core project'), findsOneWidget);
    expect(find.text('1 battle logged'), findsOneWidget);
    expect(find.text('Final Rankings'), findsOneWidget);
    expect(find.text('1. ${winningScore.factionName}'), findsOneWidget);
    expect(
      find.text(
        '${winningScore.total} pts | ${winningSummary.victoryProgressLabel} | ${winningSummary.totalPopulation} pop | ${winningSummary.unitCount} units',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Score Breakdown: Colonies ${winningScore.colonyScore} | Sectors ${winningScore.sectorScore} | Population ${winningScore.populationScore} | Military ${winningScore.militaryScore} | Science ${winningScore.scienceScore} | Reserves ${winningScore.reserveScore}',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Output: ${winningSummary.projectedProduction.food} food / ${winningSummary.projectedProduction.industry} ind / ${winningSummary.projectedProduction.research} res / ${winningSummary.projectedProduction.credits} cred | Science ${winningSummary.scienceVictoryProgressLabel}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('game screen shows score victory route', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final scoreWinner = OpenDeadlockGame.sample(
      sessionId: 'score-victory-ui',
    ).copyWith(
      turn: 20,
      scoreTurnLimit: 20,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: scoreWinner,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Human Assembly wins'), findsWidgets);
    expect(find.text('Human Assembly has the highest score at turn 20.'),
        findsOneWidget);
    expect(find.text('Victory Type'), findsOneWidget);
    expect(find.text('Score'), findsWidgets);
    expect(find.text('Held the highest score when the turn limit expired'),
        findsOneWidget);
  });

  testWidgets('selected local unit shows legal movement hints', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: OpenDeadlockGame.sample(sessionId: 'move-hints'),
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('action-hint-move-2-1')),
        findsNothing);

    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey<String>('terrain-3-1'))),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('action-hint-move-2-1')),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('action-hint-move-3-2')),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('action-hint-move-3-0')),
        findsNothing);
    expect(find.byKey(const ValueKey<String>('action-hint-move-4-1')),
        findsOneWidget);
  });

  testWidgets('selected local unit shows treaty passage hints', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final sample = OpenDeadlockGame.sample(sessionId: 'treaty-passage-ui');
    final passageGame = sample
        .copyWith(
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
        )
        .applyCommand(
          const SetDiplomacyStatusCommand(
            factionId: 'humans',
            targetFactionId: 'rebels',
            status: OpenDeadlockGame.diplomacyStatusPeace,
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: passageGame,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey<String>('terrain-3-1'))),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('action-hint-move-4-1')),
        findsOneWidget);
  });

  testWidgets('selected local unit shows attack and assault hints',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final sample = OpenDeadlockGame.sample(sessionId: 'battle-hints');
    final battleGame = sample.copyWith(
      tiles: sample.tiles.map((tile) {
        if (tile.x == 3 && tile.y == 2) {
          return tile.copyWith(ownerId: 'rebels', colonyId: 'redoubt');
        }
        return tile;
      }).toList(),
      colonies: sample.colonies.map((colony) {
        if (colony.id == 'redoubt') {
          return Colony(
            id: colony.id,
            name: colony.name,
            ownerId: colony.ownerId,
            x: 3,
            y: 2,
            population: colony.population,
            morale: colony.morale,
            construction: colony.construction,
            storedIndustry: colony.storedIndustry,
            completedBuildings: colony.completedBuildings,
          );
        }
        return colony;
      }).toList(),
      units: sample.units.map((unit) {
        if (unit.id == 'rebel-scout') {
          return unit.copyWith(x: 2, y: 1);
        }
        return unit;
      }).toList(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: battleGame,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey<String>('terrain-3-1'))),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('action-hint-attack-2-1')),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('action-hint-assault-3-2')),
        findsOneWidget);
    expect(
      find.byTooltip(
          'Attack Pact Recon: Deal 2, counter 3, you 2/5, target 3/5, both survive, damaged risk'),
      findsOneWidget,
    );
    expect(
      find.byTooltip(
          'Assault Redoubt: 5 vs 5, repelled, you 1/5, 3 pop / 26 morale, critical risk'),
      findsOneWidget,
    );
    expect(find.text('Combat Preview'), findsOneWidget);
    expect(find.text('Attack Pact Recon'), findsOneWidget);
    expect(
      find.text('Survey Team | scout | 5/5 HP | 3 atk / 1 def'),
      findsNWidgets(2),
    );
    expect(
      find.text('Pact Recon | scout | 5/5 HP | 3 atk / 1 def'),
      findsOneWidget,
    );
    expect(
      find.text('You 2 HP | target 3 HP | both survive | damaged risk'),
      findsOneWidget,
    );
    expect(
      find.text(
          'Deal 2, counter 3, you 2/5, target 3/5, both survive, damaged risk'),
      findsOneWidget,
    );
    expect(find.text('Assault Redoubt'), findsOneWidget);
    expect(
      find.text('Redoubt | colony | 4 pop / 61 morale | 5 defense'),
      findsOneWidget,
    );
    expect(
      find.text('You 1 HP | 3 pop / 26 morale | repelled | critical risk'),
      findsOneWidget,
    );
    expect(
      find.text('5 vs 5, repelled, you 1/5, 3 pop / 26 morale, critical risk'),
      findsOneWidget,
    );
  });

  testWidgets('game screen flags lethal combat previews', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final sample = OpenDeadlockGame.sample(sessionId: 'lethal-preview-ui');
    final lethalGame = sample.copyWith(
      tiles: sample.tiles.map((tile) {
        if (tile.x == 4 && tile.y == 1) {
          return tile.copyWith(
            explored: true,
            exploredBy: const <String>['humans', 'rebels'],
          );
        }
        return tile;
      }).toList(),
      units: <Unit>[
        sample.unitById('human-scout'),
        const Unit(
          id: 'rebel-armor',
          name: 'Rebel Armor',
          ownerId: 'rebels',
          type: 'armor',
          x: 4,
          y: 1,
          movesRemaining: 1,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: lethalGame,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey<String>('terrain-3-1'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Combat Preview'), findsOneWidget);
    expect(find.text('Attack Rebel Armor'), findsOneWidget);
    expect(
      find.textContaining('unit lost, lethal risk'),
      findsOneWidget,
    );
  });

  testWidgets('game screen shows recent battle log details', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final battleGame =
        OpenDeadlockGame.sample(sessionId: 'battle-log-ui').copyWith(
      reports: const <TurnReport>[
        TurnReport(
          title: 'Redoubt changed hands',
          message:
              'Survey Team overcame 4 defense with 5 assault power and took control of Redoubt.',
          category: TurnReport.categoryBattle,
          details: <String, String>{
            'kind': 'colony',
            'attackerName': 'Survey Team',
            'colonyName': 'Redoubt',
            'x': '6',
            'y': '3',
            'attackPower': '5',
            'defensePower': '4',
            'attackerHealth': '4',
            'attackerSurvived': 'true',
            'colonyCaptured': 'true',
            'previousPopulation': '2',
            'previousMorale': '80',
            'population': '1',
            'morale': '45',
            'populationDelta': '-1',
            'moraleDelta': '-35',
          },
        ),
        TurnReport(
          title: 'Pact Recon attacked Survey Team',
          message:
              'Pact Recon dealt 2 damage and survived. Survey Team countered for 1 damage and survived.',
          category: TurnReport.categoryBattle,
          details: <String, String>{
            'kind': 'unit',
            'attackerName': 'Pact Recon',
            'defenderName': 'Survey Team',
            'x': '4',
            'y': '3',
            'attackDamage': '2',
            'counterDamage': '1',
            'attackerHealth': '3',
            'defenderHealth': '4',
            'attackerSurvived': 'true',
            'defenderSurvived': 'true',
          },
        ),
        TurnReport(
          title: 'New Haven: Scout Patrol completed',
          message: 'New Haven finished Scout Patrol.',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: battleGame,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey<String>('latest-battle-summary')),
        findsOneWidget);
    expect(find.text('Latest Battle'), findsOneWidget);
    expect(find.text('Sector 7, 4'), findsOneWidget);
    expect(find.text('Redoubt changed hands'), findsWidgets);
    expect(find.text('5 attack vs 4 defense'), findsWidgets);
    expect(find.text('-1 pop / -35 morale'), findsWidgets);
    expect(find.text('1 pop / 45 morale'), findsWidgets);
    expect(find.text('Survey Team captured Redoubt'), findsWidgets);

    for (var scroll = 0;
        scroll < 18 && find.text('Tactical Log').evaluate().isEmpty;
        scroll += 1) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -480));
      await tester.pumpAndSettle();
    }

    expect(tester.takeException(), isNull);
    expect(find.text('Tactical Log'), findsOneWidget);
    expect(find.text('2 recent'), findsOneWidget);
    expect(find.text('Redoubt changed hands'), findsWidgets);
    expect(find.text('5 attack vs 4 defense'), findsWidgets);
    expect(find.text('-1 pop / -35 morale'), findsWidgets);
    expect(find.text('1 pop / 45 morale'), findsWidgets);
    expect(find.text('Survey Team captured Redoubt'), findsWidgets);
    expect(find.text('Pact Recon attacked Survey Team'), findsWidgets);
    expect(find.text('Pact Recon 2 / Survey Team 1'), findsOneWidget);
    expect(find.text('Pact Recon 3 / Survey Team 4'), findsOneWidget);
    expect(
      find.text('Pact Recon survived / Survey Team survived'),
      findsOneWidget,
    );
  });

  testWidgets('game screen groups recent reports into a news summary',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final newsGame =
        OpenDeadlockGame.sample(sessionId: 'news-summary-ui').copyWith(
      reports: const <TurnReport>[
        TurnReport(
          title: 'Pact Recon attacked Survey Team',
          message: 'Pact Recon dealt 2 damage.',
          category: TurnReport.categoryBattle,
          details: <String, String>{
            'kind': 'unit',
          },
        ),
        TurnReport(
          title: 'New Haven: Scout Patrol completed',
          message: 'New Haven finished Scout Patrol.',
        ),
        TurnReport(
          title: 'New Haven: food shortage',
          message:
              'Population changed by -1 and morale changed by -8 after a food shortage.',
        ),
        TurnReport(
          title: 'Human Assembly: Hydroponics researched',
          message: 'Food output increased.',
        ),
        TurnReport(
          title: 'Tax policy changed',
          message: 'Human Assembly adopted High Taxes.',
        ),
        TurnReport(
          title: 'Outpost 4-2 founded',
          message: 'Survey Team established a new colony.',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: newsGame,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var scroll = 0;
        scroll < 12 && find.text('News Summary').evaluate().isEmpty;
        scroll += 1) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -420));
      await tester.pumpAndSettle();
    }

    expect(tester.takeException(), isNull);
    expect(find.text('News Summary'), findsOneWidget);
    expect(find.text('6 categories / 6 reports'), findsOneWidget);
    expect(find.text('Attack (1)'), findsOneWidget);
    expect(find.text('Unit Production (1)'), findsOneWidget);
    expect(find.text('Population & Morale (1)'), findsOneWidget);
    expect(find.text('Research (1)'), findsOneWidget);
    expect(find.text('Economy (1)'), findsOneWidget);
    expect(find.text('Expansion (1)'), findsOneWidget);
    expect(find.text('New Haven: Scout Patrol completed'), findsWidgets);
    expect(find.text('Human Assembly: Hydroponics researched'), findsWidgets);
  });

  testWidgets('game screen can recover a damaged unit', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final sample = OpenDeadlockGame.sample(sessionId: 'recover-unit-ui');
    final damaged = sample.copyWith(
      units: sample.units.map((unit) {
        if (unit.id != 'human-scout') {
          return unit;
        }
        return unit.copyWith(health: 2);
      }).toList(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: damaged,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey<String>('terrain-3-1'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('2/5'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Recover Unit'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Recover Unit'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('3/5'), findsOneWidget);
    expect(find.text('0/2'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Recover Unit'), findsNothing);
  });

  testWidgets('game screen can rush colony construction with credits',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: OpenDeadlockGame.sample(sessionId: 'rush-build-ui'),
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rush +12'), findsOneWidget);

    final rushButton = find.widgetWithText(OutlinedButton, 'Rush +12');
    await tester.scrollUntilVisible(
      rushButton,
      260,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(rushButton);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('22/24 industry stored (+7)'), findsOneWidget);
    expect(find.text('Rush Build'), findsOneWidget);
  });

  testWidgets('game screen shows housing capacity in colony details',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final sample = OpenDeadlockGame.sample(sessionId: 'housing-capacity-ui');
    final capped = sample.copyWith(
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'new-haven') {
          return colony;
        }
        return colony.copyWith(
          population: OpenDeadlockGame.basePopulationCapacity +
              OpenDeadlockGame.housingPopulationCapacityBonus,
          construction: 'Apartment Complex',
          completedBuildings: const <String>[
            'Housing',
            'Factory',
            'Research Lab',
          ],
        );
      }).toList(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: capped,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('12/12'), findsOneWidget);
    expect(find.text('0 pop / +2 morale (housing cap)'), findsOneWidget);
    expect(find.text('Upkeep'), findsOneWidget);
    expect(find.text('2 credits'), findsOneWidget);
    expect(find.text('Apartment Complex'), findsOneWidget);
    expect(find.text('Build Info'), findsOneWidget);
    expect(
      find.text(
        'Cost 18 industry / Upkeep 1 credit / '
        'Produces +4 population capacity / Requires Housing',
      ),
      findsOneWidget,
    );
  });

  testWidgets('game screen can queue armor when infrastructure is ready',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final sample = OpenDeadlockGame.sample(sessionId: 'armor-build-ui');
    final armored = sample.copyWith(
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'new-haven') {
          return colony;
        }
        return colony.copyWith(
          construction: 'Scout Patrol',
          completedBuildings: const <String>['Barracks', 'Factory'],
        );
      }).toList(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: armored,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Scout Patrol'),
      find.byType(ListView),
      const Offset(0, -260),
      maxIteration: 8,
    );
    await tester.pumpAndSettle();

    expect(find.text('Security'), findsOneWidget);
    expect(find.text('3 sabotage protection'), findsOneWidget);

    await tester.tap(find.text('Scout Patrol').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Armor Company').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Armor Company'), findsOneWidget);
    expect(find.text('0/30 industry stored (+10)'), findsOneWidget);
  });

  testWidgets('game screen can fund research with credits', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: OpenDeadlockGame.sample(sessionId: 'fund-research-ui'),
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Fund +8'),
      find.byType(ListView),
      const Offset(0, -420),
      maxIteration: 10,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Fund +8'));
    await tester.pumpAndSettle();
    expect(find.text('Fund +8'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Fund +8'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('8/10'), findsOneWidget);
    expect(find.text('Fund Research'), findsOneWidget);
  });

  testWidgets('game screen shows a prioritized tech roadmap', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final sample = OpenDeadlockGame.sample(sessionId: 'tech-roadmap-ui');
    final game = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id != 'humans') {
          return faction;
        }
        return faction.copyWith(
          researchProject: 'Defense Grid',
          completedResearch: <String>['Hydroponics'],
          resources: faction.resources.copyWith(research: 7),
        );
      }).toList(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: game,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Tech Roadmap'),
      420,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 12,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tech Roadmap'), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Defense Grid 7/16'), findsOneWidget);
    expect(find.text('Industrial Automation 0/12'), findsOneWidget);
    expect(find.text('Xenoarchaeology 0/14'), findsOneWidget);
    expect(find.text('Complete'), findsOneWidget);
    expect(find.text('Hydroponics 10/10'), findsOneWidget);
    expect(find.text('Repeatable'), findsOneWidget);
    expect(find.text('Future Studies 0/10'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Defense Grid 7/16')).dy,
      lessThan(tester.getTopLeft(find.text('Industrial Automation 0/12')).dy),
    );
  });

  testWidgets('game screen can run an active computer faction turn',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final aiTurnGame = OpenDeadlockGame.sample(
      sessionId: 'active-ai-turn',
    ).copyWith(activeFactionId: 'rebels');
    final plannedCommands = aiTurnGame.planComputerCommandsFor('rebels');
    final plannedLabel = plannedCommands.length == 1
        ? '1 planned'
        : '${plannedCommands.length} planned';

    expect(plannedCommands, isNotEmpty);

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: aiTurnGame,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ElevatedButton, 'Run AI'), findsOneWidget);
    expect(find.text('Turn 1'), findsWidgets);
    expect(find.textContaining('Tarth Legion'), findsWidgets);
    await tester.dragUntilVisible(
      find.text('AI Orders'),
      find.byType(ListView),
      const Offset(0, -420),
      maxIteration: 10,
    );
    await tester.pumpAndSettle();
    expect(find.text('AI Orders'), findsOneWidget);
    expect(find.text(plannedLabel), findsOneWidget);
    expect(
      find.text('Tactical 2 / Research 1 / Economy 4 / Movement 1'),
      findsOneWidget,
    );
    expect(find.text('Research'), findsWidgets);
    expect(find.text('Economy'), findsWidgets);
    expect(find.text('Tactical'), findsWidgets);
    expect(find.text('Movement'), findsWidgets);
    expect(find.text('AI Plan | Tarth Legion'), findsWidgets);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Run AI'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(ElevatedButton, 'End Turn'), findsOneWidget);
    expect(find.text('Turn 2'), findsWidgets);
    expect(find.textContaining('Human Assembly'), findsWidgets);
    expect(find.text('AI Orders'), findsNothing);
  });

  testWidgets('computer AI plan explains diplomacy reasons', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final sample = OpenDeadlockGame.sample(sessionId: 'ai-plan-reasons');
    final traderGame = sample.copyWith(
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

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: traderGame,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('AI Orders'),
      find.byType(ListView),
      const Offset(0, -420),
      maxIteration: 10,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text('Diplomacy with Human Assembly: Alliance'),
      findsOneWidget,
    );
    expect(
      find.text('Trader profile expects +2 credits/turn and shared map intel.'),
      findsOneWidget,
    );
  });

  testWidgets('game screen can load an invite from typed sync code',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final inviteCode = GameCodec.encodeShareCode(
      GameCodec.encodeGameInvite(
        OpenDeadlockGame.sample(sessionId: 'typed-invite'),
        invitedFactionId: 'rebels',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: OpenDeadlockGame.sample(sessionId: 'before-invite'),
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapSyncMenuItem(tester, 'Load Invite');

    expect(find.text('Load Invite'), findsOneWidget);

    await tester.enterText(find.byType(TextField), inviteCode);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Join'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Joined as Tarth Legion'), findsOneWidget);
    expect(find.text('Waiting for sync'), findsWidgets);
  });

  testWidgets('game screen can import an invite from a file', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final inviteCode = GameCodec.encodeShareCode(
      GameCodec.encodeGameInvite(
        OpenDeadlockGame.sample(sessionId: 'file-invite'),
        invitedFactionId: 'rebels',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: OpenDeadlockGame.sample(sessionId: 'before-file-invite'),
          resumeLatestSave: false,
          inviteFileReader: () async => inviteCode,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapSyncMenuItem(tester, 'Import Invite File');

    expect(tester.takeException(), isNull);
    expect(find.text('Invite file loaded: joined as Tarth Legion'),
        findsOneWidget);
    expect(find.text('Waiting for sync'), findsWidgets);
  });

  testWidgets('sync menu copies a single remote player invite', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final clipboardWrites = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final arguments = call.arguments as Map<dynamic, dynamic>;
          clipboardWrites.add(arguments['text'] as String);
        }
        return null;
      },
    );
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    final asyncGame =
        OpenDeadlockGame.sample(sessionId: 'menu-invite').applyCommand(
      const SetFactionControlCommand(
        factionId: 'rebels',
        controlMode: Faction.controlRemote,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: asyncGame,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sync'));
    await tester.pumpAndSettle();

    expect(find.text('Copy Invite'), findsOneWidget);
    expect(find.text('Save Invite'), findsOneWidget);

    await tester.tap(find.text('Copy Invite').last);
    await tester.pumpAndSettle();

    expect(find.text('Review Invite'), findsOneWidget);
    expect(find.text('Invite Tarth Legion to session menu-invite'),
        findsOneWidget);
    expect(find.text('Host'), findsOneWidget);
    expect(find.text('Human Assembly'), findsWidgets);
    expect(find.text('Guest'), findsOneWidget);
    expect(find.text('Tarth Legion'), findsWidgets);
    expect(clipboardWrites, isEmpty);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Review Invite'), findsNothing);
    expect(clipboardWrites, isEmpty);

    await tester.tap(find.byTooltip('Sync'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy Invite').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Copy Invite'));
    await tester.pumpAndSettle();

    final invite = GameCodec.decodeGameInvite(clipboardWrites.single);

    expect(tester.takeException(), isNull);
    expect(invite.sessionId, 'menu-invite');
    expect(invite.hostFactionId, 'humans');
    expect(invite.invitedFactionId, 'rebels');
    expect(find.text('Invite code copied for Tarth Legion'), findsOneWidget);
  });

  testWidgets('sync menu copies invites for multiple remote players',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(480, 900);
    tester.view.devicePixelRatio = 1;
    final clipboardWrites = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final arguments = call.arguments as Map<dynamic, dynamic>;
          clipboardWrites.add(arguments['text'] as String);
        }
        return null;
      },
    );
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    final sample = OpenDeadlockGame.sample(sessionId: 'multi-menu-invite');
    const traders = Faction(
      id: 'traders',
      name: 'Trade Compact',
      colorValue: 0xFF2CB67D,
      raceId: 'uva_mosk',
      isComputer: false,
      controlMode: Faction.controlRemote,
      resources:
          ResourceStockpile(food: 12, industry: 5, research: 0, credits: 9),
    );
    final asyncGame = sample.copyWith(
      factions: <Faction>[
        sample.factionById('humans')!,
        sample.factionById('rebels')!.copyWith(
              controlMode: Faction.controlRemote,
            ),
        traders,
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: asyncGame,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sync'));
    await tester.pumpAndSettle();

    expect(find.text('Copy Invite'), findsNothing);
    expect(find.text('Save Invite'), findsNothing);
    expect(find.text('Copy Invite: Tarth Legion'), findsOneWidget);
    expect(find.text('Save Invite: Tarth Legion'), findsOneWidget);
    expect(find.text('Copy Invite: Trade Compact'), findsOneWidget);
    expect(find.text('Save Invite: Trade Compact'), findsOneWidget);

    await tester.tap(find.text('Copy Invite: Trade Compact'));
    await tester.pumpAndSettle();

    expect(find.text('Review Invite'), findsOneWidget);
    expect(
      find.textContaining('Invite Trade Compact to session'),
      findsOneWidget,
    );
    expect(find.text('Human Assembly'), findsWidgets);
    expect(find.text('Trade Compact'), findsWidgets);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Copy Invite'));
    await tester.pumpAndSettle();

    final invite = GameCodec.decodeGameInvite(clipboardWrites.single);

    expect(tester.takeException(), isNull);
    expect(invite.sessionId, 'multi-menu-invite');
    expect(invite.hostFactionId, 'humans');
    expect(invite.invitedFactionId, 'traders');
    expect(find.text('Invite code copied for Trade Compact'), findsOneWidget);
  });

  testWidgets('game screen can apply an order package from typed sync code',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final initial = OpenDeadlockGame.sample(sessionId: 'typed-orders');
    final updated = initial.applyCommand(
      const SetColonyConstructionCommand(
        factionId: 'humans',
        colonyId: 'new-haven',
        construction: 'Factory',
      ),
    );
    final orderCode = GameCodec.encodeShareCode(
      GameCodec.encodeCommandPackage(updated),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: initial,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Last Sync'),
      find.byType(Scrollable).last,
      const Offset(0, -420),
      maxIteration: 18,
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Apply Orders'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Apply Orders'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Apply Orders'),
      ),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), orderCode);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Review Orders'), findsOneWidget);
    expect(find.text('1 new order from Human Assembly'), findsOneWidget);
    expect(find.text('Sender'), findsOneWidget);
    expect(find.text('Human Assembly'), findsWidgets);
    expect(find.text('Result'), findsOneWidget);
    expect(find.text('Turn 1 | Human Assembly'), findsWidgets);
    expect(find.text('Handoff'), findsOneWidget);
    expect(find.text('Your turn | Turn 1 | Human Assembly'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('1 orders'), findsNWidgets(2));
    expect(find.text('New Haven: build Factory'), findsOneWidget);
    expect(find.text('Incoming | Human Assembly'), findsOneWidget);
    expect(find.textContaining('1 cmd'), findsNothing);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Apply Orders'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text(
        'Applied 1 new order from Human Assembly. '
        'Next: Your turn | Turn 1 | Human Assembly',
      ),
      findsWidgets,
    );
    expect(find.textContaining('1 cmd'), findsWidgets);

    await _tapSyncMenuItem(tester, 'Apply Orders');
    await tester.enterText(find.byType(TextField), orderCode);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Review Orders'), findsOneWidget);
    expect(find.text('No new orders from Human Assembly'), findsOneWidget);
    expect(find.text('0 orders'), findsWidgets);
    expect(find.text('No unapplied orders in this package.'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Close'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text(
        'No new orders from Human Assembly. '
        'Next: Your turn | Turn 1 | Human Assembly',
      ),
      findsWidgets,
    );
    expect(find.textContaining('1 cmd'), findsWidgets);
  });

  testWidgets(
      'game screen shows remote handoff after guest applies host orders',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final sample = OpenDeadlockGame.sample(sessionId: 'guest-host-orders');
    final hostSeat = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id == 'rebels') {
          return faction.copyWith(controlMode: Faction.controlRemote);
        }
        return faction;
      }).toList(),
    );
    final guestSeat = GameCodec.decodeInvitedGame(
      GameCodec.encodeGameInvite(
        hostSeat,
        hostFactionId: 'humans',
        invitedFactionId: 'rebels',
      ),
    );
    final hostAfter = hostSeat.applyCommand(
      const MoveUnitCommand(
        factionId: 'humans',
        unitId: 'human-scout',
        x: 4,
        y: 1,
      ),
    );
    final orderCode = GameCodec.encodeShareCode(
      GameCodec.encodeCommandPackage(hostAfter),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: guestSeat,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Waiting for sync'), findsWidgets);

    await _tapSyncMenuItem(tester, 'Apply Orders');
    await tester.enterText(find.byType(TextField), orderCode);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Review Orders'), findsOneWidget);
    expect(
      find.text('Waiting for sync | Turn 1 | Human Assembly'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'Apply Orders'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text(
        'Applied 1 new order from Human Assembly. '
        'Next: Waiting for sync | Turn 1 | Human Assembly',
      ),
      findsOneWidget,
    );
    expect(find.text('Waiting for sync'), findsWidgets);

    await tester.dragUntilVisible(
      find.text('Last Sync'),
      find.byType(ListView),
      const Offset(0, -420),
      maxIteration: 12,
    );
    await tester.pumpAndSettle();

    expect(find.text('Last Sync'), findsOneWidget);
    expect(
      find.text(
        'Applied 1 new order from Human Assembly. '
        'Next: Waiting for sync | Turn 1 | Human Assembly',
      ),
      findsWidgets,
    );
  });

  testWidgets('game screen can cancel an order package review', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final initial = OpenDeadlockGame.sample(sessionId: 'cancel-orders');
    final updated = initial.applyCommand(
      const SetColonyConstructionCommand(
        factionId: 'humans',
        colonyId: 'new-haven',
        construction: 'Factory',
      ),
    );
    final orderCode = GameCodec.encodeShareCode(
      GameCodec.encodeCommandPackage(updated),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: initial,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapSyncMenuItem(tester, 'Apply Orders');
    await tester.enterText(find.byType(TextField), orderCode);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Review Orders'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Review Orders'), findsNothing);
    expect(find.text('Applied 1 new order from Human Assembly'), findsNothing);
    expect(find.text('Colony Hub'), findsOneWidget);
  });

  testWidgets('game screen can undo the last pending local order',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: OpenDeadlockGame.sample(sessionId: 'undo-order'),
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Balanced - No production bias.'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('+2 industry, -1 food.').last);
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Pending Orders'),
      find.byType(Scrollable).last,
      const Offset(0, -420),
      maxIteration: 18,
    );
    await tester.pumpAndSettle();

    expect(find.text('1 pending'), findsOneWidget);
    expect(find.text('New Haven: focus Industry'), findsOneWidget);
    expect(
        find.widgetWithText(OutlinedButton, 'Undo Last Order'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Undo Last Order'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Undid New Haven: focus Industry'), findsOneWidget);
    expect(find.text('0 pending'), findsOneWidget);
    expect(find.text('No orders since the sync baseline.'), findsOneWidget);
    expect(
        find.widgetWithText(OutlinedButton, 'Undo Last Order'), findsNothing);
  });

  testWidgets('command bar can undo the last pending local order',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: OpenDeadlockGame.sample(sessionId: 'toolbar-undo-order'),
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Undo last order'), findsOneWidget);
    expect(find.text('0 cmd'), findsOneWidget);

    await tester.tap(find.textContaining('Balanced - No production bias.'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('+2 industry, -1 food.').last);
    await tester.pumpAndSettle();

    expect(find.text('Send 1 order'), findsOneWidget);
    expect(find.text('1 cmd'), findsOneWidget);

    await tester.tap(find.byTooltip('Undo last order'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Undid New Haven: focus Industry'), findsOneWidget);
    expect(find.text('Issue orders'), findsOneWidget);
    expect(find.text('0 cmd'), findsOneWidget);
  });

  testWidgets('game screen copies only orders since the sync baseline',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    final clipboardWrites = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final arguments = call.arguments as Map<dynamic, dynamic>;
          clipboardWrites.add(arguments['text'] as String);
        }
        return null;
      },
    );
    final sample = OpenDeadlockGame.sample(sessionId: 'copy-order-suffix');
    final synced = sample
        .applyCommand(
          const SetColonyConstructionCommand(
            factionId: 'humans',
            colonyId: 'new-haven',
            construction: 'Factory',
          ),
        )
        .copyWith(
          factions: sample.factions.map((faction) {
            if (faction.id != 'rebels') {
              return faction;
            }
            return faction.copyWith(controlMode: Faction.controlRemote);
          }).toList(),
        );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: synced,
          resumeLatestSave: false,
          textFileWriter: ({
            required String path,
            required String content,
            required String fileName,
          }) async {
            File(path).writeAsStringSync(content);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Balanced - No production bias.'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('+2 industry, -1 food.').last);
    await tester.pumpAndSettle();
    for (var i = 0; i < 16; i += 1) {
      if (find.text('Pending Orders').evaluate().isNotEmpty) {
        break;
      }
      await tester.drag(find.byType(ListView).last, const Offset(0, -420));
      await tester.pumpAndSettle();
    }

    expect(find.text('Pending Orders'), findsOneWidget);
    expect(find.text('1 pending'), findsOneWidget);
    expect(find.text('Command 1'), findsOneWidget);
    expect(find.text('New Haven: focus Industry'), findsOneWidget);
    expect(find.text('Turn 1 | Human Assembly'), findsOneWidget);
    expect(find.text('New Haven: build Factory'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Copy Orders'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Export Orders File'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Copy Orders'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Copy Orders'),
      ),
      findsOneWidget,
    );
    expect(
      find.text('1 new order from Human Assembly'),
      findsOneWidget,
    );
    expect(find.text('Sender'), findsOneWidget);
    expect(find.text('Share With'), findsOneWidget);
    expect(find.text('Tarth Legion'), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Handoff'),
      ),
      findsOneWidget,
    );
    expect(find.text('Your turn | Turn 1 | Human Assembly'), findsOneWidget);
    expect(find.text('Base State'), findsOneWidget);
    expect(find.text('Result State'), findsOneWidget);
    expect(find.text('Command 1'), findsWidgets);
    expect(find.text('New Haven: focus Industry'), findsWidgets);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(clipboardWrites, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);

    await _tapSyncMenuItem(tester, 'Copy Orders');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Copy Code'));
    await tester.pumpAndSettle();

    final package = GameCodec.decodeCommandPackage(clipboardWrites.single);
    final command = package.commands.single as SetColonyFocusCommand;

    expect(tester.takeException(), isNull);
    expect(
      find.text('Order code copied: 1 new order from Human Assembly'),
      findsOneWidget,
    );
    expect(package.baseCommandCount, 1);
    expect(package.commandCount, 2);
    expect(package.turn, 1);
    expect(package.activeFactionId, 'humans');
    expect(package.activeFactionName, 'Human Assembly');
    expect(package.exportedByFactionId, 'humans');
    expect(command.colonyId, 'new-haven');
    expect(command.focus, OpenDeadlockGame.colonyFocusIndustry);

    expect(find.text('0 pending'), findsOneWidget);
    expect(find.text('No orders since the sync baseline.'), findsOneWidget);

    await _tapSyncMenuItem(tester, 'Copy Orders');

    expect(find.text('No new orders since last sync'), findsOneWidget);
    expect(
      find.text(
        'This code will sync the current session but contains no new player orders.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'Copy Code'));
    await tester.pumpAndSettle();

    final emptyPackage = GameCodec.decodeCommandPackage(clipboardWrites.last);

    expect(clipboardWrites.length, 2);
    expect(emptyPackage.baseCommandCount, 2);
    expect(emptyPackage.commandCount, 2);
    expect(emptyPackage.commands, isEmpty);
    expect(
      find.text('Order code copied: no new orders since last sync'),
      findsOneWidget,
    );
  });

  testWidgets('game screen exports pending orders to a file', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1200);
    tester.view.devicePixelRatio = 1;
    final originalPlatform = FileSelectorPlatform.instance;
    final tempDirectory = Directory.systemTemp.createTempSync(
      'opendeadlock-order-export-',
    );
    final outputFile = File('${tempDirectory.path}/orders.odorders');
    final fakeFileSelector = _FakeFileSelector(savePath: outputFile.path);
    String? exportedContent;
    FileSelectorPlatform.instance = fakeFileSelector;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      FileSelectorPlatform.instance = originalPlatform;
      tempDirectory.deleteSync(recursive: true);
    });
    final sample = OpenDeadlockGame.sample(sessionId: 'export-order-file');
    final synced = sample
        .applyCommand(
          const SetColonyConstructionCommand(
            factionId: 'humans',
            colonyId: 'new-haven',
            construction: 'Factory',
          ),
        )
        .copyWith(
          factions: sample.factions.map((faction) {
            if (faction.id != 'rebels') {
              return faction;
            }
            return faction.copyWith(controlMode: Faction.controlRemote);
          }).toList(),
        );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: synced,
          resumeLatestSave: false,
          textFileWriter: ({
            required String path,
            required String content,
            required String fileName,
          }) async {
            exportedContent = content;
            File(path).writeAsStringSync(content);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Balanced - No production bias.'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('+2 industry, -1 food.').last);
    await tester.pumpAndSettle();
    for (var i = 0; i < 16; i += 1) {
      if (find.text('Pending Orders').evaluate().isNotEmpty) {
        break;
      }
      await tester.drag(find.byType(ListView).last, const Offset(0, -420));
      await tester.pumpAndSettle();
    }

    expect(find.text('1 pending'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Export Orders File'),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Export Orders File'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Export Orders File'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Export Orders File'),
      ),
      findsOneWidget,
    );
    expect(find.text('1 new order from Human Assembly'), findsOneWidget);
    expect(find.text('Share With'), findsOneWidget);
    expect(find.text('Tarth Legion'), findsWidgets);
    expect(find.text('Base State'), findsOneWidget);
    expect(find.text('Result State'), findsOneWidget);
    expect(find.text('New Haven: focus Industry'), findsWidgets);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Save File'));
    await tester.pumpAndSettle();

    expect(fakeFileSelector.savedSuggestedName,
        'opendeadlock-export-order-file-turn-1-humans.odorders');

    final package = GameCodec.decodeCommandPackage(
      exportedContent!,
    );
    final command = package.commands.single as SetColonyFocusCommand;

    expect(tester.takeException(), isNull);
    expect(package.baseCommandCount, 1);
    expect(package.commandCount, 2);
    expect(command.focus, OpenDeadlockGame.colonyFocusIndustry);
    expect(find.text('Order file saved: 1 new order from Human Assembly'),
        findsOneWidget);
    for (var i = 0; i < 8; i += 1) {
      if (find.text('0 pending').evaluate().isNotEmpty) {
        break;
      }
      await tester.drag(find.byType(Scrollable).last, const Offset(0, 320));
      await tester.pumpAndSettle();
    }
    expect(find.text('0 pending'), findsOneWidget);
  });

  testWidgets('game screen imports order packages from a file', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1200);
    tester.view.devicePixelRatio = 1;
    final initial = OpenDeadlockGame.sample(sessionId: 'import-order-file');
    final updated = initial.applyCommand(
      const SetColonyConstructionCommand(
        factionId: 'humans',
        colonyId: 'new-haven',
        construction: 'Factory',
      ),
    );
    final orderCode =
        GameCodec.encodeShareCode(GameCodec.encodeCommandPackage(updated));
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: initial,
          resumeLatestSave: false,
          textFileReader: () async => orderCode,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Last Sync'),
      find.byType(ListView),
      const Offset(0, -420),
      maxIteration: 12,
    );
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(OutlinedButton, 'Import Orders File'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Import Orders File'));
    await _pumpUntilFound(tester, find.text('Review Orders'));

    expect(find.text('Review Orders'), findsOneWidget);
    expect(find.text('1 new order from Human Assembly'), findsOneWidget);
    expect(find.text('New Haven: build Factory'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Apply Orders'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text(
        'Imported 1 new order from Human Assembly. '
        'Next: Your turn | Turn 1 | Human Assembly',
      ),
      findsWidgets,
    );
    expect(find.textContaining('1 cmd'), findsWidgets);
  });

  testWidgets('game screen exports snapshots to a file', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1200);
    tester.view.devicePixelRatio = 1;
    final originalPlatform = FileSelectorPlatform.instance;
    final tempDirectory = Directory.systemTemp.createTempSync(
      'opendeadlock-snapshot-export-',
    );
    final outputFile = File('${tempDirectory.path}/snapshot.odsave');
    final fakeFileSelector = _FakeFileSelector(savePath: outputFile.path);
    String? exportedContent;
    FileSelectorPlatform.instance = fakeFileSelector;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      FileSelectorPlatform.instance = originalPlatform;
      tempDirectory.deleteSync(recursive: true);
    });
    final snapshotGame =
        OpenDeadlockGame.sample(sessionId: 'snapshot-file').applyCommand(
      const SetColonyConstructionCommand(
        factionId: 'humans',
        colonyId: 'new-haven',
        construction: 'Factory',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: snapshotGame,
          resumeLatestSave: false,
          textFileWriter: ({
            required String path,
            required String content,
            required String fileName,
          }) async {
            exportedContent = content;
            File(path).writeAsStringSync(content);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapSyncMenuItem(tester, 'Save Snapshot File');

    final restored = GameCodec.decodeGame(exportedContent!);

    expect(tester.takeException(), isNull);
    expect(fakeFileSelector.savedSuggestedName,
        'opendeadlock-snapshot-file-turn-1-snapshot.odsave');
    expect(restored.sessionId, 'snapshot-file');
    expect(restored.commandHistory.length, 1);
    expect(restored.colonyById('new-haven').construction, 'Factory');
    expect(find.text('Snapshot file saved'), findsOneWidget);
  });

  testWidgets('game screen imports snapshots from a file', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1200);
    tester.view.devicePixelRatio = 1;
    final importedGame =
        OpenDeadlockGame.sample(sessionId: 'import-snapshot-file').applyCommand(
      const SetColonyConstructionCommand(
        factionId: 'humans',
        colonyId: 'new-haven',
        construction: 'Factory',
      ),
    );
    final snapshotCode =
        GameCodec.encodeShareCode(GameCodec.encodeGame(importedGame));
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: OpenDeadlockGame.sample(sessionId: 'before-snapshot'),
          resumeLatestSave: false,
          snapshotFileReader: () async => snapshotCode,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapSyncMenuItem(tester, 'Import Snapshot File');

    expect(tester.takeException(), isNull);
    expect(find.text('Snapshot file loaded'), findsOneWidget);
    expect(find.text('Factory'), findsWidgets);
    expect(find.textContaining('1 cmd'), findsWidgets);
  });

  testWidgets('game screen exports remote player invites to a file',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1200);
    tester.view.devicePixelRatio = 1;
    final originalPlatform = FileSelectorPlatform.instance;
    final tempDirectory = Directory.systemTemp.createTempSync(
      'opendeadlock-invite-export-',
    );
    final outputFile = File('${tempDirectory.path}/rebels.odinvite');
    final fakeFileSelector = _FakeFileSelector(savePath: outputFile.path);
    String? exportedContent;
    FileSelectorPlatform.instance = fakeFileSelector;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      FileSelectorPlatform.instance = originalPlatform;
      tempDirectory.deleteSync(recursive: true);
    });
    final asyncGame =
        OpenDeadlockGame.sample(sessionId: 'invite-file').applyCommand(
      const SetFactionControlCommand(
        factionId: 'rebels',
        controlMode: Faction.controlRemote,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: asyncGame,
          resumeLatestSave: false,
          textFileWriter: ({
            required String path,
            required String content,
            required String fileName,
          }) async {
            exportedContent = content;
            File(path).writeAsStringSync(content);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Save Invite'),
      find.byType(ListView),
      const Offset(0, -420),
      maxIteration: 12,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Save Invite'));
    await tester.pumpAndSettle();

    expect(find.text('Review Invite'), findsOneWidget);
    expect(find.text('Invite Tarth Legion to session invite-file'),
        findsOneWidget);
    expect(exportedContent, isNull);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Save Invite'));
    await tester.pumpAndSettle();

    final invite = GameCodec.decodeGameInvite(exportedContent!);
    final joined = GameCodec.decodeInvitedGame(exportedContent!);

    expect(tester.takeException(), isNull);
    expect(fakeFileSelector.savedSuggestedName,
        'opendeadlock-invite-file-invite-rebels.odinvite');
    expect(invite.sessionId, 'invite-file');
    expect(invite.hostFactionId, 'humans');
    expect(invite.invitedFactionId, 'rebels');
    expect(joined.factionById('rebels')!.isLocal, isTrue);
    expect(joined.factionById('humans')!.isRemote, isTrue);
    expect(find.text('Invite file saved for Tarth Legion'), findsOneWidget);
  });

  testWidgets('game screen can create and delete named save slots',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: OpenDeadlockGame.sample(sessionId: 'save-dialog'),
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapSyncMenuItem(tester, 'Save Local');

    expect(find.text('Save Game'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Named Test Slot');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    final store = await GameSaveStore.load();
    final savedSlots = await store.loadSlots();
    expect(savedSlots.single.name, 'Named Test Slot');
    expect(savedSlots.single.slotId.startsWith(GameSaveStore.manualSlotPrefix),
        isTrue);

    await _tapSyncMenuItem(tester, 'Load Local');

    expect(find.text('Load Game'), findsOneWidget);
    expect(find.text('Named Test Slot'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete Save'));
    await tester.pumpAndSettle();

    expect(find.text('No local saves remain.'), findsOneWidget);
    expect(await store.loadSlots(), isEmpty);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 20; attempt += 1) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 10));
  }
}

Future<void> _tapSyncMenuItem(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Sync'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

OpenDeadlockGame _defeatedWorldOverviewGame() {
  final sample = OpenDeadlockGame.sample(sessionId: 'defeated-world-ui');
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
      sample.factionById('rebels')!.copyWith(
            resources:
                sample.factionById('rebels')!.resources.copyWith(credits: 2000),
          ),
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
      if (tile.x == 6 && tile.y == 3) {
        return tile.copyWith(ownerId: 'humans');
      }
      return tile;
    }).toList(),
    colonies: <Colony>[
      sample.colonyById('new-haven'),
      sample.colonyById('redoubt').copyWith(ownerId: 'humans'),
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
      sample.unitById('human-scout'),
    ],
  );
}

OpenDeadlockGame _maintenanceShortfallGame() {
  final sample = OpenDeadlockGame.sample(sessionId: 'maintenance-ui');
  return sample.copyWith(
    factions: sample.factions.map((faction) {
      if (faction.id != 'humans') {
        return faction;
      }
      return faction.copyWith(
        raceId: 'tarth',
        traitIds: const <String>[],
      );
    }).toList(),
    colonies: sample.colonies.map((colony) {
      if (colony.id != 'new-haven') {
        return colony;
      }
      return colony.copyWith(
        completedBuildings: const <String>[
          'Apartment Complex',
          'Luxury Housing',
          'Farm Dome',
          'Factory',
          'Research Lab',
          'Militia Post',
          'Barracks',
        ],
      );
    }).toList(),
  );
}

class _FakeFileSelector extends Fake
    with MockPlatformInterfaceMixin
    implements FileSelectorPlatform {
  _FakeFileSelector({
    this.savePath,
  });

  final String? savePath;
  String? savedSuggestedName;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    return null;
  }

  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async {
    savedSuggestedName = options.suggestedName;
    final path = savePath;
    return path == null ? null : FileSaveLocation(path);
  }
}
