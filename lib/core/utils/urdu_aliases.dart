/// Roman-Urdu grocery vocabulary (Saad, 2026-07-11): Pakistani users type
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

const Map<String, List<String>> kUrduAliases = {
  // Dairy & Eggs
  'doodh': ['milk'], 'dudh': ['milk'], 'dood': ['milk'],
  'dahi': ['yogurt'], 'dahee': ['yogurt'],
  'anday': ['eggs'], 'anda': ['eggs'], 'ande': ['eggs'], 'andey': ['eggs'],
  'makhan': ['butter'], 'makkhan': ['butter'],
  'malai': ['cream'], 'balai': ['cream'],
  'ghee': ['desi ghee'],
  'khoya': ['cream'],

  // Staples
  'chawal': ['basmati rice'], 'chaawal': ['basmati rice'],
  'chawel': ['basmati rice'], 'chaval': ['basmati rice'],
  'cheeni': ['sugar'], 'chini': ['sugar'], 'khaand': ['sugar'],
  'shakkar': ['brown sugar'], 'shakar': ['brown sugar'],
  'namak': ['salt'],
  'dal': ['daal chana', 'daal masoor', 'daal moong', 'daal mash'],
  'daal': ['daal chana', 'daal masoor', 'daal moong', 'daal mash'],
  'suji': ['sooji'], 'sujee': ['sooji'],
  'sawaiyan': ['vermicelli'], 'sewaiyan': ['vermicelli'],
  'seviyan': ['vermicelli'], 'sawayyan': ['vermicelli'],
  'sewiyan': ['vermicelli'],
  'chane': ['white chickpeas'], 'chanay': ['white chickpeas'],
  'kabuli chanay': ['white chickpeas'],
  'lobia': ['red beans'], 'rajma': ['red beans'],

  // Vegetables
  'aloo': ['potatoes'], 'alu': ['potatoes'], 'aalu': ['potatoes'],
  'pyaz': ['onions'], 'piyaz': ['onions'], 'pyaaz': ['onions'],
  'tamatar': ['tomatoes'], 'timatar': ['tomatoes'],
  'adrak': ['ginger'],
  'lehsun': ['garlic'], 'lahsun': ['garlic'], 'lasan': ['garlic'],
  'hari mirch': ['green chillies'], 'mirchi': ['green chillies'],
  'dhania': ['coriander'], 'dhaniya': ['coriander'],
  'podina': ['mint'], 'pudina': ['mint'],
  'palak': ['spinach'],
  'bhindi': ['okra'],
  'gobi': ['cauliflower'], 'phool gobi': ['cauliflower'],
  'phul gobi': ['cauliflower'],
  'band gobi': ['cabbage'], 'bund gobi': ['cabbage'],
  'gajar': ['carrots'], 'gaajar': ['carrots'],
  'matar': ['peas'], 'mattar': ['peas'],
  'kheera': ['cucumber'], 'khira': ['cucumber'],
  'shimla mirch': ['capsicum'],
  'baingan': ['brinjal'], 'bengan': ['brinjal'], 'baigan': ['brinjal'],
  'karela': ['bitter gourd'], 'karelay': ['bitter gourd'],
  'kaddu': ['pumpkin'],
  'mooli': ['radish'],
  'shaljam': ['turnip'],
  'chukandar': ['beetroot'],

  // Fruit
  'aam': ['mangoes'],
  'kela': ['bananas'], 'kelay': ['bananas'], 'kele': ['bananas'],
  'santra': ['oranges'], 'sangtra': ['oranges'], 'malta': ['oranges'],
  'kinnow': ['oranges'], 'kino': ['oranges'],
  'angoor': ['grapes'], 'angur': ['grapes'],
  'anar': ['pomegranate'], 'anaar': ['pomegranate'],
  'khajoor': ['dates'], 'khajur': ['dates'],
  'seb': ['apples'], 'saib': ['apples'],
  'nimbu': ['lemons'], 'limu': ['lemons'], 'leemu': ['lemons'],

  // Meat & Fish
  'murghi': ['chicken'], 'murgi': ['chicken'],
  'gosht': ['beef', 'mutton'], 'ghosht': ['beef', 'mutton'],
  'bara gosht': ['beef'], 'chota gosht': ['mutton'],
  'bakray ka gosht': ['mutton'],
  'keema': ['qeema'], 'kima': ['qeema'], 'qima': ['qeema'],
  'machli': ['fish'], 'machhli': ['fish'], 'machlee': ['fish'],
  'jhinga': ['prawns'], 'jheenga': ['prawns'], 'jhingay': ['prawns'],

  // Spices & Condiments
  'haldi': ['turmeric powder'],
  'lal mirch': ['red chilli powder'], 'surkh mirch': ['red chilli powder'],
  'zeera': ['cumin'], 'jeera': ['cumin'], 'zira': ['cumin'],
  'kali mirch': ['black pepper'],
  'elaichi': ['cardamom'], 'ilaichi': ['cardamom'],
  'darchini': ['cinnamon'], 'dalchini': ['cinnamon'],
  'laung': ['cloves'], 'loung': ['cloves'], 'long': ['cloves'],
  'tez patta': ['bay leaves'], 'tej patta': ['bay leaves'],
  'imli': ['tamarind'],
  'sirka': ['vinegar'],
  'shehad': ['honey'], 'shehed': ['honey'], 'shahad': ['honey'],
  'gurr': ['gur'],
  'tel': ['cooking oil'], 'sarson ka tel': ['cooking oil'],
  'khana pakane ka tel': ['cooking oil'],

  // Beverages
  'chai': ['tea'], 'chai patti': ['tea'], 'chaey': ['tea'],
  'chae': ['tea'], 'patti': ['tea'],
  'pani': ['mineral water'], 'paani': ['mineral water'],
  'sharbat': ['squash'],

  // Bakery
  'double roti': ['bread'], 'dubble roti': ['bread'],
  'kulcha': ['naan'], 'kulchay': ['naan'],

  // Frozen
  'samosa': ['frozen samosa'], 'samosay': ['frozen samosa'],
  'samosas': ['frozen samosa'],
  'paratha': ['frozen paratha'], 'parathay': ['frozen paratha'],
  'kabab': ['frozen kebab'], 'kebab': ['frozen kebab'],
  'kababs': ['frozen kebab'],

  // Household & personal
  'sabun': ['soap bars'], 'saban': ['soap bars'],
  'surf': ['laundry detergent'],
  'machis': ['matchbox'], 'machiss': ['matchbox'],
  'machar spray': ['mosquito repellent'],
  'machar wala spray': ['mosquito repellent'],
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
