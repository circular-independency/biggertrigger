import 'package:flutter/material.dart';

import '../logic/user_preferences_manager.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, UserPreferencesManager? preferencesManager})
    : preferencesManager = preferencesManager ?? const UserPreferencesManager();

  final UserPreferencesManager preferencesManager;

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
    final String? username = await widget.preferencesManager.getUsername();
    if (!mounted) {
      return;
    }

    setState(() {
      _usernameController.text = username ?? '';
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

    await widget.preferencesManager.saveUsername(trimmed);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Username saved.')),
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
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      errorText: _errorMessage,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _saveUsername,
                    child: const Text('Save Username'),
                  ),
                ],
              ),
            ),
    );
  }
}
