import 'package:file_logger20/page/login.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    startVerification(); // Начинаем проверку в фоне
  }

  Future<void> startVerification() async {
    setState(() {
      _loading = true; // Включаем режим загрузки
    });

    // Производим проверку в фоне
    final granted = await verifyStorageAccess();

    // Переход на новую страницу после окончания проверки
    if (granted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => LoginPage()));
    } else {
      showErrorDialog(context);
    }

    setState(() {
      _loading = false; // Завершаем загрузку
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_download_outlined, size: 100),
                Padding(padding: EdgeInsets.all(16)),
                Text(_loading ? "Загрузка..." : ""),
              ],
            ),
          ),
          if (_loading)
            LinearProgressIndicator(value: null), // Показываем прогресс бар
        ],
      ),
    );
  }
}

// Функция для проверки текущих разрешений
Future<bool> verifyStorageAccess() async {
  var status = await Permission.storage.status;
  if (status.isDenied || status.isPermanentlyDenied) {
    final result = await Permission.storage.request();
    return result.isGranted;
  }
  return true;
}

// Функция для отображения диалога с просьбой о разрешении
void showErrorDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder:
        (context) => AlertDialog(
          title: Text("Необходимо разрешение"),
          content: Text(
            "Приложение требует доступ к файлам для дальнейшей работы.",
          ),
          actions: [
            TextButton(
              child: Text("Предоставить доступ"),
              onPressed: () async {
                final result = await Permission.storage.request();
                if (result.isGranted) {
                  Navigator.of(context).pop(); // Закрываем диалог
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => LoginPage()),
                  );
                } else {
                  showErrorDialog(context); // Повторяем запрос, если отказали
                }
              },
            ),
          ],
        ),
  );
}
