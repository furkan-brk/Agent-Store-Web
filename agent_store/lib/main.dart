import 'package:flutter/material.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'shared/services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.instance.init(); // restore JWT from SharedPreferences
  runApp(const AgentStoreApp());
}

class AgentStoreApp extends StatelessWidget {
  const AgentStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Agent Store',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: AppRouter.router,
    );
  }
}
