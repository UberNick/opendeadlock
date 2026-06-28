import 'dart:convert';

import 'game_state.dart';

class GameInvite {
  const GameInvite({
    required this.sessionId,
    required this.hostFactionId,
    required this.hostFactionName,
    required this.invitedFactionId,
    required this.invitedFactionName,
    required this.commandCount,
    required this.stateFingerprint,
    required this.snapshot,
  });

  final String sessionId;
  final String hostFactionId;
  final String hostFactionName;
  final String invitedFactionId;
  final String invitedFactionName;
  final int commandCount;
  final String stateFingerprint;
  final String snapshot;
}

class CommandPackage {
  const CommandPackage({
    required this.sessionId,
    required this.exportedByFactionId,
    required this.baseCommandCount,
    required this.commandCount,
    this.turn = 0,
    this.activeFactionId = '',
    this.activeFactionName = '',
    required this.baseCommandFingerprint,
    required this.commandFingerprint,
    required this.stateFingerprint,
    required this.commands,
  });

  final String sessionId;
  final String exportedByFactionId;
  final int baseCommandCount;
  final int commandCount;
  final int turn;
  final String activeFactionId;
  final String activeFactionName;
  final String baseCommandFingerprint;
  final String commandFingerprint;
  final String stateFingerprint;
  final List<GameCommand> commands;
}

class CommandPackagePreview {
  const CommandPackagePreview({
    required this.sessionId,
    required this.exportedByFactionId,
    required this.exportedByFactionName,
    required this.baseCommandCount,
    required this.localCommandCount,
    required this.commandCount,
    required this.overlapCommandCount,
    required this.newCommandCount,
    required this.resultTurn,
    required this.resultActiveFactionId,
    required this.resultActiveFactionName,
    required this.resultActiveControlMode,
    required this.stateFingerprint,
  });

  final String sessionId;
  final String exportedByFactionId;
  final String exportedByFactionName;
  final int baseCommandCount;
  final int localCommandCount;
  final int commandCount;
  final int overlapCommandCount;
  final int newCommandCount;
  final int resultTurn;
  final String resultActiveFactionId;
  final String resultActiveFactionName;
  final String resultActiveControlMode;
  final String stateFingerprint;

  bool get hasNewCommands {
    return newCommandCount > 0;
  }

  String get summaryLabel {
    final orderLabel = newCommandCount == 1 ? 'order' : 'orders';
    if (!hasNewCommands) {
      return 'No new orders from $exportedByFactionName';
    }
    return '$newCommandCount new $orderLabel from $exportedByFactionName';
  }

  String get resultLabel {
    return 'Turn $resultTurn | $resultActiveFactionName';
  }

  String get handoffLabel {
    return GameCodec.turnHandoffLabelFor(
      turn: resultTurn,
      activeFactionName: resultActiveFactionName,
      controlMode: resultActiveControlMode,
    );
  }
}

class GameCodec {
  const GameCodec._();

  static const int version = 1;
  static const String shareCodePrefix = 'OD1.';
  static const String snapshotKind = 'opendeadlock.snapshot';
  static const String commandsKind = 'opendeadlock.commands';
  static const String commandPackageKind = 'opendeadlock.order_package';
  static const String inviteKind = 'opendeadlock.invite';

  static String createSessionId({String prefix = 'session'}) {
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    final nonce = _fingerprint('$prefix-$now-${Object().hashCode}');
    return '$prefix-${now.toRadixString(36)}-$nonce';
  }

  static String encodeGame(OpenDeadlockGame game) {
    return jsonEncode(<String, dynamic>{
      'kind': snapshotKind,
      'version': version,
      'commandCount': game.commandHistory.length,
      'stateFingerprint': fingerprintGame(game),
      'game': game.toJson(),
    });
  }

  static OpenDeadlockGame decodeGame(String source) {
    final root = _decodeRoot(source);
    _checkVersion(root);
    return OpenDeadlockGame.fromJson(root['game'] as Map<String, dynamic>);
  }

  static OpenDeadlockGame decodeGameOrInvite(String source) {
    final root = _decodeRoot(source);
    final kind = root['kind'] as String?;
    if (kind == inviteKind) {
      return decodeInvitedGame(source);
    }
    return decodeGame(source);
  }

