import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/services/mission_service.dart';

class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  final _titleCtrl = TextEditingController();
  final _promptCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadMissions();
  }

  Future<void> _loadMissions() async {
    await MissionService.instance.refresh();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveMission() async {
    final title = _titleCtrl.text.trim();
    final prompt = _promptCtrl.text.trim();
    if (title.isEmpty || prompt.isEmpty) return;

    setState(() => _saving = true);
    await MissionService.instance.addMission(title: title, prompt: prompt);
    _titleCtrl.clear();
    _promptCtrl.clear();
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mission saved. Use with #mission-slug in chats.')),
      );
    }
  }

  Future<void> _deleteMission(String id) async {
    await MissionService.instance.deleteMission(id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final missions = MissionService.instance.missions;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Missions',
            style: TextStyle(color: AppTheme.textH, fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Reusable görev tanımlarını burada kaydet. Chat/Test alanlarında #slug ile çağır.',
            style: TextStyle(color: AppTheme.textM, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    hintText: 'Mission title (e.g. Secure API audit)',
                    filled: true,
                    fillColor: AppTheme.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _promptCtrl,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: 'Mission prompt content...',
                    filled: true,
                    fillColor: AppTheme.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _saveMission,
                    icon: const Icon(Icons.add_task),
                    label: const Text('Save Mission'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (missions.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Text('Henüz mission yok.', style: TextStyle(color: AppTheme.textM)),
            )
          else
            ...missions.map((m) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('#${m.slug}', style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(m.title, style: const TextStyle(color: AppTheme.textH, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              m.prompt,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.textM, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text('Used ${m.useCount}x', style: const TextStyle(color: AppTheme.textM, fontSize: 11)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppTheme.primary),
                        tooltip: 'Delete mission',
                        onPressed: () => _deleteMission(m.id),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
