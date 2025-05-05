import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // Для работы с json
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: FileListScreen());
  }
}

class FileListScreen extends StatefulWidget {
  @override
  _FileListScreenState createState() => _FileListScreenState();
}

class _FileListScreenState extends State {
  List files = []; // Список имен файлов

  @override
  void initState() {
    super.initState();
    _loadFileList();
  }

  Future _loadFileList() async {
    final response = await http.get(Uri.parse('http://yourserver.com/files'));
    if (response.statusCode == 200) {
      final List fileNames = jsonDecode(response.body);
      setState(() {
        files = fileNames.cast();
      });
    } else {
      // Обработка ошибки
    }
  }

  Future _downloadAndOpenFile(String fileName) async {
    final url = 'http://yourserver.com/files/$fileName'; // URL файла
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final bytes = response.bodyBytes;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');

      await file.writeAsBytes(bytes); // Сохраняем файл локально
      OpenFile.open(file.path); // Открываем файл
    } else {
      // Обработка ошибки
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Список файлов')),
      body: ListView.builder(
        itemCount: files.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(files[index]),
            onTap: () => _downloadAndOpenFile(files[index]),
          );
        },
      ),
    );
  }
}
