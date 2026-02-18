import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../services/api_services.dart';
import '../services/pdf_services.dart'; // Pastikan path ini benar

class LeaveScreen extends StatefulWidget {
  final String token;
  const LeaveScreen({super.key, required this.token});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  final ApiService _apiService = ApiService();

  // --- STATE VARIABELS ---
  int _formMode = 0; // 0 = Cuti Harian, 1 = Izin Jam
  bool _isLoading = false;

  // Controllers
  final _reasonController = TextEditingController();
  final _delegationNameController = TextEditingController();
  final _contactAddressController = TextEditingController();
  final _contactPhoneController = TextEditingController();

  // Data Cuti
  String _selectedLeaveType = 'Cuti Tahunan';
  DateTime? _startDate;
  DateTime? _endDate;
  final List<String> _leaveTypes = ['Cuti Tahunan', 'Cuti Melahirkan', 'Cuti Khusus', 'Sakit'];

  // Data Izin Jam
  DateTime? _permitDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isBackToWork = false;

  File? _attachment;

  // ... (Fungsi _pickDate, _pickTime, _pickAttachment SAMA SEPERTI SEBELUMNYA) ...
  Future<void> _pickDate(BuildContext context, {required Function(DateTime) onPicked}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => onPicked(picked));
  }

  Future<void> _pickTime(BuildContext context, {required Function(TimeOfDay) onPicked}) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) setState(() => onPicked(picked));
  }

  Future<void> _pickAttachment() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'pdf']);
    if (result != null) setState(() => _attachment = File(result.files.single.path!));
  }

  // --- FUNGSI PRINT PDF ---
  // ... (Bagian import tetap sama) ...

  // --- FUNGSI PRINT PDF (UPDATE INI SAJA) ---
  Future<void> _printPdf() async {
    // Validasi Input Sesuai Mode
    if (_formMode == 0) {
      if (_startDate == null || _endDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tanggal cuti wajib diisi")));
        return;
      }
    } else {
      if (_permitDate == null || _startTime == null || _endTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tanggal dan Waktu Ijin wajib diisi")));
        return;
      }
    }

    // Tampilkan Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. AMBIL DATA PROFIL DARI API
      final profileData = await _apiService.getProfile(widget.token);

      if (!mounted) return;
      Navigator.pop(context); // Tutup Loading

      if (profileData != null) {
        String apiName = profileData['name'] ?? "Tanpa Nama";
        String apiNik = profileData['nik'] ?? "-";

        String apiDivisi = "-";
        if (profileData['position'] != null) {
          apiDivisi = profileData['position']['name'];
        } else {
          apiDivisi = profileData['role'] ?? "-";
        }

        // 2. LOGIKA PEMILIHAN PDF
        final pdfService = PdfService();

        if (_formMode == 0) {
          // --- MODE CUTI (PTM) ---
          await pdfService.createCutiPdf(
            apiName,
            apiNik,
            apiDivisi,
            _selectedLeaveType,
            _startDate!,
            _endDate!,
            _reasonController.text,
            _delegationNameController.text,
            _contactAddressController.text,
            _contactPhoneController.text,
          );
        } else {
          // --- MODE IZIN JAM KERJA (SB) ---
          await pdfService.createHourlyPdf(
            apiName,
            apiDivisi, // Jabatan
            _permitDate!,
            _startTime!.format(context), // Jam Mulai (String HH:mm)
            _endTime!.format(context),   // Jam Selesai
            _isBackToWork,               // Checkbox Kembali Kerja
            _reasonController.text,      // Alasan
          );
        }

      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal mengambil data profil.")));
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      print("Error PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }


  // --- SUBMIT KE API (SAMA SEPERTI SEBELUMNYA) ---
  Future<void> _submitForm() async {
    // ... (Kode submit API Anda tetap sama) ...
    // Biarkan kode _submitForm Anda yang lama di sini
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text("Form Pengajuan"), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTypeSelector(),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _formMode == 0 ? _buildCutiForm() : _buildHourlyForm(),
            ),
            const SizedBox(height: 20),
            _buildReasonAndAttachment(),
            const SizedBox(height: 30),

            // TOMBOL AKSI
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _printPdf, // PANGGIL FUNGSI PDF DI SINI
                    icon: const Icon(Icons.print, color: Colors.white),
                    label: const Text("PRINT PDF", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isLoading ? null : _submitForm,
                    icon: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send, color: Colors.white),
                    label: const Text("KIRIM PENGAJUAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // ... (WIDGET BUILDER LAINNYA: _buildTypeSelector, _buildCutiForm, dll TETAP SAMA) ...
  // Paste widget-widget UI Anda (_buildCutiForm, _buildHourlyForm, dll) di bawah sini

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
      child: Row(children: [Expanded(child: _toggleButton("Cuti Harian", 0)), Expanded(child: _toggleButton("Izin Jam Kerja", 1))]),
    );
  }

  Widget _toggleButton(String title, int index) {
    bool isSelected = _formMode == index;
    return GestureDetector(
      onTap: () => setState(() => _formMode = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: isSelected ? Colors.blueAccent : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Text(title, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // Widget Form Cuti (Sesuai kode Anda sebelumnya)
  Widget _buildCutiForm() {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Detail Cuti"),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedLeaveType,
                  decoration: _inputDecoration("Jenis Cuti", Icons.category),
                  items: _leaveTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setState(() => _selectedLeaveType = val!),
                ),
                const SizedBox(height: 15),
                Row(children: [
                  Expanded(child: _dateField("Mulai", _startDate, () => _pickDate(context, onPicked: (d) => setState(() => _startDate = d)))),
                  const SizedBox(width: 10),
                  Expanded(child: _dateField("Selesai", _endDate, () => _pickDate(context, onPicked: (d) => setState(() => _endDate = d)))),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle("Selama Melakukan Cuti"),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                TextField(controller: _delegationNameController, decoration: _inputDecoration("Nama Karyawan Pengganti", Icons.person_outline)),
                const SizedBox(height: 15),
                TextField(controller: _contactAddressController, decoration: _inputDecoration("Alamat selama cuti", Icons.home_outlined)),
                const SizedBox(height: 15),
                TextField(controller: _contactPhoneController, keyboardType: TextInputType.phone, decoration: _inputDecoration("No. Telp / HP", Icons.phone_android)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Widget Form Izin Jam (Sesuai kode Anda sebelumnya)
  Widget _buildHourlyForm() {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Detail Izin Keluar"),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _dateField("Tanggal Izin", _permitDate, () => _pickDate(context, onPicked: (d) => setState(() => _permitDate = d)), fullWidth: true),
                const SizedBox(height: 15),
                Row(children: [
                  Expanded(child: _timeField("Jam Keluar", _startTime, () => _pickTime(context, onPicked: (t) => setState(() => _startTime = t)))),
                  const SizedBox(width: 10),
                  Expanded(child: _timeField("Jam Kembali", _endTime, () => _pickTime(context, onPicked: (t) => setState(() => _endTime = t)))),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReasonAndAttachment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Keterangan Tambahan"),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(controller: _reasonController, maxLines: 3, decoration: _inputDecoration("Alasan / Keperluan", Icons.notes)),
          ),
        ),
      ],
    );
  }

  // Helpers UI
  Widget _sectionTitle(String title) => Padding(padding: const EdgeInsets.only(left: 5, bottom: 8), child: Text(title, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 13)));
  InputDecoration _inputDecoration(String label, IconData icon) => InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20, color: Colors.blueAccent), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey[50]);

  Widget _dateField(String label, DateTime? date, VoidCallback onTap, {bool fullWidth = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Row(children: [
          const Icon(Icons.calendar_today, size: 18, color: Colors.blueAccent),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)), Text(date != null ? DateFormat('dd MMM yy').format(date) : "-", style: const TextStyle(fontWeight: FontWeight.bold))]))
        ]),
      ),
    );
  }

  Widget _timeField(String label, TimeOfDay? time, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Row(children: [
          const Icon(Icons.access_time, size: 18, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)), Text(time != null ? time.format(context) : "--:--", style: const TextStyle(fontWeight: FontWeight.bold))]))
        ]),
      ),
    );
  }
}