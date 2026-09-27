import 'dart:collection';

import 'package:flutter/material.dart';

import '../../models/trace_models.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../evidence/transaction_evidence_card.dart';

class GraphSection extends StatelessWidget {
  final TraceResult? result;
  final bool isLoading;
  final String? selectedNodeId;
  final ValueChanged<String> onNodeSelected;

  const GraphSection({
    super.key,
    required this.result,
    required this.isLoading,
    required this.selectedNodeId,
    required this.onNodeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Stack(
        children: [
          Positioned.fill(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : result == null
                    ? const Center(
                        child: Text(
                          'Enter a wallet address and click "Trace Wallet" to build the graph.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : TransactionGraph(
                        result: result!,
                        selectedNodeId: selectedNodeId,
                        onNodeSelected: onNodeSelected,
                      ),
          ),
          if (result != null)
            Positioned(
              left: 16,
              bottom: 16,
              child: const GraphLegend(),
            ),
        ],
      ),
    );
  }
}

class GraphLegend extends StatelessWidget {
  const GraphLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String label) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          item(AppColors.targetAmber, 'Target wallet'),
          item(AppColors.wallet, 'Wallet'),
          item(AppColors.vasp, 'Known VASP'),
          item(AppColors.targetAmber, 'Pattern indicator'),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// Transaction graph rendering
// --------------------------------------------------------------------------- //

class TransactionGraph extends StatefulWidget {
  final TraceResult result;
  final String? selectedNodeId;
  final ValueChanged<String> onNodeSelected;

  const TransactionGraph({
    super.key,
    required this.result,
    required this.selectedNodeId,
    required this.onNodeSelected,
  });

  @override
  State<TransactionGraph> createState() => TransactionGraphState();
}

class TransactionGraphState extends State<TransactionGraph> {
  int _estimateMaxLevel(TraceResult result) {
    final target = result.summary.targetWallet;
    final adjacency = <String, Set<String>>{for (final n in result.nodes) n.id: <String>{}};
    for (final e in result.edges) {
      adjacency[e.from]?.add(e.to);
      adjacency[e.to]?.add(e.from);
    }
    final levels = <String, int>{target: 0};
    final queue = Queue<String>()..add(target);
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      for (final neighbor in adjacency[current] ?? <String>{}) {
        if (!levels.containsKey(neighbor)) {
          levels[neighbor] = levels[current]! + 1;
          queue.add(neighbor);
        }
      }
    }
    return levels.values.isEmpty ? 0 : levels.values.reduce((a, b) => a > b ? a : b);
  }

  static const double nodeRadius = 26;

  Map<String, Offset> _computeLayout(Size availableSize) {
    final nodes = widget.result.nodes;
    final edges = widget.result.edges;
    final target = widget.result.summary.targetWallet;

    final adjacency = <String, Set<String>>{for (final n in nodes) n.id: <String>{}};
    for (final e in edges) {
      adjacency[e.from]?.add(e.to);
      adjacency[e.to]?.add(e.from);
    }

    final levels = <String, int>{};
    if (nodes.any((n) => n.id == target)) {
      levels[target] = 0;
      final queue = Queue<String>()..add(target);
      while (queue.isNotEmpty) {
        final current = queue.removeFirst();
        for (final neighbor in adjacency[current] ?? <String>{}) {
          if (!levels.containsKey(neighbor)) {
            levels[neighbor] = levels[current]! + 1;
            queue.add(neighbor);
          }
        }
      }
    }

    var maxLevel = levels.values.isEmpty ? 0 : levels.values.reduce((a, b) => a > b ? a : b);
    for (final n in nodes) {
      levels.putIfAbsent(n.id, () => ++maxLevel);
    }

    final byLevel = <int, List<String>>{};
    for (final entry in levels.entries) {
      byLevel.putIfAbsent(entry.value, () => []).add(entry.key);
    }

    final maxNodesInLevel = byLevel.values.fold<int>(1, (m, ids) => ids.length > m ? ids.length : m);
    final dynamicRowSpacing = (availableSize.height / (maxNodesInLevel + 1)).clamp(78.0, 150.0);
    final dynamicColumnSpacing = maxNodesInLevel >= 5 ? 260.0 : 230.0;

    final positions = <String, Offset>{};
    final sortedLevels = byLevel.keys.toList()..sort();
    for (final level in sortedLevels) {
      final ids = byLevel[level]!..sort();
      final columnHeight = ids.length * dynamicRowSpacing;
      final startY = (availableSize.height - columnHeight) / 2 + dynamicRowSpacing / 2;
      for (var i = 0; i < ids.length; i++) {
        positions[ids[i]] = Offset(
          90 + level * dynamicColumnSpacing,
          (startY <= 50 ? 50 : startY) + i * dynamicRowSpacing,
        );
      }
    }
    return positions;
  }

