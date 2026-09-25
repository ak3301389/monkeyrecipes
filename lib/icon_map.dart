import 'package:flutter/material.dart';

/// Преобразует название иконки категории (строку) в IconData.
/// Используется во всех экранах, где отображается категория.
IconData categoryIcon(String name) {
  switch (name) {
    case 'restaurant':
      return Icons.restaurant;
    case 'soup_kitchen':
      return Icons.soup_kitchen;
    case 'eco':
      return Icons.eco;
    case 'dinner_dining':
      return Icons.dinner_dining;
    case 'cake':
      return Icons.cake;
    case 'local_cafe':
      return Icons.local_cafe;
    case 'bakery_dining':
      return Icons.bakery_dining;
    case 'rice_bowl':
      return Icons.rice_bowl;
    case 'lunch_dining':
      return Icons.lunch_dining;
    case 'breakfast_dining':
      return Icons.breakfast_dining;
    case 'icecream':
      return Icons.icecream;
    case 'local_pizza':
      return Icons.local_pizza;
    case 'fastfood':
      return Icons.fastfood;
    case 'ramen_dining':
      return Icons.ramen_dining;
    case 'set_meal':
      return Icons.set_meal;
    case 'egg':
      return Icons.egg;
    case 'liquor':
      return Icons.liquor;
    case 'local_bar':
      return Icons.local_bar;
    case 'coffee':
      return Icons.coffee;
    case 'emoji_food_beverage':
      return Icons.emoji_food_beverage;
    default:
      return Icons.restaurant;
  }
}
