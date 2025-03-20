import 'package:flutter/material.dart';
import 'package:my_tarot_cross/NavBar.dart';
class DecksPage extends StatefulWidget {
  @override
  _DecksPageState createState() => _DecksPageState();
}

class _DecksPageState extends State<DecksPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return NavBar(context, _scaffoldKey, body());
  }

  Widget body() {
    return Text('Unimplemented');
  }
}