import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../widgets/note_card.dart';
import 'editor_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<NoteService>();
    final pinned = service.pinnedNotes;
    final unpinned = service.unpinnedNotes;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text('Maskboard', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'folder') _showFolderDialog(context, service);
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'folder', child: Text('폴더 관리')),
              const PopupMenuItem(value: 'sort', child: Text('정렬')),
              const PopupMenuItem(value: 'grid', child: Text('보기 방식')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 폴더 탭
          Container(
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Row(
                children: [
                  _buildFolderChip(context, '전체', service.notes.length, true),
                  for (final folder in service.folders)
                    _buildFolderChip(context, folder, service.notesInFolder(folder).length, false),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 노트 그리드
          Expanded(
            child: unpinned.isEmpty && pinned.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.note_add_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('새 노트를 만들어보세요', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: pinned.length + unpinned.length,
                    itemBuilder: (ctx, i) {
                      final note = i < pinned.length ? pinned[i] : unpinned[i - pinned.length];
                      final isPinned = i < pinned.length;
                      return NoteCard(
                        note: note,
                        isPinned: isPinned,
                        onTap: () => _openNote(context, note),
                        onTogglePin: () => service.updateNote(note.id, isPinned: !note.isPinned),
                        onDelete: () => service.deleteNote(note.id),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNote(context, SamsungNote()),
        backgroundColor: const Color(0xFFFFD54F),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.edit),
        label: const Text('새 노트', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildFolderChip(BuildContext context, String name, int count, bool selected) {
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

  void _openNote(BuildContext context, SamsungNote note) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditorScreen(note: note)),
    );
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
                    ? IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        onPressed: () {
                          service.deleteFolder(f);
                          Navigator.pop(ctx);
                        },
                      )
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
                    TextButton(
                      onPressed: () => Navigator.pop(_, ctrl.text),
                      child: const Text('추가'),
                    ),
                  ],
                ),
              );
              if (name != null && name.isNotEmpty) {
                service.addFolder(name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('폴더 추가'),
          ),
        ],
      ),
    );
  }
}
