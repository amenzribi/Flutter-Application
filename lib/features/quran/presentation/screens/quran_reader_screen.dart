import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:barakah40_flutter/app/router/app_routes.dart';
import 'package:barakah40_flutter/app/theme/app_spacing.dart';
import 'package:barakah40_flutter/app/theme/barakah_colors.dart';
import 'package:barakah40_flutter/features/quran/domain/entities/audio_playback_state.dart';
import 'package:barakah40_flutter/features/quran/domain/entities/ayah.dart';
import 'package:barakah40_flutter/features/quran/domain/entities/quran_reading_position.dart';
import 'package:barakah40_flutter/features/quran/presentation/providers/quran_providers.dart';
import 'package:barakah40_flutter/features/quran/presentation/widgets/ayah_verse_tile.dart';
import 'package:barakah40_flutter/features/quran/presentation/widgets/quran_audio_bar.dart';
import 'package:barakah40_flutter/features/user_state/presentation/providers/user_state_providers.dart';
import 'package:barakah40_flutter/shared/widgets/premium_button.dart';
import 'package:barakah40_flutter/shared/widgets/premium_scaffold.dart';

const double _minQscale = 0.8;
const double _maxQscale = 1.8;
const double _qscaleStep = 0.1;

/// Full Al-Baqarah reader: static basmala + all 286 ayah cards, a bottom
/// audio player bar, bookmarking, font-size controls, and jump-to-ayah.
///
/// Never fabricates verses — [baqarahProvider]'s loading/error states are
/// surfaced as-is, with a manual retry on error.
class QuranReaderScreen extends ConsumerStatefulWidget {
  const QuranReaderScreen({super.key, this.continueReading = false});

  /// Set from the `?continue=1` query param (legacy "متابعة القراءة" entry
  /// point). The reader auto-scrolls to the saved position either way once
  /// loaded — this only shortens the legacy 250ms settle delay for the
  /// explicit "continue" entry point.
  final bool continueReading;

  @override
  ConsumerState<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends ConsumerState<QuranReaderScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _jumpController = TextEditingController();
  final Map<int, GlobalKey> _ayahKeys = {};
  bool _autoScrollHandled = false;

  GlobalKey _keyFor(int n) => _ayahKeys.putIfAbsent(n, () => GlobalKey());

  @override
  void dispose() {
    _scrollController.dispose();
    _jumpController.dispose();
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  void _scheduleAutoScroll(int ayah) {
    if (_autoScrollHandled) return;
    _autoScrollHandled = true;
    final delay = widget.continueReading
        ? const Duration(milliseconds: 100)
        : const Duration(milliseconds: 250);
    Future<void>.delayed(delay, () {
      if (!mounted) return;
      _scrollToAyah(ayah);
    });
  }

  void _scrollToAyah(int n) {
    final ctx = _ayahKeys[n]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      alignment: 0.15,
    );
  }

  void _handleJump() {
    final n = int.tryParse(_jumpController.text.trim());
    if (n == null) return;
    final clamped = n.clamp(1, QuranReadingPosition.totalAyahs);
    FocusScope.of(context).unfocus();
    _scrollToAyah(clamped);
  }

  void _adjustFont(double current, double delta) {
    final next = (current + delta).clamp(_minQscale, _maxQscale);
    ref.read(userStateControllerProvider.notifier).setQscale(next);
  }

