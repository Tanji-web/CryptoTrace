import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/widgets/graph/graph_filter_panel.dart';

Widget buildTestApp({
  required GraphFilterState state,
  required ValueChanged<GraphFilterState> onChanged,
  required VoidCallback onReset,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 1100,
          child: StatefulBuilder(
            builder: (context, setState) {
              return GraphFilterPanel(
                state: state,
                onChanged: onChanged,
                onReset: onReset,
              );
            },
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('changes search text and exposes reset action', (tester) async {
    GraphFilterState state = const GraphFilterState();
    var resetCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 1100,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return GraphFilterPanel(
                    state: state,
                    onChanged: (next) => setState(() => state = next),
                    onReset: () => setState(() {
                      state = const GraphFilterState();
                      resetCalled = true;
                    }),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Search wallet or transaction...'), findsOneWidget);
    expect(find.text('Reset'), findsNothing);

    await tester.enterText(find.byType(TextField), '0xabc');
    await tester.pump();

    expect(state.searchQuery, '0xabc');
    expect(find.text('Reset'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pump();

    expect(resetCalled, isTrue);
    expect(state.hasActiveFilters, isFalse);
  });

  testWidgets('updates asset and direction filters', (tester) async {
    GraphFilterState state = const GraphFilterState();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 1100,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return GraphFilterPanel(
                    state: state,
                    onChanged: (next) => setState(() => state = next),
                    onReset: () => setState(() => state = const GraphFilterState()),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('Asset-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ERC-20').last);
    await tester.pump();

    expect(state.assetFilter, 'erc20');

    await tester.tap(find.byKey(const ValueKey('Direction-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Incoming to target').last);
    await tester.pump();

    expect(state.directionFilter, 'incoming');
  });
}
