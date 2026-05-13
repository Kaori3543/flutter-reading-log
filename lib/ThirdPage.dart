import 'package:flutter/material.dart';

class ThirdPage extends StatelessWidget{
  const ThirdPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title : Text("ページ(3)")
      ),
      body : Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              child: Text("ホームに戻る"),
              onPressed: (){
                Navigator.popUntil(context, (route) => route.isFirst);
              },
            ),
          ],
        ),
      )
    );
  }
}
