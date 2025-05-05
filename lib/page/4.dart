import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    List<List<String>> testLogData = [
      ["A", "B"],
      ["C", "D"],
    ];

    return Scaffold(
      body: ListView.separated(
        separatorBuilder: (context, index) => Divider(),
        itemCount: testLogData.length,
        itemBuilder: (context, index) {
          return Text(testLogData[index].join(','));
        },
      ),
    );
  }
}
