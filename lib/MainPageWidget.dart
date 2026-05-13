import 'package:flutter/material.dart';
import '/detail/BookDetail.dart';
import '/list/BookListView.dart';

class MainPageWidget extends StatefulWidget{

  @override
  State<StatefulWidget> createState() {
    return _MainPageWidget();
  }

}
class _MainPageWidget extends State<MainPageWidget>{

  bool _isSelectedItem = false;

  // 詳細画面を表示する
  void openDetail(){
    setState(() {
      _isSelectedItem = true;
    });
  }
  // 詳細画面を消す
  void closeDetail(){
    setState(() {
      _isSelectedItem = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        BookListView(openDetail),
        if (_isSelectedItem)
          BookDetail(closeDetail)
      ],
    );
  }
}
