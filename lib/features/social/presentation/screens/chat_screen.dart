import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:barakah40_flutter/app/router/app_routes.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/core/logging/app_logger.dart';
import 'package:barakah40_flutter/features/social/domain/social_repository.dart';
import 'package:barakah40_flutter/features/social/presentation/providers/social_providers.dart';
import 'package:barakah40_flutter/features/social/presentation/widgets/message_thread_view.dart';
import 'package:barakah40_flutter/features/social/presentation/widgets/social_widgets.dart';

/// One-to-one conversation with a friend.
class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.barakahColors;
    final me = ref.watch(socialIdentityProvider)?.uid ?? '';
    final conv = ref.watch(conversationProvider(conversationId));
    final friends = ref.watch(friendsProvider).valueOrNull;
    final stillFriends =
        friends == null || friends.any((f) => f.id == conversationId);

    void markRead() {
      final c = conv.valueOrNull;
      if (c == null || c.unreadFor(me) == 0) return;
      ref
          .read(socialRepositoryProvider)
          .markConversationRead(me, conversationId)
          .catchError((Object e) => AppLogger.warning('markRead failed: $e'));
    }

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.surface,
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.community),
        ),
        titleSpacing: 0,
        centerTitle: false,
        title: conv.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const Text('محادثة'),
          data: (c) => c == null
              ? const Text('محادثة')
              : Row(
                  children: [
                    SocialAvatar(
                      uid: c.otherUid(me),
                      name: c.otherName(me),
                      size: 36,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        c.otherName(me),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
      body: conv.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: RetryNote(
              message: 'لا يمكن فتح هذه المحادثة.',
              onRetry: () =>
                  ref.invalidate(conversationProvider(conversationId)),
            ),
          ),
        ),
        data: (c) => c == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: EmptyNote(message: 'هذه المحادثة غير موجودة.'),
                ),
              )
            : MessageThreadView(
                thread: ThreadRef.direct(conversationId),
                onMessagesSeen: markRead,
                canSend: stillFriends,
                disabledHint:
                    'لم تعودا صديقتين، لذا لا يمكن إرسال رسائل جديدة.',
              ),
      ),
    );
  }
}
