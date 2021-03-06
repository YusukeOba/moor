import 'package:moor/src/runtime/components/component.dart';
import 'package:test_api/test_api.dart';
import 'package:moor/moor.dart';

import '../data/tables/todos.dart';

void main() {
  test('maps the variable to sql', () {
    final variable =
        Variable(DateTime.fromMillisecondsSinceEpoch(1551297563000));
    final ctx = GenerationContext(TodoDb(null));

    variable.writeInto(ctx);

    expect('?', ctx.sql);
    expect(ctx.boundVariables, [1551297563]);
  });

  test('writes null directly for null values', () {
    final variable = Variable.withString(null);
    final ctx = GenerationContext(TodoDb(null));

    variable.writeInto(ctx);

    expect('NULL', ctx.sql);
    expect(ctx.boundVariables, isEmpty);
  });
}
