import 'package:flutter/material.dart';
import 'package:sample/SecondPage.dart';

class FirstPage extends StatelessWidget{
  const FirstPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title : Text("ページ(1)")
      ),
      body : Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              child: Text("2ページ目に遷移する"),
              onPressed: (){
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => const SecondPage()
                ));
              },
            ),
          ],
        ),
      )
    );
  }
}