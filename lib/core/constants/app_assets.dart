/// Bundled asset paths (local copies of approved legacy brand imagery from
/// `Barakah40_Delivery/web/assets`).
abstract final class AppAssets {
  static const welcomeHero = 'assets/images/p_login.webp';
  static const appIcon = 'assets/images/app_icon_192.png';

  /// Legacy `PAGE_BG` photography.
  static const pagePrayer = 'assets/images/pg/p_prayer.webp';
  static const pageQuran = 'assets/images/pg/p_quran.webp';
  static const pageChallenge = 'assets/images/pg/p_chall.webp';
  static const pageChallengeDetail = 'assets/images/pg/p_chaldetail.webp';
  static const pageAdhkar = 'assets/images/pg/p_adhkar.webp';
  static const pageDuas = 'assets/images/pg/p_duas.webp';
  static const pageQibla = 'assets/images/pg/p_qibla.webp';

  /// Tree stage images, `index` 0..19 (legacy `grow{n}` / `wilt{n}`).
  static String treeGrow(int index) =>
      'assets/images/tree/grow${index.clamp(0, 19) + 1}.webp';
  static String treeWilt(int index) =>
      'assets/images/tree/wilt${index.clamp(0, 19) + 1}.webp';
}
