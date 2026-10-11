abstract final class AppRoutes {
  static const splash = '/';
  static const welcome = '/welcome';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const home = '/home';
  static const challenge = '/challenge';
  static const quran = '/quran';
  static const quranReciter = '/quran/reciter';
  static const prayer = '/prayer';
  static const community = '/community';
  static const chat = '/community/chat/:id';
  static const challengeDetail = '/community/challenge/:id';
  static const tree = '/tree';

  static String chatPath(String id) => '/community/chat/$id';
  static String challengeDetailPath(String id) => '/community/challenge/$id';

  static const splashName = 'splash';
  static const welcomeName = 'welcome';
  static const loginName = 'login';
  static const registerName = 'register';
  static const forgotPasswordName = 'forgot-password';
  static const homeName = 'home';
  static const challengeName = 'challenge';
  static const quranName = 'quran';
  static const quranReciterName = 'quran-reciter';
  static const prayerName = 'prayer';
  static const communityName = 'community';
  static const chatName = 'chat';
  static const challengeDetailName = 'challenge-detail';
  static const treeName = 'tree';

  static const publicLocations = <String>{
    splash,
    welcome,
    login,
    register,
    forgotPassword,
  };
}
