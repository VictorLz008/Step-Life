import 'package:flutter/material.dart';
import 'package:flutter_application_2/presentation/Trackeo/inicio.dart';
import 'package:flutter_application_2/presentation/views/stats_view.dart';
import 'package:flutter_application_2/presentation/views/history_view.dart';
import 'package:flutter_application_2/presentation/views/profile_view.dart';
import 'package:flutter_application_2/presentation/views/achievements_view.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  int _selectedIndex = 0;

  final List<Widget> _views = const [
    InicioScreen(), // Tu pantalla original del mapa
    StatsView(),
    HistoryView(),
    ProfileView(),
    AchievementsView(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _views[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events_outlined), label: ''),
        ],
      ),
    );
  }
}
