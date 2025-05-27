import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p; // Библиотека для работы с путями файлов
import 'package:file/local.dart'; // Для работы с файловой системой
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart'; // Или другой HTTP клиент
import 'dart:io';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) {
    // Это исполняемый код в фоновом режиме
    print("Native called background task: $task");
    return Future.value(true);
  });
}

class MonitoringPage extends StatefulWidget {
  const MonitoringPage({super.key});

  @override
  _MonitoringPageState createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage> {
  static const platform = MethodChannel('samples.flutter.dev/files');
  bool isBackgroundModeEnabled = false;
  bool _trackingEnabled = false;
  final ScrollController _scrollController = ScrollController();
  @override
  void initState() {
    super.initState();
    _loadDirectories();
    checkTrackingStatus(); // Проверка состояния трекинга при старте
  }

  Future<void> checkTrackingStatus() async {
    try {
      final bool result = await platform.invokeMethod('isTrackingEnabled');
      setState(() {
        _trackingEnabled = result;
      });
    } on PlatformException catch (e) {
      print("Failed to check tracking status: '${e.message}'.");
    }
  }

  Future<void> toggleTracking() async {
    try {
      final bool result = await platform.invokeMethod('toggleTracking');
      setState(() {
        _trackingEnabled = result;
      });
    } on PlatformException catch (e) {
      print("Failed to toggle tracking: '${e.message}'.");
    }
  }

  void toggleBackgroundMode() {
    if (isBackgroundModeEnabled) {
      // Отключение фоновых задач
      Workmanager().cancelAll();
      print('Background Task Disabled');
    } else {
      // Активирование фоновых задач
      Workmanager().registerOneOffTask("1", "simpleTask");
      print('Background Task Enabled');
    }
    /*
    setState(() {
      isBackgroundModeEnabled = !isBackgroundModeEnabled;
    });*/
  }

  Future<void> showSelectFoldersDialog() async {
    return await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Внимание'),
          content: Text('Выбери папки для слежения'),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // Закрываем диалог
              },
            ),
          ],
        );
      },
    );
  }

  List<String> directories = [];
  // Модифицируем _pickDirectory метод
  //List<String> directories = [];

  Future<void> _pickDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();

    if (result != null) {
      // Добавляем основную директорию, если её ещё нет
      if (!directories.contains(result)) {
        setState(() {
          directories.add(result);
        });

        try {
          final subDirectories = await _listAllSubdirectories(result);
          setState(() {
            // Используем Set для удаления дубликатов
            final uniqueDirectories = {...directories, ...subDirectories};
            directories = uniqueDirectories.toList();
          });

          // Сохраняем директории в локальный файл
          await _saveDirectories();

          print("Все директории успешно добавлены!");
          print(directories);

          // Ждём, пока дерево виджетов обновится, и только после этого производим скроллинг
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(
                _scrollController.position.maxScrollExtent,
              );
            }
          });
        } catch (e) {
          print(e.toString());
        }
      }
    }
  }

  // Функция для сохранения директорий
  Future<void> _saveDirectories() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/directories.json');

      // Преобразуем список директорий в JSON и сохраняем в файл
      await file.writeAsString(jsonEncode(directories));
    } catch (e) {
      print('Ошибка при сохранении директорий: $e');
    }
  }

  // Функция для загрузки директорий при запуске приложения
  Future<void> _loadDirectories() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/directories.json');
      print(file);
      if (await file.exists()) {
        final String contents = await file.readAsString();
        final List<dynamic> decodedDirectories = jsonDecode(contents);

        setState(() {
          directories = decodedDirectories.cast<String>().toList();
        });
      }

      // Добавляем небольшую задержку
      await Future.delayed(Duration(milliseconds: 2000));

      if (mounted) {
        Future.microtask(() {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        });
      }
    } catch (e) {
      print('Ошибка при загрузке директорий: $e');
    }
  }

  /// Рекурсивная функция для сбора всех подпапок
  Future<List<String>> _listAllSubdirectories(String directoryPath) async {
    final Directory dir = Directory(directoryPath);
    final allPaths = <String>[directoryPath];

    try {
      final entries = await dir.list(recursive: true).toList();
      for (final entry in entries) {
        if (entry is Directory) {
          allPaths.add(entry.path);
        }
      }
    } on Exception catch (_) {}

    return allPaths;
  }

  Future<void> fetchDirectories() async {
    try {
      // Получаем путь к директории приложения
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String appPath = appDir.path;

      // Получаем список всех файлов и директорий рекурсивно
      final Directory directory = Directory(appPath);
      List<FileSystemEntity> entities =
          await directory.list(recursive: true).toList();

      // Создаем Set для хранения уникальных путей
      Set<String> uniquePaths = {};

      // Обрабатываем каждую директорию
      for (var entity in entities) {
        if (entity is Directory) {
          String path = entity.path;

          // Нормализуем путь
          path = path.replaceAll(
            RegExp(r'/{2,}'),
            '/',
          ); // Удаляем двойные слеши
          path = path.replaceAll(
            RegExp(r'\\'),
            '/',
          ); // Заменяем обратные слеши на прямые

          if (path.startsWith(appPath)) {
            String relativePath = path.substring(appPath.length);
            // Удаляем начальный слеш если есть
            if (relativePath.startsWith('/')) {
              relativePath = relativePath.substring(1);
            }
            // Удаляем конечный слеш если есть
            if (relativePath.endsWith('/')) {
              relativePath = relativePath.substring(0, relativePath.length - 1);
            }

            // Пропускаем пустые пути
            if (relativePath.isNotEmpty) {
              uniquePaths.add(relativePath);
            }
          }
        }
      }

      // Преобразуем Set обратно в List
      List<String> uniqueDirectories = uniquePaths.toList()..sort();

      // Фильтруем и сохраняем только существующие каталоги
      List<String> existingDirectories = await filterExistingDirectories(
        uniqueDirectories,
      );

      setState(() {
        directories = existingDirectories;
      });

      // Для отладки
      print('Найденные директории:');
      for (var dir in directories) {
        print(dir);
      }
    } catch (e) {
      print('Ошибка при получении директорий: $e');
    }
  }

  Future<List<String>> filterExistingDirectories(List<String> paths) async {
    List<String> existingPaths = [];

    for (String path in paths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        existingPaths.add(path);
      }
    }

    return existingPaths;
  }

  Future<void> clearSelectedDirectories(
    List<String> selectedDirectories,
  ) async {
    try {
      // Получаем директорию приложения
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/directories.json');

      // Обновляем список директорий, удаляя выбранные
      List<String> updatedDirectories =
          directories
              .where((dir) => !selectedDirectories.contains(dir))
              .toList();

      // Сохраняем обновленный список в файл
      await file.writeAsString(jsonEncode(updatedDirectories));

      // Обновляем состояние
      setState(() {
        directories = updatedDirectories;
      });

      print('Selected directories cleared successfully');

      // Проверяем состояние отслеживания перед отправкой файлов
      if (_trackingEnabled) {
        toggleTracking(); // Переключаем состояние сервиса
      }
    } catch (e) {
      print('Failed to clear selected directories: $e');
    }
  }

  @override
  /*void initState() {
    super.initState();
    fetchDirectories();
  }
*/
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('File logger 2.0')),
      body: SafeArea(
        // Добавляем SafeArea для предотвращения проблем с навигационной панелью
        child: SingleChildScrollView(
          controller: _scrollController,
          // Прокручиваемый контейнер
          child: Column(
            mainAxisSize: MainAxisSize.min, // Минимизируем размер столбца
            children: [
              // Содержимое вашей страницы остается прежним
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: List.generate(directories.length, (index) {
                    return Column(
                      children: [
                        ListTile(title: Text(directories[index])),
                        Divider(color: Colors.grey),
                      ],
                    );
                  }),
                ),
              ),

              //////////////              Spacer(), // Удалите этот спейсер, он вызывает смещение вниз
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                margin: const EdgeInsets.only(top: 20.0),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      fixedSize: const Size(double.infinity, 50),
                      foregroundColor: Colors.black, // Черный текст
                      backgroundColor: Colors.white, // Белый фон
                      disabledForegroundColor:
                          Colors
                              .grey, // Используем уже объявленные цвета для демонстрации
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(3)),
                        side: BorderSide(
                          color: Colors.grey,
                          width: 1,
                        ), // Серый контур толщиной в 1
                      ),
                    ),
                    onPressed: _pickDirectory,
                    child: const Text('Добавить директорию'),
                  ),
                ),
              ),
              if (directories.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  margin: const EdgeInsets.only(top: 20.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        fixedSize: const Size(double.infinity, 50),
                        foregroundColor: Colors.black, // Черный текст
                        backgroundColor: Colors.white, // Белый фон
                        disabledForegroundColor:
                            Colors
                                .grey, // Используем уже объявленные цвета для демонстрации
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(3)),
                          side: BorderSide(
                            color: Colors.grey,
                            width: 1,
                          ), // Серый контур толщиной в 1
                        ),
                      ),
                      onPressed: () async {
                        bool confirmed =
                            await showDialog<bool>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: Text("Подтверждение удаления"),
                                  content: Text(
                                    "Вы уверены, что хотите очистить все директории? Сервис будет выключен!",
                                  ),
                                  actions: [
                                    TextButton(
                                      child: Text("Отмена"),
                                      onPressed:
                                          () =>
                                              Navigator.of(context).pop(false),
                                    ),
                                    TextButton(
                                      child: Text("Удалить"),
                                      onPressed:
                                          () => Navigator.of(context).pop(true),
                                    ),
                                  ],
                                );
                              },
                            ) ??
                            false;

                        if (confirmed) {
                          print("Пользователь подтвердил очистку");
                          clearSelectedDirectories(directories);
                        }
                      },
                      child: const Text('Очистить'),
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                margin: const EdgeInsets.only(top: 20.0),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      fixedSize: const Size(double.infinity, 50),
                      foregroundColor:
                          _trackingEnabled
                              ? Colors.white
                              : Colors
                                  .black, // Цвет текста в зависимости от флага
                      backgroundColor:
                          _trackingEnabled
                              ? Colors.red
                              : Colors
                                  .white, // Цвет фона в зависимости от флага
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(3)),
                        side: BorderSide(
                          color:
                              _trackingEnabled
                                  ? Colors.red
                                  : Colors
                                      .grey, // Контур меняется в зависимости от флага
                          width: 1,
                        ),
                      ),
                    ),
                    onPressed: () {
                      if (!_trackingEnabled && directories.isEmpty) {
                        showSelectFoldersDialog(); // Показываем диалог выбора папок
                      } else {
                        toggleTracking(); // Переключаем состояние сервиса
                      }
                    },
                    child: Text(
                      _trackingEnabled ? 'Выключить сервис' : 'Включить сервис',
                    ),
                  ),
                ),
              ),

              // Дополнительный пустой контейнер внизу для визуального разделения
              Container(height: 20.0),
            ],
          ),
        ),
      ),
    );
  }
}
