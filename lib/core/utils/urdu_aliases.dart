/// Roman-Urdu + brand-generic grocery vocabulary (Saad, 2026-07-11):
/// Pakistani users type
/// "doodh", "cheeni", "sawaiyan" in English letters. Each alias maps
/// spelling variants to canonical seed-catalog entries so autocomplete and
/// auto-categorization understand them. The user's own word stays as the
/// item's display name — the alias only finds the right catalog row.
///
/// Keys are normalized (lowercase, trimmed). Values are seed-catalog
/// `nameNormalized` targets; ambiguous words (gosht, daal, tel) fan out to
/// several. Integrity is enforced by test: every target must exist in
/// kSeedCatalog.
library;

import 'package:tokri/core/db/seed_catalog.dart';
import 'package:tokri/core/utils/item_parser.dart';

const Map<String, List<String>> kUrduAliases = {
  // Dairy & Eggs
  'doodh': ['milk'], 'dudh': ['milk'], 'dood': ['milk'],
  'dhoodh': ['milk'], 'doodh ka packet': ['milk'],
  'dahi': ['yogurt'], 'dahee': ['yogurt'], 'dahi ka dabba': ['yogurt'],
  'anday': ['eggs'], 'anda': ['eggs'], 'ande': ['eggs'], 'andey': ['eggs'],
  'andaa': ['eggs'], 'undey': ['eggs'],
  'makhan': ['butter'], 'makkhan': ['butter'], 'mukhan': ['butter'],
  'malai': ['cream'], 'balai': ['cream'],
  'ghee': ['desi ghee'],
  'banaspati': ['banaspati ghee'], 'dalda': ['banaspati ghee'],
  'vanaspati': ['banaspati ghee'],
  'blue band': ['margarine'], 'blueband': ['margarine'],
  'khoya': ['cream'],
  'doodh powder': ['milk powder'], 'khushk doodh': ['milk powder'],

  // Staples
  'chawal': ['basmati rice'], 'chaawal': ['basmati rice'],
  'chawel': ['basmati rice'], 'chaval': ['basmati rice'],
  'chawl': ['basmati rice'], 'sella chawal': ['basmati rice'],
  'basmati': ['basmati rice'], 'rice': ['basmati rice'],
  'aata': ['atta'], 'ata': ['atta'], 'gandum ka atta': ['atta'],
  'kanak': ['atta'], 'chakki atta': ['atta'],
  'meda': ['maida'],
  'basan': ['besan'],
  'soojee': ['sooji'],
  'daliya': ['dalia'],
  'jai': ['oats'], 'jaee': ['oats'],
  'makai ka atta': ['cornflour'],
  'noodle': ['noodles'],
  'cheeni': ['sugar'], 'chini': ['sugar'], 'khaand': ['sugar'],
  'khand': ['sugar'], 'cheene': ['sugar'],
  'shakkar': ['brown sugar'], 'shakar': ['brown sugar'],
  'namak': ['salt'], 'nimak': ['salt'],
  'dal': ['daal chana', 'daal masoor', 'daal moong', 'daal mash'],
  'daal': ['daal chana', 'daal masoor', 'daal moong', 'daal mash'],
  // Reversed word order — people type "chana daal", the seed says
  // "daal chana", and LIKE can't flip words.
  'chana daal': ['daal chana'], 'chana dal': ['daal chana'],
  'masoor daal': ['daal masoor'], 'masoor dal': ['daal masoor'],
  'moong daal': ['daal moong'], 'moong dal': ['daal moong'],
  'mash daal': ['daal mash'], 'mash dal': ['daal mash'],
  'mash ki daal': ['daal mash'], 'urad daal': ['daal mash'],
  'urad dal': ['daal mash'], 'kali daal': ['daal mash'],
  'chanay ki daal': ['daal chana'], 'daal chanay': ['daal chana'],
  'baisan': ['besan'],
  'suji': ['sooji'], 'sujee': ['sooji'],
  'sawaiyan': ['vermicelli'], 'sewaiyan': ['vermicelli'],
  'seviyan': ['vermicelli'], 'sawayyan': ['vermicelli'],
  'sewiyan': ['vermicelli'],
  'chane': ['white chickpeas'], 'chanay': ['white chickpeas'],
  'kabuli chanay': ['white chickpeas'],
  'lobia': ['red beans'], 'rajma': ['red beans'],

  // Vegetables
  'aloo': ['potatoes'], 'alu': ['potatoes'], 'aalu': ['potatoes'],
  'aaloo': ['potatoes'], 'alloo': ['potatoes'],
  'pyaz': ['onions'], 'piyaz': ['onions'], 'pyaaz': ['onions'],
  'piaz': ['onions'], 'payaz': ['onions'],
  'tamatar': ['tomatoes'], 'timatar': ['tomatoes'],
  'tamater': ['tomatoes'], 'timater': ['tomatoes'],
  'adrak': ['ginger'], 'adrak lehsun': ['ginger', 'garlic'],
  'lehsun': ['garlic'], 'lahsun': ['garlic'], 'lasan': ['garlic'],
  'lehsan': ['garlic'], 'lassan': ['garlic'], 'thoom': ['garlic'],
  'hari mirch': ['green chillies'], 'mirchi': ['green chillies'],
  'hari mirchain': ['green chillies'], 'mirchain': ['green chillies'],
  'sabz mirch': ['green chillies'],
  'dhania': ['coriander'], 'dhaniya': ['coriander'],
  'hara dhania': ['coriander'], 'dhanya': ['coriander'],
  'podina': ['mint'], 'pudina': ['mint'], 'pudeena': ['mint'],
  'podeena': ['mint'],
  'palak': ['spinach'],
  'bhindi': ['okra'],
  'gobi': ['cauliflower'], 'phool gobi': ['cauliflower'],
  'phul gobi': ['cauliflower'], 'gobhi': ['cauliflower'],
  'phool gobhi': ['cauliflower'],
  'band gobi': ['cabbage'], 'bund gobi': ['cabbage'],
  'band gobhi': ['cabbage'], 'patta gobi': ['cabbage'],
  'gajar': ['carrots'], 'gaajar': ['carrots'], 'gajjar': ['carrots'],
  'matar': ['peas'], 'mattar': ['peas'], 'muttar': ['peas'],
  'kheera': ['cucumber'], 'khira': ['cucumber'], 'kheeray': ['cucumber'],
  'shimla mirch': ['capsicum'], 'shimla': ['capsicum'],
  'baingan': ['brinjal'], 'bengan': ['brinjal'], 'baigan': ['brinjal'],
  'baingun': ['brinjal'],
  'karela': ['bitter gourd'], 'karelay': ['bitter gourd'],
  'karele': ['bitter gourd'],
  'kaddu': ['pumpkin'], 'kadu': ['pumpkin'],
  'mooli': ['radish'], 'muli': ['radish'],
  'shaljam': ['turnip'], 'shalgam': ['turnip'],
  'chukandar': ['beetroot'], 'chuqandar': ['beetroot'],
  // Urdu-primary rows, reachable from English too.
  'bottle gourd': ['lauki'], 'ghia': ['lauki'], 'kaddu gol': ['lauki'],
  'loki': ['lauki'], 'louki': ['lauki'],
  'ridge gourd': ['tori'], 'turai': ['tori'], 'torai': ['tori'],
  'taro': ['arvi'], 'arbi': ['arvi'], 'arwi': ['arvi'],
  'fenugreek': ['methi'],
  'sweet potato': ['shakarkandi'], 'shakar kandi': ['shakarkandi'],
  'corn': ['makai'], 'bhutta': ['makai'], 'sweet corn': ['makai'],
  'makkai': ['makai'], 'challi': ['makai'], 'chhalli': ['makai'],
  'salad patta': ['lettuce'], 'salad': ['lettuce'],
  'sag': ['saag'], 'sarson ka saag': ['saag'],
  'hara pyaz': ['spring onion'], 'haray pyaz': ['spring onion'],
  'khumbi': ['mushrooms'], 'mushroom': ['mushrooms'],
  'phaliyan': ['french beans'], 'phalliyan': ['french beans'],
  'beans': ['french beans'],
  'tinda': ['tinday'], 'tinde': ['tinday'],

  // Fruit
  'aam': ['mangoes'], 'amb': ['mangoes'],
  'kela': ['bananas'], 'kelay': ['bananas'], 'kele': ['bananas'],
  'kaila': ['bananas'], 'kailay': ['bananas'],
  'santra': ['oranges'], 'sangtra': ['oranges'], 'malta': ['oranges'],
  'kinnow': ['oranges'], 'kino': ['oranges'], 'kinu': ['oranges'],
  'santara': ['oranges'], 'sangtara': ['oranges'],
  'angoor': ['grapes'], 'angur': ['grapes'], 'angoors': ['grapes'],
  'anar': ['pomegranate'], 'anaar': ['pomegranate'],
  'khajoor': ['dates'], 'khajur': ['dates'], 'chuhara': ['dates'],
  'khajooren': ['dates'],
  'seb': ['apples'], 'saib': ['apples'], 'sev': ['apples'],
  'nimbu': ['lemons'], 'limu': ['lemons'], 'leemu': ['lemons'],
  'limoo': ['lemons'], 'lemo': ['lemons'],
  'guava': ['amrood'], 'amrud': ['amrood'],
  'watermelon': ['tarbooz'], 'tarbuz': ['tarbooz'],
  'melon': ['kharbooza'], 'garma': ['kharbooza'],
  'kharbuza': ['kharbooza'],
  'pear': ['nashpati'], 'naspati': ['nashpati'],
  'papaya': ['papita'],
  'strawberry': ['strawberries'],
  'cheeku': ['chikoo'], 'chiku': ['chikoo'],
  'peach': ['aaru'], 'aru': ['aaru'],
  'apricot': ['khubani'], 'khobani': ['khubani'],
  'plum': ['aloocha'], 'alucha': ['aloocha'], 'aloo bukhara fresh': ['aloocha'],
  'jamun': ['jaman'],
  'lichi': ['lychee'], 'litchi': ['lychee'],
  'coconut': ['nariyal'], 'narial': ['nariyal'], 'khopa': ['nariyal'],

  // Meat & Fish
  'murghi': ['chicken'], 'murgi': ['chicken'], 'murgh': ['chicken'],
  'broiler': ['chicken'], 'desi murghi': ['chicken'],
  'murghi ka gosht': ['chicken'], 'chicken gosht': ['chicken'],
  'gosht': ['beef', 'mutton'], 'ghosht': ['beef', 'mutton'],
  'bara gosht': ['beef'], 'chota gosht': ['mutton'],
  'bakray ka gosht': ['mutton'], 'bakra': ['mutton'],
  'gaye ka gosht': ['beef'],
  'keema': ['qeema'], 'kima': ['qeema'], 'qima': ['qeema'],
  'qeemah': ['qeema'], 'keyma': ['qeema'],
  'machli': ['fish'], 'machhli': ['fish'], 'machlee': ['fish'],
  'machi': ['fish'],
  'jhinga': ['prawns'], 'jheenga': ['prawns'], 'jhingay': ['prawns'],
  'kalejee': ['kaleji'], 'kalayji': ['kaleji'], 'liver': ['kaleji'],

  // Spices & Condiments
  'haldi': ['turmeric powder'], 'huldi': ['turmeric powder'],
  'lal mirch': ['red chilli powder'], 'surkh mirch': ['red chilli powder'],
  'pisi mirch': ['red chilli powder'], 'kuti mirch': ['red chilli powder'],
  'pisi lal mirch': ['red chilli powder'],
  'zeera': ['cumin'], 'jeera': ['cumin'], 'zira': ['cumin'],
  'zeerah': ['cumin'], 'safed zeera': ['cumin'],
  'kali mirch': ['black pepper'], 'kaali mirch': ['black pepper'],
  'elaichi': ['cardamom'], 'ilaichi': ['cardamom'],
  'elachi': ['cardamom'], 'ilachi': ['cardamom'],
  'darchini': ['cinnamon'], 'dalchini': ['cinnamon'],
  'dar cheeni': ['cinnamon'],
  'laung': ['cloves'], 'loung': ['cloves'], 'long': ['cloves'],
  'tez patta': ['bay leaves'], 'tej patta': ['bay leaves'],
  'imli': ['tamarind'], 'imlee': ['tamarind'],
  'sirka': ['vinegar'], 'sirkah': ['vinegar'],
  'garm masala': ['garam masala'],
  'chat masala': ['chaat masala'],
  'sabut dhania': ['coriander powder'],
  'ajwaain': ['ajwain'],
  'kalongi': ['kalonji'], 'kalwanji': ['kalonji'],
  'zaitoon ka tel': ['olive oil'], 'zaitoon': ['olive oil'],
  'masala': ['garam masala'], 'masalay': ['garam masala'],
  'masale': ['garam masala'], 'masala jat': ['garam masala'],
  'chatni': ['chutney'], 'chutni': ['chutney'],
  'hari chatni': ['chutney'], 'imli ki chatni': ['chutney'],
  'podinay ki chatni': ['chutney'],
  'sesame seeds': ['til'], 'sesame': ['til'],
  'desiccated coconut': ['khopra'],
  'dried plums': ['aloo bukhara'],
  'knorr cube': ['chicken cubes'], 'yakhni cube': ['chicken cubes'],
  'knorr': ['chicken cubes'], 'stock cube': ['chicken cubes'],
  'adrak lehsun paste': ['ginger garlic paste'],
  'lehsun adrak paste': ['ginger garlic paste'],
  'shehad': ['honey'], 'shehed': ['honey'], 'shahad': ['honey'],
  'gurr': ['gur'],
  'badam': ['almonds'],
  'kaju': ['cashews'],
  'kishmish': ['raisins'],
  'moongphali': ['peanuts'], 'mumphali': ['peanuts'],
  'moong phali': ['peanuts'],
  'akhrot': ['walnuts'],
  'pista': ['pistachios'],
  'sonf': ['saunf'],
  'tel': ['cooking oil'], 'sarson ka tel': ['cooking oil'],
  'khana pakane ka tel': ['cooking oil'],

  // Beverages
  'chai': ['tea'], 'chai patti': ['tea'], 'chaey': ['tea'],
  'chae': ['tea'], 'patti': ['tea'], 'chai ki patti': ['tea'],
  'chaye': ['tea'], 'cha': ['tea'],
  'kafi': ['coffee'], 'kaafi': ['coffee'],
  'pani': ['mineral water'], 'paani': ['mineral water'],
  'pani ki botal': ['mineral water'],
  'sharbat': ['squash'],
  'cold drink': ['soft drink'], 'colddrink': ['soft drink'],
  'botal': ['soft drink'],
  'roohafza': ['rooh afza'],
  'sting': ['energy drink'], 'red bull': ['energy drink'],
  'tang': ['powdered drink mix'], 'energile': ['powdered drink mix'],

  // Bakery
  'double roti': ['bread'], 'dubble roti': ['bread'],
  'dabal roti': ['bread'],
  'kulcha': ['naan'], 'kulchay': ['naan'], 'nan': ['naan'],
  'bun': ['buns'],
  'papay': ['rusk'], 'paapay': ['rusk'],
  'biscuit': ['biscuits'], 'bisket': ['biscuits'],
  'biskut': ['biscuits'],
  'chaklet': ['chocolate'],
  'papad': ['papar'],
  'toffee': ['candy'], 'toffiyan': ['candy'], 'tofiyan': ['candy'],
  'mithai': ['candy'],
  'patties': ['chicken patties'], 'pattice': ['chicken patties'],
  'pastry': ['pastries'],
  'pita': ['pita bread'], 'shawarma bread': ['pita bread'],

  // Frozen
  'samosa': ['frozen samosa'], 'samosay': ['frozen samosa'],
  'samosas': ['frozen samosa'], 'samose': ['frozen samosa'],
  'paratha': ['frozen paratha'], 'parathay': ['frozen paratha'],
  'parathe': ['frozen paratha'],
  'kabab': ['frozen kebab'], 'kebab': ['frozen kebab'],
  'kababs': ['frozen kebab'], 'shami kabab': ['frozen kebab'],
  'kabaab': ['frozen kebab'],
  'nuggets': ['chicken nuggets'],
  'fries': ['french fries'], 'finger chips': ['french fries'],
  'spring roll': ['spring rolls'], 'rolls': ['spring rolls'],

  // Household & personal
  'sabun': ['soap bars'], 'saban': ['soap bars'],
  'sabun ki tikki': ['soap bars'], 'nahanay wala sabun': ['soap bars'],
  'surf': ['laundry detergent'], 'washing powder': ['laundry detergent'],
  'kapray dhonay wala surf': ['laundry detergent'],
  'machis': ['matchbox'], 'machiss': ['matchbox'],
  'maachis': ['matchbox'],
  'machar spray': ['mosquito repellent'],
  'machar wala spray': ['mosquito repellent'],
  'mortein': ['mosquito repellent'],
  'broom': ['jharoo'], 'jhadu': ['jharoo'], 'jharu': ['jharoo'],
  'pocha': ['mop'],
  'phenyl': ['floor cleaner'], 'fenyl': ['floor cleaner'],
  'harpic': ['toilet cleaner'],
  'vim': ['dishwashing liquid'],
  'bulb': ['light bulb'],
  'battery': ['batteries'], 'cell': ['batteries'],
  'tissue': ['tissues'], 'tissue paper': ['tissues'],
  'dettol': ['antiseptic liquid'],
  'shempo': ['shampoo'], 'shampu': ['shampoo'],
  'colgate': ['toothpaste'], 'manjan': ['toothpaste'],
  'brush': ['toothbrush'], 'danton ka brush': ['toothbrush'],
  'kanghi': ['comb'], 'kangi': ['comb'],
  'balon ka tel': ['hair oil'],
  'pads': ['sanitary pads'],
  'pampers': ['diapers'], 'diaper': ['diapers'],
  'cerelac': ['baby cereal'],
  'chusni': ['soother'], 'nipple': ['soother'],
  'panadol': ['paracetamol'], 'pain killer': ['paracetamol'],
  'bukhar ki dawa': ['paracetamol'],
  'brufen': ['ibuprofen'],
  'disprin': ['aspirin'],
  'eno': ['antacid'], 'gas ki dawa': ['antacid'],
  'khansi ka syrup': ['cough syrup'], 'khansi ki dawa': ['cough syrup'],
  'strepsils': ['lozenges'],
  'vicks': ['balm'], 'tiger balm': ['balm'], 'iodex': ['balm'],
  'glucose': ['glucose powder'], 'glucose d': ['glucose powder'],
  'mask': ['face masks'], 'masks': ['face masks'],
  'sanitizer': ['hand sanitizer'], 'hath dhone wala': ['hand sanitizer'],
  'vaseline': ['petroleum jelly'],
  'powder': ['talcum powder'],
  'henna': ['mehndi'], 'mehendi': ['mehndi'],
  'mombatti': ['candles'], 'mombattiyan': ['candles'],
  'candle': ['candles'],
  'balti': ['bucket'],
  'joona': ['scrubber'], 'juna': ['scrubber'],
  'chimti': ['clothes pegs'], 'chimtiyan': ['clothes pegs'],
  'kapray latkane wali chimti': ['clothes pegs'],
  'phenyl ki goliyan': ['naphthalene balls'],
};

