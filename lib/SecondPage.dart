import 'package:flutter/material.dart';
import 'package:sample/ThirdPage.dart';

class SecondPage extends StatelessWidget{
  const SecondPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title : Text("ページ(2)")
      ),
      body : Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              child: Text("3ページ目に遷移する"),
              onPressed: (){
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => const ThirdPage()
                ));
              },
            ),
          ],
        ),
      )
    );
  }
}