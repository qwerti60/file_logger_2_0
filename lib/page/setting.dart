import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  _SettingPageState createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  bool _switchValue = false;
  String? _chosenValue;
  bool _isHidden = true;
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();
  static const platform = MethodChannel('samples.flutter.dev/files');

  // Функция для вызова нативного метода
  Future<void> _sendFiles() async {
    // Создаем локальную ссылку на диалог (будем использовать её позже)
    late BuildContext dialogContext;

    // Показываем индикатор загрузки
    showDialog(
      context: context,
      barrierDismissible: false, // блокируем закрытие внешним кликом
      useRootNavigator: true, // важно, чтобы использовали главный navigator
      builder: (ctx) {
        // сохраняем ссылку на контекст индикатора
        dialogContext = ctx;
        return Center(
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16.0),
                const Text('Отправка файлов...'),
              ],
            ),
          ),
        );
      },
    );

    try {
      // Отправляем файлы
      final result = await platform.invokeMethod('sendFiles');

      // Важно: очищаем глобальное состояние
      Navigator.of(
        dialogContext,
      ).pop(); // закрываем индикатор прямо из контекста

      // Ждём полсекунды, чтобы убедиться, что индикатор исчез
      await Future.delayed(const Duration(milliseconds: 300));

      // Показываем успешное сообщение
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Успех'),
            content: const Text('Файлы успешно отправлены'),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    } on PlatformException catch (e) {
      // Закрываем индикатор из контекста
      Navigator.of(dialogContext).pop();

      // Ждём, чтобы убедиться, что индикатор исчез
      await Future.delayed(const Duration(milliseconds: 300));

      // Показываем сообщение об ошибке
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Ошибка'),
            content: Text(e.message ?? 'Неизвестная ошибка'),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  // Метод для сохранения пароля в Local Storage
  Future<void> savePasswordToStorage(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('password', password);
  }

  Future<void> changePassword(String password, BuildContext context) async {
    try {
      await savePasswordToStorage(
        password,
      ); // Просто сохраняем пароль в хранилище

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Сообщение'),
              content: const Text(
                'Пароль успешно изменён',
              ), // Уведомление о сохранении
              actions: [
                TextButton(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
      );
    } catch (e) {
      print('Ошибка хранения: $e');
      throw Exception('Не удалось сохранить пароль.');
    }
  }

  final _prefixController = TextEditingController();
  final _loginController = TextEditingController();
  final _httpurlController = TextEditingController();
  final _passwordController1 = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _sendingFrequencyController = TextEditingController();

  bool _isFTP = true;

  @override
  void dispose() {
    _prefixController.dispose();
    _loginController.dispose();
    _httpurlController.dispose();
    _passwordController1.dispose();
    _hostController.dispose();
    _portController.dispose();
    _sendingFrequencyController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    loadSettings();
  }
Future saveSettings() async {
try {
final file = await _getSettingsFile();

final settings = {
'prefix' : _prefixController.text.trim(),
'login' : _loginController.text.trim(),
'password' : _passwordController1.text,
'httpurl' : _httpurlController.text.trim(),
'host' : _hostController.text.trim(),
'port' : _portController.text.trim(),
'frequency' : _sendingFrequencyController.text.trim(),
'method' : _chosenValue, // например GET/POST
'separators' : _switchValue ? 1 : 0 // 1 – true, 0 – false
};

await file.writeAsString(jsonEncode(settings));
debugPrint('Настройки сохранены: ${file.path}');
      showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Text('Успех'),
              content: Text('Настройки сохранены'),
              actions: [
                TextButton(
                  child: Text('ОК'),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
      );
} catch (e, s) {
      showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Text('Ошибка'),
              content: Text(e.toString()),
              actions: [
                TextButton(
                  child: Text('ОК'),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
      );
debugPrint('Ошибка при сохранении настроек: $e\n$s');
}
}

Future _getSettingsFile() async {
final dir = await getApplicationDocumentsDirectory();
return File('${dir.path}/settings.txt');
}
  Future<void> _sendData() async {
    // Сначала сохраняем prefix локально
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/prefix.txt');
      print(file);
      await file.writeAsString(_prefixController.text);
    } catch (e) {
      print('Ошибка при сохранении prefix локально: $e');
    }

    // Отправляем данные на сервер
    try {
      var response = await http.post(
        Uri.parse('https://ivnovav.ru/logger_api/saveSettings.php'),
        body: {
          'prefix': '',
          'login': _loginController.text,
          'password': _passwordController1.text,
          'httpurl': _httpurlController.text,
          'host': _hostController.text,
          'port': _portController.text,
          'frequency': _sendingFrequencyController.text,
          'method': _chosenValue,
          'separators': _switchValue ? '1' : '0',
        },
      );

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Пустой ответ от сервера');
        }

        final parsed = json.decode(response.body);
        showDialog(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: Text('Сообщение'),
                content: Text(parsed['message']),
                actions: [
                  TextButton(
                    child: Text('ОК'),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                    },
                  ),
                ],
              ),
        );
      } else {
        throw Exception('Failed to load ads');
      }
    } catch (e) {
      print('Ошибка при отправке данных: $e');
      showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Text('Ошибка'),
              content: Text(e.toString()),
              actions: [
                TextButton(
                  child: Text('ОК'),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
      );
    }
  }

