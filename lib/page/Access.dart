import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

Future<bool> verifyStorageAccess() async {
  var status = await Permission.storage.status;
  if (status.isDenied || status.isPermanentlyDenied) {
    final result = await Permission.storage.request();
    return result.isGranted;
  }
  return true;
}

void showErrorDialog(BuildContext context) {
  showDialog(
    context: context,
    builder:
        (context) => AlertDialog(
          title: Text("Необходим доступ к файлам"),
          content: Text(
            "Для продолжения работы необходимо предоставить доступ к файлам.",
          ),
          actions: [
            TextButton(
              child: Text("OK"),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
  );
}
