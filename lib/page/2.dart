import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(MyAppf());

class MyAppf extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State {
  static const platform = MethodChannel('samples.flutter.dev/ftp');
  List _files = [];

  Future _getFtpFileList() async {
    try {
      final List result = await platform.invokeMethod('getFtpFileList');
      setState(() {
        _files = result;
      });
    } on PlatformException catch (e) {
      print("Ошибка при получении списка файлов: '${e.message}'.");
    }
  }

  Future<String?> downloadAndOpenFile(String filename) async {
    try {
      debugPrint("Начинаем загрузку файла: $filename");
      Directory directory =
          await getApplicationDocumentsDirectory(); // Приватная директория приложения
      String docPath =
          "${directory.path}/$filename"; // Формирование полного пути к файлу
      debugPrint("Формированный путь к файлу: $docPath");

      bool? downloadedSuccessfully = await platform.invokeMethod<bool>(
        'downloadAndOpenFile',
        {
          'fileName': filename,
          'savePath': docPath,
        }, // Обязательно передаем оба параметра
      );

      if (downloadedSuccessfully == true) {
        await OpenFile.open(docPath); // Открытие файла после успешной загрузки
        debugPrint("Файл успешно загружен и открыт: $docPath");
        return docPath; // Вернем путь к файлу, если всё прошло хорошо
      } else {
        debugPrint("Ошибка при загрузке файла.");
        return null; // Или вернуть другое значение, показывающее неудачу
      }
    } on PlatformException catch (e) {
      debugPrint("Ошибка при загрузке или открытии файла: ${e.message}");
      return null; // Либо вернуть особое значение ошибки
    }
  }

  Future<void> _openFile(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Не могу открыть файл $url';
    }
  }

  // Метод обновления интерфейса
  Future<void> refreshFiles() async {
    await _getFtpFileList();
  }

  void handleFileTap(int index) async {
    var pathToFile = await downloadAndOpenFile(_files[index]);
    if (pathToFile != null && pathToFile is String) {
      await _openFile(pathToFile);
    } else {
      debugPrint("Ошибка: некорректный путь к файлу ($pathToFile)");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Файлы FTP')),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _files.length,
                itemBuilder:
                    (context, index) => ListTile(
                      title: Text(_files[index]),
                      onTap:
                          () => handleFileTap(
                            index,
                          ), // Предполагается, что вы напишете эту функцию
                    ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(3)),
                    side: BorderSide(color: Colors.grey, width: 1),
                  ),
                ),
                onPressed: () {
                  // Действие при нажатии кнопки "Очистить логи"
                },
                child: const Text('Очистить логи'),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(3)),
                    side: BorderSide(color: Colors.grey, width: 1),
                  ),
                ),
                onPressed: () {
                  refreshFiles();
                },

                child: const Text('Загрузить логи c файла'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
