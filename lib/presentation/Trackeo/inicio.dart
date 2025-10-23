import 'dart:async';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _gpsStream;
  final List<LatLng> _route = [];
  final Set<Polyline> _polylines = {};
  final List<Marker> _markers = [];

  Timer? _timer;
  Duration _elapsed = Duration.zero;
  double _totalDistance = 0;
  bool _isRunning = false;
  bool _isPaused = false;

  // 🎨 Paleta
  final Color naranja = const Color(0xFFFF6B00);
  final Color grisFondo = const Color(0xFFF4F4F4);
  final Color grisBarra = const Color(0xFF303030);
  final Color textoNegro = const Color(0xFF1E1E1E);

  @override
  void dispose() {
    _timer?.cancel();
    _gpsStream?.cancel();
    super.dispose();
  }

  // 📍 Iniciar o reanudar entrenamiento
  Future<void> _startOrResumeTraining() async {
    if (_isPaused) {
      setState(() => _isPaused = false);
      return;
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("⚠️ Activa el GPS")));
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    _route.clear();
    _polylines.clear();
    _markers.clear();
    _totalDistance = 0;
    _elapsed = Duration.zero;
    _isRunning = true;
    _isPaused = false;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isRunning && !_isPaused) {
        setState(() => _elapsed += const Duration(seconds: 1));
      }
    });

    _gpsStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen((pos) {
      if (!_isRunning || _isPaused) return;

      final current = LatLng(pos.latitude, pos.longitude);

      if (_route.isNotEmpty) {
        _totalDistance += _calculateDistance(_route.last, current);
      }

      _route.add(current);
      _updateMap(current);
    });

    setState(() {});
  }

  // 🧭 Actualizar mapa
  void _updateMap(LatLng pos) {
    setState(() {
      _polylines.clear();
      _polylines.add(Polyline(
        polylineId: const PolylineId("route"),
        points: _route,
        color: naranja,
        width: 6,
      ));
      _markers
        ..clear()
        ..add(Marker(
          markerId: const MarkerId("current"),
          position: pos,
          infoWindow: const InfoWindow(title: "Posición actual"),
        ));
    });
    _mapController?.animateCamera(CameraUpdate.newLatLng(pos));
  }

  // 🛑 Pausar
  void _pauseTraining() => setState(() => _isPaused = true);

  // 🏁 Finalizar (guarda la ruta también)
  Future<void> _finishTraining() async {
    _isRunning = false;
    _timer?.cancel();
    _gpsStream?.cancel();

    if (_route.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final kcal = (_totalDistance * 70).round();

    // 🔹 Guardar la ruta (lista de coordenadas)
    final ruta = _route
        .map((p) => {"lat": p.latitude, "lng": p.longitude})
        .toList();

    final data = {
      "fecha": DateTime.now(),
      "distancia": double.parse(_totalDistance.toStringAsFixed(2)),
      "tiempo":
          "${_elapsed.inMinutes} min ${_elapsed.inSeconds.remainder(60)} seg",
      "calorias": kcal,
      "ruta": ruta, // ← Se guarda la ruta
    };

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("trainings")
        .add(data);

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("🏁 Entrenamiento guardado con recorrido")));

    setState(() {
      _route.clear();
      _polylines.clear();
      _markers.clear();
      _totalDistance = 0;
      _elapsed = Duration.zero;
      _isRunning = false;
      _isPaused = false;
    });
  }

  // 📏 Calcular distancia (Haversine)
  double _calculateDistance(LatLng p1, LatLng p2) {
    const R = 6371;
    final dLat = (p2.latitude - p1.latitude) * pi / 180;
    final dLon = (p2.longitude - p1.longitude) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(p1.latitude * pi / 180) *
            cos(p2.latitude * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  int get _calories => (_totalDistance * 70).round();

  String get _formattedTime {
    final h = _elapsed.inHours.toString().padLeft(2, '0');
    final m = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: grisFondo,
      appBar: AppBar(
        backgroundColor: grisBarra,
        title: const Text("Entrenamiento",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.48,
                child: GoogleMap(
                  onMapCreated: (controller) => _mapController = controller,
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(19.0668, -98.1887),
                    zoom: 15,
                  ),
                  polylines: _polylines,
                  markers: Set.from(_markers),
                  myLocationEnabled: true,
                  zoomControlsEnabled: false,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Datos
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(_formattedTime,
                      style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: textoNegro)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatItem(
                          label: "Distancia",
                          value: "${_totalDistance.toStringAsFixed(2)} km",
                          color: naranja),
                      _StatItem(
                          label: "Calorías",
                          value: "$_calories kcal",
                          color: naranja),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),

            if (!_isPaused)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRunning ? Colors.black : naranja,
                    padding:
                        const EdgeInsets.symmetric(vertical: 22, horizontal: 0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50)),
                  ),
                  onPressed:
                      _isRunning ? _pauseTraining : _startOrResumeTraining,
                  child: Text(
                    _isRunning ? "Pausar" : "Iniciar",
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            if (_isPaused)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: naranja,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50)),
                      ),
                      onPressed: _startOrResumeTraining,
                      child: const Text("Reanudar",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50)),
                      ),
                      onPressed: _finishTraining,
                      child: const Text("Finalizar",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatItem(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black54)),
      ],
    );
  }
}
