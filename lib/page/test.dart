import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Scaffold(body: MyCustomForm()));
  }
}

class MyCustomForm extends StatefulWidget {
  @override
  _MyCustomFormState createState() => _MyCustomFormState();
}

class _MyCustomFormState extends State {
  final _prefixController = TextEditingController();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _sendingFrequencyController = TextEditingController();

  bool _isFTP = true;

  @override
  void dispose() {
    _prefixController.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _sendingFrequencyController.dispose();
    super.dispose();
  }

  Future _sendData() async {
    var response = await http.post(
      Uri.parse('https://ivnovav.ru/logger_api/saveSettings.php'),
      body: {
        'prefix': _prefixController.text,
        'login': _loginController.text,
        'password': _passwordController.text,
        'host': _hostController.text,
        'port': _portController.text,
        'frequency': _sendingFrequencyController.text,
        'method': _isFTP ? "FTP" : "HTTP",
      },
    );
    if (response.statusCode == 200) {
      if (response.body.isEmpty) {
        throw Exception('Пустой ответ от сервера');
      }
      try {
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
      } catch (e) {
        print('Ошибка декодирования: $e');
        print('Ответ сервера: ${response.body}');
        throw Exception('Ошибка формата ответа');
      }
      // Это излишне, поскольку возвращение происходит в блоке try выше
      // return json.decode(response.body);
    } else {
      throw Exception('Failed to load ads');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ваше название'), // Задайте подходящее название
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            TextField(
              controller: _prefixController,
              decoration: InputDecoration(hintText: "Префикс"),
            ),
            Switch(
              value: _isFTP,
              onChanged: (value) {
                setState(() {
                  _isFTP = value;
                });
              },
            ),
            TextField(
              controller: _loginController,
              decoration: InputDecoration(hintText: "Логин"),
            ),
            TextField(
              controller: _passwordController,
              obscuringCharacter: '*',
              obscureText: true,
              decoration: InputDecoration(hintText: "Пароль"),
            ),
            TextField(
              controller: _hostController,
              decoration: InputDecoration(hintText: "Хост"),
            ),
            TextField(
              controller: _portController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(hintText: "Порт"),
            ),
            TextField(
              controller: _sendingFrequencyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(hintText: "Периодичность отправки"),
            ),
            ElevatedButton(
              onPressed: _sendData,
              child: Text('Отправить данные'),
            ),
          ],
        ),
      ),
    );
  }
}
