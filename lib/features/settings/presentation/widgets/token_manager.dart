import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Token 列表 Provider
final tokenListProvider = FutureProvider<TokenListResponse>((ref) async {
  final authApi = ref.watch(authApiProvider);
  return authApi.getTokens(limit: 50, offset: 0);
});

/// 令牌管理组件
class TokenManager extends ConsumerWidget {
  const TokenManager({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokensAsync = ref.watch(tokenListProvider);

    return ExpansionTile(
      leading: const Icon(Icons.key),
      title: const Text('令牌管理'),
      subtitle: const Text('管理登录令牌'),
      children: [
        tokensAsync.when(
          data: (response) => _buildTokenList(context, ref, response.tokens),
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  error is ApiException ? error.message : '加载失败',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(tokenListProvider),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTokenList(
    BuildContext context,
    WidgetRef ref,
    List<TokenInfo> tokens,
  ) {
    if (tokens.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('暂无令牌'),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tokens.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final token = tokens[index];
        return _TokenItem(token: token);
      },
    );
  }
}

class _TokenItem extends ConsumerStatefulWidget {
  final TokenInfo token;

  const _TokenItem({required this.token});

  @override
  ConsumerState<_TokenItem> createState() => _TokenItemState();
}

class _TokenItemState extends ConsumerState<_TokenItem> {
  bool _isRevoking = false;

  Future<void> _revokeToken() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认撤销'),
        content: const Text('撤销此令牌后，对应的登录会话将失效。确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('撤销'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isRevoking = true);

    try {
      final authApi = ref.read(authApiProvider);
      await authApi.revokeToken(widget.token.tokenId);
      // 刷新列表
      ref.invalidate(tokenListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('令牌已撤销')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('撤销失败: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('撤销失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRevoking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = widget.token;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 状态颜色
    Color statusColor;
    String statusText;
    if (token.isRevoked) {
      statusColor = colorScheme.error;
      statusText = '已撤销';
    } else if (token.isExpired) {
      statusColor = colorScheme.outline;
      statusText = '已过期';
    } else {
      statusColor = Colors.green;
      statusText = '活跃';
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.2),
        child: Icon(
          token.tokenType == 'access' ? Icons.vpn_key : Icons.refresh,
          color: statusColor,
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              _truncateTokenId(token.tokenId),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              statusText,
              style: theme.textTheme.labelSmall?.copyWith(
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            '类型: ${token.tokenType == 'access' ? '访问令牌' : '刷新令牌'}',
          ),
          if (token.clientInfo != null)
            Text('客户端: ${token.clientInfo}'),
          Text(
            '过期时间: ${_formatDateTime(token.expiresAt)}',
          ),
        ],
      ),
      trailing: token.isValid
          ? IconButton(
              icon: _isRevoking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.block),
              onPressed: _isRevoking ? null : _revokeToken,
              tooltip: '撤销',
            )
          : null,
      isThreeLine: true,
    );
  }

  String _truncateTokenId(String tokenId) {
    if (tokenId.length <= 16) return tokenId;
    return '${tokenId.substring(0, 8)}...${tokenId.substring(tokenId.length - 8)}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
