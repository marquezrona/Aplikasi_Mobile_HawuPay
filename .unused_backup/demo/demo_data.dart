import '../../features/admin/domain/admin_models.dart';
import '../../features/auth/domain/auth_models.dart';
import '../../features/pos/domain/pos_models.dart';

class DemoAccount {
  const DemoAccount(this.email, this.password, this.name, this.role, [this.storeName]);
  final String email, password, name;
  final UserRole role;
  final String? storeName;
}

/// Data contoh untuk mode demo (tanpa backend).
class DemoData {
  static const admin = DemoAccount('admin@hawupay.demo', 'Admin123!', 'Admin HawuPay', UserRole.admin);
  static const umkm = DemoAccount('umkm@hawupay.demo', 'Umkm123!', 'Ibu Sari', UserRole.umkm, 'Warung Sari Rasa');

  static DemoAccount? match(String email, String password) {
    for (final a in [admin, umkm]) {
      if (a.email == email.trim().toLowerCase() && a.password == password) return a;
    }
    return null;
  }

  static const products = <Product>[
    Product(id: 'p1', name: 'Kopi Susu Gula Aren', price: 18000, stock: 40, category: 'Minuman'),
    Product(id: 'p2', name: 'Es Teh Manis', price: 6000, stock: 80, category: 'Minuman'),
    Product(id: 'p3', name: 'Jus Alpukat', price: 15000, stock: 12, category: 'Minuman'),
    Product(id: 'p4', name: 'Nasi Goreng Spesial', price: 25000, stock: 25, category: 'Makanan'),
    Product(id: 'p5', name: 'Mie Ayam Bakso', price: 20000, stock: 18, category: 'Makanan'),
    Product(id: 'p6', name: 'Ayam Geprek', price: 22000, stock: 0, category: 'Makanan'),
    Product(id: 'p7', name: 'Pisang Goreng', price: 8000, stock: 30, category: 'Snack'),
    Product(id: 'p8', name: 'Kue Lapis', price: 5000, stock: 50, category: 'Snack'),
    Product(id: 'p9', name: 'Keripik Singkong', price: 12000, stock: 22, category: 'Snack'),
    Product(id: 'p10', name: 'Roti Bakar Coklat', price: 14000, stock: 15, category: 'Snack'),
  ];

  static List<PendingProduct> pending() => [
        const PendingProduct(id: 'a1', name: 'Sambal Matah Botol', storeName: 'Warung Sari Rasa', price: 28000, category: 'Makanan'),
        const PendingProduct(id: 'a2', name: 'Kopi Arabika Flores 250g', storeName: 'Kopi Kupang', price: 85000, category: 'Minuman'),
        const PendingProduct(id: 'a3', name: 'Kain Tenun Sikka (Selendang)', storeName: 'Toko Maju Jaya', price: 175000, category: 'Lainnya'),
      ];

  static const stats = AdminStats(
    activeUmkm: 128,
    totalUmkm: 142,
    transactionsToday: 1893,
    volumeToday: 48250000,
    pendingProducts: 3,
  );
}
