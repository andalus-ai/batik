// lib/src/virtualization/virtual_list_renderer.dart
//
// AgentUIKit v2 — Virtualized List & Grid Renderer
// ============================================================
// Replaces the naive all-at-once renderer for ListNode/GridNode
// with a proper virtualized implementation that only builds
// widgets for items in (or near) the viewport.
//
// Also supports:
//  • Infinite scroll with agent pagination
//  • Pull-to-refresh
//  • Separator factory
// ============================================================

import 'package:flutter/material.dart';
import '../schema/ui_schema.dart';
import '../core/registry.dart';

// ─────────────────────────────────────────────
// Virtualisation config
// ─────────────────────────────────────────────

class VirtualizationConfig {
  const VirtualizationConfig({
    this.enableVirtualization = true,
    this.virtualizationThreshold = 20,
    this.cacheExtent = 250.0,
    this.enableInfiniteScroll = false,
    this.pageSize = 20,
    this.enablePullToRefresh = false,
  });

  /// Only virtualize lists with more items than this.
  final int virtualizationThreshold;
  final bool enableVirtualization;

  /// Pixels beyond viewport to keep alive.
  final double cacheExtent;

  final bool enableInfiniteScroll;
  final int pageSize;
  final bool enablePullToRefresh;
}

// ─────────────────────────────────────────────
// Virtual List Widget
// ─────────────────────────────────────────────

class VirtualListWidget extends StatefulWidget {
  const VirtualListWidget({
    super.key,
    required this.node,
    required this.registry,
    required this.renderer,
    this.config = const VirtualizationConfig(),
    this.onLoadMore,
    this.onRefresh,
  });

  final ListNode node;
  final UIComponentRegistry registry;
  final NodeRenderer renderer;
  final VirtualizationConfig config;
  final Future<void> Function()? onLoadMore;
  final Future<void> Function()? onRefresh;

  @override
  State<VirtualListWidget> createState() => _VirtualListWidgetState();
}

