import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class SamsungNote {
  final String id;
  String title;
  String content;
  String folder;
  final DateTime createdAt;
  DateTime updatedAt;
  bool isPinned;
  bool hasDrawing;
  List<String> imagePaths;
  String? pdfPath;
  String? audioPath;
  List<Map<String, dynamic>> drawingStrokes;

  SamsungNote({
    String? id,
    this.title = '',
    this.content = '',
    this.folder = '기본',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isPinned = false,
    this.hasDrawing = false,
    this.imagePaths = const [],
    this.pdfPath,
    this.audioPath,
    this.drawingStrokes = const [],
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'folder': folder,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isPinned': isPinned ? 1 : 0,
        'hasDrawing': hasDrawing ? 1 : 0,
        'imagePaths': jsonEncode(imagePaths),
        'pdfPath': pdfPath ?? '',
        'audioPath': audioPath ?? '',
        'drawingStrokes': jsonEncode(drawingStrokes),
      };

  factory SamsungNote.fromMap(Map<String, dynamic> map) => SamsungNote(
        id: map['id'],
        title: map['title'] ?? '',
        content: map['content'] ?? '',
        folder: map['folder'] ?? '기본',
        createdAt: DateTime.parse(map['createdAt']),
        updatedAt: DateTime.parse(map['updatedAt']),
        isPinned: (map['isPinned'] ?? 0) == 1,
        hasDrawing: (map['hasDrawing'] ?? 0) == 1,
        imagePaths: map['imagePaths'] != null && map['imagePaths'].isNotEmpty
            ? List<String>.from(jsonDecode(map['imagePaths']))
            : [],
        pdfPath: (map['pdfPath'] != null && map['pdfPath'].isNotEmpty) ? map['pdfPath'] : null,
        audioPath: (map['audioPath'] != null && map['audioPath'].isNotEmpty) ? map['audioPath'] : null,
        drawingStrokes: map['drawingStrokes'] != null && map['drawingStrokes'].isNotEmpty
            ? List<Map<String, dynamic>>.from(jsonDecode(map['drawingStrokes']))
            : [],
      );
}

class NoteService extends ChangeNotifier {
  List<SamsungNote> _notes = [];
  Set<String> _folders = {'기본'};

  List<SamsungNote> get notes => List.unmodifiable(_notes);
  Set<String> get folders => Set.unmodifiable(_folders);

  List<SamsungNote> search(String query) {
    final q = query.toLowerCase();
    return _notes.where((n) =>
        n.title.toLowerCase().contains(q) ||
        n.content.toLowerCase().contains(q)).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<SamsungNote> get pinnedNotes =>
      _notes.where((n) => n.isPinned).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  List<SamsungNote> get unpinnedNotes =>
      _notes.where((n) => !n.isPinned).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  List<SamsungNote> notesInFolder(String folder) =>
      _notes.where((n) => n.folder == folder).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  void addNote(SamsungNote note) {
    _notes.insert(0, note);
    notifyListeners();
    _saveNotes();
  }

  void updateNote(String id, {String? title, String? content, String? folder, bool? isPinned}) {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      if (title != null) _notes[idx].title = title;
      if (content != null) _notes[idx].content = content;
      if (folder != null) _notes[idx].folder = folder;
      if (isPinned != null) _notes[idx].isPinned = isPinned;
      _notes[idx].updatedAt = DateTime.now();
      notifyListeners();
      _saveNotes();
    }
  }

  void deleteNote(String id) {
    _notes.removeWhere((n) => n.id == id);
    notifyListeners();
    _saveNotes();
  }

  void addFolder(String name) {
    _folders.add(name);
    notifyListeners();
  }

  void deleteFolder(String name) {
    if (name == '기본') return;
    _folders.remove(name);
    _notes.removeWhere((n) => n.folder == name);
    notifyListeners();
    _saveNotes();
  }

  Future<void> _saveNotes() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/notes.json');
    await file.writeAsString(jsonEncode(_notes.map((n) => n.toMap()).toList()));
  }

  Future<void> loadNotes() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/notes.json');
    if (await file.exists()) {
      final data = jsonDecode(await file.readAsString()) as List;
      _notes = data.map((m) => SamsungNote.fromMap(m)).toList();
      _folders = _notes.map((n) => n.folder).toSet();
      _folders.add('기본');
      notifyListeners();
    }
  }
}
