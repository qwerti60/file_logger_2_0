import 'package:file_logger20/design/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:csv/csv.dart'; // Для парсинга CSV-файлов
import 'package:permission_handler/permission_handler.dart'; // Для разрешения хранения

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  _LogsPageState createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  late Color blackPrColor = Colors.black; // определение цвета для текста
  List<String> _files = []; // список имен файлов
  List<List<dynamic>> _logData = []; // данные логов
  bool _isLoading = false; // состояние загрузки логов

  @override
  void initState() {
    super.initState();
    _printLogsInfo(); // вывод информации о журналах
  }

  /// Метод печати информации о журнале
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

  /// Метод загрузки логов
  Future _loadLogs() async {
    print('Starting to load logs...');
    setState(() {
      _isLoading = true;
      _logData.clear();
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
          ); // Парсим содержимое
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

  /// Путь к директории с логами
  Future<String> get _logsPath async {
    final externalDir = await getExternalStorageDirectory();
    if (externalDir != null) {
      final path = p.join(externalDir.path, 'logs');
      print('Полученный путь к журналам: $path');
      return path;
    } else {
      throw Exception("Не удалось получить внешнее хранилище");
    }
  }

  /// Очистка всех логов
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
          _logData.clear();
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Логи успешно удалены')));
      }
    } catch (e) {
      print('Error clearing logs: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка при очистке логов: $e')));
    }
  }
  //bool _isLoading = false;

  /// Метод для подтверждения удаления логов
  Future<void> _confirmClearLogs() async {
    return await showDialog<void>(
      context: context,
      barrierDismissible: true, // Можно закрыть касанием вне окна
      builder: (context) {
        return AlertDialog(
          title: Text('Подтверждение'),
          content: Text('Вы действительно хотите очистить логи?'),
          actions: [
            TextButton(
              child: Text('Нет'),
              onPressed: () {
                Navigator.pop(context); // Закрыть диалог
              },
            ),
            TextButton(
              child: Text('Да'),
              onPressed: () {
                _clearLogs(); // Очищаем логи
                Navigator.pop(context); // Закрыть диалог
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Верхняя половина экрана с логами занимает всё оставшееся пространство
              Expanded(
                child:
                    _isLoading
                        ? Center(child: CircularProgressIndicator())
                        : _logData.isEmpty
                        ? Center(child: Text('Нет доступных логов'))
                        : ListView.builder(
                          itemCount: _logData.length,
                          itemBuilder: (context, index) {
                            final logItem = _logData[index];

                            // Добавляем разделитель только начиная со второго элемента
                            if (index > 0) {
                              return Column(
                                children: [
                                  Divider(
                                    indent: 20,
                                    endIndent: 20,
                                    color: Colors.black,
                                    thickness: 1,
                                  ),
                                  Container(
                                    padding: EdgeInsets.only(left: 20),
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      logItem.join(', '),
                                      style: TextStyle(
                                        color: blackprColor,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }

                            // Первый элемент без линии сверху
                            return Container(
                              padding: EdgeInsets.only(left: 20),
                              alignment: Alignment.centerLeft,
                              child: Text(
                                logItem.join(', '),
                                style: TextStyle(
                                  color: blackprColor,
                                  fontSize: 16,
                                ),
                              ),
                            );
                          },
                        ),
              ),

              // Нижняя часть экрана — кнопки располагаются внизу и занимают ровно столько пространства, сколько нужно
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                margin: const EdgeInsets.only(bottom: 20.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ButtonStyle(
                      minimumSize: MaterialStateProperty.all(
                        Size.fromHeight(50),
                      ),
                      foregroundColor: MaterialStateProperty.resolveWith((
                        states,
                      ) {
                        return states.contains(MaterialState.disabled)
                            ? Colors.grey
                            : Colors.black;
                      }),
                      backgroundColor: MaterialStateProperty.all(Colors.white),
                      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(3)),
                          side: BorderSide(color: Colors.grey, width: 1),
                        ),
                      ),
                    ),
                    onPressed: _isLoading ? null : _confirmClearLogs,
                    child: const Text('Очистить логи'),
                  ),
                ),
              ),

              // Вторая кнопка
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                margin: const EdgeInsets.only(bottom: 20.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ButtonStyle(
                      minimumSize: MaterialStateProperty.all(
                        Size.fromHeight(50),
                      ),
                      foregroundColor: MaterialStateProperty.resolveWith((
                        states,
                      ) {
                        return states.contains(MaterialState.disabled)
                            ? Colors.grey
                            : Colors.black;
                      }),
                      backgroundColor: MaterialStateProperty.all(Colors.white),
                      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(3)),
                          side: BorderSide(color: Colors.grey, width: 1),
                        ),
                      ),
                    ),
                    onPressed: _isLoading ? null : _loadLogs,
                    child: const Text('Загрузить логи с файла'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
