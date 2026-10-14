import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:barakah40_flutter/app/theme/app_theme.dart';
import 'package:barakah40_flutter/features/home/domain/services/day_part.dart';
import 'package:barakah40_flutter/features/home/presentation/providers/home_providers.dart';
import 'package:barakah40_flutter/features/social/data/firestore_social_repository.dart';
import 'package:barakah40_flutter/features/social/domain/social_repository.dart';
import 'package:barakah40_flutter/features/social/presentation/providers/social_providers.dart';
import 'package:barakah40_flutter/features/social/presentation/screens/chat_screen.dart';
import 'package:barakah40_flutter/features/social/presentation/screens/community_screen.dart';

// Two accounts sharing one in-memory Firestore, each with its own UI.
void main() {
  const amina = SocialIdentity(uid: 'a1', name: 'أمينة', email: 'amina@x.com');
  const huda = SocialIdentity(uid: 'h1', name: 'هدى', email: 'huda@x.com');

  late FakeFirebaseFirestore db;
  late FirestoreSocialRepository repo;

  setUpAll(() async => initializeDateFormatting('ar'));

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = FirestoreSocialRepository(firestore: db);
    await repo.publishProfile(amina);
    await repo.publishProfile(huda);
  });

  Future<void> pumpAs(
    WidgetTester tester,
    SocialIdentity me,
    Widget screen,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        // A fresh scope per account, like two phones.
        key: ValueKey(me.uid),
        overrides: [
          socialRepositoryProvider.overrideWithValue(repo),
          socialIdentityProvider.overrideWithValue(me),
          dayPeriodProvider.overrideWithValue(DayPart.morning),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ar'),
          home: Directionality(textDirection: TextDirection.rtl, child: screen),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('search, invite, accept and chat between two accounts', (
    tester,
  ) async {
    // Amina finds Huda and sends an invite.
    await pumpAs(tester, amina, const CommunityScreen());
    expect(find.textContaining('لا صديقات بعد'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('userSearchField')), 'hud');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('هدى'), findsOneWidget);

    await tester.tap(find.text('إضافة'));
    await tester.pumpAndSettle();
    expect(find.text('أُرسل الطلب إلى هدى'), findsOneWidget);
    expect(find.text('إلغاء الطلب'), findsOneWidget);
    expect(find.text('طلبات مرسلة (1)'), findsOneWidget);

    // Huda sees it as incoming and accepts.
    await pumpAs(tester, huda, const CommunityScreen());
    await tester.tap(find.text('طلبات واردة'));
    await tester.pumpAndSettle();
    expect(find.text('أمينة'), findsOneWidget);
    await tester.tap(find.text('قبول'));
    await tester.pumpAndSettle();
    expect(find.text('تمّت إضافة أمينة'), findsOneWidget);
    expect(find.text('لا طلبات صداقة واردة.'), findsOneWidget);

    // Amina now has a friend and nothing pending.
    await pumpAs(tester, amina, const CommunityScreen());
    expect(find.text('صديقاتي (1)'), findsOneWidget);
    expect(find.text('طلبات مرسلة'), findsOneWidget);

    // Huda writes; Amina sees the message, the preview and the unread badge.
    final id = await repo.openDirectConversation(huda, 'a1', 'أمينة');
    await pumpAs(tester, huda, ChatScreen(conversationId: id));
    await tester.enterText(
      find.byKey(const Key('messageComposer')),
      'السلام عليكم يا أمينة',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('sendMessageButton')));
    await tester.pumpAndSettle();
    expect(find.text('السلام عليكم يا أمينة'), findsOneWidget);
    final composer = tester.widget<TextField>(
      find.byKey(const Key('messageComposer')),
    );
    expect(composer.controller!.text, isEmpty);

    await pumpAs(tester, amina, const CommunityScreen(initialTab: 1));
    expect(find.text('هدى'), findsOneWidget);
    expect(find.text('السلام عليكم يا أمينة'), findsOneWidget);
    expect(find.text('1'), findsWidgets); // unread badge

    // Opening the chat marks it read.
    await pumpAs(tester, amina, ChatScreen(conversationId: id));
    expect(find.text('السلام عليكم يا أمينة'), findsOneWidget);
    final conv = await tester.runAsync(() => repo.watchConversation(id).first);
    expect(conv!.unreadFor('a1'), 0);
  });

  testWidgets('chat is read-only once the friendship is removed', (
    tester,
  ) async {
    await repo.sendFriendRequest(amina, (await repo.fetchProfile('h1'))!);
    await repo.acceptFriendRequest(
      huda,
      (await repo.watchIncomingRequests('h1').first).single,
    );
    final id = await repo.openDirectConversation(amina, 'h1', 'هدى');
    await repo.unfriend('a1', 'h1');

    await pumpAs(tester, amina, ChatScreen(conversationId: id));
    expect(find.byKey(const Key('messageComposer')), findsNothing);
    expect(find.byKey(const Key('sendMessageButton')), findsNothing);
    expect(find.textContaining('لم تعودا صديقتين'), findsOneWidget);
  });
}
