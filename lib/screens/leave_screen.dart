import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../services/api_services.dart';
import '../services/pdf_services.dart';

class LeaveScreen extends StatefulWidget {
  final String token;
  const LeaveScreen({super.key, required this.token});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  final ApiService _apiService = ApiService();

  // --- STATE VARIABELS ---
  // 0 = Cuti Harian (Full Day), 1 = Izin Jam Kerja (Hourly)
  int _formMode = 0;
  bool _isLoading = false;

  // Controllers Global
  final _reasonController = TextEditingController();

  // Controllers Tambahan untuk CUTI (Sesuai Gambar)
  final _delegationNameController = TextEditingController(); // Nama delegasi
  final _contactAddressController = TextEditingController(); // Alamat saat cuti
  final _contactPhoneController = TextEditingController();   // No HP saat cuti

  // Data Cuti (Mode 0)
  String _selectedLeaveType = 'Cuti Tahunan';
  DateTime? _startDate;
  DateTime? _endDate;
  final List<String> _leaveTypes = ['Cuti Tahunan', 'Cuti Melahirkan', 'Cuti Khusus', 'Sakit'];

  // Data Izin Jam (Mode 1)
  DateTime? _permitDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isBackToWork = false;

  // Attachment
  File? _attachment;

  // --- HELPERS ---

