// lib/src/diff/ui_diff_engine.dart
//
// AgentUIKit v2 — UI Diff & Patch Engine
// ============================================================
// Compares two UINode trees and produces a minimal patch set.
// The renderer applies patches instead of rebuilding from scratch,
// preserving widget state (scroll, focus, animation) across turns.
//
// Algorithm: depth-first ID-keyed diffing (inspired by React reconciler).
// Nodes with matching `id` are considered the same logical element.
// Nodes without `id` are matched positionally within their parent.
// ============================================================

import '../schema/ui_schema.dart';

// ─────────────────────────────────────────────
// Patch operations
// ─────────────────────────────────────────────

sealed class UIPatch {
  const UIPatch(this.path);
  final String path; // JSON path to the affected node
}

/// Node props changed (type same, content different).
class UpdatePatch extends UIPatch {
  const UpdatePatch(super.path, {required this.oldNode, required this.newNode});
  final UINode oldNode;
  final UINode newNode;
}

/// Node was replaced with a different type.
class ReplacePatch extends UIPatch {
  const ReplacePatch(
    super.path, {
    required this.oldNode,
    required this.newNode,
  });
  final UINode oldNode;
  final UINode newNode;
}

/// New node inserted at position.
class InsertPatch extends UIPatch {
  const InsertPatch(super.path, {required this.node, required this.index});
  final UINode node;
  final int index;
}

/// Node removed.
class RemovePatch extends UIPatch {
  const RemovePatch(super.path, {required this.node});
  final UINode node;
}

/// Children reordered (IDs same, positions differ).
class ReorderPatch extends UIPatch {
  const ReorderPatch(
    super.path, {
    required this.fromIndex,
    required this.toIndex,
  });
  final int fromIndex;
  final int toIndex;
}

// ─────────────────────────────────────────────
// Diff result
// ─────────────────────────────────────────────

class DiffResult {
  const DiffResult({required this.patches, required this.hasChanges});

  final List<UIPatch> patches;
  final bool hasChanges;

  int get updateCount => patches.whereType<UpdatePatch>().length;
  int get insertCount => patches.whereType<InsertPatch>().length;
  int get removeCount => patches.whereType<RemovePatch>().length;
  int get replaceCount => patches.whereType<ReplacePatch>().length;

  bool get isMinor => patches.length <= 3;
  bool get isMajor => patches.length > 10;

  @override
  String toString() =>
      'DiffResult(${patches.length} patches: '
      '+$insertCount -$removeCount ~$updateCount ↔$replaceCount)';
}

// ─────────────────────────────────────────────
// Diff engine
// ─────────────────────────────────────────────

class UIDiffEngine {
  const UIDiffEngine();

  DiffResult diff(UINode? oldRoot, UINode newRoot) {
    final patches = <UIPatch>[];
    _diffNode(oldRoot, newRoot, path: 'root', patches: patches);
    return DiffResult(patches: patches, hasChanges: patches.isNotEmpty);
  }

  void _diffNode(
    UINode? oldNode,
    UINode newNode, {
    required String path,
    required List<UIPatch> patches,
  }) {
    if (oldNode == null) {
      patches.add(InsertPatch(path, node: newNode, index: 0));
      return;
    }

    // Type changed → full replace
    if (oldNode.type != newNode.type) {
      patches.add(ReplacePatch(path, oldNode: oldNode, newNode: newNode));
      return;
    }

    // Same type — check if content changed
    if (!_propsEqual(oldNode, newNode)) {
      patches.add(UpdatePatch(path, oldNode: oldNode, newNode: newNode));
    }

    // Diff children
    _diffChildren(
      oldNode.children,
      newNode.children,
      parentPath: path,
      patches: patches,
    );
  }

  void _diffChildren(
    List<UINode> oldChildren,
    List<UINode> newChildren, {
    required String parentPath,
    required List<UIPatch> patches,
  }) {
    // Build ID maps for keyed diffing
    final oldById = <String, (int, UINode)>{};
    final newById = <String, (int, UINode)>{};

    for (var i = 0; i < oldChildren.length; i++) {
      final id = oldChildren[i].id;
      if (id != null) oldById[id] = (i, oldChildren[i]);
    }
    for (var i = 0; i < newChildren.length; i++) {
      final id = newChildren[i].id;
      if (id != null) newById[id] = (i, newChildren[i]);
    }

    final matched = <int>{}; // indices in oldChildren that were matched

    // Match by ID first
    for (var ni = 0; ni < newChildren.length; ni++) {
      final newChild = newChildren[ni];
      final newPath = '$parentPath.children[$ni]';
      final id = newChild.id;

      if (id != null && oldById.containsKey(id)) {
        final (oi, oldChild) = oldById[id]!;
        matched.add(oi);

        if (oi != ni) {
          patches.add(ReorderPatch(newPath, fromIndex: oi, toIndex: ni));
        }
        _diffNode(oldChild, newChild, path: newPath, patches: patches);
      } else if (ni < oldChildren.length &&
          !oldById.containsKey(oldChildren[ni].id)) {
        // Positional match for unkeyed nodes
        final oldChild = oldChildren[ni];
        matched.add(ni);
        _diffNode(oldChild, newChild, path: newPath, patches: patches);
      } else {
        // New insertion
        patches.add(InsertPatch(newPath, node: newChild, index: ni));
      }
    }

    // Anything in old not matched → removed
    for (var oi = 0; oi < oldChildren.length; oi++) {
      if (!matched.contains(oi)) {
        patches.add(
          RemovePatch('$parentPath.children[$oi]', node: oldChildren[oi]),
        );
      }
    }
  }

  // ── Shallow prop equality ─────────────────────

  bool _propsEqual(UINode a, UINode b) {
    // Compare JSON representations — simple but reliable.
    // In production, replace with typed field comparison per node class.
    try {
      return _jsonEqual(a.toJson(), b.toJson());
    } catch (_) {
      return false;
    }
  }

  bool _jsonEqual(dynamic a, dynamic b) {
    if (a.runtimeType != b.runtimeType) return false;
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key)) return false;
        // Skip children — diffed separately
        if (key == 'children') continue;
        if (!_jsonEqual(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_jsonEqual(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}

// ─────────────────────────────────────────────
// Patch summariser (for logging / analytics)
// ─────────────────────────────────────────────

extension PatchSummary on DiffResult {
  String get summary {
    if (!hasChanges) return 'No changes';
    final parts = <String>[];
    if (insertCount > 0) parts.add('$insertCount inserted');
    if (removeCount > 0) parts.add('$removeCount removed');
    if (updateCount > 0) parts.add('$updateCount updated');
    if (replaceCount > 0) parts.add('$replaceCount replaced');
    return parts.join(', ');
  }
}
