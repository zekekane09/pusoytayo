class ApiEndpoints {
  ApiEndpoints._();

  // Backend host. Override at build time for the cloud, e.g.:
  //   flutter build apk --release --dart-define=API_BASE=https://your-app.onrender.com
  // Defaults to the Mac's LAN IP for local development.
  static const String _host = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://192.168.1.12:3000',
  );
  static const String baseUrl = '$_host/api';
  static const String socketUrl = _host;

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refreshToken = '/auth/refresh';
  static const String profile = '/auth/profile';

  // Users
  static const String users = '/users';
  static String user(String id) => '/users/$id';
  static const String updateProfile = '/users/profile';

  // Wallet
  static const String wallet = '/wallet';
  static const String walletDeposit = '/wallet/deposit';
  static const String walletDeposits = '/wallet/deposits';
  static const String walletWithdraw = '/wallet/withdraw';
  static const String walletWithdrawals = '/wallet/withdrawals';
  static const String walletTransactions = '/wallet/transactions';

  // Rooms
  static const String rooms = '/rooms';
  static String room(String code) => '/rooms/$code';

  // Rankings
  static const String rankings = '/rankings';
  static const String leaderboard = '/rankings/leaderboard';
  static const String topWins = '/rankings/top-wins';
  static String playerRank(String id) => '/rankings/$id';

  // Friends
  static const String friends = '/friends';
  static const String friendsSearch = '/friends/search';
  static const String friendRequest = '/friends/request';
  static const String friendAccept = '/friends/accept';
  static const String friendRemove = '/friends/remove';

  // Matchmaking
  static const String quickMatch = '/matchmaking/quick';

  // Health / app meta
  static const String health = '/health';
  static const String appVersion = '/app/version';
}
