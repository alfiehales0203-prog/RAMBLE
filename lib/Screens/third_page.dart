import 'package:flutter/material.dart';

class ThirdPage extends StatelessWidget {
  const ThirdPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Third Page'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'This is the Third Page!',
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Go Back One Page'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                // Go all the way back to home
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: Text('Go Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}