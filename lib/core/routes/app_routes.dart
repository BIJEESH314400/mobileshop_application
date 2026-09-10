import 'package:flutter/material.dart';

import '../../features/auth/view/login_screen.dart';
import '../../features/customers/view/customers_screen.dart';
import '../../features/dashboard/view/dashboard_screen.dart';
import '../../features/products/view/add_product_screen.dart';
import '../../features/products/view/products_screen.dart';
import '../../features/profile/view/profile_screen.dart';
import '../../features/reports/view/reports_screen.dart';
import '../../features/sales/view/sales_screen.dart';
import '../../features/service/view/service_screen.dart';
import '../../features/splash/view/splash_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const login = '/login';
  static const dashboard = '/dashboard';
  static const products = '/products';
  static const addProduct = '/add-product';
  static const sales = '/sales';
  static const service = '/service';
  static const customers = '/customers';
  static const reports = '/reports';
  static const profile = '/profile';

  static Map<String, WidgetBuilder> routes = {
    splash: (_) => const SplashScreen(),
    login: (_) => const LoginScreen(),
    dashboard: (_) => const DashboardScreen(),
    products: (_) => const ProductsScreen(),
    addProduct: (_) => const AddProductScreen(),
    sales: (_) => const SalesScreen(),
    service: (_) => const ServiceScreen(),
    customers: (_) => const CustomersScreen(),
    reports: (_) => const ReportsScreen(),
    profile: (_) => const ProfileScreen(),
  };
}
