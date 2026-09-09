import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multichannel_flutter_sample/two_channels_screen.dart';

void main() {
  testWidgets('two channel widgets can coexist in one app', (tester) async {
    final parentContainer = ProviderContainer();
    addTearDown(parentContainer.dispose);

    await tester.pumpWidget(
      ProviderScope(
        parent: parentContainer,
        child: TwoChannelsDemo(parentContainer: parentContainer),
      ),
    );

    // Kedua channel ter-render (TabBar).
    expect(find.text('Channel A'), findsOneWidget);
    expect(find.text('Channel B'), findsOneWidget);

    // Tidak ada exception selama render kedua channel sekaligus.
    expect(tester.takeException(), isNull);

    // Pindah ke tab B — channel kedua juga harus ter-render normal,
    // tanpa exception (dulu bug: SDK instance & session tertimpa antar
    // channel, yang bisa bikin channel kedua gagal initiate).
    await tester.tap(find.text('Channel B'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Channel B'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Dispose tree lalu flush timer yang tersisa (mis. retry/backoff dari
    // provider), supaya test tidak gagal karena "Timer is still pending".
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  });
}
