import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main_map_screen.dart';
import 'login_screen.dart';
import 'supplier_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ltlbpxxdkryfhgrynoey.supabase.co',
    anonKey: 'sb_publishable_5bwjhOGLRTEr-7vYBkXJsg_xgr-S4pq',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eau Sénégal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.cyan, AppColors.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(Icons.water_drop_rounded,
                        size: 38, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 3),
                ],
              ),
            ),
          );
        }

        final session = snapshot.data?.session;
        if (session != null) {
          final userMetadata = session.user.userMetadata;
          final role = userMetadata?['role'] ?? 'boutiquier';

          debugPrint("Rôle détecté dans les métadonnées : $role");

          if (role == 'fournisseur') {
            return const SupplierScreen();
          } else {
            return const MainMapScreen();
          }
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
