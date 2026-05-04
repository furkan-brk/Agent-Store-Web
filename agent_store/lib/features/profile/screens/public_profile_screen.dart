// lib/features/profile/screens/public_profile_screen.dart
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:web/web.dart' as web;

import '../../../app/theme.dart';
import '../../../shared/utils/app_snack_bar.dart';
import '../../../controllers/auth_controller.dart';
import '../../../shared/models/agent_model.dart';
import '../../../shared/services/api_service.dart';
import '../../store/widgets/agent_card.dart';

class PublicProfileScreen extends StatefulWidget {
  final String wallet;
  const PublicProfileScreen({super.key, required this.wallet});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  late final _PublicProfileController ctrl;

  @override
  void initState() {
    super.initState();
    ctrl = Get.put(_PublicProfileController(widget.wallet), tag: widget.wallet);
  }

  bool get _isOwnProfile {
    final myWallet = AuthController.to.wallet;
    return myWallet != null &&
        myWallet.toLowerCase() == widget.wallet.toLowerCase();
  }

  Future<void> _shareProfile(BuildContext context) async {
    final url = '${web.window.location.origin}/profile/${widget.wallet}';
    try {
      await web.window.navigator.clipboard.writeText(url).toDart;
      if (!context.mounted) return;
      AppSnackBar.success(context, 'Profile link copied to clipboard!');
    } catch (_) {}
  }

