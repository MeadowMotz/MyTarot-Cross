import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart' show rootBundle;

class PythonInterface {
  Future<String> compilePythonToNative(String pythonCode) async {
    if (Platform.isAndroid || Platform.isIOS) {
      return await _compileMobile(pythonCode);
    } else if (Platform.isWindows) {
      return await _compileWindows(pythonCode);
    } else if (Platform.isMacOS) {
      return await _compileMacOS(pythonCode);
    } else if (Platform.isLinux) {
      return await _compileLinux(pythonCode);
    } else {
      throw UnsupportedError('Unsupported platform for Python compilation');
    }
  }

  Future<String> _compileMobile(String pythonCode) async {
    return Future.value('Mobile compile stub: executed python code length ${pythonCode.length}');
  }

  Future<String> _compileWindows(String pythonCode) async {
    final tempDir = Directory.systemTemp;
    final tempFile = File(p.join(tempDir.path, 'temp_script.py'));

    try {
      await tempFile.writeAsString(pythonCode);
      final result = await Process.run('python', [tempFile.path]);
      await tempFile.delete();

      return result.exitCode == 0
          ? result.stdout.toString()
          : 'Error: ${result.stderr}';
    } catch (e) {
      return 'Exception: $e';
    }
  }

  Future<String> _compileMacOS(String pythonCode) async {
    final tempDir = Directory.systemTemp;
    final tempFile = File(p.join(tempDir.path, 'temp_script.py'));

    try {
      await tempFile.writeAsString(pythonCode);
      final result = await Process.run('python3', [tempFile.path]);
      await tempFile.delete();

      return result.exitCode == 0
          ? result.stdout.toString()
          : 'Error: ${result.stderr}';
    } catch (e) {
      return 'Exception: $e';
    }
  }

  Future<String> _compileLinux(String pythonCode) async {
    final tempDir = Directory.systemTemp;
    final tempFile = File(p.join(tempDir.path, 'temp_script.py'));

    try {
      await tempFile.writeAsString(pythonCode);
      final result = await Process.run('python3', [tempFile.path]);
      await tempFile.delete();

      return result.exitCode == 0
          ? result.stdout.toString()
          : 'Error: ${result.stderr}';
    } catch (e) {
      return 'Exception: $e';
    }
  }

  Future<String> processImage(List<List<double>>? edges, String imgData) async {
    final pythonCode = await rootBundle.loadString('src/python.py');

    // Write the stub runner to call the function
    final callCode = '''
import json
edges = json.loads("""${jsonEncode(edges)}""")
img_data = """$imgData"""
result = process_image_route(edges, img_data)
if result is not None:
  print(result)''';

    final fullCode = '$pythonCode\n$callCode';
    return await compilePythonToNative(fullCode);
  }

  Future<List<List<double>>> getEdges(String imgData) async {
    final pythonCode = await rootBundle.loadString('src/python.py');

    final callCode = '''
import json
img_data = """$imgData"""
result = get_image_edges(img_data)
if result is not None:
  print(json.dumps(result.tolist()))''';

    final fullCode = '$pythonCode\n$callCode';
    final resultString = await compilePythonToNative(fullCode);
    print("result: $resultString");
    final decoded = jsonDecode(resultString);
    print("decoded: $decoded");
    if (decoded is! List) {
      throw FormatException("Expected a list of edges, but got: $decoded");
    }

    try {
      List<List<double>> edges = decoded
        .map<List<double>>(
          (e) => (e as List)
              .map<double>(
                (x) => (x is num) ? x.toDouble() : double.parse(x.toString()),
              )
              .toList(),
        )
        .toList();
      return edges;
    } catch (e) {
      throw FormatException("Failed to parse edge coordinates: $e");
    }
  }
}