  static String encodeGameInvite(
    OpenDeadlockGame game, {
    required String invitedFactionId,
    String? hostFactionId,
  }) {
    final invitedFaction = game.factionById(invitedFactionId);
    if (invitedFaction == null) {
      throw ArgumentError('Unknown invited faction: $invitedFactionId.');
    }
    final hostFaction = _hostFactionFor(game, hostFactionId);
    return jsonEncode(<String, dynamic>{
      'kind': inviteKind,
      'version': version,
      'sessionId': game.sessionId,
      'hostFactionId': hostFaction.id,
      'hostFactionName': hostFaction.name,
      'invitedFactionId': invitedFaction.id,
      'invitedFactionName': invitedFaction.name,
      'commandCount': game.commandHistory.length,
      'stateFingerprint': fingerprintGame(game),
      'snapshot': encodeGame(game),
    });
  }

  static GameInvite decodeGameInvite(String source) {
    final root = _decodeRoot(source);
    _checkVersion(root);
    _checkKind(root, inviteKind);
    final invite = GameInvite(
      sessionId: root['sessionId'] as String? ?? '',
      hostFactionId: root['hostFactionId'] as String? ?? '',
      hostFactionName: root['hostFactionName'] as String? ?? '',
      invitedFactionId: root['invitedFactionId'] as String,
      invitedFactionName: root['invitedFactionName'] as String? ?? '',
      commandCount: _readVersion(root['commandCount']),
      stateFingerprint: root['stateFingerprint'] as String,
      snapshot: root['snapshot'] as String,
    );
    _validateInviteSnapshot(invite);
    return invite;
  }

  static OpenDeadlockGame decodeInvitedGame(String source) {
    final invite = decodeGameInvite(source);
    return decodeGame(invite.snapshot).localPerspectiveFor(
      invite.invitedFactionId,
    );
  }

  static String encodeCommands(Iterable<GameCommand> commands) {
    final commandList = commands.toList();
    return jsonEncode(<String, dynamic>{
      'kind': commandsKind,
      'version': version,
      'commandCount': commandList.length,
      'commands': commandList.map((command) => command.toJson()).toList(),
    });
  }

  static List<GameCommand> decodeCommands(String source) {
    final root = _decodeRoot(source);
    _checkVersion(root);
    return (root['commands'] as List<dynamic>)
        .map((command) => GameCommand.fromJson(command as Map<String, dynamic>))
        .toList();
  }

  static String encodeCommandPackage(
    OpenDeadlockGame game, {
    int fromCommandIndex = 0,
    String? exportedByFactionId,
  }) {
    if (fromCommandIndex < 0 || fromCommandIndex > game.commandHistory.length) {
      throw ArgumentError(
          'Invalid command package start index: $fromCommandIndex.');
    }
    final commands = game.commandHistory
        .skip(fromCommandIndex)
        .map((record) => record.command)
        .toList();
    final exportingFactionId = exportedByFactionId ??
        (commands.isEmpty ? game.activeFactionId : commands.last.factionId);
    return jsonEncode(<String, dynamic>{
      'kind': commandPackageKind,
      'version': version,
      'sessionId': game.sessionId,
      'exportedByFactionId': exportingFactionId,
      'baseCommandCount': fromCommandIndex,
      'commandCount': game.commandHistory.length,
      'turn': game.turn,
      'activeFactionId': game.activeFactionId,
      'activeFactionName': game.activeFaction.name,
      'baseCommandFingerprint': fingerprintCommands(
        game.commandHistory
            .take(fromCommandIndex)
            .map((record) => record.command),
      ),
      'commandFingerprint': fingerprintCommands(
        game.commandHistory.map((record) => record.command),
      ),
      'stateFingerprint': fingerprintGame(game),
      'commands': commands.map((command) => command.toJson()).toList(),
    });
  }

  static CommandPackage decodeCommandPackage(String source) {
    final root = _decodeRoot(source);
    _checkVersion(root);
    _checkKind(root, commandPackageKind);
    final baseCommandCount = _readVersion(root['baseCommandCount']);
    final commandCount = _readVersion(root['commandCount']);
    final commands = (root['commands'] as List<dynamic>)
        .map((command) => GameCommand.fromJson(command as Map<String, dynamic>))
        .toList();
    if (baseCommandCount + commands.length != commandCount) {
      throw ArgumentError(
          'Command package count does not match its command list.');
    }
    return CommandPackage(
      sessionId: root['sessionId'] as String? ?? '',
      exportedByFactionId: root['exportedByFactionId'] as String? ?? '',
      baseCommandCount: baseCommandCount,
      commandCount: commandCount,
      turn: _readOptionalInt(root['turn']),
      activeFactionId: root['activeFactionId'] as String? ?? '',
      activeFactionName: root['activeFactionName'] as String? ?? '',
      baseCommandFingerprint: root['baseCommandFingerprint'] as String? ?? '',
      commandFingerprint: root['commandFingerprint'] as String? ?? '',
      stateFingerprint: root['stateFingerprint'] as String,
      commands: commands,
    );
  }

