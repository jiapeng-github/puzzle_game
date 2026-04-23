import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/player_model.dart';

/// 数据库帮助类 - 单例模式
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('puzzle_game_v2.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  /// 创建数据库表
  Future<void> _createDB(Database db, int version) async {
    // 角色表（6个固定角色）
    await db.execute('''
      CREATE TABLE players (
        avatar TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        total_score INTEGER DEFAULT 0,
        weekly_score INTEGER DEFAULT 0,
        games_played INTEGER DEFAULT 0,
        wins INTEGER DEFAULT 0,
        gobang_wins INTEGER DEFAULT 0,
        gobang_score INTEGER DEFAULT 0,
        best_2048 INTEGER DEFAULT 0,
        game2048_score INTEGER DEFAULT 0,
        best_match3 INTEGER DEFAULT 0,
        match3_score INTEGER DEFAULT 0,
        best_flying INTEGER DEFAULT 0,
        flying_score INTEGER DEFAULT 0,
        best_sudoku INTEGER DEFAULT 0,
        sudoku_score INTEGER DEFAULT 0,
        best_memory INTEGER DEFAULT 0,
        memory_score INTEGER DEFAULT 0
      )
    ''');

    // 游戏记录表（使用avatar而非player_id）
    await db.execute('''
      CREATE TABLE game_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        avatar TEXT NOT NULL,
        game_type TEXT NOT NULL,
        score INTEGER NOT NULL,
        duration INTEGER NOT NULL,
        is_win INTEGER NOT NULL DEFAULT 0,
        played_at TEXT NOT NULL,
        FOREIGN KEY (avatar) REFERENCES players(avatar)
      )
    ''');

    // 创建索引提升查询性能
    await db.execute('CREATE INDEX idx_records_avatar ON game_records(avatar)');
    await db.execute('CREATE INDEX idx_records_game ON game_records(game_type)');
    await db.execute('CREATE INDEX idx_records_date ON game_records(played_at)');

    // 初始化6个固定角色
    await _initCharacters(db);
  }

  /// 数据库升级
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v1 -> v2: 添加飞行棋、数独、翻牌最高分字段
      await db.execute('ALTER TABLE players ADD COLUMN best_flying INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE players ADD COLUMN best_sudoku INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE players ADD COLUMN best_memory INTEGER DEFAULT 0');
    }
    if (oldVersion < 3) {
      // v2 -> v3: 添加各游戏累计积分字段
      await db.execute('ALTER TABLE players ADD COLUMN gobang_score INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE players ADD COLUMN game2048_score INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE players ADD COLUMN match3_score INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE players ADD COLUMN flying_score INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE players ADD COLUMN sudoku_score INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE players ADD COLUMN memory_score INTEGER DEFAULT 0');
    }
  }

  /// 初始化6个固定角色
  Future<void> _initCharacters(Database db) async {
    final batch = db.batch();
    for (final char in kCharacters) {
      batch.insert('players', {
        'avatar': char['avatar'],
        'name': char['name'],
        'total_score': 0,
        'weekly_score': 0,
        'games_played': 0,
        'wins': 0,
        'gobang_wins': 0,
        'gobang_score': 0,
        'best_2048': 0,
        'game2048_score': 0,
        'best_match3': 0,
        'match3_score': 0,
        'best_flying': 0,
        'flying_score': 0,
        'best_sudoku': 0,
        'sudoku_score': 0,
        'best_memory': 0,
        'memory_score': 0,
      });
    }
    await batch.commit();
  }

  /// 重置本周积分（每周一调用）
  Future<void> resetWeeklyScores() async {
    final db = await database;
    await db.update('players', {'weekly_score': 0});
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
