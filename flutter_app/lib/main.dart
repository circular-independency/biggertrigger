import 'package:flutter/material.dart';

import 'pages/end_game_page.dart';
import 'pages/game_page.dart';
import 'pages/lobby_page.dart';
import 'pages/main_menu_page.dart';
import 'pages/settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DragonHackApp());
}

class DragonHackApp extends StatelessWidget {
  const DragonHackApp({super.key});

  static const String mainMenuRoute = '/';
  static const String lobbyRoute = '/lobby';
  static const String settingsRoute = '/settings';
  static const String gameRoute = '/game';
  static const String endGameRoute = '/endgame';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DragonHack',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      initialRoute: mainMenuRoute,
      routes: {
        mainMenuRoute: (context) => const MainMenuPage(),
        lobbyRoute: (context) => LobbyPage(),
        settingsRoute: (context) => const SettingsPage(),
        gameRoute: (context) {
          final Object? args = ModalRoute.of(context)?.settings.arguments;
          final GameStartData? startData = args is GameStartData ? args : null;
          return GamePage(startData: startData);
        },
        endGameRoute: (context) {
          final Object? args = ModalRoute.of(context)?.settings.arguments;
          final String? username = args is Map
              ? args['username']?.toString()
              : null;
          return EndGamePage(username: username);
        },
      },
    );
  }
}
