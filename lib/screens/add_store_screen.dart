import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_services.dart';

class AddStoreScreen extends StatefulWidget {
  final String token;
  const AddStoreScreen({super.key, required this.token});

  @override
  State<AddStoreScreen> createState() => _AddStoreScreenState();
}

class _AddStoreScreenState extends State<AddStoreScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  // Colors based on your theme
  final Color _brandRed = const Color(0xFFD32F2F);
  final Color _darkAsphalt = const Color(0xFF1A1A1A);
  final Color _silverMetal = const Color(0xFFF5F5F5);

  // Form Controllers
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _stockController = TextEditingController();
  final _radiusController = TextEditingController(text: "100");

  // 1. TAMBAHAN CONTROLLER BARU
  final _ownerNameController = TextEditingController();
  final _ownerPhoneController = TextEditingController();

  // Location Data
  double? _latitude;
  double? _longitude;
  bool _isFetchingLocation = false;
  bool _isSubmitting = false;

  // Dropdown Data Arrays
  List<dynamic> _areas = [];
  List<dynamic> _provinces = [];
  List<dynamic> _regencies = [];
  List<dynamic> _districts = [];

  // Selected Values
  Map<String, dynamic>? _selectedArea;
  Map<String, dynamic>? _selectedProvince;
  Map<String, dynamic>? _selectedRegency;
  Map<String, dynamic>? _selectedDistrict;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _getLocation();
  }

  // --- FETCH DATA LOKASI & WILAYAH ---
  Future<void> _fetchInitialData() async {
    try {
      var areas = await _apiService.getAreas(widget.token);
      var provs = await _apiService.getProvinces(widget.token);
      setState(() {
        _areas = areas;
        _provinces = provs;
      });
    } catch (e) {
      _showSnack("Gagal mengambil data wilayah: $e", Colors.red);
    }
  }

  Future<void> _fetchRegencies(String provId) async {
    setState(() {
      _regencies = [];
      _districts = [];
      _selectedRegency = null;
      _selectedDistrict = null;
    });
    try {
      var regencies = await _apiService.getRegencies(widget.token, provId);
      setState(() => _regencies = regencies);
    } catch (e) {
      _showSnack("Gagal mengambil data Kabupaten", Colors.red);
    }
  }

  Future<void> _fetchDistricts(String regencyId) async {
    setState(() {
      _districts = [];
      _selectedDistrict = null;
    });
    try {
      var dists = await _apiService.getDistricts(widget.token, regencyId);
      setState(() => _districts = dists);
    } catch (e) {
      _showSnack("Gagal mengambil data Kecamatan", Colors.red);
    }
  }

  // --- MENDAPATKAN GPS LOKASI ---
  Future<void> _getLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('GPS tidak aktif');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Izin ditolak');
      }
      if (permission == LocationPermission.deniedForever) throw Exception('Izin ditolak permanen');

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      _showSnack("Gagal mendapat lokasi: $e", Colors.red);
    } finally {
      setState(() => _isFetchingLocation = false);
    }
  }

  // --- SUBMIT DATA KE API ---
  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latitude == null || _longitude == null) {
      _showSnack("Mohon tunggu atau refresh lokasi GPS Anda!", Colors.orange);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 2. MASUKKAN DATA OWNER KE PAYLOAD
      Map<String, dynamic> payload = {
        "name": _nameController.text,
        "owner_name": _ownerNameController.text, // Field Baru
        "phone": _ownerPhoneController.text,     // Field Baru
        "code_area": _selectedArea?['code_area'],
        "stock": int.tryParse(_stockController.text) ?? 0,
        "address": _addressController.text,
        "provinsi": _selectedProvince?['name'],
        "kabupaten": _selectedRegency?['name'],
        "kecamatan": _selectedDistrict?['name'],
        "lat": _latitude,
        "long": _longitude,
        "radius": int.tryParse(_radiusController.text) ?? 100,
      };

      bool isSuccess = await _apiService.postNewStore(widget.token, payload);

      if (isSuccess) {
        _showSnack("Toko baru berhasil ditambahkan!", Colors.green);
        if (mounted) Navigator.pop(context);
      } else {
        _showSnack("Gagal menambahkan toko.", Colors.red);
      }
    } catch (e) {
      _showSnack("Error: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _silverMetal,
      appBar: AppBar(
        backgroundColor: _darkAsphalt,
        title: const Text("Tambah Toko Baru", style: TextStyle(color: Colors.white, fontSize: 18)),
        leading: const BackButton(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("Informasi Utama"),
              _buildTextField("Nama Toko", _nameController, Icons.storefront),

              // 3. TAMBAHAN WIDGET INPUT OWNER
              _buildTextField("Nama Pemilik (Owner)", _ownerNameController, Icons.person),
              _buildTextField("No. Telepon / HP", _ownerPhoneController, Icons.phone, isNumber: true),

              _buildDropdown(
                "Code Area",
                _areas,
                _selectedArea,
                    (val) => setState(() => _selectedArea = val),
                    (item) => "${item['code_area']} (${item['name']})",
              ),
              _buildTextField("Stok Awal", _stockController, Icons.inventory, isNumber: true),

              const SizedBox(height: 20),
              _buildSectionTitle("Lokasi & Wilayah"),

              _buildDropdown(
                  "Provinsi",
                  _provinces,
                  _selectedProvince,
                      (val) {
                    setState(() => _selectedProvince = val);
                    if (val != null) _fetchRegencies(val['id'].toString());
                  },
                      (item) => item['name']
              ),

              _buildDropdown(
                  "Kabupaten / Kota",
                  _regencies,
                  _selectedRegency,
                      (val) {
                    setState(() => _selectedRegency = val);
                    if (val != null) _fetchDistricts(val['id'].toString());
                  },
                      (item) => item['name']
              ),

              _buildDropdown(
                  "Kecamatan",
                  _districts,
                  _selectedDistrict,
                      (val) => setState(() => _selectedDistrict = val),
                      (item) => item['name']
              ),
              _buildTextField("Alamat Lengkap", _addressController, Icons.location_on, maxLines: 3),


              const SizedBox(height: 10),

              // BOX GPS
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                child: Row(
                  children: [
                    Icon(Icons.gps_fixed, color: _brandRed, size: 30),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Titik Kordinat (GPS)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          _isFetchingLocation
                              ? const Text("Mencari lokasi...", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                              : Text(_latitude != null ? "Lat: $_latitude\nLon: $_longitude" : "Lokasi tidak ditemukan", style: TextStyle(color: Colors.blue[700], fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh), color: Colors.grey[600],
                      onPressed: _isFetchingLocation ? null : _getLocation,
                    )
                  ],
                ),
              ),

              const SizedBox(height: 35),

              // SUBMIT BUTTON
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSubmitting ? null : _submitData,
                  child: _isSubmitting
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("SIMPAN TOKO", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 10),
      child: Text(title, style: TextStyle(color: _darkAsphalt, fontSize: 16, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isNumber = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        validator: (value) => value == null || value.isEmpty ? "$label harus diisi" : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: maxLines == 1 ? Icon(icon, color: Colors.grey[600]) : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _brandRed)),
        ),
      ),
    );
  }

  Widget _buildDropdown(
      String label,
      List<dynamic> items,
      Map<String, dynamic>? selectedValue,
      Function(Map<String, dynamic>?) onChanged,
      String Function(Map<String, dynamic>) getLabel,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<Map<String, dynamic>>(
        value: selectedValue,
        validator: (value) => value == null ? "$label harus dipilih" : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _brandRed)),
        ),
        items: items.map((item) {
          return DropdownMenuItem<Map<String, dynamic>>(
            value: item,
            child: Text(
              getLabel(item),
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}