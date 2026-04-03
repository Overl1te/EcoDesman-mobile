import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../feed/domain/models/posts_query.dart";
import "../../../feed/presentation/controllers/feed_controller.dart";
import "../../../feed/presentation/widgets/posts_collection_view.dart";

class EventsPlaceholderScreen extends ConsumerStatefulWidget {
  const EventsPlaceholderScreen({super.key});

  @override
  ConsumerState<EventsPlaceholderScreen> createState() =>
      _EventsPlaceholderScreenState();
}

class _EventsPlaceholderScreenState
    extends ConsumerState<EventsPlaceholderScreen> {
  late final ScrollController _scrollController;
  String _eventScope = "upcoming";
  String _ordering = "recent";

  PostsQuery get _query =>
      PostsQuery(kind: "event", eventScope: _eventScope, ordering: _ordering);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 320) {
      ref.read(postsCollectionControllerProvider(_query).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = postsCollectionControllerProvider(_query);
    final state = ref.watch(provider);

    return PostsCollectionView(
      state: state,
      scrollController: _scrollController,
      onRefresh: () => ref.read(provider.notifier).refreshFeed(),
      onRetry: () => ref.invalidate(provider),
      errorMessageBuilder: ref.read(provider.notifier).toErrorMessage,
      emptyTitle: "Подходящих мероприятий пока нет",
      emptyMessage:
          "Попробуйте сменить период или дождитесь новых городских событий.",
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final scope in const [
                ("upcoming", "Ближайшие"),
                ("today", "Сегодня"),
                ("week", "Неделя"),
                ("all", "Все"),
              ])
                ChoiceChip(
                  label: Text(scope.$2),
                  selected: _eventScope == scope.$1,
                  onSelected: (_) => setState(() {
                    _eventScope = scope.$1;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text("По дате"),
                selected: _ordering == "recent",
                onSelected: (_) => setState(() {
                  _ordering = "recent";
                }),
              ),
              ChoiceChip(
                label: const Text("Популярные"),
                selected: _ordering == "popular",
                onSelected: (_) => setState(() {
                  _ordering = "popular";
                }),
              ),
            ],
          ),
        ],
      ),
      onLikeTap: (post) async {
        await ref.read(provider.notifier).toggleLike(post);
      },
      onFavoriteTap: (post) async {
        await ref.read(provider.notifier).toggleFavorite(post);
      },
    );
  }
}