  static OpenDeadlockGame applyCommandPackage(
    OpenDeadlockGame game,
    CommandPackage package,
  ) {
    return _mergeCommandPackage(game, package).game;
  }

  static CommandPackagePreview previewCommandPackage(
    OpenDeadlockGame game,
    CommandPackage package,
  ) {
    final merge = _mergeCommandPackage(game, package);
    final exportedByFaction = package.exportedByFactionId.isEmpty
        ? null
        : game.factionById(package.exportedByFactionId);
    return CommandPackagePreview(
      sessionId: package.sessionId,
      exportedByFactionId: package.exportedByFactionId,
      exportedByFactionName: exportedByFaction?.name ??
          (package.exportedByFactionId.isEmpty
              ? 'unknown faction'
              : package.exportedByFactionId),
      baseCommandCount: package.baseCommandCount,
      localCommandCount: game.commandHistory.length,
      commandCount: package.commandCount,
      overlapCommandCount: merge.overlapCommandCount,
      newCommandCount: merge.newCommandCount,
      resultTurn: merge.game.turn,
      resultActiveFactionId: merge.game.activeFactionId,
      resultActiveFactionName: merge.game.activeFaction.name,
      resultActiveControlMode: merge.game.activeFaction.controlMode,
      stateFingerprint: package.stateFingerprint,
    );
  }

  static String turnHandoffLabelFor({
    required int turn,
    required String activeFactionName,
    required String controlMode,
  }) {
    final resultLabel = 'Turn $turn | $activeFactionName';
    if (controlMode == Faction.controlLocal) {
      return 'Your turn | $resultLabel';
    }
    if (controlMode == Faction.controlRemote) {
      return 'Waiting for sync | $resultLabel';
    }
    if (controlMode == Faction.controlComputer) {
      return 'Run AI | $resultLabel';
    }
    final controlLabel = Faction.controlModeLabelFor(controlMode);
    return 'Next up ($controlLabel) | $resultLabel';
  }

  static _CommandPackageMerge _mergeCommandPackage(
    OpenDeadlockGame game,
    CommandPackage package,
  ) {
    if (package.sessionId.isNotEmpty && package.sessionId != game.sessionId) {
      throw ArgumentError(
        'Command package is for session ${package.sessionId}, '
        'but this game is session ${game.sessionId}.',
      );
    }
    if (package.baseCommandCount > game.commandHistory.length) {
      throw ArgumentError(
        'Command package starts at ${package.baseCommandCount}, '
        'but the current game has only ${game.commandHistory.length} command(s).',
      );
    }
    if (package.baseCommandFingerprint.isNotEmpty) {
      final localBaseFingerprint = fingerprintCommands(
        game.commandHistory
            .take(package.baseCommandCount)
            .map((record) => record.command),
      );
      if (localBaseFingerprint != package.baseCommandFingerprint) {
        throw ArgumentError(
          'Command package base history does not match this game.',
        );
      }
    }

    var updatedGame = game;
    var packageIndex = 0;
    var historyIndex = package.baseCommandCount;
    while (historyIndex < game.commandHistory.length &&
        packageIndex < package.commands.length) {
      final localCommand = game.commandHistory[historyIndex].command;
      final incomingCommand = package.commands[packageIndex];
      if (!_commandsMatch(localCommand, incomingCommand)) {
        throw ArgumentError(
            'Command package diverges from local history at command $historyIndex.');
      }
      historyIndex += 1;
      packageIndex += 1;
    }

    final overlapCommandCount = packageIndex;
    var newCommandCount = 0;
    while (packageIndex < package.commands.length) {
      updatedGame = updatedGame.applyCommand(package.commands[packageIndex]);
      packageIndex += 1;
      newCommandCount += 1;
    }
    if (package.commandFingerprint.isNotEmpty) {
      final updatedCommandFingerprint = fingerprintCommands(
        updatedGame.commandHistory
            .take(package.commandCount)
            .map((record) => record.command),
      );
      if (updatedCommandFingerprint != package.commandFingerprint) {
        throw ArgumentError(
          'Command package final history does not match the synced game.',
        );
      }
    }
    if (package.turn != 0 && package.turn != updatedGame.turn) {
      throw ArgumentError(
        'Command package ends on turn ${package.turn}, '
        'but the synced game ends on turn ${updatedGame.turn}.',
      );
    }
    if (package.activeFactionId.isNotEmpty &&
        package.activeFactionId != updatedGame.activeFactionId) {
      throw ArgumentError(
        'Command package ends with active faction ${package.activeFactionId}, '
        'but the synced game is waiting for ${updatedGame.activeFactionId}.',
      );
    }
    if (package.activeFactionName.isNotEmpty &&
        package.activeFactionName != updatedGame.activeFaction.name) {
      throw ArgumentError(
        'Command package active faction label does not match the synced game.',
      );
    }
    final updatedStateFingerprint = fingerprintGame(updatedGame);
    if (updatedStateFingerprint != package.stateFingerprint) {
      throw ArgumentError(
        'Command package final state does not match the synced game.',
      );
    }
    return _CommandPackageMerge(
      game: updatedGame,
      overlapCommandCount: overlapCommandCount,
      newCommandCount: newCommandCount,
    );
  }

