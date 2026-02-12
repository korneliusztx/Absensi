import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/api_services.dart';

class AttendanceScreen extends StatefulWidget {
  final String token;
  const AttendanceScreen({super.key, required this.token});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  File? _image;
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  Future<void> _doAbsen() async {
    setState(() => _isLoading = true);

    // 1. Ambil Lokasi
    await Geolocator.requestPermission();
    Position pos = await Geolocator.getCurrentPosition();

    // 2. Ambil Foto
    final XFile? photo = await ImagePicker().pickImage(source: ImageSource.camera);

    if (photo != null) {
      _image = File(photo.path);

      // 3. Kirim ke API Service
      bool success = await _apiService.postAttendance(widget.token, pos.latitude, pos.longitude, _image!);

      if (success) {
        if(!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Absen Berhasil!"), backgroundColor: Colors.green));
        Navigator.pop(context);
      } else {
        if(!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal Absen"), backgroundColor: Colors.red));
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Absensi")),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton.icon(
          icon: const Icon(Icons.camera),
          label: const Text("Ambil Foto & Absen"),
          onPressed: _doAbsen,
        ),
      ),
    );
  }
}