import 'dart:convert';

import 'game_state.dart';

class ReplayStep {
  const ReplayStep({
    required this.index,
    required this.record,
    required this.game,
  });

  final int index;
  final CommandRecord record;
  final OpenDeadlockGame game;
}

class ReplayResult {
  const ReplayResult({
    required this.game,
    required this.steps,
  });

  final OpenDeadlockGame game;
  final List<ReplayStep> steps;
}

class GameReplay {
  const GameReplay._();

  static ReplayResult replay(
    OpenDeadlockGame initial,
    Iterable<CommandRecord> history,
  ) {
    var game = initial.copyWith(commandHistory: const <CommandRecord>[]);
    final steps = <ReplayStep>[];
    var index = 0;

    for (final record in history) {
      game = game.applyCommand(record.command);
      steps.add(
        ReplayStep(
          index: index,
          record: record,
          game: game,
        ),
      );
      index += 1;
    }

    return ReplayResult(game: game, steps: steps);
  }

  static bool hasSameState(OpenDeadlockGame a, OpenDeadlockGame b) {
    return _stableGameJson(a) == _stableGameJson(b);
  }

  static String _stableGameJson(OpenDeadlockGame game) {
    return jsonEncode(game.toJson());
  }
}
