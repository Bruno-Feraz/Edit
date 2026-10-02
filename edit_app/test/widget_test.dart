import 'package:flutter_test/flutter_test.dart';

import 'package:edit_app/main.dart';
import 'package:edit_app/services/project_store.dart';

void main() {
  testWidgets('Home mostra brand Edit', (tester) async {
    await tester.pumpWidget(EditApp(store: ProjectStore()));
    await tester.pump();
    expect(find.text('Edit'), findsOneWidget);
  });
}
