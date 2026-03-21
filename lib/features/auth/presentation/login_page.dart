import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../domain/auth_state.dart';
import 'providers/auth_provider.dart';

/// 登录页面
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiUrlController = TextEditingController();

  bool _obscurePassword = true;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    // 嵌入模式下 API 地址已由 main() 设定，无需加载存储的地址
    if (!AppConfig.isEmbedded) {
      _loadSavedApiUrl();
    }
  }

  Future<void> _loadSavedApiUrl() async {
    final prefs = await ref.read(appPreferencesProvider.future);
    final savedUrl = prefs.getApiBaseUrl();
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _apiUrlController.text = savedUrl;
      setState(() {
        _showAdvanced = true;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _apiUrlController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authNotifier = ref.read(authStateProvider.notifier);

    await authNotifier.login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      // 嵌入模式不传 apiBaseUrl，baseUrl 已在 main() 中通过 Uri.base.origin 设定
      apiBaseUrl: (!AppConfig.isEmbedded && _apiUrlController.text.trim().isNotEmpty)
          ? _apiUrlController.text.trim()
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 监听认证状态变化，显示错误信息
    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next.error != null && next.error!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // 登录成功后跳转
      if (next.status == AuthStatus.authenticated) {
        // TODO: 使用 go_router 导航到首页
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('登录成功'),
            backgroundColor: colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo 和标题
                    _buildHeader(theme, colorScheme),
                    const SizedBox(height: 48),

                    // 登录表单卡片
                    Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainerLow,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 用户名输入框
                            _buildUsernameField(colorScheme),
                            const SizedBox(height: 16),

                            // 密码输入框
                            _buildPasswordField(colorScheme),
                            const SizedBox(height: 16),

                            // 高级设置（API 地址）— 嵌入模式下隐藏，独立部署时显示
                            if (!AppConfig.isEmbedded) _buildAdvancedSettings(colorScheme),
                            const SizedBox(height: 24),

                            // 登录按钮
                            _buildLoginButton(authState, colorScheme),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 底部提示
                    _buildFooter(theme),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        // Logo
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.music_note_rounded,
            size: 48,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'MiMusic',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '登录以继续',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildUsernameField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _usernameController,
      decoration: const InputDecoration(
        labelText: '用户名',
        hintText: '请输入用户名',
        prefixIcon: Icon(Icons.person_outline),
      ),
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.username],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '请输入用户名';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: '密码',
        hintText: '请输入密码',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
      ),
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      onFieldSubmitted: (_) => _handleLogin(),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入密码';
        }
        return null;
      },
    );
  }

  Widget _buildAdvancedSettings(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 展开/收起按钮
        InkWell(
          onTap: () {
            setState(() {
              _showAdvanced = !_showAdvanced;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  _showAdvanced
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  '高级设置',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),

        // API 地址输入框
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextFormField(
              controller: _apiUrlController,
              decoration: InputDecoration(
                labelText: 'API 地址',
                hintText: AppConfig.baseUrl,
                prefixIcon: const Icon(Icons.cloud_outlined),
                helperText: '独立部署模式使用，留空则使用默认地址',
                helperMaxLines: 2,
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  // 简单的 URL 格式验证
                  if (!value.startsWith('http://') &&
                      !value.startsWith('https://')) {
                    return '请输入有效的 URL（以 http:// 或 https:// 开头）';
                  }
                }
                return null;
              },
            ),
          ),
          crossFadeState: _showAdvanced
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildLoginButton(AuthState authState, ColorScheme colorScheme) {
    return FilledButton(
      onPressed: authState.isLoading ? null : _handleLogin,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
      ),
      child: authState.isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.onPrimary,
              ),
            )
          : const Text('登录'),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Text(
      '© ${DateTime.now().year} MiMusic',
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