class _VirtualListWidgetState extends State<VirtualListWidget> {
  final _scrollController = ScrollController();
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    if (widget.config.enableInfiniteScroll) {
      _scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMore) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _triggerLoadMore();
    }
  }

  Future<void> _triggerLoadMore() async {
    if (_loadingMore || widget.onLoadMore == null) return;
    setState(() => _loadingMore = true);
    await widget.onLoadMore!();
    if (mounted) setState(() => _loadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    final children = widget.node.children;
    final isH = widget.node.scrollDirection == 'horizontal';
    final shouldVirtualize = widget.config.enableVirtualization &&
        children.length >= widget.config.virtualizationThreshold;

    Widget list;

    if (shouldVirtualize) {
      list = _buildVirtualList(children, isH);
    } else {
      list = _buildRegularList(children, isH, context);
    }

    if (widget.config.enablePullToRefresh && widget.onRefresh != null) {
      list = RefreshIndicator(onRefresh: widget.onRefresh!, child: list);
    }

    return list;
  }

  Widget _buildVirtualList(List<UINode> children, bool isH) {
    final hasSeparator = widget.node.separator != null;
    final itemCount = children.length +
        (_loadingMore ? 1 : 0) +
        (widget.node.shrinkWrap == true ? 0 : 0);

    return ListView.builder(
      controller: _scrollController,
      scrollDirection: isH ? Axis.horizontal : Axis.vertical,
      shrinkWrap: widget.node.shrinkWrap ?? false,
      physics: widget.node.shrinkWrap == true
          ? const NeverScrollableScrollPhysics()
          : null,
      cacheExtent: widget.config.cacheExtent,
      itemExtent: widget.node.itemExtent,
      itemCount: itemCount,
      itemBuilder: (ctx, i) {
        // Loading indicator at end
        if (_loadingMore && i == children.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (i >= children.length) return const SizedBox.shrink();

        final node = children[i];
        final item = widget.renderer.render(ctx, node);

        if (hasSeparator && i < children.length - 1) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              item,
              widget.renderer.render(ctx, widget.node.separator!),
            ],
          );
        }
        return item;
      },
    );
  }

  Widget _buildRegularList(
    List<UINode> children,
    bool isH,
    BuildContext context,
  ) {
    final widgets = children
        .map((c) => widget.renderer.render(context, c))
        .toList(growable: false);

    if (widget.node.separator != null) {
      return ListView.separated(
        controller: _scrollController,
        scrollDirection: isH ? Axis.horizontal : Axis.vertical,
        shrinkWrap: widget.node.shrinkWrap ?? false,
        physics: widget.node.shrinkWrap == true
            ? const NeverScrollableScrollPhysics()
            : null,
        itemCount: widgets.length,
        itemBuilder: (_, i) => widgets[i],
        separatorBuilder: (ctx, _) =>
            widget.renderer.render(ctx, widget.node.separator!),
      );
    }

    return ListView(
      controller: _scrollController,
      scrollDirection: isH ? Axis.horizontal : Axis.vertical,
      shrinkWrap: widget.node.shrinkWrap ?? false,
      itemExtent: widget.node.itemExtent,
      children: [
        ...widgets,
        if (_loadingMore)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Virtual Grid Widget
// ─────────────────────────────────────────────

class VirtualGridWidget extends StatelessWidget {
  const VirtualGridWidget({
    super.key,
    required this.node,
    required this.renderer,
    this.config = const VirtualizationConfig(),
  });

  final GridNode node;
  final NodeRenderer renderer;
  final VirtualizationConfig config;

  @override
  Widget build(BuildContext context) {
    final children = node.children;
    final crossAxisCount = node.crossAxisCount ?? 2;
    final shouldVirtualize = config.enableVirtualization &&
        children.length >= config.virtualizationThreshold;

    if (shouldVirtualize) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        cacheExtent: config.cacheExtent,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: node.childAspectRatio ?? 1.0,
          mainAxisSpacing: node.mainAxisSpacing ?? 0,
          crossAxisSpacing: node.crossAxisSpacing ?? 0,
        ),
        itemCount: children.length,
        itemBuilder: (ctx, i) => renderer.render(ctx, children[i]),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      childAspectRatio: node.childAspectRatio ?? 1.0,
      mainAxisSpacing: node.mainAxisSpacing ?? 0,
      crossAxisSpacing: node.crossAxisSpacing ?? 0,
      children: children.map((c) => renderer.render(context, c)).toList(),
    );
  }
}

// ─────────────────────────────────────────────
// Paginated node list (for infinite scroll)
// ─────────────────────────────────────────────

class PaginatedNodeList extends StatefulWidget {
  const PaginatedNodeList({
    super.key,
    required this.initialNodes,
    required this.renderer,
    required this.loadMore,
    this.pageSize = 20,
    this.separator,
  });

  final List<UINode> initialNodes;
  final NodeRenderer renderer;
  final Future<List<UINode>> Function(int page) loadMore;
  final int pageSize;
  final UINode? separator;

  @override
  State<PaginatedNodeList> createState() => _PaginatedNodeListState();
}

class _PaginatedNodeListState extends State<PaginatedNodeList> {
  final _nodes = <UINode>[];
  final _scrollController = ScrollController();
  int _page = 0;
  bool _loading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _nodes.addAll(widget.initialNodes);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loading || !_hasMore) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    setState(() => _loading = true);
    try {
      final newNodes = await widget.loadMore(_page + 1);
      setState(() {
        _nodes.addAll(newNodes);
        _page++;
        _hasMore = newNodes.length >= widget.pageSize;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _nodes.length + (_loading ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == _nodes.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final item = widget.renderer.render(ctx, _nodes[i]);
        if (widget.separator != null && i < _nodes.length - 1) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [item, widget.renderer.render(ctx, widget.separator!)],
          );
        }
        return item;
      },
    );
  }
}
