import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final Color naranja = const Color(0xFFFF6B00);
  final Color grisFondo = const Color(0xFFF4F4F4);
  final Color grisBarra = const Color(0xFF303030);

  User? user;
  String nombre = "";
  String correo = "";
  String foto = "";
  int entrenamientos = 0;
  double totalKm = 0;
  int totalCalorias = 0;
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

  /// 🔹 Cargar datos del usuario y sus estadísticas
  Future<void> _cargarDatosUsuario() async {
    user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docUser =
        await FirebaseFirestore.instance.collection("users").doc(user!.uid).get();

    setState(() {
      correo = user!.email ?? "Sin correo";
      foto = user!.photoURL ??
          "https://cdn-icons-png.flaticon.com/512/149/149071.png";

      if (docUser.exists && docUser.data()!.containsKey("nombre")) {
        nombre = docUser["nombre"];
      } else if (user!.displayName != null && user!.displayName!.isNotEmpty) {
        nombre = user!.displayName!;
      } else {
        final base = correo.split("@").first;
        nombre = base.isNotEmpty
            ? base[0].toUpperCase() + base.substring(1)
            : "Usuario";
      }
    });

    final query = await FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .collection("trainings")
        .get();

    double km = 0;
    int cal = 0;

    for (var doc in query.docs) {
      final data = doc.data();

      final distancia = (data["distancia"] ?? 0);
      final calorias = (data["calorias"] ?? 0);

      km += distancia is num
          ? distancia.toDouble()
          : double.tryParse(distancia.toString()) ?? 0.0;

      cal += calorias is num
          ? calorias.round()
          : int.tryParse(calorias.toString()) ?? 0;
    }

    setState(() {
      entrenamientos = query.docs.length;
      totalKm = km;
      totalCalorias = cal;
      cargando = false;
    });
  }

  /// 🔒 Cerrar sesión
  Future<void> _cerrarSesion() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  /// ❌ Eliminar cuenta
  Future<void> _eliminarCuenta() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1️⃣ Eliminar datos de Firestore
      await FirebaseFirestore.instance.collection("users").doc(user.uid).delete();

      // 2️⃣ Eliminar usuario de Firebase Auth
      await user.delete();

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Debes volver a iniciar sesión antes de eliminar tu cuenta.",
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al eliminar cuenta: ${e.message}")),
        );
      }
    }
  }

  /// 🧾 Confirmación antes de eliminar cuenta
  void _mostrarConfirmacionEliminarCuenta() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Eliminar cuenta",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        content: const Text(
          "¿Estás seguro de que deseas eliminar tu cuenta? Esta acción no se puede deshacer.",
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancelar",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _eliminarCuenta();
            },
            child: const Text(
              "Eliminar",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// 🔐 Confirmación antes de cerrar sesión
  void _mostrarConfirmacionCerrarSesion() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Cerrar sesión",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        content: const Text(
          "¿Deseas cerrar tu sesión actual?",
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancelar",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFF6B00),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _cerrarSesion();
            },
            child: const Text(
              "Cerrar sesión",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: grisFondo,
      appBar: AppBar(
        backgroundColor: grisBarra,
        title: const Text(
          "Perfil",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 🧍 Foto
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: NetworkImage(foto),
                    backgroundColor: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    nombre,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    correo,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 25),

                  // 📊 Estadísticas
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [naranja, Colors.deepOrangeAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        )
                      ],
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statItem("Entrenamientos", "$entrenamientos"),
                        _statItem(
                            "Distancia", "${totalKm.toStringAsFixed(1)} km"),
                        _statItem("Calorías", "$totalCalorias kcal"),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ⚙️ Opciones disponibles
                  _optionTile(Icons.logout, "Cerrar sesión",
                      _mostrarConfirmacionCerrarSesion),
                  _optionTile(Icons.delete_forever, "Eliminar cuenta",
                      _mostrarConfirmacionEliminarCuenta),
                ],
              ),
            ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _optionTile(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 3))
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: naranja, size: 28),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