  @override
  Widget build(BuildContext context) {
    final nodes = widget.result.nodes;
    final edges = widget.result.edges;
    final patternNodeIds = widget.result.patterns
        .expand((pattern) => pattern.nodeIds)
        .toSet();
    final patternTxHashes = widget.result.patterns
        .expand((pattern) => pattern.txHashes)
        .toSet();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxLevel = widget.result.nodes.isEmpty
            ? 0
            : _estimateMaxLevel(widget.result);
        final canvasWidth = (constraints.maxWidth > 0 ? constraints.maxWidth : 800)
            .clamp(900, 900 + maxLevel * 230);
        final canvasHeight = (constraints.maxHeight > 0 ? constraints.maxHeight : 600)
            .clamp(620, 1100);
        final canvasSize = Size(canvasWidth.toDouble(), canvasHeight.toDouble());
        final positions = _computeLayout(canvasSize);

        return InteractiveViewer(
          minScale: 0.4,
          maxScale: 2.5,
          boundaryMargin: const EdgeInsets.all(200),
          child: SizedBox(
            width: canvasSize.width,
            height: canvasSize.height,
            child: Stack(
              children: [
                CustomPaint(
                  size: canvasSize,
                  painter: EdgePainter(
                    edges: edges,
                    positions: positions,
                    patternTxHashes: patternTxHashes,
                  ),
                ),
                for (final node in nodes)
                  if (positions.containsKey(node.id))
                    Positioned(
                      left: positions[node.id]!.dx - nodeRadius,
                      top: positions[node.id]!.dy - nodeRadius,
                      child: GraphNodeWidget(
                        node: node,
                        radius: nodeRadius,
                        isSelected: node.id == widget.selectedNodeId,
                        hasPattern: patternNodeIds.contains(node.id),
                        onTap: () => showNodeDetails(context, node),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showNodeDetails(BuildContext context, GraphNode node) {
    widget.onNodeSelected(node.id);
    final relatedEdges = widget.result.edges.where((e) => e.from == node.id || e.to == node.id).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    node.isVasp ? Icons.account_balance_outlined : Icons.account_balance_wallet_outlined,
                    color: node.isVasp ? AppColors.vasp : (node.isTarget ? AppColors.targetAmber : AppColors.wallet),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      node.isTarget ? 'Target Wallet' : (node.vaspName ?? 'Wallet'),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(node.id, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              if (node.isVasp) ...[
                const SizedBox(height: 4),
                Text('Type: ${node.vaspType ?? "Unknown"} (VASP)',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 3),
                Text(
                  'Registry status: ${node.vaspVerified ? "Verified" : "Demo / not independently verified"}',
                  style: TextStyle(
                    fontSize: 11,
                    color: node.vaspVerified ? AppColors.vasp : AppColors.targetAmber,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const Divider(height: 24),
              Text('Transactions (${relatedEdges.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: relatedEdges.length,
                  separatorBuilder: (_, _) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final e = relatedEdges[index];
                    final direction = e.from == node.id ? 'Sent to' : 'Received from';
                    final counterparty = e.from == node.id ? e.to : e.from;
                    return TransactionEvidenceCard(
                      edge: e,
                      directionLabel: direction,
                      counterparty: counterparty,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


class GraphNodeWidget extends StatelessWidget {
  final GraphNode node;
  final double radius;
  final bool isSelected;
  final bool hasPattern;
  final VoidCallback onTap;

  const GraphNodeWidget({
    super.key,
    required this.node,
    required this.radius,
    required this.isSelected,
    required this.hasPattern,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color fillColor = node.isVasp
        ? AppColors.vasp.withValues(alpha: 0.12)
        : node.isTarget
            ? AppColors.targetAmber.withValues(alpha: 0.15)
            : AppColors.wallet.withValues(alpha: 0.10);
    final Color borderColor = node.isVasp ? AppColors.vasp : (node.isTarget ? AppColors.targetAmber : AppColors.wallet);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  color: fillColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: isSelected || hasPattern ? 3 : 2),
                  boxShadow: [
                    if (hasPattern)
                      BoxShadow(
                        color: AppColors.targetAmber.withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    if (isSelected)
                      BoxShadow(
                        color: borderColor.withValues(alpha: 0.35),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    if (!hasPattern && !isSelected)
                      const BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1)),
                  ],
                ),
                child: Icon(
                  node.isVasp ? Icons.account_balance_outlined : Icons.account_balance_wallet_outlined,
                  size: 20,
                  color: borderColor,
                ),
              ),
              if (hasPattern)
                const Positioned(
                  right: -4,
                  top: -4,
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 15,
                    color: AppColors.targetAmber,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(4)),
            child: Text(
              node.isVasp ? (node.vaspName ?? 'VASP') : shorten(node.id, keep: 5),
              style: const TextStyle(fontSize: 10, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}



class EdgePainter extends CustomPainter {
  final List<GraphEdge> edges;
  final Map<String, Offset> positions;
  final Set<String> patternTxHashes;

  EdgePainter({
    required this.edges,
    required this.positions,
    required this.patternTxHashes,
  });

  String _pairKey(String from, String to) {
    return from.compareTo(to) <= 0 ? '$from|$to' : '$to|$from';
  }

  String _directionKey(GraphEdge edge) => '${edge.from}|${edge.to}';

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final pairGroups = <String, List<GraphEdge>>{};

    for (final edge in edges) {
      pairGroups.putIfAbsent(_pairKey(edge.from, edge.to), () => []).add(edge);
    }

    for (final group in pairGroups.values) {
      final directionGroups = <String, List<GraphEdge>>{};
      for (final edge in group) {
        directionGroups.putIfAbsent(_directionKey(edge), () => []).add(edge);
      }

      final directionKeys = directionGroups.keys.toList()..sort();
      final hasReverseDirections = directionKeys.length > 1;

      for (var directionGroupIndex = 0;
          directionGroupIndex < directionKeys.length;
          directionGroupIndex++) {
        final directionEdges = directionGroups[directionKeys[directionGroupIndex]]!;
        final side = directionGroupIndex == 0 ? -1.0 : 1.0;

        for (var index = 0; index < directionEdges.length; index++) {
          final edge = directionEdges[index];
          final from = positions[edge.from];
          final to = positions[edge.to];
          if (from == null || to == null) continue;

          final direction = to - from;
          final length = direction.distance;
          if (length == 0) continue;
          final unit = direction / length;
          final normal = Offset(-unit.dy, unit.dx);

          final count = directionEdges.length;
          final centeredOffset = count == 1
              ? 0.0
              : (index - (count - 1) / 2) * 14.0;
          final offset = hasReverseDirections
              ? side * 22.0 + centeredOffset
              : centeredOffset;

          final curveFrom = from + normal * offset;
          final curveTo = to + normal * offset;

          final isPatternEdge = patternTxHashes.contains(edge.txHash);
          linePaint
            ..color = isPatternEdge ? AppColors.targetAmber : AppColors.border
            ..strokeWidth = isPatternEdge ? 2.5 : 1.5;

          final path = Path()
            ..moveTo(curveFrom.dx, curveFrom.dy)
            ..quadraticBezierTo(
              (curveFrom.dx + curveTo.dx) / 2 + normal.dx * offset,
              (curveFrom.dy + curveTo.dy) / 2 + normal.dy * offset,
              curveTo.dx,
              curveTo.dy,
            );
          canvas.drawPath(path, linePaint);

          final arrowTip = curveTo - unit * 30;
          _drawArrowhead(canvas, arrowTip - unit * 18, arrowTip, linePaint.color);

          final midpoint = Offset(
            (curveFrom.dx + curveTo.dx) / 2 + normal.dx * offset,
            (curveFrom.dy + curveTo.dy) / 2 + normal.dy * offset,
          );
          final textPainter = TextPainter(
            text: TextSpan(
              text: edgeLabel(edge),
              style: TextStyle(
                fontSize: 9,
                color: isPatternEdge ? AppColors.targetAmber : AppColors.textSecondary,
                backgroundColor: AppColors.background,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: 180);
          textPainter.paint(
            canvas,
            midpoint - Offset(textPainter.width / 2, textPainter.height / 2),
          );
        }
      }
    }
  }

  void _drawArrowhead(Canvas canvas, Offset from, Offset to, Color color) {
    const arrowSize = 6.0;
    final direction = to - from;
    final length = direction.distance;
    if (length == 0) return;
    final unit = direction / length;
    final tip = to - unit * 30;
    final normal = Offset(-unit.dy, unit.dx);
    final p1 = tip - unit * arrowSize + normal * (arrowSize / 2);
    final p2 = tip - unit * arrowSize - normal * (arrowSize / 2);

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant EdgePainter oldDelegate) {
    return oldDelegate.edges != edges ||
        oldDelegate.positions != positions ||
        oldDelegate.patternTxHashes != patternTxHashes;
  }
}