Future loadSettings() async {
try {
final file = await _getSettingsFile();

if (!await file.exists()) {
debugPrint('settings.txt ещё не создан – пропускаем загрузку');
return;
}

final jsonStr = await file.readAsString();
if (jsonStr.isEmpty) return;

final map = jsonDecode(jsonStr);

setState(() {
_prefixController.text = map['prefix'] ?? '';
_loginController.text = map['login'] ?? '';
_passwordController1.text = map['password'] ?? '';
_httpurlController.text = map['httpurl'] ?? '';
_hostController.text = map['host'] ?? '';
_portController.text = map['port'] ?? '';
_sendingFrequencyController.text = map['frequency'] ?? '';
_chosenValue = map['method'] ?? 'GET';
_switchValue = (map['separators'] ?? 0) == 1;
});

debugPrint('Настройки загружены');
} catch (e, s) {
debugPrint('Ошибка при чтении настроек: $e\n$s');
}
}
  // Добавьте метод для чтения prefix при запуске приложения
  Future<String> loadPrefix() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/prefix.txt');
      if (await file.exists()) {
        String prefix = await file.readAsString();
        //_prefixController.text = prefix; // Установка значения в контроллер
        return prefix;
      }
    } catch (e) {
      print('Ошибка при чтении prefix: $e');
    }
    return '_default'; // Возвращаем пустую строку, если не удалось прочитать файл
  } //  TextEditingController _prefixController = TextEditingController();

  // Добавьте контроллеры для всех полей

  void getSettings() async {
    var url = 'http://ivnovav.ru/logger_api/getSettings.php';
    var response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      var data = json.decode(response.body);

      // Получаем prefix из loadPrefix()
      String prefix = await loadPrefix();

      setState(() {
        _prefixController.text = prefix; // Используем полученный prefix
        _loginController.text = data['login'] ?? '';
        _passwordController1.text = data['password'] ?? '';
        _hostController.text = data['host'] ?? '';
        _httpurlController.text = data['httpurl'] ?? '';
        _sendingFrequencyController.text = data['frequency']?.toString() ?? '';
        _portController.text = data['port']?.toString() ?? '';
        _chosenValue = data['method'];
        _switchValue = data['separators'] == 1 ? true : false;
      });
    } else {
      print('Failed to load settings');
    }
  }

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
      uploadFile(
        file,
        _hostController.text,
        _loginController.text,
        _passwordController1.text,
      );
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

  Future<void> uploadFile(
    PlatformFile file,
    String _host,
    String _login,
    String _password,
  ) async {
    FTPConnect ftpConnect = FTPConnect(_host, user: _login, pass: _password);

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
    return Scaffold(
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              margin: const EdgeInsets.only(top: 80.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(left: 5),
                      child: Text(
                        "Изменение пароля",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  SizedBox(height: 5),
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      fillColor: Color(0xFF21212114), // Цвет фона поля
                      filled: true,
                      hintText: "Новый пароль",
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    obscureText: true, // Скрытие введённого текста
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: confirmPasswordController,
                    decoration: InputDecoration(
                      fillColor: Color(0xFF21212114), // Цвет фона поля
                      filled: true,
                      hintText: "Повтор пароля",
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    obscureText: true, // Скрытие введённого текста
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 10,
                    ), // Задаем отступ только сверху
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          fixedSize: const Size(double.infinity, 50),
                          foregroundColor: Colors.black,
                          backgroundColor: Colors.white,
                          disabledForegroundColor: Colors.grey,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(3)),
                            side: BorderSide(color: Colors.grey, width: 1),
                          ),
                        ),
                        onPressed: () {
                          if (passwordController.text.isNotEmpty &&
                              confirmPasswordController.text.isNotEmpty &&
                              passwordController.text ==
                                  confirmPasswordController.text) {
                            changePassword(passwordController.text, context);
                          } else {
                            showDialog(
                              context: context,
                              builder:
                                  (ctx) => AlertDialog(
                                    title: Text('Ошибка'),
                                    content: Text(
                                      'Введенные пароли не совпадают или не введены.',
                                    ),
                                    actions: [
                                      TextButton(
                                        child: Text('ОК'),
                                        onPressed: () {
                                          Navigator.of(ctx).pop();
                                        },
                                      ),
                                    ],
                                  ),
                            );
                          }
                        },
                        child: const Text('Изменить пароль'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(left: 5),
                        child: Text(
                          "Настройка отчётности",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: EdgeInsets.all(20.0), // Пример отступа
              padding: EdgeInsets.all(4.0), // Пример внутреннего отступа

              child: TextField(
                controller: _prefixController,
                decoration: InputDecoration(
                  fillColor: Color(0xFF21212114), // Цвет фона поля
                  filled: true,
                  hintText: "Ryaz_Tab A",
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                // obscureText: true, // Скрытие введённого текста, раскомментируйте при необходимости
              ),
            ),
            Container(
              padding: const EdgeInsets.all(
                20.0,
              ), // Добавляем отступы вокруг содержимого контейнера

              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Разделитель в отчёте"),
                    Switch(
                      value:
                          _switchValue, // Использует переменную состояния для управления значением Switch
                      onChanged: (bool newValue) {
                        setState(() {
                          _switchValue =
                              newValue; // Обновляет переменную состояния
                        });
                      },
                      inactiveThumbColor:
                          Colors
                              .grey, // Цвет кружка переключателя в выключенном состоянии
                      inactiveTrackColor: Colors.grey.withOpacity(
                        0.50,
                      ), // Цвет фона переключателя в выключенном состоянии
                      activeColor: Color(
                        0xFF1C437E,
                      ), // Цвет кружка переключателя во включенном состоянии
                      activeTrackColor: Color(0xFF1C437E).withOpacity(
                        0.50,
                      ), // Цвет фона переключателя во включенном состоянии
                    ),
                  ],
                ),
              ),
            ),
            Container(
              // Здесь вы можете добавить параметры для Container, например, margin, padding, decoration и т.д.
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 20.0,
                ), // Отступы по бокам
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('Передача файлов'),
                    DropdownButton<String>(
                      underline: SizedBox(), // Убрать подчеркивание
                      value: _chosenValue,
                      hint: Text('Выберите метод'),
                      items:
                          <String>['ftp', 'http'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Row(
                                children: <Widget>[
                                  Text(value),
                                  // Если текущее значение равно выбранному, показываем иконку галочки
                                  if (_chosenValue == value)
                                    Icon(Icons.check, color: Color(0xFF1C437E)),
                                ],
                              ),
                            );
                          }).toList(),
                      onChanged: (String? value) {
                        setState(() {
                          _chosenValue = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            _chosenValue == 'http'
                ? Container(
                  padding: EdgeInsets.only(
                    left: 20.0,
                    top: 10.0, // Отступ сверху 10.0
                    right: 20.0,
                  ), // Отступы по бокам и сверху

                  child: TextField(
                    controller: _httpurlController,
                    decoration: InputDecoration(
                      fillColor: Color(0xFF21212114), // Цвет фона поля
                      filled: true,
                      hintText: "HTTP URL",
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    // obscureText: true, // Скрытие введённого текста
                  ),
                ) // Пустой контейнер, если значение равно 'http'
                : Column(
                  children: [
                    Container(
                      padding: EdgeInsets.only(
                        left: 20.0,
                        top: 10.0, // Отступ сверху 10.0
                        right: 20.0,
                      ), // Отступы по бокам и сверху

                      child: TextField(
                        controller: _loginController,
                        decoration: InputDecoration(
                          fillColor: Color(0xFF21212114), // Цвет фона поля
                          filled: true,
                          hintText: "Login",
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        // obscureText: true, // Скрытие введённого текста
                      ),
                    ),
                    Container(
                      // Здесь вы можете добавить свойства Container, например margin, color и т.д.
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: 20.0,
                          top: 10.0, // Отступ сверху 10.0
                          right: 20.0,
                        ), // Отступы по бокам и сверху

                        child: TextField(
                          controller: _passwordController1,
                          obscureText:
                              _isHidden, // Переключатель видимости текста
                          style: TextStyle(
                            color:
                                Colors
                                    .black, // Устанавливаем цвет текста в черный
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Пароль', // Вместо labelText используем hintText
                            filled: true, // Включаем заливку
                            fillColor: Color(
                              0xFF21212114,
                            ), // Указываем цвет заливки
                            suffixIcon: IconButton(
                              icon: Icon(
                                // Иконка глаза меняется в зависимости от состояния _isHidden
                                _isHidden
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                // Обновляем состояние видимости пароля при нажатии
                                setState(() {
                                  _isHidden = !_isHidden;
                                });
                              },
                            ),
                            labelStyle: TextStyle(
                              color: Colors.grey, // Цвет текста подсказки
                            ),
                            border: OutlineInputBorder(
                              // Используем OutlineInputBorder
                              borderSide:
                                  BorderSide.none, // Убираем видимый бордюр
                              borderRadius: BorderRadius.circular(
                                5,
                              ), // Можно задать радиус скругления
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide:
                                  BorderSide
                                      .none, // Убираем видимый бордюр в обычном состоянии
                              borderRadius: BorderRadius.circular(5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide:
                                  BorderSide
                                      .none, // Убираем видимый бордюр при фокусе
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(
                        20.0,
                      ), // Подстраиваем отступы по вашему предпочтению
                      child: Row(
                        children: [
                          // Растягиваем левое поле на всё доступное пространство, минус ширина правого
                          Expanded(
                            child: TextField(
                              controller: _hostController,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Color(
                                  0xFF21212114,
                                ), // Цвет фона поля
                                hintText: 'host',
                                border: OutlineInputBorder(
                                  borderSide: BorderSide.none,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 10,
                          ), // Добавляем небольшой отступ между полями
                          // Устанавливаем ширину правого поля ровно в 250
                          Container(
                            width: 100,
                            child: TextField(
                              controller: _portController,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Color(
                                  0xFF21212114,
                                ), // Цвет фона поля

                                hintText: 'port',
                                border: OutlineInputBorder(
                                  borderSide: BorderSide.none,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

            Container(
              padding: EdgeInsets.only(
                left: 20.0,
                top: 5.0, // Отступ сверху 10.0
                right: 20.0,
              ), // Подстраиваем отступы по вашему предпочтению
              child: Row(
                children: [
                  Text(
                    'Отправлять в день',
                    style: TextStyle(color: Colors.black, fontSize: 16),
                  ),
                  Spacer(), // Используйте Spacer для автоматического занятия всего доступного пространства
                  Container(
                    width: 100,
                    alignment:
                        Alignment.centerRight, // Выравнивание по правому краю
                    child: TextField(
                      controller: _sendingFrequencyController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Color(0xFF21212114), // Цвет фона поля

                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Spacer(), // Разделитель, который автоматически расширяется
            // Контейнеры с кнопками внизу
            Container(
              padding: EdgeInsets.only(
                left: 20.0,
                top: 10.0, // Отступ сверху 10.0
                right: 20.0,
              ), // Отступы по бокам и сверху

              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    fixedSize: const Size(double.infinity, 50),
                    foregroundColor: Colors.black,
                    backgroundColor: Colors.white,
                    disabledForegroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(3)),
                      side: BorderSide(color: Colors.grey, width: 1),
                    ),
                  ),
                  onPressed: saveSettings,
                  child: const Text('Сохранить изменения'),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.only(
                left: 20.0,
                top: 10.0,
                right: 20.0,
                bottom: 20.0, // Добавлен отступ снизу
              ),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    fixedSize: const Size(double.infinity, 50),
                    foregroundColor: Colors.black,
                    backgroundColor: Colors.white,
                    disabledForegroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(3)),
                      side: BorderSide(color: Colors.grey, width: 1),
                    ),
                  ),
                  onPressed: _sendFiles,
                  child: const Text('Тестовый запрос'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
