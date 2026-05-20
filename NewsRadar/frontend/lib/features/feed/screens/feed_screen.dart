import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/models/models.dart';
import '../../../shared/models/user.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/badges.dart';
import '../../../core/theme.dart';
import '../../articles/screens/article_detail_screen.dart';
import '../../auth/screens/auth_screen.dart';
import '../../chat/screens/chat_screen.dart';
import '../../../shared/utils/url_launcher_helper.dart';
import '../widgets/article_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FEED SCREEN (Consumer-facing)
// ─────────────────────────────────────────────────────────────────────────────

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  final _searchController = TextEditingController();
  late TabController _tabController;

  List<Article> _articles = [];
  List<Article> _breaking = [];
  Set<String> _bookmarks = {};
  bool _loading = true;
  String? _error;
  String? _selectedCategory;
  bool _showSearchBar = false;

  final List<String> _categories = [
    'all', 'technology', 'business', 'health',
    'science', 'sports', 'entertainment',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(_onTabChange);
    _loadBookmarks();
    _loadArticles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _bookmarks = prefs.getStringList('bookmarks')?.toSet() ?? {});
  }

  Future<void> _toggleBookmark(Article a) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_bookmarks.contains(a.url)) {
        _bookmarks.remove(a.url);
      } else {
        _bookmarks.add(a.url);
      }
    });
    await prefs.setStringList('bookmarks', _bookmarks.toList());
    HapticFeedback.lightImpact();
  }

  void _onTabChange() {
    if (_tabController.indexIsChanging) return;
    final cat = _categories[_tabController.index];
    setState(() { _selectedCategory = cat == 'all' ? null : cat; });
    _loadArticles();
  }

  Future<void> _loadArticles() async {
    setState(() { _loading = true; _error = null; });
    try {
      final articles = await _api.getArticles(category: _selectedCategory);
      // First 3 = breaking news (most recent)
      setState(() {
        _articles = articles;
        _breaking = articles.take(3).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _searchArticles(String query) async {
    if (query.trim().isEmpty) { _loadArticles(); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final articles = await _api.searchArticles(query);
      setState(() { _articles = articles; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _openArticle(Article article) {
    Navigator.push(context,
      MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: article)));
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      // Pulsing AI Chat FAB
      floatingActionButton: _buildFAB(),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, inner) => [
          SliverAppBar(
            floating: true, snap: true, pinned: false,
            backgroundColor: AppColors.primary,
            expandedHeight: 110,
            flexibleSpace: FlexibleSpaceBar(background: _buildHeader()),
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(_showSearchBar ? 90 : 50),
              child: Column(children: [
                if (_showSearchBar) _buildSearchBar(),
                _buildCategoryTabs(),
              ]),
            ),
          ),
        ],
        body: RefreshIndicator(
          onRefresh: _loadArticles,
          color: AppColors.accent,
          backgroundColor: AppColors.primaryLight,
          child: _buildBody(),
        ),
      ),
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────
  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => const ChatScreen())),
      backgroundColor: const Color(0xFF004E9F),
      icon: const Icon(Icons.mic_rounded, color: Colors.white),
      label: Text('Ask AI',
        style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
      elevation: 8,
    )
      .animate(onPlay: (c) => c.repeat(reverse: true))
      .elevation(begin: 6, end: 14, duration: 1800.ms, curve: Curves.easeInOut);
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final user = AuthService().currentUser;
    return Container(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 0),
      child: Row(children: [
        // Logo
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accentDeep]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.radar_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('NewsRadar', style: GoogleFonts.inter(
              fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            Text('AI-Powered News Intelligence', style: GoogleFonts.inter(
              fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
        const Spacer(),
        // LIVE badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.badgeGreen.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.badgeGreen.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6,
              decoration: const BoxDecoration(color: AppColors.badgeGreen, shape: BoxShape.circle))
                .animate(onPlay: (c) => c.repeat()).fade(duration: 800.ms),
            const SizedBox(width: 4),
            Text('LIVE', style: GoogleFonts.inter(
              fontSize: 10, color: AppColors.badgeGreen, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ]),
        ),
        const SizedBox(width: 6),
        // Search toggle
        IconButton(
          icon: Icon(_showSearchBar ? Icons.search_off_rounded : Icons.search_rounded,
            color: AppColors.textMuted, size: 22),
          onPressed: () => setState(() {
            _showSearchBar = !_showSearchBar;
            if (!_showSearchBar) {
              _searchController.clear();
              _loadArticles();
            }
          }),
        ),
        // Bookmarks
        IconButton(
          icon: const Icon(Icons.bookmark_rounded, color: AppColors.textMuted, size: 22),
          tooltip: 'Saved articles',
          onPressed: () => _showBookmarksSheet(),
        ),
        // User avatar
        if (user != null) ...[
          PopupMenuButton<String>(
            offset: const Offset(0, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: AppColors.surface,
            onSelected: (v) {
              if (v == 'logout') {
                AuthService().logout();
                Navigator.pushAndRemoveUntil(context,
                  MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.name, style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Text(user.email, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Color(user.role.colorValue).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Color(user.role.colorValue).withValues(alpha: 0.4)),
                    ),
                    child: Text(user.role.label, style: GoogleFonts.jetBrainsMono(
                      fontSize: 10, color: Color(user.role.colorValue), fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(children: [
                  const Icon(Icons.logout_rounded, color: AppColors.badgeRed, size: 16),
                  const SizedBox(width: 8),
                  Text('Sign out', style: GoogleFonts.inter(color: AppColors.badgeRed, fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
            child: CircleAvatar(
              radius: 17,
              backgroundColor: Color(user.role.colorValue).withValues(alpha: 0.2),
              child: Text(user.avatarInitials, style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w700, color: Color(user.role.colorValue))),
            ),
          ),
        ],
      ]),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search news, topics, people...',
          hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textMuted),
                onPressed: () { _searchController.clear(); _loadArticles(); })
            : null,
          filled: true, fillColor: AppColors.primaryLight,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
        ),
        onChanged: (v) => setState(() {}),
        onSubmitted: _searchArticles,
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.2);
  }

  // ── Category tabs ──────────────────────────────────────────────────────────
  Widget _buildCategoryTabs() {
    return SizedBox(
      height: 42,
      child: TabBar(
        controller: _tabController, isScrollable: true,
        indicatorColor: AppColors.accent, indicatorWeight: 2,
        labelColor: AppColors.accent, unselectedLabelColor: AppColors.textMuted,
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
        tabs: _categories.map((c) => Tab(text: c[0].toUpperCase() + c.substring(1))).toList(),
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_loading) return _buildShimmer();
    if (_error != null) return _buildError();
    if (_articles.isEmpty) return _buildEmpty();

    return CustomScrollView(
      slivers: [
        // Breaking news strip (only on "All" tab)
        if (_selectedCategory == null && _breaking.isNotEmpty)
          SliverToBoxAdapter(child: _buildBreakingBanner()),

        // Stats row
        SliverToBoxAdapter(child: _buildStatsRow()),

        // Article list
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => EnhancedArticleCard(
                article: _articles[i],
                index: i,
                isBookmarked: _bookmarks.contains(_articles[i].url),
                onTap: () => _openArticle(_articles[i]),
                onBookmark: () => _toggleBookmark(_articles[i]),
                onShare: () {
                  Clipboard.setData(ClipboardData(text: _articles[i].url));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Link copied! 📋',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      duration: 1500.ms,
                      backgroundColor: AppColors.accentDeep,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
              ),
              childCount: _articles.length,
            ),
          ),
        ),
      ],
    );
  }

  // ── Breaking News Banner ───────────────────────────────────────────────────
  Widget _buildBreakingBanner() {
    return Container(
      height: 52,
      margin: const EdgeInsets.only(top: 8),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          margin: const EdgeInsets.only(left: 16),
          decoration: BoxDecoration(
            color: AppColors.badgeRed,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('BREAKING', style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _breaking.length,
            separatorBuilder: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('•', style: GoogleFonts.inter(color: AppColors.textMuted)),
            ),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => _openArticle(_breaking[i]),
              child: Center(child: Text(
                _breaking[i].title.length > 55
                  ? '${_breaking[i].title.substring(0, 55)}…'
                  : _breaking[i].title,
                style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              )),
            ),
          ),
        ),
      ]),
    ).animate().fadeIn(duration: 400.ms);
  }

  // ── Stats Row ──────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    final verified = _articles.where((a) => a.status == 'VERIFIED').length;
    final disputed = _articles.where((a) => a.status == 'DISPUTED').length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: [
        _MiniStat(label: '${_articles.length} articles', icon: Icons.article_outlined, color: AppColors.textMuted),
        const SizedBox(width: 12),
        _MiniStat(label: '$verified verified', icon: Icons.verified_rounded, color: AppColors.badgeGreen),
        const SizedBox(width: 12),
        if (disputed > 0)
          _MiniStat(label: '$disputed disputed', icon: Icons.warning_amber_rounded, color: AppColors.badgeAmber),
      ]),
    );
  }

  // ── Shimmer ────────────────────────────────────────────────────────────────
  Widget _buildShimmer() => ListView.builder(
    itemCount: 5,
    itemBuilder: (_, __) => const LoadingShimmerCard(),
  );

  // ── Error ──────────────────────────────────────────────────────────────────
  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: AppColors.badgeRed.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.wifi_off_rounded, color: AppColors.badgeRed, size: 34),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 20),
        Text('Backend not reachable', style: GoogleFonts.inter(
          fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text('Start the Python server first:\npython -m uvicorn main:app --port 8000',
          style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.textMuted),
          textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _loadArticles,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentDeep,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ChatScreen())),
          icon: const Icon(Icons.mic_rounded, size: 18),
          label: const Text('Use AI Chat anyway'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accentDeep,
            side: const BorderSide(color: AppColors.accentDeep),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]),
    ),
  );

  // ── Empty ──────────────────────────────────────────────────────────────────
  Widget _buildEmpty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.search_off_rounded, size: 56, color: AppColors.textMuted),
      const SizedBox(height: 16),
      Text('No articles found', style: GoogleFonts.inter(
        fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      Text('Try a different category or search term',
        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
    ]),
  );

  // ── Bookmarks bottom sheet ─────────────────────────────────────────────────
  void _showBookmarksSheet() {
    final saved = _articles.where((a) => _bookmarks.contains(a.url)).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.primaryLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(children: [
        const SizedBox(height: 12),
        Container(width: 36, height: 4,
          decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            const Icon(Icons.bookmark_rounded, color: AppColors.accent, size: 20),
            const SizedBox(width: 8),
            Text('Saved Articles (${saved.length})',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ]),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        Expanded(
          child: saved.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.bookmark_border_rounded, size: 48, color: AppColors.textMuted),
                const SizedBox(height: 12),
                Text('No saved articles yet', style: GoogleFonts.inter(color: AppColors.textMuted)),
                Text('Tap 🔖 on any article to save it',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              ]))
            : ListView.builder(
                itemCount: saved.length,
                itemBuilder: (ctx, i) => ListTile(
                  leading: const Icon(Icons.article_rounded, color: AppColors.accent),
                  title: Text(saved[i].title,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(saved[i].source.name,
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                  onTap: () {
                    Navigator.pop(context);
                    _openArticle(saved[i]);
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.bookmark_remove_rounded, color: AppColors.badgeRed, size: 20),
                    onPressed: () {
                      _toggleBookmark(saved[i]);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ENHANCED ARTICLE CARD
// ─────────────────────────────────────────────────────────────────────────────

class EnhancedArticleCard extends StatelessWidget {
  final Article article;
  final int index;
  final bool isBookmarked;
  final VoidCallback onTap;
  final VoidCallback onBookmark;
  final VoidCallback onShare;

  const EnhancedArticleCard({
    super.key,
    required this.article,
    required this.onTap,
    required this.onBookmark,
    required this.onShare,
    this.index = 0,
    this.isBookmarked = false,
  });

  String _formatTime() {
    try {
      final dt = DateTime.parse(article.publishedAt);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return article.publishedAt.length > 10 ? article.publishedAt.substring(0, 10) : article.publishedAt;
    }
  }

  Color get _verdictColor {
    switch (article.status) {
      case 'VERIFIED': return AppColors.badgeGreen;
      case 'DISPUTED': return AppColors.badgeRed;
      case 'MISINFORMATION': return const Color(0xFF7C3AED);
      default: return AppColors.badgeAmber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            if (article.urlToImage != null)
              Stack(children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: Image.network(
                    article.urlToImage!,
                    height: 175, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _noImagePlaceholder(),
                  ),
                ),
                // Verdict badge overlay on image
                Positioned(
                  top: 10, left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _verdictColor.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(article.status,
                      style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ])
            else
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: _noImagePlaceholder(),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Source + time
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(article.source.name,
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w600)),
                    ),
                    const Spacer(),
                    const Icon(Icons.schedule_rounded, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Text(_formatTime(),
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                  ]),
                  const SizedBox(height: 8),

                  // Title
                  Text(
                    article.title.length > 110 ? '${article.title.substring(0, 110)}…' : article.title,
                    style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary, height: 1.4),
                  ),

                  // Description
                  if (article.description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      article.description!.length > 90 ? '${article.description!.substring(0, 90)}…' : article.description!,
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                    ),
                  ],

                  const SizedBox(height: 10),
                  // Bottom row
                  Row(children: [
                    VerdictBadgeWidget(status: article.status),
                    const Spacer(),
                    // Open in browser
                    OpenArticleButton(url: article.url, sourceName: article.source.name, compact: true),
                    const SizedBox(width: 8),
                    // Share
                    GestureDetector(
                      onTap: onShare,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: const Icon(Icons.share_rounded, size: 15, color: AppColors.textMuted),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Bookmark
                    GestureDetector(
                      onTap: onBookmark,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: isBookmarked
                            ? AppColors.accent.withValues(alpha: 0.12)
                            : AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isBookmarked ? AppColors.accent : AppColors.divider),
                        ),
                        child: Icon(
                          isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          size: 15,
                          color: isBookmarked ? AppColors.accent : AppColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Analyze CTA
                    GestureDetector(
                      onTap: onTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accentDeep]),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.psychology_rounded, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text('Analyze', style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    )
      .animate(delay: Duration(milliseconds: index * 60))
      .fadeIn(duration: 400.ms)
      .slideY(begin: 0.1, curve: Curves.easeOut);
  }

  Widget _noImagePlaceholder() => Container(
    height: 80, width: double.infinity,
    color: AppColors.surface,
    child: const Icon(Icons.article_rounded, color: AppColors.textMuted, size: 36),
  );
}

// ─── Mini stat chip ───────────────────────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _MiniStat({required this.label, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 13, color: color),
    const SizedBox(width: 4),
    Text(label, style: GoogleFonts.inter(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE FEED BODY (embedded in journalist/other dashboards)
// ─────────────────────────────────────────────────────────────────────────────

class FeedBodyContent extends StatefulWidget {
  const FeedBodyContent({super.key});
  @override
  State<FeedBodyContent> createState() => _FeedBodyContentState();
}

class _FeedBodyContentState extends State<FeedBodyContent> {
  final _api = ApiService();
  List<Article> _articles = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final articles = await _api.getArticles();
      setState(() { _articles = articles; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return ListView.builder(itemCount: 5, itemBuilder: (_, __) => const LoadingShimmerCard());
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, color: AppColors.textMuted, size: 48),
        const SizedBox(height: 12),
        Text('Backend not reachable', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
      ]));
    }
    if (_articles.isEmpty) {
      return Center(child: Text('No articles found',
        style: GoogleFonts.inter(fontSize: 15, color: AppColors.textMuted)));
    }
    return RefreshIndicator(
      onRefresh: _load, color: AppColors.accent,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: _articles.length,
        itemBuilder: (_, i) => ArticleCard(
          article: _articles[i], index: i,
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: _articles[i])))),
      ),
    );
  }
}
