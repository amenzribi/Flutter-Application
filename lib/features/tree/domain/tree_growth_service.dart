import 'dart:math' as math;

import 'package:barakah40_flutter/core/constants/app_assets.dart';
import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_name.dart';
import 'package:barakah40_flutter/features/prayer/domain/services/prayer_day_key.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/user_app_state.dart';

/// Kinds written to `S.activity[dayKey]` (legacy `markActivity(f)`).
abstract final class TreeActivity {
  static const read = 'read';
  static const prayer = 'prayer';
  static const adhkar = 'adhkar';
  static const tasbih = 'tasbih';
  static const baqarah = 'baqarah';

  /// Kinds that count as "active today" (legacy `dayHasActivity`).
  static const counted = [read, adhkar, tasbih, baqarah];
}

/// What the tree card shows right now.
class TreeDisplay {
  const TreeDisplay({
    required this.stage,
    required this.healthy,
    required this.dormant,
    required this.points,
    required this.nextPercent,
  });

  /// 0..19, index into the 20 grow/wilt images.
  final int stage;

  /// False when a prayer window was missed today, or while dormant.
  final bool healthy;

  /// A whole day passed with no activity: shown as a dry seed (stage 0).
  final bool dormant;
  final int points;

  /// 0..100 progress towards the next stage.
  final int nextPercent;

  String get imageAsset =>
      healthy ? AppAssets.treeGrow(stage) : AppAssets.treeWilt(stage);
  String get label => TreeGrowthService.stageLabels[stage];
  double get vitality => healthy ? 1 : 0.4;
  String get hint => TreeGrowthService.hintFor(this);
}

/// Result of resolving the tree: what to show + the `S.tree` map to persist
/// when it changed (legacy `cappedStage()` saves as a side effect).
class TreeResolution {
  const TreeResolution(this.display, this.updatedTree);

  final TreeDisplay display;

  /// `null` when nothing needs saving.
  final Map<String, dynamic>? updatedTree;
}

/// Exact port of the legacy "شجرة الإنجازات" rules from
/// `Barakah40_Delivery/web/index.html` (TREE_PTS, TREE_TH, computeTreePoints,
/// cappedStage, prayerWiltNow, treeDisplay, treeNextPct, treeHintFor).
/// See docs/TREE_GROWTH.md for the rules in plain language.
abstract final class TreeGrowthService {
  static const pointsPrayer = 10;
  static const pointsChallengeDay = 15;
  static const thresholds = [
    0, 5, 12, 21, 32, 46, 62, 82, 105, 132, //
    162, 196, 234, 276, 322, 372, 426, 484, 546, 612,
  ];

  static const stageLabels = [
    'بذرة', 'بذرة تنبت', 'برعم', 'نبتة صغيرة', 'نبتة مورقة', //
    'شتلة', 'شجيرة', 'شجرة صغيرة', 'شجرة مزهرة', 'شجرة وطائر',
    'شجرة بعشّ', 'عشّ وطائر', 'طائران', 'طيور', 'عشّ وبيض',
    'رعاية البيض', 'طيور تحلّق', 'فرخ يفقس', 'عائلة الطيور', 'شجرة مباركة',
  ];

  // ---------------------------------------------------------------------------
  // Points & stages
  // ---------------------------------------------------------------------------

  /// Legacy `computeTreePoints()`: cumulative over the account's lifetime.
  static int computePoints(UserAppState s) {
    var pts = 0;
    for (final day in s.prayer.log.values) {
      if (day is! Map) continue;
      for (final p in PrayerName.values) {
        if (day[p.key] == true) pts += pointsPrayer;
      }
    }
    pts += s.completed.where((d) => d).length * pointsChallengeDay;
    final pos = (s.lastAyah != null && s.lastAyah != 0)
        ? s.lastAyah!
        : (s.audioPos ?? 0);
    pts += (math.min(pos, 286) / 286 * 40).round();
    var adhkar = 0;
    for (final v in s.adhkarCount.values) {
      if (v is num) adhkar += v.toInt();
    }
    pts += (math.min(adhkar, 400) * 0.4).round();
    pts += (math.min(s.tasbeeh.count, 600) * 0.15).round();
    return pts;
  }

  /// Legacy `treePointsStage(p)`.
  static int stageForPoints(int points) {
    var stage = 0;
    for (var i = 0; i < thresholds.length; i++) {
      if (points >= thresholds[i]) stage = i;
    }
    return stage;
  }