/// Canonical seed names for a normalized word; empty when unknown.
List<String> canonicalsFor(String normalized) =>
    kUrduAliases[normalized] ?? const [];

/// Canonicals for any alias the typed [prefix] could be starting — this is
/// what lets "sawai" already suggest Vermicelli. Two characters minimum so
/// single letters don't drag in half the map.
Set<String> aliasCanonicalsForPrefix(String prefix) {
  if (prefix.length < 2) return const {};
  return {
    for (final entry in kUrduAliases.entries)
      if (entry.key.startsWith(prefix)) ...entry.value,
  };
}

/// One preferred Roman-Urdu label per canonical seed row, shown next to the
/// English name on suggestion chips ("Milk · Doodh") so someone who only
/// knows the Urdu word understands what they're picking (Saad, 2026-07-11).
/// Only rows whose common Urdu name differs meaningfully get an entry —
/// Urdu-primary rows (Lauki, Amrood, Kaleji…) already read right.
/// Integrity is test-enforced against the seed catalog.
const Map<String, String> kUrduDisplayNames = {
  // Dairy & Eggs
  'milk': 'Doodh', 'eggs': 'Anday', 'yogurt': 'Dahi', 'butter': 'Makhan',
  'cream': 'Malai', 'margarine': 'Blue Band', 'milk powder': 'Khushk doodh',
  // Staples & grains
  'basmati rice': 'Chawal', 'sugar': 'Cheeni', 'brown sugar': 'Shakkar',
  'salt': 'Namak', 'vermicelli': 'Sawaiyan',
  'white chickpeas': 'Kabuli chanay', 'red beans': 'Lobia',
  'oats': 'Jai', 'cornflour': 'Makai ka atta',
  // Vegetables
  'potatoes': 'Aloo', 'onions': 'Pyaz', 'tomatoes': 'Tamatar',
  'ginger': 'Adrak', 'garlic': 'Lehsun', 'green chillies': 'Hari mirch',
  'coriander': 'Dhania', 'mint': 'Podina', 'spinach': 'Palak',
  'okra': 'Bhindi', 'cauliflower': 'Phool gobi', 'cabbage': 'Band gobi',
  'carrots': 'Gajar', 'peas': 'Matar', 'cucumber': 'Kheera',
  'capsicum': 'Shimla mirch', 'brinjal': 'Baingan',
  'bitter gourd': 'Karela', 'pumpkin': 'Kaddu', 'radish': 'Mooli',
  'turnip': 'Shaljam', 'beetroot': 'Chukandar',
  'spring onion': 'Hara pyaz', 'mushrooms': 'Khumbi',
  'french beans': 'Phaliyan', 'lettuce': 'Salad patta',
  // Fruit
  'mangoes': 'Aam', 'bananas': 'Kelay', 'oranges': 'Santray',
  'grapes': 'Angoor', 'pomegranate': 'Anar', 'dates': 'Khajoor',
  'apples': 'Seb', 'lemons': 'Nimbu', 'lychee': 'Lichi',
  // Meat & Fish
  'chicken': 'Murghi', 'beef': 'Bara gosht', 'mutton': 'Chota gosht',
  'fish': 'Machli', 'prawns': 'Jhinga',
  // Spices & Condiments
  'turmeric powder': 'Haldi', 'red chilli powder': 'Lal mirch',
  'cumin': 'Zeera', 'black pepper': 'Kali mirch', 'cardamom': 'Elaichi',
  'cinnamon': 'Darchini', 'cloves': 'Laung', 'bay leaves': 'Tez patta',
  'tamarind': 'Imli', 'vinegar': 'Sirka', 'honey': 'Shehad',
  'cooking oil': 'Tel', 'olive oil': 'Zaitoon ka tel',
  'chicken cubes': 'Yakhni cube',
  'coriander powder': 'Dhania powder',
  // Snacks & dry fruit
  'almonds': 'Badam', 'cashews': 'Kaju', 'raisins': 'Kishmish',
  'peanuts': 'Moongphali', 'walnuts': 'Akhrot', 'pistachios': 'Pista',
  'candy': 'Toffiyan',
  // Beverages
  'tea': 'Chai', 'mineral water': 'Pani', 'soft drink': 'Cold drink',
  'powdered drink mix': 'Tang',
  // Bakery & frozen
  'bread': 'Double roti', 'frozen samosa': 'Samosay',
  'frozen paratha': 'Parathay', 'frozen kebab': 'Kabab',
  // Household
  'soap bars': 'Sabun', 'laundry detergent': 'Surf',
  'matchbox': 'Machis', 'candles': 'Mombatti', 'bucket': 'Balti',
  'mop': 'Pocha', 'clothes pegs': 'Chimtiyan',
  'scrubber': 'Joona', 'floor cleaner': 'Phenyl',
  'toilet cleaner': 'Harpic', 'dishwashing liquid': 'Vim',
  'antiseptic liquid': 'Dettol', 'mosquito repellent': 'Machar spray',
  // Personal care & baby
  'comb': 'Kanghi', 'petroleum jelly': 'Vaseline',
  'hair oil': 'Balon ka tel', 'diapers': 'Pampers',
  'baby cereal': 'Cerelac', 'soother': 'Chusni',
  // Pharmacy
  'paracetamol': 'Panadol', 'ibuprofen': 'Brufen', 'aspirin': 'Disprin',
  'antacid': 'ENO', 'lozenges': 'Strepsils', 'balm': 'Vicks',
  'cough syrup': 'Khansi ka syrup', 'glucose powder': 'Glucose-D',
  'hand sanitizer': 'Sanitizer',
};

/// Roman-Urdu label for a canonical row, or null when the English name is
/// what everyone says anyway.
String? urduLabelFor(String nameNormalized) =>
    kUrduDisplayNames[nameNormalized];

/// Seed display names by normalized name, for alias → English lookups.
final Map<String, String> _seedDisplayByNormalized = {
  for (final entry in kSeedCatalog) normalizeItemName(entry.name): entry.name,
};

/// The "other language" label for a list item (Saad, 2026-07-11): an item
/// named in English gets its Roman-Urdu name ("Milk" → "Doodh"); an item
/// the user typed in Urdu gets the English seed name ("doodh" → "Milk").
/// Null when there's nothing meaningfully different to show.
String? counterpartLabel(String nameNormalized) {
  final urdu = kUrduDisplayNames[nameNormalized];
  if (urdu != null) return urdu;
  final canonicals = canonicalsFor(nameNormalized);
  if (canonicals.isEmpty) return null;
  return _seedDisplayByNormalized[canonicals.first];
}
