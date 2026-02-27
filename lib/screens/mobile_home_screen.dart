import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk PlatformException
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart'; // Wajib ada untuk Permission.phone
import 'package:my_device_info/my_device_info.dart'; // Package device info
import 'package:sumber_baru/screens/add_store_screen.dart';

import '../services/api_services.dart';
import 'attendance_screen.dart';
import 'leave_screen.dart';
import 'pdf_viewer_screen.dart';
import 'visit_schedule_screen.dart';
import 'package:sumber_baru/screens/profile_screen.dart';

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

  // --- 1. COLORS ---
  final Color _brandRed = const Color(0xFFD32F2F);
  final Color _darkAsphalt = const Color(0xFF1A1A1A);
  final Color _silverMetal = const Color(0xFFF5F5F5);
  final Color _chrome = const Color(0xFFE0E0E0);
  final Color _successGreen = const Color(0xFF2E7D32);

  // --- 2. VARIABLE DEVICE INFO ---
  String _platformVersion = 'Unknown';
  String _imeiNo = 'Unknown';
  String _modelName = 'Unknown';
  String _manufacturer = 'Unknown';
  String _deviceName = 'Unknown';
  String _hardware = 'Unknown';

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _tabController = TabController(length: 2, vsync: this);

    _loadInitialData();
    _initDeviceState(); // Panggil fungsi ambil data HP
  }

  // --- 3. LOGIKA AMBIL DATA HP (Sesuai Snippet Anda) ---
  Future<void> _initDeviceState() async {
    // Cek Permission dulu
    var status = await Permission.phone.status;
    if (!status.isGranted) {
      status = await Permission.phone.request();
    }

    if (status.isGranted) {
      try {
        String platformVersion = await MyDeviceInfo.platformVersion;
        String imeiNo = await MyDeviceInfo.deviceIMEINumber;
        String modelName = await MyDeviceInfo.deviceModel;
        String manufacturer = await MyDeviceInfo.deviceManufacturer;
        String deviceName = await MyDeviceInfo.deviceName;
        String hardware = await MyDeviceInfo.hardware;

        if (!mounted) return;

        setState(() {
          _platformVersion = platformVersion;
          _imeiNo = imeiNo;
          _modelName = modelName;
          _manufacturer = manufacturer;
          _deviceName = deviceName;
          _hardware = hardware;
        });
      } on PlatformException {
        if (!mounted) return;
        setState(() {
          _platformVersion = 'Failed to get platform version.';
        });
      }
    }
  }

  void _loadInitialData() {
    _profileFuture = _apiService.getProfile(widget.token);
    _attendanceFuture = _apiService.getHistory(widget.token);
    _leaveFuture = _apiService.getLeaveHistory(widget.token);
  }

  Future<void> _refreshData() async {
    setState(() {
      _loadInitialData();
      _initDeviceState(); // Refresh device info juga
    });
    try {
      await Future.wait([_profileFuture, _attendanceFuture, _leaveFuture]);
    } catch (e) {
      print("Error refreshing data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _silverMetal,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: _brandRed,
          backgroundColor: Colors.white,
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _buildDashboardHeader(),
                      const SizedBox(height: 25),
                      _buildActionButtons(),
                      const SizedBox(height: 20),
                      _buildStatsSection(),
                      const SizedBox(height: 20),

                      // --- 4. MENAMPILKAN INFO DEVICE DI SINI ---
                      _buildDeviceInfoCard(),

                      const SizedBox(height: 25),
                    ],
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    minHeight: 65.0,
                    maxHeight: 65.0,
                    child: Container(
                      color: _silverMetal,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(color: _darkAsphalt, borderRadius: BorderRadius.circular(8)),
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.grey[600],
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          tabs: const [Tab(text: "Riwayat Absen"), Tab(text: "Riwayat Cuti")],
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
                _buildScrollableList(_buildSliverAttendanceList(), 'absen_mobile'),
                _buildScrollableList(_buildSliverLeaveList(), 'cuti_mobile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableList(Widget sliverList, String key) {
    return Builder(builder: (context) => CustomScrollView(
      key: PageStorageKey<String>(key),
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(padding: const EdgeInsets.only(top: 10, bottom: 20), sliver: sliverList),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    ));
  }

  // --- WIDGET BARU: INFO DEVICE ---
  Widget _buildDeviceInfoCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _chrome),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.perm_device_information_rounded, color: _darkAsphalt, size: 20),
                const SizedBox(width: 8),
                Text("Informasi Perangkat", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _darkAsphalt)),
              ],
            ),
            const Divider(height: 24),
            _deviceInfoRow("Model", "$_manufacturer $_modelName"),
            _deviceInfoRow("Device Name", _deviceName),
            _deviceInfoRow("Hardware", _hardware),
            _deviceInfoRow("Android Ver", _platformVersion),
            _deviceInfoRow("IMEI", _imeiNo, isBold: true, color: _brandRed),
          ],
        ),
      ),
    );
  }

  Widget _deviceInfoRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
                  color: color ?? _darkAsphalt
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS UI LAINNYA ---

  Widget _buildDashboardHeader() {
    DateTime now = DateTime.now();
    String dayName = DateFormat('EEEE', 'id_ID').format(now);
    String fullDate = DateFormat('d MMMM yyyy', 'id_ID').format(now);

    return ClipPath(
      clipper: HomeHeaderClipper(),
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(color: _darkAsphalt),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'lib/assets/spooring-berkala.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(color: _darkAsphalt),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.8)],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 40, top: -50,
              child: Transform.rotate(
                angle: 0.2,
                child: Container(width: 10, height: 400, color: _brandRed.withOpacity(0.6)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Mode Mobile / Lapangan", style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(
                        widget.name.split(' ')[0],
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity(0.2))
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_outlined, color: _brandRed, size: 14),
                            const SizedBox(width: 8),
                            Text("$dayName, $fullDate", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ProfileScreen(token: widget.token))
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _brandRed, width: 2)
                      ),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: const Icon(Icons.person_outline, color: Colors.white, size: 32),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // --- BARIS 1: KIRIM KUNJUNGAN & PENGAJUAN CUTI (Sejajar) ---
          Row(
            children: [
              Expanded(
                child: _bigButton(
                  "KIRIM KUNJUNGAN",
                  Icons.camera_alt_outlined,
                  Colors.blueAccent,
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceScreen(token: widget.token, isMobile: true))),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _bigButton(
                  "PENGAJUAN CUTI",
                  Icons.calendar_month_outlined,
                  Colors.orange,
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => LeaveScreen(token: widget.token))),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // --- BARIS 2: JADWAL KUNJUNGAN (Lebar Penuh) ---
          SizedBox(
            width: double.infinity,
            child: _bigButton(
              "JADWAL KUNJUNGAN",
              Icons.schedule_send_outlined,
              _darkAsphalt,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => VisitScheduleScreen(token: widget.token))),
            ), // Tutup _bigButton diperbaiki di sini
          ),

          const SizedBox(height: 12),

          // --- BARIS 3: TAMBAH TOKO BARU (Lebar Penuh) ---
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _darkAsphalt,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddStoreScreen(token: widget.token))),
              icon: const Icon(Icons.storefront_rounded, color: Colors.white),
              label: const Text(
                "TAMBAH TOKO BARU",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
              ),
            ),
          ),

        ],
      ),
    );
  }

  Widget _bigButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      shadowColor: color.withOpacity(0.4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 10),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(height: 8),
              Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          String sisa = snapshot.data?['leave_quota']?.toString() ?? "0";
          String hutang = snapshot.data?['debt_hours']?.toString() ?? "0";
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _chrome),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  _statItem("Sisa Cuti", sisa, "Hari", _darkAsphalt, Icons.pie_chart_outline_rounded),
                  VerticalDivider(color: _chrome, thickness: 1, width: 30),
                  _statItem("Terlambat", hutang, "Jam", _brandRed, Icons.access_time_rounded),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statItem(String label, String val, String unit, Color color, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.08), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(val, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
                  const SizedBox(width: 4),
                  Text(unit, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAttendanceList() {
    return FutureBuilder<List<dynamic>>(
      future: _attendanceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())));

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverFillRemaining(hasScrollBody: false, child: _emptyIllustration("Belum ada riwayat kunjungan"));
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            var item = snapshot.data![index];
            DateTime date = DateTime.parse(item['created_at']);
            String timeIn = item['clock_in'] != null ? DateFormat('HH:mm').format(DateTime.parse(item['clock_in'])) : "--:--";

            return Container(
              margin: const EdgeInsets.only(bottom: 12, left: 20, right: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12),
                border: Border(left: BorderSide(color: Colors.blueAccent, width: 5)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: Row(children: [
                Column(children: [
                  Text(DateFormat('dd').format(date), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: _darkAsphalt)),
                  Text(DateFormat('MMM').format(date).toUpperCase(), style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w800)),
                ]),
                VerticalDivider(color: _chrome, width: 32),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("WAKTU KUNJUNGAN", style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(timeIn, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _darkAsphalt)),
                  ],
                )),
                Icon(Icons.check_circle, color: Colors.blueAccent.withOpacity(0.5)),
              ]),
            );
          }, childCount: snapshot.data!.length),
        );
      },
    );
  }

  Widget _buildSliverLeaveList() {
    return FutureBuilder<List<dynamic>>(
      future: _leaveFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())));

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverFillRemaining(hasScrollBody: false, child: _emptyIllustration("Belum ada riwayat cuti"));
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            var item = snapshot.data![index];
            String status = item['status'] ?? "Pending";
            Color badgeColor = status == "Approved" ? _successGreen : Colors.orange;
            return GestureDetector(
              onTap: () => _showLeaveDetail(item),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12, left: 20, right: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2))]),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _brandRed.withOpacity(0.08), shape: BoxShape.circle), child: Icon(Icons.description_outlined, color: _brandRed, size: 20)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item['type'] ?? "Cuti", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _darkAsphalt)), const SizedBox(height: 4), Text("${item['start_date']}", style: TextStyle(color: Colors.grey[600], fontSize: 12))])),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(status.toUpperCase(), style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.w900))),
                ]),
              ),
            );
          }, childCount: snapshot.data!.length),
        );
      },
    );
  }

  Widget _emptyIllustration(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold)),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  void _showLeaveDetail(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.9, expand: false,
        builder: (_, controller) => Container(
          padding: const EdgeInsets.all(25),
          child: ListView(
            controller: controller,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              Text("Detail Pengajuan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _darkAsphalt)),
              const SizedBox(height: 20),
              _detailRow(Icons.category_outlined, "Tipe", item['type'] ?? "-"),
              _detailRow(Icons.info_outline, "Status", item['status'] ?? "Pending"),
              const Divider(height: 30),
              _detailRow(Icons.calendar_today_outlined, "Mulai", item['start_date'] ?? "-"),
              _detailRow(Icons.event_outlined, "Selesai", item['end_date'] ?? "-"),
              _detailRow(Icons.note_outlined, "Alasan", item['reason'] ?? "Tidak ada catatan"),
              if (item['attachment_url'] != null) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PdfViewerScreen(url: item['attachment_url'], title: "Lampiran Cuti"))),
                  icon: const Icon(Icons.picture_as_pdf_rounded), label: const Text("LIHAT LAMPIRAN PDF"),
                  style: ElevatedButton.styleFrom(backgroundColor: _brandRed, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(children: [
        Icon(icon, size: 18, color: _brandRed), const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)), Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _darkAsphalt))])
      ]),
    );
  }
}

class HomeHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(size.width / 2, size.height, size.width, size.height - 40);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight; final double maxHeight; final Widget child;
  _SliverAppBarDelegate({required this.minHeight, required this.maxHeight, required this.child});
  @override double get minExtent => minHeight;
  @override double get maxExtent => maxHeight;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => SizedBox.expand(child: child);
  @override bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => maxHeight != oldDelegate.maxHeight || minHeight != oldDelegate.minHeight || child != oldDelegate.child;
}