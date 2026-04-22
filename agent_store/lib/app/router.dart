import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:get/get.dart';
import '../features/store/screens/store_screen.dart';
import '../features/agent_detail/screens/agent_detail_screen.dart';
import '../features/library/screens/library_screen.dart';
import '../features/create_agent/screens/create_agent_screen.dart';
import '../features/wallet/screens/wallet_connect_screen.dart';
import '../features/guild/screens/guild_screen.dart';
import '../features/guild/screens/guild_detail_screen.dart';
import '../features/guild/screens/guild_create_screen.dart';
import '../features/wallet/screens/credit_history_screen.dart';
import '../features/leaderboard/screens/leaderboard_screen.dart';
import '../features/creator/screens/creator_dashboard_screen.dart';
import '../shared/widgets/notification_panel.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/profile/screens/public_profile_screen.dart';
import '../features/guild_master/screens/guild_master_screen.dart';
import '../features/missions/screens/missions_screen.dart';
import '../features/legend/screens/legend_screen.dart';
import '../controllers/auth_controller.dart';
import '../shared/services/app_telemetry_service.dart';
import 'theme.dart';

// Intent classes for keyboard shortcuts
class _GoStoreIntent extends Intent {
  const _GoStoreIntent();
}

class _GoLibraryIntent extends Intent {
  const _GoLibraryIntent();
}

class _GoCreateIntent extends Intent {
  const _GoCreateIntent();
}

class _GoGuildIntent extends Intent {
  const _GoGuildIntent();
}

class _GoLegendIntent extends Intent {
  const _GoLegendIntent();
}

class _DismissIntent extends Intent {
  const _DismissIntent();
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _GoBackIntent extends Intent {
  const _GoBackIntent();
}

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (_, __, child) => _AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const StoreScreen()),
          GoRoute(
            path: '/agent/:id',
            builder: (ctx, s) {
              final id = int.tryParse(s.pathParameters['id'] ?? '');
              if (id == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) => ctx.go('/'));
                return const SizedBox.shrink();
              }
              return AgentDetailScreen(agentId: id);
            },
          ),
          GoRoute(path: '/library', builder: (_, __) => const LibraryScreen()),
          GoRoute(path: '/create', builder: (_, __) => const CreateAgentScreen()),
          GoRoute(path: '/wallet', builder: (_, __) => const WalletConnectScreen()),
          GoRoute(path: '/guild', builder: (_, __) => const GuildScreen()),
          GoRoute(path: '/guild/create', builder: (_, __) => const GuildCreateScreen()),
          GoRoute(
            path: '/guild/:id',
            builder: (ctx, s) {
              final id = int.tryParse(s.pathParameters['id'] ?? '');
              if (id == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) => ctx.go('/guild'));
                return const SizedBox.shrink();
              }
              return GuildDetailScreen(guildId: id);
            },
          ),
          GoRoute(
            path: '/guild-master',
            builder: (_, s) {
              final extra = s.extra is Map<String, dynamic> ? s.extra as Map<String, dynamic> : null;
              final agents = extra?['agents'] as List<Map<String, dynamic>>?;
              final guildName = extra?['guild_name'] as String?;
              return GuildMasterScreen(
                initialAgents: agents,
                initialGuildName: guildName,
              );
            },
          ),
          GoRoute(path: '/credits/history', builder: (_, __) => const CreditHistoryScreen()),
          GoRoute(path: '/leaderboard', builder: (_, __) => const LeaderboardScreen()),
          GoRoute(path: '/missions', builder: (_, __) => const MissionsScreen()),
          GoRoute(path: '/legend', builder: (_, __) => const LegendScreen()),
          GoRoute(path: '/creator', builder: (_, __) => const CreatorDashboardScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
          GoRoute(
            path: '/profile/:wallet',
            builder: (ctx, s) {
              final wallet = s.pathParameters['wallet'];
              if (wallet == null || wallet.isEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) => ctx.go('/'));
                return const SizedBox.shrink();
              }
              return PublicProfileScreen(wallet: wallet);
            },
          ),
        ],
      ),
    ],
  );
}

class _AppShell extends StatefulWidget {
  final Widget child;
  const _AppShell({required this.child});

