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
      find.byType(Scrollable).last,
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

    expect(find.text('Send 1 order'), findsWidgets);
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
    expect(
        find.widgetWithText(TextButton, 'Review Survey Team'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Fund +8'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(TextButton, 'Fund +8'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Fund +8'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Hydroponics 8/10, 2 left'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Fund +8'), findsNothing);

    await tester.ensureVisible(
      find.widgetWithText(TextButton, 'Review Survey Team'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Review Survey Team'));
    await tester.pumpAndSettle();

    await _scrollSidePanelUntilVisible(
      tester,
      find.text('Survey Team'),
      delta: const Offset(0, 420),
      maxScrolls: 24,
    );
    await tester.pumpAndSettle();

    expect(find.text('Survey Team'), findsWidgets);
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
      'opendeadlock.music_enabled': true,
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
    expect(find.byTooltip('Pause music'), findsOneWidget);
    await _scrollSidePanelUntilVisible(
      tester,
      find.text('Audio'),
      delta: const Offset(0, -360),
    );

    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('Effects'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Enabled'), findsNWidgets(2));
    expect(find.text('Cues'), findsOneWidget);
    expect(
        find.text('Orders, saves, sync, music, turn actions'), findsOneWidget);

    await tester.tap(find.byTooltip('Mute sound effects'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('opendeadlock.sound_effects_enabled'), isFalse);
    expect(find.byTooltip('Enable sound effects'), findsOneWidget);
    expect(find.text('Sound effects muted'), findsOneWidget);
    expect(find.text('Muted'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause music'));
    await tester.pumpAndSettle();

    expect(preferences.getBool('opendeadlock.music_enabled'), isFalse);
    expect(find.byTooltip('Resume music'), findsOneWidget);
    expect(find.text('Music paused'), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);
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
    tester.view.physicalSize = const Size(960, 960);
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
    expect(find.text('Survey Team'), findsWidgets);
  });

  testWidgets('game screen shows terrain catalog', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: OpenDeadlockGame.sample(sessionId: 'terrain-catalog-ui'),
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey<String>('terrain-2-2'))),
    );
    await tester.pumpAndSettle();

    await _scrollSidePanelUntilVisible(tester, find.text('Terrain Catalog'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Terrain Catalog'), findsOneWidget);
    expect(find.text('5 terrain types / Forest selected'), findsOneWidget);

    await tester.tap(find.text('Terrain Catalog'));
    await tester.pumpAndSettle();

    expect(find.text('Plains - Available'), findsOneWidget);
    expect(find.text('Forest - Selected'), findsOneWidget);
    expect(find.text('Ridge - Available'), findsOneWidget);
    expect(find.text('Water - Available'), findsOneWidget);
    expect(find.text('Ruins - Available'), findsOneWidget);
    expect(
        find.text('3 food / 1 industry / 0 research / 1 move'), findsOneWidget);
    expect(
        find.text('2 food / 2 industry / 0 research / 2 move'), findsOneWidget);
    expect(
        find.text('1 food / 3 industry / 0 research / 2 move'), findsOneWidget);
    expect(find.text('2 food / 0 industry / 1 research / Blocked'),
        findsOneWidget);
    expect(
        find.text('0 food / 1 industry / 3 research / 1 move'), findsOneWidget);
    expect(
      find.text('Research-bearing water, blocked until naval rules exist.'),
      findsOneWidget,
    );
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
    expect(find.text('Human Armor'), findsWidgets);
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

  testWidgets('game screen ranks sectors for active resource overlay',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final game = OpenDeadlockGame.sample(sessionId: 'overlay-ranking');
    final visibleTiles = game.tiles
        .where((tile) =>
            tile.isExploredBy(game.activeFactionId) &&
            OpenDeadlockGame.isTerrainPassable(tile.terrain))
        .toList(growable: false)
      ..sort((a, b) {
        final valueCompare = b.yields.industry.compareTo(a.yields.industry);
        if (valueCompare != 0) {
          return valueCompare;
        }
        final aTotal = a.yields.food + a.yields.industry + a.yields.research;
        final bTotal = b.yields.food + b.yields.industry + b.yields.research;
        final totalCompare = bTotal.compareTo(aTotal);
        if (totalCompare != 0) {
          return totalCompare;
        }
        final yCompare = a.y.compareTo(b.y);
        if (yCompare != 0) {
          return yCompare;
        }
        return a.x.compareTo(b.x);
      });
    final topTiles = visibleTiles.take(3).toList(growable: false);
    final ownedTopTiles =
        topTiles.where((tile) => tile.ownerId == game.activeFactionId).length;
    PlanetTile? bestOwnedEmpty;
    for (final tile in visibleTiles) {
      if (tile.ownerId == game.activeFactionId && tile.colonyId == null) {
        bestOwnedEmpty = tile;
        break;
      }
    }

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: game,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester
        .tap(find.byKey(const ValueKey<String>('map-overlay-industry')));
    await tester.pumpAndSettle();

    await _scrollSidePanelUntilVisible(
      tester,
      find.byKey(const ValueKey<String>('resource-overlay-intel')),
      maxScrolls: 56,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('resource-overlay-intel')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Resource Overlay'), findsOneWidget);
    expect(find.text('Industry'), findsWidgets);
    expect(find.text('Industry yield'), findsOneWidget);
    expect(
      find.text(
        '${topTiles.first.yields.industry} industry at Sector ${topTiles.first.x + 1}, ${topTiles.first.y + 1}',
      ),
      findsOneWidget,
    );
    expect(
      find.text('$ownedTopTiles of top ${topTiles.length} sectors'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Sector ${bestOwnedEmpty!.x + 1}, ${bestOwnedEmpty.y + 1} | ${bestOwnedEmpty.yields.food} food / ${bestOwnedEmpty.yields.industry} industry / ${bestOwnedEmpty.yields.research} research',
      ),
      findsOneWidget,
    );
    for (var index = 0; index < topTiles.length; index += 1) {
      final tile = topTiles[index];
      final ownerLabel = tile.ownerId == game.activeFactionId
          ? 'Owned'
          : tile.ownerId == null
              ? 'Neutral'
              : game.factionById(tile.ownerId)!.name;
      expect(
        find.text(
          'Sector ${tile.x + 1}, ${tile.y + 1} | ${tile.yields.industry} industry | $ownerLabel',
        ),
        findsOneWidget,
      );
    }

    await tester.tap(
      find.byKey(
        ValueKey<String>(
          'resource-overlay-target-1-${topTiles.first.x}-${topTiles.first.y}',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _scrollSidePanelUntilVisible(
      tester,
      find.text('Sector ${topTiles.first.x + 1}, ${topTiles.first.y + 1}'),
      delta: const Offset(0, 420),
      maxScrolls: 56,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text('Sector ${topTiles.first.x + 1}, ${topTiles.first.y + 1}'),
      findsWidgets,
    );
    expect(
      find.text(
        '${topTiles.first.yields.food} food / ${topTiles.first.yields.industry} industry / ${topTiles.first.yields.research} research',
      ),
      findsWidgets,
    );
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

    await _scrollSidePanelUntilVisible(
      tester,
      find.text('AI Profile'),
      delta: const Offset(0, -260),
      maxScrolls: 16,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('AI Profile'), findsOneWidget);
    expect(find.text('Researcher'), findsOneWidget);
    expect(find.text('Race Effects'), findsOneWidget);
    expect(find.text('+2 credits per colony'), findsOneWidget);
    expect(find.text('Build Priorities'), findsOneWidget);
    expect(find.text('Research labs, factories'), findsOneWidget);
    expect(find.text('Research Priorities'), findsOneWidget);
    expect(find.text('Xenoarchaeology, Industrial Automation'), findsOneWidget);
    expect(find.text('Diplomacy Bias'), findsOneWidget);
    expect(
      find.text('Avoids distractions while funding science'),
      findsOneWidget,
    );
    expect(find.text('Economy Bias'), findsOneWidget);
    expect(
      find.text('Funds research earlier and favors science focus'),
      findsOneWidget,
    );
    expect(find.text('Tactical Bias'), findsOneWidget);
    expect(
      find.text('Defends research tempo and sabotage exposure'),
      findsOneWidget,
    );
    expect(
      find.text(
          'Prioritizes research labs, science focus, and research projects.'),
      findsOneWidget,
    );
  });

  testWidgets('game screen shows race catalog', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final sample = OpenDeadlockGame.sample(sessionId: 'race-catalog-ui');
    final profiled = sample.copyWith(
      factions: sample.factions.map((faction) {
        if (faction.id != 'humans') {
          return faction;
        }
        return faction.copyWith(raceId: 'relu');
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

    await _scrollSidePanelUntilVisible(tester, find.text('Race Catalog'));
    await tester.ensureVisible(find.text('Race Catalog'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Race Catalog'), findsOneWidget);
    expect(find.text("7 races / Re'Lu active"), findsOneWidget);

    await tester.tap(find.text('Race Catalog'));
    await tester.pumpAndSettle();

    expect(find.text("Re'Lu - Active"), findsOneWidget);
    expect(find.text('Human - Available'), findsOneWidget);
    expect(find.text('Tarth - Available'), findsOneWidget);
    expect(
      find.textContaining('reveals full map'),
      findsWidgets,
    );
    expect(
      find.textContaining('prioritizes Xenoarchaeology'),
      findsWidgets,
    );
    expect(
      find.textContaining(
          'Aggressive militarists with stronger ground attacks.'),
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

  testWidgets('game screen summarizes opponent intel', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final sample = OpenDeadlockGame.sample(sessionId: 'opponent-intel-ui');
    final game = sample.copyWith(
      tiles: sample.tiles
          .map((tile) =>
              tile.colonyId == 'redoubt' ? tile.revealTo('humans') : tile)
          .toList(growable: false),
    );
    final rival = game.factionById('rebels')!;
    final activeStrength = game.militaryStrengthFor('humans');
    final rivalStrength = game.militaryStrengthFor(rival.id);
    final rivalScore = game.factionScoreFor(rival.id).total;
    final activeScore = game.factionScoreFor('humans').total;
    final visibleRivalUnits = game.units
        .where((unit) =>
            unit.ownerId == rival.id && game.isUnitVisibleTo('humans', unit))
        .length;
    final knownRivalColonies = game.colonies
        .where((colony) =>
            colony.ownerId == rival.id &&
            game.tileAt(colony.x, colony.y).isExploredBy('humans'))
        .length;
    final knownRivalColony = game.colonies
        .where((colony) =>
            colony.ownerId == rival.id &&
            game.tileAt(colony.x, colony.y).isExploredBy('humans'))
        .toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));
    final visibleRivalUnit = game.units
        .where((unit) =>
            unit.ownerId == rival.id && game.isUnitVisibleTo('humans', unit))
        .toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));
    final knownRivalSector = game.tiles
        .where(
            (tile) => tile.ownerId == rival.id && tile.isExploredBy('humans'))
        .toList(growable: false)
      ..sort((a, b) {
        final yComparison = a.y.compareTo(b.y);
        if (yComparison != 0) {
          return yComparison;
        }
        return a.x.compareTo(b.x);
      });
    final contactName = knownRivalColony.isNotEmpty
        ? knownRivalColony.first.name
        : visibleRivalUnit.isNotEmpty
            ? visibleRivalUnit.first.name
            : 'Sector ${knownRivalSector.first.x + 1}, ${knownRivalSector.first.y + 1}';
    final threatLabel = rivalStrength > activeStrength
        ? 'stronger threat'
        : rivalStrength < activeStrength
            ? 'weaker threat'
            : 'matched threat';
    final stanceHint = rivalStrength > activeStrength
        ? 'avoid exposed fights'
        : rivalStrength < activeStrength
            ? 'press military advantage'
            : 'scout before committing';
    final scoreDelta = rivalScore - activeScore;
    final scoreDeltaLabel = scoreDelta > 0 ? '+$scoreDelta' : '$scoreDelta';

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: game,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _scrollSidePanelUntilVisible(
      tester,
      find.byKey(const ValueKey<String>('opponent-intel')),
      maxScrolls: 48,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('opponent-intel')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Opponent Intel'), findsOneWidget);
    expect(find.text('1 rivals'), findsOneWidget);
    expect(find.text('1 active war'), findsWidgets);
    expect(
      find.text(
          '$visibleRivalUnits visible units / $knownRivalColonies known colonies'),
      findsWidgets,
    );
    expect(find.text('Tarth Legion'), findsWidgets);
    expect(
      find.text('War | $threatLabel | $rivalScore pts'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Strength $rivalStrength vs $activeStrength | Score $scoreDeltaLabel',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Profile Conqueror | $stanceHint'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('opponent-intel-view-rebels')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('opponent-intel-peace-rebels')),
      findsOneWidget,
    );

    await tester
        .tap(find.byKey(const ValueKey<String>('opponent-intel-peace-rebels')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('No active wars'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('opponent-intel-peace-rebels')),
      findsNothing,
    );

    await tester
        .tap(find.byKey(const ValueKey<String>('opponent-intel-view-rebels')));
    await tester.pumpAndSettle();

    await _scrollSidePanelUntilVisible(
      tester,
      find.text(contactName),
      delta: const Offset(0, 420),
      maxScrolls: 56,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(contactName), findsWidgets);
  });

  testWidgets('game screen summarizes map intel', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final game = OpenDeadlockGame.sample(sessionId: 'map-intel-ui');
    final exploredTiles = game.tiles
        .where((tile) => tile.isExploredBy(game.activeFactionId))
        .toList(growable: false);
    final ownedCount =
        exploredTiles.where((tile) => tile.ownerId == 'humans').length;
    final rivalCount = exploredTiles
        .where((tile) => tile.ownerId != null && tile.ownerId != 'humans')
        .length;
    final neutralCount =
        exploredTiles.where((tile) => tile.ownerId == null).length;
    final passableCount = exploredTiles
        .where((tile) => OpenDeadlockGame.isTerrainPassable(tile.terrain))
        .length;
    final emptyOwnedCount = exploredTiles
        .where((tile) =>
            tile.ownerId == 'humans' &&
            tile.colonyId == null &&
            OpenDeadlockGame.isTerrainPassable(tile.terrain))
        .length;
    final terrainCounts = <String, int>{};
    var food = 0;
    var industry = 0;
    var research = 0;
    PlanetTile? bestTile;
    for (final tile in exploredTiles) {
      terrainCounts[tile.terrain] = (terrainCounts[tile.terrain] ?? 0) + 1;
      food += tile.yields.food;
      industry += tile.yields.industry;
      research += tile.yields.research;
      final tileScore =
          tile.yields.food + tile.yields.industry + tile.yields.research;
      final bestScore = bestTile == null
          ? -1
          : bestTile.yields.food +
              bestTile.yields.industry +
              bestTile.yields.research;
      if (OpenDeadlockGame.isTerrainPassable(tile.terrain) &&
          tileScore > bestScore) {
        bestTile = tile;
      }
    }
    var dominantTerrain = terrainCounts.keys.first;
    for (final terrain in terrainCounts.keys.skip(1)) {
      final terrainCount = terrainCounts[terrain]!;
      final dominantCount = terrainCounts[dominantTerrain]!;
      if (terrainCount > dominantCount ||
          (terrainCount == dominantCount &&
              terrain.compareTo(dominantTerrain) < 0)) {
        dominantTerrain = terrain;
      }
    }

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: game,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _scrollSidePanelUntilVisible(
      tester,
      find.byKey(const ValueKey<String>('map-intel')),
      maxScrolls: 52,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('map-intel')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Map Intel'), findsOneWidget);
    expect(
      find.text('${exploredTiles.length}/${game.tiles.length} known'),
      findsOneWidget,
    );
    expect(
      find.text(
          '$ownedCount owned / $rivalCount rival / $neutralCount neutral'),
      findsOneWidget,
    );
    expect(
      find.text(
        '${OpenDeadlockGame.terrainLabelFor(dominantTerrain)} leads ${terrainCounts[dominantTerrain]} / $passableCount passable',
      ),
      findsOneWidget,
    );
    expect(
      find.text('$food food / $industry industry / $research research'),
      findsOneWidget,
    );
    expect(
      find.text('$emptyOwnedCount owned empty sectors'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Sector ${bestTile!.x + 1}, ${bestTile.y + 1} | ${OpenDeadlockGame.terrainLabelFor(bestTile.terrain)} | ${bestTile.yields.food} food / ${bestTile.yields.industry} industry / ${bestTile.yields.research} research',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('map-intel-select-best')),
      findsOneWidget,
    );

    await tester
        .tap(find.byKey(const ValueKey<String>('map-intel-select-best')));
    await tester.pumpAndSettle();

    await _scrollSidePanelUntilVisible(
      tester,
      find.text('Sector ${bestTile.x + 1}, ${bestTile.y + 1}'),
      delta: const Offset(0, 420),
      maxScrolls: 56,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text('Sector ${bestTile.x + 1}, ${bestTile.y + 1}'),
      findsWidgets,
    );
  });

  testWidgets('game screen summarizes session audit', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final game = OpenDeadlockGame.sample(sessionId: 'session-audit-ui');
    final commandFingerprint = GameCodec.fingerprintCommands(
      game.commandHistory.map((record) => record.command),
    );
    final stateFingerprint = GameCodec.fingerprintGame(game);
    final localSeats = game.factions.where((faction) => faction.isLocal).length;
    final computerSeats =
        game.factions.where((faction) => faction.isComputer).length;
    final remoteSeats =
        game.factions.where((faction) => faction.isRemote).length;

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: game,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _scrollSidePanelUntilVisible(
      tester,
      find.byKey(const ValueKey<String>('session-audit')),
      maxScrolls: 56,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('session-audit')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Session Audit'), findsOneWidget);
    expect(find.text('session-audit-ui'), findsWidgets);
    expect(find.text('Turn ${game.turn} | ${game.activeFaction.name}'),
        findsOneWidget);
    expect(
      find.text(Faction.controlModeLabelFor(game.activeFaction.controlMode)),
      findsWidgets,
    );
    expect(
      find.text('$localSeats local / $computerSeats AI / $remoteSeats remote'),
      findsOneWidget,
    );
    expect(
      find.text(OpenDeadlockGame.victoryConditionLabelFor(
        game.victoryCondition,
      )),
      findsWidgets,
    );
    expect(find.text('${game.commandHistory.length} recorded'), findsOneWidget);
    expect(find.text(_shortFingerprintForTest(commandFingerprint)),
        findsOneWidget);
    expect(
        find.text(_shortFingerprintForTest(stateFingerprint)), findsOneWidget);
    expect(
      find.text(GameCodec.turnHandoffLabelFor(
        turn: game.turn,
        activeFactionName: game.activeFaction.name,
        controlMode: game.activeFaction.controlMode,
      )),
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

  testWidgets('game screen shows colony focus catalog', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final sample = OpenDeadlockGame.sample(sessionId: 'focus-catalog-ui');
    final focused = sample.copyWith(
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'new-haven') {
          return colony;
        }
        return colony.copyWith(focus: OpenDeadlockGame.colonyFocusIndustry);
      }).toList(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: focused,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final focusCatalog = find.text('Focus Catalog').first;
    await _scrollSidePanelUntilVisible(tester, focusCatalog);
    await tester.ensureVisible(focusCatalog);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Focus Catalog'), findsOneWidget);
    expect(find.text('5 options / Industry active'), findsOneWidget);

    await tester.tap(focusCatalog);
    await tester.pumpAndSettle();

    expect(find.text('Industry - Active'), findsOneWidget);
    expect(find.text('Balanced - Available'), findsOneWidget);
    expect(find.text('Growth - Available'), findsOneWidget);
    expect(find.text('Research - Available'), findsOneWidget);
    expect(find.text('Revenue - Available'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('focus-catalog-select-research'),
      ),
      findsOneWidget,
    );
    expect(find.text('No production bias.'), findsWidgets);
    expect(find.text('+2 food, -1 industry.'), findsWidgets);
    expect(find.text('+2 industry, -1 food.'), findsWidgets);
    expect(find.text('+2 research, -1 industry.'), findsWidgets);
    expect(find.text('+3 credits, -1 research.'), findsWidgets);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('focus-catalog-select-research'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Research - Active'), findsOneWidget);
    expect(find.text('Industry - Available'), findsOneWidget);
    expect(find.text('5 options / Research active'), findsOneWidget);
    expect(find.text('7 food / 6 ind / 5 res / 9 cred'), findsOneWidget);
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

  testWidgets('game screen summarizes next turn forecast', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final game = OpenDeadlockGame.sample(sessionId: 'turn-forecast-ui');
    final colony = game.colonyById('new-haven');
    final projection = game.colonyProductionFor(colony);
    final output = projection.output + game.tradeIncomeFor('humans');
    final nextStores = game.activeFaction.resources + output;

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: game,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _scrollSidePanelUntilVisible(
      tester,
      find.byKey(const ValueKey<String>('turn-forecast')),
      maxScrolls: 40,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('turn-forecast')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Turn Forecast'), findsOneWidget);
    expect(
      find.text(
        '${output.food} food / ${output.industry} ind / ${output.research} res / ${output.credits} cred',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        '${nextStores.food} food / ${nextStores.industry} ind / ${nextStores.research} res / ${nextStores.credits} cred',
      ),
      findsOneWidget,
    );
    expect(find.text('No builds complete'), findsOneWidget);
    expect(find.textContaining('New Haven'), findsWidgets);
    expect(
      find.textContaining(
          'pop ${projection.populationChange > 0 ? '+' : ''}${projection.populationChange}'),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey<String>('turn-forecast-review-first')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('turn-forecast-row-new-haven')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('turn-forecast-review-first')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await _scrollSidePanelUntilVisible(
      tester,
      find.text('Population'),
      delta: const Offset(0, 420),
      maxScrolls: 40,
    );
    expect(find.text('Population'), findsOneWidget);
    expect(find.text('Morale'), findsOneWidget);
  });

  testWidgets('game screen prioritizes strategic advisor actions',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final sample = OpenDeadlockGame.sample(sessionId: 'strategic-advisor-ui');
    final woundedScout = sample.unitById('human-scout').copyWith(health: 2);
    final remainingResearch = OpenDeadlockGame.researchCostFor(
          sample.activeFaction.researchProject,
        ) -
        sample.activeFaction.resources.research;
    final affordableResearch = sample.activeFaction.resources.credits ~/
        OpenDeadlockGame.researchCreditCostPerPoint;
    final fundedResearch = remainingResearch < affordableResearch
        ? remainingResearch
        : affordableResearch;
    final fundCost = OpenDeadlockGame.fundResearchCostFor(fundedResearch);
    final game = sample.copyWith(
      units: sample.units
          .map((unit) => unit.id == woundedScout.id ? woundedScout : unit)
          .toList(growable: false),
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

    await _scrollSidePanelUntilVisible(
      tester,
      find.byKey(const ValueKey<String>('strategic-advisor')),
      maxScrolls: 45,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('strategic-advisor')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Strategic Advisor'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('strategic-advisor-open-top')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('strategic-advisor-row-1')),
      findsOneWidget,
    );
    expect(find.text('Recover Survey Team'), findsWidgets);
    expect(
      find.text(
        '2/${OpenDeadlockGame.maxHealthFor(woundedScout.type)} HP, 2 moves',
      ),
      findsOneWidget,
    );
    expect(find.text('1 ready / 1 wounded'), findsOneWidget);
    expect(find.text('1 active war'), findsOneWidget);
    expect(find.text('Fund Hydroponics'), findsOneWidget);
    expect(find.text('Buy $fundedResearch research with $fundCost credits'),
        findsOneWidget);
    expect(find.text('Offer peace to Tarth Legion'), findsOneWidget);
    expect(
      find.text('Reopen treaty trade before ending the turn'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Fund Hydroponics'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Fund Hydroponics'), findsNothing);
    expect(find.text('Buy $fundedResearch research with $fundCost credits'),
        findsNothing);

    await tester
        .tap(find.widgetWithText(TextButton, 'Offer peace to Tarth Legion'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('No active wars'), findsOneWidget);
    expect(find.text('Offer peace to Tarth Legion'), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, 'Recover Survey Team'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await _scrollSidePanelUntilVisible(
      tester,
      find.widgetWithText(OutlinedButton, 'Recover Unit'),
      delta: const Offset(0, 420),
      maxScrolls: 40,
    );
    expect(find.widgetWithText(OutlinedButton, 'Recover Unit'), findsOneWidget);
  });

  testWidgets('game screen shows a multi-colony overview and jumps to colonies',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 2200);
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

  testWidgets('game screen summarizes faction economy', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final game = _maintenanceShortfallGame();
    final faction = game.activeFaction;
    final summary = game.worldSummaryFor(faction.id);
    final colonies = game.colonies
        .where((colony) => colony.ownerId == faction.id)
        .toList(growable: false);
    final projections =
        colonies.map((colony) => game.colonyProductionFor(colony)).toList();
    final warningCount = projections
        .where((projection) =>
            projection.isStarving ||
            projection.isInUnrest ||
            projection.isRioting ||
            projection.hasMaintenanceShortfall)
        .length;
    final maintenanceShortfall = projections.fold<int>(
      0,
      (total, projection) => total + projection.maintenanceShortfall,
    );
    final researchCost = OpenDeadlockGame.researchCostFor(
      faction.researchProject,
    );
    final remainingResearch = researchCost - faction.resources.research;
    final affordableResearch = faction.resources.credits ~/
        OpenDeadlockGame.researchCreditCostPerPoint;
    final fundableResearch = affordableResearch < remainingResearch
        ? affordableResearch
        : remainingResearch;
    final fundCost = OpenDeadlockGame.fundResearchCostFor(fundableResearch);

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
      find.byKey(const ValueKey<String>('faction-economy')),
      420,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 12,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Faction Economy'), findsOneWidget);
    expect(find.text('${faction.resources.credits} credits'), findsWidgets);
    expect(find.text(_resourceLineForTest(summary.projectedProduction)),
        findsWidgets);
    expect(
      find.text(
        '${colonies.length} active | ${warningCount == 0 ? 'no warnings' : '$warningCount warnings'}',
      ),
      findsOneWidget,
    );
    expect(find.text('$maintenanceShortfall credit shortfall'), findsOneWidget);
    expect(find.text('Fund $fundableResearch of $remainingResearch remaining'),
        findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('faction-economy-fund-research')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('faction-economy-fund-research')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text('${faction.resources.credits - fundCost} credits'),
      findsWidgets,
    );
    expect(
      find.text(
        '${faction.resources.research + fundableResearch}/$researchCost ${faction.researchProject}',
      ),
      findsOneWidget,
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

    await _scrollSidePanelUntilVisible(
      tester,
      find.textContaining('Balanced - No tax pressure.'),
      delta: const Offset(0, -260),
    );

    await tester.ensureVisible(
      find.textContaining('Balanced - No tax pressure.').last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Balanced - No tax pressure.').last);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('High - +3 credits, -2 morale.').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
        find.textContaining('High - +3 credits, -2 morale.'), findsOneWidget);

    await _scrollSidePanelUntilVisible(
      tester,
      find.text('7 food / 7 ind / 3 res / 12 cred'),
      delta: const Offset(0, 360),
    );

    expect(find.text('7 food / 7 ind / 3 res / 12 cred'), findsWidgets);
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

    await _scrollSidePanelUntilVisible(
      tester,
      find.text('Trade Routes'),
      maxScrolls: 24,
    );
    await tester.pumpAndSettle();

    expect(find.text('Trade Routes'), findsOneWidget);
    expect(find.text('No treaty trade'), findsOneWidget);
    expect(find.text('+0 credits / turn from 0 routes'), findsOneWidget);
    expect(
      find.text('Make peace or alliance treaties to open treaty trade.'),
      findsOneWidget,
    );

    await _scrollSidePanelUntilVisible(
      tester,
      find.text('No visible project to sabotage'),
      maxScrolls: 24,
    );
    await tester.pumpAndSettle();

    expect(find.text('Strength 14 vs 15'), findsOneWidget);
    expect(find.text('Intel scan: 5 sectors / 6 credits'), findsOneWidget);
    expect(find.text('No visible project to sabotage'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Scan').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Intel up to date'), findsWidgets);
    expect(
        find.text('Sabotage Redoubt: 4 industry / 10 credits'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Sabotage').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('No visible project to sabotage'), findsOneWidget);

    for (var scroll = 0;
        scroll < 16 && find.text('Tactical Log').evaluate().isEmpty;
        scroll += 1) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -320));
      await tester.pumpAndSettle();
    }
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

  testWidgets('trade routes can open and upgrade treaties', (tester) async {
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
          initialGame: OpenDeadlockGame.sample(
            sessionId: 'trade-routes-actions-ui',
          ),
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _scrollSidePanelUntilVisible(
      tester,
      find.text('Trade Routes'),
      maxScrolls: 24,
    );
    await tester.pumpAndSettle();

    final peaceButton = find.byKey(
      const ValueKey<String>('trade-routes-peace-rebels'),
    );
    final topTradeButton = find.byKey(
      const ValueKey<String>('trade-routes-open-top'),
    );
    expect(find.text('+0 credits / turn from 0 routes'), findsOneWidget);
    expect(topTradeButton, findsOneWidget);
    expect(find.text('Open Trade with Tarth Legion'), findsOneWidget);
    expect(peaceButton, findsOneWidget);

    await tester.ensureVisible(topTradeButton);
    await tester.pumpAndSettle();
    await tester.tap(topTradeButton);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('+2 credits / turn from 1 route'), findsOneWidget);
    expect(find.text('Peace +2'), findsOneWidget);
    expect(topTradeButton, findsOneWidget);
    expect(find.text('Upgrade Trade with Tarth Legion'), findsOneWidget);

    final allianceButton = find.byKey(
      const ValueKey<String>('trade-routes-alliance-rebels'),
    );
    expect(allianceButton, findsOneWidget);

    await tester.ensureVisible(allianceButton);
    await tester.pumpAndSettle();
    await tester.tap(allianceButton);
    await tester.pumpAndSettle();

    await _scrollSidePanelUntilVisible(
      tester,
      find.text('+4 credits / turn from 1 route'),
      delta: const Offset(0, 420),
      maxScrolls: 24,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('+4 credits / turn from 1 route'), findsOneWidget);
    expect(find.text('Alliance +4'), findsOneWidget);
    expect(allianceButton, findsNothing);
  });

  testWidgets('game screen summarizes intel operations', (tester) async {
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
              OpenDeadlockGame.sample(sessionId: 'intel-operations-ui'),
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.byKey(const ValueKey<String>('intel-operations')),
      find.byType(Scrollable).last,
      const Offset(0, -420),
      maxIteration: 16,
    );
    await tester.pumpAndSettle();

    expect(find.text('Intel Operations'), findsOneWidget);
    expect(find.text('Credits'), findsOneWidget);
    expect(find.text('24 available | scan 6 / sabotage 10'), findsOneWidget);
    expect(find.text('Best Scan'), findsOneWidget);
    expect(find.text('Tarth Legion: 5 hidden sectors'), findsOneWidget);
    expect(find.text('Best Sabotage'), findsOneWidget);
    expect(find.text('No visible wartime construction'), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('No target selected'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('intel-operations-open-top')),
      findsOneWidget,
    );
    expect(find.text('Run Best Scan'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('intel-operations-scan-best')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('intel-operations-sabotage-best')),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Scan Best Target'),
        findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Sabotage Best Target'),
        findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey<String>('intel-operations-scan-best')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Intel up to date'), findsWidgets);
    expect(find.text('Redoubt: 4 industry damage'), findsOneWidget);
    expect(find.text('No protection'), findsWidgets);
    expect(find.text('Run Best Sabotage'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('intel-operations-open-top')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('No visible wartime construction'), findsWidgets);
    expect(find.text('8 available | scan 6 / sabotage 10'), findsOneWidget);
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

    await _scrollSidePanelUntilVisible(
      tester,
      find.text('Rank'),
      delta: const Offset(0, -260),
    );

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

    final reviewButton = find.byKey(
      const ValueKey<String>('world-score-review-humans'),
    );
    expect(reviewButton, findsOneWidget);

    await tester.ensureVisible(reviewButton);
    await tester.pumpAndSettle();
    await tester.tap(reviewButton);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await _scrollSidePanelUntilVisible(
      tester,
      find.text('Population'),
      delta: const Offset(0, 420),
      maxScrolls: 40,
    );
    expect(find.text('New Haven'), findsWidgets);
    expect(find.text('Population'), findsOneWidget);
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

    await _scrollSidePanelUntilVisible(
      tester,
      find.text('Victory Paths'),
      delta: const Offset(0, -480),
    );

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

    final reviewButton = find.byKey(
      const ValueKey<String>('victory-path-review-humans'),
    );
    expect(reviewButton, findsOneWidget);

    await tester.ensureVisible(reviewButton);
    await tester.pumpAndSettle();
    await tester.tap(reviewButton);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await _scrollSidePanelUntilVisible(
      tester,
      find.text('Population'),
      delta: const Offset(0, 420),
      maxScrolls: 40,
    );
    expect(find.text('New Haven'), findsWidgets);
    expect(find.text('Population'), findsOneWidget);
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

    await _scrollSidePanelUntilVisible(
      tester,
      find.textContaining('Defeated | Tarth'),
      maxScrolls: 30,
    );

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
    expect(find.text('Victory Cutscene'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('victory-cutscene-player')),
        findsOneWidget);
    expect(find.text('Scene 1/3'), findsOneWidget);
    expect(
      find.text(
        'Human Assembly uplinks the final discovery from every research lab.',
      ),
      findsWidgets,
    );

    await tester.tap(find.byTooltip('Next Scene'));
    await tester.pumpAndSettle();

    expect(find.text('Scene 2/3'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('cutscene-scene-2')),
      findsOneWidget,
    );
    expect(
      find.text('The colony network powers ancient vaults across the planet.'),
      findsWidgets,
    );

    await tester.tap(find.byTooltip('Replay Cutscene'));
    await tester.pumpAndSettle();

    expect(find.text('Scene 1/3'), findsOneWidget);
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
    expect(find.text('Victory Cutscene'), findsOneWidget);
    expect(
      find.text('The colony network powers ancient vaults across the planet.'),
      findsOneWidget,
    );
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
    expect(find.text('Victory Cutscene'), findsOneWidget);
    expect(
      find.text(
        'Human Assembly closes the final council tally with the strongest score.',
      ),
      findsWidgets,
    );
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

  testWidgets('selected local unit can use unit order buttons', (tester) async {
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
          initialGame: OpenDeadlockGame.sample(sessionId: 'unit-orders-ui'),
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey<String>('terrain-3-1'))),
    );
    await tester.pumpAndSettle();

    await _scrollSidePanelUntilVisible(
      tester,
      find.byKey(const ValueKey<String>('unit-orders')),
    );
    await tester
        .ensureVisible(find.byKey(const ValueKey<String>('unit-orders')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Unit Orders'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('unit-orders-open-top')),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('unit-order-move-4-1')),
        findsOneWidget);
    expect(find.text('Open Top Order'), findsOneWidget);
    expect(find.text('Move to 5, 2'), findsOneWidget);
    expect(find.text('Forest / 2 move'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('unit-order-move-4-1')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey<String>('unit-icon-scout-4-1')),
        findsOneWidget);
    expect(find.text('Survey Team'), findsWidgets);
    expect(find.text('No movement remaining.'), findsOneWidget);
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

    await _scrollSidePanelUntilVisible(
      tester,
      find.byKey(const ValueKey<String>('unit-orders')),
    );
    await tester
        .ensureVisible(find.byKey(const ValueKey<String>('unit-orders')));
    await tester.pumpAndSettle();

    expect(find.text('Unit Orders'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('unit-order-attack-2-1')),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('unit-order-assault-3-2')),
        findsOneWidget);
    expect(find.text('Attack Pact Recon'), findsWidgets);
    expect(find.text('Assault Redoubt'), findsWidgets);
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

  testWidgets('game screen summarizes combat readiness', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final sample = OpenDeadlockGame.sample(sessionId: 'combat-readiness-ui');
    final readinessGame = sample.copyWith(
      tiles: sample.tiles.map((tile) {
        if (tile.colonyId == 'redoubt' || (tile.x == 4 && tile.y == 1)) {
          return tile.copyWith(
            exploredBy: <String>{...tile.exploredBy, 'humans'}.toList(),
          );
        }
        return tile;
      }).toList(),
      units: <Unit>[
        sample.unitById('human-scout').copyWith(health: 3),
        const Unit(
          id: 'human-infantry',
          name: 'Assembly Infantry',
          ownerId: 'humans',
          type: 'infantry',
          x: 2,
          y: 2,
          movesRemaining: 1,
          health: 8,
        ),
        sample.unitById('rebel-scout').copyWith(x: 4, y: 1),
      ],
      reports: const <TurnReport>[
        TurnReport(
          title: 'Pact Recon attacked Survey Team',
          message: 'Pact Recon dealt 2 damage.',
          category: TurnReport.categoryBattle,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: readinessGame,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _scrollSidePanelUntilVisible(
      tester,
      find.byKey(const ValueKey<String>('combat-readiness')),
      delta: const Offset(0, -480),
      maxScrolls: 32,
    );

    expect(tester.takeException(), isNull);
    expect(
        find.byKey(const ValueKey<String>('combat-readiness')), findsOneWidget);
    expect(find.text('Combat Readiness'), findsOneWidget);
    expect(find.text('Posture'), findsOneWidget);
    expect(find.text('Enemy contact'), findsOneWidget);
    expect(find.text('Strength'), findsOneWidget);
    expect(find.textContaining('power'), findsWidgets);
    expect(find.text('Units'), findsOneWidget);
    expect(find.text('2 total / 1 combat / 2 ready'), findsOneWidget);
    expect(find.text('Wounded'), findsOneWidget);
    expect(find.text('Survey Team 3/5'), findsOneWidget);
    expect(find.text('Visible Enemies'), findsOneWidget);
    expect(find.text('Pact Recon at 5, 2'), findsOneWidget);
    expect(find.text('Known Enemy Colonies'), findsOneWidget);
    expect(find.text('Redoubt at 7, 4'), findsOneWidget);
    expect(find.text('Recent Battles'), findsOneWidget);
    expect(find.text('1 logged'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('combat-readiness-review-first'),
      ),
      findsOneWidget,
    );
    expect(find.text('Review First Threat'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('combat-readiness-view-enemy-unit'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('combat-readiness-view-enemy-colony'),
      ),
      findsOneWidget,
    );

    final firstThreatButton = find.byKey(
      const ValueKey<String>('combat-readiness-review-first'),
    );
    final enemyColonyButton = find.byKey(
      const ValueKey<String>('combat-readiness-view-enemy-colony'),
    );

    await tester.ensureVisible(firstThreatButton);
    await tester.pumpAndSettle();

    await tester.tap(firstThreatButton);
    await tester.pumpAndSettle();

    await _scrollSidePanelUntilVisible(
      tester,
      find.text('Sector 5, 2'),
      delta: const Offset(0, 420),
      maxScrolls: 56,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Sector 5, 2'), findsWidgets);

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: readinessGame,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _scrollSidePanelUntilVisible(
      tester,
      find.byKey(const ValueKey<String>('combat-readiness')),
      delta: const Offset(0, -480),
      maxScrolls: 32,
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(enemyColonyButton);
    await tester.pumpAndSettle();

    await tester.tap(enemyColonyButton);
    await tester.pumpAndSettle();

    await _scrollSidePanelUntilVisible(
      tester,
      find.text('Redoubt'),
      delta: const Offset(0, 420),
      maxScrolls: 56,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Redoubt'), findsWidgets);
  });

  testWidgets('game screen summarizes and selects active units',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final sample = OpenDeadlockGame.sample(sessionId: 'unit-roster-ui');
    final rosterGame = sample.copyWith(
      units: <Unit>[
        sample.unitById('human-scout').copyWith(health: 3),
        const Unit(
          id: 'human-infantry',
          name: 'Assembly Infantry',
          ownerId: 'humans',
          type: 'infantry',
          x: 2,
          y: 2,
          movesRemaining: 1,
          health: 8,
        ),
        sample.unitById('rebel-scout'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: rosterGame,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey<String>('unit-roster')), findsOneWidget);
    expect(find.text('Unit Roster'), findsOneWidget);
    expect(find.text('2 total'), findsOneWidget);
    expect(find.text('2 ready / 1 wounded'), findsOneWidget);
    expect(find.text('Scout | HP 3/5 | Moves 2/2'), findsOneWidget);
    expect(find.text('Infantry | HP 8/8 | Moves 1/1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('unit-roster-review-first')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('unit-roster-row-human-infantry')),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Assembly Infantry'));
    await tester.pumpAndSettle();

    expect(find.text('Unit'), findsOneWidget);
    expect(find.text('Assembly Infantry'), findsWidgets);
    expect(find.text('Type'), findsOneWidget);
    expect(find.text('Infantry'), findsOneWidget);
    expect(find.text('8/8'), findsOneWidget);
  });

  testWidgets('game screen summarizes expansion planning', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: OpenDeadlockGame.sample(sessionId: 'expansion-planner'),
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _scrollSidePanelUntilVisible(
      tester,
      find.byKey(const ValueKey<String>('expansion-planner')),
      maxScrolls: 48,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('expansion-planner')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Expansion Planner'), findsOneWidget);
    expect(find.text('1 ready'), findsOneWidget);
    expect(find.text('1 ready / 1 scouting'), findsOneWidget);
    expect(find.text('3 best sectors listed'), findsOneWidget);
    expect(find.text('Survey Team ready at 4, 2'), findsOneWidget);
    expect(find.text('Sector 1, 1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('expansion-planner-review-first')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('expansion-ready-unit-human-scout')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('expansion-site-0-0')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('expansion-planner-review-first')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await _scrollSidePanelUntilVisible(
      tester,
      find.widgetWithText(ElevatedButton, 'Found Colony'),
      delta: const Offset(0, 420),
    );
    expect(find.widgetWithText(ElevatedButton, 'Found Colony'), findsOneWidget);
  });

  testWidgets('game screen shows unit catalog', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: OpenDeadlockGame.sample(sessionId: 'unit-catalog-ui'),
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey<String>('terrain-3-1'))),
    );
    await tester.pumpAndSettle();

    await _scrollSidePanelUntilVisible(tester, find.text('Unit Catalog'));
    await tester.ensureVisible(find.text('Unit Catalog'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Unit Catalog'), findsOneWidget);
    expect(find.text('3 unit types / Scout selected'), findsOneWidget);

    await tester.tap(find.text('Unit Catalog'));
    await tester.pumpAndSettle();

    expect(find.text('Scout - Selected'), findsOneWidget);
    expect(find.text('Infantry - Available'), findsOneWidget);
    expect(find.text('Armor - Available'), findsOneWidget);
    expect(find.text('5 HP / 3 attack / 1 defense / 2 moves / 2 vision'),
        findsOneWidget);
    expect(find.text('8 HP / 4 attack / 2 defense / 1 moves / 1 vision'),
        findsOneWidget);
    expect(find.text('10 HP / 6 attack / 3 defense / 1 moves / 1 vision'),
        findsOneWidget);
    expect(
      find.text('Fast recon unit that can found colonies and reveal more map.'),
      findsOneWidget,
    );
    expect(
      find.text('Heavy assault unit with the strongest attack and durability.'),
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

    await tester.scrollUntilVisible(
      find.text('Tactical Log'),
      420,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 24,
    );
    await tester.pumpAndSettle();

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
            'x': '6',
            'y': '3',
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

    await _scrollSidePanelUntilVisible(tester, find.text('News Summary'));

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

    await _scrollSidePanelUntilVisible(
      tester,
      find.byKey(const ValueKey<String>('strategic-archive')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Strategic Archive'), findsOneWidget);
    expect(find.text('6 recent'), findsOneWidget);
    expect(find.text('Pact Recon attacked Survey Team'), findsWidgets);
    expect(
        find.text(
            'Attack 1 / Unit Production 1 / Population & Morale 1 / Research 1'),
        findsOneWidget);
    expect(
        find.text('Combat: Pact Recon attacked Survey Team'), findsOneWidget);
    expect(find.text('Economy: Tax policy changed'), findsOneWidget);
    expect(find.text('Research: Human Assembly: Hydroponics researched'),
        findsWidgets);

    final combatButton = find.byKey(
      const ValueKey<String>('archive-highlight-review-Combat'),
    );
    expect(combatButton, findsOneWidget);

    await tester.ensureVisible(combatButton);
    await tester.pumpAndSettle();
    await tester.tap(combatButton);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await _scrollSidePanelUntilVisible(
      tester,
      find.text('Sector 7, 4'),
      delta: const Offset(0, 420),
      maxScrolls: 40,
    );
    expect(find.text('Sector 7, 4'), findsOneWidget);
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
    final recoverButton = find.widgetWithText(OutlinedButton, 'Recover Unit');
    await _scrollSidePanelUntilVisible(tester, recoverButton);
    await tester.ensureVisible(recoverButton);
    await tester.pumpAndSettle();

    expect(recoverButton, findsOneWidget);

    await tester.tap(recoverButton);
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

  testWidgets('game screen can use colony order actions', (tester) async {
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
          initialGame: OpenDeadlockGame.sample(sessionId: 'colony-orders-ui'),
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _scrollSidePanelUntilVisible(
      tester,
      find.byKey(const ValueKey<String>('colony-orders')),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('colony-orders')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Colony Orders'), findsOneWidget);
    expect(find.text('Rush Construction +12'), findsOneWidget);
    expect(find.text('24 credits for Colony Hub'), findsOneWidget);
    expect(find.textContaining('Assign Best Work'), findsOneWidget);
    expect(find.text('Copy Balanced Focus'), findsOneWidget);
    expect(find.text('Copy Colony Hub Build'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('colony-orders-open-top')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('colony-orders-rush')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('colony-orders-assign-best')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('colony-orders-open-top')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('22/24 industry stored (+7)'), findsOneWidget);
    expect(find.text('Rush Construction'), findsWidgets);
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

  testWidgets('game screen shows colony build catalog', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final sample = OpenDeadlockGame.sample(sessionId: 'build-catalog-ui');
    final game = sample.copyWith(
      colonies: sample.colonies.map((colony) {
        if (colony.id != 'new-haven') {
          return colony;
        }
        return colony.copyWith(
          construction: 'Research Lab',
          completedBuildings: const <String>['Housing', 'Factory'],
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
      find.text('Build Catalog'),
      420,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 12,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Build Catalog'), findsOneWidget);
    expect(find.text('Options'), findsOneWidget);
    expect(find.text('7 available / 2 completed / 3 locked'), findsOneWidget);

    await tester.tap(find.text('Build Catalog'));
    await tester.pumpAndSettle();

    expect(find.text('Housing - Completed'), findsOneWidget);
    expect(find.text('Factory - Completed'), findsOneWidget);
    expect(find.text('Apartment Complex - Available'), findsOneWidget);
    expect(find.text('Luxury Housing - Locked'), findsOneWidget);
    expect(find.text('Armor Company - Locked'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('build-catalog-queue-Apartment Complex'),
      ),
      findsOneWidget,
    );
    expect(
      find.text('18 industry / 1 upkeep / Requires Housing'),
      findsOneWidget,
    );
    expect(
      find.text('30 industry / 0 upkeep / Requires Barracks and Factory'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('build-catalog-queue-Apartment Complex'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Apartment Complex'), findsWidgets);
    expect(find.text('Apartment Complex - Available'), findsOneWidget);
    expect(find.textContaining('0/18 industry stored'), findsOneWidget);
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

    final fundButton =
        find.byKey(const ValueKey<String>('research-panel-fund-research'));
    await _scrollSidePanelUntilVisible(tester, fundButton);
    await tester.ensureVisible(fundButton);
    await tester.pumpAndSettle();
    expect(fundButton, findsOneWidget);

    await tester.tap(fundButton);
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

    await _scrollSidePanelUntilVisible(tester, find.text('Tech Roadmap'));

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

  testWidgets('game screen shows research catalog', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final sample = OpenDeadlockGame.sample(sessionId: 'research-catalog-ui');
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

    await _scrollSidePanelUntilVisible(
      tester,
      find.text('Research Catalog'),
      delta: const Offset(0, -260),
    );
    await tester.ensureVisible(find.text('Research Catalog'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Research Catalog'), findsOneWidget);
    expect(
      find.textContaining('2 next / 1 current / 1 complete / 1 repeatable'),
      findsOneWidget,
    );

    await tester.tap(find.text('Research Catalog'));
    await tester.pumpAndSettle();

    expect(find.text('Defense Grid - Current'), findsOneWidget);
    expect(find.text('Hydroponics - Complete'), findsOneWidget);
    expect(find.text('Industrial Automation - Next'), findsOneWidget);
    expect(find.text('Future Studies - Repeatable'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>(
          'research-catalog-select-Industrial Automation',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.text('16 research / 48 credits from empty'),
      findsOneWidget,
    );
    expect(
      find.text(
          '+2 defense and +3 sabotage protection for controlled colonies.'),
      findsWidgets,
    );
    expect(
      find.text('10 research / 30 credits from empty'),
      findsWidgets,
    );
    expect(
      find.text(
          'Converts research into credits after the core tree is complete.'),
      findsWidgets,
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'research-catalog-select-Industrial Automation',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Industrial Automation - Current'), findsOneWidget);
    expect(find.text('Defense Grid - Next'), findsOneWidget);
    expect(find.text('Industrial Automation 7/12'), findsOneWidget);
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
    await _scrollSidePanelUntilVisible(tester, find.text('AI Orders'));
    expect(find.text('AI Orders'), findsOneWidget);
    expect(find.text(plannedLabel), findsOneWidget);
    expect(
      find.text('Tactical 2 / Research 1 / Economy 4 / Movement 1'),
      findsOneWidget,
    );
    expect(find.text('5 map shortcuts / 3 abstract orders'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('ai-orders-review-first')),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Review Redoubt'), findsWidgets);
    expect(find.text('Research'), findsWidgets);
    expect(find.text('Economy'), findsWidgets);
    expect(find.text('Tactical'), findsWidgets);
    expect(find.text('Movement'), findsWidgets);
    expect(find.text('AI Plan | Tarth Legion'), findsWidgets);

    final aiOrderButton = find.byKey(
      const ValueKey<String>('ai-order-review-2'),
    );
    expect(aiOrderButton, findsOneWidget);

    await tester.ensureVisible(aiOrderButton);
    await tester.pumpAndSettle();
    await tester.tap(aiOrderButton);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await _scrollSidePanelUntilVisible(
      tester,
      find.text('Population'),
      delta: const Offset(0, 420),
      maxScrolls: 40,
    );
    expect(find.text('Redoubt'), findsWidgets);
    expect(find.text('Population'), findsOneWidget);

    await _scrollSidePanelUntilVisible(
      tester,
      find.widgetWithText(ElevatedButton, 'Run AI'),
      delta: const Offset(0, 420),
      maxScrolls: 40,
    );
    await tester.pumpAndSettle();

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

    await _scrollSidePanelUntilVisible(tester, find.text('AI Orders'));

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

  testWidgets('sync panel explains async connectivity', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(520, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final sample = OpenDeadlockGame.sample(sessionId: 'connectivity-panel');
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

    await tester.dragUntilVisible(
      find.text('Transport'),
      find.byType(Scrollable).last,
      const Offset(0, -420),
      maxIteration: 18,
    );
    await tester.pumpAndSettle();

    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('Invite and order packages'), findsOneWidget);
    expect(find.text('Integrity'), findsOneWidget);
    expect(find.text('State fingerprints verified'), findsOneWidget);
    expect(find.text('Local Role'), findsOneWidget);
    expect(find.text('Local player can issue orders'), findsOneWidget);
    expect(find.text('Remote Seats'), findsOneWidget);
    expect(find.text('Tarth Legion, Trade Compact'), findsOneWidget);
    expect(find.text('Package Flow'), findsOneWidget);
    expect(find.text('Share invites or import remote orders'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('sync-handoff-checklist')),
        findsOneWidget);
    expect(find.text('Handoff Checklist'), findsOneWidget);
    expect(find.text('Share invites with Tarth Legion, Trade Compact.'),
        findsOneWidget);
    expect(find.text('Issue local orders or end the turn.'), findsOneWidget);
    expect(find.text('Verify the state hash after each imported package.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
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
      maxIteration: 32,
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
    expect(find.byKey(const ValueKey<String>('sync-ledger')), findsOneWidget);
    expect(find.text('Sync Ledger'), findsOneWidget);
    expect(find.text('Source'), findsOneWidget);
    expect(find.text('Typed Code'), findsOneWidget);
    expect(find.text('Received'), findsOneWidget);
    expect(find.text('1 order'), findsWidgets);
    expect(find.text('Result State'), findsOneWidget);

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

    for (var scroll = 0;
        scroll < 18 && find.text('Last Sync').evaluate().isEmpty;
        scroll += 1) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -420));
      await tester.pumpAndSettle();
    }

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
    final initialColony = initial.colonyById('new-haven');
    final initialBuildCost =
        OpenDeadlockGame.buildCostFor(initialColony.construction);
    final initialProjection = initial.colonyProductionFor(initialColony);
    final initialProgressLabel =
        '${initialColony.storedIndustry}/$initialBuildCost industry stored (+${initialProjection.constructionWork})';
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
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey<String>('terrain-2-2'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('New Haven'), findsOneWidget);
    await _scrollSidePanelUntilVisible(
      tester,
      find.text(initialProgressLabel),
    );
    expect(find.text(initialProgressLabel), findsOneWidget);
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

    await tester.dragUntilVisible(
      find.textContaining('Balanced - No production bias.'),
      find.byType(Scrollable).last,
      const Offset(0, -260),
      maxIteration: 8,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Balanced - No production bias.'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('+2 industry, -1 food.').last);
    await tester.pumpAndSettle();
    await _scrollSidePanelUntilVisible(
      tester,
      find.text('Pending Orders'),
      maxScrolls: 30,
    );

    expect(find.text('1 pending'), findsOneWidget);
    expect(find.text('New Haven: focus Industry'), findsWidgets);
    expect(
        find.widgetWithText(OutlinedButton, 'Undo Last Order'), findsOneWidget);

    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Undo Last Order'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Undo Last Order'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Undid New Haven: focus Industry'), findsOneWidget);
    await _scrollSidePanelUntilVisible(
      tester,
      find.text('0 pending'),
      delta: const Offset(0, 420),
    );
    expect(find.text('0 pending'), findsOneWidget);
    expect(find.text('No orders since the sync baseline.'), findsOneWidget);
    expect(
        find.widgetWithText(OutlinedButton, 'Undo Last Order'), findsNothing);
  });

  testWidgets('command bar can undo the last pending local order',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 960);
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

    await tester.dragUntilVisible(
      find.textContaining('Balanced - No production bias.'),
      find.byType(Scrollable).last,
      const Offset(0, -260),
      maxIteration: 8,
    );
    await tester.pumpAndSettle();
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
    await tester.dragUntilVisible(
      find.text('Pending Orders'),
      find.byType(Scrollable).last,
      const Offset(0, -420),
      maxIteration: 24,
    );
    await tester.pumpAndSettle();

    final pendingOrders = find.byKey(const ValueKey<String>('pending-orders'));
    expect(find.text('Pending Orders'), findsOneWidget);
    expect(find.descendant(of: pendingOrders, matching: find.text('1 pending')),
        findsOneWidget);
    expect(find.descendant(of: pendingOrders, matching: find.text('Command 1')),
        findsOneWidget);
    expect(
        find.descendant(
          of: pendingOrders,
          matching: find.text('New Haven: focus Industry'),
        ),
        findsOneWidget);
    expect(
        find.descendant(
          of: pendingOrders,
          matching: find.text('Turn 1 | Human Assembly'),
        ),
        findsOneWidget);
    expect(
        find.descendant(
          of: pendingOrders,
          matching: find.text('New Haven: build Factory'),
        ),
        findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Copy Orders'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Export Orders File'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, 'Copy Orders'),
      160,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 4,
    );
    await tester.pumpAndSettle();
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

  testWidgets('game screen shows a replay timeline for command history',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(960, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final replayGame = OpenDeadlockGame.sample(sessionId: 'replay-timeline-ui')
        .applyCommand(
          const SetColonyConstructionCommand(
            factionId: 'humans',
            colonyId: 'new-haven',
            construction: 'Factory',
          ),
        )
        .applyCommand(
          const SetColonyFocusCommand(
            factionId: 'humans',
            colonyId: 'new-haven',
            focus: OpenDeadlockGame.colonyFocusResearch,
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialGame: replayGame,
          resumeLatestSave: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _scrollSidePanelUntilVisible(
      tester,
      find.byKey(const ValueKey<String>('replay-timeline')),
    );

    final commandFingerprint = GameCodec.fingerprintCommands(
      replayGame.commandHistory.map((record) => record.command),
    );
    final stateFingerprint = GameCodec.fingerprintGame(replayGame);

    expect(find.text('Replay Timeline'), findsOneWidget);
    expect(find.text('2 commands'), findsOneWidget);
    expect(find.text('Last Actor'), findsOneWidget);
    expect(find.text('Replay Window'), findsOneWidget);
    expect(find.text('Commands 1-2'), findsOneWidget);
    expect(find.text('Command Hash'), findsOneWidget);
    expect(find.text(_shortFingerprintForTest(commandFingerprint)),
        findsOneWidget);
    expect(find.text('State Hash'), findsOneWidget);
    expect(find.text(_shortFingerprintForTest(stateFingerprint)), findsWidgets);
    expect(find.text('Audit'), findsOneWidget);
    expect(find.text('Snapshot + command log'), findsOneWidget);
    expect(find.text('Human Assembly'), findsWidgets);
    expect(find.text('New Haven: build Factory'), findsWidgets);
    expect(find.text('New Haven: focus Research'), findsWidgets);
    expect(find.text('Turn 1 | Human Assembly'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('replay-timeline-review-latest')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('replay-timeline-review-latest')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('replay-timeline-review-latest')),
    );
    await tester.pumpAndSettle();

    await _scrollSidePanelUntilVisible(
      tester,
      find.text('Population'),
      delta: const Offset(0, 420),
      maxScrolls: 56,
    );
    await tester.pumpAndSettle();

    expect(find.text('New Haven'), findsWidgets);
    expect(find.text('Population'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    await tester.dragUntilVisible(
      find.text('Pending Orders'),
      find.byType(Scrollable).last,
      const Offset(0, -420),
      maxIteration: 24,
    );
    await tester.pumpAndSettle();

    expect(find.text('1 pending'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Export Orders File'),
      findsOneWidget,
    );

    final pendingOrderButton = find.byKey(
      const ValueKey<String>('pending-order-review-2'),
    );
    expect(pendingOrderButton, findsOneWidget);

    await tester.ensureVisible(pendingOrderButton);
    await tester.pumpAndSettle();
    await tester.tap(pendingOrderButton);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await _scrollSidePanelUntilVisible(
      tester,
      find.text('Population'),
      delta: const Offset(0, 420),
      maxScrolls: 40,
    );
    expect(find.text('New Haven'), findsWidgets);
    expect(find.text('Population'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Pending Orders'),
      find.byType(Scrollable).last,
      const Offset(0, -420),
      maxIteration: 24,
    );
    await tester.pumpAndSettle();

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

    final importOrdersFile =
        find.widgetWithText(OutlinedButton, 'Import Orders File');
    await _scrollSidePanelUntilVisible(tester, importOrdersFile);

    expect(importOrdersFile, findsOneWidget);

    await tester.ensureVisible(importOrdersFile);
    await tester.pumpAndSettle();
    await tester.tap(importOrdersFile);
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
    expect(find.byKey(const ValueKey<String>('sync-ledger')), findsOneWidget);
    expect(find.text('Imported File'), findsOneWidget);
    expect(find.text('Base Cmd'), findsOneWidget);
    expect(find.text('Result State'), findsOneWidget);
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

    final saveInvite = find.widgetWithText(OutlinedButton, 'Save Invite');
    await _scrollSidePanelUntilVisible(tester, saveInvite);
    await tester.ensureVisible(saveInvite);
    await tester.pumpAndSettle();
    await tester.tap(saveInvite);
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

String _resourceLineForTest(ResourceStockpile stockpile) {
  return '${stockpile.food} food / ${stockpile.industry} ind / '
      '${stockpile.research} res / ${stockpile.credits} cred';
}

Future<void> _scrollSidePanelUntilVisible(
  WidgetTester tester,
  Finder finder, {
  Offset delta = const Offset(0, -420),
  int maxScrolls = 30,
}) async {
  for (var scroll = 0; scroll < maxScrolls; scroll += 1) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.drag(find.byType(Scrollable).last, delta);
    await tester.pumpAndSettle();
  }
}

String _shortFingerprintForTest(String fingerprint) {
  if (fingerprint.isEmpty) {
    return 'Unavailable';
  }
  if (fingerprint.length <= 16) {
    return fingerprint;
  }
  return '${fingerprint.substring(0, 8)}...${fingerprint.substring(fingerprint.length - 5)}';
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
