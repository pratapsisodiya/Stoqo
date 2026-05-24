import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stoqomobile/app.dart';
import 'package:stoqomobile/core/database/app_database.dart';
import 'package:stoqomobile/core/sync/background_sync_service.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await AppDatabase.instance;

  // Single ProviderContainer shared between the widget tree and background services
  final container = ProviderContainer();
  BackgroundSyncService.instance.start(container);

  runApp(UncontrolledProviderScope(container: container, child: const StoqoApp()));
}
