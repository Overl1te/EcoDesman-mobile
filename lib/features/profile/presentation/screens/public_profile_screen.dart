import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../../shared/widgets/app_empty_state.dart";
import "../../../../shared/widgets/app_error_state.dart";
import "../../../auth/data/repositories/auth_repository_impl.dart";
import "../../../auth/domain/models/app_user.dart";
import "../../../auth/presentation/controllers/auth_controller.dart";
import "../../../feed/presentation/widgets/post_card.dart";
import "../controllers/profile_controller.dart";
import "../widgets/profile_summary_card.dart";

class PublicProfileScreen extends ConsumerStatefulWidget {
  const PublicProfileScreen({super.key, required this.userId});

  final int userId;

  @override
  ConsumerState<PublicProfileScreen> createState() =>
      _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {
  bool _isBusy = false;

  Future<void> _refreshData() async {
    ref.invalidate(publicProfileProvider(widget.userId));
    ref.invalidate(userPostsProvider(widget.userId));
    await Future.wait([
      ref.refresh(publicProfileProvider(widget.userId).future),
      ref.refresh(userPostsProvider(widget.userId).future),
    ]);
  }

  Future<void> _runModerationAction(
    Future<AppUser> Function() action, {
    required String successMessage,
  }) async {
    setState(() {
      _isBusy = true;
    });

    try {
      await action();
      await _refreshData();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(publicProfileProvider(widget.userId));
    final postsAsync = ref.watch(userPostsProvider(widget.userId));
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Профиль")),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          return AppErrorState(
            title: "Не удалось открыть профиль",
            message: "Проверьте подключение и попробуйте снова.",
            onRetry: _refreshData,
          );
        },
        data: (user) {
          final canAdminister =
              authState.user?.isAdmin == true && authState.user!.id != user.id;

          return RefreshIndicator(
            onRefresh: _refreshData,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                ProfileSummaryCard(
                  user: user,
                  actions: canAdminister
                      ? [
                          FilledButton.tonalIcon(
                            onPressed: _isBusy
                                ? null
                                : () {
                                    _runModerationAction(
                                      () => ref
                                          .read(authRepositoryProvider)
                                          .warnUser(user.id),
                                      successMessage: "Предупреждение выдано",
                                    );
                                  },
                            icon: const Icon(Icons.warning_amber_rounded),
                            label: const Text("Предупредить"),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _isBusy
                                ? null
                                : () {
                                    _runModerationAction(
                                      () => user.isBanned
                                          ? ref
                                                .read(authRepositoryProvider)
                                                .unbanUser(user.id)
                                          : ref
                                                .read(authRepositoryProvider)
                                                .banUser(user.id),
                                      successMessage: user.isBanned
                                          ? "Пользователь разблокирован"
                                          : "Пользователь заблокирован",
                                    );
                                  },
                            icon: Icon(
                              user.isBanned ? Icons.lock_open : Icons.block,
                            ),
                            label: Text(
                              user.isBanned ? "Разбанить" : "Забанить",
                            ),
                          ),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: user.role,
                              items: const [
                                DropdownMenuItem(
                                  value: "user",
                                  child: Text("Пользователь"),
                                ),
                                DropdownMenuItem(
                                  value: "moderator",
                                  child: Text("Модератор"),
                                ),
                                DropdownMenuItem(
                                  value: "admin",
                                  child: Text("Админ"),
                                ),
                              ],
                              onChanged: _isBusy
                                  ? null
                                  : (value) {
                                      if (value == null || value == user.role) {
                                        return;
                                      }
                                      _runModerationAction(
                                        () => ref
                                            .read(authRepositoryProvider)
                                            .updateUserRole(
                                              userId: user.id,
                                              role: value,
                                            ),
                                        successMessage: "Роль обновлена",
                                      );
                                    },
                            ),
                          ),
                        ]
                      : const [],
                ),
                const SizedBox(height: 20),
                Text(
                  "Публикации",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                postsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stackTrace) {
                    return AppErrorState(
                      title: "Не удалось загрузить посты",
                      message: "Попробуйте обновить страницу профиля.",
                      onRetry: () {
                        ref.invalidate(userPostsProvider(widget.userId));
                      },
                    );
                  },
                  data: (page) {
                    if (page.items.isEmpty) {
                      return const AppEmptyState(
                        title: "Пока нет публикаций",
                        message:
                            "Как только пользователь опубликует посты, они появятся здесь.",
                      );
                    }

                    return Column(
                      children: [
                        for (final post in page.items) ...[
                          PostCard(
                            post: post,
                            onTap: () => context.push("/posts/${post.id}"),
                            onAuthorTap: () {},
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
