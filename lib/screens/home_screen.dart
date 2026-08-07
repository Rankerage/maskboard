import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../widgets/note_card.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<NoteService>();
    final results = _query.isNotEmpty ? service.search(_query) : null;
    final pinned = results ?? service.pinnedNotes;
    final unpinned = results != null ? [] : service.unpinnedNotes;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: _isSearching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(hintText: '노트 검색...', border: InputBorder.none),
                onChanged: (v) => setState(() => _query = v)),
              )
            : const Text('Maskboard', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() { _isSearching = !_isSearching; _query = ''; _searchCtrl.clear(); }),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'folder') _showFolderDialog(context, service);
              if (v == 'sync') _syncToCloud(service);
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'folder', child: Text('폴더 관리')),
              const PopupMenuItem(value: 'sort', child: Text('정렬')),
              const PopupMenuItem(value: 'sync', child: Text('클라우드 동기화')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Row(
                children: [
                  _buildFolderChip('전체', service.notes.length, _query.isEmpty),
                  for (final folder in service.folders)
                    _buildFolderChip(folder, service.notesInFolder(folder).length, false),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: unpinned.isEmpty && pinned.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.note_add_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          _query.isNotEmpty ? '검색 결과 없음' : '새 노트를 만들어보세요',
                          style: const TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, childAspectRatio: 0.85,
                      crossAxisSpacing: 10, mainAxisSpacing: 10,
                    ),
                    itemCount: pinned.length + unpinned.length,
                    itemBuilder: (ctx, i) {
                      final note = i < pinned.length ? pinned[i] : unpinned[i - pinned.length];
                      return NoteCard(
                        note: note,
                        isPinned: i < pinned.length,
                        onTap: () => _openNote(note),
                        onTogglePin: () => service.updateNote(note.id, isPinned: !note.isPinned),
                        onDelete: () => service.deleteNote(note.id),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNote(SamsungNote()),
        backgroundColor: const Color(0xFFFFD54F),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.edit),
        label: const Text('새 노트', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildFolderChip(String name, int count, bool selected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text('$name ($count)'),
        selected: selected,
        selectedColor: const Color(0xFFFFD54F),
        backgroundColor: Colors.grey[100],
        onSelected: (_) {},
      ),
    );
  }

  void _openNote(SamsungNote note) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => EditorScreen(note: note)));
  }

  void _showFolderDialog(BuildContext context, NoteService service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('폴더 관리'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final f in service.folders)
              ListTile(
                title: Text(f),
                trailing: f != '기본'
                    ? IconButton(icon: const Icon(Icons.delete, size: 20), onPressed: () { service.deleteFolder(f); Navigator.pop(ctx); })
                    : null,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final ctrl = TextEditingController();
              final name = await showDialog<String>(
                context: ctx,
                builder: (_) => AlertDialog(
                  title: const Text('새 폴더'),
                  content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: '폴더 이름')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(_), child: const Text('취소')),
                    TextButton(onPressed: () => Navigator.pop(_, ctrl.text), child: const Text('추가')),
                  ],
                ),
              );
              if (name != null && name.isNotEmpty) { service.addFolder(name); Navigator.pop(ctx); }
            },
            child: const Text('폴더 추가'),
          ),
        ],
      ),
    );
  }

  void _syncToCloud(NoteService service) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('HermesA 동기화 준비 중...')),
    );
  }
}
