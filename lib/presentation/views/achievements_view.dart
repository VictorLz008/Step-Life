import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AchievementsView extends StatefulWidget {
  const AchievementsView({super.key});

  @override
  State<AchievementsView> createState() => _AchievementsViewState();
}

class _AchievementsViewState extends State<AchievementsView> {
  final Color naranja = const Color(0xFFFF6B00);
  final Color grisFondo = const Color(0xFFF4F4F4);
  final Color grisBarra = const Color(0xFF303030);
  final Color textoNegro = const Color(0xFF1E1E1E);

  double totalKm = 0;
  int totalEntrenamientos = 0;
  int totalCalorias = 0;
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarEstadisticas();
  }

  Future<void> _cargarEstadisticas() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final query = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("trainings")
        .get();

    double km = 0;
    int calorias = 0;

    for (var doc in query.docs) {
      final data = doc.data();

      final distancia = (data["distancia"] ?? 0);
      final caloriasData = (data["calorias"] ?? 0);

      // 🔹 Conversión segura sin errores
      km += distancia is num
          ? distancia.toDouble()
          : double.tryParse(distancia.toString()) ?? 0.0;

      calorias += caloriasData is num
          ? caloriasData.round()
          : int.tryParse(caloriasData.toString()) ?? 0;
    }

    setState(() {
      totalEntrenamientos = query.docs.length;
      totalKm = km;
      totalCalorias = calorias;
      cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: grisFondo,
      appBar: AppBar(
        backgroundColor: grisBarra,
        title: const Text(
          "Logros",
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
                  // 🔸 Estadísticas principales
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatBox(
                          label: "Entrenamientos",
                          value: "$totalEntrenamientos",
                          color: naranja,
                        ),
                        _StatBox(
                          label: "Distancia total",
                          value: "${totalKm.toStringAsFixed(2)} km",
                          color: naranja,
                        ),
                        _StatBox(
                          label: "Calorías",
                          value: "$totalCalorias kcal",
                          color: naranja,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  const Text(
                    "Tus logros 🏆",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 🔹 Lista de logros (estáticos por ahora)
                  _buildAchievement(
                    icon: Icons.flag,
                    title: "Primer entrenamiento",
                    description: "Completaste tu primer entrenamiento",
                    unlocked: totalEntrenamientos >= 1,
                  ),
                  _buildAchievement(
                    icon: Icons.directions_run,
                    title: "5 km acumulados",
                    description: "Has recorrido más de 5 km en total",
                    unlocked: totalKm >= 5,
                  ),
                  _buildAchievement(
                    icon: Icons.local_fire_department,
                    title: "1,000 calorías quemadas",
                    description: "Has quemado más de 1,000 calorías",
                    unlocked: totalCalorias >= 1000,
                  ),
                  _buildAchievement(
                    icon: Icons.star,
                    title: "10 entrenamientos",
                    description: "Completaste 10 sesiones",
                    unlocked: totalEntrenamientos >= 10,
                  ),
                  _buildAchievement(
                    icon: Icons.bolt,
                    title: "20 km acumulados",
                    description: "Has recorrido más de 20 km",
                    unlocked: totalKm >= 20,
                  ),
                  _buildAchievement(
                    icon: Icons.favorite,
                    title: "2000 calorías quemadas",
                    description: "¡Tu constancia se nota!",
                    unlocked: totalCalorias >= 2000,
                  ),
                ],
              ),
            ),
    );
  }

  // ---- Widget individual para logros ----
  Widget _buildAchievement({
    required IconData icon,
    required String title,
    required String description,
    required bool unlocked,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: unlocked ? Colors.white : Colors.grey[300],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked ? naranja : Colors.grey.shade400,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: unlocked ? naranja : Colors.grey,
            size: 36,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: unlocked ? Colors.black87 : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: unlocked ? Colors.black54 : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Icon(
            unlocked ? Icons.check_circle : Icons.lock,
            color: unlocked ? naranja : Colors.grey,
            size: 30,
          ),
        ],
      ),
    );
  }
}

// ---- Caja para estadísticas principales ----
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
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}