  static String fingerprintGame(OpenDeadlockGame game) {
    return _fingerprint(jsonEncode(_canonicalSyncJsonFor(game)));
  }

  static String fingerprintCommands(Iterable<GameCommand> commands) {
    return _fingerprint(
      jsonEncode(commands.map((command) => command.toJson()).toList()),
    );
  }

  static bool isShareCode(String source) {
    return source.trim().startsWith(shareCodePrefix);
  }

  static String encodeShareCode(String source) {
    final compressed = _LzwCodec.compress(utf8.encode(source));
    final encoded = base64Url.encode(compressed).replaceAll('=', '');
    return '$shareCodePrefix$encoded';
  }

  static String decodeShareCode(String source) {
    final trimmed = source.trim();
    if (!trimmed.startsWith(shareCodePrefix)) {
      return source;
    }
    final encoded = trimmed.substring(shareCodePrefix.length);
    final padding = (4 - encoded.length % 4) % 4;
    final padded = '$encoded${List.filled(padding, '=').join()}';
    final compressed = base64Url.decode(padded);
    return utf8.decode(_LzwCodec.decompress(compressed));
  }

  static void _checkVersion(Map<String, dynamic> root) {
    final fileVersion = _readVersion(root['version']);
    if (fileVersion != version) {
      throw ArgumentError('Unsupported game data version: $fileVersion.');
    }
  }

  static void _checkKind(Map<String, dynamic> root, String expectedKind) {
    final kind = root['kind'] as String?;
    if (kind != expectedKind) {
      throw ArgumentError('Expected $expectedKind data, got $kind.');
    }
  }

  static int _readVersion(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    throw ArgumentError('Missing game data version.');
  }