  @override
  State<_AppShell> createState() => _AppShellState();
}

/// Provides access to shared app-level state for keyboard shortcuts.
class AppShellState {
  /// The store screen registers its search FocusNode here so that
  /// the '/' shortcut can request focus cross-widget.
  static FocusNode? searchFocusNode;
}

class _AppShellState extends State<_AppShell> {
  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    Get.find<AppTelemetryService>().onRouteSeen(loc);
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 768;

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyS, alt: true): _GoStoreIntent(),
        SingleActivator(LogicalKeyboardKey.keyL, alt: true): _GoLibraryIntent(),
        SingleActivator(LogicalKeyboardKey.keyC, alt: true): _GoCreateIntent(),
        SingleActivator(LogicalKeyboardKey.keyG, alt: true): _GoGuildIntent(),
        SingleActivator(LogicalKeyboardKey.keyW, alt: true): _GoLegendIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _DismissIntent(),
        SingleActivator(LogicalKeyboardKey.slash): _FocusSearchIntent(),
        SingleActivator(LogicalKeyboardKey.backspace, alt: true): _GoBackIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _GoStoreIntent: CallbackAction<_GoStoreIntent>(
            onInvoke: (_) {
              context.go('/');
              return null;
            },
          ),
          _GoLibraryIntent: CallbackAction<_GoLibraryIntent>(
            onInvoke: (_) {
              context.go('/library');
              return null;
            },
          ),
          _GoCreateIntent: CallbackAction<_GoCreateIntent>(
            onInvoke: (_) {
              context.go('/create');
              return null;
            },
          ),
          _GoGuildIntent: CallbackAction<_GoGuildIntent>(
            onInvoke: (_) {
              context.go('/guild');
              return null;
            },
          ),
          _GoLegendIntent: CallbackAction<_GoLegendIntent>(
            onInvoke: (_) {
              context.go('/legend');
              return null;
            },
          ),
          _DismissIntent: CallbackAction<_DismissIntent>(
            onInvoke: (_) {
              Navigator.of(context).maybePop();
              return null;
            },
          ),
          _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
            onInvoke: (_) {
              // Navigate to store and request focus on the search field
              final currentLoc = GoRouterState.of(context).uri.toString();
              if (currentLoc != '/') context.go('/');
              // Use the shared search focus node
              WidgetsBinding.instance.addPostFrameCallback((_) {
                AppShellState.searchFocusNode?.requestFocus();
              });
              return null;
            },
          ),
          _GoBackIntent: CallbackAction<_GoBackIntent>(
            onInvoke: (_) {
              Navigator.of(context).maybePop();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: isNarrow ? _NarrowLayout(child: widget.child) : _WideLayout(child: widget.child),
        ),
      ),
    );
  }
}