  /// Legacy `treeNextPct()`.
  static int nextPercent(int points) {
    final s = math.min(19, stageForPoints(points));
    final lo = thresholds[s];
    final hi = s + 1 < thresholds.length ? thresholds[s + 1] : lo + 180;
    return (((points - lo) / (hi - lo)) * 100).round().clamp(0, 100);
  }

  // ---------------------------------------------------------------------------
  // Activity
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _activity(UserAppState s) =>
      s.extraMap('activity') ?? const {};

  /// Legacy `dayHasActivity(key)`.
  static bool dayHasActivity(UserAppState s, String dayKey) {
    final a = _activity(s)[dayKey];
    if (a is Map && TreeActivity.counted.any((k) => a[k] == true)) {
      return true;
    }
    final log = s.prayer.log[dayKey];
    return log is Map && PrayerName.values.any((p) => log[p.key] == true);
  }

  /// Legacy `missedDayGap()`: consecutive inactive days before today.
  static int missedDayGap(UserAppState s, DateTime now) {
    var gap = 0;
    var d = DateTime(now.year, now.month, now.day - 1);
    for (var i = 0; i < 90; i++) {
      if (dayHasActivity(s, PrayerDayKey.dayKey(d))) break;
      gap++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return gap;
  }

  /// Legacy `treeActiveALotToday()`: ≥4 prayers or a challenge day today.
  static bool activeALotToday(UserAppState s, DateTime now) {
    final today = PrayerDayKey.dayKey(now);
    final log = s.prayer.log[today];
    final prayed = log is Map
        ? PrayerName.values.where((p) => log[p.key] == true).length
        : 0;
    if (prayed >= 4) return true;
    final completedAt = s.extraMap('completedAt') ?? const {};
    return completedAt.values.any(
      (v) =>
          v is num &&
          PrayerDayKey.dayKey(DateTime.fromMillisecondsSinceEpoch(v.toInt())) ==
              today,
    );
  }

  /// Legacy `prayerWiltNow()`: a prayer whose window has closed today is
  /// still unmarked. Needs today's schedule; without it the tree never wilts.
  static bool prayerWiltNow(UserAppState s, DateTime now) {
    final p = s.prayer;
    final today = PrayerDayKey.dayKey(now);
    if (p.times.isEmpty || p.timesDate != today) return false;
    final log = p.log[today];
    final nowMin = now.hour * 60 + now.minute;
    int? mn(Object? raw) {
      if (raw is! String) return null;
      final parts = raw.split(':');
      if (parts.length < 2) return null;
      final h = int.tryParse(parts[0].trim());
      final m = int.tryParse(parts[1].trim().split(' ').first);
      return h == null || m == null ? null : h * 60 + m;
    }

    const order = PrayerName.values;
    for (var i = 0; i < order.length; i++) {
      final t = mn(p.times[order[i].key]);
      if (t == null) continue;
      int close;
      if (i < 4) {
        close = mn(p.times[order[i + 1].key]) ?? t + 90;
      } else {
        close = 24 * 60 - 1;
      }
      final done = log is Map && log[order[i].key] == true;
      if (nowMin >= close && !done) return true;
    }
    return false;
  }

  /// Legacy `treeVitalityNow()`.
  static double vitalityNow(Map<String, dynamic> tree, DateTime now) {
    final last = tree['lastActive'];
    final lastDay = last is num
        ? DateTime.fromMillisecondsSinceEpoch(last.toInt())
        : now;
    final today = DateTime(now.year, now.month, now.day);
    final lastDate = DateTime(lastDay.year, lastDay.month, lastDay.day);
    final gap = math.max(0, (today.difference(lastDate).inHours / 24).round());
    final base = tree['vitality'] is num
        ? (tree['vitality'] as num).toDouble()
        : 1.0;
    return (base - gap * 0.13).clamp(0.0, 1.0);
  }

  /// Legacy `markActivity(kind)` + `treeAddPoints`: flags today's activity
  /// and refreshes vitality / lastActive. Returns a new state.
  static UserAppState recordActivity(
    UserAppState s,
    String kind,
    DateTime now,
  ) {
    final key = PrayerDayKey.dayKey(now);
    final activity = Map<String, dynamic>.from(_activity(s));
    final day = activity[key] is Map
        ? Map<String, dynamic>.from(activity[key] as Map)
        : <String, dynamic>{};
    day[kind] = true;
    activity[key] = day;

    final tree = _ensureTree(s.extraMap('tree'), now);
    tree['vitality'] = math.min(1.0, vitalityNow(tree, now) + 0.16);
    tree['lastActive'] = now.millisecondsSinceEpoch;

    return s.copyWithExtra('activity', activity).copyWithExtra('tree', tree);
  }

  /// Legacy `ensureTree()` defaults; returns a mutable copy.
  static Map<String, dynamic> _ensureTree(
    Map<String, dynamic>? raw,
    DateTime now,
  ) {
    final t = Map<String, dynamic>.from(raw ?? const {});
    final ms = now.millisecondsSinceEpoch;
    t.putIfAbsent('createdAt', () => ms);
    if (t['points'] is! num) t['points'] = 0;
    if (t['stage'] is! num) t['stage'] = 0;
    if (t['vitality'] is! num) t['vitality'] = 1;
    if (t['lastActive'] is! num) t['lastActive'] = ms;
    if (t['awarded'] is! Map) t['awarded'] = <String, dynamic>{};
    if (t['history'] is! List) t['history'] = <dynamic>[];
    if (t['shownStage'] is! num) t['shownStage'] = -1;
    if (t['stageDay'] is! String) t['stageDay'] = '';
    if (t['grownToday'] is! num) t['grownToday'] = 0;
    if (t['dormant'] is! bool) t['dormant'] = false;
    return t;
  }

  // ---------------------------------------------------------------------------
  // Resolution (legacy cappedStage + treeDisplay)
  // ---------------------------------------------------------------------------

  static TreeResolution resolve(UserAppState s, DateTime now) {
    final original = s.extraMap('tree');
    final t = _ensureTree(original, now);
    final today = PrayerDayKey.dayKey(now);
    final points = computePoints(s);
    final target = stageForPoints(points).clamp(0, 19);
    final activeToday = dayHasActivity(s, today);
    final everActive = points > 0;
    final lapse = !activeToday && everActive && missedDayGap(s, now) >= 1;

    var shown = (t['shownStage'] as num).toInt();
    var grown = (t['grownToday'] as num).toInt();
    var dormant = t['dormant'] as bool;
    var stageDay = t['stageDay'] as String;

    if (shown < 0) {
      shown = lapse ? 0 : target;
      stageDay = today;
      grown = 0;
      dormant = lapse;
    } else {
      if (stageDay != today) {
        stageDay = today;
        grown = 0;
      }
      if (lapse) {
        // A full day without prayer or activity: back to a dry seed.
        shown = 0;
        grown = 0;
        dormant = true;
      } else {
        // Waking from dormancy needs activity today; normal growth follows
        // points, at most 1 stage/day (2 on a very active day).
        if (dormant && activeToday) dormant = false;
        if (!dormant) {
          if (target < shown) {
            shown = target;
          } else if (target > shown) {
            final max = activeALotToday(s, now) ? 2 : 1;
            final can = max - grown;
            if (can > 0) {
              final g = math.min(can, target - shown);
              shown += g;
              grown += g;
            }
          }
        }
      }
    }

    final changed =
        original == null ||
        original['shownStage'] != shown ||
        original['stageDay'] != stageDay ||
        original['grownToday'] != grown ||
        original['dormant'] != dormant;
    t
      ..['shownStage'] = shown
      ..['stageDay'] = stageDay
      ..['grownToday'] = grown
      ..['dormant'] = dormant;

    final stage = shown.clamp(0, 19);
    final wilted = prayerWiltNow(s, now) || dormant;
    return TreeResolution(
      TreeDisplay(
        stage: stage,
        healthy: !wilted,
        dormant: dormant,
        points: points,
        nextPercent: nextPercent(points),
      ),
      changed ? t : null,
    );
  }

  /// Legacy `treeHintFor(d)`.
  static String hintFor(TreeDisplay d) {
    if (d.dormant) {
      return 'مرّ يومٌ كامل دون طاعة، فعادت شجرتكِ بذرةً يابسة — سجّلي صلاتكِ أو وِردكِ اليوم لتُحييها وتنمو من جديد.';
    }
    if (d.healthy) {
      if (d.stage >= 17) {
        return 'ما شاء الله! بلغت شجرتكِ أوجَها وازدهرت — دُمتِ على الطاعة.';
      }
      if (d.stage >= 9) {
        return 'شجرتكِ تكبر وتزدهر وتأوي الطير، واصلي نشاطكِ اليومي.';
      }
      if (d.stage >= 3) return 'أحسنتِ! شجرتكِ بدأت تنمو — استمرّي لتكبر.';
      return 'ابدئي نشاطكِ اليوم لتنبت بذرتكِ وتنمو.';
    }
    return 'شجرتكِ ذابلة بسبب صلاة فائتة — سجّلي صلاتك لتعود خضراء بنفس مرحلتها دون أن تفقدي نموّكِ.';
  }
}
