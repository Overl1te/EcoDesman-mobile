import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:url_launcher/url_launcher.dart";

import "../../../../core/network/error_message.dart";
import "../../domain/models/social_auth_provider.dart";
import "../controllers/auth_controller.dart";

enum _AuthMode { signIn, signUp }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _oauthLinksChannel = EventChannel("eco_nizhny/oauth_links");

  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerPasswordConfirmationController = TextEditingController();

  _AuthMode _mode = _AuthMode.signIn;
  bool _obscureLoginPassword = true;
  bool _obscureRegisterPassword = true;
  bool _obscureRegisterPasswordConfirmation = true;
  bool _acceptTerms = false;
  bool _acceptPrivacyPolicy = false;
  bool _acceptPersonalData = false;
  bool _acceptPublicPersonalDataDistribution = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _registerPasswordController.dispose();
    _registerPasswordConfirmationController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!_loginFormKey.currentState!.validate()) {
      return;
    }

    await ref
        .read(authControllerProvider.notifier)
        .login(
          identifier: _identifierController.text.trim(),
          password: _passwordController.text,
        );
  }

  Future<void> _submitRegister() async {
    if (!_registerFormKey.currentState!.validate()) {
      return;
    }

    if (!_acceptTerms || !_acceptPrivacyPolicy || !_acceptPersonalData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Для регистрации нужно принять соглашение, политику и согласие на обработку данных.",
          ),
        ),
      );
      return;
    }

    await ref
        .read(authControllerProvider.notifier)
        .register(
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          password: _registerPasswordController.text,
          passwordConfirmation: _registerPasswordConfirmationController.text,
          acceptTerms: _acceptTerms,
          acceptPrivacyPolicy: _acceptPrivacyPolicy,
          acceptPersonalData: _acceptPersonalData,
          acceptPublicPersonalDataDistribution:
              _acceptPublicPersonalDataDistribution,
          displayName: _displayNameController.text.trim(),
          phone: _phoneController.text.trim(),
        );
  }

  Future<void> _startSocialAuth(String provider) async {
    if (_mode == _AuthMode.signUp &&
        (!_acceptTerms || !_acceptPrivacyPolicy || !_acceptPersonalData)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Для регистрации через соцсеть примите соглашение, политику и согласие на обработку данных.",
          ),
        ),
      );
      return;
    }

    final redirectUri = "ecodesman://auth/social/$provider/callback";
    final state = [
      _acceptTerms,
      _acceptPrivacyPolicy,
      _acceptPersonalData,
      _acceptPublicPersonalDataDistribution,
    ].map((value) => value ? "1" : "0").join();

    try {
      final providers = await ref
          .read(authControllerProvider.notifier)
          .fetchSocialProviders(redirectUri: redirectUri, state: state);
      SocialAuthProvider? option;
      for (final item in providers) {
        if (item.id == provider) {
          option = item;
          break;
        }
      }

      if (option == null ||
          !option.enabled ||
          option.authorizationUrl.isEmpty) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Этот способ входа пока не настроен.")),
        );
        return;
      }

      final result = await _launchAndWaitForOAuthCallback(
        option.authorizationUrl,
      );
      final resultUri = Uri.parse(result);
      final code = resultUri.queryParameters["code"];
      final providerError = resultUri.queryParameters["error"];

      if (providerError != null || code == null || code.isEmpty) {
        throw StateError("Провайдер не вернул код авторизации.");
      }

      await ref
          .read(authControllerProvider.notifier)
          .loginWithSocial(
            provider: provider,
            code: code,
            redirectUri: redirectUri,
            acceptTerms: _acceptTerms,
            acceptPrivacyPolicy: _acceptPrivacyPolicy,
            acceptPersonalData: _acceptPersonalData,
            acceptPublicPersonalDataDistribution:
                _acceptPublicPersonalDataDistribution,
          );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            humanizeNetworkError(
              error,
              fallback: "Не удалось начать вход через соцсеть",
            ),
          ),
        ),
      );
    }
  }

  Future<String> _launchAndWaitForOAuthCallback(String authorizationUrl) async {
    final completer = Completer<String>();
    late final StreamSubscription<String> subscription;

    subscription = _oauthLinksChannel
        .receiveBroadcastStream()
        .cast<String>()
        .listen((link) {
          if (!completer.isCompleted && link.startsWith("ecodesman://")) {
            completer.complete(link);
          }
        });

    try {
      final uri = Uri.parse(authorizationUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw StateError("Не удалось открыть браузер для авторизации.");
      }

      return await completer.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () {
          throw TimeoutException("Время авторизации истекло.");
        },
      );
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> _showPasswordResetSheet() async {
    final formKey = GlobalKey<FormState>();
    final identifierController = TextEditingController(
      text: _identifierController.text.trim(),
    );
    final messenger = ScaffoldMessenger.of(context);
    var isSubmitting = false;
    String? errorText;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final sheetElement = sheetContext as Element;
        final navigator = Navigator.of(sheetContext);

        Future<void> submit() async {
          if (!formKey.currentState!.validate() || isSubmitting) {
            return;
          }

          isSubmitting = true;
          errorText = null;
          sheetElement.markNeedsBuild();

          try {
            final detail = await ref
                .read(authControllerProvider.notifier)
                .requestPasswordReset(
                  identifier: identifierController.text.trim(),
                );
            if (!mounted) {
              return;
            }
            if (navigator.mounted) {
              navigator.pop();
            }
            messenger.showSnackBar(SnackBar(content: Text(detail)));
          } catch (error) {
            errorText = humanizeNetworkError(
              error,
              fallback: "Не удалось отправить запрос на восстановление",
            );
            if (sheetElement.mounted) {
              sheetElement.markNeedsBuild();
            }
          } finally {
            isSubmitting = false;
            if (sheetElement.mounted) {
              sheetElement.markNeedsBuild();
            }
          }
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Восстановление пароля",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Введите почту, телефон или логин. Канал отправки кода подключим следующим шагом, а сам recovery-flow уже зафиксирован.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: identifierController,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => submit(),
                  decoration: const InputDecoration(
                    labelText: "Почта, телефон или логин",
                    hintText: "Например, anna@econizhny.local",
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Введите почту, телефон или логин";
                    }
                    return null;
                  },
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 14),
                  _AuthErrorBanner(message: errorText!),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: isSubmitting ? null : submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Продолжить"),
                ),
              ],
            ),
          ),
        );
      },
    );

    identifierController.dispose();
  }

  void _setMode(_AuthMode nextMode) {
    if (_mode == nextMode) {
      return;
    }

    ref.read(authControllerProvider.notifier).clearError();
    setState(() {
      _mode = nextMode;
    });
  }

  void _applyDemoCredentials() {
    _setMode(_AuthMode.signIn);
    _identifierController.text = "anna@econizhny.local";
    _passwordController.text = "demo12345";
    ref.read(authControllerProvider.notifier).clearError();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (!mounted) {
        return;
      }

      if (next.status == AuthStatus.authenticated ||
          next.status == AuthStatus.guest) {
        context.go("/app");
      }
    });

    final authState = ref.watch(authControllerProvider);
    final isSignIn = _mode == _AuthMode.signIn;
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.colorScheme.surface, theme.scaffoldBackgroundColor],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _AuthHeader(),
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SegmentedButton<_AuthMode>(
                              multiSelectionEnabled: false,
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment<_AuthMode>(
                                  value: _AuthMode.signIn,
                                  label: Text("Вход"),
                                  icon: Icon(Icons.login_rounded),
                                ),
                                ButtonSegment<_AuthMode>(
                                  value: _AuthMode.signUp,
                                  label: Text("Регистрация"),
                                  icon: Icon(Icons.person_add_alt_1_rounded),
                                ),
                              ],
                              selected: {_mode},
                              onSelectionChanged: authState.isBusy
                                  ? null
                                  : (selection) {
                                      if (selection.isNotEmpty) {
                                        _setMode(selection.first);
                                      }
                                    },
                            ),
                            const SizedBox(height: 20),
                            Text(
                              isSignIn ? "Вход в аккаунт" : "Создание аккаунта",
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isSignIn
                                  ? "Войдите по почте, телефону или логину."
                                  : "Подтверждение почты и номера добавим следующим шагом, а базовый auth-flow уже готов.",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _SocialAuthButtons(
                              isBusy: authState.isBusy,
                              onProviderSelected: _startSocialAuth,
                            ),
                            const SizedBox(height: 20),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: isSignIn
                                  ? _LoginForm(
                                      key: const ValueKey("login-form"),
                                      formKey: _loginFormKey,
                                      identifierController:
                                          _identifierController,
                                      passwordController: _passwordController,
                                      obscurePassword: _obscureLoginPassword,
                                      onTogglePasswordVisibility: () {
                                        setState(() {
                                          _obscureLoginPassword =
                                              !_obscureLoginPassword;
                                        });
                                      },
                                      onForgotPassword: _showPasswordResetSheet,
                                      onClearError: () {
                                        ref
                                            .read(
                                              authControllerProvider.notifier,
                                            )
                                            .clearError();
                                      },
                                      onSubmit: _submitLogin,
                                    )
                                  : _RegisterForm(
                                      key: const ValueKey("register-form"),
                                      formKey: _registerFormKey,
                                      displayNameController:
                                          _displayNameController,
                                      usernameController: _usernameController,
                                      emailController: _emailController,
                                      phoneController: _phoneController,
                                      passwordController:
                                          _registerPasswordController,
                                      passwordConfirmationController:
                                          _registerPasswordConfirmationController,
                                      obscurePassword: _obscureRegisterPassword,
                                      obscurePasswordConfirmation:
                                          _obscureRegisterPasswordConfirmation,
                                      acceptTerms: _acceptTerms,
                                      acceptPrivacyPolicy: _acceptPrivacyPolicy,
                                      acceptPersonalData: _acceptPersonalData,
                                      acceptPublicPersonalDataDistribution:
                                          _acceptPublicPersonalDataDistribution,
                                      onTogglePasswordVisibility: () {
                                        setState(() {
                                          _obscureRegisterPassword =
                                              !_obscureRegisterPassword;
                                        });
                                      },
                                      onTogglePasswordConfirmationVisibility: () {
                                        setState(() {
                                          _obscureRegisterPasswordConfirmation =
                                              !_obscureRegisterPasswordConfirmation;
                                        });
                                      },
                                      onClearError: () {
                                        ref
                                            .read(
                                              authControllerProvider.notifier,
                                            )
                                            .clearError();
                                      },
                                      onAcceptTermsChanged: (value) {
                                        setState(() {
                                          _acceptTerms = value;
                                        });
                                      },
                                      onAcceptPrivacyPolicyChanged: (value) {
                                        setState(() {
                                          _acceptPrivacyPolicy = value;
                                        });
                                      },
                                      onAcceptPersonalDataChanged: (value) {
                                        setState(() {
                                          _acceptPersonalData = value;
                                        });
                                      },
                                      onAcceptPublicPersonalDataChanged: (value) {
                                        setState(() {
                                          _acceptPublicPersonalDataDistribution =
                                              value;
                                        });
                                      },
                                    ),
                            ),
                            if (authState.errorMessage != null) ...[
                              const SizedBox(height: 16),
                              _AuthErrorBanner(
                                message: authState.errorMessage!,
                              ),
                            ],
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: authState.isBusy
                                  ? null
                                  : isSignIn
                                  ? _submitLogin
                                  : _submitRegister,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              icon: authState.isBusy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      isSignIn
                                          ? Icons.arrow_forward_rounded
                                          : Icons.person_add_alt_1_rounded,
                                    ),
                              label: Text(
                                isSignIn ? "Войти" : "Создать аккаунт",
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (isSignIn)
                              TextButton.icon(
                                onPressed: authState.isBusy
                                    ? null
                                    : _applyDemoCredentials,
                                icon: const Icon(Icons.flash_on_outlined),
                                label: const Text("Подставить демо-аккаунт"),
                              ),
                            if (isSignIn) const SizedBox(height: 4),
                            OutlinedButton.icon(
                              onPressed: authState.isBusy
                                  ? null
                                  : () {
                                      ref
                                          .read(authControllerProvider.notifier)
                                          .continueAsGuest();
                                    },
                              icon: const Icon(Icons.visibility_outlined),
                              label: const Text("Продолжить как гость"),
                            ),
                            const SizedBox(height: 16),
                            _AuthFooter(
                              isSignIn: isSignIn,
                              onToggleMode: authState.isBusy
                                  ? null
                                  : () => _setMode(
                                      isSignIn
                                          ? _AuthMode.signUp
                                          : _AuthMode.signIn,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset("assets/app_icon.png", fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "ЭкоВыхухоль",
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Лента, карта и профиль в одном приложении.",
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AuthErrorBanner extends StatelessWidget {
  const _AuthErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthFooter extends StatelessWidget {
  const _AuthFooter({required this.isSignIn, required this.onToggleMode});

  final bool isSignIn;
  final VoidCallback? onToggleMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isSignIn
                  ? "Нет аккаунта? Зарегистрируйтесь и сразу заходите в приложение."
                  : "Уже есть аккаунт? Вернитесь ко входу.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onToggleMode,
            child: Text(isSignIn ? "Регистрация" : "Вход"),
          ),
        ],
      ),
    );
  }
}

