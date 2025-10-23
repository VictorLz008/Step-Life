import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TrainingDetailView extends StatefulWidget {
  final DateTime fecha;
  final double distancia;
  final String tiempo;
  final int calorias;
  final List<dynamic>? ruta;

  const TrainingDetailView({
    super.key,
    required this.fecha,
    required this.distancia,
    required this.tiempo,
    required this.calorias,
    this.ruta,
  });

  @override
  State<TrainingDetailView> createState() => _TrainingDetailViewState();
}

class _TrainingDetailViewState extends State<TrainingDetailView> {
  GoogleMapController? _mapController;

  // Paleta
  final Color naranja = const Color(0xFFFF6B00);
  final Color grisBarra = const Color(0xFF303030);
  final Color grisFondo = const Color(0xFFF4F4F4);
  final Color textoNegro = const Color(0xFF1E1E1E);

  final Set<Polyline> _polylines = {};
  final List<Marker> _markers = [];

  @override
  void initState() {
    super.initState();
    _prepareRoute();
  }

  // ---- Helpers seguros ------------------------------------------------------

  double _toDouble(dynamic v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  LatLng _latLngFrom(dynamic e) {
    final lat = _toDouble((e is Map) ? e["lat"] : null);
    final lng = _toDouble((e is Map) ? e["lng"] : null);
    return LatLng(lat, lng);
  }

  // ---- Carga y dibujo de ruta ----------------------------------------------

  void _prepareRoute() {
    if (widget.ruta == null || widget.ruta!.isEmpty) return;

    final puntos = widget.ruta!.map(_latLngFrom).toList();

    _polylines.add(Polyline(
      polylineId: const PolylineId("recorrido"),
      color: naranja,
      width: 6,
      points: puntos,
    ));

    _markers.add(Marker(
      markerId: const MarkerId("inicio"),
      position: puntos.first,
      infoWindow: const InfoWindow(title: "Inicio"),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    ));

    _markers.add(Marker(
      markerId: const MarkerId("fin"),
      position: puntos.last,
      infoWindow: const InfoWindow(title: "Fin"),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasRoute = widget.ruta != null && widget.ruta!.isNotEmpty;
    final LatLng initialTarget = hasRoute
        ? _latLngFrom(widget.ruta!.first)
        : const LatLng(19.0668, -98.1887);

    return Scaffold(
      backgroundColor: grisFondo,
      appBar: AppBar(
        backgroundColor: grisBarra,
        title: const Text(
          "Detalle del entrenamiento",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              "${widget.fecha.day}/${widget.fecha.month}/${widget.fecha.year}",
              style: TextStyle(
                fontSize: 22,
                color: textoNegro,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatBox(
                  label: "Distancia",
                  value: "${widget.distancia} km",
                  color: naranja,
                ),
                _StatBox(
                  label: "Tiempo",
                  value: widget.tiempo,
                  color: naranja,
                ),
                _StatBox(
                  label: "Calorías",
                  value: "${widget.calorias} kcal",
                  color: naranja,
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Mapa
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  color: Colors.grey[300],
                  child: !hasRoute
                      ? Center(
                          child: Text(
                            "No hay recorrido guardado 📍",
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        )
                      : GoogleMap(
                          onMapCreated: (controller) async {
                            _mapController = controller;

                            // Calcula bounds y hace zoom automático
                            final puntos =
                                widget.ruta!.map(_latLngFrom).toList();

                            // Evita fallos si la lista solo tiene un punto
                            if (puntos.length == 1) {
                              await _mapController!.animateCamera(
                                CameraUpdate.newCameraPosition(
                                  CameraPosition(
                                    target: puntos.first,
                                    zoom: 16.0, // double
                                  ),
                                ),
                              );
                            } else {
                              await _mapController!.animateCamera(
                                CameraUpdate.newLatLngBounds(
                                  _calculateBounds(puntos),
                                  50.0, // padding como double
                                ),
                              );
                            }
                          },
                          polylines: _polylines,
                          markers: Set.from(_markers),
                          initialCameraPosition: CameraPosition(
                            target: initialTarget,
                            zoom: 15.0, // double
                          ),
                          zoomControlsEnabled: false,
                          myLocationButtonEnabled: false,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Calcula límites del mapa para hacer zoom a toda la ruta
  LatLngBounds _calculateBounds(List<LatLng> puntos) {
    double minLat = puntos.first.latitude;
    double maxLat = puntos.first.latitude;
    double minLng = puntos.first.longitude;
    double maxLng = puntos.first.longitude;

    for (final p in puntos.skip(1)) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}

// Tarjeta de estadísticas
class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          " ",
          style: TextStyle(fontSize: 1), // micro espaciado
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}
