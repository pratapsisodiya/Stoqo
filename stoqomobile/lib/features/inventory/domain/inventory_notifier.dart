import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stoqomobile/features/inventory/data/product_repository.dart';
import 'package:stoqomobile/features/inventory/domain/models/movement_model.dart';
import 'package:stoqomobile/features/inventory/domain/models/product_model.dart';
import 'package:stoqomobile/shared/providers/global_providers.dart';

class ProductListState {
  final List<ProductModel> products;
  final bool loading;
  final String? error;
  final String query;
  final bool lowStockOnly;

  const ProductListState({
    this.products = const [],
    this.loading = false,
    this.error,
    this.query = '',
    this.lowStockOnly = false,
  });

  ProductListState copyWith({
    List<ProductModel>? products,
    bool? loading,
    String? error,
    String? query,
    bool? lowStockOnly,
  }) =>
      ProductListState(
        products: products ?? this.products,
        loading: loading ?? this.loading,
        error: error,
        query: query ?? this.query,
        lowStockOnly: lowStockOnly ?? this.lowStockOnly,
      );
}

class ProductListNotifier extends StateNotifier<ProductListState> {
  final ProductRepository _repo;

  ProductListNotifier(this._repo) : super(const ProductListState());

  Future<void> load(String branchId) async {
    state = state.copyWith(loading: true);
    try {
      final products = await _repo.getProducts(
        branchId,
        query: state.query.isEmpty ? null : state.query,
        lowStockOnly: state.lowStockOnly,
      );
      state = state.copyWith(products: products, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void setQuery(String q, String branchId) {
    state = state.copyWith(query: q);
    load(branchId);
  }

  void toggleLowStock(String branchId) {
    state = state.copyWith(lowStockOnly: !state.lowStockOnly);
    load(branchId);
  }
}

final productListProvider =
    StateNotifierProvider<ProductListNotifier, ProductListState>((ref) {
  return ProductListNotifier(ref.watch(productRepoProvider));
});

// Single product — reads from local DB only
final productDetailProvider =
    FutureProvider.family<ProductModel?, String>((ref, id) async {
  return ref.watch(productRepoProvider).getProduct(id);
});

// Movements — local DB only
final movementsProvider =
    FutureProvider.family<List<MovementModel>, (String branchId, String? productId)>(
        (ref, args) async {
  return ref.watch(productRepoProvider).getMovements(args.$1, productId: args.$2);
});

// Dashboard stats entirely from local DB
final dashboardStatsProvider =
    FutureProvider.family<DashboardStats, String>((ref, branchId) async {
  final repo = ref.watch(productRepoProvider);
  final lowStock = await repo.countLowStock(branchId);
  final outOfStock = await repo.countOutOfStock(branchId);
  final total = await repo.countProducts(branchId);
  final todayMovements = await repo.getTodayMovements(branchId);
  return DashboardStats(
    lowStock: lowStock,
    outOfStock: outOfStock,
    totalProducts: total,
    todayMovementCount: todayMovements.length,
  );
});

class DashboardStats {
  final int lowStock;
  final int outOfStock;
  final int totalProducts;
  final int todayMovementCount;

  const DashboardStats({
    required this.lowStock,
    required this.outOfStock,
    required this.totalProducts,
    required this.todayMovementCount,
  });
}
