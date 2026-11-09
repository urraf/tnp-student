import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/alerts.dart';
import '../core/api_client.dart';
import '../data/models.dart';
import '../data/repository.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
final repositoryProvider = Provider<TnpRepository>((ref) => TnpRepository(ref.watch(apiClientProvider)));

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({this.status = AuthStatus.unknown, this.user, this.student, this.message});

  final AuthStatus status;
  final AppUser? user;
  final Student? student;

  /// Shown on the login screen (e.g. "Session expired").
  final String? message;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({AuthStatus? status, AppUser? user, Student? student, String? message}) => AuthState(
    status: status ?? this.status,
    user: user ?? this.user,
    student: student ?? this.student,
    message: message,
  );
}

class AuthController extends Notifier<AuthState> {
  TnpRepository get _repo => ref.read(repositoryProvider);
  ApiClient get _api => ref.read(apiClientProvider);
  TokenStore get _tokens => ref.read(tokenStoreProvider);

  @override
  AuthState build() {
    _api.onUnauthorized = () {
      if (state.isAuthenticated) {
        logout(message: 'Your session expired. Please log in again.');
      }
    };
    return const AuthState();
  }

  /// Restores a saved session on app start.
  Future<void> bootstrap() async {
    final token = await _tokens.read();
    if (token == null || token.isEmpty) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    _api.token = token;
    try {
      await _loadProfile();
    } on ApiException catch (e) {
      if (e.isUnauthorized || e.statusCode == 403) {
        await logout(message: 'Session expired. Please log in again.');
      } else {
        // Network trouble: keep the saved session and let the splash screen
        // offer a retry instead of forcing a fresh login.
        state = AuthState(status: AuthStatus.unknown, message: e.message);
      }
    }
  }

  Future<void> _loadProfile() async {
    final results = await Future.wait([_repo.me(), _repo.studentMe()]);
    state = AuthState(status: AuthStatus.authenticated, user: results[0] as AppUser, student: results[1] as Student);
  }

  /// Throws [ApiException] on failure so the UI can show the message.
  Future<void> login(String identifier, String password) async {
    final jwt = await _repo.login(identifier, password);
    _api.token = jwt;
    try {
      await _loadProfile();
      await _tokens.write(jwt);
    } catch (e) {
      _api.token = null;
      rethrow;
    }
  }

  /// Re-fetches `/students/me` after profile changes.
  Future<void> refreshProfile() async {
    if (!state.isAuthenticated) return;
    final student = await _repo.studentMe();
    state = state.copyWith(student: student);
  }

  Future<void> logout({String? message}) async {
    _api.token = null;
    await _api.cookieJar.deleteAll();
    await _tokens.clear();
    try {
      await Alerts.reset();
    } catch (_) {}
    state = AuthState(status: AuthStatus.unauthenticated, message: message);
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Convenience: the signed-in student (null while signed out).
final studentProvider = Provider<Student?>((ref) => ref.watch(authProvider).student);
