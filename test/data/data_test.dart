import 'dart:io';
import 'dart:typed_data';

import 'package:ai_sleep/core/night_record.dart';
import 'package:ai_sleep/core/session.dart';
import 'package:ai_sleep/core/stager.dart';
import 'package:ai_sleep/core/trends.dart';
import 'package:ai_sleep/data/export.dart';
import 'package:ai_sleep/data/night_repository.dart';
import 'package:ai_sleep/data/wav.dart';
import 'package:flutter_test/flutter_test.dart';

NightRecord night(String id, DateTime start, {Set<String>? tags, int snores = 0,
    List<SnoreClip>? clips, int sleepEpochs = 900}) {
  final epochs = [
    for (var i = 0; i < 10; i++) Epoch(index: i, stage: Stage.wake, movement: 0.3, snores: 0),
    for (var i = 10; i < 10 + sleepEpochs; i++)
      Epoch(index: i, stage: Stage.n2, movement: 0, snores: i < 10 + snores ? 1 : 0),
  ];
  return NightRecord(
    id: id,
    start: start,
    end: start.add(Duration(seconds: epochs.length * epochSeconds)),
    epochs: epochs,
    snoreOffsetsS: const [],
    tags: tags,
    clips: clips,
  );
}

void main() {
  late Directory dir;
  late NightRepository repo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ai_sleep_test');
    repo = NightRepository(dir);
    await repo.init();
  });
  tearDown(() => dir.delete(recursive: true));

  test('saves, loads newest first, and deletes nights', () async {
    await repo.save(night('a', DateTime(2026, 1, 1, 23), tags: {'Alcohol'}));
    await repo.save(night('b', DateTime(2026, 1, 2, 23)));
    final all = await repo.loadAll();
    expect(all.map((n) => n.id), ['b', 'a']);
    expect(all.last.tags, {'Alcohol'});

    await repo.delete(all.first);
    expect((await repo.loadAll()).map((n) => n.id), ['a']);
  });

  test('skips corrupt files instead of failing', () async {
    await repo.save(night('a', DateTime(2026, 1, 1, 23)));
    await File('${dir.path}/nights/bad.json').writeAsString('{not json');
    expect(await repo.loadAll(), hasLength(1));
  });

  test('prunes old clips but keeps the night', () async {
    final clip = File('${repo.clipsDir.path}/old.wav');
    await clip.writeAsBytes([1, 2, 3]);
    await repo.save(night('old', DateTime(2026, 1, 1, 23),
        clips: [const SnoreClip(file: 'old.wav', offsetS: 10)]));
    final removed = await repo.pruneClips(days: 30, now: DateTime(2026, 3, 1));
    expect(removed, 1);
    expect(await clip.exists(), isFalse);
    expect((await repo.loadAll()).single.clips, isEmpty);
  });

  test('WAV encoding has a valid header and length', () {
    final wav = encodeWav(List.filled(160, 0.5), 16000);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(wav.length, 44 + 320);
    expect(ByteData.sublistView(wav).getUint32(24, Endian.little), 16000);
  });

  test('sample ring keeps the latest samples in order', () {
    final ring = SampleRing(4)..addAll([1, 2, 3, 4, 5, 6]);
    expect(ring.last(3), [4, 5, 6]);
    expect(ring.last(10), [3, 4, 5, 6]);
  });

  test('CSV export has one row per night and escapes tags', () {
    final csv = exportNightsCsv([night('a', DateTime(2026, 1, 1, 23), tags: {'Late meal', 'x,y'})]);
    final lines = csv.split('\n');
    expect(lines, hasLength(2));
    expect(lines.first, startsWith('date,start,end,score'));
    expect(lines.last, contains('"Late meal;x,y"'));
    expect(exportEpochsCsv([night('a', DateTime(2026, 1, 1, 23))]).split('\n'), hasLength(911));
  });

  test('tag effects compare nights with and without a tag', () {
    final nights = [
      night('1', DateTime(2026, 1, 1), tags: {'Alcohol'}, snores: 400, sleepEpochs: 700),
      night('2', DateTime(2026, 1, 2), tags: {'Alcohol'}, snores: 400, sleepEpochs: 700),
      night('3', DateTime(2026, 1, 3)),
      night('4', DateTime(2026, 1, 4)),
    ];
    final effects = tagEffects(nights);
    expect(effects.single.tag, 'Alcohol');
    expect(effects.single.snoreDelta, greaterThan(0));
    expect(effects.single.sleepDeltaMin, closeTo(-100, 0.1));
    expect(tagEffects(nights.take(3).toList()), isEmpty, reason: 'needs 2 nights each side');
  });
}
