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
    fetchDirectories();
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

        // Отправляем полный список серверу
        final response = await Dio().post(
          'http://ivnovav.ru/logger_api/add_directory.php',
          data: {'directories': directories},
        );

        if (response.statusCode == 200) {
          print("Все директории успешно добавлены!");
          print(directories);

          // Ждём, пока дерево виджетов обновится, и только после этого производим скроллинг
          SchedulerBinding.instance.addPostFrameCallback((_) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: Duration(
                milliseconds: 300,
              ), // Время анимации (например, 300 мс)
              curve: Curves.easeInOut, // Кривая движения
            );
          });
        } else {
          print("Ошибка при добавлении директорий.");
        }
      } catch (e) {
        print(e.toString());
      }
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
    var uri = Uri.parse('http://ivnovav.ru/logger_api/get_directory.php');
    var response = await http.get(uri);

    if (response.statusCode == 200) {
      var responseBody = response.body;

      // Проверяем, не равно ли тело ответа "0 results"
      if (responseBody.trim() == "0 results") {
        print("Директории не найдены.");
        setState(() {
          directories = [];
        });
      } else {
        // Преобразуем ответ в динамический список
        List json = jsonDecode(responseBody);

        // Получаем список директорий, игнорируя возможные null или некорректные данные
        List<String> newDirectories =
            json
                .where(
                  (element) =>
                      element is Map &&
                      element.containsKey('directory_path') &&
                      element['directory_path'] is String,
                )
                .map((item) => item['directory_path'])
                .cast<String>()
                .toList();

        // Фильтруем и сохраняем только существующие каталоги
        List<String> existingDirectories = await filterExistingDirectories(
          newDirectories,
        );

        setState(() {
          directories = existingDirectories;
        });
        // Выполняем автоматический скроллинг после обновления списка директорий
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        });
      }
    } else {
      print("Ошибка при получении директорий.");
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
    var data = {'directories': selectedDirectories};
    final response = await http.post(
      Uri.parse('http://ivnovav.ru/logger_api/clearDirectoryes.php'),
      headers: {"Content-Type": "application/json"},
      body: json.encode(data),
    );

    if (response.statusCode == 200) {
      // Если сервер успешно обработал запрос
      print('Selected directories cleared successfully');
      List<String> updatedDirectories =
          directories
              .where((dir) => !selectedDirectories.contains(dir))
              .toList();

      setState(() {
        directories = updatedDirectories;
      });
    } else {
      // Если сервер не смог обработать запрос
      print('Failed to clear selected directories');
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
