import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme.dart';
import 'features/auth/screens/auth_screen.dart';
import 'features/dashboard/screens/role_router.dart';
import 'shared/models/user.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Try to restore a saved session before showing any UI
  final bool autoLogged = await AuthService().tryAutoLogin();

  runApp(NewsRadarApp(startLoggedIn: autoLogged));
}

class NewsRadarApp extends StatelessWidget {
  final bool startLoggedIn;
  const NewsRadarApp({super.key, required this.startLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NewsRadar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: startLoggedIn ? const RoleRouter() : const AuthScreen(),
    );
  }
}
