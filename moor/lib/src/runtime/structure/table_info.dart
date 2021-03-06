import 'package:moor/moor.dart';
import 'package:moor/src/runtime/expressions/variables.dart';

/// Base class for generated classes. [TableDsl] is the type specified by the
/// user that extends [Table], [DataClass] is the type of the data class
/// generated from the table.
abstract class TableInfo<TableDsl, DataClass> {
  /// Type system sugar. Implementations are likely to inherit from both
  /// [TableInfo] and [TableDsl] and can thus just return their instance.
  TableDsl get asDslTable;

  /// The primary key of this table. Can be null if no custom primary key has
  /// been specified
  Set<GeneratedColumn> get $primaryKey => null;

  /// The table name in the sql table
  String get $tableName;
  List<GeneratedColumn> get $columns;

  /// Validates that the given entity can be inserted into this table, meaning
  /// that it respects all constraints (nullability, text length, etc.).
  /// During insertion mode, fields that have a default value or are
  /// auto-incrementing are allowed to be null as they will be set by sqlite.
  bool validateIntegrity(DataClass instance, bool isInserting);

  /// Maps the given data class to a [Map] that can be inserted into sql. The
  /// keys should represent the column name in sql, the values the corresponding
  /// values of the field.
  ///
  /// If [includeNulls] is true, fields of the [DataClass] that are null will be
  /// written as a [Variable] with a value of null. Otherwise, these fields will
  /// not be written into the map at all.
  Map<String, Variable> entityToSql(DataClass instance,
      {bool includeNulls = false});

  /// Maps the given row returned by the database into the fitting data class.
  DataClass map(Map<String, dynamic> data);
}
