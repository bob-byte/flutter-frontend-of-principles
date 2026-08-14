import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/habit.dart';
import '../models/habit_record.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'principles_habits.db');

    return await openDatabase(
      path,
      version: 4, // Incremented version to apply schema changes
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE habits ADD COLUMN targetGoalId INTEGER');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE habits ADD COLUMN isArchived INTEGER DEFAULT 0');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE habits ADD COLUMN reminders TEXT');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE habits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        targetGoal TEXT,
        targetGoalId INTEGER,
        isFlexible INTEGER DEFAULT 1,
        frequency TEXT,
        reminderTime TEXT,
        difficulty INTEGER DEFAULT 5,
        notes TEXT,
        isArchived INTEGER DEFAULT 0,
        reminders TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE habit_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habitId INTEGER NOT NULL,
        date TEXT NOT NULL,
        status INTEGER DEFAULT 0,
        FOREIGN KEY (habitId) REFERENCES habits (id) ON DELETE CASCADE
      )
    ''');
    
    // Індекс для швидкого пошуку по датах (оскільки ми будемо часто запитувати "всі відмітки за цей тиждень")
    await db.execute('CREATE INDEX idx_habit_records_date ON habit_records (date)');
  }

  // --- HABITS (Звички) ---
  Future<int> insertHabit(Habit habit) async {
    final db = await database;
    return await db.insert('habits', habit.toMap());
  }

  Future<void> insertOrUpdateHabitWithBackendId(Habit habit) async {
    final db = await database;
    final existing = await db.query('habits', where: 'id = ?', whereArgs: [habit.id]);
    if (existing.isNotEmpty) {
      await db.update('habits', habit.toMap(), where: 'id = ?', whereArgs: [habit.id]);
    } else {
      await db.insert('habits', habit.toMap());
    }
  }

  Future<List<Habit>> getAllHabits({bool isArchived = false}) async {
    final db = await database;
    final maps = await db.query('habits', where: 'isArchived = ?', whereArgs: [isArchived ? 1 : 0]);
    return maps.map((e) => Habit.fromMap(e)).toList();
  }

  Future<int> updateHabit(Habit habit) async {
    final db = await database;
    return await db.update(
      'habits',
      habit.toMap(),
      where: 'id = ?',
      whereArgs: [habit.id],
    );
  }

  Future<int> deleteHabit(int id) async {
    final db = await database;
    return await db.delete(
      'habits',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- HABIT RECORDS (Відмітки) ---
  
  // Додати, оновити або видалити відмітку на конкретний день (Optimistic UI Update helper)
  Future<void> setHabitRecordStatus(int habitId, DateTime date, HabitStatus status, {bool skipSync = false}) async {
    final db = await database;
    final dateString = date.toIso8601String().substring(0, 10);
    
    final existing = await db.query(
      'habit_records',
      where: 'habitId = ? AND date = ?',
      whereArgs: [habitId, dateString],
    );
    
    if (existing.isNotEmpty) {
      if (status == HabitStatus.none) {
        // Якщо статус "none", ми просто видаляємо запис з бази для економії місця
        await db.delete(
          'habit_records',
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      } else {
        // Оновлюємо хрестик на галочку чи навпаки
        await db.update(
          'habit_records',
          {'status': status.index},
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      }
    } else if (status != HabitStatus.none) {
      // Створюємо новий запис
      await db.insert('habit_records', {
        'habitId': habitId,
        'date': dateString,
        'status': status.index,
      });
    }
  }

  // Отримати всі відмітки за діапазон дат (наприклад, для відмальовки 7 днів на головному екрані)
  Future<List<HabitRecord>> getRecordsForDateRange(DateTime start, DateTime end) async {
    final db = await database;
    final startString = start.toIso8601String().substring(0, 10);
    final endString = end.toIso8601String().substring(0, 10);
    
    final maps = await db.query(
      'habit_records',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startString, endString],
    );
    
    return maps.map((e) => HabitRecord.fromMap(e)).toList();
  }

  Future<List<HabitRecord>> getAllRecordsForHabit(int habitId) async {
    final db = await database;
    final maps = await db.query(
      'habit_records',
      where: 'habitId = ?',
      whereArgs: [habitId],
    );
    return maps.map((e) => HabitRecord.fromMap(e)).toList();
  }
}
