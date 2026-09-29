import 'dart:convert';
import 'dart:io';

import '../core/night_record.dart';

/// Stores each night as a JSON file, and snore clips as WAV files, in a
/// directory on the phone. Nothing leaves the device unless exported.
class NightRepository {
  NightRepository(this.root);

  final Directory root;

  Directory get _nights => Directory('${root.path}/nights');
  Directory get clipsDir => Directory('${root.path}/clips');

  Future<void> init() async {
    await _nights.create(recursive: true);
    await clipsDir.create(recursive: true);
  }

  File _file(String id) => File('${_nights.path}/$id.json');

  Future<void> save(NightRecord night) async {
    final tmp = File('${_file(night.id).path}.tmp');
    await tmp.writeAsString(jsonEncode(night.toJson()), flush: true);
    await tmp.rename(_file(night.id).path); // atomic replace
  }

  /// All nights, newest first. Unreadable files are skipped, not fatal.
  Future<List<NightRecord>> loadAll() async {
    if (!await _nights.exists()) return [];
    final nights = <NightRecord>[];
    await for (final f in _nights.list()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      try {
        final j = jsonDecode(await f.readAsString()) as Map<String, Object?>;
        nights.add(NightRecord.fromJson(j));
      } on FormatException {
        continue;
      }
    }
    nights.sort((a, b) => b.start.compareTo(a.start));
    return nights;
  }

  Future<void> delete(NightRecord night) async {
    for (final c in night.clips) {
      final f = File('${clipsDir.path}/${c.file}');
      if (await f.exists()) await f.delete();
    }
    final f = _file(night.id);
    if (await f.exists()) await f.delete();
  }

  Future<void> deleteAll() async {
    if (await root.exists()) await root.delete(recursive: true);
    await init();
  }

  /// Deletes clips from nights older than [days]; the night's stats are kept.
  Future<int> pruneClips({required int days, DateTime? now}) async {
    final cutoff = (now ?? DateTime.now()).subtract(Duration(days: days));
    var removed = 0;
    for (final night in await loadAll()) {
      if (night.clips.isEmpty || night.start.isAfter(cutoff)) continue;
      for (final c in night.clips) {
        final f = File('${clipsDir.path}/${c.file}');
        if (await f.exists()) {
          await f.delete();
          removed++;
        }
      }
      await save(night.copyWith(clips: []));
    }
    return removed;
  }
}
