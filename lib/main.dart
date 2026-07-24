import 'package:flutter/material.dart';

import 'core/api/rule34video_api.dart';
import 'core/session/session_store.dart';
import 'features/shell/app_shell.dart';

void main() {
  runApp(const AppBootstrap());
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late final SessionStore _sessionStore;
  late final Rule34VideoApi _api;
  late final Future<void> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _sessionStore = SessionStore();
    _api = Rule34VideoApi(sessionStore: _sessionStore);
    _bootstrapFuture = _sessionStore.load();
  }

  @override
  void dispose() {
    _api.close();
    _sessionStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            home: _LoadingScreen(),
            debugShowCheckedModeBanner: false,
          );
        }

        return Rule34VideoApp(api: _api);
      },
    );
  }
}

class Rule34VideoApp extends StatelessWidget {
  const Rule34VideoApp({super.key, required this.api});

  final Rule34VideoApi api;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xffd74576),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'Rule34Video',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xff101014),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: false),
      ),
      home: AdultGate(api: api),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
