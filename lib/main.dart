import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/game_provider.dart';
import 'screens/home/character_select_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/audio_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 预初始化 AudioService 单例
  AudioService();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const PuzzleApp());
}

class PuzzleApp extends StatelessWidget {
  const PuzzleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameProvider()..loadPlayers(),
      child: MaterialApp(
        title: '益智小游戏',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const _StartRouter(),
      ),
    );
  }
}

/// 启动路由：有玩家 → 首页，无玩家 → 角色选择
class _StartRouter extends StatefulWidget {
  const _StartRouter();

  @override
  State<_StartRouter> createState() => _StartRouterState();
}

class _StartRouterState extends State<_StartRouter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    final provider = context.read<GameProvider>();
    // 等待加载完成
    while (provider.isLoading) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    if (!mounted) return;
    if (provider.allPlayers.isNotEmpty) {
      // 自动选中上一次的玩家（列表中第一个）
      if (provider.currentPlayer == null) {
        provider.selectPlayer(provider.allPlayers.first);
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CharacterSelectScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFFF9E6),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
