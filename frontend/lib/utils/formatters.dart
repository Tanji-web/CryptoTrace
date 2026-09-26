import '../models/trace_models.dart';

String shorten(String value, {int keep = 6}) {
  if (value.length <= keep * 2 + 3) return value;
  return '${value.substring(0, keep)}...${value.substring(value.length - 4)}';
}

String formatEth(double value) {
  if (value == 0) return '0 ETH';
  if (value >= 1) return '${value.toStringAsFixed(2)} ETH';
  if (value >= 0.000001) return '${value.toStringAsFixed(6)} ETH';
  return '${value.toStringAsFixed(8)} ETH';
}

String edgeLabel(GraphEdge edge) {
  if (edge.assetType == 'contract_interaction') return 'Contract interaction';
  final amount = edge.assetSymbol == 'ETH' || edge.assetType == 'native_eth' || edge.assetType == 'internal_eth'
      ? formatEth(edge.amount)
      : '${edge.amount.toStringAsFixed(edge.amount >= 100 ? 0 : 4)} ${edge.assetSymbol ?? 'TOKEN'}';
  return amount;
}
