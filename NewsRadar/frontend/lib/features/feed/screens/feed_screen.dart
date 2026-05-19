import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/models/models.dart';
import '../../../shared/models/user.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/badges.dart';
import '../../../core/theme.dart';
import '../../analysis/screens/analysis_screen.dart';
import '../../articles/screens/article_detail_screen.dart';
import '../../auth/screens/auth_screen.dart';
import '../widgets/article_card.dart';

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
  bool _loading = true;
  String? _error;
  String? _selectedCategory;

  final List<String> _categories = [
    'all', 'technology', 'business', 'health',
    'science', 'sports', 'entertainment',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(_onTabChange);
    _loadArticles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
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
      setState(() { _articles = articles; _loading = false; });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, inner) => [
          SliverAppBar(
            floating: true, snap: true, pinned: false,
            backgroundColor: AppColors.primary,
            expandedHeight: 110,
            flexibleSpace: FlexibleSpaceBar(background: _buildHeader()),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(80),
              child: Column(children: [_buildSearchBar(), _buildCategoryTabs()]),
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

  Widget _buildHeader() {
    final user = AuthService().currentUser;
    return Container(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 0),
      child: Row(
        children: [
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
              Text('NewsRadar', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              Text('AI-Powered News Intelligence', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
          const Spacer(),
          // LIVE badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.badgeGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.badgeGreen.withOpacity(0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6,
                decoration: const BoxDecoration(color: AppColors.badgeGreen, shape: BoxShape.circle))
                  .animate(onPlay: (c) => c.repeat()).fade(duration: 800.ms),
              const SizedBox(width: 4),
              Text('LIVE', style: GoogleFonts.inter(fontSize: 10, color: AppColors.badgeGreen, fontWeight: FontWeight.w700, letterSpacing: 1)),
            ]),
          ),
          const SizedBox(width: 10),
          // User avatar + logout popup
          if (user != null)
            PopupMenuButton<String>(
              offset: const Offset(0, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: AppColors.surface,
              onSelected: (v) {
                if (v == 'logout') {
                  AuthService().logout();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                    (_) => false,
                  );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text(user.email, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Color(user.role.colorValue).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Color(user.role.colorValue).withOpacity(0.4)),
                      ),
                      child: Text(user.role.label,
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, color: Color(user.role.colorValue), fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(children: [
                    const Icon(Icons.logout_rounded, size: 16, color: AppColors.badgeRed),
                    const SizedBox(width: 10),
                    Text('Sign out', style: GoogleFonts.inter(fontSize: 13, color: AppColors.badgeRed, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Color(user.role.colorValue).withOpacity(0.2),
                child: Text(
                  user.avatarInitials,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Color(user.role.colorValue)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search news...', hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
          filled: true, fillColor: AppColors.primaryLight,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
        ),
        onSubmitted: _searchArticles,
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return SizedBox(
      height: 36,
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

  Widget _buildBody() {
    if (_loading) return ListView.builder(itemCount: 5, itemBuilder: (_, __) => const LoadingShimmerCard());
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, color: AppColors.textMuted, size: 48),
        const SizedBox(height: 16),
        Text('Backend not reachable', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text('Start the Python server first', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(height: 20),
        ElevatedButton.icon(onPressed: _loadArticles, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
      ]));
    }
    if (_articles.isEmpty) {
      return Center(child: Text('No articles found', style: GoogleFonts.inter(fontSize: 16, color: AppColors.textMuted)));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: _articles.length,
      itemBuilder: (_, i) => ArticleCard(article: _articles[i], index: i, onTap: () => _openArticle(_articles[i])),
    );
  }
}

// ─── Reusable feed body (embedded in other dashboards) ────────────────────────

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
    if (_error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.wifi_off_rounded, color: AppColors.textMuted, size: 48),
      const SizedBox(height: 12),
      Text('Backend not reachable', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
    ]));
    if (_articles.isEmpty) return Center(child: Text('No articles found', style: GoogleFonts.inter(fontSize: 15, color: AppColors.textMuted)));
    return RefreshIndicator(
      onRefresh: _load, color: AppColors.accent,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: _articles.length,
        itemBuilder: (_, i) => ArticleCard(
          article: _articles[i], index: i,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: _articles[i])))),
      ),
    );
  }
}
