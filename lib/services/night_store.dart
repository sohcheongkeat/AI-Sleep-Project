import 'package:flutter/foundation.dart';

import '../core/night_record.dart';
import '../data/night_repository.dart';

/// In-memory list of saved nights (newest first) that the screens listen to.
class NightStore extends ChangeNotifier {
  NightStore(this.repository);

  final NightRepository repository;
  List<NightRecord> nights = [];

  Future<void> reload() async {
    nights = await repository.loadAll();
    notifyListeners();
  }

  Future<void> save(NightRecord night) async {
    await repository.save(night);
    await reload();
  }

  Future<void> delete(NightRecord night) async {
    await repository.delete(night);
    await reload();
  }

  Future<void> deleteAll() async {
    await repository.deleteAll();
    await reload();
  }

  /// Nights before [night], newest first — the history used for advice.
  List<NightRecord> historyBefore(NightRecord night) =>
      nights.where((n) => n.start.isBefore(night.start)).toList();
}
