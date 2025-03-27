import 'dart:io';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:my_tarot_cross/DrawPage.dart';
import 'package:my_tarot_cross/main.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:carousel_slider/carousel_slider.dart' as slider;
import 'package:path/path.dart' as p;

class DecksPage extends StatefulWidget {
  @override
  _DecksPageState createState() => _DecksPageState();
}

class _DecksPageState extends State<DecksPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<String> deckOptions = ['No deck selected'];
  String? selectedDeck;
  final List<String> imageExtensions = ['.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp'];
  static final Logger _logger = Logger('MyHomePage'); 
  int currentIndex = 0;
  Future<String>? _meaning;
  Map<String, String?> cards = {};
  Directory? direc;

  @override
  void initState() {
    super.initState();
    
    // Initialize storage permission request and directory setting
    requestStoragePermission();
    setDir();
  }

  // Request storage permission asynchronously
  Future<void> requestStoragePermission() async {
    await Permission.storage.request();
  }

  // Set directory asynchronously based on platform
  Future<void> setDir() async {
    Directory? tempDir;

    if (Platform.isIOS || Platform.isAndroid) {
      tempDir = await getApplicationDocumentsDirectory();
    } else {
      // For other platforms, use relative path
      tempDir = Directory('../decks/');
    }

    setState(() {
      direc = tempDir;  // Safely assign the directory
    });

    // After setting the directory, create it if it doesn't exist
    if (!direc!.existsSync()) {
      direc!.createSync(recursive: true);
    }

    // Initialize dropdownOptions after the directory is set
    initializeDropdownOptions();
  }

  // Initialize dropdown options based on the directory content
  void initializeDropdownOptions() {
    if (direc != null) {
      deckOptions.addAll(direc!
      .listSync()
      .whereType<Directory>() // Filters only directories
      .map((dir) => dir.uri.pathSegments[dir.uri.pathSegments.length - 2]) // Extracts only folder name
      .toList());
    
      selectedDeck = deckOptions[0];
    }
  }

  void mapCards(String deck) {
    final directory = Directory('../decks/$deck');
    if (!directory.existsSync()) {
      _logger.severe("Directory does not exist");
      return;
    }
    List<FileSystemEntity> fimageFiles = [], ftextFiles = [];
    List<String> imageFiles = [], textFiles = [];

    void collectFiles(Directory dir) {
      // Loop through all files and directories in the current directory
      dir.listSync(recursive: true, followLinks: false).forEach((fileSystemEntity) {
        if (fileSystemEntity is File) {
          // Add image files to the list
          if (imageExtensions.any((ext) => fileSystemEntity.path.toLowerCase().endsWith(ext))) {
            fimageFiles.add(fileSystemEntity);
          }
          // Add text files to the list
          else if (fileSystemEntity.path.toLowerCase().endsWith('.txt')) {
            ftextFiles.add(fileSystemEntity);
          }
        }
      });
    }

    collectFiles(directory);
    fimageFiles.forEach((file) {imageFiles.add(file.path);});
    ftextFiles.forEach((file) {textFiles.add(file.path);});
    
    for (var image in imageFiles) {
      final name = p.withoutExtension(image.split('/').last); 
      for (var txt in textFiles) {
        final meaning = p.withoutExtension(txt.split('/').last);
        if (name==meaning) { // When names equal, map paths
          if (cards.containsKey(image)) _logger.info("Duplicate card [$image] with meaning [${cards[image]}]");
          cards.addAll({image: txt});
        }
      }
    }
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
                cards.clear();
                if (selectedDeck!="No deck selected") mapCards(selectedDeck!);
              });
              _logger.info('Images used: ${cards.keys.toList()}');
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
          Container(
            width: 1200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25), // Rounded corners
              gradient: LinearGradient(
                colors: [
                  Colors.purple,
                  Colors.blue,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border(
                bottom: BorderSide(color: Colors.black, width: 5),
                top: BorderSide(color: Colors.black, width: 5),
              ),
            ),
            padding: EdgeInsets.all(4), // Thickness of the border
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20), // Must match Carousel item radius
              ),
              child:
                slider.CarouselSlider.builder(
                  itemCount: cards.length,
                  itemBuilder: (context, index, realIdx) {
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: SizedBox(
                          width: 300,
                          child: Image.file(File(cards.keys.elementAt(index))),
                      ),
                    );
                  },
                  options: slider.CarouselOptions(
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
                        String imageName = cards.keys.elementAt(index); // Extract image filename
                        _meaning = File(cards[imageName]!).readAsString();
                      });
                    },
                  ),
                ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 500,
            height: 200,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: Colors.black),
                right: BorderSide(color: Colors.black),
              ),
            ),
            child: FutureBuilder<String>(
              future: _meaning,  // The future to be resolved
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  // While waiting for the data
                  return CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  // If an error occurred
                  return Text('Error: ${snapshot.error}');
                } else if (snapshot.hasData) {
                  // Once the data is available
                  return Text(snapshot.data ?? 'No data available', textAlign: TextAlign.center,);
                } else {
                  // If no data is returned
                  return Text('No description available', textAlign: TextAlign.center,);
                }
              },
            ),
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
              child: const Text(
                'Menu',
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home, color: Colors.white),
              title: const Text('Home', style: TextStyle(color: Colors.black)),
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
              title: const Text('Decks', style: TextStyle(color: Colors.black)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DecksPage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.casino_rounded, color: Colors.white),
              title: const Text('Draw', style: TextStyle(color: Colors.black)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DrawPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
