import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:my_tarot_cross/DrawPage.dart';
import 'package:my_tarot_cross/main.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:carousel_slider/carousel_slider.dart' as slider;
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;

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

  void deleteCard(String filePath) async {
    final fileIm = File(filePath);
    final fileTxt = File("${p.withoutExtension(filePath)}.txt");

    if (await fileIm.exists() && await fileTxt.exists()) {
      await fileIm.delete();
      _logger.info("Image deleted successfully");
      await fileTxt.delete();
      _logger.info("Text deleted successfully");
    } else {
      _logger.severe("File not found");
    }
  }

  void saveCard(String filePath) async {
    String? path = await FilePicker.platform.saveFile(
    dialogTitle: 'Select Save Location',
    fileName: 'card.jpg',
    type: FileType.custom,
    allowedExtensions: ['png', 'jpg', 'jpeg'],
    );

    if (path != null) {
      try {
        // Read the original file as bytes
        List<int> bytes = await File(filePath).readAsBytes();

        // Decode the image
        img.Image? image = img.decodeImage(Uint8List.fromList(bytes));
        if (image == null) {
          _logger.severe('Error: Unable to decode image.');
          return;
        }

        // Get the target file extension
        String extension = path.split('.').last.toLowerCase();

        // Encode the image in the correct format
        List<int> newBytes;
        switch (extension) {
          case 'png':
            newBytes = img.encodePng(image);
            break;
          case 'jpg':
          case 'jpeg':
            newBytes = img.encodeJpg(image);
            break;
          default:
            _logger.severe('Error: Unsupported file format.');
            return;
        }

        // Save the new file
        await File(path).writeAsBytes(newBytes);
        _logger.info('File saved successfully at: $path');
      } catch (e) {
        _logger.severe('Error saving file: $e');
      }
    } else {
      _logger.info('User canceled the dialog.');
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            if (selectedDeck!='No deck selected' && selectedDeck!=null)
              PopupMenuButton<String>(
                icon: const Icon(Icons.miscellaneous_services),
                onSelected: (String value) {
                  switch (value) {
                    case 'Edit card': {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: const Text("To edit a card, go to the home page and create a new card with the same name")));
                    }
                    case 'Delete card': {
                      String path = cards.keys.elementAt(currentIndex);
                      deleteCard(path);
                      setState(() {
                        cards.remove(path);
                      });
                    }
                    case 'Export card': {
                      saveCard(cards.keys.elementAt(currentIndex));
                    }
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'Edit card',
                    child: const Text('Edit card'),
                  ),
                  PopupMenuItem<String>(
                    value: 'Delete card',
                    child: const Text('Delete card'),
                  ),
                  PopupMenuItem<String>(
                    value: 'Export card',
                    child: const Text('Export card'),
                  ),
                ],
            ),
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
            icon: const Icon(
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
              leading: const Icon(Icons.home, color: Colors.white),
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
              leading: const Icon(Icons.star, color: Colors.white),
              title: const Text('Decks', style: TextStyle(color: Colors.black)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DecksPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.casino_rounded, color: Colors.white),
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
