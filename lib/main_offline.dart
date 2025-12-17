import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/task_provider_offline.dart';
import 'screens/home_screen_offline.dart';
import 'services/camera_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar CameraService para detectar câmeras disponíveis
  await CameraService.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TaskProviderOffline()..initialize(),
      child: MaterialApp(
        title: 'Task Manager Offline-First',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        home: const HomeScreenOffline(),
      ),
    );
  }
}
