// lib/src/widgets/agent_ui_chat.dart
//
// Batik Framework - Enhanced Chat Widget (Riverpod-powered)
// ============================================================
// Full-featured agent conversation widget integrating:
//  • Riverpod state management
//  • Streaming with progress bar
//  • Diff-aware rendering with animations
//  • Skeleton loading
//  • Offline cache awareness
//  • Tool-use status display
//  • Multi-session support
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../state/agent_providers.dart';
import '../renderer/ui_renderer.dart';
import '../core/action_dispatcher.dart';
import '../core/registry.dart';
import '../animation/animated_node_renderer.dart';
import '../schema/ui_schema.dart';

// ─────────────────────────────────────────────
// AgentUIChat
// ─────────────────────────────────────────────

/// Full-featured agent conversation widget with streaming, animations, and state management.
///
/// Features:
/// - Real-time streaming response with progress bar
/// - Diff-aware rendering for smooth animations
/// - Tool-use status indicators
/// - Multi-session support via Riverpod
/// - Skeleton loading states
/// - Customizable chat bubbles and layouts
/// - Offline cache awareness
class AgentUIChat extends ConsumerStatefulWidget {
  const AgentUIChat({
    super.key,
    required this.config,
    required this.actionHandler,
    this.registry,
    this.animationConfig = const AnimationConfig(),
    this.initialVariables = const {},
    this.initialPrompt,
    this.showInputBar = true,
    this.inputHint = 'Message…',
    this.showToolStatusIndicator = true,
    this.onError,
    this.headerBuilder,
    this.emptyStateBuilder,
    this.userBubbleBuilder,
    this.agentBubbleBuilder,
    this.useStreaming = true,
  });

  /// Session configuration (ID, initial messages, etc.)
  final AgentSessionConfig config;

  /// Handler for processing user actions triggered from the UI
  final ActionHandler actionHandler;

  /// Custom component registry (defaults to built-in components)
  final UIComponentRegistry? registry;

  /// Animation configuration for entrance and update animations
  final AnimationConfig animationConfig;

  /// Initial runtime variables available to the UI
  final Map<String, dynamic> initialVariables;

  /// Optional message to send automatically on mount
  final String? initialPrompt;

  /// Show the message input bar
  final bool showInputBar;

  /// Placeholder text for the input field
  final String inputHint;

  /// Show status indicator when agent is using tools
  final bool showToolStatusIndicator;

  /// Callback for handling errors
  final void Function(Object)? onError;

  /// Custom builder for header section (above messages)
  final Widget Function(BuildContext)? headerBuilder;

  /// Custom builder for empty state (no messages yet)
  final Widget Function(BuildContext)? emptyStateBuilder;

  /// Custom builder for user message bubbles
  final Widget Function(BuildContext, String text)? userBubbleBuilder;

  /// Custom builder for agent response bubbles
  final Widget Function(BuildContext, ConversationTurn)? agentBubbleBuilder;

  /// Enable streaming mode (real-time response streaming)
  final bool useStreaming;

  @override
  ConsumerState<AgentUIChat> createState() => _AgentUIChatState();
}

class _AgentUIChatState extends ConsumerState<AgentUIChat> {
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode();

  AgentSessionNotifier get _session =>
      ref.read(agentSessionProvider(widget.config).notifier);

