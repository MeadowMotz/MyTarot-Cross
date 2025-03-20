
import 'package:flutter/material.dart';
import 'package:my_tarot_cross/DecksPage.dart';
import 'package:my_tarot_cross/main.dart';

Widget NavBar(BuildContext context, GlobalKey<ScaffoldState> _scaffoldKey, Widget body) {
  return Scaffold(
      key: _scaffoldKey,  
      appBar: AppBar(
        title: Text('Decks'),
        leading: IconButton(
          icon: Icon(
            Icons.menu, 
            color: Colors.black,
          ),
          onPressed: () {
            if (_scaffoldKey.currentState!.isDrawerOpen) {
              _scaffoldKey.currentState!.openEndDrawer();  // Close the drawer
            } else {
              _scaffoldKey.currentState!.openDrawer();  // Open the drawer
            }
          }
        ),
      ),
      body: body,
      // Drawer content
      drawer: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        width: 250,  // Adjust width on toggle
        curve: Curves.easeInOut,
        color: Colors.blue,
        child: Column(
          children: [
            DrawerHeader(
              child: Text(
                'Menu',
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home, color: Colors.white),
              title: Text('Home', style: TextStyle(color: Colors.black)),
              onTap: () {
                // Navigate to Home page
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MyHomePage(title: 'Home',)),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.star, color: Colors.white),
              title: Text('Decks', style: TextStyle(color: Colors.black)),
              onTap: () {
                // Navigate to Deck page
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DecksPage()),
                );
              },
            ),
          ],
        ),
      )
    );
}