  Future<void> _pickDate(BuildContext context, {required Function(DateTime) onPicked}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.blueAccent),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => onPicked(picked));
    }
  }

  Future<void> _pickTime(BuildContext context, {required Function(TimeOfDay) onPicked}) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.blueAccent),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => onPicked(picked));
    }
  }

  Future<void> _pickAttachment() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
    );

    if (result != null) {
      setState(() {
        _attachment = File(result.files.single.path!);
      });
    }
  }

  // --- SUBMIT LOGIC ---
  Future<void> _submitForm() async {
    if (_reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Alasan wajib diisi")));
      return;
    }

    setState(() => _isLoading = true);

    String type;
    String startStr;
    String endStr;
    // Kita gabungkan data tambahan ke dalam 'notes' agar tersimpan di backend
    String notes = _reasonController.text;

    if (_formMode == 0) {
      // --- MODE CUTI ---
      if (_startDate == null || _endDate == null) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tanggal cuti wajib diisi")));
        return;
      }
      type = _selectedLeaveType;
      startStr = DateFormat('yyyy-MM-dd').format(_startDate!);
      endStr = DateFormat('yyyy-MM-dd').format(_endDate!);

      // Tambahkan Data Delegasi & Kontak ke Notes
      notes += "\n\n--- DETAIL SELAMA CUTI ---";
      if (_delegationNameController.text.isNotEmpty) {
        notes += "\nPekerjaan diserahkan ke: ${_delegationNameController.text}";
      }
      if (_contactAddressController.text.isNotEmpty) {
        notes += "\nDapat dihubungi di (Alamat): ${_contactAddressController.text}";
      }
      if (_contactPhoneController.text.isNotEmpty) {
        notes += "\nNo Telp/HP: ${_contactPhoneController.text}";
      }

    } else {
      // --- MODE IZIN JAM ---
      if (_permitDate == null || _startTime == null || _endTime == null) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tanggal dan Jam wajib diisi")));
        return;
      }
      type = "Izin Jam Kerja";
      startStr = "${DateFormat('yyyy-MM-dd').format(_permitDate!)} ${_startTime!.format(context)}";
      endStr = "${DateFormat('yyyy-MM-dd').format(_permitDate!)} ${_endTime!.format(context)}";

      notes += "\n[Kembali Kerja: ${_isBackToWork ? 'Ya' : 'Tidak'}]";
    }

    // Panggil API
    bool success = await _apiService.postLeave(
      widget.token,
      type,
      startStr,
      endStr,
      notes,
      _attachment,
    );

    setState(() => _isLoading = false);

    if (success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pengajuan Berhasil!"), backgroundColor: Colors.green));
      Navigator.pop(context);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal mengirim pengajuan"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Form Pengajuan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // 1. TOGGLE SWITCHER (Cuti vs Izin)
            _buildTypeSelector(),
            const SizedBox(height: 20),

            // 2. FORM UTAMA (Berubah sesuai Toggle)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _formMode == 0 ? _buildCutiForm() : _buildHourlyForm(),
            ),

            const SizedBox(height: 20),

            // 3. COMMON FIELDS (Alasan & Lampiran)
            _buildReasonAndAttachment(),

            const SizedBox(height: 30),

            // 4. SUBMIT BUTTON

          ],
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(child: _toggleButton("Cuti Harian", 0)),
          Expanded(child: _toggleButton("Izin Jam Kerja", 1)),
        ],
      ),
    );
  }

  Widget _toggleButton(String title, int index) {
    bool isSelected = _formMode == index;
    return GestureDetector(
      onTap: () => setState(() => _formMode = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // FORM MODE 0: CUTI HARIAN (UPDATED)
  Widget _buildCutiForm() {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Detail Cuti"),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Dropdown Jenis Cuti
                DropdownButtonFormField<String>(
                  value: _selectedLeaveType,
                  decoration: _inputDecoration("Jenis Cuti", Icons.category),
                  items: _leaveTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setState(() => _selectedLeaveType = val!),
                ),
                const SizedBox(height: 15),

                // Tanggal Mulai & Selesai
                Row(
                  children: [
                    Expanded(
                        child: _dateField(
                            "Mulai",
                            _startDate,
                                () => _pickDate(context, onPicked: (d) => setState(() => _startDate = d))
                        )
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _dateField(
                            "Selesai",
                            _endDate,
                                () => _pickDate(context, onPicked: (d) => setState(() => _endDate = d))
                        )
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // --- BAGIAN BARU: SELAMA MELAKUKAN CUTI ---
        _sectionTitle("Selama Melakukan Cuti"),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Delegasi
                const Text("Pekerjaan diserahkan kepada:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueAccent)),
                const SizedBox(height: 8),
                TextField(
                  controller: _delegationNameController,
                  decoration: _inputDecoration("Nama Karyawan Pengganti", Icons.person_outline),
                ),
                const SizedBox(height: 15),
                const Divider(),
                const SizedBox(height: 10),

                // 2. Kontak Darurat
                const Text("Dapat dihubungi di:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueAccent)),
                const SizedBox(height: 8),
                TextField(
                  controller: _contactAddressController,
                  maxLines: 2,
                  decoration: _inputDecoration("Alamat selama cuti", Icons.home_outlined),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _contactPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration("No. Telp / HP", Icons.phone_android),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // FORM MODE 1: IZIN JAM KERJA
  Widget _buildHourlyForm() {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Detail Izin Keluar"),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Tanggal Izin
                _dateField(
                    "Tanggal Izin",
                    _permitDate,
                        () => _pickDate(context, onPicked: (d) => setState(() => _permitDate = d)),
                    fullWidth: true
                ),
                const SizedBox(height: 15),

                // Jam Mulai & Selesai
                Row(
                  children: [
                    Expanded(
                        child: _timeField(
                            "Jam Keluar",
                            _startTime,
                                () => _pickTime(context, onPicked: (t) => setState(() => _startTime = t))
                        )
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _timeField(
                            "Jam Kembali",
                            _endTime,
                                () => _pickTime(context, onPicked: (t) => setState(() => _endTime = t))
                        )
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Kembali ke kantor?", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(_isBackToWork ? "Ya, saya akan kembali" : "Tidak, langsung pulang"),
                  value: _isBackToWork,
                  activeColor: Colors.blueAccent,
                  onChanged: (val) => setState(() => _isBackToWork = val),
                ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                TextField(
                  controller: _reasonController,
                  maxLines: 3,
                  decoration: _inputDecoration("Alasan / Keperluan", Icons.notes),
                ),
                const SizedBox(height: 20),

                // Upload Area
                GestureDetector(
                  onTap: _pickAttachment,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 15),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                    ),
                    child: _attachment == null
                        ? Column(
                      children: [
                        Icon(Icons.cloud_upload_outlined, size: 30, color: Colors.blueAccent.withOpacity(0.7)),
                        const SizedBox(height: 10),
                        const Text("Tap untuk upload Bukti / Surat Dokter", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    )
                        : Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_attachment!.path.split('/').last, overflow: TextOverflow.ellipsis)),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => setState(() => _attachment = null),
                        )
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- STYLING HELPERS ---

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 8),
      child: Text(title, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: Colors.blueAccent),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
    );
  }

  Widget _dateField(String label, DateTime? date, VoidCallback onTap, {bool fullWidth = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 18, color: Colors.blueAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(
                    date != null ? DateFormat('dd MMM yy').format(date) : "-",
                    style: TextStyle(fontWeight: FontWeight.bold, color: date != null ? Colors.black : Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeField(String label, TimeOfDay? time, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 18, color: Colors.orange),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(
                    time != null ? time.format(context) : "--:--",
                    style: TextStyle(fontWeight: FontWeight.bold, color: time != null ? Colors.black : Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}