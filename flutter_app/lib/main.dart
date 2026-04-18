import 'package:flutter/material.dart';

import 'logic/game_session_controller.dart';
import 'pages/game_page.dart';
import 'pages/lobby_page.dart';
import 'pages/main_menu_page.dart';
import 'pages/settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DragonHackApp());
}

class DragonHackApp extends StatefulWidget {
  const DragonHackApp({super.key});

  static const String mainMenuRoute = '/';
  static const String lobbyRoute = '/lobby';
  static const String settingsRoute = '/settings';
  static const String gameRoute = '/game';

  @override
  State<DragonHackApp> createState() => _DragonHackAppState();
}

class _DragonHackAppState extends State<DragonHackApp> {
  late final GameSessionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = GameSessionController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TriggerRoyale',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      initialRoute: DragonHackApp.mainMenuRoute,
      routes: <String, WidgetBuilder>{
        DragonHackApp.mainMenuRoute: (BuildContext context) => const MainMenuPage(),
        DragonHackApp.lobbyRoute: (BuildContext context) =>
            LobbyPage(controller: _controller),
        DragonHackApp.settingsRoute: (BuildContext context) => const SettingsPage(),
        DragonHackApp.gameRoute: (BuildContext context) => GamePage(controller: _controller),
      },
    );
  }
}
