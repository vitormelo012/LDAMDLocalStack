import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final Color color;
  final IconData icon;

  const Category({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'colorValue': color.value,
      'iconCodePoint': icon.codePoint,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      color: Color(map['colorValue']),
      icon: IconData(map['iconCodePoint'], fontFamily: 'MaterialIcons'),
    );
  }
}

// Categorias predefinidas
class Categories {
  static const work = Category(
    id: 'work',
    name: 'Trabalho',
    color: Colors.blue,
    icon: Icons.work,
  );

  static const personal = Category(
    id: 'personal',
    name: 'Pessoal',
    color: Colors.green,
    icon: Icons.person,
  );

  static const shopping = Category(
    id: 'shopping',
    name: 'Compras',
    color: Colors.orange,
    icon: Icons.shopping_cart,
  );

  static const health = Category(
    id: 'health',
    name: 'Saúde',
    color: Colors.red,
    icon: Icons.favorite,
  );

  static const study = Category(
    id: 'study',
    name: 'Estudos',
    color: Colors.purple,
    icon: Icons.school,
  );

  static const home = Category(
    id: 'home',
    name: 'Casa',
    color: Colors.brown,
    icon: Icons.home,
  );

  static const finance = Category(
    id: 'finance',
    name: 'Finanças',
    color: Colors.teal,
    icon: Icons.attach_money,
  );

  static const other = Category(
    id: 'other',
    name: 'Outros',
    color: Colors.grey,
    icon: Icons.more_horiz,
  );

  static List<Category> get all => [
        work,
        personal,
        shopping,
        health,
        study,
        home,
        finance,
        other,
      ];

  static Category getById(String id) {
    return all.firstWhere(
      (category) => category.id == id,
      orElse: () => other,
    );
  }
}
