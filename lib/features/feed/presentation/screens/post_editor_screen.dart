import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../../core/network/error_message.dart";
import "../../../../core/network/image_upload_service.dart";
import "../../../../core/utils/date_formatter.dart";
import "../../../../shared/widgets/app_error_state.dart";
import "../../../auth/presentation/controllers/auth_controller.dart";
import "../../../profile/presentation/controllers/profile_controller.dart";
import "../../data/repositories/posts_repository_impl.dart";
import "../../domain/models/post_details.dart";
import "../../domain/models/post_write_input.dart";
import "../controllers/feed_controller.dart";

class PostEditorScreen extends ConsumerStatefulWidget {
  const PostEditorScreen({super.key, this.postId});

  final int? postId;

  bool get isEditing => postId != null;

  @override
  ConsumerState<PostEditorScreen> createState() => _PostEditorScreenState();
}

class _PostEditorScreenState extends ConsumerState<PostEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _imageUrlsController = TextEditingController();
  final _eventLocationController = TextEditingController();
  bool _isPublished = true;
  bool _isSaving = false;
  bool _isUploadingImages = false;
  bool _didHydrate = false;
  String _selectedKind = "news";
  DateTime? _eventStartsAt;
  DateTime? _eventEndsAt;
  String? _errorMessage;

  bool get _isEvent => _selectedKind == "event";

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _imageUrlsController.dispose();
    _eventLocationController.dispose();
    super.dispose();
  }

  void _hydrate(PostDetails post) {
    if (_didHydrate) {
      return;
    }

    _titleController.text = post.title;
    _bodyController.text = post.body;
    _imageUrlsController.text = post.images
        .map((image) => image.imageUrl)
        .join("\n");
    _eventLocationController.text = post.eventLocation;
    _selectedKind = post.kind;
    _eventStartsAt = post.eventStartsAt;
    _eventEndsAt = post.eventEndsAt;
    _isPublished = post.isPublished;
    _didHydrate = true;
  }

  Future<void> _pickAndUploadImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) {
        return;
      }

      final paths = result.files
          .map((file) => file.path)
          .whereType<String>()
          .toList();
      if (paths.isEmpty) {
        setState(() {
          _errorMessage = "Не удалось получить выбранные изображения";
        });
        return;
      }

      setState(() {
        _isUploadingImages = true;
        _errorMessage = null;
      });

      final uploader = ref.read(imageUploadServiceProvider);
      final uploadedUrls = <String>[];
      for (final path in paths) {
        uploadedUrls.add(await uploader.uploadImage(path));
      }

      final currentLines = _imageUrlsController.text
          .split("\n")
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
      _imageUrlsController.text = [...currentLines, ...uploadedUrls].join("\n");
    } catch (error) {
      setState(() {
        _errorMessage = humanizeNetworkError(
          error,
          fallback: "Не удалось загрузить изображения",
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImages = false;
        });
      }
    }
  }

  Future<void> _pickEventStart() async {
    final picked = await _pickDateTime(
      initial: _eventStartsAt ?? DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _eventStartsAt = picked;
      _eventEndsAt ??= picked.add(const Duration(hours: 2));
    });
  }

  Future<void> _pickEventEnd() async {
    final start = _eventStartsAt ?? DateTime.now().add(const Duration(days: 1));
    final picked = await _pickDateTime(
      initial: _eventEndsAt ?? start.add(const Duration(hours: 2)),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _eventEndsAt = picked;
    });
  }

  Future<DateTime?> _pickDateTime({required DateTime initial}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (date == null || !mounted) {
      return null;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) {
      return null;
    }

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final currentUser = ref.read(authControllerProvider).user;
    if (currentUser == null) {
      return;
    }

    if (_isEvent &&
        (_eventStartsAt == null ||
            _eventLocationController.text.trim().isEmpty)) {
      setState(() {
        _errorMessage = "Для события укажите дату начала и место проведения";
      });
      return;
    }

    if (_isEvent &&
        _eventEndsAt != null &&
        _eventStartsAt != null &&
        _eventEndsAt!.isBefore(_eventStartsAt!)) {
      setState(() {
        _errorMessage = "Дата окончания не может быть раньше даты начала";
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final input = PostWriteInput(
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
      kind: _selectedKind,
      isPublished: _isPublished,
      imageUrls: _imageUrlsController.text
          .split("\n")
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(),
      eventStartsAt: _isEvent ? _eventStartsAt : null,
      eventEndsAt: _isEvent ? _eventEndsAt : null,
      eventLocation: _isEvent ? _eventLocationController.text.trim() : "",
    );

    try {
      final repository = ref.read(postsRepositoryProvider);
      final saved = widget.isEditing
          ? await repository.updatePost(postId: widget.postId!, input: input)
          : await repository.createPost(input);

      ref.read(feedControllerProvider.notifier).upsertPost(saved);
      ref.invalidate(postsCollectionControllerProvider(defaultEventsQuery));
      ref.invalidate(postsCollectionControllerProvider(favoritePostsQuery));
      ref.invalidate(userPostsProvider(saved.author.id));
      ref.invalidate(publicProfileProvider(saved.author.id));
      if (saved.author.id != currentUser.id) {
        ref.invalidate(userPostsProvider(currentUser.id));
      }
      if (widget.postId != null) {
        ref
            .read(postDetailsControllerProvider(widget.postId!).notifier)
            .replacePost(saved);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEditing ? "Пост обновлен" : "Пост сохранен"),
        ),
      );

      if (widget.isEditing) {
        context.pop();
      } else {
        context.go("/posts/${saved.id}");
      }
    } catch (error) {
      setState(() {
        _errorMessage = humanizeNetworkError(
          error,
          fallback: widget.isEditing
              ? "Не удалось обновить пост"
              : "Не удалось создать пост",
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    if (!authState.isAuthenticated || authState.user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Редактор поста")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Чтобы публиковать посты, нужно войти в аккаунт.",
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go("/login"),
                  child: const Text("Перейти ко входу"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (widget.isEditing) {
      final postAsync = ref.watch(
        postDetailsControllerProvider(widget.postId!),
      );
      return Scaffold(
        appBar: AppBar(title: const Text("Редактирование поста")),
        body: postAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) {
            return AppErrorState(
              title: "Не удалось открыть пост",
              message: "Попробуйте снова чуть позже.",
              onRetry: () {
                ref.invalidate(postDetailsControllerProvider(widget.postId!));
              },
            );
          },
          data: (post) {
            _hydrate(post);
            return _PostEditorForm(
              formKey: _formKey,
              titleController: _titleController,
              bodyController: _bodyController,
              imageUrlsController: _imageUrlsController,
              eventLocationController: _eventLocationController,
              isPublished: _isPublished,
              selectedKind: _selectedKind,
              errorMessage: _errorMessage,
              isSaving: _isSaving,
              isUploadingImages: _isUploadingImages,
              eventStartsAt: _eventStartsAt,
              eventEndsAt: _eventEndsAt,
              onUploadImages: _pickAndUploadImages,
              onKindChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedKind = value;
                  if (value != "event") {
                    _eventStartsAt = null;
                    _eventEndsAt = null;
                    _eventLocationController.clear();
                  }
                });
              },
              onPickEventStart: _pickEventStart,
              onPickEventEnd: _pickEventEnd,
              onPublishedChanged: (value) {
                setState(() {
                  _isPublished = value;
                });
              },
              onSave: _save,
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Новый пост")),
      body: _PostEditorForm(
        formKey: _formKey,
        titleController: _titleController,
        bodyController: _bodyController,
        imageUrlsController: _imageUrlsController,
        eventLocationController: _eventLocationController,
        isPublished: _isPublished,
        selectedKind: _selectedKind,
        errorMessage: _errorMessage,
        isSaving: _isSaving,
        isUploadingImages: _isUploadingImages,
        eventStartsAt: _eventStartsAt,
        eventEndsAt: _eventEndsAt,
        onUploadImages: _pickAndUploadImages,
        onKindChanged: (value) {
          if (value == null) {
            return;
          }
          setState(() {
            _selectedKind = value;
            if (value != "event") {
              _eventStartsAt = null;
              _eventEndsAt = null;
              _eventLocationController.clear();
            }
          });
        },
        onPickEventStart: _pickEventStart,
        onPickEventEnd: _pickEventEnd,
        onPublishedChanged: (value) {
          setState(() {
            _isPublished = value;
          });
        },
        onSave: _save,
      ),
    );
  }
}

class _PostEditorForm extends StatelessWidget {
  const _PostEditorForm({
    required this.formKey,
    required this.titleController,
    required this.bodyController,
    required this.imageUrlsController,
    required this.eventLocationController,
    required this.isPublished,
    required this.selectedKind,
    required this.errorMessage,
    required this.isSaving,
    required this.isUploadingImages,
    required this.eventStartsAt,
    required this.eventEndsAt,
    required this.onUploadImages,
    required this.onKindChanged,
    required this.onPickEventStart,
    required this.onPickEventEnd,
    required this.onPublishedChanged,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final TextEditingController bodyController;
  final TextEditingController imageUrlsController;
  final TextEditingController eventLocationController;
  final bool isPublished;
  final String selectedKind;
  final String? errorMessage;
  final bool isSaving;
  final bool isUploadingImages;
  final DateTime? eventStartsAt;
  final DateTime? eventEndsAt;
  final VoidCallback onUploadImages;
  final ValueChanged<String?> onKindChanged;
  final VoidCallback onPickEventStart;
  final VoidCallback onPickEventEnd;
  final ValueChanged<bool> onPublishedChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEvent = selectedKind == "event";

    return SafeArea(
      child: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: "Заголовок",
                border: OutlineInputBorder(),
              ),
              maxLength: 160,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: selectedKind,
              decoration: const InputDecoration(
                labelText: "Тип публикации",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: "news", child: Text("Новость")),
                DropdownMenuItem(value: "story", child: Text("История")),
                DropdownMenuItem(value: "event", child: Text("Событие")),
              ],
              onChanged: onKindChanged,
            ),
            if (isEvent) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: eventLocationController,
                decoration: const InputDecoration(
                  labelText: "Место проведения",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onPickEventStart,
                      icon: const Icon(Icons.event),
                      label: Text(
                        eventStartsAt == null
                            ? "Начало"
                            : formatEventRange(eventStartsAt, null),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onPickEventEnd,
                      icon: const Icon(Icons.schedule),
                      label: Text(
                        eventEndsAt == null
                            ? "Окончание"
                            : formatEventRange(eventEndsAt, null),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: bodyController,
              decoration: const InputDecoration(
                labelText: "Текст",
                border: OutlineInputBorder(),
              ),
              minLines: 8,
              maxLines: 12,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return "Введите текст публикации";
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Изображения",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: isUploadingImages ? null : onUploadImages,
                  icon: isUploadingImages
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: const Text("Загрузить"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: imageUrlsController,
              decoration: const InputDecoration(
                labelText: "Ссылки на изображения",
                helperText:
                    "Можно загрузить файл или вставить URL. По одной ссылке на строку.",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.multiline,
              minLines: 3,
              maxLines: 6,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: isPublished,
              onChanged: onPublishedChanged,
              title: Text(
                isPublished ? "Опубликовано" : "Черновик",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                isPublished
                    ? "Пост сразу появится в ленте."
                    : "Черновик сохранится без публикации.",
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                errorMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: isSaving ? null : onSave,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Сохранить пост"),
            ),
          ],
        ),
      ),
    );
  }
}
