import 'dart:io';
import 'package:flutter/material.dart';

class EditorPage extends StatefulWidget {
  final String imagePath;
  final Future<List<List<double>>> imageEdges;

  EditorPage({super.key, required this.imagePath, required this.imageEdges});

  @override
  _EditorPageState createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  List<Offset> corners = [];
  double imageWidth = 1, imageHeight = 1;
  double displayWidth = 300, displayHeight = 400;
  double scaleX = 1, scaleY = 1;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
    widget.imageEdges.then((data) {
      setState(() {
        corners = data.map((point) => _scalePoint(Offset(point[0], point[1]))).toList();
      });
    });
  }

  void _loadImageSize() {
    final image = Image.file(File(widget.imagePath));
    image.image.resolve(ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        setState(() {
          imageWidth = info.image.width.toDouble();
          imageHeight = info.image.height.toDouble();

          scaleX = displayWidth / imageWidth;
          scaleY = displayHeight / imageHeight;

          if (corners.isNotEmpty) {
            corners = corners.map((point) => _scalePoint(point)).toList();
          }
        });
      }),
    );
  }

  Offset _scalePoint(Offset point) {
    return Offset(point.dx * scaleX, point.dy * scaleY);
  }

  Offset getMidpoint(Offset a, Offset b) {
    return Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
  }

  void _updateCorner(int index, Offset newPosition) {
    setState(() {
      double dx = newPosition.dx.clamp(0, displayWidth);
      double dy = newPosition.dy.clamp(0, displayHeight);
      corners[index] = Offset(dx, dy);
    });
  }

  List<List<double>> getPointsAsList() {
  return corners.map((corner) {
    // Reverse the scaling before passing to the backend
    double dx = corner.dx / scaleX;
    double dy = corner.dy / scaleY;
    return [dx, dy];
  }).toList();
}

  void _returnPoints() {
    Navigator.pop(context, getPointsAsList());
  }

  Widget _buildDraggablePoint(int index) {
    return Positioned(
      left: corners[index].dx - 10,
      top: corners[index].dy - 10,
      child: GestureDetector(
        onPanUpdate: (details) {
          _updateCorner(index, corners[index] + details.delta);
        },
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manual Editor')),
      body: FutureBuilder<List<List<double>>>(
        future: widget.imageEdges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No edges detected.'));
          } else {
            return Center(
              child: Column(
                children: [
                  const SizedBox(height: 50),
                  SizedBox(
                    height: displayHeight,
                    width: displayWidth,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.file(
                            File(widget.imagePath),
                            fit: BoxFit.cover,
                          ),
                        ),

                        // Draw dynamic quadrilateral overlay
                        if (corners.length == 4)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: QuadrilateralPainter(corners),
                            ),
                          ),

                        // Corner points (draggable)
                        for (int i = 0; i < corners.length; i++)
                          _buildDraggablePoint(i),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _returnPoints,
                    child: const Text("Confirm"),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}

// Custom Painter for Quadrilateral
class QuadrilateralPainter extends CustomPainter {
  final List<Offset> points;

  QuadrilateralPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 4) return;

    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..lineTo(points[3].dx, points[3].dy)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
