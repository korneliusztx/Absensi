import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_services.dart';
import 'attendance_screen.dart';
import 'leave_screen.dart';

class HomeScreen extends StatefulWidget {
  final String token;
  final String name;

  const HomeScreen({super.key, required this.token, required this.name});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMinimalHeader(),

            const SizedBox(height: 20),

            _buildStatsSection(),

            const SizedBox(height: 25),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _actionButton("Masuk", Icons.fingerprint, Colors.blue,
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceScreen(token: widget.token)))),
                  _actionButton("Keluar", Icons.exit_to_app, Colors.pinkAccent,
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceScreen(token: widget.token)))),
                  _actionButton("Cuti", Icons.calendar_today_rounded, Colors.orange,
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => LeaveScreen(token: widget.token)))),
                ],
              ),
            ),

            const SizedBox(height: 25),

            Container(
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.black, // Indikator hitam elegan
                  borderRadius: BorderRadius.circular(20),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey[600],
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                tabs: const [
                  Tab(text: "Riwayat Absen"),
                  Tab(text: "Riwayat Cuti"),
                ],
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

  Widget _buildMinimalHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Halo, ${widget.name.split(' ')[0]}", // Ambil nama depan saja biar rapi
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.black87),
              ),
              Text(
                DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.grey[200],
            child: Icon(Icons.person, color: Colors.grey[800]),
          ),
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
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(val, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(unit, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1), // Warna pastel transparan
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildModernAttendanceList() {
    return FutureBuilder<List<dynamic>>(
      future: _attendanceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty) return _emptyIllustration();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            var item = snapshot.data![index];
            DateTime date = DateTime.parse(item['created_at']);
            String day = DateFormat('dd').format(date);
            String month = DateFormat('MMM').format(date);

            String timeIn = item['clock_in'] != null ? DateFormat('HH:mm').format(DateTime.parse(item['clock_in'])) : "--:--";
            String timeOut = item['clock_out'] != null ? DateFormat('HH:mm').format(DateTime.parse(item['clock_out'])) : "--:--";

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  // Tanggal Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(day, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(month, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _timeColumn("Masuk", timeIn, Colors.green),
                        Container(width: 1, height: 25, color: Colors.grey[200]),
                        _timeColumn("Keluar", timeOut, Colors.redAccent),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _timeColumn(String label, String time, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[400])),
        Text(time, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
      ],
    );
  }

  Widget _buildModernLeaveList() {
    return FutureBuilder<List<dynamic>>(
      future: _leaveFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty) return _emptyIllustration();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            var item = snapshot.data![index];
            String type = item['type'] ?? "Cuti";
            String date = item['start_date'] ?? "";
            String status = item['status'] ?? "Pending";

            Color badgeColor = status == "Approved" ? Colors.green : Colors.orange;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle),
                    child: const Icon(Icons.description, color: Colors.blue, size: 20),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(type, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(date, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(status, style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _emptyIllustration() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 40, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text("Tidak ada data", style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }
}