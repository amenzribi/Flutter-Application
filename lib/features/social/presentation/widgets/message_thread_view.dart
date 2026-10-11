import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/features/social/domain/social_models.dart';
import 'package:barakah40_flutter/features/social/domain/social_repository.dart';
import 'package:barakah40_flutter/features/social/presentation/providers/social_providers.dart';
import 'package:barakah40_flutter/features/social/presentation/widgets/social_widgets.dart';

/// Real-time message list + composer, shared by direct chats and challenge
/// discussions.
class MessageThreadView extends ConsumerStatefulWidget {
  const MessageThreadView({
    super.key,
    required this.thread,
    this.showSenderNames = false,
    this.onMessagesSeen,
    this.canSend = true,
    this.disabledHint,
  });

  final ThreadRef thread;
  final bool showSenderNames;

  /// Called whenever new messages are displayed (to clear unread counts).
  final VoidCallback? onMessagesSeen;

  final bool canSend;
  final String? disabledHint;

  @override
  ConsumerState<MessageThreadView> createState() => _MessageThreadViewState();
}

class _MessageThreadViewState extends ConsumerState<MessageThreadView> {
  final _controller = TextEditingController();
  int _lastSeenCount = -1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final me = ref.read(socialIdentityProvider);
    final text = _controller.text.trim();
    if (me == null || text.isEmpty) return;
    _controller.clear();
    setState(() {});
    // Not awaited for UI purposes: offline sends stay queued (shown with a
    // clock) and complete when the connection returns. A rejected write
    // rolls back locally and lands in the catch.
    try {
      await ref
          .read(socialRepositoryProvider)
          .sendMessage(me, widget.thread, text);
    } on SocialException catch (e) {
      if (mounted) {
        if (_controller.text.isEmpty) _controller.text = text;
        setState(() {});
        showSocialSnack(context, 'لم تُرسل الرسالة: ${e.message}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider(widget.thread));
    final me = ref.watch(socialIdentityProvider)?.uid ?? '';
    final colors = context.barakahColors;

    final list = messages.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: RetryNote(
            message: 'تعذّر تحميل الرسائل. تحقّقي من الاتصال.',
            onRetry: () => ref.invalidate(messagesProvider(widget.thread)),
          ),
        ),
      ),
      data: (items) {
        if (items.length != _lastSeenCount) {
          _lastSeenCount = items.length;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => widget.onMessagesSeen?.call(),
          );
        }
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: EmptyNote(
                message: widget.showSenderNames
                    ? 'لا رسائل بعد. ابدئي النقاش وشجّعي صديقاتكِ.'
                    : 'لا رسائل بعد. ابدئي المحادثة بالسلام.',
              ),
            ),
          );
        }
        // reverse: newest at the bottom, list anchored to the bottom so the
        // keyboard and new messages keep the latest one in view.
        final reversed = items.reversed.toList();
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          itemCount: reversed.length,
          itemBuilder: (context, i) {
            final m = reversed[i];
            final older = i + 1 < reversed.length ? reversed[i + 1] : null;
            final showDay =
                older == null || !_sameDay(older.createdAt, m.createdAt);
            final showName =
                widget.showSenderNames &&
                m.senderId != me &&
                (older == null || older.senderId != m.senderId || showDay);
            return Column(
              children: [
                if (showDay) _DaySeparator(date: m.createdAt),
                _Bubble(message: m, mine: m.senderId == me, showName: showName),
              ],
            );
          },
        );
      },
    );

    return Column(
      children: [
        Expanded(child: list),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(top: BorderSide(color: colors.line)),
            ),
            child: widget.canSend
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('messageComposer'),
                          controller: _controller,
                          minLines: 1,
                          maxLines: 5,
                          maxLength: ChatMessage.maxLength,
                          textInputAction: TextInputAction.newline,
                          keyboardType: TextInputType.multiline,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'اكتبي رسالة…',
                            counterText: '',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton.filled(
                          key: const Key('sendMessageButton'),
                          tooltip: 'إرسال',
                          style: IconButton.styleFrom(
                            backgroundColor: colors.olive,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _controller.text.trim().isEmpty
                              ? null
                              : _send,
                          // Arrow points left in RTL reading direction.
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      widget.disabledHint ?? '',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.muted),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  static bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return true;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    final d = date;
    final now = DateTime.now();
    String label;
    if (d == null) {
      label = 'الآن';
    } else if (d.year == now.year && d.month == now.month && d.day == now.day) {
      label = 'اليوم';
    } else {
      final y = now.subtract(const Duration(days: 1));
      label = (d.year == y.year && d.month == y.month && d.day == y.day)
          ? 'أمس'
          : DateFormat('d MMMM y', 'ar').format(d);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: colors.line),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11.5, color: colors.inkSoft),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.showName,
  });

  final ChatMessage message;
  final bool mine;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    final bg = mine ? colors.olive : colors.surface;
    final fg = mine ? Colors.white : colors.ink;
    final time = message.createdAt == null
        ? ''
        : DateFormat('h:mm a', 'ar').format(message.createdAt!);
    final status = message.pending ? 'لم تُرسل بعد' : 'أُرسلت';
    // One readable unit for screen readers (sender, text, time, status);
    // SelectableText alone is exposed as a field on some platforms.
    final spoken = [
      mine ? 'أنتِ' : message.senderName,
      message.text,
      if (!message.pending && time.isNotEmpty) time,
      if (mine || message.pending) status,
    ].join('، ');
    // RTL: my messages sit on the start (right) side like in Arabic chat apps.
    return Semantics(
      container: true,
      label: spoken,
      child: ExcludeSemantics(
        child: Align(
          alignment: mine
              ? AlignmentDirectional.centerStart
              : AlignmentDirectional.centerEnd,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 3),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              decoration: BoxDecoration(
                color: bg,
                border: mine ? null : Border.all(color: colors.line),
                borderRadius: BorderRadiusDirectional.only(
                  topStart: const Radius.circular(16),
                  topEnd: const Radius.circular(16),
                  bottomStart: Radius.circular(mine ? 4 : 16),
                  bottomEnd: Radius.circular(mine ? 16 : 4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showName)
                    Text(
                      message.senderName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: legacyAvatarColor(message.senderId),
                      ),
                    ),
                  SelectableText(
                    message.text,
                    style: TextStyle(color: fg, fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.pending ? 'جارٍ الإرسال' : time,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: fg.withValues(alpha: 0.7),
                        ),
                      ),
                      if (mine) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.pending
                              ? Icons.schedule_rounded
                              : Icons.done_rounded,
                          size: 13,
                          color: fg.withValues(alpha: 0.75),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
