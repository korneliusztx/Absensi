import 'package:absensi_evotap/screens/mobil_home_screen.dart';
import 'package:flutter/material.dart';
import '../services/api_services.dart';
import '../models/user_model.dart';
import 'home_screen.dart';
import 'reset_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nikController = TextEditingController();
  final _passController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  bool _obscurePassword = true; // State untuk lihat/tutup password

  final Color _primaryColor = const Color(0xFF1E88E5); // Biru Profesional

  void _handleLogin() async {

    setState(() => _isLoading = true);

    LoginResponse res = await _apiService.login(_nikController.text, _passController.text);

    if (res.success && res.accessToken != null) {

      if (res.isOldPass) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ResetPasswordScreen(token: res.accessToken!)),
        );
        return;
      }

      var profileData = await _apiService.getProfile(res.accessToken!);

      setState(() => _isLoading = false); // Stop loading

      if (profileData != null) {
        bool isMobile = false;

        if (profileData['position'] != null && profileData['position']['is_mobile'] == true) {
          isMobile = true;
        }

        if (!mounted) return;

        if (isMobile) {
          // Ke Halaman Khusus Mobile (2 Tombol)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MobileHomeScreen(token: res.accessToken!, name: res.name ?? "User")),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen(token: res.accessToken!, name: res.name ?? "User")),
          );
        }
      } else {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen(token: res.accessToken!, name: res.name ?? "User")),
        );
      }

    } else {
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SizedBox(
            height: size.height - 50,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.apartment_rounded, size: 64, color: _primaryColor),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Sumber Baru PORTAL",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[800],
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Silakan masuk untuk melanjutkan",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                ),
                const Spacer(flex: 1),


                _buildTextField(
                  controller: _nikController,
                  label: "Nomor Induk Karyawan (NIK)",
                  icon: Icons.badge_outlined,
                  inputType: TextInputType.number,
                ),
                const SizedBox(height: 20),

                _buildTextField(
                  controller: _passController,
                  label: "Password",
                  icon: Icons.lock_outline,
                  isPassword: true,
                ),

                const SizedBox(height: 32),

                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      disabledBackgroundColor: _primaryColor.withOpacity(0.6),
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
                const Spacer(flex: 3),

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
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType inputType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
          labelStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(icon, color: _primaryColor),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _primaryColor, width: 1.5),
          ),
        ),
      ),
    );
  }
}