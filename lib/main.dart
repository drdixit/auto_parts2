import 'package:flutter/material.dart';
import 'package:auto_parts2/screens/home_screen.dart';
import 'package:auto_parts2/theme/app_colors.dart';
import 'package:auto_parts2/database/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database for desktop platforms
  await DatabaseHelper.initializeDatabase();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auto Parts Inventory',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.surface,
          primary: AppColors.buttonNeutral,
          secondary: AppColors.chipSelected,
          error: AppColors.error,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.surfaceLight,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
