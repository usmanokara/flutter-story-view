import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  final String table = 'downloadPath';

  // This is the actual database filename that is saved in the docs directory.
  static const _databaseName = "test.db";

  // Increment this version when you need to change the schema.
  static const _databaseVersion = 1;

  String? _path;

  // Make this a singleton class.
  DatabaseHelper._privateConstructor();

  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // Only allow a single open connection to the database.
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // open the database
  _initDatabase() async {
    // The path_provider plugin gets the right directory for Android or iOS.
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    _path = join("${documentsDirectory.path}/testdb", _databaseName);
    // Open the database. Can also add an onUpdate callback parameter.
    return await openDatabase(_path!,
        version: _databaseVersion, onCreate: _onCreate);
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
              CREATE TABLE $table (
                ColumnId INTEGER PRIMARY KEY,
                UniqueId TEXT,
                LocalPath TEXT
              )
              ''');
  }

  Future<int> insert(String path, String uid) async {
    Database db = await database;
    int id = await db.insert(table, {"UniqueId": uid, "LocalPath": path});
    return id;
  }

  Future<List<Map<String, dynamic>>> queryPath(String uid) async {
    Database db = await database;
    List<Map<String, dynamic>> list =
        await db.query(table, where: "UniqueId = ?", whereArgs: [uid]);
    return list;
  }

  Future deletePathFromDb(String uid) async {
    Database db = await database;

    await db.delete(table, where: "UniqueId = ?", whereArgs: [uid]);
  }
}

class DownloadUtils {
  static Future<File?> download(String url, String id,
      {bool verifyOnly = false,
      String? extension,
      Function(CancelToken cancelToken)? cancelCallBack}) async {
    String path = '';
    DatabaseHelper database = DatabaseHelper.instance;
    List<Map<String, dynamic>> data = [];
    final Dio dio = Dio();
    data = await database.queryPath(url);

    if (data.isEmpty) {
      print("Data: $data");
      final dir = await getApplicationDocumentsDirectory();
      path = "${dir.path}/voice_intro/$id${extension ?? ".wav"}";
      print(path);
      print("file path$path");
      print("Path before download: $path");
      try {
        if (verifyOnly) return null;
        await dio.download(url, path);
      } on DioError catch (e) {
        print("Download Error: $e");
      }
      DatabaseHelper database = DatabaseHelper.instance;
      await database.insert(path, url);

      print("Download completed");
      return File(path);
    }
    path = data[0]['LocalPath'];
    print("Audio Path: $path");
    if (FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound) {
      await database.deletePathFromDb(url);
      final dir = await getApplicationDocumentsDirectory();
      print("audio dir keys: $id$extension");
      path = "${dir.path}/voice_intro/$id.${extension ?? "wav"}";
      print("file path$path");
      print("Path before download: $path");
      try {
        await dio.download(url, path);
      } on DioError catch (e) {
        print("Download Error: $e");
      }
      await database.insert(path, url);
      print("Download completed");
      return File(path);
    }
    return File(path);
    print(
        "file exist: ${FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound}");
  }
}
