import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart'; // 1. Import Image Picker
import 'dart:io';
import '../services/api_services.dart'; // Import ApiService

class VisitDetailScreen extends StatefulWidget {
  final Map<String, dynamic> visitData;
  final String token;

  const VisitDetailScreen({super.key, required this.visitData, required this.token});

  @override
  State<VisitDetailScreen> createState() => _VisitDetailScreenState();
}

class _VisitDetailScreenState extends State<VisitDetailScreen> {
  final ApiService _apiService = ApiService(); // Init Service
  final Color _bgDark = const Color(0xFF1A1F24);
  final Color _cardDark = const Color(0xFF252A31);

  bool _isLoadingCheckIn = false;
  bool _isLoadingCheckOut = false;
  bool _hasCheckedIn = false;
  bool _hasCheckedOut = false;

  @override
  void initState() {
    super.initState();
    // Cek status awal dari data API (sesuaikan key dengan respons API Anda)
    // Misalnya API memberikan field 'status' = 'In Progress' atau 'Completed'
    String status = widget.visitData['status'] ?? "Pending";

    print(widget.visitData['id']);

    if (status == "In Progress") {
      _hasCheckedIn = true;
    } else if (status == "Completed" || status == "Done") {
      _hasCheckedIn = true;
      _hasCheckedOut = true;
    }
  }

  // --- 1. GET GPS ---
  Future<Position?> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GPS tidak aktif.')));
      return null;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  // --- 2. AMBIL FOTO KAMERA ---
  Future<File?> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (photo != null) return File(photo.path);
    return null;
  }

  // --- 3. DIALOG INPUT CATATAN ---
  Future<String?> _showNoteDialog(String title, String hint) async {
    TextEditingController _noteController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _cardDark,
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: TextField(
            controller: _noteController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[500]),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
            ),
          ),
          actions: [
            TextButton(child: const Text("Batal"), onPressed: () => Navigator.pop(context)),
            TextButton(child: const Text("Kirim", style: TextStyle(color: Colors.blueAccent)), onPressed: () => Navigator.pop(context, _noteController.text)),
          ],
        );
      },
    );
  }

  // --- 4. PROSES CLOCK IN ---
  Future<void> _handleCheckIn() async {
    // 1. Ambil Foto Bukti
    File? photo = await _takePhoto();
    if (photo == null) return;

    // 2. Ambil Catatan (Opsional)

    setState(() => _isLoadingCheckIn = true);

    try {
      Position? position = await _determinePosition();
      if (position != null) {
        // PANGGIL API
        var res = await _apiService.clockInVisit(
            widget.token,
            widget.visitData['id'].toString(),
            position.latitude.toString(),
            position.longitude.toString(),
            photo
        );

        if (res['success'] == true) {
          setState(() => _hasCheckedIn = true);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Clock In Berhasil!"), backgroundColor: Colors.green));
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? "Gagal Clock In"), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoadingCheckIn = false);
    }
  }

  // --- 5. PROSES CLOCK OUT ---
  Future<void> _handleCheckOut() async {
    // 1. Ambil Foto Bukti Selesai
    File? photo = await _takePhoto();
    if (photo == null) return;

    // 2. Ambil Hasil Kunjungan (Wajib diisi biasanya)
    String? resultNote = await _showNoteDialog("Hasil Kunjungan", "Contoh: Toko order 50 karton");
    if (resultNote == null || resultNote.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hasil kunjungan wajib diisi!"), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isLoadingCheckOut = true);

    try {
      Position? position = await _determinePosition();
      if (position != null) {
        // PANGGIL API
        var res = await _apiService.clockOutVisit(
            widget.token,
            widget.visitData['id'].toString(),
            position.latitude.toString(),
            position.longitude.toString(),
            photo,
            resultNote
        );

        if (res['success'] == true) {
          setState(() => _hasCheckedOut = true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kunjungan Selesai!"), backgroundColor: Colors.green));
            Navigator.pop(context); // Kembali ke list jadwal karena sudah selesai
          }
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? "Gagal Clock Out"), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoadingCheckOut = false);
    }
  }

  // --- 6. NAVIGASI GOOGLE MAPS ---
  Future<void> _openGoogleMaps(String lat, String lng) async {
    final Uri googleMapsUrl = Uri.parse("http://maps.google.com/maps?daddr=$lat,$lng&mode=driving");
    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tidak dapat membuka Google Maps")));
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _bgDark,
        elevation: 0,
        title: const Text("Detail Kunjungan", style: TextStyle(color: Colors.white)),
        leading: const BackButton(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // INFO UTAMA
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.visitData['customer_name'] ?? "-", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.grey),
                  const SizedBox(height: 8),
                  _detailRow(Icons.access_time, "Waktu", widget.visitData['time'] ?? "-"),
                  _detailRow(Icons.location_on, "Alamat", widget.visitData['address'] ?? "-"),
                  _detailRow(Icons.person, "Kontak (PIC)", widget.visitData['contact'] ?? "-"),
                  _detailRow(Icons.note, "Catatan Awal", widget.visitData['notes'] ?? "-"),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // TOMBOL NAVIGASI
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () {
                  final lat = widget.visitData['latitude']?.toString();
                  final lng = widget.visitData['longitude']?.toString();
                  if (lat != null && lng != null) _openGoogleMaps(lat, lng);
                  else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lokasi tidak tersedia")));
                },
                icon: const Icon(Icons.navigation, color: Colors.white),
                label: const Text("Navigasi ke Lokasi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),

            // TOMBOL AKSI (CLOCK IN / OUT)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, disabledBackgroundColor: Colors.grey[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: (_isLoadingCheckIn || _hasCheckedIn) ? null : _handleCheckIn,
                      child: _isLoadingCheckIn
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(_hasCheckedIn ? "Sedang Visit" : "Clock In", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, disabledBackgroundColor: Colors.grey[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: (_isLoadingCheckOut || _hasCheckedOut || !_hasCheckedIn) ? null : _handleCheckOut,
                      child: _isLoadingCheckOut
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(_hasCheckedOut ? "Selesai" : "Clock Out", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 20),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)), const SizedBox(height: 4), Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500))])),
        ],
      ),
    );
  }
}