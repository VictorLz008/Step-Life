import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class StatsView extends StatefulWidget {
  const StatsView({super.key});

  @override
  State<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends State<StatsView> {
  final Color naranja = const Color(0xFFFF6B00);
  final Color grisFondo = const Color(0xFFF4F4F4);
  final Color grisBarra = const Color(0xFF303030);

  bool cargando = true;
  List<Map<String, dynamic>> entrenamientos = [];
  Map<String, double> semanaKm = {};
  Map<String, double> mesKm = {};
  double totalKm = 0;
  double totalCal = 0;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_MX', null).then((_) => _cargarDatos());
  }

  Future<void> _cargarDatos() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final query = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("trainings")
        .orderBy("fecha", descending: false)
        .get();

    entrenamientos = query.docs.map((doc) {
      final data = doc.data();
      return {
        "fecha": (data["fecha"] as Timestamp).toDate(),
        "distancia": (data["distancia"] ?? 0).toDouble(),
        "calorias": (data["calorias"] ?? 0).toDouble(),
      };
    }).toList();

    _procesarDatos();
    setState(() => cargando = false);
  }

  void _procesarDatos() {
    final now = DateTime.now();
    totalKm = 0;
    totalCal = 0;

    for (var e in entrenamientos) {
      totalKm += e["distancia"];
      totalCal += e["calorias"];
    }

    // 📅 Datos semanales
    semanaKm.clear();
    for (int i = 0; i < 7; i++) {
      final dia = now.subtract(Duration(days: 6 - i));
      final label =
          DateFormat.E('es_MX').format(dia).substring(0, 2).toUpperCase();
      final totalDia = entrenamientos
          .where((e) =>
              e["fecha"].year == dia.year &&
              e["fecha"].month == dia.month &&
              e["fecha"].day == dia.day)
          .fold<double>(0, (sum, e) => sum + (e["distancia"] ?? 0));
      semanaKm[label] = totalDia;
    }

    // 📆 Datos mensuales (6 meses sin duplicados)
    mesKm.clear();
    for (int i = 5; i >= 0; i--) {
      final mes = DateTime(now.year, now.month - i, 1);
      final label = DateFormat('MMM', 'es_MX')
          .format(mes)
          .replaceAll('.', '')
          .toUpperCase();
      final totalMes = entrenamientos
          .where((e) =>
              e["fecha"].year == mes.year && e["fecha"].month == mes.month)
          .fold<double>(0, (sum, e) => sum + (e["distancia"] ?? 0));
      mesKm[label] = totalMes;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: grisFondo,
      appBar: AppBar(
        backgroundColor: grisBarra,
        title: const Text(
          "Estadísticas",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCard(),
                  const SizedBox(height: 30),
                  const Text(
                    "Actividad de la semana 📅",
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  _buildWeeklyChart(),
                  const SizedBox(height: 40),
                  const Text(
                    "Progreso mensual 📈",
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  _buildMonthlyChart(),
                ],
              ),
            ),
    );
  }

  // 🔸 Tarjeta resumen superior
  Widget _buildSummaryCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [naranja.withOpacity(0.9), Colors.deepOrange.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem(Icons.directions_run, "Distancia total",
              "${totalKm.toStringAsFixed(1)} km"),
          _summaryItem(Icons.local_fire_department, "Calorías",
              "${totalCal.round()} kcal"),
          _summaryItem(Icons.calendar_today, "Sesiones",
              "${entrenamientos.length}"),
        ],
      ),
    );
  }

  Widget _summaryItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 32),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }

  // 📊 Gráfico semanal
  Widget _buildWeeklyChart() {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
        ],
      ),
      child: BarChart(
        BarChartData(
          maxY: (semanaKm.values.isNotEmpty
                  ? semanaKm.values.reduce((a, b) => a > b ? a : b)
                  : 1) *
              1.3,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: naranja.withOpacity(0.85),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  "${semanaKm.keys.elementAt(group.x)}\n${rod.toY.toStringAsFixed(2)} km",
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1, // fuerza 1 etiqueta por valor
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < semanaKm.keys.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        semanaKm.keys.elementAt(index),
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          barGroups: List.generate(semanaKm.length, (i) {
            final y = semanaKm.values.elementAt(i);
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: y,
                  gradient: LinearGradient(
                    colors: [naranja, Colors.deepOrangeAccent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  width: 16,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // 📈 Gráfico mensual con una etiqueta por mes
  Widget _buildMonthlyChart() {
    final promedioMes =
        mesKm.isEmpty ? 0 : mesKm.values.reduce((a, b) => a + b) / mesKm.length;

    return Container(
      height: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              "Promedio mensual: ${promedioMes.toStringAsFixed(1)} km",
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700]),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (mesKm.length - 1).toDouble(),
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1, // 👈 fuerza solo una etiqueta por mes
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < mesKm.keys.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              mesKm.keys.elementAt(index),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: naranja,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          naranja.withOpacity(0.3),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    spots: List.generate(
                      mesKm.length,
                      (i) => FlSpot(
                        i.toDouble(),
                        mesKm.values.elementAt(i),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
