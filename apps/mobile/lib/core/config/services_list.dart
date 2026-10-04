import 'package:flutter/material.dart';

class ServiceDef {
  final String id;
  final String title;
  final IconData icon;
  final String imageUrl;
  final String category; // 'Home', 'Tech', 'Vehicle', 'Beauty'
  final double rating;
  final double priceMin;
  final double priceMax;

  const ServiceDef({
    required this.id,
    required this.title,
    required this.icon,
    required this.imageUrl,
    required this.category,
    this.rating = 4.8,
    this.priceMin = 150.0,
    this.priceMax = 350.0,
  });

  factory ServiceDef.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    return ServiceDef(
      id: id,
      title: json['title'] as String? ?? id.replaceAll('_', ' ').split(' ').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '').join(' '),
      icon: _getIconForId(id),
      imageUrl: json['image_url'] as String? ?? json['imageUrl'] as String? ?? '',
      category: json['category'] as String? ?? 'Home',
      rating: (json['rating'] as num?)?.toDouble() ?? 4.8,
      priceMin: (json['price_min'] as num?)?.toDouble() ?? (json['priceMin'] as num?)?.toDouble() ?? 150.0,
      priceMax: (json['price_max'] as num?)?.toDouble() ?? (json['priceMax'] as num?)?.toDouble() ?? 350.0,
    );
  }
}

IconData _getIconForId(String id) {
  switch (id) {
    case 'electrician':
    case 'emergency_electrician':
      return Icons.electrical_services_rounded;
    case 'plumber':
    case 'emergency_plumbing':
      return Icons.plumbing_rounded;
    case 'phone_repair':
      return Icons.phone_android_rounded;
    case 'laptop_repair':
      return Icons.laptop_mac_rounded;
    case 'ac_service':
    case 'ac_breakdown':
      return Icons.ac_unit_rounded;
    case 'carpenter':
      return Icons.carpenter_rounded;
    case 'stove_repair':
    case 'gas_stove_repair':
      return Icons.local_fire_department_rounded;
    default:
      return Icons.home_repair_service_rounded;
  }
}

const List<ServiceDef> kAllServices = [
  ServiceDef(
    id: 'electrician',
    title: 'Electrician',
    icon: Icons.electrical_services_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1621905251918-48416bd8575a?auto=format&fit=crop&w=600&q=80',
    category: 'Home',
    rating: 4.84,
    priceMin: 99.0,
    priceMax: 299.0,
  ),
  ServiceDef(
    id: 'plumber',
    title: 'Plumber',
    icon: Icons.plumbing_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1607472586893-edb57bdc0e39?auto=format&fit=crop&w=600&q=80',
    category: 'Home',
    rating: 4.82,
    priceMin: 99.0,
    priceMax: 349.0,
  ),
  ServiceDef(
    id: 'phone_repair',
    title: 'Phone Repair',
    icon: Icons.phone_android_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1512941937669-90a1b58e7e9c?auto=format&fit=crop&w=600&q=80',
    category: 'Tech',
    rating: 4.88,
    priceMin: 499.0,
    priceMax: 1499.0,
  ),
  ServiceDef(
    id: 'laptop_repair',
    title: 'Laptop Repair',
    icon: Icons.laptop_mac_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1588702547954-4800f964702a?auto=format&fit=crop&w=600&q=80',
    category: 'Tech',
    rating: 4.92,
    priceMin: 449.0,
    priceMax: 1299.0,
  ),
  ServiceDef(
    id: 'ac_service',
    title: 'AC Service',
    icon: Icons.ac_unit_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?auto=format&fit=crop&w=600&q=80',
    category: 'Home',
    rating: 4.89,
    priceMin: 399.0,
    priceMax: 899.0,
  ),
  ServiceDef(
    id: 'carpenter',
    title: 'Carpenter',
    icon: Icons.carpenter_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1504148455328-c376907d081c?auto=format&fit=crop&w=600&q=80',
    category: 'Home',
    rating: 4.79,
    priceMin: 149.0,
    priceMax: 499.0,
  ),
  ServiceDef(
    id: 'stove_repair',
    title: 'Stove Repair',
    icon: Icons.local_fire_department_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?auto=format&fit=crop&w=600&q=80',
    category: 'Home',
    rating: 4.85,
    priceMin: 199.0,
    priceMax: 449.0,
  ),
  ServiceDef(
    id: 'home_repair',
    title: 'Home Repair',
    icon: Icons.home_repair_service_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1581783342308-f792dbdd27c5?auto=format&fit=crop&w=600&q=80',
    category: 'Home',
    rating: 4.88,
    priceMin: 99.0,
    priceMax: 299.0,
  ),
];
