import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/api_services.dart';

class LeaveScreen extends StatefulWidget {
  final String token;
  const LeaveScreen({super.key, required this.token});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  final _reasonController = TextEditingController();
  final ApiService _apiService = ApiService();

  String _selectedType = 'Sakit';
  DateTime? _startDate;
  DateTime? _endDate;
  File? _attachment;
  bool _isLoading = false;

  final List<String> _leaveTypes = ['Sakit', 'Izin', 'Cuti'];

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate == null) _endDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickAttachment() async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);

    if (file != null) {
      setState(() {
        _attachment = File(file.path);
      });
    }
  }

  Future<void> _submitLeave() async {
    if (_startDate == null || _endDate == null || _reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mohon lengkapi semua data form")),
      );
      return;
    }

    setState(() => _isLoading = true);

    String startStr = DateFormat('yyyy-MM-dd').format(_startDate!);
    String endStr = DateFormat('yyyy-MM-dd').format(_endDate!);

    bool success = await _apiService.postLeave(
      widget.token,
      _selectedType,
      startStr,
      endStr,
      _reasonController.text,
      _attachment,
    );

    setState(() => _isLoading = false);

    if (success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pengajuan Berhasil Dikirim!"), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gagal mengirim pengajuan"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Form Pengajuan Cuti"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Jenis Pengajuan", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    DropdownButton<String>(
                      value: _selectedType,
                      isExpanded: true,
                      underline: Container(),
                      items: _leaveTypes.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedType = val!),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(
                  child: _datePickerCard("Mulai", _startDate, () => _selectDate(context, true)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _datePickerCard("Selesai", _endDate, () => _selectDate(context, false)),
                ),
              ],
            ),
            const SizedBox(height: 15),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                child: TextField(
                  controller: _reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    labelText: "Alasan Cuti",
                    hintText: "Contoh: Demam tinggi, perlu istirahat.",
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),

            GestureDetector(
              onTap: _pickAttachment,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey),
                ),
                child: _attachment == null
                    ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.cloud_upload, size: 40, color: Colors.grey),
                    Text("Upload Lampiran (Opsional)", style: TextStyle(color: Colors.grey)),
                  ],
                )
                    : Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.file(_attachment!, fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => setState(() => _attachment = null),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isLoading ? null : _submitLeave,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("KIRIM PENGAJUAN", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _datePickerCard(String title, DateTime? date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Text(
                    date == null ? "-" : DateFormat('dd MMM yyyy').format(date),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}