import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../../core/network/error_message.dart";
import "../../../../core/routing/app_routes.dart";
import "../../../../core/utils/date_formatter.dart";
import "../../../../shared/widgets/app_empty_state.dart";
import "../../../../shared/widgets/app_error_state.dart";
import "../../../../shared/widgets/role_chip.dart";
import "../../../auth/data/repositories/auth_repository_impl.dart";
import "../../../auth/domain/models/app_user.dart";
import "../../../auth/presentation/controllers/auth_controller.dart";
import "../../../feed/domain/models/feed_post.dart";
import "../../../map/domain/models/eco_map_category.dart";
import "../../data/datasources/admin_remote_data_source.dart";
import "../../domain/models/admin_map_point.dart";
import "../../domain/models/admin_map_point_input.dart";
import "../../domain/models/admin_overview.dart";

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen>
    with SingleTickerProviderStateMixin {
  final _postSearchController = TextEditingController();
  final _userSearchController = TextEditingController();
  final _pointSearchController = TextEditingController();

  late final TabController _tabController;

  AdminOverview? _overview;
  List<FeedPost> _posts = const [];
  List<AppUser> _users = const [];
  List<AdminMapPoint> _points = const [];
  List<EcoMapCategory> _categories = const [];

  bool _isLoadingOverview = false;
  bool _isLoadingPosts = false;
  bool _isLoadingUsers = false;
  bool _isLoadingPoints = false;
  String? _postsError;
  String? _usersError;
  String? _pointsError;
  String? _busyKey;

  String _postKind = "all";
  String _postStatus = "all";
  String _userRole = "all";
  String _userStatus = "all";
  String _pointStatus = "all";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.microtask(_loadAll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _postSearchController.dispose();
    _userSearchController.dispose();
    _pointSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadOverview(),
      _loadPosts(),
      _loadUsers(),
      _loadCategoriesAndPoints(),
    ]);
  }

  Future<void> _loadOverview() async {
    setState(() => _isLoadingOverview = true);
    try {
      _overview = await ref.read(adminRemoteDataSourceProvider).fetchOverview();
    } catch (error) {
      _showSnack(
        humanizeNetworkError(
          error,
          fallback: "Не удалось загрузить обзор админки",
        ),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingOverview = false);
      }
    }
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoadingPosts = true;
      _postsError = null;
    });

    try {
      _posts = await ref
          .read(adminRemoteDataSourceProvider)
          .fetchPosts(
            search: _postSearchController.text,
            kind: _postKind,
            publicationStatus: _postStatus,
          );
    } catch (error) {
      _postsError = humanizeNetworkError(
        error,
        fallback: "Не удалось загрузить посты",
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingPosts = false);
      }
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoadingUsers = true;
      _usersError = null;
    });

    try {
      _users = await ref
          .read(adminRemoteDataSourceProvider)
          .fetchUsers(
            search: _userSearchController.text,
            role: _userRole,
            status: _userStatus,
          );
    } catch (error) {
      _usersError = humanizeNetworkError(
        error,
        fallback: "Не удалось загрузить пользователей",
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingUsers = false);
      }
    }
  }

  Future<void> _loadCategoriesAndPoints() async {
    setState(() {
      _isLoadingPoints = true;
      _pointsError = null;
    });

    try {
      final categories = await ref
          .read(adminRemoteDataSourceProvider)
          .fetchMapCategories();
      final points = await ref
          .read(adminRemoteDataSourceProvider)
          .fetchMapPoints(
            search: _pointSearchController.text,
            isActive: switch (_pointStatus) {
              "active" => true,
              "hidden" => false,
              _ => null,
            },
          );

      _categories = categories;
      _points = points;
    } catch (error) {
      _pointsError = humanizeNetworkError(
        error,
        fallback: "Не удалось загрузить точки карты",
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingPoints = false);
      }
    }
  }

  Future<void> _runAction(String key, Future<void> Function() action) async {
    setState(() => _busyKey = key);
    try {
      await action();
    } catch (error) {
      _showSnack(
        humanizeNetworkError(
          error,
          fallback: "Не удалось выполнить действие администратора",
        ),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _busyKey = null);
      }
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Отмена"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Подтвердить"),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _togglePostPublished(FeedPost post) async {
    await _runAction("post-${post.id}", () async {
      await ref
          .read(adminRemoteDataSourceProvider)
          .togglePostPublished(postId: post.id, isPublished: !post.isPublished);
      await Future.wait([_loadPosts(), _loadOverview()]);
    });
  }

  Future<void> _deletePost(FeedPost post) async {
    final confirmed = await _confirm(
      "Удалить пост",
      "Пост будет удалён без возможности восстановления.",
    );
    if (!confirmed) {
      return;
    }

    await _runAction("post-delete-${post.id}", () async {
      await ref.read(adminRemoteDataSourceProvider).deletePost(post.id);
      await Future.wait([_loadPosts(), _loadOverview()]);
    });
  }

  Future<void> _updateUserRole(AppUser user, String role) async {
    await _runAction("user-role-${user.id}", () async {
      await ref
          .read(authRepositoryProvider)
          .updateUserRole(userId: user.id, role: role);
      await _loadUsers();
    });
  }

  Future<void> _moderateUser(AppUser user, String action) async {
    await _runAction("user-$action-${user.id}", () async {
      if (action == "warn") {
        await ref.read(authRepositoryProvider).warnUser(user.id);
      } else if (action == "ban") {
        await ref.read(authRepositoryProvider).banUser(user.id);
      } else {
        await ref.read(authRepositoryProvider).unbanUser(user.id);
      }
      await Future.wait([_loadUsers(), _loadOverview()]);
    });
  }

  Future<void> _openPointEditor([AdminMapPoint? point]) async {
    if (_categories.isEmpty) {
      _showSnack("Сначала дождитесь загрузки категорий.", isError: true);
      return;
    }

    final input = await showModalBottomSheet<AdminMapPointInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _PointEditorSheet(categories: _categories, point: point);
      },
    );

    if (input == null) {
      return;
    }

    await _runAction(
      point == null ? "point-create" : "point-save-${point.id}",
      () async {
        if (point == null) {
          await ref.read(adminRemoteDataSourceProvider).createMapPoint(input);
        } else {
          await ref
              .read(adminRemoteDataSourceProvider)
              .updateMapPoint(pointId: point.id, input: input);
        }
        await Future.wait([_loadCategoriesAndPoints(), _loadOverview()]);
      },
    );
  }

  Future<void> _deletePoint(AdminMapPoint point) async {
    final confirmed = await _confirm(
      "Удалить точку",
      "Точка будет удалена с карты и из админки.",
    );
    if (!confirmed) {
      return;
    }

    await _runAction("point-delete-${point.id}", () async {
      await ref.read(adminRemoteDataSourceProvider).deleteMapPoint(point.id);
      await Future.wait([_loadCategoriesAndPoints(), _loadOverview()]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    if (!authState.isAuthenticated || user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Админка")),
        body: const AppEmptyState(
          title: "Нужен вход",
          message: "Войдите в аккаунт с правами администратора.",
        ),
      );
    }

    if (!user.canAccessAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text("Админка")),
        body: const AppEmptyState(
          title: "Недостаточно прав",
          message: "Раздел доступен только для админов и суперпользователей.",
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Админка"),
          actions: [
            IconButton(
              onPressed: () => _loadAll(),
              icon: const Icon(Icons.refresh),
              tooltip: "Обновить",
            ),
          ],
        ),
        body: Column(
          children: [
            _buildOverview(),
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: "Посты"),
                  Tab(text: "Пользователи"),
                  Tab(text: "Точки"),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _PostsTab(
                    posts: _posts,
                    isLoading: _isLoadingPosts,
                    error: _postsError,
                    searchController: _postSearchController,
                    selectedKind: _postKind,
                    selectedStatus: _postStatus,
                    busyKey: _busyKey,
                    onRefresh: _loadPosts,
                    onKindChanged: (value) => setState(() => _postKind = value),
                    onStatusChanged: (value) =>
                        setState(() => _postStatus = value),
                    onView: (post) => context.push(
                      AppRoutes.postDetail(
                        postId: post.id,
                        authorUsername: post.author.username,
                        postSlug: post.slug,
                      ),
                    ),
                    onEdit: (post) =>
                        context.push(AppRoutes.postEditor(post.id)),
                    onTogglePublished: _togglePostPublished,
                    onDelete: _deletePost,
                  ),
                  _UsersTab(
                    users: _users,
                    isLoading: _isLoadingUsers,
                    error: _usersError,
                    searchController: _userSearchController,
                    selectedRole: _userRole,
                    selectedStatus: _userStatus,
                    busyKey: _busyKey,
                    onRefresh: _loadUsers,
                    onRoleFilterChanged: (value) =>
                        setState(() => _userRole = value),
                    onStatusChanged: (value) =>
                        setState(() => _userStatus = value),
                    onRoleChanged: _updateUserRole,
                    onWarn: (user) => _moderateUser(user, "warn"),
                    onBan: (user) => _moderateUser(user, "ban"),
                    onUnban: (user) => _moderateUser(user, "unban"),
                  ),
                  _PointsTab(
                    points: _points,
                    isLoading: _isLoadingPoints,
                    error: _pointsError,
                    searchController: _pointSearchController,
                    selectedStatus: _pointStatus,
                    categories: _categories,
                    busyKey: _busyKey,
                    onRefresh: _loadCategoriesAndPoints,
                    onStatusChanged: (value) =>
                        setState(() => _pointStatus = value),
                    onCreate: () => _openPointEditor(),
                    onEdit: _openPointEditor,
                    onDelete: _deletePoint,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview() {
    if (_isLoadingOverview && _overview == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: LinearProgressIndicator(),
      );
    }

    if (_overview == null) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          _AdminStatCard(
            title: "Посты",
            value: "${_overview!.postsCount}",
            caption:
                "${_overview!.publishedPostsCount} опубликовано · ${_overview!.draftPostsCount} черновиков",
          ),
          const SizedBox(width: 12),
          _AdminStatCard(
            title: "Точки",
            value: "${_overview!.mapPointsCount}",
            caption:
                "${_overview!.activeMapPointsCount} активных · ${_overview!.hiddenMapPointsCount} скрытых",
          ),
          const SizedBox(width: 12),
          _AdminStatCard(
            title: "Пользователи",
            value: "${_overview!.usersCount}",
            caption:
                "${_overview!.adminsCount} админов · ${_overview!.bannedUsersCount} заблокировано",
          ),
        ],
      ),
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  const _AdminStatCard({
    required this.title,
    required this.value,
    required this.caption,
  });

  final String title;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                caption,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostsTab extends StatelessWidget {
  const _PostsTab({
    required this.posts,
    required this.isLoading,
    required this.error,
    required this.searchController,
    required this.selectedKind,
    required this.selectedStatus,
    required this.busyKey,
    required this.onRefresh,
    required this.onKindChanged,
    required this.onStatusChanged,
    required this.onView,
    required this.onEdit,
    required this.onTogglePublished,
    required this.onDelete,
  });

  final List<FeedPost> posts;
  final bool isLoading;
  final String? error;
  final TextEditingController searchController;
  final String selectedKind;
  final String selectedStatus;
  final String? busyKey;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onKindChanged;
  final ValueChanged<String> onStatusChanged;
  final void Function(FeedPost post) onView;
  final void Function(FeedPost post) onEdit;
  final Future<void> Function(FeedPost post) onTogglePublished;
  final Future<void> Function(FeedPost post) onDelete;

  @override
  Widget build(BuildContext context) {
    if (isLoading && posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && posts.isEmpty) {
      return AppErrorState(
        title: "Не удалось загрузить посты",
        message: error!,
        onRetry: () => onRefresh(),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    labelText: "Поиск",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedKind,
                  decoration: const InputDecoration(
                    labelText: "Тип",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: "all", child: Text("Все типы")),
                    DropdownMenuItem(value: "news", child: Text("Новости")),
                    DropdownMenuItem(value: "story", child: Text("Истории")),
                    DropdownMenuItem(value: "event", child: Text("События")),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onKindChanged(value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(
                    labelText: "Статус",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: "all",
                      child: Text("Все публикации"),
                    ),
                    DropdownMenuItem(
                      value: "published",
                      child: Text("Опубликованные"),
                    ),
                    DropdownMenuItem(value: "draft", child: Text("Черновики")),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onStatusChanged(value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => onRefresh(),
                    child: const Text("Применить"),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (posts.isEmpty)
          const AppEmptyState(
            title: "Посты не найдены",
            message: "Попробуйте изменить фильтры или создать новый материал.",
          )
        else
          for (final post in posts) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.title.isEmpty
                                    ? "Без заголовка"
                                    : post.title,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "@${post.author.name} · ${formatPostDate(post.publishedAt)}",
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Chip(
                          label: Text(
                            post.isPublished ? "Опубликован" : "Черновик",
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      post.previewText.isEmpty ? post.body : post.previewText,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          label: const Text("Открыть"),
                          onPressed: () => onView(post),
                        ),
                        ActionChip(
                          label: const Text("Редактировать"),
                          onPressed: () => onEdit(post),
                        ),
                        ActionChip(
                          label: Text(
                            post.isPublished ? "В черновик" : "Опубликовать",
                          ),
                          onPressed: busyKey == "post-${post.id}"
                              ? null
                              : () => onTogglePublished(post),
                        ),
                        ActionChip(
                          label: const Text("Удалить"),
                          onPressed: busyKey == "post-delete-${post.id}"
                              ? null
                              : () => onDelete(post),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab({
    required this.users,
    required this.isLoading,
    required this.error,
    required this.searchController,
    required this.selectedRole,
    required this.selectedStatus,
    required this.busyKey,
    required this.onRefresh,
    required this.onRoleFilterChanged,
    required this.onStatusChanged,
    required this.onRoleChanged,
    required this.onWarn,
    required this.onBan,
    required this.onUnban,
  });

  final List<AppUser> users;
  final bool isLoading;
  final String? error;
  final TextEditingController searchController;
  final String selectedRole;
  final String selectedStatus;
  final String? busyKey;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onRoleFilterChanged;
  final ValueChanged<String> onStatusChanged;
  final Future<void> Function(AppUser user, String role) onRoleChanged;
  final Future<void> Function(AppUser user) onWarn;
  final Future<void> Function(AppUser user) onBan;
  final Future<void> Function(AppUser user) onUnban;

  @override
  Widget build(BuildContext context) {
    if (isLoading && users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && users.isEmpty) {
      return AppErrorState(
        title: "Не удалось загрузить пользователей",
        message: error!,
        onRetry: () => onRefresh(),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    labelText: "Поиск",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(
                    labelText: "Роль",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: "all", child: Text("Все роли")),
                    DropdownMenuItem(value: "admin", child: Text("Админы")),
                    DropdownMenuItem(
                      value: "support",
                      child: Text("Техподдержка"),
                    ),
                    DropdownMenuItem(
                      value: "moderator",
                      child: Text("Модераторы"),
                    ),
                    DropdownMenuItem(
                      value: "user",
                      child: Text("Пользователи"),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onRoleFilterChanged(value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(
                    labelText: "Статус",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: "all", child: Text("Все статусы")),
                    DropdownMenuItem(value: "active", child: Text("Активные")),
                    DropdownMenuItem(
                      value: "banned",
                      child: Text("Заблокированные"),
                    ),
                    DropdownMenuItem(
                      value: "admin",
                      child: Text("С доступом к админке"),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onStatusChanged(value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => onRefresh(),
                    child: const Text("Применить"),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (users.isEmpty)
          const AppEmptyState(
            title: "Пользователи не найдены",
            message: "Проверьте фильтры или строку поиска.",
          )
        else
          for (final user in users) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text("@${user.username} · ${user.email}"),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        RoleChip(role: user.role),
                        Chip(
                          label: Text(
                            user.isBanned ? "Заблокирован" : "Активен",
                          ),
                        ),
                        if (user.canAccessAdmin)
                          const Chip(label: Text("Админ-доступ")),
                        if (user.canAccessSupport)
                          const Chip(label: Text("Доступ к поддержке")),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: user.role,
                      decoration: const InputDecoration(
                        labelText: "Роль пользователя",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: "admin", child: Text("Админ")),
                        DropdownMenuItem(
                          value: "support",
                          child: Text("Техподдержка"),
                        ),
                        DropdownMenuItem(
                          value: "moderator",
                          child: Text("Модератор"),
                        ),
                        DropdownMenuItem(
                          value: "user",
                          child: Text("Пользователь"),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          onRoleChanged(user, value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          label: const Text("Предупредить"),
                          onPressed: busyKey == "user-warn-${user.id}"
                              ? null
                              : () => onWarn(user),
                        ),
                        ActionChip(
                          label: Text(
                            user.isBanned ? "Разблокировать" : "Заблокировать",
                          ),
                          onPressed:
                              busyKey == "user-ban-${user.id}" ||
                                  busyKey == "user-unban-${user.id}"
                              ? null
                              : () =>
                                    user.isBanned ? onUnban(user) : onBan(user),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _PointsTab extends StatelessWidget {
  const _PointsTab({
    required this.points,
    required this.isLoading,
    required this.error,
    required this.searchController,
    required this.selectedStatus,
    required this.categories,
    required this.busyKey,
    required this.onRefresh,
    required this.onStatusChanged,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
  });

  final List<AdminMapPoint> points;
  final bool isLoading;
  final String? error;
  final TextEditingController searchController;
  final String selectedStatus;
  final List<EcoMapCategory> categories;
  final String? busyKey;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onCreate;
  final Future<void> Function(AdminMapPoint point) onEdit;
  final Future<void> Function(AdminMapPoint point) onDelete;

  @override
  Widget build(BuildContext context) {
    if (isLoading && points.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && points.isEmpty) {
      return AppErrorState(
        title: "Не удалось загрузить точки",
        message: error!,
        onRetry: () => onRefresh(),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    labelText: "Поиск",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(
                    labelText: "Статус",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: "all", child: Text("Все точки")),
                    DropdownMenuItem(value: "active", child: Text("Активные")),
                    DropdownMenuItem(value: "hidden", child: Text("Скрытые")),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onStatusChanged(value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => onRefresh(),
                        child: const Text("Применить"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: categories.isEmpty ? null : onCreate,
                        child: const Text("Новая точка"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (points.isEmpty)
          const AppEmptyState(
            title: "Точки не найдены",
            message: "Измените фильтры или создайте новую точку.",
          )
        else
          for (final point in points) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            point.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Chip(
                          label: Text(point.isActive ? "Активна" : "Скрыта"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(point.address.isEmpty ? point.slug : point.address),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final category in point.categories)
                          Chip(label: Text(category.title)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          label: const Text("Редактировать"),
                          onPressed: () => onEdit(point),
                        ),
                        ActionChip(
                          label: const Text("Удалить"),
                          onPressed: busyKey == "point-delete-${point.id}"
                              ? null
                              : () => onDelete(point),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _PointEditorSheet extends StatefulWidget {
  const _PointEditorSheet({required this.categories, this.point});

  final List<EcoMapCategory> categories;
  final AdminMapPoint? point;

  @override
  State<_PointEditorSheet> createState() => _PointEditorSheetState();
}

class _PointEditorSheetState extends State<_PointEditorSheet> {
  late final TextEditingController _slugController;
  late final TextEditingController _titleController;
  late final TextEditingController _shortDescriptionController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _addressController;
  late final TextEditingController _workingHoursController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _sortOrderController;
  late final TextEditingController _imageUrlsController;
  late bool _isActive;
  late Set<int> _selectedCategoryIds;

  @override
  void initState() {
    super.initState();
    final point = widget.point;
    _slugController = TextEditingController(text: point?.slug ?? "");
    _titleController = TextEditingController(text: point?.title ?? "");
    _shortDescriptionController = TextEditingController(
      text: point?.shortDescription ?? "",
    );
    _descriptionController = TextEditingController(
      text: point?.description ?? "",
    );
    _addressController = TextEditingController(text: point?.address ?? "");
    _workingHoursController = TextEditingController(
      text: point?.workingHours ?? "",
    );
    _latitudeController = TextEditingController(
      text: point != null ? "${point.latitude}" : "",
    );
    _longitudeController = TextEditingController(
      text: point != null ? "${point.longitude}" : "",
    );
    _sortOrderController = TextEditingController(
      text: point != null ? "${point.sortOrder}" : "0",
    );
    _imageUrlsController = TextEditingController(
      text: point?.images.map((image) => image.imageUrl).join("\n") ?? "",
    );
    _isActive = point?.isActive ?? true;
    _selectedCategoryIds =
        point?.categories.map((item) => item.id).toSet() ?? <int>{};
  }

  @override
  void dispose() {
    _slugController.dispose();
    _titleController.dispose();
    _shortDescriptionController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _workingHoursController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _sortOrderController.dispose();
    _imageUrlsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.point == null ? "Новая точка" : "Редактор точки",
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            for (final field in [
              (_titleController, "Название", 1),
              (_slugController, "Slug", 1),
              (_shortDescriptionController, "Краткое описание", 2),
              (_descriptionController, "Описание", 4),
              (_addressController, "Адрес", 2),
              (_workingHoursController, "Часы работы", 1),
              (_latitudeController, "Широта", 1),
              (_longitudeController, "Долгота", 1),
              (_sortOrderController, "Порядок сортировки", 1),
              (
                _imageUrlsController,
                "Изображения (по одной ссылке на строку)",
                4,
              ),
            ]) ...[
              TextField(
                controller: field.$1,
                minLines: field.$3,
                maxLines: field.$3 == 1 ? 1 : field.$3 + 2,
                decoration: InputDecoration(
                  labelText: field.$2,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
              title: const Text("Показывать на карте"),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in widget.categories)
                  FilterChip(
                    label: Text(category.title),
                    selected: _selectedCategoryIds.contains(category.id),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedCategoryIds.add(category.id);
                        } else {
                          _selectedCategoryIds.remove(category.id);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final latitude = double.tryParse(
                    _latitudeController.text.trim(),
                  );
                  final longitude = double.tryParse(
                    _longitudeController.text.trim(),
                  );
                  final sortOrder =
                      int.tryParse(_sortOrderController.text.trim()) ?? 0;

                  if (_titleController.text.trim().isEmpty ||
                      _slugController.text.trim().isEmpty ||
                      latitude == null ||
                      longitude == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Заполните название, slug и корректные координаты.",
                        ),
                      ),
                    );
                    return;
                  }

                  Navigator.of(context).pop(
                    AdminMapPointInput(
                      slug: _slugController.text.trim(),
                      title: _titleController.text.trim(),
                      shortDescription: _shortDescriptionController.text.trim(),
                      description: _descriptionController.text.trim(),
                      address: _addressController.text.trim(),
                      workingHours: _workingHoursController.text.trim(),
                      latitude: latitude,
                      longitude: longitude,
                      isActive: _isActive,
                      sortOrder: sortOrder,
                      categoryIds: _selectedCategoryIds.toList(),
                      imageUrls: _imageUrlsController.text
                          .split("\n")
                          .map((value) => value.trim())
                          .where((value) => value.isNotEmpty)
                          .toList(),
                    ),
                  );
                },
                child: Text(
                  widget.point == null ? "Создать точку" : "Сохранить",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
