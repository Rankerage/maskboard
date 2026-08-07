import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';

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
      ));
    } else {
      service.updateNote(widget.note.id,
        title: _titleCtrl.text,
        content: _contentCtrl.text,
        folder: _selectedFolder,
      );
    }
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
          onPressed: () {
            _saveNote();
            Navigator.pop(context);
          },
        ),
        title: const Text(''),
        actions: [
          IconButton(icon: const Icon(Icons.push_pin_outlined, color: Colors.black), onPressed: () {}),
          IconButton(icon: const Icon(Icons.bookmark_border, color: Colors.black), onPressed: () {}),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            itemBuilder: (ctx) => [
              PopupMenuItem(
                child: const Text('삭제'),
                onTap: () {
                  context.read<NoteService>().deleteNote(widget.note.id);
                  Navigator.pop(context);
                },
              ),
              const PopupMenuItem(child: Text('공유')),
              const PopupMenuItem(child: Text('PDF로 저장')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 제목
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _titleCtrl,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                hintText: '제목',
                border: InputBorder.none,
              ),
              onChanged: (_) => _saveNote(),
            ),
          ),
          const Divider(height: 1),
          // 폴더 선택
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.folder_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _selectedFolder,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const Spacer(),
                Text(
                  '${_contentCtrl.text.length}자',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 본문
          Expanded(
            child: _showDrawing ? _buildDrawingCanvas() : _buildTextEditor(),
          ),
          // 하단 툴바
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
        decoration: const InputDecoration(
          hintText: '노트를 작성하세요...',
          border: InputBorder.none,
        ),
        onChanged: (_) => _saveNote(),
      ),
    );
  }

  Widget _buildDrawingCanvas() {
    return Container(
      color: Colors.grey[50],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.draw, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            Text(
              '펜으로 그리기',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      ),
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
              _toolbarButton(Icons.format_bold, '굵게'),
              _toolbarButton(Icons.format_italic, '기울임'),
              _toolbarButton(Icons.format_underlined, '밑줄'),
              _toolbarButton(Icons.format_list_bulleted, '목록'),
              Container(width: 1, height: 24, color: Colors.grey[300]),
              _toolbarButton(
                _showDrawing ? Icons.text_fields : Icons.draw,
                _showDrawing ? '텍스트' : '그리기',
                onTap: () => setState(() => _showDrawing = !_showDrawing),
              ),
              _toolbarButton(Icons.mic_none, '녹음'),
              _toolbarButton(Icons.image_outlined, '사진'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbarButton(IconData icon, String label, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: Colors.grey[700]),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}
