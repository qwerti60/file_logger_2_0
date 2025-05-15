//import 'dart:ffi';

import 'dart:convert';

import 'package:file_logger20/config.dart';
import 'package:file_logger20/design/colors.dart';
import 'package:file_logger20/design/dimension.dart';
import 'package:file_logger20/page/2.dart';
import 'package:file_logger20/page/3.dart';
import 'package:file_logger20/page/monitoring.dart';
import 'package:file_logger20/page/pages.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<LoginPage> {
  var login;
  var password;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  void _login(BuildContext context) async {
    final response = await http.post(
      Uri.parse('http://ivnovav.ru/logger_api/login.php'),
      body: {'password': _passwordController.text},
    );
    print(password);
    if (response.body == 'success') {
      // Если пароль верный, переходим к следующему окну
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PagesScreen()),
      );
    } else {
      // Если пароль неверный, показываем ошибку
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Ошибка'),
            content: const Text('Неверный пароль'),
            actions: [
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

  bool _isHidden = true;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 200.0),
            Image.asset(
              'assets/images/logo.png', // путь к изображению
              width: 102, // ширина изображения
              height: 94, // высота изображения
            ),
            const Text(
              'File logger 2.0',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: blackprColor,
                fontSize: fontSize24,
              ),
            ),
            const Text(
              'Авторизация',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: blackprColor,
                fontSize: fontSize20,
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              margin: const EdgeInsets.only(top: 20.0),
              child: TextField(
                controller: _passwordController,
                obscureText: _isHidden, // Переключатель видимости текста
                style: TextStyle(
                  color: Colors.black, // Устанавливаем цвет текста в черный
                ),
                decoration: InputDecoration(
                  labelText: 'Пароль',
                  suffixIcon: IconButton(
                    icon: Icon(
                      // Иконка глаза меняется в зависимости от состояния _isHidden
                      _isHidden ? Icons.visibility_off : Icons.visibility,
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
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.black,
                    ), // Цвет подчеркивания по умолчанию
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.black,
                    ), // Цвет подчеркивания при фокусе
                  ),
                  fillColor: Colors.black,
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
                    foregroundColor: Colors.black, // Черный текст
                    backgroundColor: Colors.white, // Белый фон
                    disabledForegroundColor:
                        grayprprColor, // Задает цвет текста, когда кнопка неактивна
                    shape: RoundedRectangleBorder(
                      // Изменил на RoundedRectangleBorder для удобства работы с side
                      borderRadius: BorderRadius.all(Radius.circular(3)),
                      side: BorderSide(
                        color: Colors.grey,
                        width: 1,
                      ), // Серый контур толщиной в 1
                    ),
                  ),
                  onPressed: () => _login(context),

                  child: const Text('Войти'),
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
                    foregroundColor: Colors.black, // Черный текст
                    backgroundColor: Colors.white, // Белый фон
                    disabledForegroundColor:
                        grayprprColor, // Задает цвет текста, когда кнопка неактивна
                    shape: RoundedRectangleBorder(
                      // Изменил на RoundedRectangleBorder для удобства работы с side
                      borderRadius: BorderRadius.all(Radius.circular(3)),
                      side: BorderSide(
                        color: Colors.grey,
                        width: 1,
                      ), // Серый контур толщиной в 1
                    ),
                  ),
                  onPressed: () {
                    // Navigator push используется для навигации
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => PagesScreen()),
                    );
                  },

                  child: const Text('test 1'),
                ),
              ),
            ),
            /*          Container(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              margin: const EdgeInsets.only(top: 20.0),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    fixedSize: const Size(double.infinity, 50),
                    foregroundColor: Colors.black, // Черный текст
                    backgroundColor: Colors.white, // Белqый фон
                    disabledForegroundColor:
                        grayprprColor, // Задает цвет текста, когда кнопка неактивна
                    shape: RoundedRectangleBorder(
                      // Изменил на RoundedRectangleBorder для удобства работы с side
                      borderRadius: BorderRadius.all(Radius.circular(3)),
                      side: BorderSide(
                        color: Colors.grey,
                        width: 1,
                      ), // Серый контур толщиной в 1
                    ),
                  ),
                  onPressed: () {
                    // Navigator push используется для навигации
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => ()),
                    );
                  },

                  child: const Text('test 2'),
                ),
              ),
            ),*/
          ],
        ),
      ),
    );
  }
}
