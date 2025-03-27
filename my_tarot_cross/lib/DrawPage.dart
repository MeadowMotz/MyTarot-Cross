import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:my_tarot_cross/DecksPage.dart';
import 'package:my_tarot_cross/main.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

class DrawPage extends StatefulWidget {
  @override
  _DrawPageState createState() => _DrawPageState();
}

class _DrawPageState extends State<DrawPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<String> imageExtensions = ['.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp'];
  List<String> deckOptions = ['No deck selected'];
  static final Logger _logger = Logger('MyHomePage'); 
  String? cardBase64, selectedDeck, cardPath;
  Future<String>? _meaning;
  bool? flipped;
  Map<String, String?> cards = {};

  @override
  void initState() {
    super.initState();

    Future<void> requestStoragePermission() async {
      await Permission.storage.request();
    }

    if (Platform.isIOS || Platform.isAndroid) requestStoragePermission();

    deckOptions.addAll(Directory('../decks/')
      .listSync()
      .whereType<Directory>() // Filters only directories
      .map((dir) => dir.uri.pathSegments[dir.uri.pathSegments.length - 2]) // Extracts only folder name
      .toList());
    
    selectedDeck = deckOptions[0];
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

  Future<void> drawCard(String deck) async {
    List<FileSystemEntity> fimageFiles = [];
    List<String> imageFiles = [];
    final directory = Directory('../decks/$deck');
 
    Future<String?> _getIpAddress() async {
      if (Platform.isAndroid || Platform.isIOS) {
        final info = NetworkInfo();
        return await info.getWifiIP();
      } else {
        return 'IP Address not available on this platform';
      }
    }
    void collectFiles(Directory dir) {
      // Loop through all files and directories in the current directory
      dir.listSync(recursive: true, followLinks: false).forEach((fileSystemEntity) {
        if (fileSystemEntity is File) {
          // Add image files to the list
          if (imageExtensions.any((ext) => fileSystemEntity.path.toLowerCase().endsWith(ext))) {
            fimageFiles.add(fileSystemEntity);
          }
        }
      });
    }

    _logger.info("Using deck: $deck");
    collectFiles(directory);
    fimageFiles.forEach((file) {imageFiles.add(file.path);});

    final requestBody = {
      'images': imageFiles,
    };

    // Get the dynamic IP address before making the request
    String? ipAddress = await _getIpAddress();
    if (ipAddress == 'IP Address not available on this platform') {
      ipAddress = 'localhost';
    }

    final response = await http.post(
      Uri.parse('http://$ipAddress:5000/draw_card'), 
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['card'] != null && data['card'].isNotEmpty) {
        setState(() {
          cardBase64 = data['image'];
          cardPath = data['card'];
          _meaning = File(cards[cardPath]!).readAsString();
        });
      } else {
        _logger.severe("Processed image is null or empty.");
      }
    } else {
      _logger.severe('Failed to process image: ${response.statusCode} - ${response.body}');
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
            },
            items: deckOptions.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            hint: Text("Deck"),
          ),
          const SizedBox(height: 20,),
          if (cardBase64!=null) Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            SizedBox(
              width: 300,
              height: 400,
              child: Image.memory(
                base64Decode(cardBase64!),
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 50,),
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
          ],),
          if (selectedDeck!='No deck selected') ElevatedButton(
            onPressed: () => {
              drawCard(selectedDeck!)
            }, 
            child: const Text('Draw'),
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
        title: Text('Draw a card'),
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
