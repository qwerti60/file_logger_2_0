import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:csv/csv.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

// Запрос разрешений
Future<void> requestStoragePermission() async {
  if (await Permission.storage.request().isGranted) {
    // Разрешения получены
  } else {
    // Разрешения не получены
  }
}

class LogViewerScreen extends StatefulWidget {
  @override
  _LogViewerScreenState createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State {
  List _logData = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _printLogsInfo(); // Печать информации при инициализации
  }

  Future _printLogsInfo() async {
    print('=== Logs Information ===');
    final directory = await getApplicationDocumentsDirectory();
    final logsPath = '${directory.path}/logs';
    print('Logs directory path: $logsPath');

    try {
      final logsDir = Directory(logsPath);
      if (await logsDir.exists()) {
        print('Logs directory exists');
        int fileCount = 0;
        await for (final entity in logsDir.list()) {
          if (entity is File && entity.path.endsWith('.csv')) {
            fileCount++;
            final fileStats = await entity.stat();
            print('Found log file: ${entity.path}');
            print('File size: ${fileStats.size} bytes');
            print('Last modified: ${fileStats.modified}');
          }
        }
        print('Total CSV files found: $fileCount');
      } else {
        print('Logs directory does not exist');
      }
    } catch (e) {
      print('Error while checking logs directory: $e');
    }
    print('=====================');
  }

  Future get _logsPath async {
    // Получаем доступ к внешнему хранилищу
    final externalDir = await getExternalStorageDirectory();

    if (externalDir != null) {
      final path = p.join(externalDir.path, 'logs');

      // Создаем директорию, если её ещё нет
      //await Directory(logPath).create(recursive: true);

      print('Полученный путь к журналам: $path');
      return path;
    } else {
      throw Exception("Не удалось получить внешнее хранилище");
    }
  }

  Future _loadLogs() async {
    print('Starting to load logs...');
    setState(() {
      _isLoading = true;
      _logData = [];
    });

    try {
      final logsDir = Directory(await _logsPath);
      print('Checking if logs directory exists...');

      if (!await logsDir.exists()) {
        print('Logs directory does not exist');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      print('Processing log files...');
      await for (final file in logsDir.list()) {
        if (file.path.endsWith('.csv')) {
          print('Reading file: ${file.path}');
          final contents = await File(file.path).readAsString();
          print('File contents length: ${contents.length}');

          final rowsAsListOfValues = const CsvToListConverter().convert(
            contents,
          );
          print('Parsed ${rowsAsListOfValues.length} rows from CSV');

          setState(() {
            _logData.addAll(rowsAsListOfValues);
          });
        }
      }
      print('Finished loading logs. Total entries: ${_logData.length}');
    } catch (e) {
      print('Error loading logs: $e');
      print('Stack trace: ${StackTrace.current}');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка при загрузке логов: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future _clearLogs() async {
    print('Starting to clear logs...');
    try {
      final logsDir = Directory(await _logsPath);
      print('Checking if logs directory exists for clearing...');

      if (await logsDir.exists()) {
        print('Deleting logs directory...');
        await logsDir.delete(recursive: true);
        print('Logs directory successfully deleted');

        setState(() {
          _logData = [];
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Логи успешно удалены')));
      } else {
        print('Logs directory does not exist, nothing to clear');
      }
    } catch (e) {
      print('Error clearing logs: $e');
      print('Stack trace: ${StackTrace.current}');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка при удалении логов: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Просмотр логов'),
        actions: [
          IconButton(
            icon: Icon(Icons.info),
            onPressed: _printLogsInfo,
            tooltip: 'Показать информацию о логах',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _loadLogs,
                  child: Text('Загрузить логи с файла'),
                ),
                ElevatedButton(
                  onPressed: _clearLogs,
                  child: Text('Очистить логи'),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _logData.isEmpty
                    ? Center(child: Text('Нет доступных логов'))
                    : ListView.builder(
                      itemCount: _logData.length,
                      itemBuilder: (context, index) {
                        return Card(
                          margin: EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              _logData[index].join(', '),
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
