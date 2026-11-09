import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/alerts.dart';
import '../../core/theme.dart';
import '../widgets/content.dart';

class _NavItem {
  const _NavItem(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

const _items = [
  _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
  _NavItem(Icons.work_outline_rounded, Icons.work_rounded, 'Jobs'),
  _NavItem(Icons.assignment_outlined, Icons.assignment_rounded, 'Applied'),
  _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  _NavItem(Icons.grid_view_outlined, Icons.grid_view_rounded, 'More'),
];

/// Bottom padding every tab page should leave for the floating nav bar.
double navBarInset(BuildContext context) => 96 + MediaQuery.paddingOf(context).bottom;

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  StatefulNavigationShell get shell => widget.shell;

  @override
  void initState() {
    super.initState();
    Alerts.pendingRoute.addListener(_openPending);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _openPending();
      // Turn on background alerts after sign-in unless the user switched them off.
      try {
        if (await Alerts.isEnabled()) await Alerts.enable();
      } catch (e) {
        debugPrint('Could not enable alerts: $e');
      }
    });
  }

  @override
  void dispose() {
    Alerts.pendingRoute.removeListener(_openPending);
    super.dispose();
  }

  /// Opens the job / notice a tapped notification points to.
  void _openPending() {
    final route = Alerts.pendingRoute.value;
    if (route == null || !mounted) return;
    Alerts.pendingRoute.value = null;
    if (route.startsWith('/job/') || route.startsWith('/notice/')) {
      context.push(route);
    } else {
      openLink(context, route);
    }
  }

  void _onTap(int i) {
    HapticFeedback.selectionClick();
    shell.goBranch(i, initialLocation: i == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    // Tabs have no AppBar, so set the status bar icon colour explicitly
    // (otherwise a dark detail page's style can linger after popping).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (context.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Scaffold(
        extendBody: true,
        body: shell,
        bottomNavigationBar: _FloatingNavBar(index: shell.currentIndex, onTap: _onTap),
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom > 0 ? bottom : 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: (context.isDark ? const Color(0xFF161A2A) : Colors.white).withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: p.border.withValues(alpha: 0.8)),
              boxShadow: [BoxShadow(color: p.shadow, blurRadius: 30, offset: const Offset(0, 10))],
            ),
            child: Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    flex: i == index ? 18 : 10,
                    child: _NavButton(item: _items[i], selected: i == index, onTap: () => onTap(i)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected, required this.onTap});
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = context.palette.muted;
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            height: 46,
            padding: EdgeInsets.symmetric(horizontal: selected ? 10 : 0),
            decoration: BoxDecoration(
              gradient: selected ? AppColors.brandGradient : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.crimson.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                        spreadRadius: -4,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: Icon(
                    selected ? item.activeIcon : item.icon,
                    key: ValueKey(selected),
                    color: selected ? Colors.white : muted,
                    size: 23,
                  ),
                ),
                Flexible(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: selected
                        ? Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Large page title used at the top of each tab.
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.title, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.headlineMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: context.text.bodyMedium?.copyWith(color: context.palette.muted)),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
