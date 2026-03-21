import 'package:flutter/material.dart';

import '../../core/theme/tv_theme.dart';

/// TV 优化的网格视图
/// 
/// 专为 TV 端设计的网格布局，特性：
/// - 使用 FocusTraversalGroup 确保 D-Pad 方向键能正确在网格项间移动
/// - 更大的间距和内边距，适合远距离观看
/// - 默认 4 列布局
class TvGridView extends StatelessWidget {
  /// 网格列数，默认 4
  final int crossAxisCount;
  
  /// 主轴间距，默认 24
  final double mainAxisSpacing;
  
  /// 交叉轴间距，默认 24
  final double crossAxisSpacing;
  
  /// 内边距，默认 EdgeInsets.all(48)
  final EdgeInsets padding;
  
  /// 项目数量
  final int itemCount;
  
  /// 项目构建器
  final Widget Function(BuildContext, int) itemBuilder;
  
  /// 子项宽高比
  final double childAspectRatio;
  
  /// 是否收缩包裹内容
  final bool shrinkWrap;
  
  /// 滚动物理效果
  final ScrollPhysics? physics;
  
  /// 滚动控制器
  final ScrollController? controller;

  const TvGridView({
    super.key,
    this.crossAxisCount = TvTheme.gridColumns,
    this.mainAxisSpacing = TvTheme.gridSpacing,
    this.crossAxisSpacing = TvTheme.gridSpacing,
    this.padding = TvTheme.gridPadding,
    required this.itemCount,
    required this.itemBuilder,
    this.childAspectRatio = 1.0,
    this.shrinkWrap = false,
    this.physics,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: _TvGridFocusTraversalPolicy(crossAxisCount),
      child: GridView.builder(
        controller: controller,
        padding: padding,
        shrinkWrap: shrinkWrap,
        physics: physics,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: mainAxisSpacing,
          crossAxisSpacing: crossAxisSpacing,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      ),
    );
  }
}

/// TV 优化的 Sliver 网格视图
/// 
/// 用于 CustomScrollView 中的网格布局
class TvSliverGrid extends StatelessWidget {
  /// 网格列数，默认 4
  final int crossAxisCount;
  
  /// 主轴间距，默认 24
  final double mainAxisSpacing;
  
  /// 交叉轴间距，默认 24
  final double crossAxisSpacing;
  
  /// 项目数量
  final int itemCount;
  
  /// 项目构建器
  final Widget Function(BuildContext, int) itemBuilder;
  
  /// 子项宽高比
  final double childAspectRatio;

  const TvSliverGrid({
    super.key,
    this.crossAxisCount = TvTheme.gridColumns,
    this.mainAxisSpacing = TvTheme.gridSpacing,
    this.crossAxisSpacing = TvTheme.gridSpacing,
    required this.itemCount,
    required this.itemBuilder,
    this.childAspectRatio = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: _TvGridFocusTraversalPolicy(crossAxisCount),
      child: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: mainAxisSpacing,
          crossAxisSpacing: crossAxisSpacing,
          childAspectRatio: childAspectRatio,
        ),
        delegate: SliverChildBuilderDelegate(
          itemBuilder,
          childCount: itemCount,
        ),
      ),
    );
  }
}

/// TV 优化的列表视图
/// 
/// 专为 TV 端设计的列表布局，特性：
/// - 更大的列表项高度
/// - 支持 D-Pad 焦点导航
class TvListView extends StatelessWidget {
  /// 内边距
  final EdgeInsets padding;
  
  /// 项目数量
  final int itemCount;
  
  /// 项目构建器
  final Widget Function(BuildContext, int) itemBuilder;
  
  /// 项目间距
  final double itemSpacing;
  
  /// 是否收缩包裹内容
  final bool shrinkWrap;
  
  /// 滚动物理效果
  final ScrollPhysics? physics;
  
  /// 滚动控制器
  final ScrollController? controller;

  const TvListView({
    super.key,
    this.padding = TvTheme.gridPadding,
    required this.itemCount,
    required this.itemBuilder,
    this.itemSpacing = TvTheme.spacingMedium,
    this.shrinkWrap = false,
    this.physics,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: ListView.separated(
        controller: controller,
        padding: padding,
        shrinkWrap: shrinkWrap,
        physics: physics,
        itemCount: itemCount,
        separatorBuilder: (_, __) => SizedBox(height: itemSpacing),
        itemBuilder: itemBuilder,
      ),
    );
  }
}

/// TV 网格焦点遍历策略
/// 
/// 确保 D-Pad 方向键能在网格中正确导航：
/// - 左/右键在同一行内移动
/// - 上/下键在相邻行的同一列位置移动
class _TvGridFocusTraversalPolicy extends FocusTraversalPolicy
    with DirectionalFocusTraversalPolicyMixin {
  final int crossAxisCount;

  _TvGridFocusTraversalPolicy(this.crossAxisCount);

  @override
  Iterable<FocusNode> sortDescendants(
    Iterable<FocusNode> descendants,
    FocusNode currentNode,
  ) {
    // 按照焦点节点在网格中的位置排序
    final list = descendants.toList();
    
    // 按照垂直位置（y）排序，然后按水平位置（x）排序
    list.sort((a, b) {
      final aRect = a.rect;
      final bRect = b.rect;
      
      // 首先按行排序（y 坐标）
      final rowDiff = (aRect.top - bRect.top).sign.toInt();
      if (rowDiff != 0) return rowDiff;
      
      // 同一行内按列排序（x 坐标）
      return (aRect.left - bRect.left).sign.toInt();
    });
    
    return list;
  }
}

/// TV 水平滚动视图
/// 
/// 专为 TV 端设计的水平滚动列表，常用于：
/// - 首页推荐卡片
/// - 歌单轮播
class TvHorizontalListView extends StatelessWidget {
  /// 内边距
  final EdgeInsets padding;
  
  /// 项目数量
  final int itemCount;
  
  /// 项目构建器
  final Widget Function(BuildContext, int) itemBuilder;
  
  /// 项目间距
  final double itemSpacing;
  
  /// 列表高度
  final double height;
  
  /// 滚动控制器
  final ScrollController? controller;

  const TvHorizontalListView({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: TvTheme.contentPadding),
    required this.itemCount,
    required this.itemBuilder,
    this.itemSpacing = TvTheme.gridSpacing,
    required this.height,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: FocusTraversalGroup(
        child: ListView.separated(
          controller: controller,
          scrollDirection: Axis.horizontal,
          padding: padding,
          itemCount: itemCount,
          separatorBuilder: (_, __) => SizedBox(width: itemSpacing),
          itemBuilder: itemBuilder,
        ),
      ),
    );
  }
}
