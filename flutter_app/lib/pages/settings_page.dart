import 'package:flutter/material.dart';

import '../components/cyber_input_field.dart';
import '../components/cyber_theme.dart';
import '../components/hud_background.dart';
import '../components/settings_profile_card.dart';
import '../logic/user_preferences_manager.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key} );

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _usernameController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final String? username = await UserPreferencesManager.getUsername();
    if (!mounted) {
      return;
    }

    setState(() {
      _usernameController.text = username ?? 'COMMANDER_01';
      _isLoading = false;
    });
  }

  Future<void> _saveUsername() async {
    final String trimmed = _usernameController.text.trim();

    if (trimmed.length < 3) {
      setState(() {
        _errorMessage = 'Username must have at least 3 characters.';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    await UserPreferencesManager.saveUsername(trimmed);
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
            'Username saved.',
            style: TextStyle(color: CyberColors.cyan, fontWeight: FontWeight.w700),
          ),
        ),
      );
  }

  @override
  void dispose() {
    _usernameController.dispose();
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
                            errorText: _errorMessage,
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
                            onPressed: _saveUsername,
                            child: const Text('SAVE USERNAME'),
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
