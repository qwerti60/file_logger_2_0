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

    if (result != null && !directories.contains(result)) {
      setState(() {
        directories.add(result);
      });

      try {
        final subDirectories = await _listAllSubdirectories(result);
        for (var dir in subDirectories) {
          setState(() {
            directories.add(dir);
          });
        }

        // Сохраняем директории в локальный файл
        await _saveDirectories();

        print("Все директории успешно добавлены!");
        print(directories);

        // Ждём, пока дерево виджетов обновится, и только после этого производим скроллинг
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        });
      } catch (e) {
        print(e.toString());
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
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
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

      // Получаем список всех файлов и директорий
      final Directory directory = Directory(appPath);
      List<FileSystemEntity> entities =
          await directory.list(recursive: true).toList();

      // Фильтруем только директории
      List<String> newDirectories =
          entities
              .where((entity) => entity is Directory)
              .map((entity) => entity.path)
              .toList();

      // Преобразуем пути в относительные (относительно корневой директории приложения)
      newDirectories =
          newDirectories.map((path) {
            return path.replaceFirst(appPath, '');
          }).toList();

      // Удаляем пустые пути и корневую директорию
      newDirectories = newDirectories.where((path) => path.isNotEmpty).toList();

      // Удаляем дубликаты
      newDirectories = newDirectories.toSet().toList();

      // Фильтруем и сохраняем только существующие каталоги
      List<String> existingDirectories = await filterExistingDirectories(
        newDirectories,
      );

      setState(() {
        directories = existingDirectories;
      });

      // Выполняем автоматический скроллинг после обновления списка директорий
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    } catch (e) {
      print("Ошибка при получении директорий: $e");
      setState(() {
        directories = [];
      });
    }
  }

  Future<List<String>> filterExistingDirectories(
    List<String> directoriesToCheck,
  ) async {
    final fs = const LocalFileSystem();
    final appDocsDir = await getApplicationDocumentsDirectory();

    // Параллельно проверяем каждую директорию
    List<String?> checkedDirs = await Future.wait(
      directoriesToCheck.map((dir) async {
        final fullPath = p.join(appDocsDir.path, dir);
        final fileEntity = fs.directory(fullPath);

        if (await fileEntity.exists()) {
          return dir;
        } else {
          return null;
        }
      }),
    );

    // Убираем null и формируем финальный список
    return checkedDirs.where((dir) => dir != null).map((dir) => dir!).toList();
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
                                    "Вы уверены, что хотите очистить все директории?",
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
