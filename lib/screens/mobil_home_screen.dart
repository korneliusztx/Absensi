import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_services.dart';
import 'attendance_screen.dart';
import 'leave_screen.dart';

class MobileHomeScreen extends StatefulWidget {
  final String token;
  final String name;

  const MobileHomeScreen({super.key, required this.token, required this.name});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  late Future<List<dynamic>> _attendanceFuture;
  late Future<List<dynamic>> _leaveFuture;
  late Future<Map<String, dynamic>?> _profileFuture;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _profileFuture = _apiService.getProfile(widget.token);
      _attendanceFuture = _apiService.getHistory(widget.token);
      _leaveFuture = _apiService.getLeaveHistory(widget.token);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // AppBar khusus Mobile Sales/Lapngan
      appBar: AppBar(
        title: const Text("Mobile Sales", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(onPressed: _refreshData, icon: const Icon(Icons.refresh))
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header & Stats (SAMA PERSIS)
            _buildMinimalHeader(),
            const SizedBox(height: 20),
            _buildStatsSection(),
            const SizedBox(height: 25),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _bigActionButton(
                        "Kirim Kunjungan\n(Foto & Lokasi)",
                        Icons.camera_alt,
                        Colors.blueAccent,
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceScreen(token: widget.token)))
                    ),
                  ),
                  const SizedBox(width: 15),
                  // TOMBOL 2: CUTI
                  Expanded(
                    child: _bigActionButton(
                        "Pengajuan\nCuti",
                        Icons.calendar_month,
                        Colors.orange,
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => LeaveScreen(token: widget.token)))
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // 3. TAB BAR & LIST (SAMA PERSIS)
            Container(
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey[600],
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                tabs: const [Tab(text: "Riwayat Absen"), Tab(text: "Riwayat Cuti")],
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildModernAttendanceList(),
                  _buildModernLeaveList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bigActionButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 140),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10), // Tambah padding vertikal
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 15), // Jarak sedikit diperlebar
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13, // Sedikit diperkecil agar muat
                  fontWeight: FontWeight.bold,
                  color: color.withOpacity(0.9)
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildMinimalHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Halo, ${widget.name.split(' ')[0]}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const Text("Mode Mobile / Lapangan", style: TextStyle(fontSize: 12, color: Colors.grey)), // Penanda Mode
            ],
          ),
          const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.location_on, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          String sisa = "-";
          String hutang = "-";
          if (snapshot.hasData && snapshot.data != null) {
            sisa = snapshot.data!['leave_quota'].toString();
            hutang = snapshot.data!['debt_hours'].toString();
          }
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50], borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                _statItem("Sisa Cuti", sisa, "Hari", Colors.blueAccent),
                Container(height: 30, width: 1, color: Colors.grey[300], margin: const EdgeInsets.symmetric(horizontal: 20)),
                _statItem("Terlambat", hutang, "Jam", Colors.redAccent),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statItem(String label, String val, String unit, Color color) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(val, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 4),
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(unit, style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
        ]),
      ]),
    );
  }

  Widget _buildModernAttendanceList() {
    return FutureBuilder<List<dynamic>>(
      future: _attendanceFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("Belum ada data"));
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            var item = snapshot.data![index];
            DateTime date = DateTime.parse(item['created_at']);
            String day = DateFormat('dd').format(date);
            String month = DateFormat('MMM').format(date);
            String timeIn = item['clock_in'] != null ? DateFormat('HH:mm').format(DateTime.parse(item['clock_in'])) : "--:--";

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                    child: Column(children: [
                      Text(day, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(month, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ]),
                  ),
                  const SizedBox(width: 16),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Waktu Kunjungan", style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(timeIn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                  ]),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModernLeaveList() {
    return FutureBuilder<List<dynamic>>(
      future: _leaveFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("Belum ada data"));
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            var item = snapshot.data![index];
            return ListTile(title: Text(item['type'] ?? "Cuti"), subtitle: Text(item['status'] ?? "Pending"));
          },
        );
      },
    );
  }
}