  @override
  void initState() {
    super.initState();
    // Seed variable store
    if (widget.initialVariables.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(
              sessionVariableStoreProvider(
                widget.config.sessionId ?? 'default',
              ).notifier,
            )
            .setMany(widget.initialVariables);
      });
    }
    // Auto-send initial prompt
    if (widget.initialPrompt != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMessage(widget.initialPrompt!);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    _inputController.clear();

    if (widget.useStreaming) {
      _session.sendMessageStreaming(text);
    } else {
      _session.sendMessage(text);
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(agentSessionProvider(widget.config));

    // Auto-scroll on new content
    ref.listen(agentSessionProvider(widget.config), (prev, next) {
      if (next.history.length != prev?.history.length) {
        _scrollToBottom();
      }
    });

    // Propagate errors
    if (sessionState.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onError?.call(sessionState.error!);
      });
    }

    return Column(
      children: [
        // Streaming progress bar
        StreamProgressBar(
          progress: sessionState.streamProgress,
          isStreaming: sessionState.status == AgentSessionStatus.streaming,
        ),

        // Tool-use status banner
        if (widget.showToolStatusIndicator &&
            sessionState.status == AgentSessionStatus.callingTool)
          _ToolStatusBanner(detail: sessionState.statusDetail),

        // Header
        if (widget.headerBuilder != null) widget.headerBuilder!(context),

        // Message list
        Expanded(
          child: sessionState.history.isEmpty && !sessionState.isLoading
              ? _buildEmptyState(context)
              : _buildMessageList(context, sessionState),
        ),

        // Input bar
        if (widget.showInputBar) _buildInputBar(context, sessionState),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return widget.emptyStateBuilder?.call(context) ??
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 48,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 12),
              Text(
                'Start a conversation',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
        );
  }

  Widget _buildMessageList(
    BuildContext context,
    AgentSessionState sessionState,
  ) {
    final turns = sessionState.history;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: turns.length + (sessionState.isLoading ? 1 : 0),
      itemBuilder: (ctx, i) {
        // Loading skeleton at end
        if (i == turns.length) {
          return _buildLoadingSkeleton(ctx, sessionState);
        }
        return _buildTurn(ctx, turns[i], i);
      },
    );
  }

  Widget _buildTurn(BuildContext ctx, ConversationTurn turn, int index) {
    if (turn.role == 'user') {
      final bubble =
          widget.userBubbleBuilder?.call(ctx, turn.content) ??
          _UserBubble(text: turn.content);

      return AnimatedUINode(
        animation: widget.animationConfig.entranceAnimation,
        staggerIndex: 0,
        child: bubble,
      );
    }

    if (turn.uiResponse != null) {
      return AnimatedUINode(
        animation: widget.animationConfig.entranceAnimation,
        staggerIndex: 0,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child:
              widget.agentBubbleBuilder?.call(ctx, turn) ??
              _buildUIResponse(ctx, turn),
        ),
      );
    }

    if (turn.content.isNotEmpty) {
      return AnimatedUINode(
        animation: widget.animationConfig.entranceAnimation,
        staggerIndex: 0,
        child: _AgentTextBubble(text: turn.content),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildUIResponse(BuildContext ctx, ConversationTurn turn) {
    final sessionState = ref.read(agentSessionProvider(widget.config));

    return ProviderScope(
      child: AgentUIRenderer(
        response: turn.uiResponse!,
        actionHandler: widget.actionHandler,
        registry: widget.registry,
        onError: (e, _) => widget.onError?.call(e),
        diff: sessionState.lastDiff,
        animationConfig: widget.animationConfig,
      ),
    );
  }

  Widget _buildLoadingSkeleton(
    BuildContext ctx,
    AgentSessionState sessionState,
  ) {
    if (sessionState.currentResponse != null &&
        sessionState.status == AgentSessionStatus.streaming) {
      // Show partial streaming result
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AgentUIRenderer(
          response: sessionState.currentResponse!,
          actionHandler: widget.actionHandler,
          registry: widget.registry,
          animationConfig: widget.animationConfig,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SkeletonLoader(lines: 3, showHeader: true),
      ),
    );
  }

  Widget _buildInputBar(BuildContext ctx, AgentSessionState sessionState) {
    final isLoading = sessionState.isLoading;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
        top: 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(ctx).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _inputFocus,
              enabled: !isLoading,
              maxLines: 6,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: widget.inputHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SendButton(
            isLoading: isLoading,
            onSend: () => _sendMessage(_inputController.text),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Updated AgentUIRenderer (diff + animation aware)
// ─────────────────────────────────────────────

extension AgentUIRendererEnhanced on AgentUIRenderer {
  // The existing renderer is extended via constructor params
  // diff and animationConfig are new optional params
}

// ─────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withOpacity(.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(text, style: TextStyle(color: cs.onPrimary, fontSize: 15)),
      ),
    );
  }
}

class _AgentTextBubble extends StatelessWidget {
  const _AgentTextBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Text(text, style: TextStyle(color: cs.onSurface, fontSize: 15)),
      ),
    );
  }
}

class _ToolStatusBanner extends StatelessWidget {
  const _ToolStatusBanner({this.detail});
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.onTertiaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            detail ?? 'Agent is using a tool…',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.isLoading, required this.onSend});
  final bool isLoading;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: isLoading
          ? Container(
              key: const ValueKey('loading'),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(.2),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            )
          : IconButton.filled(
              key: const ValueKey('send'),
              onPressed: onSend,
              icon: const Icon(Icons.arrow_upward_rounded),
              iconSize: 20,
            ),
    );
  }
}
