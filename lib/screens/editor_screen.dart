import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/note.dart';
import '../widgets/drawing_canvas.dart';

class EditorScreen extends StatefulWidget {
  final SamsungNote note;
  const EditorScreen({super.key, required this.note});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  String _selectedFolder = '기본';
  bool _showDrawing = false;
  List<DrawingStroke> _strokes = [];
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  bool _isRecording = false;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note.title);
    _contentCtrl = TextEditingController(text: widget.note.content);
    _selectedFolder = widget.note.folder;
  }

  @override
  void dispose() {
    _saveNote();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  void _saveNote() {
    final service = context.read<NoteService>();
    if (widget.note.title.isEmpty && _titleCtrl.text.isEmpty && _contentCtrl.text.isEmpty) return;
    if (widget.note.title.isEmpty) {
      service.addNote(SamsungNote(
        title: _titleCtrl.text,
        content: _contentCtrl.text,
        folder: _selectedFolder,
        hasDrawing: _showDrawing,
        drawingStrokes: _strokes.map((s) => s.toMap()).toList(),
      ));
    } else {
      service.updateNote(widget.note.id,
        title: _titleCtrl.text,
        content: _contentCtrl.text,
        folder: _selectedFolder,
      );
    }
  }

  Future<void> _pickImage() async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      final ins = _contentCtrl.selection.baseOffset;
      _contentCtrl.text = '${_contentCtrl.text.substring(0, ins)}[IMG:${file.path}]${_contentCtrl.text.substring(ins)}';
      _saveNote();
    }
  }

  Future<void> _importPDF() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null) {
      _contentCtrl.text += '\n[PDF:${result.files.single.path}]';
      _saveNote();
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      _recordingPath = await _recorder.stop();
      _isRecording = false;
      _contentCtrl.text += '\n[REC:$_recordingPath]';
      _saveNote();
    } else {
      if (await _recorder.hasPermission()) {
        await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc));
        _isRecording = true;
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () { _saveNote(); Navigator.pop(context); },
        ),
        title: const Text(''),
        actions: [
          IconButton(icon: Icon(widget.note.isPinned ? Icons.push_pin : Icons.push_pin_outlined, color: Colors.black), onPressed: () {}),
          IconButton(icon: const Icon(Icons.bookmark_border, color: Colors.black), onPressed: () {}),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            itemBuilder: (ctx) => [
              PopupMenuItem(child: const Text('삭제'), onTap: () {
                context.read<NoteService>().deleteNote(widget.note.id);
                Navigator.pop(context);
              }),
              const PopupMenuItem(child: Text('공유')),
              const PopupMenuItem(child: Text('PDF로 저장')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _titleCtrl,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(hintText: '제목', border: InputBorder.none),
              onChanged: (_) => _saveNote(),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.folder_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(_selectedFolder, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const Spacer(),
                Text('${_contentCtrl.text.length}자', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _showDrawing ? _buildDrawingEditor() : _buildTextEditor(),
          ),
          _buildBottomToolbar(),
        ],
      ),
    );
  }

  Widget _buildTextEditor() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _contentCtrl,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(fontSize: 16, height: 1.6),
        decoration: const InputDecoration(hintText: '노트를 작성하세요...', border: InputBorder.none),
        onChanged: (_) => _saveNote(),
      ),
    );
  }

  Widget _buildDrawingEditor() {
    return DrawingCanvas(
      strokes: _strokes,
      onStrokesChanged: (s) => _strokes = s,
    );
  }

  Widget _buildBottomToolbar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _tbBtn(Icons.format_bold, '굵게'),
              _tbBtn(Icons.format_italic, '기울임'),
              _tbBtn(Icons.format_underlined, '밑줄'),
              _tbBtn(Icons.format_list_bulleted, '목록'),
              Container(width: 1, height: 24, color: Colors.grey[300]),
              _tbBtn(_showDrawing ? Icons.text_fields : Icons.draw, _showDrawing ? '텍스트' : '그리기',
                  onTap: () => setState(() => _showDrawing = !_showDrawing)),
              _tbBtn(_isRecording ? Icons.mic : Icons.mic_none, _isRecording ? '중지' : '녹음',
                  onTap: _toggleRecording),
              _tbBtn(Icons.image_outlined, '사진', onTap: _pickImage),
              _tbBtn(Icons.picture_as_pdf, 'PDF', onTap: _importPDF),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tbBtn(IconData icon, String label, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: Colors.grey[700]),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}
