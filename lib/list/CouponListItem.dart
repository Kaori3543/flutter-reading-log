import 'package:flutter/material.dart';
import 'package:sample/list/MainContent.dart';

class CouponListItem extends StatelessWidget {
  final VoidCallback? onPressed;
  const CouponListItem(this.onPressed, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(10),
      padding: EdgeInsets.all(10),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey, blurRadius: 3)],
      ),

      child: Row(
        children: [
          Container(
            width: 100,
            height: 100,
            margin: EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1),
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.grey, blurRadius: 1)],
            ),
            child: imageWidget(),
          ),
          Expanded(
            child: SizedBox(
              height: 100,
              child: MainContent(onPressed ?? () {})
            ),
          ),
        ],
      ),
    );
  }

  //  画像を表示
  Widget imageWidget() {
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: Image.asset(
          'assets/images/c_img.jpg',
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 100,
              height: 100,
              color: Colors.red[100],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Colors.red, size: 30),
                  SizedBox(height: 4),
                  Text(
                    '画像読み込みエラー',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'asset not found',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: 8,
                      decoration: TextDecoration.lineThrough,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
