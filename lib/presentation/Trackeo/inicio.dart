import 'dart:async';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:xml/xml.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  GoogleMapController? _mapController;
  final Set<Polyline> _polylines = {};
  final List<LatLng> _route = [];
  final List<Marker> _markers = [];
  List<LatLng> _mockPoints = [];

  Timer? _timer;
  int _currentIndex = 0;
  DateTime? _startTime;

  // 🔄 Por defecto usamos GPS real
  bool _useRealGPS = true;
  StreamSubscription<Position>? _gpsStream;

  /// 👉 Leer archivo GPX
  Future<void> _loadGpxRoute() async {
    final gpxString =
        await rootBundle.loadString('assets/estadio_loreto.gpx');
    final gpx = XmlDocument.parse(gpxString);

    final points = gpx.findAllElements('trkpt').map((node) {
      final lat = double.parse(node.getAttribute('lat')!);
      final lon = double.parse(node.getAttribute('lon')!);
      return LatLng(lat, lon);
    }).toList();

    setState(() {
      _mockPoints = points;
    });

    if (_mockPoints.isNotEmpty) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_mockPoints.first, 14),
      );

      _markers.add(Marker(
        markerId: const MarkerId("posicion"),
        position: _mockPoints.first,
        infoWindow: const InfoWindow(title: "Inicio (GPX)"),
      ));
    }
  }

  /// 👉 Fórmula de Haversine (km)
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

  /// 👉 Simulación GPX
  void _startMockRoute() {
    if (_mockPoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Ruta GPX no cargada")),
      );
      return;
    }

    _route.clear();
    _currentIndex = 0;
    _timer?.cancel();
    _startTime = DateTime.now();

    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_currentIndex < _mockPoints.length) {
        setState(() {
          final current = _mockPoints[_currentIndex];
          _route.add(current);
          _updatePolylineAndMarker(current, Colors.red);
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLng(_mockPoints[_currentIndex]),
        );

        _currentIndex++;
      } else {
        _finishTraining();
      }
    });
  }

  /// 👉 GPS real
  Future<void> _enableRealGPS() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Activa el GPS para continuar")),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    _route.clear();
    _startTime = DateTime.now();

    _gpsStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position pos) {
      final current = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _route.add(current);
        _updatePolylineAndMarker(current, Colors.blue);
      });

      _mapController?.animateCamera(CameraUpdate.newLatLng(current));
    });
  }

  /// 👉 Actualizar polyline + marcador
  void _updatePolylineAndMarker(LatLng current, Color color) {
    _polylines.clear();
    _polylines.add(Polyline(
      polylineId: const PolylineId("route"),
      points: _route,
      color: color,
      width: 5,
    ));

    _markers.clear();
    _markers.add(Marker(
      markerId: const MarkerId("posicion"),
      position: current,
      infoWindow: const InfoWindow(title: "Posición actual"),
    ));
  }

  /// 👉 Guardar en Firestore
  Future<void> _saveTrainingToFirestore(
      double distancia, String tiempo, int calorias) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final training = {
      "distancia": distancia,
      "tiempo": tiempo,
      "calorias": calorias,
      "fecha": DateTime.now(),
    };

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("trainings")
        .add(training);
  }

  /// 👉 Finalizar entrenamiento
  void _finishTraining() {
    _timer?.cancel();
    _gpsStream?.cancel();

    if (_startTime == null || _route.isEmpty) return;

    final duration = DateTime.now().difference(_startTime!);

    double totalKm = 0;
    for (int i = 0; i < _route.length - 1; i++) {
      totalKm += _calculateDistance(_route[i], _route[i + 1]);
    }

    final calorias = (totalKm * 70).round();

    _saveTrainingToFirestore(
      double.parse(totalKm.toStringAsFixed(2)),
      "${duration.inMinutes} min ${duration.inSeconds % 60} seg",
      calorias,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "🏁 Entrenamiento finalizado\n"
          "Distancia: ${totalKm.toStringAsFixed(2)} km\n"
          "Tiempo: ${duration.inMinutes} min ${duration.inSeconds % 60} seg\n"
          "Calorías: $calorias kcal",
        ),
      ),
    );
  }

  void _stopRoute() {
    _finishTraining();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _gpsStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Entrenamiento"),
        actions: [
          Row(
            children: [
              const Text("GPX"),
              Switch(
                value: _useRealGPS,
                onChanged: (val) {
                  setState(() {
                    _useRealGPS = val;
                  });
                },
              ),
              const Text("GPS"),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              onMapCreated: (controller) {
                _mapController = controller;
                if (!_useRealGPS) _loadGpxRoute();
              },
              initialCameraPosition: const CameraPosition(
                target: LatLng(19.0668, -98.1887),
                zoom: 14,
              ),
              polylines: _polylines,
              markers: Set.from(_markers),
              myLocationEnabled: _useRealGPS,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () =>
                      _useRealGPS ? _enableRealGPS() : _startMockRoute(),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text("Iniciar"),
                ),
                ElevatedButton.icon(
                  onPressed: _stopRoute,
                  icon: const Icon(Icons.stop),
                  label: const Text("Detener"),
                ),
              ],
            ),
          ),
          Expanded(
            child: user == null
                ? const Center(child: Text("⚠️ No hay usuario logueado"))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("users")
                        .doc(user.uid)
                        .collection("trainings")
                        .orderBy("fecha", descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) {
                        return const Center(
                          child: Text("No tienes entrenamientos guardados aún."),
                        );
                      }

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data =
                              docs[index].data() as Map<String, dynamic>;
                          final fecha = (data["fecha"] as Timestamp).toDate();

                          return ListTile(
                            leading: const Icon(Icons.directions_run),
                            title: Text("Distancia: ${data["distancia"]} km"),
                            subtitle: Text(
                                "Tiempo: ${data["tiempo"]} | Calorías: ${data["calorias"]} kcal"),
                            trailing: Text(
                              "${fecha.day}/${fecha.month}/${fecha.year}",
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
