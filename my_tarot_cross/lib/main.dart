import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:my_tarot_cross/DecksPage.dart';
import 'package:my_tarot_cross/DrawPage.dart';
import 'package:logging/logging.dart'; 
import 'package:my_tarot_cross/EditorPage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:my_tarot_cross/python.dart';

void main() {
  Logger.root.level = Level.ALL;  
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  runApp(const TarotApp());
}

class TarotApp extends StatelessWidget {
  const TarotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Home'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final PythonInterface _python = PythonInterface();
  static final Logger _logger = Logger('MyHomePage'); 
  String? _path, _rectifiedImageBase64, deck, card, cardName, cardMeaning;
  bool isLoading = false, showText = false;
  List<String> dropdownOptions = ['Add new deck'];
  String selectedDeck = '';
  TextEditingController newDeckController = TextEditingController(), 
                        newCardController = TextEditingController(),
                        meaningController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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
      dropdownOptions.addAll(
        direc!.listSync()
          .whereType<Directory>()  // Filters only directories
          .map((dir) => dir.uri.pathSegments[dir.uri.pathSegments.length - 2])  // Extracts folder name
          .toList(),
      );
    }
  }

  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (result != null && result.files.isNotEmpty) {
      if (result.files.length==1) {
        setState(() {
          _path = result.files.first.path;
        });
      }
      else { // When multiple files, use dialogs
        for (var file in result.files) {
          await _sendImageToBackend(file.path!, null);
          Map<String, String>? userInput = await _getUserInput(context); // Wait for user input

          if (userInput != null) {
            await _saveImage(selectedDeck, userInput["name"]!, userInput["meaning"]!);
          } else {
            _logger.info("User canceled input.");
          }
        }
        setState(() {
          _rectifiedImageBase64 = null;
          selectedDeck = '';
        }); 
      }
    } else {
      _logger.severe("No image picked");
    }
  }

  Future<Map<String, String>?> _getUserInput(BuildContext context) async {
    TextEditingController nameController = TextEditingController();
    TextEditingController meaningController = TextEditingController();
    Completer<Map<String, String>?> completer = Completer<Map<String, String>?>();

    showDialog(
      context: context,
      barrierDismissible: false, // Prevents closing without input
      builder: (context) {
        return AlertDialog(
          title: const Text("Enter Card Details"),
          content: Row(
            children: [
              _displayRectifiedImage(),
              const SizedBox(width: 20,),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 300, child: Column(children: [
                    TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Enter card name (ex: major/Fool, swords/7)',
                    ),
                  ),
                  TextField(
                    controller: meaningController,
                    decoration: const InputDecoration(
                      labelText: 'Enter card meaning',
                    ),
                    keyboardType: TextInputType.multiline,
                    minLines: 1,
                    maxLines: null,
                  ),
                  ],),),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                completer.complete(null); // User canceled
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty && meaningController.text.trim().isNotEmpty) {
                  completer.complete({
                    "name": nameController.text.trim(),
                    "meaning": meaningController.text.trim()
                  });
                  Navigator.of(context).pop();
                }
              },
              child: const Text("Submit"),
            ),
          ],
        );
      },
    );

    setState(() {
      _path = null;
    });

    return completer.future; // Wait until user submits or cancels
  }

  Future<List<List<double>>> _getEdges(String path) async {
    final bytes = await File(path).readAsBytes();
    final base64Image = base64Encode(bytes);

    final edges = await _python.getEdges(base64Image);
    _logger.info("Edges: $edges");
    return edges;
  }

  void _navigateToEditor(BuildContext context) async {
    dynamic edges = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditorPage(imagePath: _path!, imageEdges: _getEdges(_path!))),
    );
    _sendImageToBackend(_path!, edges);
  }

  Future<void> _sendImageToBackend(String path, List<List<double>>? edges) async {
    _logger.info("Starting manipulation...");
    setState(() {
      isLoading = true;
    });

    _logger.info("Using image: $path");
    final bytes = await File(path).readAsBytes();
    final base64Image = base64Encode(bytes);
    final processedImg = await _python.processImage(edges, base64Image);
    final sanitized = processedImg.replaceAll(RegExp(r'\s'), '');
    setState(() {
      _rectifiedImageBase64 = sanitized;
      isLoading = false;
    });
  }

  Widget buildLoadingIndicator() {
    if (isLoading) {
      return const CircularProgressIndicator();
    }
    return SizedBox.shrink();
  }

 Widget _displayRectifiedImage() {
    if (isLoading) {
      // Show a loading indicator if the image is still being processed.
      return buildLoadingIndicator();
    } else if (_rectifiedImageBase64 != null && _rectifiedImageBase64!.isNotEmpty) {
      
      return SizedBox(
        width: 300,
        height: 400,
        child: Image.memory(
          base64Decode(_rectifiedImageBase64!),
          fit: BoxFit.contain,
        ),
      );
    } else {
      return const Text('No rectified image available.', textAlign: TextAlign.center,);
    }
  }

  Future<void> _saveImage(String deck, String card, String meaning) async {
    try {
      String imagePath = '${direc!.path}$deck/${card.split('/').first}/';
      card = card.split('/').last;

      // Create decks and deck folder if doesnt exist
      Directory folderDir = Directory(imagePath);
      if (!(await folderDir.exists())) {
        _logger.info('Creating $imagePath');
        await folderDir.create(recursive: true);
      }
   
      File destinationFile = File('$imagePath$card.jpg');
      File txtFile = File('$imagePath$card.txt');

      if (_rectifiedImageBase64 != null) {
        Uint8List imageBytes = base64Decode(_rectifiedImageBase64!);
        await destinationFile.writeAsBytes(imageBytes);
        await txtFile.writeAsString(meaning);

        _logger.info('Image saved successfully at: ${destinationFile.path}');
      }
    } catch (e) {
      _logger.severe('Error saving image: $e');
    }
  }

  Future<void> _openCamera() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      _logger.info('Camera image selected: ${image.path}');
      setState(() {
        _path = image.path;
      });
    } else {
      _logger.info('Camera image selection canceled');
    }
  }

  void _showDropdownMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext ctx) {
        return Wrap(
          children: [
            if (!Platform.isMacOS && !Platform.isLinux && !Platform.isWindows) ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Camera'),
              onTap: () {
                Navigator.pop(ctx); // Close menu
                _openCamera(); 
              },
            ),
            ListTile(
              leading: Icon(Icons.image),
              title: Text('Choose File'),
              onTap: () {
                Navigator.pop(ctx); // Close menu
                _pickImage(); 
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text('Home'),
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
  
  Widget body() {
    return Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center, 
          crossAxisAlignment: CrossAxisAlignment.center, 
          children: [
            // Original image
            SizedBox(
              width: 300, 
              child: _path != null ? Image.file(File(_path!)) : const Text("No image picked.", textAlign: TextAlign.center,),
            ),
            const SizedBox(width:50),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (selectedDeck != '' && selectedDeck != 'Add new deck')
                  // Camera or file picker
                  ElevatedButton(
                    onPressed: () => _showDropdownMenu(context),
                    child: const Text('Pick Image'),
                  ),
                const SizedBox(height: 10,),
                if (_path != null) 
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center, 
                    children: [
                      // Manual editor
                      ElevatedButton(
                        onPressed: () => _navigateToEditor(context),
                        child: const Text('Manual'),
                      ),
                      const SizedBox(width: 20), 
                      // Autodetect
                      ElevatedButton(
                        onPressed: () => _sendImageToBackend(_path!, null),
                        child: const Text('Auto detection'),
                      ),
                    ],
                  ),
                const SizedBox(height: 5,),
                // Select deck
                DropdownButton<String>(
                  value: selectedDeck.isEmpty ? null : selectedDeck, 
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedDeck = newValue ?? '';  
                    });
                  },
                  items: dropdownOptions.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  hint: const Text("Deck"),
                ),
                if (selectedDeck=='')
                  const Text('Please select or make a deck'),
                if (selectedDeck == 'Add new deck')
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Container(
                          width: 150, 
                          child: TextField(
                            controller: newDeckController,
                            decoration: const InputDecoration(
                              labelText: 'Enter deck name',
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () {
                            String newDeck = newDeckController.text.trim();
                            if (newDeck.isNotEmpty && !dropdownOptions.contains(newDeck)) {
                              setState(() {
                                dropdownOptions.insert(dropdownOptions.length - 1, newDeck); 
                                selectedDeck = newDeck; 
                              });
                              newDeckController.clear(); 
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter a valid deck name')),
                              );
                            }
                          },
                          child: const Text('Add Deck'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // When deck selected and rectified image available ...
                  if (selectedDeck!='Add new deck' && selectedDeck!='' && _rectifiedImageBase64!=null) Column(children:[
                    Row( children: [
                      // Enter card name
                      Container(
                        width: 300, // Adjust this width based on your layout
                        child: TextField(
                          controller: newCardController,
                          decoration: const InputDecoration(
                            labelText: 'Enter card name (ex: major/Fool, swords/7)',
                          ),
                        ),
                    ),
                    const SizedBox(width: 30,),
                    // Save rectified image
                    ElevatedButton(
                      onPressed: () {
                        cardName = newCardController.text.trim();
                        cardMeaning = meaningController.text.trim();
                        newCardController.clear();
                        meaningController.clear();
                        if (cardName!=null && cardMeaning!=null) _saveImage(selectedDeck, cardName!, cardMeaning!);
                        else showText = true;
                      },
                      child: const Text("Save")),
                    ],),
                    const SizedBox(height: 10,),
                    Container(
                      width: 400, 
                      child: TextField(
                        keyboardType: TextInputType.multiline,
                        minLines: 1,
                        maxLines: null,
                        controller: meaningController,
                        decoration: const InputDecoration(
                          labelText: 'Enter card meaning',
                        ),
                      ),
                    ),
                  ]),
                  if (showText) const Text("Please enter a card name and/or meaning"),
              ],
            ),
            const SizedBox(width:50),
            // Show rectified image
            SizedBox(
              width: 300,
              child: _displayRectifiedImage(),
            ),
          ],
        ),
      );
  } 
}