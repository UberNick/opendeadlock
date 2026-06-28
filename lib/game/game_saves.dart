import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'game_codec.dart';
import 'game_state.dart';

class SavedGameSlot {
  const SavedGameSlot({
    required this.slotId,
    required this.name,
    required this.sessionId,
    required this.updatedAtIso8601,
    required this.turn,
    required this.activeFactionId,
    required this.activeFactionName,
    required this.commandCount,
    required this.stateFingerprint,
    required this.snapshot,
  });

  final String slotId;
  final String name;
  final String sessionId;
  final String updatedAtIso8601;
  final int turn;
  final String activeFactionId;
  final String activeFactionName;
  final int commandCount;
  final String stateFingerprint;
  final String snapshot;

  OpenDeadlockGame decodeGame() {
    return GameCodec.decodeGame(snapshot);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'slotId': slotId,
      'name': name,
      'sessionId': sessionId,
      'updatedAtIso8601': updatedAtIso8601,
      'turn': turn,
      'activeFactionId': activeFactionId,
      'activeFactionName': activeFactionName,
      'commandCount': commandCount,
      'stateFingerprint': stateFingerprint,
      'snapshot': snapshot,
    };
  }

  static SavedGameSlot fromJson(Map<String, dynamic> json) {
    return SavedGameSlot(
      slotId: json['slotId'] as String,
      name: json['name'] as String,
      sessionId: json['sessionId'] as String? ?? '',
      updatedAtIso8601: json['updatedAtIso8601'] as String,
      turn: _readInt(json['turn']),
      activeFactionId: json['activeFactionId'] as String,
      activeFactionName: json['activeFactionName'] as String,
      commandCount: _readInt(json['commandCount']),
      stateFingerprint: json['stateFingerprint'] as String,
      snapshot: json['snapshot'] as String,
    );
  }
}

class GameSaveArchive {
  const GameSaveArchive._();

  static const int version = 1;
  static const String slotKind = 'opendeadlock.save_slot';

  static SavedGameSlot slotFromGame(
    OpenDeadlockGame game, {
    required String slotId,
    String? name,
    DateTime? updatedAt,
  }) {
    final snapshot = GameCodec.encodeGame(game);
    return SavedGameSlot(
      slotId: slotId,
      name: name == null || name.trim().isEmpty
          ? defaultNameFor(game)
          : name.trim(),
      sessionId: game.sessionId,
      updatedAtIso8601: (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
      turn: game.turn,
      activeFactionId: game.activeFactionId,
      activeFactionName: game.activeFaction.name,
      commandCount: game.commandHistory.length,
      stateFingerprint: GameCodec.fingerprintGame(game),
      snapshot: snapshot,
    );
  }

  static String defaultNameFor(OpenDeadlockGame game) {
    return 'Turn ${game.turn} - ${game.activeFaction.name}';
  }

  static String encodeSlot(SavedGameSlot slot) {
    return jsonEncode(<String, dynamic>{
      'kind': slotKind,
      'version': version,
      'slot': slot.toJson(),
    });
  }

  static SavedGameSlot decodeSlot(String source) {
    final root = jsonDecode(source) as Map<String, dynamic>;
    final kind = root['kind'] as String?;
    if (kind != slotKind) {
      throw ArgumentError('Expected $slotKind data, got $kind.');
    }
    final fileVersion = _readInt(root['version']);
    if (fileVersion != version) {
      throw ArgumentError('Unsupported save slot version: $fileVersion.');
    }
    return SavedGameSlot.fromJson(root['slot'] as Map<String, dynamic>);
  }
}

class GameSaveStore {
  const GameSaveStore(this.preferences);

  static const String autosaveSlotId = 'autosave';
  static const String defaultSlotId = autosaveSlotId;
  static const String manualSlotPrefix = 'manual';
  static const String _slotIndexKey = 'opendeadlock.save_slots';
  static const String _slotKeyPrefix = 'opendeadlock.save_slot.';

  final SharedPreferences preferences;

  static Future<GameSaveStore> load() async {
    final preferences = await SharedPreferences.getInstance();
    return GameSaveStore(preferences);
  }

  static String createManualSlotId({DateTime? now}) {
    final timestamp = (now ?? DateTime.now()).toUtc().microsecondsSinceEpoch;
    return '$manualSlotPrefix-${timestamp.toRadixString(36)}';
  }

  Future<List<SavedGameSlot>> loadSlots() async {
    final slotIds =
        preferences.getStringList(_slotIndexKey) ?? const <String>[];
    final slots = <SavedGameSlot>[];
    for (final slotId in slotIds) {
      final source = preferences.getString(_slotKeyFor(slotId));
      if (source == null) {
        continue;
      }
      slots.add(GameSaveArchive.decodeSlot(source));
    }
    slots.sort(
      (a, b) => b.updatedAtIso8601.compareTo(a.updatedAtIso8601),
    );
    return slots;
  }

  Future<SavedGameSlot?> loadLatestSlot() async {
    final slots = await loadSlots();
    return slots.isEmpty ? null : slots.first;
  }

  Future<OpenDeadlockGame?> loadLatestGame() async {
    final latestSlot = await loadLatestSlot();
    if (latestSlot == null) {
      return null;
    }
    return latestSlot.decodeGame();
  }

  Future<SavedGameSlot> saveGame(
    OpenDeadlockGame game, {
    String slotId = defaultSlotId,
    String? name,
    DateTime? updatedAt,
  }) async {
    final slot = GameSaveArchive.slotFromGame(
      game,
      slotId: slotId,
      name: name,
      updatedAt: updatedAt,
    );
    await preferences.setString(
      _slotKeyFor(slot.slotId),
      GameSaveArchive.encodeSlot(slot),
    );
    await _rememberSlotId(slot.slotId);
    return slot;
  }

  Future<OpenDeadlockGame?> loadGame(String slotId) async {
    final source = preferences.getString(_slotKeyFor(slotId));
    if (source == null) {
      return null;
    }
    return GameSaveArchive.decodeSlot(source).decodeGame();
  }

  Future<bool> deleteSlot(String slotId) async {
    final removed = await preferences.remove(_slotKeyFor(slotId));
    final slotIds =
        preferences.getStringList(_slotIndexKey) ?? const <String>[];
    await preferences.setStringList(
      _slotIndexKey,
      slotIds.where((currentSlotId) => currentSlotId != slotId).toList(),
    );
    return removed;
  }

  Future<void> _rememberSlotId(String slotId) async {
    final slotIds =
        preferences.getStringList(_slotIndexKey) ?? const <String>[];
    if (slotIds.contains(slotId)) {
      return;
    }
    await preferences.setStringList(
      _slotIndexKey,
      <String>[...slotIds, slotId],
    );
  }

  static String _slotKeyFor(String slotId) {
    return '$_slotKeyPrefix$slotId';
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
