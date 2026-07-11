import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Icon names offered for lists.
const kListIcons = <String>[
  'shopping-basket',
  'shopping-cart',
  'apple',
  'carrot',
  'milk',
  'beef',
  'croissant',
  'cookie',
  'cup-soda',
  'pill',
  'wrench',
  'party-popper',
  'gift',
  'baby',
  'dog',
  'shirt',
  'book-open',
  'plane',
];

/// String → IconData for everything stored in the DB (list icons, category
/// icons). Unknown names fall back to the basket so old data never crashes
/// a build after an icon rename.
IconData resolveIcon(String name) => _icons[name] ?? LucideIcons.shoppingBasket;

const _icons = <String, IconData>{
  'shopping-basket': LucideIcons.shoppingBasket,
  'shopping-cart': LucideIcons.shoppingCart,
  'apple': LucideIcons.apple,
  'carrot': LucideIcons.carrot,
  'milk': LucideIcons.milk,
  'beef': LucideIcons.beef,
  'croissant': LucideIcons.croissant,
  'wheat': LucideIcons.wheat,
  'flame': LucideIcons.flame,
  'cookie': LucideIcons.cookie,
  'cup-soda': LucideIcons.cupSoda,
  'snowflake': LucideIcons.snowflake,
  'spray-can': LucideIcons.sprayCan,
  'sparkles': LucideIcons.sparkles,
  'baby': LucideIcons.baby,
  'pill': LucideIcons.pill,
  'wrench': LucideIcons.wrench,
  'party-popper': LucideIcons.partyPopper,
  'gift': LucideIcons.gift,
  'dog': LucideIcons.dog,
  'shirt': LucideIcons.shirt,
  'book-open': LucideIcons.bookOpen,
  'plane': LucideIcons.plane,
};
