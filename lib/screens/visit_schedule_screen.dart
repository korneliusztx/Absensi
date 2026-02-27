import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../services/api_services.dart';
import 'visit_detail_screen.dart';

class VisitScheduleScreen extends StatefulWidget {
  final String token;
  const VisitScheduleScreen({super.key, required this.token});

  @override
  State<VisitScheduleScreen> createState() => _VisitScheduleScreenState();
}

class _VisitScheduleScreenState extends State<VisitScheduleScreen> {
  final ApiService _apiService = ApiService();

  // Calendar State
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Data State
  List<dynamic> _visits = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Colors (Dark Theme)
  final Color _bgDark = const Color(0xFF1A1F24);
  final Color _cardDark = const Color(0xFF252A31);
  final Color _accentBlue = const Color(0xFF3498DB);

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) {
      setState(() {
        _selectedDay = _focusedDay;
      });
      _fetchVisits(_selectedDay!);
    });

  }

  Future<void> _fetchVisits(DateTime date) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String dateStr = DateFormat('yyyy-MM-dd').format(date);
      List<dynamic> data = await _apiService.getVisitsByDate(widget.token, dateStr);

      if (!mounted) return;
      print(data);

      setState(() {
        _visits = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Gagal memuat data. Cek koneksi internet.";
        _isLoading = false;
        _visits = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedDay == null) {
      return Scaffold(
        backgroundColor: _bgDark,
        body: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _bgDark,
        elevation: 0,
        title: const Text("Jadwal Kunjungan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // --- 1. KALENDER SECTION ---
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardDark,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TableCalendar(
              locale: 'id_ID',
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_selectedDay, selectedDay)) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  _fetchVisits(selectedDay);
                }
              },
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
                rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
              ),
              calendarStyle: CalendarStyle(
                defaultTextStyle: const TextStyle(color: Colors.white),
                weekendTextStyle: const TextStyle(color: Colors.white70),
                selectedDecoration: BoxDecoration(color: _accentBlue, shape: BoxShape.circle),
                todayDecoration: BoxDecoration(color: _accentBlue.withOpacity(0.3), shape: BoxShape.circle),
                outsideDaysVisible: false,
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Colors.grey),
                weekendStyle: TextStyle(color: Colors.grey),
              ),
            ),
          ),

          // --- 2. HEADER LIST SECTION ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Text(
                  "Agenda: ${DateFormat('d MMMM yyyy', 'id_ID').format(_selectedDay!)}",
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // --- 3. LIST VISIT SECTION ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _errorMessage != null
                ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)))
                : _visits.isEmpty
                ? Center(child: Text("Tidak ada kunjungan", style: TextStyle(color: Colors.grey[500])))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _visits.length,
              itemBuilder: (context, index) {
                final item = _visits[index];
                return _buildVisitItem(item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitItem(Map<String, dynamic> item) {
    // 1. Parsing Data dari JSON Bersarang
    var customer = item['customer'] ?? {}; // Ambil objek customer
    String status = item['status'] ?? "Pending";
    String time = item['schedule_time'] ?? "--:--";

    // Potong detik dari waktu (09:00:00 -> 09:00)
    if (time.length > 5) {
      time = time.substring(0, 5);
    }

    // Cek Status (Case Insensitive)
    bool isDone = status.toLowerCase() == "completed" || status.toLowerCase() == "done";

    return GestureDetector(
      onTap: () {
        // PERSIAPAN DATA UNTUK DETAIL SCREEN
        // Kita harus meratakan (flatten) data agar sesuai dengan yang diharapkan VisitDetailScreen sebelumnya
        // terutama bagian latitude/longitude untuk Google Maps
        Map<String, dynamic> detailData = {
          "id": item['id'],
          "customer_name": customer['name'],
          "address": customer['address'],
          "time": time,
          "status": status,
          "contact": customer['cust_id'], // Atau field lain jika ada PIC
          "notes": item['notes'],
          "latitude": customer['lat'], // Penting untuk Navigasi GPS
          "longitude": customer['long'], // Penting untuk Navigasi GPS
          "check_in_time": null, // Isi dari API jika ada
          "check_out_time": null, // Isi dari API jika ada
        };

        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => VisitDetailScreen(
                  visitData: detailData,
                  token: widget.token,
                )
            )
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: isDone ? Colors.green : Colors.orange, width: 4)),
        ),
        child: Row(
          children: [
            // Waktu & Status
            SizedBox(
              width: 70,
              child: Column(
                children: [
                  Text(time, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                        color: isDone ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4)
                    ),
                    child: Text(
                      isDone ? "Selesai" : "Pending",
                      style: TextStyle(color: isDone ? Colors.green : Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Info Toko (Diambil dari objek 'customer')
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer['name'] ?? "Tanpa Nama", // Ambil dari nested object
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.location_on, color: Colors.grey, size: 12),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          customer['address'] ?? "-", // Ambil dari nested object
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}