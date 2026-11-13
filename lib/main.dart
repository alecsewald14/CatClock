import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app/live_screen.dart';
import 'app/theme.dart';
import 'weather/weather_repository.dart';
import 'weather/weather_setup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dataDirectory = await getApplicationSupportDirectory();
  runApp(CatClockApp(weather: createWeatherRepository(dataDirectory)));
}

Future<void> _openInBrowser(Uri address) async {
  await launchUrl(address, mode: LaunchMode.externalApplication);
}

class CatClockApp extends StatelessWidget {
  const CatClockApp({
    super.key,
    required this.weather,
    this.openLink = _openInBrowser,
    this.clock = DateTime.now,
  });

  /// Keeps the weather up to date. Replaced by a fake one in tests.
  final WeatherRepository weather;

  /// Opens a web address in the person's browser. Replaced in tests.
  final Future<void> Function(Uri address) openLink;

  /// The device's local time. Replaced in tests.
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cat Clock',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: LiveScreen(weather: weather, openLink: openLink, clock: clock),
    );
  }
}
