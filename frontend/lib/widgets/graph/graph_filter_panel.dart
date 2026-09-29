import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class GraphFilterState {
  final String searchQuery;
  final String assetFilter;
  final String directionFilter;
  final bool patternsOnly;
  final bool evidenceMode;

  const GraphFilterState({
    this.searchQuery = '',
    this.assetFilter = 'all',
    this.directionFilter = 'all',
    this.patternsOnly = false,
    this.evidenceMode = false,
  });

  GraphFilterState copyWith({
    String? searchQuery,
    String? assetFilter,
    String? directionFilter,
    bool? patternsOnly,
    bool? evidenceMode,
  }) {
    return GraphFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      assetFilter: assetFilter ?? this.assetFilter,
      directionFilter: directionFilter ?? this.directionFilter,
      patternsOnly: patternsOnly ?? this.patternsOnly,
      evidenceMode: evidenceMode ?? this.evidenceMode,
    );
  }

  bool get hasActiveFilters =>
      searchQuery.trim().isNotEmpty ||
      assetFilter != 'all' ||
      directionFilter != 'all' ||
      patternsOnly ||
      evidenceMode;
}

class GraphFilterPanel extends StatefulWidget {
  final GraphFilterState state;
  final ValueChanged<GraphFilterState> onChanged;
  final VoidCallback onReset;

  const GraphFilterPanel({
    super.key,
    required this.state,
    required this.onChanged,
    required this.onReset,
  });

  @override
  State<GraphFilterPanel> createState() => _GraphFilterPanelState();
}

class _GraphFilterPanelState extends State<GraphFilterPanel> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.searchQuery);
  }

  @override
  void didUpdateWidget(covariant GraphFilterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_searchController.text != widget.state.searchQuery) {
      _searchController.value = _searchController.value.copyWith(
        text: widget.state.searchQuery,
        selection: TextSelection.collapsed(offset: widget.state.searchQuery.length),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 220,
            child: TextField(
              controller: _searchController,
              onChanged: (value) => widget.onChanged(widget.state.copyWith(searchQuery: value)),
              decoration: InputDecoration(
                hintText: 'Search wallet or transaction...',
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          widget.onChanged(widget.state.copyWith(searchQuery: ''));
                        },
                      ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.3),
                ),
              ),
            ),
          ),
          _buildDropdown(
            value: widget.state.assetFilter,
            label: 'Asset',
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All assets')),
              DropdownMenuItem(value: 'eth', child: Text('ETH')),
              DropdownMenuItem(value: 'erc20', child: Text('ERC-20')),
              DropdownMenuItem(value: 'contract', child: Text('Contract')),
            ],
            onChanged: (value) {
              if (value != null) widget.onChanged(widget.state.copyWith(assetFilter: value));
            },
          ),
          _buildDropdown(
            value: widget.state.directionFilter,
            label: 'Direction',
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All directions')),
              DropdownMenuItem(value: 'outgoing', child: Text('Outgoing from target')),
              DropdownMenuItem(value: 'incoming', child: Text('Incoming to target')),
            ],
            onChanged: (value) {
              if (value != null) widget.onChanged(widget.state.copyWith(directionFilter: value));
            },
          ),
          FilterChip(
            selected: widget.state.patternsOnly,
            label: const Text('Patterns only'),
            avatar: const Icon(Icons.warning_amber_rounded, size: 15),
            onSelected: (selected) => widget.onChanged(widget.state.copyWith(patternsOnly: selected)),
          ),
          FilterChip(
            selected: widget.state.evidenceMode,
            label: const Text('Evidence mode'),
            avatar: const Icon(Icons.fact_check_outlined, size: 15),
            onSelected: (selected) => widget.onChanged(widget.state.copyWith(evidenceMode: selected)),
          ),
          if (widget.state.hasActiveFilters)
            TextButton.icon(
              onPressed: widget.onReset,
              icon: const Icon(Icons.restart_alt, size: 16),
              label: const Text('Reset'),
            ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required String label,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label-$value'),
        initialValue: value,
        isDense: true,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}
