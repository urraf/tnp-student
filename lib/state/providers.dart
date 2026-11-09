import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/alerts.dart';
import '../core/api_client.dart';
import '../core/config.dart';
import '../data/models.dart';
import 'auth.dart';

// ------------------------------------------------------------- Theme mode --

final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('Overridden in main()'));

class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final saved = ref.read(sharedPrefsProvider).getString(_key);
    return ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
  }

  void set(ThemeMode mode) {
    state = mode;
    ref.read(sharedPrefsProvider).setString(_key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

// --------------------------------------------------------- Paged listing --

class PagedState<T> {
  const PagedState({
    this.items = const [],
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<T> items;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? error;

  PagedState<T> copyWith({
    List<T>? items,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) => PagedState<T>(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    hasMore: hasMore ?? this.hasMore,
    error: clearError ? null : (error ?? this.error),
  );
}

// ---------------------------------------------------------- Announcements --

class NoticeFilter {
  const NoticeFilter({this.type = 'All', this.tag, this.search = ''});
  final String type;
  final String? tag;
  final String search;

  NoticeFilter copyWith({String? type, String? tag, bool clearTag = false, String? search}) =>
      NoticeFilter(type: type ?? this.type, tag: clearTag ? null : (tag ?? this.tag), search: search ?? this.search);
}

class NoticeFilterController extends Notifier<NoticeFilter> {
  @override
  NoticeFilter build() => const NoticeFilter();

  void setType(String type) => state = state.copyWith(type: type, clearTag: true);
  void setTag(String? tag) => state = state.copyWith(tag: tag, clearTag: tag == null);
  void setSearch(String q) => state = state.copyWith(search: q);
}

final noticeFilterProvider = NotifierProvider<NoticeFilterController, NoticeFilter>(NoticeFilterController.new);

class NoticesController extends Notifier<PagedState<Announcement>> {
  int _generation = 0;

  @override
  PagedState<Announcement> build() {
    ref.watch(noticeFilterProvider);
    ref.watch(studentProvider.select((s) => s?.id));
    Future.microtask(refresh);
    return const PagedState(loading: true);
  }

  Future<void> refresh() => _load(reset: true);
  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    await _load(reset: false);
  }

  Future<void> _load({required bool reset}) async {
    final student = ref.read(studentProvider);
    if (student == null) return;
    final filter = ref.read(noticeFilterProvider);
    final gen = reset ? ++_generation : _generation;
    state = reset
        ? state.copyWith(loading: state.items.isEmpty, clearError: true, hasMore: true)
        : state.copyWith(loadingMore: true, clearError: true);
    try {
      final page = await ref
          .read(repositoryProvider)
          .announcements(
            student: student,
            start: reset ? 0 : state.items.length,
            type: filter.type,
            tag: filter.tag,
            search: filter.search,
          );
      if (gen != _generation) return;
      state = PagedState(
        items: reset ? page : [...state.items, ...page],
        hasMore: page.length >= AppConfig.noticePageSize,
      );
      markSeenSafely(() => Alerts.markNoticesSeen(page.map((n) => n.id)));
    } on ApiException catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(loading: false, loadingMore: false, error: e.message);
    }
  }
}

final noticesProvider = NotifierProvider<NoticesController, PagedState<Announcement>>(NoticesController.new);

final noticeTagsProvider = FutureProvider.autoDispose.family<List<String>, String>(
  (ref, type) => ref.watch(repositoryProvider).announcementTags(type),
);

final noticeDetailProvider = FutureProvider.autoDispose.family<NoticeDetail, String>(
  (ref, id) => ref.watch(repositoryProvider).noticeDetail(id),
);

// --------------------------------------------------------- Company events --

class JobsController extends Notifier<PagedState<CompanyEvent>> {
  int _generation = 0;

  @override
  PagedState<CompanyEvent> build() {
    ref.watch(studentProvider.select((s) => s?.id));
    Future.microtask(refresh);
    return const PagedState(loading: true);
  }

  Future<void> refresh() => _load(reset: true);
  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    await _load(reset: false);
  }

  Future<void> _load({required bool reset}) async {
    final student = ref.read(studentProvider);
    if (student == null) return;
    final gen = reset ? ++_generation : _generation;
    state = reset
        ? state.copyWith(loading: state.items.isEmpty, clearError: true, hasMore: true)
        : state.copyWith(loadingMore: true, clearError: true);
    try {
      final page = await ref
          .read(repositoryProvider)
          .companyEvents(student: student, start: reset ? 0 : state.items.length);
      if (gen != _generation) return;
      state = PagedState(
        items: reset ? page : [...state.items, ...page],
        hasMore: page.length >= AppConfig.jobsPageSize,
      );
      markSeenSafely(() => Alerts.markEventsSeen(page.map((e) => e.id)));
    } on ApiException catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(loading: false, loadingMore: false, error: e.message);
    }
  }
}

final jobsProvider = NotifierProvider<JobsController, PagedState<CompanyEvent>>(JobsController.new);

final jobDetailProvider = FutureProvider.autoDispose.family<CompanyEvent, String>(
  (ref, id) => ref.watch(repositoryProvider).companyEvent(id),
);

final eligibilityProvider = FutureProvider.autoDispose.family<Eligibility, String>((ref, id) {
  final user = ref.watch(authProvider).user;
  return ref.watch(repositoryProvider).eligibility(id, user?.studentId ?? '');
});

final resumesProvider = FutureProvider.autoDispose<List<ResumeFile>>((ref) => ref.watch(repositoryProvider).resumes());

final applicationsProvider = FutureProvider.autoDispose<List<Application>>(
  (ref) => ref.watch(repositoryProvider).myApplications(),
);

// ---------------------------------------------------------- Forms & NOCs --

final formsProvider = FutureProvider.autoDispose<List<FormDoc>>((ref) => ref.watch(repositoryProvider).forms());

final formUploadsProvider = FutureProvider.autoDispose<List<FormUpload>>(
  (ref) => ref.watch(repositoryProvider).formUploads(),
);

final nocsProvider = FutureProvider.autoDispose<List<Noc>>((ref) => ref.watch(repositoryProvider).nocs());

// --------------------------------------------------------------- Feedback --

final feedbacksProvider = FutureProvider.autoDispose.family<List<FeedbackItem>, bool>((ref, resolvedOnly) {
  final user = ref.watch(authProvider).user;
  return ref.watch(repositoryProvider).feedbacks(user?.studentId ?? '', resolvedOnly: resolvedOnly);
});

// ---------------------------------------------------------------- Captcha --

final captchaProvider = FutureProvider.autoDispose<String>((ref) => ref.watch(repositoryProvider).captcha());
