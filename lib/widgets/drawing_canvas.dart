import 'package:flutter/material.dart';

class DrawingCanvas extends StatefulWidget {
  final List<DrawingStroke> strokes;
  final ValueChanged<List<DrawingStroke>> onStrokesChanged;

  const DrawingCanvas({
    super.key,
    required this.strokes,
    required this.onStrokesChanged,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  DrawingTool _currentTool = DrawingTool.pen;
  Color _currentColor = Colors.black;
  double _strokeWidth = 2.0;
  List<Offset?> _currentStroke = [];
  final List<DrawingStroke> _redoStack = [];

  void _undo() {
    if (widget.strokes.isNotEmpty) {
      _redoStack.add(widget.strokes.removeLast());
      widget.onStrokesChanged(widget.strokes);
      setState(() {});
    }
  }

  void _redo() {
    if (_redoStack.isNotEmpty) {
      widget.strokes.add(_redoStack.removeLast());
      widget.onStrokesChanged(widget.strokes);
      setState(() {});
    }
  }

  void _clear() {
    _redoStack.clear();
    widget.strokes.clear();
    widget.onStrokesChanged(widget.strokes);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: CustomPaint(
                  painter: DrawingPainter(
                    strokes: widget.strokes,
                    currentStroke: _currentStroke,
                    currentColor: _currentColor,
                    currentWidth: _strokeWidth,
                    currentTool: _currentTool,
                  ),
                  size: Size.infinite,
                ),
              ),
              Positioned(
                top: 8, right: 8,
                child: Column(
                  children: [
                    _miniButton(Icons.undo, _undo),
                    const SizedBox(height: 4),
                    _miniButton(Icons.redo, _redo),
                    const SizedBox(height: 4),
                    _miniButton(Icons.delete_outline, _clear),
                  ],
                ),
              ),
            ],
          ),
        ),
        DrawingToolbar(
          currentTool: _currentTool,
          currentColor: _currentColor,
          strokeWidth: _strokeWidth,
          onToolChanged: (t) => setState(() => _currentTool = t),
          onColorChanged: (c) => setState(() => _currentColor = c),
          onWidthChanged: (w) => setState(() => _strokeWidth = w),
        ),
      ],
    );
  }

  Widget _miniButton(IconData icon, VoidCallback tap) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: tap,
        child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, size: 18)),
      ),
    );
  }

  void _onPanStart(DragStartDetails d) {
    _currentStroke = [d.localPosition];
    setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails d) {
    _currentStroke.add(d.localPosition);
    setState(() {});
  }

  void _onPanEnd(DragEndDetails d) {
    if (_currentStroke.isNotEmpty) {
      widget.strokes.add(DrawingStroke(
        points: List.from(_currentStroke),
        color: _currentTool == DrawingTool.eraser ? Colors.white : _currentColor,
        width: _currentTool == DrawingTool.highlighter ? _strokeWidth * 3 : _strokeWidth,
        tool: _currentTool,
      ));
      widget.onStrokesChanged(widget.strokes);
    }
    _currentStroke = [];
    _redoStack.clear();
    setState(() {});
  }
}

enum DrawingTool { pen, highlighter, eraser, selection }

class DrawingStroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final DrawingTool tool;

  DrawingStroke({
    required this.points,
    required this.color,
    required this.width,
    required this.tool,
  });

  Map<String, dynamic> toMap() => {
        'points': points.map((p) => '${p.dx},${p.dy}').join(';'),
        'color': color.value,
        'width': width,
        'tool': tool.index,
      };

  factory DrawingStroke.fromMap(Map<String, dynamic> map) {
    final pts = (map['points'] as String).split(';').map((s) {
      final p = s.split(',');
      return Offset(double.parse(p[0]), double.parse(p[1]));
    }).toList();
    return DrawingStroke(
      points: pts,
      color: Color(map['color']),
      width: (map['width'] as num).toDouble(),
      tool: DrawingTool.values[map['tool']],
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final List<Offset?> currentStroke;
  final Color currentColor;
  final double currentWidth;
  final DrawingTool currentTool;

  DrawingPainter({
    required this.strokes,
    required this.currentStroke,
    required this.currentColor,
    required this.currentWidth,
    required this.currentTool,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke.points, stroke.color, stroke.width, stroke.tool);
    }
    if (currentStroke.length > 1) {
      final pts = currentStroke.whereType<Offset>().toList();
      _drawStroke(canvas, pts, currentColor, currentWidth, currentTool);
    }
  }

  void _drawStroke(Canvas canvas, List<Offset> pts, Color color, double w, DrawingTool tool) {
    if (pts.length < 2) return;
    final paint = Paint()
      ..color = tool == DrawingTool.highlighter ? color.withOpacity(0.4) : color
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..blendMode = tool == DrawingTool.eraser ? BlendMode.clear : BlendMode.srcOver;

    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 1; i < pts.length - 1; i++) {
      final mid = Offset((pts[i].dx + pts[i + 1].dx) / 2, (pts[i].dy + pts[i + 1].dy) / 2);
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant DrawingPainter old) => true;
}

class DrawingToolbar extends StatelessWidget {
  final DrawingTool currentTool;
  final Color currentColor;
  final double strokeWidth;
  final ValueChanged<DrawingTool> onToolChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onWidthChanged;

  const DrawingToolbar({
    super.key,
    required this.currentTool,
    required this.currentColor,
    required this.strokeWidth,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onWidthChanged,
  });

  final _colors = [Colors.black, Colors.red, Colors.blue, Colors.green, Colors.orange, Colors.purple];
  final _widths = [1.0, 2.0, 4.0, 6.0];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _toolBtn(DrawingTool.pen, Icons.edit),
              _toolBtn(DrawingTool.highlighter, Icons.format_color_text),
              _toolBtn(DrawingTool.eraser, Icons.auto_fix_normal),
            ],
          ),
          const Divider(height: 1),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final c in _colors)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => onColorChanged(c),
                      child: Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: c, shape: BoxShape.circle,
                          border: currentColor.value == c.value
                              ? Border.all(color: Colors.grey, width: 2)
                              : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolBtn(DrawingTool tool, IconData icon) {
    final sel = currentTool == tool;
    return GestureDetector(
      onTap: () => onToolChanged(tool),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: sel ? Colors.grey[200] : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 22, color: sel ? Colors.black : Colors.grey[600]),
      ),
    );
  }
}