/// Desktop/tablet layout with persistent sidebar
class _WideLayout extends StatelessWidget {
  final Widget child;
  const _WideLayout({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const SizedBox(
            width: AppSizing.navSidebar,
            child: _Sidebar(),
          ),
          // Thin vertical divider between sidebar and content
          Container(
            width: 1,
            color: Theme.of(context).colorScheme.outline,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mobile layout with bottom navigation bar + hamburger drawer for overflow
class _NarrowLayout extends StatefulWidget {
  final Widget child;
  const _NarrowLayout({required this.child});

  @override
  State<_NarrowLayout> createState() => _NarrowLayoutState();
}

class _NarrowLayoutState extends State<_NarrowLayout> {
  /// The five bottom nav destinations and their routes.
  static const _bottomNavItems = <({IconData icon, IconData activeIcon, String label, String path})>[
    (icon: Icons.storefront_outlined, activeIcon: Icons.storefront, label: 'Store', path: '/'),
    (icon: Icons.bookmarks_outlined, activeIcon: Icons.bookmarks, label: 'Library', path: '/library'),
    (icon: Icons.add_circle_outline, activeIcon: Icons.add_circle, label: 'Create', path: '/create'),
    (icon: Icons.groups_outlined, activeIcon: Icons.groups, label: 'Guilds', path: '/guild'),
  ];

  int _selectedIndex(String loc) {
    for (var i = 0; i < _bottomNavItems.length; i++) {
      final path = _bottomNavItems[i].path;
      if (loc == path || (path != '/' && loc.startsWith(path))) return i;
    }
    // "More" tab (index 4) for any route not in the bottom nav
    return 4;
  }

  void _onNavTap(int index) {
    if (index == 4) {
      // Open drawer for "More" items
      Scaffold.of(context).openDrawer();
      return;
    }
    context.go(_bottomNavItems[index].path);
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    final currentIndex = _selectedIndex(loc);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.auto_awesome, color: colorScheme.onPrimary, size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              'AgentStore',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: NotificationBell(),
          ),
        ],
      ),
      drawer: const Drawer(child: _Sidebar(isDrawer: true)),
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: colorScheme.outline, width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: _onNavTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: colorScheme.onSurface.withValues(alpha: 0.5),
          selectedFontSize: 11,
          unselectedFontSize: 10,
          iconSize: 22,
          elevation: 0,
          items: [
            ..._bottomNavItems.map((item) => BottomNavigationBarItem(
              icon: Icon(item.icon),
              activeIcon: Icon(item.activeIcon),
              label: item.label,
            )),
            const BottomNavigationBarItem(
              icon: Icon(Icons.menu),
              activeIcon: Icon(Icons.menu_open),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final bool isDrawer;
  const _Sidebar({this.isDrawer = false});

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: isDrawer ? null : AppSizing.navSidebar,
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: FocusTraversalGroup(
          child: Column(
            children: [
              const SizedBox(height: 24),
              // ── Branding ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.auto_awesome, color: colorScheme.onPrimary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'AgentStore',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Navigation items (scrollable) ──
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // ── Primary ──
                    _SectionLabel(label: 'EXPLORE', colorScheme: colorScheme),
                    _NavItem(
                        icon: Icons.storefront_outlined,
                        label: 'Store',
                        path: '/',
                        loc: loc,
                        tooltip: 'Alt+S',
                        isDrawer: isDrawer),
                    _NavItem(
                        icon: Icons.bookmarks_outlined,
                        label: 'Library',
                        path: '/library',
                        loc: loc,
                        tooltip: 'Alt+L',
                        isDrawer: isDrawer),
                    _NavItem(
                        icon: Icons.add_circle_outline,
                        label: 'Create Agent',
                        path: '/create',
                        loc: loc,
                        tooltip: 'Alt+C',
                        isDrawer: isDrawer),

                    const SizedBox(height: 16),

                    // ── Community ──
                    _SectionLabel(label: 'COMMUNITY', colorScheme: colorScheme),
                    _NavItem(
                        icon: Icons.groups_outlined,
                        label: 'Guilds',
                        path: '/guild',
                        loc: loc,
                        tooltip: 'Alt+G',
                        isDrawer: isDrawer),
                    _NavItem(
                        icon: Icons.auto_awesome_outlined,
                        label: 'Guild Master',
                        path: '/guild-master',
                        loc: loc,
                        tooltip: 'AI Team Builder',
                        isDrawer: isDrawer),
                    _NavItem(
                        icon: Icons.emoji_events_outlined,
                        label: 'Leaderboard',
                        path: '/leaderboard',
                        loc: loc,
                        isDrawer: isDrawer),

                    const SizedBox(height: 16),

                    // ── Missions ──
                    _SectionLabel(label: 'MISSIONS', colorScheme: colorScheme),
                    _NavItem(icon: Icons.flag_outlined, label: 'Missions', path: '/missions', loc: loc, isDrawer: isDrawer),
                    _NavItem(
                        icon: Icons.account_tree_outlined,
                        label: 'Legend',
                        path: '/legend',
                        loc: loc,
                        tooltip: 'Alt+W',
                        isDrawer: isDrawer),

                    const SizedBox(height: 16),

                    // ── Account ──
                    _SectionLabel(label: 'ACCOUNT', colorScheme: colorScheme),
                    _NavItem(
                        icon: Icons.analytics_outlined, label: 'Dashboard', path: '/creator', loc: loc, isDrawer: isDrawer),
                    _NavItem(icon: Icons.settings_outlined, label: 'Settings', path: '/settings', loc: loc, isDrawer: isDrawer),
                    _NavItem(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Wallet',
                        path: '/wallet',
                        loc: loc,
                        isDrawer: isDrawer),
                  ],
                ),
              ),

              // ── Notification bell (desktop only — mobile has it in AppBar) ──
              if (!isDrawer) ...[
                Divider(color: colorScheme.outline, height: 1, indent: 20, endIndent: 20),
                const SizedBox(height: 8),
              ],

              // ── User info + notification ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _UserFooter(isDrawer: isDrawer),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section group label for sidebar nav groups
class _SectionLabel extends StatelessWidget {
  final String label;
  final ColorScheme colorScheme;
  const _SectionLabel({required this.label, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 20, bottom: 4, top: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            color: colorScheme.onSurface.withValues(alpha: 0.35),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
      ),
    );
  }
}

/// Bottom section of sidebar showing wallet info + notification bell
class _UserFooter extends StatelessWidget {
  final bool isDrawer;
  const _UserFooter({required this.isDrawer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final auth = AuthController.to;

    return Obx(() {
      if (!auth.isConnected.value) {
        return Row(
          children: [
            Expanded(
              child: _ConnectButton(colorScheme: colorScheme),
            ),
            if (!isDrawer) ...[
              const SizedBox(width: 8),
              const NotificationBell(),
            ],
          ],
        );
      }

      return Row(
        children: [
          // User avatar circle
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withValues(alpha: 0.15),
              border: Border.all(color: colorScheme.primary.withValues(alpha: 0.4)),
            ),
            child: Icon(Icons.person_outline, color: colorScheme.primary, size: 16),
          ),
          const SizedBox(width: 8),
          // Wallet address + credits
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  auth.username.value.isNotEmpty ? auth.username.value : auth.shortWallet,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  '${auth.credits.value} credits',
                  style: TextStyle(
                    color: colorScheme.secondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (!isDrawer) ...[
            const SizedBox(width: 4),
            const NotificationBell(),
          ],
        ],
      );
    });
  }
}

/// Minimal connect button for unauthenticated state in sidebar footer
class _ConnectButton extends StatelessWidget {
  final ColorScheme colorScheme;
  const _ConnectButton({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go('/wallet'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: colorScheme.primary, size: 14),
              const SizedBox(width: 6),
              Text(
                'Connect',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String path;
  final String loc;
  final String? tooltip;
  final bool isDrawer;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.path,
    required this.loc,
    this.tooltip,
    this.isDrawer = false,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;
  bool _focused = false;

  bool get _selected => widget.loc == widget.path || (widget.path != '/' && widget.loc.startsWith(widget.path));

  void _navigate() {
    context.go(widget.path);
    // Close drawer on mobile after navigation
    if (widget.isDrawer) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine colors based on state: selected > focused/hovered > default
    Color iconColor;
    Color labelColor;
    Color bgColor;
    FontWeight fontWeight;

    if (_selected) {
      iconColor = colorScheme.primary;
      labelColor = colorScheme.primary;
      bgColor = colorScheme.primary.withValues(alpha: 0.12);
      fontWeight = FontWeight.w600;
    } else if (_hovered || _focused) {
      iconColor = colorScheme.onSurface;
      labelColor = colorScheme.onSurface;
      bgColor = colorScheme.onSurface.withValues(alpha: 0.06);
      fontWeight = FontWeight.w500;
    } else {
      iconColor = colorScheme.onSurface.withValues(alpha: 0.5);
      labelColor = colorScheme.onSurface.withValues(alpha: 0.6);
      bgColor = Colors.transparent;
      fontWeight = FontWeight.normal;
    }

    final item = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _navigate();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: _navigate,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              // Left accent bar for selected item
              border: _selected
                  ? Border(
                      left: BorderSide(color: colorScheme.primary, width: 3),
                    )
                  : _focused
                      ? Border.all(color: colorScheme.primary.withValues(alpha: 0.4), width: 1)
                      : null,
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: iconColor, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: labelColor,
                      fontWeight: fontWeight,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        preferBelow: false,
        child: item,
      );
    }
    return item;
  }
}
