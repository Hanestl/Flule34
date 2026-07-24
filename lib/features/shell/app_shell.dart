import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/rule34video_api.dart';
import '../account/account_page.dart';
import '../home/home_page.dart';
import '../search/search_page.dart';

class AdultGate extends StatefulWidget {
  const AdultGate({super.key, required this.api});

  final Rule34VideoApi api;

  @override
  State<AdultGate> createState() => _AdultGateState();
}

class _AdultGateState extends State<AdultGate> {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  late Future<bool> _confirmedFuture;

  @override
  void initState() {
    super.initState();
    _confirmedFuture = _isConfirmed();
  }

  Future<bool> _isConfirmed() async {
    return await _preferences.getBool('adult_confirmed') ?? false;
  }

  Future<void> _confirm() async {
    await _preferences.setBool('adult_confirmed', true);
    if (mounted) {
      setState(() {
        _confirmedFuture = Future<bool>.value(true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _confirmedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _Splash();
        }
        if (snapshot.data == true) {
          return AppShell(api: widget.api);
        }
        return _AgeConfirmation(onConfirm: _confirm);
      },
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.api});

  final Rule34VideoApi api;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(api: widget.api),
      SearchPage(api: widget.api),
      AccountPage(api: widget.api),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(icon: Icon(Icons.search), label: '搜索'),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _AgeConfirmation extends StatelessWidget {
  const _AgeConfirmation({required this.onConfirm});

  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 52,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '仅限成年人',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '本应用包含仅适合成年人的内容。继续即表示你已达到所在地区法定成年年龄，并同意遵守当地法律。',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: onConfirm,
                    child: const Text('我已年满法定成年年龄'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('未达到法定成年年龄时，请不要继续使用本应用。')),
                    ),
                    child: const Text('我未达到法定成年年龄'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
