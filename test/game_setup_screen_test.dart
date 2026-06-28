import 'package:OpenDeadlock/game/game_state.dart';
import 'package:OpenDeadlock/gameplay/game_screen.dart';
import 'package:OpenDeadlock/gameplay/game_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('setup screen can start a four faction game', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: GameSetupScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('10 x 7 sectors (70 total)'), findsOneWidget);
    expect(find.text('AI Opponents'), findsOneWidget);
    expect(find.text('Rival factions run computer turns.'), findsOneWidget);
    expect(
      find.text('Balanced plains, forests, ridges, water, and ruins.'),
      findsOneWidget,
    );
    expect(find.text('All factions begin at war.'), findsOneWidget);
    expect(find.text('Conquest or science can win the game.'), findsOneWidget);
    expect(
      find.text('Each faction knows the sectors around its capital.'),
      findsOneWidget,
    );
    expect(
      find.text('Balanced reserves for a normal opening.'),
      findsOneWidget,
    );
    expect(find.text('2 starting colonies'), findsOneWidget);
    expect(
      find.text('Flexible colonists with strong budget reserves.'),
      findsOneWidget,
    );
    expect(find.text('+2 credits per colony.'), findsOneWidget);
    expect(
      find.text(
        'Scholars: +1 research per colony; prefers Research Lab; '
        'prioritizes Xenoarchaeology. Traders: +2 credits per colony; '
        'prioritizes Future Studies.',
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('world-seed-field')),
      '7',
    );
    await tester.pumpAndSettle();
    await _selectDropdownOption(
      tester,
      currentLabel: 'War',
      optionLabel: 'Peace',
    );
    expect(
      find.text('All factions begin at peace and may trade.'),
      findsOneWidget,
    );
    await _selectDropdownOption(
      tester,
      currentLabel: 'Any Victory',
      optionLabel: 'Science',
    );
    expect(
      find.text('Only completing every core research project ends the game.'),
      findsOneWidget,
    );
    await _selectDropdownOption(
      tester,
      currentLabel: 'Home Region',
      optionLabel: 'Full Map',
    );
    expect(
      find.text('Every faction starts with the whole planet revealed.'),
      findsOneWidget,
    );
    await _selectDropdownOption(
      tester,
      currentLabel: 'Standard Supplies',
      optionLabel: 'Abundant Supplies',
    );
    expect(
      find.text('Extra reserves accelerate early builds and research.'),
      findsOneWidget,
    );
    await tester.dragUntilVisible(
      find.byType(SwitchListTile),
      find.byType(ListView),
      const Offset(0, -420),
      maxIteration: 12,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();
    expect(find.text('3 starting colonies'), findsOneWidget);
    final uncheckedFactionSwitch = find.byWidgetPredicate((widget) {
      return widget is SwitchListTile && widget.value == false;
    });
    await tester.dragUntilVisible(
      uncheckedFactionSwitch,
      find.byType(ListView),
      const Offset(0, -420),
      maxIteration: 12,
    );
    await tester.pumpAndSettle();
    await tester.tap(uncheckedFactionSwitch.first);
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('4 starting colonies'),
      find.byType(ListView),
      const Offset(0, 420),
      maxIteration: 12,
    );
    await tester.pumpAndSettle();
    expect(find.text('4 starting colonies'), findsOneWidget);
    final startButton = find.widgetWithText(ElevatedButton, 'Start');
    await tester.dragUntilVisible(
      startButton,
      find.byType(ListView),
      const Offset(0, -420),
      maxIteration: 12,
    );
    await tester.pumpAndSettle();
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    final gameScreen = tester.widget<GameScreen>(find.byType(GameScreen));

    expect(tester.takeException(), isNull);
    expect(gameScreen.initialGame.factions.length, 4);
    expect(gameScreen.initialGame.tileAt(0, 0).terrain, 'ridge');
    expect(gameScreen.initialGame.factionById('humans')!.aiPersonality,
        Faction.aiPersonalityResearcher);
    expect(gameScreen.initialGame.factionById('humans')!.isLocal, isTrue);
    expect(gameScreen.initialGame.factionById('rebels')!.aiPersonality,
        Faction.aiPersonalityConqueror);
    expect(gameScreen.initialGame.factionById('rebels')!.isComputer, isTrue);
    expect(gameScreen.initialGame.factionById('traders')!.aiPersonality,
        Faction.aiPersonalityTrader);
    expect(gameScreen.initialGame.factionById('traders')!.isComputer, isTrue);
    expect(gameScreen.initialGame.factionById('maug')!.aiPersonality,
        Faction.aiPersonalityResearcher);
    expect(gameScreen.initialGame.factionById('maug')!.isComputer, isTrue);
    expect(gameScreen.initialGame.colonies.length, 4);
    expect(gameScreen.initialGame.units.length, 4);
    expect(gameScreen.initialGame.victoryCondition,
        OpenDeadlockGame.victoryConditionScience);
    expect(
      gameScreen.initialGame.factionById('humans')!.resources.toJson(),
      <String, dynamic>{
        'food': 28,
        'industry': 14,
        'research': 4,
        'credits': 40
      },
    );
    expect(
      gameScreen.initialGame.factionById('rebels')!.resources.toJson(),
      <String, dynamic>{
        'food': 24,
        'industry': 12,
        'research': 4,
        'credits': 34
      },
    );
    expect(
      gameScreen.initialGame.tiles.every(
        (tile) => tile.isExploredBy('humans'),
      ),
      isTrue,
    );
    expect(gameScreen.initialGame.factionById('maug'), isNotNull);
    expect(gameScreen.initialGame.diplomacy.length, 6);
    expect(
      gameScreen.initialGame.diplomacyStatusBetween('humans', 'rebels'),
      OpenDeadlockGame.diplomacyStatusPeace,
    );
    expect(
      gameScreen.initialGame.diplomacyStatusBetween('traders', 'maug'),
      OpenDeadlockGame.diplomacyStatusPeace,
    );
  });

  testWidgets('setup mode can start async multiplayer seats', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: GameSetupScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await _selectDropdownOption(
      tester,
      currentLabel: 'AI Opponents',
      optionLabel: 'Async Multiplayer',
    );
    expect(find.text('Async Multiplayer'), findsOneWidget);
    expect(
      find.text('Rival factions wait for invite and order packages.'),
      findsOneWidget,
    );

    await tester.dragUntilVisible(
      find.byType(SwitchListTile),
      find.byType(ListView),
      const Offset(0, -420),
      maxIteration: 12,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    final startButton = find.widgetWithText(ElevatedButton, 'Start');
    await tester.dragUntilVisible(
      startButton,
      find.byType(ListView),
      const Offset(0, -420),
      maxIteration: 12,
    );
    await tester.pumpAndSettle();
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    final gameScreen = tester.widget<GameScreen>(find.byType(GameScreen));

    expect(tester.takeException(), isNull);
    expect(gameScreen.initialGame.factionById('humans')!.isLocal, isTrue);
    expect(gameScreen.initialGame.factionById('rebels')!.isRemote, isTrue);
    expect(gameScreen.initialGame.factionById('traders')!.isRemote, isTrue);
    expect(gameScreen.initialGame.factions.length, 3);
  });
}

Future<void> _selectDropdownOption(
  WidgetTester tester, {
  required String currentLabel,
  required String optionLabel,
}) async {
  await tester.tap(find.text(currentLabel).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(optionLabel).last);
  await tester.pumpAndSettle();
}
