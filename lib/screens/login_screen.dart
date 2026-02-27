import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_device_info/my_device_info.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart'; // 1. Import Wajib
import 'package:package_info_plus/package_info_plus.dart'; // 1. Import Wajib
import 'dart:io';
import '../services/api_services.dart';
import '../models/user_model.dart';
import 'home_screen.dart';
import 'mobile_home_screen.dart';
import 'reset_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  // Controller
  final _nikController = TextEditingController();
  final _passController = TextEditingController();
  final ApiService _apiService = ApiService();

  // Animation Controllers
  late AnimationController _entryController;
  late Animation<double> _entryAnimation;

  late AnimationController _formFadeController;
  late Animation<double> _formFadeAnimation;
  late Animation<Offset> _formSlideAnimation;

  // State
  bool _isLoading = false;
  final ValueNotifier<bool> _obscurePasswordNotifier = ValueNotifier(true);

  // Variable Device Data
  String? _deviceImei;
  String? _onesignalId;
  String _appVersion = "";

  // Colors
  final Color _brandRed = const Color(0xFFD32F2F);
  final Color _brandBlack = const Color(0xFF212121);
  final double _logoWidth = 260.0;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initDeviceId();
    _initOneSignalId();
    _getAppVersion();
  }
  Future<void> _getAppVersion() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        // info.version = Versi (contoh: 1.0.0)
        // info.buildNumber = Build number (contoh: 1)
        _appVersion = info.version;
      });
    }
  }
  // --- FUNGSI AMBIL DEVICE ID ---
  Future<void> _initDeviceId() async {
    try {
      // Menggunakan property static dari package my_device_info
      String? deviceId = await MyDeviceInfo.deviceIMEINumber;

      if (mounted) {
        setState(() => _deviceImei = deviceId);
        print("Device IMEI didapat: $_deviceImei");
      }
    } catch (e) {
      print("Gagal mengambil Device ID: $e");
      if (mounted) setState(() => _deviceImei = "unknown_device");
    }
  }

  // --- FUNGSI AMBIL ONESIGNAL ID ---
  Future<void> _initOneSignalId() async {
    // Coba ambil ID saat ini (OneSignal v5)
    var id = OneSignal.User.pushSubscription.id;

    if (mounted) {
      setState(() => _onesignalId = id);
      print("OneSignal ID Awal: $_onesignalId");
    }

    // Listener jika ID berubah (misal baru sync)
    OneSignal.User.pushSubscription.addObserver((state) {
      if (state.current.id != null) {
        print("OneSignal ID Updated: ${state.current.id}");
        if (mounted) {
          setState(() => _onesignalId = state.current.id);
        }
      }
    });
  }

  void _setupAnimations() {
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _entryAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );
    _formFadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _formFadeAnimation = CurvedAnimation(
      parent: _formFadeController,
      curve: Curves.easeOutQuart,
    );
    _formSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(_formFadeAnimation);

    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) {
        _entryController.forward();
        _formFadeController.forward();
      }
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _formFadeController.dispose();
    _nikController.dispose();
    _passController.dispose();
    _obscurePasswordNotifier.dispose();
    super.dispose();
  }

  void _navigateBasedOnRole(String token, String name, bool isMobile) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => isMobile
            ? MobileHomeScreen(token: token, name: name)
            : HomeScreen(token: token, name: name),
      ),
    );
  }

  Future<void> _handleLogin() async {
    final nik = _nikController.text.trim();
    final pass = _passController.text.trim();

    if (nik.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("NIK dan Password harus diisi"), backgroundColor: Colors.red),
      );
      return;
    }

    // Pastikan Data Device Terisi
    String finalImei = _deviceImei ?? "unknown_device";
    String finalOneSignalId = _onesignalId ?? OneSignal.User.pushSubscription.id ?? "";

    setState(() => _isLoading = true);

    try {
      // 3. Panggil API Login dengan 4 Parameter (NIK, Pass, IMEI, OneSignalID)
      LoginResponse res = await _apiService.login(nik, pass, finalImei, finalOneSignalId);

      if (res.success && res.accessToken != null) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', res.accessToken!);
        await prefs.setString('name', res.name ?? "User");
        await prefs.setString('nik', nik);

        // Simpan info device
        await prefs.setString('device_imei', finalImei);

        if (res.isOldPass) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => ResetPasswordScreen(token: res.accessToken!)),
          );
          return;
        }

        var profileData = await _apiService.getProfile(res.accessToken!);

        if (!mounted) return;
        setState(() => _isLoading = false);

        bool isMobile = false;
        String userName = res.name ?? "User";

        if (profileData != null) {
          final position = profileData['position'];
          if (position != null && position['is_mobile'] == true) {
            isMobile = true;
          }
          if (profileData['name'] != null) {
            userName = profileData['name'];
          }
        }

        _navigateBasedOnRole(res.accessToken!, userName, isMobile);

      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Terjadi kesalahan: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),

                  // --- LOGO IMAGE ---
                  RepaintBoundary(
                    child: Center(
                      child: Hero(
                        tag: 'app_logo',
                        child: Image.asset(
                          "lib/assets/sbb.png",
                          height: 100,
                          width: 250,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.image_not_supported, size: 100, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // --- ANIMATED LINE ---
                  RepaintBoundary(
                    child: Center(
                      child: SizedBox(
                        width: _logoWidth,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AnimatedBuilder(
                            animation: _entryAnimation,
                            builder: (context, child) {
                              return Container(
                                height: 4,
                                width: _logoWidth * _entryAnimation.value,
                                decoration: BoxDecoration(
                                  color: _brandRed,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- FORM CONTENT ---
                  FadeTransition(
                    opacity: _formFadeAnimation,
                    child: SlideTransition(
                      position: _formSlideAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            "ABSENSI",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: Color(0xFF212121),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Masukan Data Diri",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 40),

                          // INPUT NIK
                          _buildTextField(
                            controller: _nikController,
                            label: "Nomor Induk Karyawan (NIK)",
                            icon: Icons.badge_outlined,
                            primaryColor: _brandRed,
                            isPassword: false,
                          ),
                          const SizedBox(height: 20),

                          // INPUT PASSWORD
                          ValueListenableBuilder<bool>(
                            valueListenable: _obscurePasswordNotifier,
                            builder: (context, isObscure, child) {
                              return _buildTextField(
                                controller: _passController,
                                label: "Kata Sandi",
                                icon: Icons.lock_outline,
                                primaryColor: _brandRed,
                                isPassword: true,
                                isObscure: isObscure,
                                onToggleVisibility: () {
                                  _obscurePasswordNotifier.value = !isObscure;
                                },
                              );
                            },
                          ),

                          const SizedBox(height: 32),

                          // TOMBOL LOGIN
                          SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _brandRed,
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                                  : const Text(
                                "MASUK",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),
                          Center(
                            child: Text(
                              "Versi $_appVersion",
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color primaryColor,
    required bool isPassword,
    bool isObscure = false,
    VoidCallback? onToggleVisibility,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? isObscure : false,
        keyboardType: isPassword ? TextInputType.visiblePassword : TextInputType.text,
        style: const TextStyle(fontSize: 16, color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
          prefixIcon: Icon(icon, color: primaryColor.withOpacity(0.8)),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              isObscure ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey[400],
            ),
            onPressed: onToggleVisibility,
          )
              : null,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: primaryColor, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: primaryColor, width: 2.0),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        ),
      ),
    );
  }
}