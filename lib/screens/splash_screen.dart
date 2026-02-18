import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

// Import Service & Screens
import '../services/api_services.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'mobil_home_screen.dart'; // Pastikan nama file sesuai (mobil/mobile)

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _startCheckSession();
  }

  Future<void> _startCheckSession() async {
    // 1. Jalankan Timer Minimal (agar logo tampil minimal 2 detik)
    //    dan Proses Cek Session secara bersamaan (Parallel)

    try {
      final List<dynamic> results = await Future.wait([
        Future.delayed(const Duration(seconds: 2)), // Delay visual
        _getSessionData(), // Cek logic login
      ]);

      // Ambil hasil dari _getSessionData (index ke-1)
      final sessionData = results[1] as Map<String, dynamic>?;

      if (!mounted) return;

      if (sessionData != null && sessionData['valid'] == true) {
        // --- SUKSES LOGIN ---
        bool isMobile = sessionData['isMobile'];
        String token = sessionData['token'];
        String name = sessionData['name'];

        if (isMobile) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MobileHomeScreen(token: token, name: name)),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen(token: token, name: name)),
          );
        }
      } else {
        // --- GAGAL / BELUM LOGIN ---
        _goToLogin();
      }

    } catch (e) {
      // Jika error parah, lempar ke login
      print("Error Splash: $e");
      if (mounted) _goToLogin();
    }
  }

  // Fungsi Logika Pengecekan
  Future<Map<String, dynamic>?> _getSessionData() async {
    try {
      // 1. Ambil Token dari Memory HP
      // Gunakan timeout agar tidak freeze jika SharedPreferences macet
      SharedPreferences prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw "Timeout Prefs",
      );

      String? token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        return null; // Belum login
      }

      // 2. Cek Validitas Token ke API (Sekalian ambil Role terbaru)
      // Penting: Cek ke server untuk memastikan user belum resign/dipecat/ganti role
      final profileData = await _apiService.getProfile(token).timeout(
          const Duration(seconds: 5),
          onTimeout: () => null // Jika internet mati/timeout, anggap gagal (ke login)
      );

      if (profileData != null) {
        // Cek Role Mobile
        bool isMobile = false;
        if (profileData['position'] != null && profileData['position']['is_mobile'] == true) {
          debugPrint(profileData['position']['is_mobile']);
          isMobile = true;
        }

        // Update nama terbaru ke Prefs (opsional)
        String name = profileData['name'] ?? "User";
        await prefs.setString('name', name);

        return {
          'valid': true,
          'token': token,
          'name': name,
          'isMobile': isMobile,
        };
      }
    } catch (e) {
      print("Session Check Error: $e");
    }
    return null;
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // LOGO
            Image.asset(
              "lib/assets/sbb.png",
              width: 250,
              errorBuilder: (ctx, err, stack) => const Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
            ),
            const SizedBox(height: 30),

            // Loading Indikator Kecil
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(color: Color(0xFFD32F2F), strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}