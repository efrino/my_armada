import 'package:flutter/material.dart';
import '../services/wss_service.dart';
import '../utils/helpers.dart';
import '../utils/permission_manager.dart';
import '../utils/permissions.dart';
import '../models/wss_model.dart';

class HistoryIfpWssPage extends StatefulWidget {
  const HistoryIfpWssPage({super.key});

  @override
  State<HistoryIfpWssPage> createState() => _HistoryIfpWssPageState();
}

class _HistoryIfpWssPageState extends State<HistoryIfpWssPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<WssStockModel> _stocks = [];
  List<WssHistoryModel> _history = [];
  bool _isLoadingStock = false;
  bool _isLoadingHistory = false;

  // Search controllers
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  // Filtered lists
  List<WssStockModel> get _filteredStocks {
    if (_searchQuery.isEmpty) return _stocks;
    return _stocks.where((stock) {
      return stock.partWss.toLowerCase().contains(_searchQuery) ||
          (stock.model?.toLowerCase().contains(_searchQuery) ?? false) ||
          (stock.customer?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();
  }

  List<WssHistoryModel> get _filteredHistory {
    if (_searchQuery.isEmpty) return _history;
    return _history.where((item) {
      return item.partWss.toLowerCase().contains(_searchQuery) ||
          item.referenceType.toLowerCase().contains(_searchQuery) ||
          item.transactionType.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadStocks(), _loadHistory()]);
  }

  Future<void> _loadStocks() async {
    setState(() => _isLoadingStock = true);

    final response = await WssService.getAllStock();

    if (mounted) {
      setState(() {
        _isLoadingStock = false;
        if (response.success && response.data != null) {
          _stocks = response.data!;
        }
      });
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);

    final response = await WssService.getHistory(limit: 100);

    if (mounted) {
      setState(() {
        _isLoadingHistory = false;
        if (response.success && response.data != null) {
          _history = response.data!;
        }
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
  }

  @override
  Widget build(BuildContext context) {
    // Check permission - jika tidak punya view permission, tampilkan no access
    if (!permissionManager.hasPermission(AppPermissions.viewHistoryIfpWss) &&
        !permissionManager.isAdmin) {
      return _buildNoAccess();
    }

    return Column(
      children: [
        // Search Box
        _buildSearchBox(),

        // Tab Bar
        _buildTabBar(),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildStockTab(), _buildHistoryTab()],
          ),
        ),
      ],
    );
  }

  /// Tab Bar Widget
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.blue.shade700,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: Colors.blue.shade700,
        indicatorWeight: 3,
        tabs: const [
          Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Stock WSS'),
          Tab(icon: Icon(Icons.history), text: 'History'),
        ],
      ),
    );
  }

  /// No access widget
  Widget _buildNoAccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Akses Ditolak',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Anda tidak memiliki permission untuk mengakses halaman ini.\nHubungi admin untuk mendapatkan akses.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Cari part, model, customer...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: _clearSearch,
                )
              : null,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildStockTab() {
    if (_isLoadingStock) {
      return const Center(child: CircularProgressIndicator());
    }

    final stocks = _filteredStocks;

    if (_stocks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada data stock',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadStocks,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    if (stocks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Tidak ditemukan "$_searchQuery"',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStocks,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Text(
                  '${stocks.length} item',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                if (_searchQuery.isNotEmpty)
                  Text(
                    ' dari ${_stocks.length}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
              ],
            ),
          ),

          // List items
          ...stocks.map(_buildStockCard),
        ],
      ),
    );
  }

  Widget _buildStockCard(WssStockModel stock) {
    final isLow = stock.isLowStock;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    stock.partWss,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isLow ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isLow ? 'LOW' : 'OK',
                    style: TextStyle(
                      color: isLow
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Stock Info
            Row(
              children: [
                Expanded(
                  child: _buildStockInfo(
                    'Stock',
                    Helpers.formatNumber(stock.stockQty),
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStockInfo(
                    'Min',
                    Helpers.formatNumber(stock.minStock),
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStockInfo(
                    'Model',
                    stock.model ?? '-',
                    Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Customer & Updated
            Row(
              children: [
                Icon(Icons.business, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    stock.customer ?? '-',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  Helpers.formatDateTime(stock.updatedAt),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockInfo(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _getShade700(color),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  /// Helper untuk mendapatkan shade700 dari Color
  Color _getShade700(Color color) {
    return HSLColor.fromColor(color).withLightness(0.3).toColor();
  }

  Widget _buildHistoryTab() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    final history = _filteredHistory;

    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Belum ada history transaksi',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Tidak ditemukan "$_searchQuery"',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: Column(
        children: [
          // Result count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${history.length} item',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                if (_searchQuery.isNotEmpty) ...[
                  Text(
                    ' dari ${_history.length}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                return _buildHistoryCard(item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(WssHistoryModel item) {
    final isIn = item.isIn;
    final color = Helpers.getTransactionColor(item.transactionType);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isIn ? Icons.add_circle_outline : Icons.remove_circle_outline,
            color: color,
            size: 28,
          ),
        ),
        title: Text(
          item.partWss,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${item.referenceType} • ${Helpers.formatDateTime(item.createdAt)}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isIn ? '+' : '-'}${Helpers.formatNumber(item.qtyChange)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
            Text(
              '→ ${Helpers.formatNumber(item.qtyAfter)}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
