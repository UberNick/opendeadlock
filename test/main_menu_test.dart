import 'package:OpenDeadlock/game/game_codec.dart';
import 'package:OpenDeadlock/game/game_saves.dart';
import 'package:OpenDeadlock/game/game_state.dart';
import 'package:OpenDeadlock/menu/dev_menu.dart';
import 'package:OpenDeadlock/menu/main_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('main menu continues the latest local save', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final store = GameSaveStore(preferences);
    final olderGame = OpenDeadlockGame.sample(sessionId: 'menu-continue-old');
    final latestGame = OpenDeadlockGame.sample(sessionId: 'menu-continue-new')
        .applyCommand(const EndTurnCommand(factionId: 'humans'));

    await store.saveGame(
      olderGame,
      slotId: 'older-slot',
      name: 'Older Slot',
      updatedAt: DateTime.utc(2026, 6, 28, 3, 10),
    );
    await store.saveGame(
      latestGame,
      slotId: 'latest-slot',
      name: 'Latest Slot',
      updatedAt: DateTime.utc(2026, 6, 28, 4, 10),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: MainMenu(title: 'OpenDeadlock'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Sync'), findsOneWidget);
    expect(find.text('Turn 2'), findsWidgets);
    expect(find.textContaining('Human Assembly'), findsWidgets);
  });

  testWidgets('main menu reports when continue has no local save',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      const MaterialApp(
        home: MainMenu(title: 'OpenDeadlock'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('No local save found'), findsOneWidget);
  });

  testWidgets('main menu joins a game from an invite code', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final invite = GameCodec.encodeShareCode(
      GameCodec.encodeGameInvite(
        OpenDeadlockGame.sample(sessionId: 'menu-join'),
        invitedFactionId: 'rebels',
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: MainMenu(title: 'OpenDeadlock'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Join Game'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), invite);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Join'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Sync'), findsOneWidget);
    expect(find.text('Turn 1'), findsWidgets);
    expect(find.textContaining('Human Assembly'), findsWidgets);
  });

  testWidgets('main menu joins a game from an invite file', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final invite = GameCodec.encodeShareCode(
      GameCodec.encodeGameInvite(
        OpenDeadlockGame.sample(sessionId: 'menu-file-join'),
        invitedFactionId: 'rebels',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MainMenu(
          title: 'OpenDeadlock',
          joinFileReader: () async => invite,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Join Game'));
    await tester.pumpAndSettle();

    expect(find.text('Open File'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Open File'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Sync'), findsOneWidget);
    expect(find.text('Turn 1'), findsWidgets);
    expect(find.textContaining('Human Assembly'), findsWidgets);
  });

  testWidgets('main menu loads a chosen local save slot', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final store = GameSaveStore(preferences);
    final savedGame = OpenDeadlockGame.sample(sessionId: 'menu-load')
        .applyCommand(const EndTurnCommand(factionId: 'humans'));

    await store.saveGame(
      savedGame,
      slotId: 'menu-slot',
      name: 'Menu Slot',
      updatedAt: DateTime.utc(2026, 6, 28, 4, 10),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: MainMenu(title: 'OpenDeadlock'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Load Game'));
    await tester.pumpAndSettle();

    expect(find.text('Menu Slot'), findsOneWidget);

    await tester.tap(find.text('Menu Slot'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Sync'), findsOneWidget);
    expect(find.text('Turn 2'), findsWidgets);
    expect(find.textContaining('Human Assembly'), findsWidgets);
  });

  testWidgets('developer menu opens legacy reference gallery', (tester) async {
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
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: DevMenu(title: 'Developer Menu'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Legacy References'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Legacy References'), findsOneWidget);
    expect(find.text('Gameplay Screen'), findsWidgets);
    expect(find.text('Playing_Screen.png'), findsOneWidget);
    expect(find.text('1 of 18'), findsOneWidget);
    expect(
      find.text('Gameplay map, command density, and side-panel layout'),
      findsOneWidget,
    );

    await tester
        .tap(find.byKey(const ValueKey<String>('legacy-reference-next')));
    await tester.pumpAndSettle();

    expect(find.text('Full Gameplay Screen'), findsWidgets);
    expect(find.text('Playing_Full_Screen.png'), findsOneWidget);
    expect(find.text('2 of 18'), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey<String>('legacy-reference-previous')));
    await tester.pumpAndSettle();

    expect(find.text('Playing_Screen.png'), findsOneWidget);
    expect(find.text('1 of 18'), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey<String>('legacy-reference-previous')));
    await tester.pumpAndSettle();

    expect(
        find.text('Inline_Screenshot_2026-06-27_18-08-27.png'), findsOneWidget);
    expect(find.text('18 of 18'), findsOneWidget);

    await tester.tap(find.text('Order Screen'));
    await tester.pumpAndSettle();

    expect(find.text('Order_Screen.png'), findsOneWidget);
    expect(find.text('3 of 18'), findsOneWidget);
    expect(
      find.text('Turn orders, confirmation flow, and control grouping'),
      findsOneWidget,
    );

    await tester
        .tap(find.byKey(const ValueKey<String>('legacy-reference-copy-path')));
    await tester.pumpAndSettle();

    expect(clipboardWrites, <String>[
      'docs/reference/legacy-screenshots/nick-2026-06-27/Order_Screen.png',
    ]);
    expect(find.text('Copied Order_Screen.png path'), findsOneWidget);
  });

  testWidgets('developer menu shows decoder handoff commands', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DevMenu(title: 'Developer Menu'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Decoder Tools'), findsOneWidget);
    expect(find.text('Game folder'), findsOneWidget);
    expect(find.text('Not selected'), findsOneWidget);
    expect(find.text('Tool source'), findsOneWidget);
    expect(find.text('tools/src/decoder'), findsOneWidget);
    expect(find.text('Output target'), findsOneWidget);
    expect(find.text('build/decoded-assets'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Decoder Guide'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Decoder Handoff'), findsOneWidget);
    expect(find.text('Selected game'), findsOneWidget);
    expect(
        find.text('Choose the original Deadlock folder first'), findsOneWidget);
    expect(find.text('Decoder source'), findsOneWidget);
    expect(
      find.text(
        'cmake -S tools/src/decoder -B build/decoder && cmake --build build/decoder',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('compare decoded art against Legacy References'),
      findsOneWidget,
    );
  });

  testWidgets('developer menu opens opening comic storyboard', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DevMenu(title: 'Developer Menu'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ElevatedButton, 'View Comic'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'View Comic'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Opening Comic'), findsOneWidget);
    expect(find.text('Storyboard'), findsOneWidget);
    expect(find.text('A New World'), findsWidgets);
    expect(
        find.text('The colony ships descend over Gallius IV.'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pumpAndSettle();

    expect(find.text('First Orders'), findsWidgets);
    expect(find.text('Scouts fan out while factories wake from cold storage.'),
        findsOneWidget);

    await tester.tap(find.text('Planetary Conquest').last);
    await tester.pumpAndSettle();

    expect(find.text('Planetary Conquest'), findsWidgets);
    expect(
      find.text('Treaties, sabotage, science, and armor shape the endgame.'),
      findsOneWidget,
    );
  });
}
