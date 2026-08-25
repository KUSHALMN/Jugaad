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
      return Icons.electrical_services_rounded;
    case 'plumber':
      return Icons.plumbing_rounded;
    case 'laptop_repair':
      return Icons.laptop_mac_rounded;
    case 'phone_repair':
      return Icons.phone_android_rounded;
    case 'carpenter':
      return Icons.carpenter_rounded;
    case 'painter':
      return Icons.format_paint_rounded;
    case 'ac_service':
      return Icons.ac_unit_rounded;
    case 'cleaning':
      return Icons.cleaning_services_rounded;
    case 'car_wash':
      return Icons.local_car_wash_rounded;
    case 'bike_mechanic':
      return Icons.two_wheeler_rounded;
    case 'hair_salon':
      return Icons.content_cut_rounded;
    case 'spa_massage':
      return Icons.spa_rounded;
    case 'water_leakage':
      return Icons.water_damage_rounded;
    case 'power_outage':
      return Icons.power_off_rounded;
    case 'locked_out_of_home':
      return Icons.vpn_key_rounded;
    case 'blocked_toilet_drain':
      return Icons.plumbing_rounded;
    case 'water_pump_failure':
      return Icons.settings_suggest_rounded;
    case 'ac_breakdown':
      return Icons.ac_unit_rounded;
    case 'electrical_short_circuit':
      return Icons.bolt_rounded;
    case 'emergency_plumbing':
      return Icons.plumbing_rounded;
    case 'emergency_electrician':
      return Icons.electrical_services_rounded;
    default:
      return Icons.miscellaneous_services_rounded;
  }
}

const List<ServiceDef> kAllServices = [
  ServiceDef(
    id: 'electrician',
    title: 'Electrician',
    icon: Icons.electrical_services_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1621905251918-48416bd8575a?w=400',
    category: 'Home',
    rating: 4.8,
    priceMin: 150.0,
    priceMax: 350.0,
  ),
  ServiceDef(
    id: 'plumber',
    title: 'Plumber',
    icon: Icons.plumbing_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1607472586893-edb57bdc0e39?w=400',
    category: 'Home',
    rating: 4.7,
    priceMin: 150.0,
    priceMax: 350.0,
  ),
  ServiceDef(
    id: 'laptop_repair',
    title: 'Laptop repair',
    icon: Icons.laptop_mac_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1588702547954-4800f964702a?w=400',
    category: 'Tech',
    rating: 4.9,
    priceMin: 200.0,
    priceMax: 500.0,
  ),
  ServiceDef(
    id: 'phone_repair',
    title: 'Phone repair',
    icon: Icons.phone_android_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1512941937669-90a1b58e7e9c?w=400',
    category: 'Tech',
    rating: 4.8,
    priceMin: 150.0,
    priceMax: 400.0,
  ),
  ServiceDef(
    id: 'carpenter',
    title: 'Carpenter',
    icon: Icons.carpenter_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=400',
    category: 'Home',
    rating: 4.6,
    priceMin: 180.0,
    priceMax: 400.0,
  ),
  ServiceDef(
    id: 'painter',
    title: 'Painter',
    icon: Icons.format_paint_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1562259949-e8e7689d7828?w=400',
    category: 'Home',
    rating: 4.8,
    priceMin: 250.0,
    priceMax: 600.0,
  ),
  ServiceDef(
    id: 'ac_service',
    title: 'AC service',
    icon: Icons.ac_unit_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=400',
    category: 'Home',
    rating: 4.7,
    priceMin: 200.0,
    priceMax: 500.0,
  ),
  ServiceDef(
    id: 'cleaning',
    title: 'Cleaning',
    icon: Icons.cleaning_services_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=400',
    category: 'Home',
    rating: 4.8,
    priceMin: 150.0,
    priceMax: 350.0,
  ),
  ServiceDef(
    id: 'car_wash',
    title: 'Car Wash',
    icon: Icons.local_car_wash_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1520340356584-f9917d1eea6f?w=400',
    category: 'Vehicle',
    rating: 4.7,
    priceMin: 200.0,
    priceMax: 400.0,
  ),
  ServiceDef(
    id: 'bike_mechanic',
    title: 'Bike mechanic',
    icon: Icons.two_wheeler_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1485965120184-e220f721d03e?w=400',
    category: 'Vehicle',
    rating: 4.6,
    priceMin: 150.0,
    priceMax: 350.0,
  ),
  ServiceDef(
    id: 'hair_salon',
    title: 'Hair Salon',
    icon: Icons.content_cut_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1560066984-138dadb4c035?w=400',
    category: 'Beauty',
    rating: 4.8,
    priceMin: 150.0,
    priceMax: 300.0,
  ),
  ServiceDef(
    id: 'spa_massage',
    title: 'Spa & Massage',
    icon: Icons.spa_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1540555700478-4be289fbecef?w=400',
    category: 'Beauty',
    rating: 4.9,
    priceMin: 300.0,
    priceMax: 800.0,
  ),
  ServiceDef(
    id: 'water_leakage',
    title: 'Water Leakage',
    icon: Icons.water_damage_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?w=400',
    category: 'Emergency',
    rating: 4.9,
    priceMin: 300.0,
    priceMax: 800.0,
  ),
  ServiceDef(
    id: 'power_outage',
    title: 'Power Outage',
    icon: Icons.power_off_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1473341304170-971dccb5ac1e?w=400',
    category: 'Emergency',
    rating: 4.9,
    priceMin: 300.0,
    priceMax: 800.0,
  ),
  ServiceDef(
    id: 'locked_out_of_home',
    title: 'Locked Out Of Home',
    icon: Icons.vpn_key_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1507208773393-40d9fc670acf?w=400',
    category: 'Emergency',
    rating: 4.9,
    priceMin: 300.0,
    priceMax: 800.0,
  ),
  ServiceDef(
    id: 'blocked_toilet_drain',
    title: 'Blocked Toilet/Drain',
    icon: Icons.plumbing_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=400',
    category: 'Emergency',
    rating: 4.9,
    priceMin: 300.0,
    priceMax: 800.0,
  ),
  ServiceDef(
    id: 'water_pump_failure',
    title: 'Water Pump Failure',
    icon: Icons.settings_suggest_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1621905251918-48416bd8575a?w=400',
    category: 'Emergency',
    rating: 4.9,
    priceMin: 300.0,
    priceMax: 800.0,
  ),
  ServiceDef(
    id: 'ac_breakdown',
    title: 'AC Breakdown',
    icon: Icons.ac_unit_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=400',
    category: 'Emergency',
    rating: 4.9,
    priceMin: 300.0,
    priceMax: 800.0,
  ),
  ServiceDef(
    id: 'electrical_short_circuit',
    title: 'Electrical Short Circuit',
    icon: Icons.bolt_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1621905251918-48416bd8575a?w=400',
    category: 'Emergency',
    rating: 4.9,
    priceMin: 300.0,
    priceMax: 800.0,
  ),
  ServiceDef(
    id: 'emergency_plumbing',
    title: 'Emergency Plumbing',
    icon: Icons.plumbing_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1607472586893-edb57bdc0e39?w=400',
    category: 'Emergency',
    rating: 4.9,
    priceMin: 300.0,
    priceMax: 800.0,
  ),
  ServiceDef(
    id: 'emergency_electrician',
    title: 'Emergency Electrician',
    icon: Icons.electrical_services_rounded,
    imageUrl: 'https://images.unsplash.com/photo-1621905251918-48416bd8575a?w=400',
    category: 'Emergency',
    rating: 4.9,
    priceMin: 300.0,
    priceMax: 800.0,
  ),
];
