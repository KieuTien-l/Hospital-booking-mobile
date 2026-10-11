import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../models/usage_guide_ui_model.dart';
import '../models/usage_guide_demo_data.dart';
import '../widgets/help_support_card.dart';
import '../widgets/help_topic_card.dart';
import '../widgets/patient_home_background.dart';
import 'usage_guide_detail_page.dart';
import 'faq_detail_page.dart';

class UsageGuidePage extends StatefulWidget {
  const UsageGuidePage({super.key});
  @override
  State<UsageGuidePage> createState() => _UsageGuidePageState();
}

class _UsageGuidePageState extends State<UsageGuidePage> {
  final _search = TextEditingController();
  FaqCategory? _category;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final faqs = UsageGuideDemoData.faqs
        .where(
          (faq) =>
              (_category == null || faq.category == _category) &&
              faq.question.toLowerCase().contains(query),
        )
        .toList();
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme
            .apply(fontFamily: 'BeVietnamPro'),
      ),
      child: DefaultTabController(
        length: 2,
        child: PatientHomeBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              title: const Text(
                'Hướng dẫn sử dụng',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: HelpSupportCard(),
                        ),
                      ),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _HelpTabs(),
                      ),
                    ],
                    body: TabBarView(
                      children: [
                        ListView(
                          key: const PageStorageKey('usage-procedures'),
                          padding: const EdgeInsets.all(16),
                          children: [
                            for (final guide in UsageGuideDemoData.guides)
                              HelpTopicCard(
                                title: guide.title,
                                icon: guide.icon,
                                description: guide.description,
                                onTap: () => Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        UsageGuideDetailPage(guide: guide),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        ListView(
                          key: const PageStorageKey('usage-faqs'),
                          padding: const EdgeInsets.all(16),
                          children: [
                            TextField(
                              controller: _search,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Tìm kiếm câu hỏi...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: query.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Xóa tìm kiếm',
                                        icon: const Icon(Icons.clear),
                                        onPressed: () =>
                                            setState(() => _search.clear()),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                ChoiceChip(
                                  label: const Text('Tất cả'),
                                  selected: _category == null,
                                  onSelected: (_) =>
                                      setState(() => _category = null),
                                ),
                                for (final category in FaqCategory.values)
                                  ChoiceChip(
                                    label: Text(category.label),
                                    selected: _category == category,
                                    onSelected: (_) =>
                                        setState(() => _category = category),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (faqs.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 48,
                                      color: AppColors.textSecondary,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Không tìm thấy câu hỏi phù hợp.',
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            for (final faq in faqs)
                              HelpTopicCard(
                                title: faq.question,
                                icon: Icons.help_outline,
                                onTap: () {
                                  FocusScope.of(context).unfocus();
                                  Navigator.of(context).push<void>(
                                    MaterialPageRoute(
                                      builder: (_) => FaqDetailPage(faq: faq),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HelpTabs extends SliverPersistentHeaderDelegate {
  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Material(
    color: AppColors.surface,
    child: const SizedBox(
      height: 56,
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.center,
        labelColor: AppColors.textOnPrimary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primaryDark,
        tabs: [
          Tab(text: 'Quy trình'),
          Tab(text: 'Câu hỏi thường gặp'),
        ],
      ),
    ),
  );
  @override
  bool shouldRebuild(covariant _HelpTabs oldDelegate) => false;
}