  void _handlePlayPause(AudioPlaybackState playback, int? effectiveAyah) {
    final controller = ref.read(quranAudioControllerProvider.notifier);
    if (playback.isPlaying) {
      controller.pause();
    } else if (playback.isPaused) {
      controller.resume();
    } else {
      controller.playFrom(effectiveAyah ?? 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncAyahs = ref.watch(baqarahProvider);
    final appState = ref.watch(userAppStateProvider);
    final reciter = ref.watch(currentReciterProvider);
    final playback = ref.watch(quranAudioControllerProvider);
    final effectiveAyah = appState.audioPos ?? appState.lastAyah;

    ref.listen<AsyncValue<List<Ayah>>>(baqarahProvider, (previous, next) {
      next.whenData((_) {
        if (effectiveAyah != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scheduleAutoScroll(effectiveAyah);
          });
        }
      });
    });

    return PremiumScaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: PremiumIconButton(
          icon: Icons.arrow_back,
          tooltip: 'رجوع',
          onPressed: _goBack,
        ),
        title: const Text('سورة البقرة'),
        actions: [
          IconButton(
            tooltip: 'تصغير الخط',
            icon: const Icon(Icons.text_decrease_rounded),
            onPressed: () => _adjustFont(appState.qscale, -_qscaleStep),
          ),
          IconButton(
            tooltip: 'تكبير الخط',
            icon: const Icon(Icons.text_increase_rounded),
            onPressed: () => _adjustFont(appState.qscale, _qscaleStep),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: asyncAyahs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ReaderErrorState(
                onRetry: () => ref.read(baqarahProvider.notifier).refresh(),
              ),
              data: (ayahs) => _ReaderBody(
                ayahs: ayahs,
                qscale: appState.qscale,
                bookmarkedAyah: appState.lastAyah,
                playback: playback,
                scrollController: _scrollController,
                jumpController: _jumpController,
                keyFor: _keyFor,
                onJump: _handleJump,
                onToggleBookmark: (n) => ref
                    .read(userStateControllerProvider.notifier)
                    .toggleLastAyahBookmark(n),
                onPlayFrom: (n) =>
                    ref.read(quranAudioControllerProvider.notifier).playFrom(n),
              ),
            ),
          ),
          QuranAudioBar(
            playback: playback,
            reciterName: reciter.arabicName,
            onPlayPause: () => _handlePlayPause(playback, effectiveAyah),
            onStop: () =>
                ref.read(quranAudioControllerProvider.notifier).stop(),
            onTapReciter: () => context.push(AppRoutes.quranReciter),
          ),
        ],
      ),
    );
  }
}

class _ReaderBody extends StatelessWidget {
  const _ReaderBody({
    required this.ayahs,
    required this.qscale,
    required this.bookmarkedAyah,
    required this.playback,
    required this.scrollController,
    required this.jumpController,
    required this.keyFor,
    required this.onJump,
    required this.onToggleBookmark,
    required this.onPlayFrom,
  });

  final List<Ayah> ayahs;
  final double qscale;
  final int? bookmarkedAyah;
  final AudioPlaybackState playback;
  final ScrollController scrollController;
  final TextEditingController jumpController;
  final GlobalKey Function(int n) keyFor;
  final VoidCallback onJump;
  final ValueChanged<int> onToggleBookmark;
  final ValueChanged<int> onPlayFrom;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: jumpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'اذهب إلى رقم الآية',
                    isDense: true,
                  ),
                  onSubmitted: (_) => onJump(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filled(
                onPressed: onJump,
                icon: const Icon(Icons.north_east_rounded),
                tooltip: 'انتقال',
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            itemCount: ayahs.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _BasmalaHeader(colors: colors);
              }
              final ayah = ayahs[index - 1];
              final isBookmarked = bookmarkedAyah == ayah.n;
              final isPlaying =
                  playback.currentAyah == ayah.n && !playback.isError;
              return KeyedSubtree(
                key: keyFor(ayah.n),
                child: AyahVerseTile(
                  ayah: ayah,
                  qscale: qscale,
                  isBookmarked: isBookmarked,
                  isPlaying: isPlaying,
                  onToggleBookmark: () => onToggleBookmark(ayah.n),
                  onPlayFrom: () => onPlayFrom(ayah.n),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BasmalaHeader extends StatelessWidget {
  const _BasmalaHeader({required this.colors});

  final BarakahColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(
        'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: 'AmiriQuran',
          fontSize: 26,
          color: colors.oliveDeep,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ReaderErrorState extends StatelessWidget {
  const _ReaderErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.barakahColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 40, color: colors.danger),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'تعذّر تحميل سورة البقرة',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'تحققي من اتصال الإنترنت ثم أعيدي المحاولة.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.inkSoft),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            PremiumButton(
              label: 'إعادة المحاولة',
              icon: Icons.refresh_rounded,
              expand: false,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
