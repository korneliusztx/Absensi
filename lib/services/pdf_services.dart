import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfService {
  Future<void> createPdf(
      String name,
      String nik,
      String divisi,
      String leaveType, // Jenis Cuti yang dipilih
      DateTime startDate,
      DateTime endDate,
      String reason,
      String handoverName,
      String address,
      String phone,
      ) async {

    final pdf = pw.Document();

    // Hitung jumlah hari
    int totalDays = endDate.difference(startDate).inDays + 1;

    // Font bawaan PDF kadang tidak support bold standar, kita pakai default

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(""), // Placeholder Logo Kiri (Kosong)
                    pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          // Ganti Text ini dengan pw.Image jika punya logo file
                          pw.Text("PT. PRIMA TUNGGAL MANDIRI", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                        ]
                    )
                  ]
              ),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text("PERMOHONAN CUTI", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, decoration: pw.TextDecoration.underline)),
              ),
              pw.SizedBox(height: 20),

              // --- DATA KARYAWAN (Baris 1 & 2) ---
              _buildRowInfo("Nama", ": $name", "Divisi / Departement", ": $divisi"),
              pw.SizedBox(height: 5),
              _buildRowInfo("NIK / Barcode", ": $nik", "Hari / Tanggal", ": ${DateFormat('dd-MM-yyyy').format(DateTime.now())}"),

              pw.SizedBox(height: 20),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 10),

              // --- JENIS CUTI & TANGGAL ---
              pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Kolom Kiri: Checkbox Jenis Cuti
                    pw.Expanded(
                        flex: 1,
                        child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text("Jenis Cuti :"),
                              pw.SizedBox(height: 5),
                              _buildCheckbox("Cuti Tahunan", leaveType == "Cuti Tahunan"),
                              _buildCheckbox("Cuti Hamil / Melahirkan", leaveType.contains("Hamil")),
                              _buildCheckbox("Cuti / Izin Khusus", leaveType.contains("Khusus")),
                            ]
                        )
                    ),
                    // Kolom Kanan: Diisi Oleh Pemohon
                    pw.Expanded(
                        flex: 1,
                        child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text("Diisi oleh Pemohon :"),
                              pw.SizedBox(height: 5),
                              _buildSimpleRow("Mulai tanggal", ": ${DateFormat('dd-MM-yyyy').format(startDate)}"),
                              _buildSimpleRow("Sampai tanggal", ": ${DateFormat('dd-MM-yyyy').format(endDate)}"),
                              _buildSimpleRow("Jumlah hari", ": $totalDays Hari"),
                            ]
                        )
                    )
                  ]
              ),

              pw.SizedBox(height: 15),
              pw.Text("Pekerjaan yang ditinggalkan & masih harus diselesaikan :"),
              pw.Container(
                  width: double.infinity,
                  height: 30,
                  decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(width: 1))
                  ),
                  child: pw.Text(reason, style: const pw.TextStyle(fontSize: 10)) // Alasan dimasukkan sini
              ),

              pw.SizedBox(height: 15),
              pw.Text("Selama melakukan cuti :"),
              pw.SizedBox(height: 5),

              pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                        child: pw.Column(children: [
                          _buildSimpleRow("Pekerjaan diserahkan kepada", ""),
                          _buildSimpleRow("Nama", ": $handoverName"),
                          _buildSimpleRow("Tanda Tangan", ": _____________"),
                        ])
                    ),
                    pw.SizedBox(width: 20),
                    pw.Expanded(
                        child: pw.Column(children: [
                          _buildSimpleRow("Dapat dihubungi di", ""),
                          _buildSimpleRow("Alamat", ": $address"),
                          _buildSimpleRow("No. Telp/HP", ": $phone"),
                        ])
                    )
                  ]
              ),

              pw.SizedBox(height: 20),

              // --- TABEL PERHITUNGAN (Kotak Besar di Bawah) ---
              pw.Container(
                  decoration: pw.BoxDecoration(border: pw.Border.all()),
                  child: pw.Row(
                      children: [
                        // Kolom Kiri: Perhitungan Cuti
                        pw.Expanded(
                            child: pw.Padding(
                                padding: const pw.EdgeInsets.all(5),
                                child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text("Perhitungan cuti tahunan :", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                                      pw.Divider(),
                                      _buildTableItem("Tgl. Masuk Kerja", ": _______"),
                                      pw.SizedBox(height: 10),
                                      _buildTableItem("Sisa Cuti tahun", ": _______ hari"),
                                      _buildTableItem("Cuti yang diambil", ": $totalDays hari (-)"),
                                      pw.Divider(),
                                      _buildTableItem("Sisa Cuti", ": _______ hari"),
                                    ]
                                )
                            )
                        ),
                        pw.Container(width: 1, height: 100, color: PdfColors.black), // Garis Tengah Vertikal
                        // Kolom Kanan: Cuti Khusus
                        pw.Expanded(
                            child: pw.Padding(
                                padding: const pw.EdgeInsets.all(5),
                                child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text("Cuti Khusus (tidak mengurangi cuti tahunan) :", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                                      pw.Divider(),
                                      _buildSmallText("1. Karyawan Menikah : 3 hari"),
                                      _buildSmallText("2. Menikahkan anak : 2 hari"),
                                      _buildSmallText("3. Istri melahirkan/keguguran : 2 hari"),
                                      _buildSmallText("4. Anggota keluarga meninggal : 1 hari"),
                                    ]
                                )
                            )
                        ),
                      ]
                  )
              ),

              pw.SizedBox(height: 10),

              // --- KOLOM TANDA TANGAN ---
              pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    pw.TableRow(children: [
                      pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(""))), // Kosong kiri
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("Ya   Tidak   Tunda")),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("Ya   Tidak   Tunda")),
                    ]),
                    pw.TableRow(children: [
                      pw.Container(height: 40), // Ruang Tanda Tangan
                      pw.Container(height: 40),
                      pw.Container(height: 40),
                    ]),
                    pw.TableRow(children: [
                      pw.Center(child: pw.Text("Karyawan", style: const pw.TextStyle(fontSize: 10))),
                      pw.Center(child: pw.Text("Div. / Dept. Head", style: const pw.TextStyle(fontSize: 10))),
                      pw.Center(child: pw.Text("HR Dept.", style: const pw.TextStyle(fontSize: 10))),
                    ]),
                  ]
              ),

              pw.SizedBox(height: 5),
              pw.Text("*) Note: Permohonan cuti diterima HR Dept paling lambat 1 minggu sebelum tanggal pelaksanaan.", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            ],
          );
        },
      ),
    );

    // Langsung Print / Share / Simpan
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // --- WIDGET HELPER UNTUK PDF ---

  pw.Widget _buildRowInfo(String label1, String val1, String label2, String val2) {
    return pw.Row(
        children: [
          pw.Expanded(child: pw.Row(children: [pw.Container(width: 80, child: pw.Text(label1)), pw.Text(val1)])),
          pw.Expanded(child: pw.Row(children: [pw.Container(width: 100, child: pw.Text(label2)), pw.Text(val2)])),
        ]
    );
  }

  pw.Widget _buildSimpleRow(String label, String val) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
          children: [
            pw.Container(width: 100, child: pw.Text(label, style: const pw.TextStyle(fontSize: 10))),
            pw.Text(val, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ]
      ),
    );
  }

  pw.Widget _buildCheckbox(String label, bool isChecked) {
    return pw.Row(
        children: [
          pw.Container(
            width: 10, height: 10,
            margin: const pw.EdgeInsets.only(right: 5, bottom: 2),
            decoration: pw.BoxDecoration(border: pw.Border.all()),
            child: isChecked ? pw.Center(child: pw.Text("X", style: const pw.TextStyle(fontSize: 8))) : null,
          ),
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        ]
    );
  }

  pw.Widget _buildTableItem(String label, String val) {
    return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          pw.Text(val, style: const pw.TextStyle(fontSize: 9)),
        ]
    );
  }

  pw.Widget _buildSmallText(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
    );
  }
}