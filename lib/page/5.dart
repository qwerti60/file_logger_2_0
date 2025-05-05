import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/material.dart';

Future getLogFiles() async {
  // Получаем директорию приложения
  final Directory appDir = await getApplicationDocumentsDirectory();

  // Путь к папке logs
  final String logsPath = '${appDir.path}/logs';
  final Directory logsDir = Directory(logsPath);

  // Проверяем существует ли директория
  if (await logsDir.exists()) {
    // Получаем список файлов
    List files = await logsDir.list().toList();

    // Возвращаем только имена файлов
    return files.whereType().map((file) => file.path.split('/').last).toList();
  }

  return [];
}

class LogFilesWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: getLogFiles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        }

        if (snapshot.hasError) {
          return Text('Ошибка: ${snapshot.error}');
        }

        final files = snapshot.data ?? [];

        return ListView.builder(
          itemCount: files.length,
          itemBuilder: (context, index) {
            return ListTile(title: Text(files[index]));
          },
        );
      },
    );
  }
}
