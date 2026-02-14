import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_services.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String token;

  const ProfileScreen({super.key, required this.token});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();

  // Variable untuk menampung Future profile
  late Future<Map<String, dynamic>?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _profileFuture = _apiService.getProfile(widget.token);
    });
  }

  // --- FUNGSI EDIT DATA ---
  void _showEditDialog(String title, String fieldName, String currentValue) {
    TextEditingController controller = TextEditingController(text: currentValue == "-" ? "" : currentValue);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Ubah $title"),
          content: TextField(
            controller: controller,
            keyboardType: title == "Telepon" ? TextInputType.phone : TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: "Masukkan $title baru",
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Tutup dialog
                _saveData(fieldName, controller.text);
              },
              child: const Text("Simpan"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveData(String field, String value) async {
    // Tampilkan Loading
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Menyimpan perubahan...")));

    // Panggil API Update
    bool success = await _apiService.updateProfile(widget.token, field, value);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Berhasil diperbarui!"), backgroundColor: Colors.green));
      _refreshData(); // Refresh tampilan agar data baru muncul
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal memperbarui data."), backgroundColor: Colors.red));
    }
  }

  // --- FUNGSI LOGOUT ---
  Future<void> _logout() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi"),
        content: const Text("Yakin ingin keluar?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Ya", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profil Karyawan"), elevation: 0),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          // 1. KONDISI LOADING
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. KONDISI ERROR / NULL
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 50, color: Colors.red),
                  const SizedBox(height: 10),
                  const Text("Gagal memuat profil"),
                  TextButton(
                    onPressed: _refreshData,
                    child: const Text("Coba Lagi"),
                  )
                ],
              ),
            );
          }

          // 3. KONDISI SUKSES
          var data = snapshot.data!;

          // Ambil data
          String name = data['name'] ?? "-";
          String nik = data['nik'] ?? "-";
          String email = data['email'] ?? "-"; // Ambil Email
          String phone = data['phone'] ?? "-";
          String role = data['role'] ?? "Staff";

          // Data Nested
          String branch = (data['branch'] != null) ? data['branch']['name'] : "-";
          String position = (data['position'] != null) ? data['position']['name'] : "-";
          String homebase = (data['homebase'] != null) ? data['homebase']['name'] : "-";
          String joinDate = data['join_date'] ?? "-";

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // --- HEADER FOTO ---
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        child: Text(
                          name.isNotEmpty ? name[0] : "?",
                          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      Text(position, style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green)
                        ),
                        child: Text(role, style: TextStyle(color: Colors.green[800], fontSize: 12)),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // --- INFO DETAIL (CARD) ---
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Column(
                    children: [
                      // ITEM YANG TIDAK BISA DIEDIT (onTap: null)
                      _buildInfoTile(Icons.badge, "NIK", nik),
                      const Divider(height: 1),

                      // ITEM YANG BISA DIEDIT (Panggil _showEditDialog)
                      _buildInfoTile(
                          Icons.email,
                          "Email",
                          email,
                          isEditable: true,
                          onTap: () => _showEditDialog("Email", "email", email)
                      ),
                      const Divider(height: 1),

                      _buildInfoTile(
                          Icons.phone,
                          "Telepon",
                          phone,
                          isEditable: true,
                          onTap: () => _showEditDialog("Telepon", "phone", phone)
                      ),
                      const Divider(height: 1),

                      // ITEM LAIN TIDAK BISA DIEDIT
                      _buildInfoTile(Icons.store, "Cabang", branch),
                      const Divider(height: 1),
                      _buildInfoTile(Icons.location_city, "Homebase", homebase),
                      const Divider(height: 1),
                      _buildInfoTile(Icons.calendar_today, "Bergabung", joinDate),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // --- TOMBOL LOGOUT ---
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[50],
                      foregroundColor: Colors.red,
                      elevation: 0,
                    ),
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text("Keluar Aplikasi"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Widget Tile yang dimodifikasi untuk mendukung Edit
  Widget _buildInfoTile(IconData icon, String title, String value, {VoidCallback? onTap, bool isEditable = false}) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueGrey),
      title: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)
      ),
      // Jika isEditable true, tampilkan icon pensil kecil
      trailing: isEditable
          ? Icon(Icons.edit, size: 18, color: Colors.blue[300])
          : null,
      onTap: onTap, // Kalau null, berarti tidak bisa diklik
    );
  }
}