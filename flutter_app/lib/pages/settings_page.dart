import 'package:flutter/material.dart';

import '../components/cyber_input_field.dart';
import '../components/cyber_theme.dart';
import '../components/hud_background.dart';
import '../components/settings_profile_card.dart';
import '../logic/socket_manager.dart';
import '../logic/user_preferences_manager.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _serverUrlController = TextEditingController();

  bool _isLoading = true;
  String? _usernameError;
  String? _serverUrlError;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final String? username = await UserPreferencesManager.getUsername();
    final String? serverUrl = await UserPreferencesManager.getServerUrl();

    if (!mounted) {
      return;
    }

    setState(() {
      _usernameController.text = username ?? 'COMMANDER_01';
      _serverUrlController.text = serverUrl ?? SocketManager.defaultSocketUrl();
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final String username = _usernameController.text.trim();
    final String serverUrl = SocketManager.normalizeSocketUrl(
      _serverUrlController.text.trim(),
    );

    setState(() {
      _usernameError = username.length < 3
          ? 'Username must have at least 3 characters.'
          : null;
      _serverUrlError = serverUrl.isEmpty ? 'Server URL is required.' : null;
    });

    if (_usernameError != null || _serverUrlError != null) {
      return;
    }

    await UserPreferencesManager.saveUsername(username);
    await UserPreferencesManager.saveServerUrl(serverUrl);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: CyberColors.panel,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: CyberColors.cyan.withValues(alpha: 0.7)),
            borderRadius: BorderRadius.circular(8),
          ),
          content: const Text(
            'Settings saved.',
            style: TextStyle(color: CyberColors.cyan, fontWeight: FontWeight.w700),
          ),
        ),
      );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HudBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double pad = constraints.maxWidth * 0.06;
                    final double gap = constraints.maxHeight * 0.02;

                    return SingleChildScrollView(
                      padding: EdgeInsets.all(pad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const Text(
                            'SETTINGS',
                            style: TextStyle(
                              color: CyberColors.cyan,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                            ),
                          ),
                          SizedBox(height: gap),
                          SettingsProfileCard(
                            username: _usernameController.text.trim().isEmpty
                                ? 'COMMANDER_01'
                                : _usernameController.text.trim(),
                            signalText: '[SIG_STR: 98%] // SYS_STABLE',
                            rankText: 'ELITE_TIER',
                            avatarIcon: Icons.person,
                            progress: 0.72,
                          ),
                          SizedBox(height: gap * 1.2),
                          CyberInputField(
                            controller: _usernameController,
                            label: 'USERNAME',
                            hint: 'Enter commander name',
                            errorText: _usernameError,
                          ),
                          SizedBox(height: gap),
                          CyberInputField(
                            controller: _serverUrlController,
                            label: 'SERVER_URL',
                            hint: 'ws://192.168.1.10:8765',
                            errorText: _serverUrlError,
                          ),
                          SizedBox(height: gap * 0.6),
                          const Text(
                            'Use your computer LAN IP here so all phones connect to the same websocket server.',
                            style: TextStyle(
                              color: CyberColors.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: gap),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CyberColors.lime,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                            onPressed: _saveSettings,
                            child: const Text('SAVE SETTINGS'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
