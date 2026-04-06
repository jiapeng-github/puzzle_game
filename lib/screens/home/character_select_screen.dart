import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/player_model.dart';
import '../../providers/game_provider.dart';
import '../home/home_screen.dart';

/// 角色选择页面 — 首次进入时显示，全部内容在单屏内不滚动
class CharacterSelectScreen extends StatefulWidget {
  const CharacterSelectScreen({super.key});

  @override
  State<CharacterSelectScreen> createState() => _CharacterSelectScreenState();
}

class _CharacterSelectScreenState extends State<CharacterSelectScreen> {
  int _selectedIndex = 0;
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final provider = context.read<GameProvider>();
    final character = kCharacters[_selectedIndex];
    final name = _nameController.text.trim().isEmpty
        ? character['name']!
        : _nameController.text.trim();
    await provider.createPlayer(name, character['avatar']!);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 360;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4FC3F7), Color(0xFFFF7043)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isSmall ? 12 : 24,
              vertical: 8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 标题
                Text(
                  '选择你的角色',
                  style: TextStyle(
                    fontSize: isSmall ? 24 : 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '选一个代表你的小伙伴吧！',
                  style: TextStyle(
                    fontSize: isSmall ? 13 : 15,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),

                // 3×3 角色网格 — 不可滚动，撑满剩余空间
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = 3;
                      final rows = 3;
                      final spacing = isSmall ? 8.0 : 14.0;
                      final itemW =
                          (constraints.maxWidth - spacing * (cols - 1)) / cols;
                      final itemH =
                          (constraints.maxHeight - spacing * (rows - 1)) / rows;

                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: List.generate(kCharacters.length, (index) {
                          final char = kCharacters[index];
                          final selected = index == _selectedIndex;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedIndex = index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: itemW,
                              height: itemH,
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFFFFD54F)
                                      : Colors.transparent,
                                  width: 3,
                                ),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        )
                                      ]
                                    : [],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    char['emoji']!,
                                    style: TextStyle(
                                      fontSize: isSmall ? 28 : 36,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    char['name']!,
                                    style: TextStyle(
                                      fontSize: isSmall ? 11 : 13,
                                      fontWeight: FontWeight.bold,
                                      color: selected
                                          ? const Color(0xFFFF7043)
                                          : Colors.white,
                                    ),
                                  ),
                                  if (selected)
                                    const Text('✓',
                                        style: TextStyle(
                                            color: Color(0xFFFFD54F),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // 名称输入
                SizedBox(
                  height: 48,
                  child: TextField(
                    controller: _nameController,
                    style: TextStyle(
                        fontSize: isSmall ? 14 : 16, color: Colors.white),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 0),
                      hintText:
                          '输入昵称（默认：${kCharacters[_selectedIndex]['name']}）',
                      hintStyle:
                          const TextStyle(color: Colors.white54, fontSize: 14),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon:
                          const Icon(Icons.person, color: Colors.white70),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // 确认按钮
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFFF7043),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      '开始游戏！',
                      style: TextStyle(
                        fontSize: isSmall ? 16 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