  static int _readOptionalInt(Object? value) {
    if (value == null) {
      return 0;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? 0;
  }

  static bool _commandsMatch(GameCommand a, GameCommand b) {
    return jsonEncode(a.toJson()) == jsonEncode(b.toJson());
  }

  static Map<String, dynamic> _decodeRoot(String source) {
    return jsonDecode(decodeShareCode(source)) as Map<String, dynamic>;
  }

  static Faction _hostFactionFor(
    OpenDeadlockGame game,
    String? hostFactionId,
  ) {
    if (hostFactionId != null) {
      final faction = game.factionById(hostFactionId);
      if (faction == null) {
        throw ArgumentError('Unknown host faction: $hostFactionId.');
      }
      return faction;
    }
    for (final faction in game.factions) {
      if (faction.isLocal) {
        return faction;
      }
    }
    return game.activeFaction;
  }

  static void _validateInviteSnapshot(GameInvite invite) {
    final game = decodeGame(invite.snapshot);
    if (invite.sessionId.isNotEmpty && invite.sessionId != game.sessionId) {
      throw ArgumentError(
        'Invite is for session ${invite.sessionId}, '
        'but its snapshot is session ${game.sessionId}.',
      );
    }
    if (invite.commandCount != game.commandHistory.length) {
      throw ArgumentError(
        'Invite command count does not match its snapshot.',
      );
    }
    if (invite.stateFingerprint != fingerprintGame(game)) {
      throw ArgumentError(
        'Invite state fingerprint does not match its snapshot.',
      );
    }
    if (game.factionById(invite.invitedFactionId) == null) {
      throw ArgumentError(
        'Invite references unknown faction ${invite.invitedFactionId}.',
      );
    }
  }

  static Map<String, dynamic> _canonicalSyncJsonFor(OpenDeadlockGame game) {
    final root = game.toJson();
    root['factions'] = (root['factions'] as List<dynamic>).map((entry) {
      final faction = Map<String, dynamic>.from(
        entry as Map<String, dynamic>,
      );
      final controlMode = faction['controlMode'] as String? ??
          ((faction['isComputer'] as bool? ?? false)
              ? Faction.controlComputer
              : Faction.controlLocal);
      final isComputer = controlMode == Faction.controlComputer;
      faction['isComputer'] = isComputer;
      faction['controlMode'] = isComputer ? Faction.controlComputer : 'human';
      return faction;
    }).toList();
    return root;
  }

  static String _fingerprint(String value) {
    var hash = 0x811C9DC5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

class _CommandPackageMerge {
  const _CommandPackageMerge({
    required this.game,
    required this.overlapCommandCount,
    required this.newCommandCount,
  });

  final OpenDeadlockGame game;
  final int overlapCommandCount;
  final int newCommandCount;
}

class _LzwCodec {
  const _LzwCodec._();

  static List<int> compress(List<int> input) {
    if (input.isEmpty) {
      return const <int>[];
    }

    final dictionary = <String, int>{};
    for (var value = 0; value < 256; value += 1) {
      dictionary[String.fromCharCode(value)] = value;
    }

    final writer = _BitWriter();
    var dictionarySize = 256;
    var sequence = String.fromCharCode(input.first);

    for (var index = 1; index < input.length; index += 1) {
      final character = String.fromCharCode(input[index]);
      final candidate = '$sequence$character';
      if (dictionary.containsKey(candidate)) {
        sequence = candidate;
        continue;
      }

      writer.write(dictionary[sequence]!, 16);
      if (dictionarySize < 0x10000) {
        dictionary[candidate] = dictionarySize;
        dictionarySize += 1;
      }
      sequence = character;
    }

    writer.write(dictionary[sequence]!, 16);
    return writer.toBytes();
  }

  static List<int> decompress(List<int> input) {
    if (input.isEmpty) {
      return const <int>[];
    }

    final reader = _BitReader(input);
    final dictionary = <int, List<int>>{};
    for (var value = 0; value < 256; value += 1) {
      dictionary[value] = <int>[value];
    }

    var dictionarySize = 256;
    final firstCode = reader.read(16);
    if (firstCode == null || !dictionary.containsKey(firstCode)) {
      throw ArgumentError('Invalid OpenDeadlock share code.');
    }

    var sequence = dictionary[firstCode]!;
    final output = <int>[...sequence];
    int? code;
    while ((code = reader.read(16)) != null) {
      late final List<int> entry;
      if (dictionary.containsKey(code)) {
        entry = dictionary[code]!;
      } else if (code == dictionarySize) {
        entry = <int>[...sequence, sequence.first];
      } else {
        throw ArgumentError('Invalid OpenDeadlock share code.');
      }

      output.addAll(entry);
      if (dictionarySize < 0x10000) {
        dictionary[dictionarySize] = <int>[...sequence, entry.first];
        dictionarySize += 1;
      }
      sequence = entry;
    }

    return output;
  }
}

class _BitWriter {
  final List<int> _bytes = <int>[];
  int _current = 0;
  int _bitCount = 0;

  void write(int value, int width) {
    for (var index = 0; index < width; index += 1) {
      final bit = (value >> index) & 1;
      _current |= bit << _bitCount;
      _bitCount += 1;
      if (_bitCount == 8) {
        _bytes.add(_current);
        _current = 0;
        _bitCount = 0;
      }
    }
  }

  List<int> toBytes() {
    if (_bitCount > 0) {
      _bytes.add(_current);
    }
    return _bytes;
  }
}

class _BitReader {
  _BitReader(this._bytes);

  final List<int> _bytes;
  int _bitOffset = 0;

  int? read(int width) {
    if ((_bytes.length * 8) - _bitOffset < width) {
      return null;
    }

    var value = 0;
    for (var index = 0; index < width; index += 1) {
      final absoluteBit = _bitOffset + index;
      final byte = _bytes[absoluteBit ~/ 8];
      final bit = (byte >> (absoluteBit % 8)) & 1;
      value |= bit << index;
    }
    _bitOffset += width;
    return value;
  }
}
