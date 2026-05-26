// lib/admin/components/admin_data_table.dart
// ─────────────────────────────────────────────────────────────────────────────
// Reusable data table component for CMS listing & CRUD operations
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/theme.dart';

typedef RowBuilder<T> = List<Widget> Function(T item, int index);

class AdminDataTable<T> extends StatefulWidget {
  const AdminDataTable({
    super.key,
    required this.title,
    required this.items,
    required this.columns,
    required this.rowBuilder,
    required this.onSearch,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    this.searchHint = 'Search…',
    this.isLoading = false,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyMessage = 'No items found',
  });

  final String title;
  final List<T> items;
  final List<String> columns;
  final RowBuilder<T> rowBuilder;
  final Function(String query) onSearch;
  final VoidCallback onAdd;
  final Function(T item) onEdit;
  final Function(String id) onDelete;
  final String searchHint;
  final bool isLoading;
  final IconData emptyIcon;
  final String emptyMessage;

  @override
  State<AdminDataTable<T>> createState() => _AdminDataTableState<T>();
}

class _AdminDataTableState<T> extends State<AdminDataTable<T>> {
  late TextEditingController _searchCtrl;
  late ScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _scrollCtrl = ScrollController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Header with toolbar ────────────────────────────────────────────
        _buildToolbar(),

        // ── Table / List content ────────────────────────────────────────────
        Expanded(
          child: widget.isLoading
              ? const _LoadingState()
              : widget.items.isEmpty
              ? _EmptyState(
            icon: widget.emptyIcon,
            message: widget.emptyMessage,
          )
              : _buildTable(),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: EkkleiciaColors.bgDeep,
        border: Border(
          bottom: BorderSide(
            color: EkkleiciaColors.goldBorder,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Add button
          Row(
            children: [
              Text(
                widget.title,
                style: EkkleciaTheme.headingMedium,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: widget.onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add New'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search field
          TextField(
            controller: _searchCtrl,
            onChanged: widget.onSearch,
            style: const TextStyle(
              color: EkkleiciaColors.textPrimary,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: widget.searchHint,
              hintStyle: const TextStyle(
                color: EkkleiciaColors.textSecondary,
                fontSize: 12,
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
                color: EkkleiciaColors.goldDim,
              ),
              filled: true,
              fillColor: EkkleiciaColors.bgElevated,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: EkkleiciaColors.goldBorder,
                  width: 0.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: EkkleiciaColors.gold,
                  width: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return SingleChildScrollView(
      controller: _scrollCtrl,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            EkkleiciaColors.bgElevated,
          ),
          dataRowColor: WidgetStateProperty.all(
            EkkleiciaColors.bgMid,
          ),
          columns: [
            // Index column
            DataColumn(
              label: Text(
                '#',
                style: EkkleciaTheme.headingSmall,
              ),
              numeric: true,
            ),
            // Content columns
            ...widget.columns.map(
                  (col) => DataColumn(
                label: Text(
                  col,
                  style: EkkleciaTheme.headingSmall,
                ),
              ),
            ),
            // Actions column
            DataColumn(
              label: Text(
                'Actions',
                style: EkkleciaTheme.headingSmall,
              ),
            ),
          ],
          rows: List.generate(
            widget.items.length,
                (index) {
              final item = widget.items[index];
              final rowCells = widget.rowBuilder(item, index);

              return DataRow(
                cells: [
                  // Index cell
                  DataCell(
                    Text(
                      '${index + 1}',
                      style: EkkleciaTheme.bodySmall,
                    ),
                  ),
                  // Row cells
                  ...rowCells.map((cell) => DataCell(cell)),
                  // Actions cell
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ActionButton(
                          icon: Icons.edit_outlined,
                          tooltip: 'Edit',
                          onPressed: () => widget.onEdit(item),
                          color: EkkleiciaColors.gold,
                        ),
                        const SizedBox(width: 8),
                        _ActionButton(
                          icon: Icons.delete_outline,
                          tooltip: 'Delete',
                          onPressed: () => _confirmDelete(item),
                          color: EkkleiciaColors.maroon,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _confirmDelete(T item) {
    final id = (item as dynamic).id as String;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EkkleiciaColors.bgPrimary,
        title: const Text(
          'Delete Item?',
          style: TextStyle(
            color: EkkleiciaColors.textPrimary,
          ),
        ),
        content: const Text(
          'This action cannot be undone.',
          style: TextStyle(
            color: EkkleiciaColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: EkkleiciaColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete(id);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: EkkleiciaColors.maroon),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// LOADING STATE
// ════════════════════════════════════════════════════════════════════════════
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation(EkkleiciaColors.gold),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ════════════════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 48,
            color: EkkleiciaColors.goldDim,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: EkkleiciaColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ACTION BUTTON
// ════════════════════════════════════════════════════════════════════════════
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: color.withOpacity(0.4),
              width: 0.5,
            ),
          ),
          child: Icon(
            icon,
            size: 14,
            color: color,
          ),
        ),
      ),
    );
  }
}