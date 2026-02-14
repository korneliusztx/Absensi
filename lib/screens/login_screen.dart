import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Pastikan sudah install package ini
import '../services/api_services.dart';
import '../models/user_model.dart';
import 'home_screen.dart';
import 'mobil_home_screen.dart';
import 'reset_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  // Controller
  final _nikController = TextEditingController();
  final _passController = TextEditingController();
  final ApiService _apiService = ApiService();

  // Animation
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;

  // State
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Colors (Sumber Baru Branding)
  final Color _brandRed = const Color(0xFFD32F2F);
  final Color _brandBlack = const Color(0xFF212121);
  // final Color _brandOrange = const Color(0xFFFFA000); // Unused for now

  // Logo Config
  final double _logoWidth = 260.0;

  @override
  void initState() {
    super.initState();
    // Setup Animasi Garis Bawah Logo
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _widthAnimation = Tween<double>(
      begin: 0.0,
      end: _logoWidth,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    ));

    _animationController.forward();

    // Opsional: Cek apakah user sudah login sebelumnya di sini
    _checkAutoLogin();
  }

  void _checkAutoLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    if (token != null) {
      // Jika butuh validasi token ke server, lakukan di sini.
      // Jika tidak, bisa langsung redirect (tapi hati-hati validitas token).
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nikController.dispose();
    _passController.dispose();
    super.dispose();
  }

  // Logic Login
  void _handleLogin() async {
    if (_nikController.text.isEmpty || _passController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("NIK dan Password harus diisi"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    // 1. Coba Login ke API
    LoginResponse res = await _apiService.login(_nikController.text, _passController.text);

    if (res.success && res.accessToken != null) {
      // SIMPAN TOKEN KE MEMORI HP (PENTING AGAR TIDAK HILANG SAAT RELOAD)
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', res.accessToken!);
      await prefs.setString('name', res.name ?? "User");
      await prefs.setString('nik', _nikController.text);

      // 2. Cek apakah harus ganti password (User Baru/Reset)
      if (res.isOldPass) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ResetPasswordScreen(token: res.accessToken!)),
        );
        return;
      }

      // 3. Ambil Profil untuk cek Posisi (Mobile/Desktop)
      var profileData = await _apiService.getProfile(res.accessToken!);
      setState(() => _isLoading = false);

      if (profileData != null) {
        // Cek logic is_mobile sesuai respons JSON backend kamu
        bool isMobile = false;
        // Contoh: profileData['position'] mungkin null, jadi pakai ?.
        if (profileData['position'] != null && profileData['position']['is_mobile'] == 1) {
          // Catatan: Pastikan backend kirim true/false atau 1/0
          isMobile = true;
        } else if (profileData['position'] != null && profileData['position']['is_mobile'] == true) {
          isMobile = true;
        }

        if (!mounted) return;

        // 4. Navigasi Berdasarkan Tipe User
        if (isMobile) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => MobileHomeScreen(
                    token: res.accessToken!,
                    name: res.name ?? "User"
                )
            ),
          );
        } else {
          // Default ke HomeScreen biasa (Desktop/Admin/Staff Kantor)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => HomeScreen(
                    token: res.accessToken!,
                    name: res.name ?? "User"
                )
            ),
          );
        }
      } else {
        // Fallback jika gagal ambil profil tapi login sukses
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen(token: res.accessToken!, name: res.name ?? "User")),
        );
      }
    } else {
      // Gagal Login
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center( // Tambahkan Center utama agar konten di tengah saat keyboard turun
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ConstrainedBox( // Agar layout tidak berantakan di layar besar
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  // --- LOGO IMAGE ---
                  Center(
                    child: Image.asset(
                      "lib/assets/sbb-removebg-preview.png", // Pastikan path di pubspec.yaml benar
                      height: 100,
                      width: 250,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.image_not_supported, size: 100, color: Colors.grey),
                    ),
                  ),

                  // --- ANIMATED LINE ---
                  const SizedBox(height: 10),
                  Center(
                    child: SizedBox(
                      width: _logoWidth,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: AnimatedBuilder(
                          animation: _widthAnimation,
                          builder: (context, child) {
                            return Container(
                              height: 4,
                              width: _widthAnimation.value,
                              decoration: BoxDecoration(
                                color: _brandRed,
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                    color: _brandRed.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- TITLE ---
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [_brandRed, _brandBlack],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ).createShader(bounds),
                    child: const Text(
                      "ABSENSI",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: Colors.white, // Warna ini akan tertimpa ShaderMask
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  Text(
                    "Masukan Data Diri",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),

                  const SizedBox(height: 40),

                  // --- INPUT FIELDS ---
                  _buildTextField(
                    controller: _nikController,
                    label: "Nomor Induk Karyawan (NIK)",
                    icon: Icons.badge_outlined,
                    inputType: TextInputType.text,
                    primaryColor: _brandRed,
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(
                    controller: _passController,
                    label: "Kata Sandi",
                    icon: Icons.lock_outline,
                    isPassword: true,
                    primaryColor: _brandRed,
                  ),

                  const SizedBox(height: 32),

                  // --- LOGIN BUTTON ---
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandRed,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: _brandRed.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        disabledBackgroundColor: _brandRed.withOpacity(0.6),
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

                  // --- FOOTER ---
                  const Center(
                    child: Text(
                      "Versi 1.0.0",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Widget Helper
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color primaryColor,
    bool isPassword = false,
    TextInputType inputType = TextInputType.text,
  }) {
    // Kita gunakan StatefulBuilder kecil atau logic di parent setState
    // agar toggle password visibility bekerja.
    // Karena _obscurePassword ada di state parent, ini sudah benar.
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        keyboardType: inputType,
        style: const TextStyle(fontSize: 16, color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
          prefixIcon: Icon(icon, color: primaryColor.withOpacity(0.8)),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey[400],
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
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