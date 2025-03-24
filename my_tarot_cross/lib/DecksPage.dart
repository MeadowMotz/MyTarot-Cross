import 'dart:io';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:my_tarot_cross/main.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:carousel_slider/carousel_slider.dart';

class DecksPage extends StatefulWidget {
  @override
  _DecksPageState createState() => _DecksPageState();
}

class _DecksPageState extends State<DecksPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<String> images = [];
  List<String> deckOptions = ['No deck selected'];
  String? selectedDeck;
  final List<String> imageExtensions = ['.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp'];
  static final Logger _logger = Logger('MyHomePage'); 
  int currentIndex = 0;
  String currentCardText = "Select a card"; 

  // Map of images to descriptions (you can replace with real descriptions)
  Map<String, String> cardDescriptions = {
    'CatTarot\\6 Swords.jpg': 'This is the first card’s meaning.',
    'CatTarot\\7 Swords.jpg': 'This is the second card’s meaning.',
    // Add more cards as needed
  };

  @override
  void initState() {
    super.initState();

    if (Platform.isIOS || Platform.isAndroid) requestStoragePermission();

    deckOptions.addAll(Directory('../decks/')
      .listSync()
      .whereType<Directory>() // Filters only directories
      .map((dir) => dir.uri.pathSegments[dir.uri.pathSegments.length - 2]) // Extracts only folder name
      .toList());
    
    selectedDeck = deckOptions[0];
  }

  Future<void> requestStoragePermission() async {
    await Permission.storage.request();
  }

  Widget body() {
    return Center(
      child: Column(
        children: [
          DropdownButton<String>(
            value: selectedDeck,
            onChanged: (String? newValue) {
              setState(() {
                selectedDeck = newValue ?? '';
                images.clear();
                images.addAll(Directory('../decks/$selectedDeck')
                    .listSync()
                    .whereType<File>() // Filter only files
                    .where((file) => imageExtensions.any((ext) => file.path.toLowerCase().endsWith(ext))) // Filter image types
                    .map((file) => file.path) // Get file paths
                    .toList());
              });
              _logger.info('Images used: $images');
            },
            items: deckOptions.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            hint: Text("Deck"),
          ),
          if (selectedDeck == null) Text('No decks available.'),
          const SizedBox(height: 10,),
          CarouselSlider.builder(
            itemCount: images.length,
            itemBuilder: (context, index, realIdx) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SizedBox(
                  width: 300,
                  child: Image.file(File(images[index])),
                ),
              );
            },
            options: CarouselOptions(
              height: 300,
              enlargeCenterPage: true,
              autoPlay: false,
              viewportFraction: 0.1, 
              enableInfiniteScroll: false,
              aspectRatio: 16 / 9,
              initialPage: 0,
              enlargeFactor: 0.3,
              onPageChanged: (index, reason) {
                setState(() {
                  currentIndex = index;
                  String imageName = images[index].split('/').last; // Extract image filename
                  _logger.info("imageName: $imageName");
                  currentCardText = cardDescriptions[imageName] ?? "No description available.";
                });
              },
            ),
          ),
          const SizedBox(height: 20),
          Text(
            currentCardText,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                _scaffoldKey.currentState!.openEndDrawer(); // Close the drawer
              } else {
                _scaffoldKey.currentState!.openDrawer(); // Open the drawer
              }
            }),
      ),
      body: body(),
      drawer: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        width: 250, // Adjust width on toggle
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => MyHomePage(
                            title: 'Home',
                          )),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.star, color: Colors.white),
              title: Text('Decks', style: TextStyle(color: Colors.black)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DecksPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
