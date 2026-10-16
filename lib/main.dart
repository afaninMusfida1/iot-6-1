import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

const List<String> daftarPasien = ['pasien01', 'pasien02'];

DatabaseReference get refMonitoring =>
    FirebaseDatabase.instance.ref('monitoring-pasien');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AplikasiRumahSakit());
}

// ───────────────────────── Model & aksi ─────────────────────────

class DataPasien {
  const DataPasien({
    required this.kunci,
    required this.status,
    required this.pesan,
  });

  final String kunci; // contoh: pasien01
  final int status; // 0 = aman, 1 = minta bantuan
  final String pesan;

  int get nomor => int.parse(kunci.replaceAll('pasien', ''));
  String get nama => 'Pasien ${nomor.toString().padLeft(2, '0')}';
  bool get butuhBantuan => status == 1;
  String get pesanTampil => pesan.isEmpty ? '$nama meminta bantuan' : pesan;

  static List<DataPasien> dariSnapshot(Object? nilai) {
    final peta = nilai is Map ? nilai : <dynamic, dynamic>{};
    return daftarPasien.map((kunci) {
      final item = peta[kunci];
      final data = item is Map ? item : <dynamic, dynamic>{};
      return DataPasien(
        kunci: kunci,
        status: int.tryParse('${data['status']}') ?? 0,
        pesan: '${data['pesan'] ?? ''}',
      );
    }).toList();
  }
}

Future<void> kirimPanggilan(DataPasien pasien) {
  return refMonitoring.child(pasien.kunci).set({
    'status': 1,
    'pesan': 'Pasien ${pasien.nomor} Meminta Bantuan',
  });
}

Future<void> selesaiPanggilan(DataPasien pasien) {
  return refMonitoring.child(pasien.kunci).set({
    'status': 0,
    'pesan': '',
  });
}

Future<void> jalankanAman(
  BuildContext context,
  Future<void> Function() aksi,
) async {
  try {
    await aksi();
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gagal mengirim data: $e')),
    );
  }
}

// ───────────────────────── Aplikasi ─────────────────────────

class AplikasiRumahSakit extends StatelessWidget {
  const AplikasiRumahSakit({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monitoring Pasien RS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const HalamanPilihPeran(),
    );
  }
}

class HalamanPilihPeran extends StatelessWidget {
  const HalamanPilihPeran({super.key});

  void _buka(BuildContext context, Widget halaman) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => halaman));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_hospital, size: 80),
              const SizedBox(height: 16),
              Text(
                'Monitoring Pasien RS',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text('Pilih peran perangkat ini'),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _buka(context, const HalamanPasien()),
                  icon: const Icon(Icons.bed),
                  label: const Text('Aplikasi Pasien'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _buka(context, const HalamanPerawat()),
                  icon: const Icon(Icons.medical_services),
                  label: const Text('Aplikasi Perawat'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Membungkus stream Firebase agar dipakai halaman Pasien dan Perawat.
class PenyediaDataPasien extends StatelessWidget {
  const PenyediaDataPasien({super.key, required this.builder});

  final Widget Function(BuildContext context, List<DataPasien> daftar) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: refMonitoring.onValue,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return builder(
          context,
          DataPasien.dariSnapshot(snapshot.data!.snapshot.value),
        );
      },
    );
  }
}

// ───────────────────────── Halaman Pasien ─────────────────────────

class HalamanPasien extends StatelessWidget {
  const HalamanPasien({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aplikasi Pasien')),
      body: PenyediaDataPasien(
        builder: (context, daftar) => ListView(
          padding: const EdgeInsets.all(16),
          children: [for (final pasien in daftar) KartuPasien(pasien: pasien)],
        ),
      ),
    );
  }
}

class KartuPasien extends StatelessWidget {
  const KartuPasien({super.key, required this.pasien});

  final DataPasien pasien;

  @override
  Widget build(BuildContext context) {
    final aktif = pasien.butuhBantuan;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              aktif ? Icons.notifications_active : Icons.notifications_none,
              size: 56,
              color: aktif ? Colors.red : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(pasien.nama, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(aktif ? 'Menunggu perawat...' : 'Tidak ada panggilan'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: aktif
                  ? OutlinedButton.icon(
                      onPressed: () => jalankanAman(
                        context,
                        () => selesaiPanggilan(pasien),
                      ),
                      icon: const Icon(Icons.close),
                      label: const Text('BATALKAN PANGGILAN'),
                    )
                  : FilledButton.icon(
                      onPressed: () => jalankanAman(
                        context,
                        () => kirimPanggilan(pasien),
                      ),
                      icon: const Icon(Icons.notifications_active),
                      label: const Text('MINTA BANTUAN'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Halaman Perawat ─────────────────────────

class HalamanPerawat extends StatelessWidget {
  const HalamanPerawat({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aplikasi Perawat')),
      body: PenyediaDataPasien(
        builder: (context, daftar) {
          final aktif = daftar.where((p) => p.butuhBantuan).toList();

          if (aktif.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 80, color: Colors.green),
                  SizedBox(height: 12),
                  Text('Semua pasien aman'),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final pasien in aktif)
                Card(
                  color: Colors.red.shade50,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                      size: 36,
                    ),
                    title: Text(pasien.pesanTampil),
                    subtitle: Text(pasien.nama),
                    trailing: FilledButton(
                      onPressed: () => jalankanAman(
                        context,
                        () => selesaiPanggilan(pasien),
                      ),
                      child: const Text('SELESAI'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}