  @override
  void dispose() {
    Get.delete<_PublicProfileController>(tag: widget.wallet);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() => Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(slivers: [
        // ── App bar ────────────────────────────────────────────────────
        SliverAppBar(
          backgroundColor: AppTheme.surface,
          pinned: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textB, size: 18),
            onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          ),
          title: Row(children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppTheme.olive,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            SelectableText(
              _shorten(widget.wallet),
              style: const TextStyle(
                color: AppTheme.textH,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                letterSpacing: 0.5,
              ),
            ),
          ]),
          centerTitle: false,
          actions: [
            // Share profile
            _ProfileActionButton(
              icon: Icons.share_outlined,
              tooltip: 'Share Profile',
              onPressed: () => _shareProfile(context),
            ),
            // Edit profile (only if own)
            if (_isOwnProfile)
              _ProfileActionButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit Profile',
                onPressed: () => context.go('/settings'),
              ),
            const SizedBox(width: 8),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: AppTheme.border),
          ),
        ),

        // ── Content states ─────────────────────────────────────────────
        if (ctrl.isLoading.value)
          SliverFillRemaining(child: _buildLoadingState())
        else if (ctrl.error.value != null)
          SliverFillRemaining(child: _buildErrorState(ctrl))
        else ...[
          SliverToBoxAdapter(child: _ProfileHeader(wallet: widget.wallet, ctrl: ctrl)),
          // Stats row + follow counts
          SliverToBoxAdapter(child: _StatsRow(ctrl: ctrl)),
          // Follow button (only for other profiles, not own)
          if (!_isOwnProfile)
            SliverToBoxAdapter(
              child: Obx(() => Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: _FollowSection(
                  ctrl: ctrl,
                  isOwnProfile: false,
                ),
              )),
            ),
          // Achievements section
          if (ctrl.badges.isNotEmpty)
            SliverToBoxAdapter(child: _BadgesSection(badges: ctrl.badges)),
          // Section title + search + sort
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.auto_awesome_outlined, size: 16, color: AppTheme.textM),
                    const SizedBox(width: 8),
                    const Text(
                      'Created Agents',
                      style: TextStyle(
                        color: AppTheme.textH,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.card2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${ctrl.agents.length}',
                        style: const TextStyle(
                          color: AppTheme.textM,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ]),
                  if (ctrl.agents.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Row(children: [
                      // Search field
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: TextField(
                            onChanged: ctrl.setSearchQuery,
                            style: const TextStyle(color: AppTheme.textH, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search agents...',
                              hintStyle: const TextStyle(color: AppTheme.textM, fontSize: 13),
                              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.textM),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              filled: true,
                              fillColor: AppTheme.card,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: AppTheme.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: AppTheme.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: AppTheme.gold, width: 1.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Sort chips
                      _ProfileSortChip(
                        label: 'Newest',
                        isSelected: ctrl.sortMode.value == 'newest',
                        onTap: () => ctrl.setSortMode('newest'),
                      ),
                      const SizedBox(width: 6),
                      _ProfileSortChip(
                        label: 'Most Saved',
                        isSelected: ctrl.sortMode.value == 'most_saved',
                        onTap: () => ctrl.setSortMode('most_saved'),
                      ),
                      const SizedBox(width: 6),
                      _ProfileSortChip(
                        label: 'Most Used',
                        isSelected: ctrl.sortMode.value == 'most_used',
                        onTap: () => ctrl.setSortMode('most_used'),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ),
          // Agents grid or empty state
          if (ctrl.agents.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.gold.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.gold.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_outlined,
                        color: AppTheme.gold,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No agents created yet',
                      style: TextStyle(
                        color: AppTheme.textH,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'This creator hasn\'t published any agents.',
                      style: TextStyle(
                        color: AppTheme.textM,
                        fontSize: 13,
                      ),
                    ),
                  ]),
                ),
              ),
            )
          else if (ctrl.filteredAgents.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.search_off_rounded, size: 48,
                    color: AppTheme.textM.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  const Text('No matching agents',
                    style: TextStyle(color: AppTheme.textM, fontSize: 14)),
                ]),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => AgentCard(agent: ctrl.filteredAgents[i]),
                  childCount: ctrl.filteredAgents.length,
                ),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 300,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.72,
                ),
              ),
            ),
          // ── Activity Feed ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Obx(() => _ActivityFeedSection(ctrl: ctrl)),
          ),
        ],
      ]),
    ));
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(children: [
        const SizedBox(height: 32),
        // Avatar skeleton
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppTheme.card,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.border),
          ),
        ),
        const SizedBox(height: 16),
        // Name skeleton
        Container(
          width: 160,
          height: 16,
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 200,
          height: 12,
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 32),
        // Stats skeleton
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (int i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 24),
            Container(
              width: 80,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 32),
        // Grid skeleton
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.72,
            ),
            itemCount: 4,
            itemBuilder: (_, __) => Container(
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildErrorState(_PublicProfileController ctrl) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: AppTheme.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            ctrl.error.value!,
            style: const TextStyle(
              color: AppTheme.textB,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: ctrl.load,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  static String _shorten(String w) =>
      w.length > 10 ? '${w.substring(0, 6)}...${w.substring(w.length - 4)}' : w;
}

// ── Profile Header ──────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final String wallet;
  final _PublicProfileController ctrl;
  const _ProfileHeader({required this.wallet, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final username = ctrl.profile.value?['username'] as String? ?? '';
    final bio = ctrl.profile.value?['bio'] as String? ?? '';
    final memberSince = ctrl.profile.value?['created_at'] as String?;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
      ),
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
      child: Column(children: [
        // Avatar + name row
        Row(children: [
          // Avatar circle
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.2),
                  AppTheme.gold.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: const Icon(Icons.person_rounded, color: AppTheme.primary, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username or wallet
                if (username.isNotEmpty) ...[
                  Text(
                    username,
                    style: const TextStyle(
                      color: AppTheme.textH,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    _PublicProfileScreenState._shorten(wallet),
                    style: const TextStyle(
                      color: AppTheme.textM,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ] else
                  SelectableText(
                    _PublicProfileScreenState._shorten(wallet),
                    style: const TextStyle(
                      color: AppTheme.textH,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                // Member since
                if (memberSince != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.calendar_today_outlined, size: 12, color: AppTheme.textM),
                    const SizedBox(width: 5),
                    Text(
                      'Member since ${_formatMemberDate(memberSince)}',
                      style: const TextStyle(
                        color: AppTheme.textM,
                        fontSize: 11,
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ]),
        // Bio
        if (bio.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              bio,
              style: const TextStyle(
                color: AppTheme.textB,
                fontSize: 13,
                height: 1.5,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ]),
    );
  }

  String _formatMemberDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

// ── Stats Row ───────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final _PublicProfileController ctrl;
  const _StatsRow({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
      child: Row(children: [
        _StatCard(
          icon: Icons.auto_awesome_rounded,
          value: '${ctrl.agentCount}',
          label: 'Agents',
          color: AppTheme.primary,
        ),
        const SizedBox(width: 12),
        _StatCard(
          icon: Icons.bookmark_rounded,
          value: '${ctrl.totalSaves}',
          label: 'Total Saves',
          color: AppTheme.gold,
        ),
        const SizedBox(width: 12),
        _StatCard(
          icon: Icons.play_circle_rounded,
          value: '${ctrl.totalUses}',
          label: 'Total Uses',
          color: AppTheme.olive,
        ),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textM,
              fontSize: 11,
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Badges Section ──────────────────────────────────────────────────────────

class _BadgesSection extends StatelessWidget {
  final List<_BadgeInfo> badges;
  const _BadgesSection({required this.badges});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.emoji_events_outlined, size: 16, color: AppTheme.gold),
            SizedBox(width: 8),
            Text(
              'Achievements',
              style: TextStyle(
                color: AppTheme.textH,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: badges.map((b) => _BadgeChip(badge: b)).toList(),
          ),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatefulWidget {
  final _BadgeInfo badge;
  const _BadgeChip({required this.badge});

  @override
  State<_BadgeChip> createState() => _BadgeChipState();
}

class _BadgeChipState extends State<_BadgeChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.badge.description,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.badge.color.withValues(alpha: 0.12)
                : widget.badge.color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.badge.color.withValues(alpha: _hovered ? 0.4 : 0.2),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.badge.icon, size: 14, color: widget.badge.color),
            const SizedBox(width: 6),
            Text(
              widget.badge.label,
              style: TextStyle(
                color: widget.badge.color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Badge info model ────────────────────────────────────────────────────────

class _BadgeInfo {
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  const _BadgeInfo({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });
}

// ── Local micro-controller ──────────────────────────────────────────────────

class _PublicProfileController extends GetxController {
  final String wallet;
  _PublicProfileController(this.wallet);

  final profile = Rxn<Map<String, dynamic>>();
  final agents = <AgentModel>[].obs;
  final isLoading = true.obs;
  final error = RxnString();

  // Social state
  final isFollowing = false.obs;
  final followerCount = 0.obs;
  final followingCount = 0.obs;
  final isFollowLoading = false.obs;

  // Activity feed
  final activityItems = <Map<String, dynamic>>[].obs;
  final activityLoading = false.obs;
  final activityNextCursor = 0.obs;

  // Filter/sort state
  final searchQuery = ''.obs;
  final sortMode = 'newest'.obs; // newest, most_saved, most_used

  void setSearchQuery(String q) => searchQuery.value = q;
  void setSortMode(String m) => sortMode.value = m;

  List<AgentModel> get filteredAgents {
    var result = agents.toList();

    // Search filter
    if (searchQuery.value.isNotEmpty) {
      final q = searchQuery.value.toLowerCase();
      result = result.where((a) => a.title.toLowerCase().contains(q)).toList();
    }

    // Sort
    switch (sortMode.value) {
      case 'most_saved':
        result.sort((a, b) => b.saveCount.compareTo(a.saveCount));
      case 'most_used':
        result.sort((a, b) => b.useCount.compareTo(a.useCount));
      default: // newest
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return result;
  }

  int get agentCount =>
      (profile.value?['agent_count'] as num?)?.toInt() ?? agents.length;
  int get totalSaves =>
      (profile.value?['total_saves'] as num?)?.toInt() ??
      agents.fold(0, (s, a) => s + a.saveCount);
  int get totalUses =>
      (profile.value?['total_uses'] as num?)?.toInt() ??
      agents.fold(0, (s, a) => s + a.useCount);

  List<_BadgeInfo> get badges {
    final list = <_BadgeInfo>[];
    if (agentCount >= 1) {
      list.add(const _BadgeInfo(
        label: 'Creator',
        description: 'Published at least 1 agent',
        icon: Icons.auto_awesome_rounded,
        color: AppTheme.primary,
      ));
    }
    if (agentCount >= 5) {
      list.add(const _BadgeInfo(
        label: 'Prolific',
        description: 'Published 5+ agents',
        icon: Icons.stars_rounded,
        color: AppTheme.gold,
      ));
    }
    if (totalSaves >= 10) {
      list.add(const _BadgeInfo(
        label: 'Popular',
        description: 'Agents saved 10+ times by others',
        icon: Icons.favorite_rounded,
        color: Color(0xFFE57373),
      ));
    }
    if (totalSaves >= 50) {
      list.add(const _BadgeInfo(
        label: 'Trending',
        description: 'Agents saved 50+ times',
        icon: Icons.trending_up_rounded,
        color: AppTheme.olive,
      ));
    }
    return list;
  }

  @override
  void onInit() {
    super.onInit();
    load();
    _loadSocial();
    loadActivity();
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      final result = await ApiService.instance.getPublicProfile(wallet);
      if (result == null) {
        error.value = 'Profile not found.';
      } else {
        profile.value = result;
        agents.value = (result['agents'] as List<dynamic>? ?? [])
            .map((e) => AgentModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      error.value = 'Failed to load profile.';
    }
    isLoading.value = false;
  }

  Future<void> _loadSocial() async {
    final data = await ApiService.instance.getFollowStatus(wallet);
    if (data != null) {
      isFollowing.value = data['is_following'] as bool? ?? false;
      followerCount.value = (data['followers'] as num?)?.toInt() ?? 0;
      followingCount.value = (data['following'] as num?)?.toInt() ?? 0;
    }
  }

  Future<void> toggleFollow() async {
    if (isFollowLoading.value) return;
    isFollowLoading.value = true;
    final wasFollowing = isFollowing.value;
    // Optimistic update.
    isFollowing.value = !wasFollowing;
    followerCount.value += wasFollowing ? -1 : 1;

    final ok = wasFollowing
        ? await ApiService.instance.unfollowUser(wallet)
        : await ApiService.instance.followUser(wallet);

    if (!ok) {
      // Revert on failure.
      isFollowing.value = wasFollowing;
      followerCount.value += wasFollowing ? 1 : -1;
    }
    isFollowLoading.value = false;
  }

  Future<void> loadActivity({bool loadMore = false}) async {
    if (activityLoading.value) return;
    activityLoading.value = true;
    final beforeId = loadMore ? activityNextCursor.value : 0;
    final data = await ApiService.instance.getActivityFeed(
      wallet,
      beforeId: beforeId,
      limit: 10,
    );
    if (data != null) {
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      if (loadMore) {
        activityItems.addAll(items);
      } else {
        activityItems.value = items;
      }
      activityNextCursor.value = (data['next_cursor'] as num?)?.toInt() ?? 0;
    }
    activityLoading.value = false;
  }
}

// ── Follow Section ──────────────────────────────────────────────────────────

class _FollowSection extends StatelessWidget {
  final _PublicProfileController ctrl;
  final bool isOwnProfile;
  const _FollowSection({required this.ctrl, required this.isOwnProfile});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Follower / Following count pills
        _CountPill(
          icon: Icons.people_outline_rounded,
          count: ctrl.followerCount.value,
          label: 'followers',
        ),
        const SizedBox(width: 10),
        _CountPill(
          icon: Icons.person_add_alt_1_outlined,
          count: ctrl.followingCount.value,
          label: 'following',
        ),
        if (!isOwnProfile) ...[
          const Spacer(),
          // Follow / Unfollow button
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: ctrl.isFollowLoading.value
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    ),
                  )
                : OutlinedButton.icon(
                    key: ValueKey(ctrl.isFollowing.value),
                    onPressed: ctrl.toggleFollow,
                    icon: Icon(
                      ctrl.isFollowing.value
                          ? Icons.person_remove_outlined
                          : Icons.person_add_alt_1_outlined,
                      size: 16,
                    ),
                    label: Text(
                      ctrl.isFollowing.value ? 'Unfollow' : 'Follow',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ctrl.isFollowing.value
                          ? AppTheme.textM
                          : AppTheme.primary,
                      side: BorderSide(
                        color: ctrl.isFollowing.value
                            ? AppTheme.border
                            : AppTheme.primary,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
          ),
        ],
      ],
    );
  }
}

class _CountPill extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  const _CountPill({required this.icon, required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.card2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: AppTheme.textM),
        const SizedBox(width: 5),
        Text(
          '$count',
          style: const TextStyle(
            color: AppTheme.textH,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textM, fontSize: 11),
        ),
      ]),
    );
  }
}

// ── Activity Feed Section ───────────────────────────────────────────────────

class _ActivityFeedSection extends StatelessWidget {
  final _PublicProfileController ctrl;
  const _ActivityFeedSection({required this.ctrl});

  static const _activityIcons = {
    'agent_created': (Icons.add_circle_outline_rounded, Color(0xFF66BB6A)),
    'agent_forked': (Icons.fork_right_rounded, Color(0xFF42A5F5)),
    'agent_saved': (Icons.bookmark_add_outlined, AppTheme.gold),
  };

  @override
  Widget build(BuildContext context) {
    if (ctrl.activityItems.isEmpty && !ctrl.activityLoading.value) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: AppTheme.border, height: 32),
          const Row(children: [
            Icon(Icons.timeline_rounded, size: 16, color: AppTheme.textM),
            SizedBox(width: 8),
            Text(
              'Recent Activity',
              style: TextStyle(
                color: AppTheme.textH,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          if (ctrl.activityLoading.value && ctrl.activityItems.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            ...ctrl.activityItems.map((item) {
              final type = item['type'] as String? ?? '';
              final agentTitle = item['agent_title'] as String? ?? 'Unknown agent';
              final createdAt = item['created_at'] as String?;
              final (icon, color) = _activityIcons[type] ??
                  (Icons.circle_outlined, AppTheme.textM);
              final verb = switch (type) {
                'agent_created' => 'Created',
                'agent_forked' => 'Forked',
                'agent_saved' => 'Saved',
                _ => type,
              };
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          color: AppTheme.textB,
                          fontSize: 13,
                        ),
                        children: [
                          TextSpan(
                            text: '$verb ',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(text: agentTitle),
                        ],
                      ),
                    ),
                  ),
                  if (createdAt != null)
                    Text(
                      _relativeTime(createdAt),
                      style: const TextStyle(
                        color: AppTheme.textM,
                        fontSize: 11,
                      ),
                    ),
                ]),
              );
            }),
          if (ctrl.activityNextCursor.value > 0)
            TextButton(
              onPressed: () => ctrl.loadActivity(loadMore: true),
              child: const Text('Load more'),
            ),
        ],
      ),
    );
  }

  String _relativeTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toUtc();
      final diff = DateTime.now().toUtc().difference(dt);
      if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'just now';
    } catch (_) {
      return '';
    }
  }
}

// ── Profile action button (app bar) ─────────────────────────────────────────

class _ProfileActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  const _ProfileActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  State<_ProfileActionButton> createState() => _ProfileActionButtonState();
}

class _ProfileActionButtonState extends State<_ProfileActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _hovered ? AppTheme.card2 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              color: _hovered ? AppTheme.textH : AppTheme.textM,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sort chip for profile agent list ────────────────────────────────────────

class _ProfileSortChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _ProfileSortChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ProfileSortChip> createState() => _ProfileSortChipState();
}

class _ProfileSortChipState extends State<_ProfileSortChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppTheme.gold.withValues(alpha: 0.15)
                : (_hovered ? AppTheme.card2 : AppTheme.card),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isSelected
                  ? AppTheme.gold.withValues(alpha: 0.5)
                  : (_hovered ? AppTheme.border2 : AppTheme.border),
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.isSelected ? AppTheme.gold : AppTheme.textM,
              fontSize: 11,
              fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
