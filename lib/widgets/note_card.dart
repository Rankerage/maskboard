import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';

class NoteCard extends StatelessWidget {
  final SamsungNote note;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  const NoteCard({
    super.key,
    required this.note,
    required this.isPinned,
    required this.onTap,
    required this.onTogglePin,
    required this.onDelete,
  });

  final List<Color> _cardColors = const [
    Color(0xFFFFF9C4),
    Color(0xFFF3E5F5),
    Color(0xFFE8F5E9),
    Color(0xFFE3F2FD),
    Color(0xFFFFF3E0),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _cardColors[note.id.hashCode.abs() % _cardColors.length];
    final dateStr = DateFormat('yy.MM.dd').format(note.updatedAt);

    return GestureDetector(
      onTap: onTap,
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
                  title: Text(isPinned ? '고정 해제' : '고정'),
                  onTap: () { onTogglePin; Navigator.pop(ctx); },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('삭제', style: TextStyle(color: Colors.red)),
                  onTap: () { onDelete(); Navigator.pop(ctx); },
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    note.title.isEmpty ? '새 노트' : note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                if (isPinned)
                  const Icon(Icons.push_pin, size: 16, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                note.content.isEmpty ? '내용을 입력하세요' : note.content,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ),
            Text(
              dateStr,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
