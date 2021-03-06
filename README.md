# Moor
[![Build Status](https://travis-ci.com/simolus3/moor.svg?token=u4VnFEE5xnWVvkE6QsqL&branch=master)](https://travis-ci.com/simolus3/moor)
[API: ![Generator version](https://img.shields.io/pub/v/moor.svg)](https://pub.dartlang.org/packages/moor)
[Runtime: ![Generator version](https://img.shields.io/pub/v/moor_flutter.svg)](https://pub.dartlang.org/packages/moor_flutter)
[Generator: ![Generator version](https://img.shields.io/pub/v/moor_generator.svg)](https://pub.dartlang.org/packages/moor_generator)

Moor is an easy to use and safe way to persist data for Flutter apps. It features
a fluent Dart DSL to describe tables and will generate matching database code that
can be used to easily read and store your app's data. It also features a reactive
API that will deliver auto-updating streams for your queries.

- [Moor](#moor)
  * [Getting started](#getting-started)
    + [Adding the dependency](#adding-the-dependency)
    + [Declaring tables](#declaring-tables)
    + [Generating the code](#generating-the-code)
  * [Writing queries](#writing-queries)
    + [Select statements](#select-statements)
      - [Where](#where)
      - [Limit](#limit)
      - [Ordering](#ordering)
    + [Updates and deletes](#updates-and-deletes)
    + [Inserts](#inserts)
    + [Custom statements](#custom-statements)
  * [Migrations](#migrations)
  * [TODO-List and current limitations](#todo-list-and-current-limitations)
    + [Limitations (at the moment)](#limitations-at-the-moment)
    + [Planned for the future](#planned-for-the-future)
    + [Interesting stuff that would be nice to have](#interesting-stuff-that-would-be-nice-to-have)

## Getting started
### Adding the dependency
First, let's add moor to your project's `pubspec.yaml`.
```yaml
dependencies:
  moor_flutter:

dev_dependencies:
  moor_generator:
  build_runner: 
```
We're going to use the `moor_flutter` library to specify tables and access the database. The
`moor_generator` library will take care of generating the necessary code so the
library knows how your table structure looks like.

### Declaring tables
You can use the DSL included with this library to specify your libraries with simple
dart code:
```dart
import 'package:moor_flutter/moor_flutter.dart';

// assuming that your file is called filename.dart. This will give an error at first,
// but it's needed for moor to know about the generated code
part 'filename.g.dart'; 

// this will generate a table called "todos" for us. The rows of that table will
// be represented by a class called "Todo".
class Todos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 6, max: 10)();
  TextColumn get content => text().named('body')();
  IntColumn get category => integer().nullable()();
}

// This will make moor generate a class called "Category" to represent a row in this table.
// By default, "Categorie" would have been used because it only strips away the trailing "s"
// in the table name.
@DataClassName("Category")
class Categories extends Table {
  
  IntColumn get id => integer().autoIncrement()();
  TextColumn get description => text()();
}

// this annotation tells moor to prepare a database class that uses both of the
// tables we just defined. We'll see how to use that database class in a moment.
@UseMoor(tables: [Todos, Categories])
class MyDatabase {
  
}
```

__⚠️ Warning:__ Even though it might look like it, the content of a `Table` class does not support full Dart code. It can only
be used to declare the table name, its primary key and columns. The code inside of a table class will never be 
executed. Instead, the generator will take a look at your table classes to figure out how their structure looks like.
This won't work if the body of your tables is not constant. This should not be problem, but please be aware of this as you can't put logic inside these classes.

### Generating the code
Moor integrates with the dart `build` system, so you can generate all the code needed with 
`flutter packages pub run build_runner build`. If you want to continously rebuild the generated code
whever you change your code, run `flutter packages pub run build_runner watch` instead.
After running either command once, the moor generator will have created a class for your
database and data classes for your entities. To use it, change the `MyDatabase` class as
follows:
```dart
@UseMoor(tables: [Todos, Categories])
class MyDatabase extends _$MyDatabase {
  // we tell the database where to store the data with this constructor
  MyDatabase() : super(FlutterQueryExecutor.inDatabaseFolder(path: 'db.sqlite'));

  // you should bump this number whenever you change or add a table definition. Migrations
  // are covered later in this readme.
  @override
  int get schemaVersion => 1; 
}
```
You can ignore the `schemaVersion` at the moment, the important part is that you can
now run your queries with fluent Dart code:
## Writing queries
```dart
// inside the database class:

  // loads all todo entries
  Future<List<Todo>> get allTodoEntries => select(todos).get();

  // watches all todo entries in a given category. The stream will automatically
  // emit new items whenever the underlying data changes.
  Stream<List<TodoEntry>> watchEntriesInCategory(Category c) {
    return (select(todos)..where((t) => t.category.equals(c.id))).watch();
  }
}
```
### Select statements
You can create `select` statements by starting them with `select(tableName)`, where the 
table name
is a field generated for you by moor. Each table used in a database will have a matching field
to run queries against. Any query can be run once with `get()` or be turned into an auto-updating
stream using `watch()`.
#### Where
You can apply filters to a query by calling `where()`. The where method takes a function that
should map the given table to an `Expression` of boolean. A common way to create such expression
is by using `equals` on expressions. Integer columns can also be compared with `isBiggerThan`
and `isSmallerThan`. You can compose expressions using `and(a, b), or(a, b)` and `not(a)`.
#### Limit
You can limit the amount of results returned by calling `limit` on queries. The method accepts
the amount of rows to return and an optional offset.
#### Ordering
You can use the `orderBy` method on the select statement. It expects a list of functions that extract the individual
ordering terms from the table.
```dart
Future<List<TodoEntry>> sortEntriesAlphabetically() {
  return (select(todos)..orderBy([(t) => OrderingTerm(expression: t.title)])).get();
}
```
You can also reverse the order by setting the `mode` property of the `OrderingTerm` to
`OrderingMode.desc`.
### Updates and deletes
You can use the generated `row` class to update individual fields of any row:
```dart
Future moveImportantTasksIntoCategory(Category target) {
  // use update(...).write when you have a custom where clause and want to update
  // only the columns that you specify (here, only "category" will be updated, the
  // title and description of the rows affected will be left unchanged).
  // Notice that you can't set fields back to null with this method.
  return (update(todos)
      ..where((t) => t.title.like('%Important%'))
    ).write(TodoEntry(
      category: target.id
    ),
  );
}

Future update(TodoEntry entry) {
  // using replace will update all fields from the entry that are not marked as a primary key.
  // it will also make sure that only the entry with the same primary key will be updated.
  // Here, this means that the row that has the same id as entry will be updated to reflect
  // the entry's title, content and category. Unlike write, this supports setting columns back
  // to null. As it set's its where clause automatically, it can not be used together with where.
  return update(todos).replace(entry);
}

Future feelingLazy() {
  // delete the oldest nine entries
  return (delete(todos)..where((t) => t.id.isSmallerThanValue(10))).go();
}
```
__⚠️ Caution:__ If you don't explicitly add a `where` clause on updates or deletes, 
the statement will affect all rows in the table!

### Inserts
You can very easily insert any valid object into tables:
```dart
// returns the generated id
Future<int> addTodoEntry(Todo entry) {
  return into(todos).insert(entry);
}
```
All row classes generated will have a constructor that can be used to create objects:
```dart
addTodoEntry(
  Todo(
    title: 'Important task',
    content: 'Refactor persistence code',
  ),
);
```
If a column is nullable or has a default value (this includes auto-increments), the field
can be omitted. All other fields must be set and non-null. The `insert` method will throw
otherwise.

### Custom statements
You can also issue custom queries by calling `customUpdate` for update and deletes and
`customSelect` or `customSelectStream` for select statements. Using the todo example
above, here is a simple custom query that loads all categories and how many items are
in each category:
```dart
class CategoryWithCount {
  final Category category;
  final int count; // amount of entries in this category

  CategoryWithCount(this.category, this.count);
}

// then, in the database class:
Stream<List<CategoryWithCount>> categoriesWithCount() {
    // select all categories and load how many associated entries there are for
    // each category
    return customSelectStream(
        'SELECT *, (SELECT COUNT(*) FROM todos WHERE category = c.id) AS "amount" FROM categories c;',
        readsFrom: {todos, categories}).map((rows) {
      // when we have the result set, map each row to the data class
      return rows
          .map((row) => CategoryWithCount(Category.fromData(row.data, this), row.readInt('amount')))
          .toList();
    });
  }
```
For custom selects, you should use the `readsFrom` parameter to specify from which tables the query is
reading. When using a `Stream`, moor will be able to know after which updates the stream should emit
items. If you're using a custom query for updates or deletes with `customUpdate`, you should also
use the `updates` parameter to let moor know which tables you're touching.

## Migrations
Moor provides a migration API that can be used to gradually apply schema changes after bumping
the `schemaVersion` getter inside the `Database` class. To use it, override the `migration`
getter. Here's an example: Let's say you wanted to add a due date to your todo entries:
```dart
class Todos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 6, max: 10)();
  TextColumn get content => text().named('body')();
  IntColumn get category => integer().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()(); // we just added this column
}
```
We can now change the `database` class like this:
```dart
  @override
  int get schemaVersion => 2; // bump because the tables have changed

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) {
      return m.createAllTables();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from == 1) {
        // we added the dueDate property in the change from version 1
        await m.addColumn(todos, todos.dueDate);
      }
    }
  );

  // rest of class can stay the same
```
You can also add individual tables or drop them. You can't use the high-level query API in
migrations. If you need to use it, please specify the `onFinished` method on the 
`MigrationStrategy`. It will be called after a migration happened and it's safe to call methods
on your database from inside that method.

### Extracting functionality with DAOs
When you have a lot of queries, putting them all into one class quickly becomes
tedious. You can avoid this by extracting some queries into classes that are 
available from your main database class. Consider the following code:
```dart
part 'todos_dao.g.dart';

// the _TodosDaoMixin will be created by moor. It contains all the necessary
// fields for the tables. The <MyDatabase> type annotation is the database class
// that should use this dao.
@UseDao(tables: [Todos])
class TodosDao extends DatabaseAccessor<MyDatabase> with _TodosDaoMixin {
  // this constructor is required so that the main database can create an instance
  // of this object.
  TodosDao(MyDatabase db) : super(db);

  Stream<List<TodoEntry>> todosInCategory(Category category) {
    if (category == null) {
      return (select(todos)..where((t) => isNull(t.category))).watch();
    } else {
      return (select(todos)..where((t) => t.category.equals(category.id)))
          .watch();
    }
  }
}
```
If we now change the annotation on the `MyDatabase` class to `@UseMoor(tables: [Todos, Categories], daos: [TodosDao])`
and re-run the code generation, a generated getter `todosDao` can be used to access the instance of that dao.

## TODO-List and current limitations
### Limitations (at the moment)
Please note that a workaround for most on this list exists with custom statements.

- No joins
- No `group by` or window functions

### Planned for the future
These aren't sorted by priority. If you have more ideas or want some features happening soon,
let me know by creating an issue!
- Simple `COUNT(*)` operations (group operations will be much more complicated)
- Support default values and expressions
- Support more Datatypes: We should at least support `Uint8List` out of the box,
supporting floating / fixed point numbers as well would be awesome
- Support Dart VM apps
- References
  - DSL API
  - Support in generator
  - Validation
- Table joins
- Bulk inserts
- Custom column constraints
- When inserts / updates fail, explain why that happened
### Interesting stuff that would be nice to have
Implementing this will very likely result in backwards-incompatible changes.

- Find a way to hide implementation details from users while still making them
  accessible for the generated code
- `GROUP BY` grouping functions 
- Support for different database engines
  - Support webapps via `AlaSQL` or a different engine
