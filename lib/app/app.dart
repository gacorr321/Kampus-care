import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_strings.dart';
import '../presentation/providers/auth_provider.dart';
import '../presentation/providers/item_provider.dart';
import '../presentation/providers/notification_provider.dart';
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/splash/splash_screen.dart';

class KampusCareApp extends StatelessWidget {
  const KampusCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ItemProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const _AuthGate(),
    );
  }
}

/// Watches [AuthProvider.status] and shows the appropriate screen.
/// Calls [AuthProvider.checkAuthState] on first build to resolve persistent auth.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void initState() {
    super.initState();
    // AuthProvider is available because MultiProvider is an ancestor.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AuthProvider>().checkAuthState();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        Widget home;
        switch (auth.status) {
          case AuthStatus.authenticated:
            home = const HomeScreen();
            break;
          case AuthStatus.unauthenticated:
            home = const LoginScreen();
            break;
          case AuthStatus.uninitialized:
            home = const SplashScreen();
            break;
        }

        return MaterialApp(
          title: AppStrings.appName,
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          home: home,
        );
      },
    );
  }
}
