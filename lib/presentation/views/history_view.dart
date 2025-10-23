import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_2/presentation/views/training_detail_view.dart';

class HistoryView extends StatelessWidget {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final Color naranja = const Color(0xFFFF6B00);
    final Color grisFondo = const Color(0xFFF4F4F4);
    final Color grisBarra = const Color(0xFF303030);
    final Color textoNegro = const Color(0xFF1E1E1E);

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("⚠️ No hay usuario logueado")),
      );
    }

    return Scaffold(
      backgroundColor: grisFondo,
      appBar: AppBar(
        backgroundColor: grisBarra,
        title: const Text("Historial de Entrenamientos",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
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
                child: Text("Aún no tienes entrenamientos guardados 🏃‍♂️"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final fecha = (data["fecha"] as Timestamp).toDate();

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TrainingDetailView(
                        fecha: fecha,
                        distancia: (data["distancia"] ?? 0).toDouble(),
                        tiempo: data["tiempo"] ?? "",
                        calorias: (data["calorias"] ?? 0).toInt(),
                        ruta: data["ruta"], // 👈 enviamos la ruta
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 3))
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 60,
                        width: 60,
                        decoration: BoxDecoration(
                          color: naranja.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child:
                            Icon(Icons.directions_run, color: naranja, size: 34),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${fecha.day}/${fecha.month}/${fecha.year}",
                              style: TextStyle(
                                  color: textoNegro,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Distancia: ${data["distancia"]} km",
                              style: TextStyle(
                                  color: textoNegro.withOpacity(0.8),
                                  fontSize: 15),
                            ),
                            Text(
                              "Tiempo: ${data["tiempo"]} | ${data["calorias"]} kcal",
                              style: TextStyle(
                                  color: textoNegro.withOpacity(0.6),
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: Colors.black38, size: 28),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
