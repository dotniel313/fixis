// v1.1.0 - Configuración inicial de Drift (SQLite)
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
// Esta línea dará error temporalmente hasta que corramos el generador de código
part 'app_database.g.dart';

// Definición de la tabla de Trabajos Locales
class LocalJobs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get supabaseId => text().nullable()(); // ID remoto cuando se sincronice
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, in_progress, completed
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))(); // ¿Está sincronizado con Supabase?
}

// Clase principal de la base de datos
@DriftDatabase(tables: [LocalJobs])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

// Función para abrir la conexión a SQLite en el almacenamiento del dispositivo
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'fixis_pro_db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}