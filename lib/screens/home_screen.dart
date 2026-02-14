import 'package:SumberBaru/screens/pdf_viewer_screen.dart';
import 'package:SumberBaru/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_services.dart';
import 'attendance_screen.dart';
import 'leave_screen.dart';
import 'login_screen.dart';

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

  // --- Warna Branding ---
  final Color _brandRed = const Color(0xFFD32F2F);
  final Color _brandBlack = const Color(0xFF212121);
  final Color _brandOrange = const Color(0xFFFFA000);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() {
      _profileFuture = _apiService.getProfile(widget.token);
      _attendanceFuture = _apiService.getHistory(widget.token);
      _leaveFuture = _apiService.getLeaveHistory(widget.token);
    });
    await Future.wait([_profileFuture, _attendanceFuture, _leaveFuture]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: _brandRed,
          notificationPredicate: (notification) {
            // Memastikan refresh indicator bekerja meskipun di dalam NestedScrollView
            return notification.depth == 1;
          },
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                // BAGIAN 1: Header yang ikut ter-scroll hilang (Logo, Stats, Tombol)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMinimalHeader(),
                      const SizedBox(height: 24),
                      _buildStatsSection(),
                      const SizedBox(height: 30),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _actionButton("Masuk", Icons.login, _brandRed,
                                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceScreen(token: widget.token)))),
                            _actionButton("Keluar", Icons.logout, _brandBlack,
                                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceScreen(token: widget.token)))),
                            _actionButton("Cuti", Icons.calendar_today_rounded, _brandOrange,
                                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => LeaveScreen(token: widget.token)))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),

                // BAGIAN 2: TabBar yang LENGKET (Pinned) di atas
                SliverPersistentHeader(
                  pinned: true, // KUNCI AGAR MENTOK KE ATAS TAPI GAK HILANG
                  floating: false,
                  delegate: _SliverAppBarDelegate(
                    minHeight: 60.0,
                    maxHeight: 60.0,
                    child: Container(
                      color: const Color(0xFFF8F9FA), // Samakan warna background agar tidak transparan
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: _brandBlack,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.grey[600],
                          dividerColor: Colors.transparent,
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          tabs: const [
                            Tab(text: "Riwayat Absen"),
                            Tab(text: "Riwayat Cuti"),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                // Bungkus dengan Builder agar CustomScrollView punya context sendiri
                Builder(
                  builder: (BuildContext context) {
                    return CustomScrollView(
                      key: const PageStorageKey<String>('absen'),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.only(top: 16, bottom: 20),
                          sliver: _buildSliverAttendanceList(),
                        ),
                      ],
                    );
                  },
                ),
                Builder(
                  builder: (BuildContext context) {
                    return CustomScrollView(
                      key: const PageStorageKey<String>('cuti'),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.only(top: 16, bottom: 20),
                          sliver: _buildSliverLeaveList(),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildMinimalHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20), // Sesuaikan padding
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LOGO (Sesuai gambar kamu)
              Image.asset("lib/assets/sbb-removebg-preview.png", height: 30),
              const SizedBox(height: 10),
              Text(
                "Halo, ${widget.name.split(' ')[0]}",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.black87),
              ),
              // ... tanggal ...
            ],
          ),

          // GANTI TOMBOL "KELUAR" LAMA DENGAN INI:
          GestureDetector(
            onTap: () {
              // Navigasi ke Profile Screen
              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileScreen(
                    token: widget.token, // Cukup kirim Token saja
                  ))
              );
            },
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.grey[200],
                child: Icon(Icons.person, color: Colors.grey[800]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          String sisa = snapshot.data?['leave_quota']?.toString() ?? "-";
          String hutang = snapshot.data?['debt_hours']?.toString() ?? "-";
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 8))]),
            child: Row(children: [_statItem("Sisa Cuti", sisa, "Hari", _brandBlack), Container(height: 40, width: 1, color: Colors.grey[200], margin: const EdgeInsets.symmetric(horizontal: 24)), _statItem("Terlambat", hutang, "Jam", _brandRed)]),
          );
        },
      ),
    );
  }

  Widget _statItem(String label, String val, String unit, Color color) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(val, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)), const SizedBox(width: 6), Padding(padding: const EdgeInsets.only(bottom: 5), child: Text(unit, style: TextStyle(fontSize: 14, color: Colors.grey[400], fontWeight: FontWeight.w600)))])
      ]),
    );
  }

  Widget _actionButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(height: 64, width: 64, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Icon(icon, color: color, size: 28)),
        const SizedBox(height: 10),
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _brandBlack))
      ]),
    );
  }

  // --- SLIVER LIST BUILDERS (Agar performa scroll NestedScrollView maksimal) ---

  Widget _buildSliverAttendanceList() {
    return FutureBuilder<List<dynamic>>(
      future: _attendanceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())));
        if (!snapshot.hasData || snapshot.data!.isEmpty) return SliverToBoxAdapter(child: _emptyIllustration());

        return SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              var item = snapshot.data![index];
              DateTime date = DateTime.parse(item['created_at']);
              String timeIn = item['clock_in'] != null ? DateFormat('HH:mm').format(DateTime.parse(item['clock_in'])) : "--:--";
              String timeOut = item['clock_out'] != null ? DateFormat('HH:mm').format(DateTime.parse(item['clock_out'])) : "--:--";

              return Container(
                margin: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))]),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade100)),
                    child: Column(children: [Text(DateFormat('dd').format(date), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _brandBlack)), Text(DateFormat('MMM').format(date), style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600))]),
                  ),
                  const SizedBox(width: 20),
                  Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_timeColumn("Masuk", timeIn, Colors.green[700]!), Container(width: 1, height: 30, color: Colors.grey[100]), _timeColumn("Keluar", timeOut, _brandRed)])),
                ]),
              );
            },
            childCount: snapshot.data!.length,
          ),
        );
      },
    );
  }

  Widget _buildSliverLeaveList() {
    return FutureBuilder<List<dynamic>>(
      future: _leaveFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())));
        if (!snapshot.hasData || snapshot.data!.isEmpty) return SliverToBoxAdapter(child: _emptyIllustration());

        return SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              var item = snapshot.data![index];
              String status = item['status'] ?? "Pending";
              Color badgeColor = status == "Approved" ? Colors.green : _brandOrange;

              return GestureDetector(
                onTap: () => _showLeaveDetail(item),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))]),
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _brandRed.withOpacity(0.05), shape: BoxShape.circle), child: Icon(Icons.description_outlined, color: _brandRed, size: 22)),
                    const SizedBox(width: 18),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item['type'] ?? "Cuti", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _brandBlack)), const SizedBox(height: 4), Text(item['start_date'] ?? "", style: TextStyle(color: Colors.grey[500], fontSize: 13))])),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text(status, style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.w700))),
                  ]),
                ),
              );
            },
            childCount: snapshot.data!.length,
          ),
        );
      },
    );
  }

  Widget _timeColumn(String label, String time, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.w600)), Text(time, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color))]);
  }

  Widget _emptyIllustration() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(height: 50), Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[300]), const SizedBox(height: 12), Text("Tidak ada data", style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500))]);
  }

  // --- FITUR DETAIL & PDF ---
  void _showLeaveDetail(Map<String, dynamic> item) {
    String type = item['type'] ?? "-";
    String attachment = item['attachment_url'] ?? "";
    String status = item['status'] ?? "Pending";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, controller) {
              return Container(
                padding: const EdgeInsets.all(25),
                child: ListView(
                  controller: controller,
                  children: [
                    Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 20),
                    Text("Detail Pengajuan $type", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text("Status: $status", style: TextStyle(color: status == "Approved" ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                    const Divider(height: 30),
                    _detailRow(Icons.calendar_today, "Tanggal Mulai", item['start_date'] ?? "-"),
                    const SizedBox(height: 15),
                    _detailRow(Icons.event, "Tanggal Selesai", item['end_date'] ?? "-"),
                    const SizedBox(height: 15),
                    _detailRow(Icons.note, "Alasan / Notes", item['reason'] ?? "Tidak ada catatan"),
                    const SizedBox(height: 25),
                    if (attachment.isNotEmpty) ...[
                      const Text("Lampiran:", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PdfViewerScreen(url: attachment, title: "Bukti Cuti - $type"))),
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.withOpacity(0.3))),
                          child: Row(children: [const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 30), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Lihat Dokumen PDF", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)), Text(attachment.split('/').last, style: const TextStyle(color: Colors.grey, fontSize: 12), overflow: TextOverflow.ellipsis)])), const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey)]),
                        ),
                      )
                    ] else
                      const Text("Tidak ada lampiran", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            });
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 20, color: Colors.grey[600]), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 2), Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))]))]);
  }
}

// --- CLASS TAMBAHAN UNTUK STICKY HEADER ---
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}