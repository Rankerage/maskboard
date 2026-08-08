import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import '../models/note.dart';
import '../widgets/drawing_canvas.dart';
import 'live_share_screen.dart';

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
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  bool _isBullet = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note.title);
    _contentCtrl = TextEditingController(text: _stripFormatTags(widget.note.content));
    _selectedFolder = widget.note.folder;
  }

  String _stripFormatTags(String text) {
    return text.replaceAll('[B]', '').replaceAll('[/B]', '')
        .replaceAll('[I]', '').replaceAll('[/I]', '')
        .replaceAll('[U]', '').replaceAll('[/U]', '');
  }

  @override
  void dispose() {
    _saveNote();
    _titleCtrl.dispose(); _contentCtrl.dispose();
    _recorder.dispose(); _player.dispose();
    super.dispose();
  }

  void _saveNote() {
    final service = context.read<NoteService>();
    if (widget.note.title.isEmpty && _titleCtrl.text.isEmpty && _contentCtrl.text.isEmpty) return;
    if (widget.note.title.isEmpty) {
      service.addNote(SamsungNote(
        title: _titleCtrl.text, content: _contentCtrl.text,
        folder: _selectedFolder, hasDrawing: _showDrawing,
        drawingStrokes: _strokes.map((s) => s.toMap()).toList(),
      ));
    } else {
      service.updateNote(widget.note.id, title: _titleCtrl.text, content: _contentCtrl.text, folder: _selectedFolder);
    }
  }

  void _applyFormat(String tag) {
    final sel = _contentCtrl.selection;
    if (!sel.isValid || sel.start == sel.end) return;
    final text = _contentCtrl.text;
    final selected = text.substring(sel.start, sel.end);
    final formatted = '[$tag]$selected[/$tag]';
    _contentCtrl.text = text.substring(0, sel.start) + formatted + text.substring(sel.end);
    _contentCtrl.selection = TextSelection.collapsed(offset: sel.start + formatted.length);
    _saveNote();
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
      final path = result.files.single.path!;
      _contentCtrl.text += '\n[PDF:$path]';
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

  void _playAudio(String path) {
    if (path.isNotEmpty) _player.play(DeviceFileSource(path));
  }

  void _exportPDF() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF 내보내기 준비 중...')));
  }

  void _shareNote() {
    Share.share('${_titleCtrl.text}\n\n${_contentCtrl.text}', subject: _titleCtrl.text);
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('노트 삭제'),
        content: const Text('이 노트를 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(onPressed: () {
            context.read<NoteService>().deleteNote(widget.note.id);
            Navigator.pop(ctx); Navigator.pop(context);
          }, child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<NoteService>().globalDarkMode;

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF1A1A1A) : Colors.white,
      appBar: AppBar(
        backgroundColor: dark ? const Color(0xFF2D2D2D) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: dark ? Colors.white : Colors.black),
          onPressed: () { _saveNote(); Navigator.pop(context); },
        ),
        title: const Text(''),
        actions: [
          IconButton(icon: const Icon(Icons.people_outline, color: Colors.black), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveShareScreen()))),
          IconButton(icon: Icon(widget.note.isPinned ? Icons.push_pin : Icons.push_pin_outlined, color: Colors.black), onPressed: () {}),
          PopupMenuButton(
            icon: Icon(Icons.more_vert, color: dark ? Colors.white : Colors.black),
            itemBuilder: (ctx) => [
              PopupMenuItem(child: const Text('삭제'), onTap: _confirmDelete),
              PopupMenuItem(child: const Text('공유'), onTap: _shareNote),
              PopupMenuItem(child: const Text('PDF로 저장'), onTap: _exportPDF),
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
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: dark ? Colors.white : Colors.black),
              decoration: InputDecoration(hintText: '제목', border: InputBorder.none, hintStyle: TextStyle(color: dark ? Colors.grey[600] : Colors.grey[400])),
              onChanged: (_) => _saveNote(),
            ),
          ),
          Divider(height: 1, color: dark ? Colors.grey[800] : Colors.grey[200]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(children: [
              Icon(Icons.folder_outlined, size: 16, color: dark ? Colors.grey[500] : Colors.grey),
              const SizedBox(width: 4),
              Text(_selectedFolder, style: TextStyle(color: dark ? Colors.grey[500] : Colors.grey, fontSize: 13)),
              const Spacer(),
              Text('${_contentCtrl.text.length}자', style: TextStyle(color: dark ? Colors.grey[500] : Colors.grey, fontSize: 12)),
            ]),
          ),
          Divider(height: 1, color: dark ? Colors.grey[800] : Colors.grey[200]),
          Expanded(child: _showDrawing ? _buildDrawingEditor() : _buildRichTextEditor(dark)),
          _buildBottomToolbar(dark),
        ],
      ),
    );
  }

  Widget _buildRichTextEditor(bool dark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 콘텐츠 파싱해서 표시
          ..._contentCtrl.text.split('\n').map((line) {
            if (line.startsWith('[IMG:')) {
              final path = line.substring(5, line.length - 1);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(path), fit: BoxFit.contain),
                ),
              );
            }
            if (line.startsWith('[PDF:')) {
              final path = line.substring(5, line.length - 1);
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: Text(path.split('/').last),
                  subtitle: const Text('터치하여 열기'),
                  onTap: () {},
                ),
              );
            }
            if (line.startsWith('[REC:')) {
              final path = line.substring(5, line.length - 1);
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.play_circle, color: Colors.blue),
                  title: const Text('녹음'),
                  subtitle: const Text('터치하여 재생'),
                  onTap: () => _playAudio(path),
                ),
              );
            }
            // 리치텍스트 변환
            String display = line;
            display = display.replaceAllMapped(RegExp(r'\[B\](.*?)\[/B\]'), (m) => '**${m[1]}**');
            display = display.replaceAllMapped(RegExp(r'\[I\](.*?)\[/I\]'), (m) => '*${m[1]}*');
            display = display.replaceAllMapped(RegExp(r'\[U\](.*?)\[/U\]'), (m) => '__${m[1]}__');
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: RichText(
                text: _parseMarkdown(display, dark),
              ),
            );
          }),
          // 실제 입력 필드
          TextField(
            controller: _contentCtrl,
            maxLines: null,
            style: TextStyle(fontSize: 16, height: 1.6, color: dark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: '노트를 작성하세요...',
              border: InputBorder.none,
              hintStyle: TextStyle(color: dark ? Colors.grey[600] : Colors.grey[400]),
            ),
            onChanged: (_) => _saveNote(),
          ),
        ]),
      ),
    );
  }

  TextSpan _parseMarkdown(String text, bool dark) {
    final color = dark ? Colors.white : Colors.black;
    final spans = <TextSpan>[];
    final regex = RegExp(r'(\*\*.*?\*\*|\*.*?\*|__.*?__)');
    int last = 0;
    for (final m in regex.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start), style: TextStyle(color: color)));
      final match = m.group(0)!;
      if (match.startsWith('**')) {
        spans.add(TextSpan(text: match.substring(2, match.length - 2), style: TextStyle(fontWeight: FontWeight.bold, color: color)));
      } else if (match.startsWith('__')) {
        spans.add(TextSpan(text: match.substring(2, match.length - 2), style: TextStyle(decoration: TextDecoration.underline, color: color)));
      } else {
        spans.add(TextSpan(text: match.substring(1, match.length - 1), style: TextStyle(fontStyle: FontStyle.italic, color: color)));
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last), style: TextStyle(color: color)));
    return TextSpan(children: spans);
  }

  Widget _buildDrawingEditor() {
    return DrawingCanvas(strokes: _strokes, onStrokesChanged: (s) => _strokes = s);
  }

  Widget _buildBottomToolbar(bool dark) {
    return Container(
      decoration: BoxDecoration(color: dark ? const Color(0xFF2D2D2D) : Colors.white, border: Border(top: BorderSide(color: dark ? Colors.grey[800]! : Colors.grey[200]!))),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _tbBtn(Icons.format_bold, '굵게', dark, onTap: () { _isBold = !_isBold; _applyFormat('B'); }),
            _tbBtn(Icons.format_italic, '기울임', dark, onTap: () { _isItalic = !_isItalic; _applyFormat('I'); }),
            _tbBtn(Icons.format_underlined, '밑줄', dark, onTap: () { _isUnderline = !_isUnderline; _applyFormat('U'); }),
            _tbBtn(Icons.format_list_bulleted, '목록', dark),
            Container(width: 1, height: 24, color: Colors.grey[600]),
            _tbBtn(_showDrawing ? Icons.text_fields : Icons.draw, _showDrawing ? '텍스트' : '그리기', dark, onTap: () => setState(() => _showDrawing = !_showDrawing)),
            _tbBtn(_isRecording ? Icons.mic : Icons.mic_none, _isRecording ? '중지' : '녹음', dark, onTap: _toggleRecording),
            _tbBtn(Icons.image_outlined, '사진', dark, onTap: _pickImage),
            _tbBtn(Icons.picture_as_pdf, 'PDF', dark, onTap: _importPDF),
          ]),
        ),
      ),
    );
  }

  Widget _tbBtn(IconData icon, String label, bool dark, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: dark ? Colors.grey[400] : Colors.grey[700]),
          Text(label, style: TextStyle(fontSize: 10, color: dark ? Colors.grey[400] : Colors.grey[600])),
        ]),
      ),
    );
  }
}
