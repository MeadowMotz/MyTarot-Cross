import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:logging/logging.dart'; 
import 'package:my_tarot_cross/EditorPage.dart';

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
  static final Logger _logger = Logger('MyHomePage'); 
  PlatformFile? _image;
  String? _path;
  String? _rectifiedImageBase64;
  bool isLoading = false;

  Future<String?> _getIpAddress() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final info = NetworkInfo();
      return await info.getWifiIP();
    } else {
      return 'IP Address not available on this platform';
    }
  }

  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      if (result.files.isNotEmpty) {
        setState(() {
          _image = result.files.first;
          _path = result.files.first.path;
        });
      }
      else {
        _logger.severe("No image picked");
      }
    }
  }

  Future<List<List<double>>> _getEdges(PlatformFile image) async {
    String path = image.path!;
    final bytes = await File(path).readAsBytes();
    final base64Image = base64Encode(bytes);

    final requestBody = {
      'image': base64Image,
    };

    String? ipAddress = await _getIpAddress();
    if (ipAddress == 'IP Address not available on this platform') {
      ipAddress = 'localhost';
    }

    final response = await http.post(
      Uri.parse('http://$ipAddress:5000/get_points'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['image_edges'] != null) {
        List<List<double>> edges = [];
        for (var point in data['image_edges']) {
          edges.add([point[0].toDouble(), point[1].toDouble()]);
        }
        return edges;
      } else {
        throw Exception('Failed to detect edges');
      }
    } else {
      throw Exception('Failed to get points: ${response.statusCode}');
    }
  }

  void _navigateToEditor(BuildContext context) async {
    dynamic edges = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditorPage(imagePath: _path!, imageEdges: _getEdges(_image!))),
    );
    _sendImageToBackend(_image!, edges);
  }

  Future<void> _sendImageToBackend(PlatformFile image, List<List<double>>? edges) async {
    _logger.info("Starting manipulation...");
    setState(() {
      isLoading = true; // Start loading
    });

    String path = image.path!;
    _logger.info("Using image: $path");
    final bytes = await File(path).readAsBytes();
    final base64Image = base64Encode(bytes);
    final requestBody = {
      'image': base64Image,
      'image_edges': edges
    };

    // Get the dynamic IP address before making the request
    String? ipAddress = await _getIpAddress();
    if (ipAddress == 'IP Address not available on this platform') {
      ipAddress = 'localhost';
    }


    final response = await http.post(
      Uri.parse('http://$ipAddress:5000/process_image'), // Using dynamic IP address
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['processed_image'] != null && data['processed_image'].isNotEmpty) {
        setState(() {
          _rectifiedImageBase64 = data['processed_image'];
        });
      } else {
        _logger.severe("Processed image is null or empty.");
      }
    } else {
      _logger.severe('Failed to process image: ${response.statusCode} - ${response.body}');
    }

    setState(() {
      isLoading = false; // Stop loading
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
      // If no rectified image is available, show an alternative message.
      return const Text('No rectified image available.', textAlign: TextAlign.center,);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center, 
          crossAxisAlignment: CrossAxisAlignment.center, 
          children: [
            SizedBox(
              width: 300, 
              child: _image != null ? Image.file(File(_path!)) : const Text("No image picked.", textAlign: TextAlign.center,),
            ),
            SizedBox(width:50),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ElevatedButton(
                  onPressed: _pickImage,
                  child: const Text('Pick Image'),
                ),
                if (_image != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center, 
                    children: [
                      ElevatedButton(
                        onPressed: () => _navigateToEditor(context),
                        child: const Text('Manual'),
                      ),
                      const SizedBox(width: 20), 
                      ElevatedButton(
                        onPressed: () => _sendImageToBackend(_image!, null),
                        child: const Text('Auto detection'),
                      ),
                    ],
                  ),
              ],
            ),
            SizedBox(width:50),
            SizedBox(
              width: 300,
              child: _displayRectifiedImage(),
            ),
          ],
        ),
      ),
    );
  }
}