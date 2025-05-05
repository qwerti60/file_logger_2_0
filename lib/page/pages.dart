import 'package:file_logger20/page/2.dart';
import 'package:file_logger20/page/3.dart' show MyApp;
import 'package:file_logger20/page/4.dart';
import 'package:file_logger20/page/csv_load.dart';
import 'package:file_logger20/page/logs.dart';
import 'package:file_logger20/page/monitoring.dart';
import 'package:file_logger20/page/setting.dart';
import 'package:flutter/material.dart';

import '../design/colors.dart';

void main() {
  runApp(const PagesScreen());
}

class PagesScreen extends StatelessWidget {
  const PagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: MyCustomScreen());
  }
}

// Преобразуем StatelessWidget в StatefulWidget
class MyCustomScreen extends StatefulWidget {
  const MyCustomScreen({super.key});

  @override
  _MyCustomScreenState createState() => _MyCustomScreenState();
}

class _MyCustomScreenState extends State {
  int _currentPage = 0; // Допустимо для StatefulWidget
  Widget _getScreen() {
    switch (_currentPage) {
      case 0:
        // Вместо возвращения MyApp, возможно, вы захотите показать другой стартовый экран
        return const MonitoringPage(); // мониторинг
      case 1:
        //  return MyAppf(); // логи
        return const LogsPage(); // логи
      case 2:
        return const SettingPage(); // логи
      //case 3:
      //  return MyWidget(); // наастройки
      //       return LogViewerScreen(); // наастройки
      default:
        return MyApp(); // мониторинг
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: <Widget>[Expanded(child: _getScreen())]),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Color(0xFF1C437E), // Установка фона
        items: [
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/finance.png',
              width: 24,
              height: 24,
            ), // Установка кастомной картинки
            label: 'Мониторинг',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/news.png',
              width: 17,
              height: 17,
            ), // Установка кастомной картинки
            label: 'Логи',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/settings.png',
              width: 24,
              height: 24,
            ), // Установка кастомной картинки
            label: 'Настройки',
          ),
          /*BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/settings.png',
              width: 24,
              height: 24,
            ), // Установка кастомной картинки
            label: 'TEST',
          ),*/
        ],
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentPage,
        selectedItemColor:
            Colors.white, // Цвет для иконки и текста выбранного элемента
        unselectedItemColor: Colors.white.withOpacity(
          0.6,
        ), // Цвет для иконки и текста невыбранного элемента
        selectedLabelStyle: TextStyle(
          color: Colors.white,
        ), // Стиль для текста выбранного элемента
        unselectedLabelStyle: TextStyle(
          color: Colors.white.withOpacity(0.6),
        ), // Стиль для текста невыбранного элемента
        onTap: (int intIndex) {
          setState(() {
            _currentPage = intIndex;
          });
        },
      ),
    );
  }
}
