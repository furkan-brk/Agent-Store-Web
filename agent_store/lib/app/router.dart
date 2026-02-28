import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
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

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (_, __, child) => _AppShell(child: child),
        routes: [
          GoRoute(path: '/',          builder: (_, __) => const StoreScreen()),
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
          GoRoute(path: '/library',       builder: (_, __) => const LibraryScreen()),
          GoRoute(path: '/create',        builder: (_, __) => const CreateAgentScreen()),
          GoRoute(path: '/wallet',        builder: (_, __) => const WalletConnectScreen()),
          GoRoute(path: '/guild',         builder: (_, __) => const GuildScreen()),
          GoRoute(path: '/guild/create',  builder: (_, __) => const GuildCreateScreen()),
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
          GoRoute(path: '/credits/history', builder: (_, __) => const CreditHistoryScreen()),
          GoRoute(path: '/leaderboard',     builder: (_, __) => const LeaderboardScreen()),
          GoRoute(path: '/creator',         builder: (_, __) => const CreatorDashboardScreen()),
          GoRoute(path: '/settings',        builder: (_, __) => const SettingsScreen()),
          GoRoute(
            path: '/profile/:wallet',
            builder: (_, s) => PublicProfileScreen(wallet: s.pathParameters['wallet']!),
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

class _AppShellState extends State<_AppShell> {
  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyS, alt: true): _GoStoreIntent(),
        SingleActivator(LogicalKeyboardKey.keyL, alt: true): _GoLibraryIntent(),
        SingleActivator(LogicalKeyboardKey.keyC, alt: true): _GoCreateIntent(),
        SingleActivator(LogicalKeyboardKey.keyG, alt: true): _GoGuildIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _GoStoreIntent: CallbackAction<_GoStoreIntent>(
            onInvoke: (_) { context.go('/'); return null; },
          ),
          _GoLibraryIntent: CallbackAction<_GoLibraryIntent>(
            onInvoke: (_) { context.go('/library'); return null; },
          ),
          _GoCreateIntent: CallbackAction<_GoCreateIntent>(
            onInvoke: (_) { context.go('/create'); return null; },
          ),
          _GoGuildIntent: CallbackAction<_GoGuildIntent>(
            onInvoke: (_) { context.go('/guild'); return null; },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Row(children: [const _Sidebar(), Expanded(child: widget.child)]),
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    return Container(
      width: 210,
      color: const Color(0xFF22231A),
      child: Column(children: [
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: const Color(0xFF81231E), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.auto_awesome, color: Color(0xFFE8D9B8), size: 18),
            ),
            const SizedBox(width: 10),
            const Text('AgentStore', style: TextStyle(color: Color(0xFFE8D9B8), fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
        ),
        const SizedBox(height: 28),
        _NavItem(icon: Icons.storefront_outlined,           label: 'Store',   path: '/',       loc: loc, tooltip: 'Alt+S'),
        _NavItem(icon: Icons.bookmarks_outlined,            label: 'Library', path: '/library',loc: loc, tooltip: 'Alt+L'),
        _NavItem(icon: Icons.add_box_outlined,              label: 'Create',  path: '/create', loc: loc, tooltip: 'Alt+C'),
        _NavItem(icon: Icons.groups_outlined,               label: 'Guilds',  path: '/guild',  loc: loc, tooltip: 'Alt+G'),
        _NavItem(icon: Icons.emoji_events_outlined,         label: 'Leaderboard', path: '/leaderboard', loc: loc),
        _NavItem(icon: Icons.analytics_outlined,            label: 'Creator',     path: '/creator',      loc: loc),
        const Spacer(),
        const Divider(color: Color(0xFF3D3E2A), height: 1),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(children: [
            Text('', style: TextStyle(color: Color(0xFF9E8F72), fontSize: 12)),
            Spacer(),
            NotificationBell(),
          ]),
        ),
        _NavItem(icon: Icons.settings_outlined,               label: 'Settings', path: '/settings', loc: loc),
        _NavItem(icon: Icons.account_balance_wallet_outlined, label: 'Wallet', path: '/wallet', loc: loc),
        const SizedBox(height: 16),
      ]),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String path;
  final String loc;
  final String? tooltip;
  const _NavItem({required this.icon, required this.label, required this.path, required this.loc, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final selected = loc == path || (path != '/' && loc.startsWith(path));
    final item = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: () => context.go(path),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF81231E).withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(icon, color: selected ? const Color(0xFF81231E) : const Color(0xFF7A6E52), size: 20),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(
              color: selected ? const Color(0xFF81231E) : const Color(0xFF9E8F72),
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            )),
          ]),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        preferBelow: false,
        child: item,
      );
    }
    return item;
  }
}
