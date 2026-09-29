import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path_provider/path_provider.dart';

import 'data/night_repository.dart';
import 'services/alarm_service.dart';
import 'services/overnight_service.dart';
import 'services/night_store.dart';
import 'services/settings.dart';
import 'services/tracking_controller.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) FlutterForegroundTask.initCommunicationPort();
  OvernightService.init();
  await AlarmService.init();

  final dir = await getApplicationDocumentsDirectory();
  final repository = NightRepository(Directory('${dir.path}/sleep'));
  await repository.init();
  final settings = Settings(File('${dir.path}/settings.json'));
  await settings.load();
  await repository.pruneClips(days: settings.clipRetentionDays);

  final store = NightStore(repository);
  await store.reload();

  runApp(AiSleepApp(
    settings: settings,
    store: store,
    tracking: TrackingController(repository: repository),
  ));
}
