import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

void main() {
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
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
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
  PlatformFile? _image; // Store the selected image
  String? _path;
  String? _rectifiedImageBase64; // Store the rectified image in base64

  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);

    if (result != null) {
      setState(() {
        _image = result.files.first;
        _path = result.files.first.path;
      });

      // Send image to Python backend
      await _sendImageToBackend(_image!);
    }
  }

  Future<void> _sendImageToBackend(PlatformFile image) async {
    // Read the image as bytes and encode it to base64
    final bytes = await File(image.path!).readAsBytes();
    final base64Image = base64Encode(bytes);

    // Create a map to send in the HTTP POST request
    final requestBody = {'image': base64Image};

    // Send HTTP POST request to Python server
    final response = await http.post(
      Uri.parse('http://localhost:5000/process_image'),  // URL to local Python server
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      // Parse the response
      final data = jsonDecode(response.body);
      setState(() {
        _rectifiedImageBase64 = data['processed_image'];
      });
    } else {
      print('Failed to process image');
    }
  }

Widget _displayRectifiedImage() {
  if (_rectifiedImageBase64 != null) {
    return SizedBox(
      width: 300,  // Set your desired width
      height: 400, // Set your desired height
      child: Image.memory(
        base64Decode(_rectifiedImageBase64!),
        fit: BoxFit.contain,  // You can change the BoxFit depending on your needs
      ),
    );
  } else {
    return const Text('No rectified image available.');
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text('Pick Image'),
            ),
            _displayRectifiedImage(), 
          ],
        ),
      ),
    );
  }
}
