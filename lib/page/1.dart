import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Future<void> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      PlatformFile file = result.files.first;

      print(file.name);
      print(file.bytes);
      print(file.size);
      print(file.extension);
      print(file.path);

      // Отправка файла на сервер
      uploadFile1(file);
    } else {
      // Пользователь отменил выбор
    }
  }

  Future<void> uploadFile1(file) async {
    var uri = Uri.parse('http://app72.ru/upload/'); // URL для загрузки файла
    var request = http.MultipartRequest('POST', uri)
      ..files.add(
        await http.MultipartFile.fromPath(
          'file', // ключ, по которому сервер принимает файл
          file.path,
        ),
      );

    var response = await request.send();

    if (response.statusCode == 200) {
      print('Файл успешно загружен');
    } else {
      print('Ошибка при загрузке файла');
    }
  }

  Future<void> uploadFile(PlatformFile file) async {
    FTPConnect ftpConnect = FTPConnect(
      '31.31.198.54',
      user: 'u2395188',
      pass: 'U4i6OiMv67Uv4kfcdcfx7',
    );

    try {
      // Подключение
      await ftpConnect.connect();

      // Передача файла
      final fileToUpload = File(file.path!); // Убедитесь, что path не null
      final bool res = await ftpConnect.uploadFileWithRetry(
        fileToUpload,
        pRetryCount: 2, // Попытается загрузить файл 2 раза в случае неудачи
        pRemoteName: file.name,
      ); // Имя файла на сервере

      print('Upload result: $res');

      // Отключение
      await ftpConnect.disconnect();
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('FTP Upload Example')),
        body: Center(
          child: ElevatedButton(
            onPressed: pickFile,
            child: Text('Upload File'),
          ),
        ),
      ),
    );
  }
}