class _SocialAuthButtons extends StatelessWidget {
  const _SocialAuthButtons({
    required this.isBusy,
    required this.onProviderSelected,
  });

  final bool isBusy;
  final ValueChanged<String> onProviderSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Theme.of(context).dividerColor)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                "Войти через",
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            Expanded(child: Divider(color: Theme.of(context).dividerColor)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SocialAuthButton(
                label: "VK",
                fullLabel: "ВКонтакте",
                color: const Color(0xFF2787F5),
                isBusy: isBusy,
                onPressed: () => onProviderSelected("vk"),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SocialAuthButton(
                label: "G",
                fullLabel: "Google",
                color: const Color(0xFFD83B2D),
                isBusy: isBusy,
                onPressed: () => onProviderSelected("google"),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SocialAuthButton(
                label: "Я",
                fullLabel: "Яндекс",
                color: const Color(0xFFF2C94C),
                foregroundColor: const Color(0xFF20251F),
                isBusy: isBusy,
                onPressed: () => onProviderSelected("yandex"),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SocialAuthButton extends StatelessWidget {
  const _SocialAuthButton({
    required this.label,
    required this.fullLabel,
    required this.color,
    required this.isBusy,
    required this.onPressed,
    this.foregroundColor = Colors.white,
  });

  final String label;
  final String fullLabel;
  final Color color;
  final Color foregroundColor;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: isBusy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: color,
            child: Text(
              label,
              style: TextStyle(
                color: foregroundColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(child: Text(fullLabel)),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required super.key,
    required this.formKey,
    required this.identifierController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onTogglePasswordVisibility,
    required this.onForgotPassword,
    required this.onClearError,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController identifierController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onForgotPassword;
  final VoidCallback onClearError;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: identifierController,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
                AutofillHints.telephoneNumber,
              ],
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onChanged: (_) => onClearError(),
              decoration: const InputDecoration(
                labelText: "Почта, телефон или логин",
                hintText: "Например, anna@econizhny.local",
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return "Введите почту, телефон или логин";
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: passwordController,
              autofillHints: const [AutofillHints.password],
              obscureText: obscurePassword,
              textInputAction: TextInputAction.done,
              onChanged: (_) => onClearError(),
              onFieldSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                labelText: "Пароль",
                hintText: "Введите пароль",
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: onTogglePasswordVisibility,
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Введите пароль";
                }
                return null;
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onForgotPassword,
                child: const Text("Забыли пароль?"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegisterForm extends StatelessWidget {
  const _RegisterForm({
    required super.key,
    required this.formKey,
    required this.displayNameController,
    required this.usernameController,
    required this.emailController,
    required this.phoneController,
    required this.passwordController,
    required this.passwordConfirmationController,
    required this.obscurePassword,
    required this.obscurePasswordConfirmation,
    required this.acceptTerms,
    required this.acceptPrivacyPolicy,
    required this.acceptPersonalData,
    required this.acceptPublicPersonalDataDistribution,
    required this.onTogglePasswordVisibility,
    required this.onTogglePasswordConfirmationVisibility,
    required this.onClearError,
    required this.onAcceptTermsChanged,
    required this.onAcceptPrivacyPolicyChanged,
    required this.onAcceptPersonalDataChanged,
    required this.onAcceptPublicPersonalDataChanged,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController displayNameController;
  final TextEditingController usernameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final TextEditingController passwordConfirmationController;
  final bool obscurePassword;
  final bool obscurePasswordConfirmation;
  final bool acceptTerms;
  final bool acceptPrivacyPolicy;
  final bool acceptPersonalData;
  final bool acceptPublicPersonalDataDistribution;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onTogglePasswordConfirmationVisibility;
  final VoidCallback onClearError;
  final ValueChanged<bool> onAcceptTermsChanged;
  final ValueChanged<bool> onAcceptPrivacyPolicyChanged;
  final ValueChanged<bool> onAcceptPersonalDataChanged;
  final ValueChanged<bool> onAcceptPublicPersonalDataChanged;

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: displayNameController,
              autofillHints: const [AutofillHints.name],
              textInputAction: TextInputAction.next,
              onChanged: (_) => onClearError(),
              decoration: const InputDecoration(
                labelText: "Имя",
                hintText: "Как показывать вас в приложении",
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: usernameController,
              autofillHints: const [AutofillHints.username],
              textInputAction: TextInputAction.next,
              onChanged: (_) => onClearError(),
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r"\s")),
              ],
              decoration: const InputDecoration(
                labelText: "Логин",
                hintText: "Например, eco_vyhuhol",
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: (value) {
                final normalized = value?.trim() ?? "";
                if (normalized.isEmpty) {
                  return "Введите логин";
                }
                if (normalized.length < 3) {
                  return "Логин должен быть не короче 3 символов";
                }
                if (normalized.contains(" ")) {
                  return "Логин не должен содержать пробелы";
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: emailController,
              autofillHints: const [AutofillHints.email],
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onChanged: (_) => onClearError(),
              decoration: const InputDecoration(
                labelText: "Электронная почта",
                hintText: "you@example.com",
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (value) {
                final normalized = value?.trim() ?? "";
                if (normalized.isEmpty) {
                  return "Введите электронную почту";
                }
                if (!normalized.contains("@")) {
                  return "Введите корректную электронную почту";
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: phoneController,
              autofillHints: const [AutofillHints.telephoneNumber],
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              onChanged: (_) => onClearError(),
              decoration: const InputDecoration(
                labelText: "Телефон",
                hintText: "Необязательно",
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: passwordController,
              autofillHints: const [AutofillHints.newPassword],
              obscureText: obscurePassword,
              textInputAction: TextInputAction.next,
              onChanged: (_) => onClearError(),
              decoration: InputDecoration(
                labelText: "Пароль",
                hintText: "Придумайте надежный пароль",
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: onTogglePasswordVisibility,
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: _validatePassword,
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: passwordController,
              builder: (context, value, child) {
                return _PasswordStrengthChecklist(password: value.text);
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: passwordConfirmationController,
              autofillHints: const [AutofillHints.newPassword],
              obscureText: obscurePasswordConfirmation,
              textInputAction: TextInputAction.done,
              onChanged: (_) => onClearError(),
              decoration: InputDecoration(
                labelText: "Повторите пароль",
                hintText: "Введите пароль еще раз",
                prefixIcon: const Icon(Icons.verified_user_outlined),
                suffixIcon: IconButton(
                  onPressed: onTogglePasswordConfirmationVisibility,
                  icon: Icon(
                    obscurePasswordConfirmation
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Повторите пароль";
                }
                if (value != passwordController.text) {
                  return "Пароли не совпадают";
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  CheckboxListTile(
                    value: acceptTerms,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (value) => onAcceptTermsChanged(value ?? false),
                    title: const Text("Принимаю пользовательское соглашение"),
                  ),
                  CheckboxListTile(
                    value: acceptPrivacyPolicy,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (value) =>
                        onAcceptPrivacyPolicyChanged(value ?? false),
                    title: const Text(
                      "Ознакомлен с политикой обработки персональных данных",
                    ),
                  ),
                  CheckboxListTile(
                    value: acceptPersonalData,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (value) =>
                        onAcceptPersonalDataChanged(value ?? false),
                    title: const Text(
                      "Даю согласие на обработку персональных данных",
                    ),
                  ),
                  CheckboxListTile(
                    value: acceptPublicPersonalDataDistribution,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (value) =>
                        onAcceptPublicPersonalDataChanged(value ?? false),
                    title: const Text(
                      "Разрешаю публичное распространение данных профиля",
                    ),
                    subtitle: const Text(
                      "Необязательное согласие для открытых разделов профиля.",
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => context.push("/profile/help"),
                icon: const Icon(Icons.description_outlined),
                label: const Text("Открыть документы"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordStrengthChecklist extends StatelessWidget {
  const _PasswordStrengthChecklist({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final rules = _evaluatePassword(password);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Надежность пароля",
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _PasswordRuleRow(
            title: "Не короче 8 символов",
            isPassed: rules.hasMinLength,
          ),
          const SizedBox(height: 8),
          _PasswordRuleRow(
            title: "Есть строчные и заглавные буквы",
            isPassed: rules.hasLetterCaseMix,
          ),
          const SizedBox(height: 8),
          _PasswordRuleRow(
            title: "Есть хотя бы одна цифра",
            isPassed: rules.hasDigit,
          ),
          const SizedBox(height: 8),
          _PasswordRuleRow(title: "Без пробелов", isPassed: rules.hasNoSpaces),
        ],
      ),
    );
  }
}

class _PasswordRuleRow extends StatelessWidget {
  const _PasswordRuleRow({required this.title, required this.isPassed});

  final String title;
  final bool isPassed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isPassed
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Icon(
          isPassed ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: isPassed ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _PasswordRules {
  const _PasswordRules({
    required this.hasMinLength,
    required this.hasLetterCaseMix,
    required this.hasDigit,
    required this.hasNoSpaces,
  });

  final bool hasMinLength;
  final bool hasLetterCaseMix;
  final bool hasDigit;
  final bool hasNoSpaces;
}

_PasswordRules _evaluatePassword(String value) {
  final hasUppercase = value.contains(RegExp(r"[A-ZА-Я]"));
  final hasLowercase = value.contains(RegExp(r"[a-zа-я]"));

  return _PasswordRules(
    hasMinLength: value.length >= 8,
    hasLetterCaseMix: hasUppercase && hasLowercase,
    hasDigit: value.contains(RegExp(r"\d")),
    hasNoSpaces: !value.contains(RegExp(r"\s")),
  );
}

String? _validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return "Введите пароль";
  }

  final rules = _evaluatePassword(value);
  if (!rules.hasMinLength) {
    return "Пароль должен быть не короче 8 символов";
  }
  if (!rules.hasLetterCaseMix) {
    return "Добавьте строчные и заглавные буквы";
  }
  if (!rules.hasDigit) {
    return "Добавьте хотя бы одну цифру";
  }
  if (!rules.hasNoSpaces) {
    return "Пароль не должен содержать пробелы";
  }
  return null;
}
