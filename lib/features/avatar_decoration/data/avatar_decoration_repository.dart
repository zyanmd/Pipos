import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import 'models/avatar_decoration_model.dart';

class AvatarDecorationRepository {
  AvatarDecorationRepository._();
  static final AvatarDecorationRepository instance = AvatarDecorationRepository._();

  static const String _prefActiveKey = 'active_avatar_decoration';

  /// Complete built-in catalog of Discord-style avatar decorations
  static const Map<String, List<String>> defaultCatalog = {
    'general': [
      'im_a_clown', 'mokoko', 'sakura_gyoiko', 'warp_helmet',
      'victory_crown', 'freezer_bunny_lovebug', 'wingman_boba',
      'los_santos', 'hailey', 'bunny', 'torgal_puppy',
      'street_fighter_6_battle_field', 'wolf_morph', 'wallach_spaceport',
      'batarang', 'rift_butterfly', 'bush_camper', 'shield_potion',
      'tga_controller', 'shadow', 'new_year_2025', 'santa_cat_ears',
      'snowfall', 'rec_room_lightning', 'wingmans_got_it',
      'jeff_the_land_shark', 'fuchsia_agent', 'heart_to_heart',
    ],
    'seasonal': [
      'trick_pumpkin', 'treat_pumpkin', 'trick_spider', 'treat_spider',
      'trick_skull', 'treat_skull', 'trick_ghost', 'treat_ghost',
      'heart_to_heart', 'santa_cat_ears', 'daredevil', 'lover_girl_autumn',
      'autumn_foliage', 'moomoo_hood', 'valorant_summer_kickoff', 'i_love_repo',
      'freezer_bunny_lovebug', 'disxcore_headset', 'pink_headset', 'green_headset',
      'blue_futuristic_ui', 'pink_futuristic_ui', 'green_futuristic_ui',
      'blue_smoke', 'pink_smoke', 'green_smoke', 'blue_gyroscope', 'pink_gyroscope',
      'green_gyroscope', 'blue_shine_helmet', 'pink_shine_helmet', 'green_shine_helmet',
      'blue_hyper_helmet', 'pink_hyper_helmet', 'green_hyper_helmet', 'saw',
      'sakura', 'sakura_pink', 'sakura_ukon', 'sakura_gyoiko',
      'mushroom_1', 'mushroom_2', 'mushroom_3', 'mushroom_4', 'forest',
      'frog_1', 'frog_derpy', 'frog_3', 'frog_angry',
      'cat_1', 'cat_2', 'cat_3', 'cat_4',
      'dog_1', 'dog_2', 'dog_3',
      'blanket_green', 'blanket_orange', 'blanket_pink', 'blanket_purple',
      'box_white_blue', 'box_blue_yellow', 'box_green_red', 'box_red_white',
      'box_red_white_blue', 'confetti_festive', 'confetti_fire', 'confetti_ice',
      'confetti_mint', 'confetti_star', 'confetti_vaporwave', 'ice_cube',
      'icicle_gleaming', 'icicle_snowing', 'teacup_blue', 'teacup_orange',
      'teacup_pink', 'teacup_red', 'lunar_flowers', 'starlight_tiara',
      'astral_aura', 'luna_moths', 'moonlit_charms', 'liquid_moon',
      'neon_cat_hoodie', 'neon_cat_hoodie_blue', 'neon_cat_hoodie_pink',
      'neon_cat_hoodie_black', 'mischievous_kitties_hearts', 'mister_fantastic',
      'the_fantastic_four', 'spirit_blossom_springs_sett', 'spirit_blossom_springs',
      'spirit_blossom_springs_ahri', 'aespa_fanlight', 'shy_in_love',
      'in_love', 'in_love_blue', 'in_love_green', 'heartbloom',
      'heartbloom_purple', 'heartbloom_blue', 'heartbloom_yellow', 'heartbloom_green',
      'rose_bearer_pink', 'rose_bearer_blue', 'angel', 'devil',
      'aim_for_love', 'lovestruck', 'ring_of_roses_red', 'ring_of_roses_blue',
      'heartstrings_red', 'heartstrings_blue', 'ruby_hearts', 'snakes_hug',
      'lotus_flower', 'red_lantern', 'fan_flourish', 'lunar_lanterns',
      'firecrackers', 'dragons_smile', 'lucky_envelopes', 'koi_pond',
      'aurora', 'polar_bear_hat', 'string_lights', 'string_lights_aurora',
      'string_lights_ember', 'string_lights_dusk', 'string_lights_mix',
      'snowglobe', 'snowglobe_wood', 'snowglobe_pink', 'snowglobe_blue',
      'snowglobe_green', 'fresh_pine', 'fresh_pine_cinnamon', 'fresh_pine_ribbon',
      'spooky_cat_ears', 'spooky_cat_ears_midnight', 'candlelight',
      'candlelight_crimson', 'candlelight_dark', 'hood_dark', 'hood_crimson',
      'witch_hat_plum', 'witch_hat_midnight', 'zombie_food', 'zombie_food_purple',
      'bloodthirsty', 'bloodthirsty_green', 'bloodthirsty_gold',
      'chrysanthemums_twilight', 'chrysanthemums_morning', 'dusk_and_dawn',
      'floral_harmony', 'floral_harmony_sunburst', 'autumns_arbor',
      'autumns_arbor_aurora', 'autumn_crown', 'faces_of_the_moon', 'fox_hat',
      'fox_hat_chestnut', 'fox_hat_snow', 'fall_leaves', 'fall_leaves_scarlet',
      'fall_leaves_woodland', 'a_hint_of_clove', 'honeyblossom', 'dandelion_duo',
      'hugh_the_rainbow', 'strawberry_vine', 'butterflies', 'the_petal_pack',
      'new_year_2024', 'new_year_2025', 'graveyard_cat', 'ghosts', 'minions',
      'jack_o_lantern', 'pumpkin_spice', 'frog_hat',
    ],
    'emoji': [
      'cat_ears', 'ki_energy', 'heartbloom', 'dismay', 'rage',
      'in_tears', 'radiating_energy', 'soul_leaving_body', 'sweat_drops',
      'starry_eyed', 'in_love', 'shocked', 'angry',
    ],
    'gaming': [
      'lego_fortnite', 'fortnite_galactic_battle', 'fortnite_boogie_bomb',
      'street_fighter_6_battle_field', 'victory_crown', 'white_mana',
      'blue_mana', 'black_mana', 'red_mana', 'green_mana', 'ggez',
      'gold_laurel_wreath', 'golden_hex', 'terrain_tiles', 'hex_tiles',
      'city_walls', 'next_turn_button', 'the_anomaly', 'the_mark',
      'the_monster_you_created', 'the_atlas_gauntlets', 'flame_chompers',
      'fishbones', 'the_hexcore', 'powered_by_shimmer', 'dice_violet',
      'dice_azure', 'gelatinous_cube_green', 'gelatinous_cube_blue',
      'owlbear_cub', 'owlbear_cub_snowy', 'baby_displacer_beast', 'ryu',
      'chun_li', 'ken', 'akuma', 'cammy', 'guile', 'juri', 'm_bison',
      'kabuto', 'oni_mask', 'straw_hat', 'sakura_ink', 'sakura_warrior',
      'shurikens_mask', 'valorant_champions_2024', 'yoru_dimensional_drift',
      'viper_poison_cloud', 'cypher_neural_theft', 'omens_cowl', 'reynas_leer',
      'frag_out', 'blade_storm', 'chillet', 'pal_sphere', 'cattiva',
      'lamball', 'depresso', 'selyne', 'joystick', 'clyde_invaders',
      'pipedream', 'hot_shot', 'mallow_jump', 'slither_n_snack',
      'pirate_captain', 'scallywag', 'good_ol_pepper', 'crossbones',
      'cannon_fire', 'helmsman',
    ],
    'anime': [
      'marvel_snap_venom', 'dragon_balls', 'port_of_soul', 'mirage',
      'mirage_void', 'mirage_twilight', 'mirage_nightshade', 'cat_onesie',
      'cat_onesie_pink', 'cat_onesie_black', 'shy', 'rumbling', 'magical_girl',
      'sakura_scholar', 'sushi_roll', 'ramen_bowl', 'ramen_bowl_toppings',
      'angry', 'angry_pink', 'angry_yellow', 'radiating_energy',
      'radiating_energy_yellow', 'radiating_energy_blue', 'sweat_drops',
      'sweat_drops_cyan', 'sweat_drops_pink', 'soul_leaving_body',
      'soul_leaving_body_blue', 'starry_eyed', 'starry_eyed_green',
      'starry_eyed_pink', 'shocked', 'shocked_green', 'shocked_yellow',
      'ki_energy', 'ki_energy_green', 'ki_energy_cyan', 'ki_energy_blue',
      'ki_energy_fuchsia', 'dismay', 'dismay_purple', 'dismay_pink',
      'dismay_yellow', 'dismay_green', 'in_tears', 'in_tears_purple',
      'in_tears_pink', 'in_tears_yellow', 'in_tears_green', 'cat_ears',
      'cat_ears_yellow', 'cat_ears_green', 'cat_ears_blue', 'cat_ears_purple',
      'rage', 'rage_green', 'rage_blue', 'rage_purple', 'rage_red',
      'lofi_girl_outfit', 'sleepy_chilledcow', 'spongebob', 'imagination',
      'patrick_star', 'flower_clouds', 'gary_the_snail', 'sandy_cheeks',
      'musclebob', 'arcane_sigil', 'beamchop', 'stinkums', 'chuck', 'winkle',
      'chewbert', 'doodlezard', 'glop', 'gawblehop',
    ],
    'characters': [
      'mushcaps', 'mooncaps_pink', 'mooncaps_blue', 'goblin_stinkums',
    ],
    'fantasy': [
      'kitsune', 'unicorn', 'phoenix', 'dancing_fairies',
      'crystal_elk', 'mermaid_serenade',
      'angela_avatar', 'jean_grey_phoenix', 'how_to_train_your_dragon',
      'pondering_portal', 'magic_mists', 'spirit_blossom_zed',
      'spirit_blossom_morgana', 'spirit_blossom_karma', 'bonsai',
      'sakura_city', 'hologram_dragon', 'cyber_katana', 'o_n_i', 'jingasa',
      'magic_portal_purple', 'magic_portal_blue', 'fairy_sprites_pink',
      'fairy_sprites_blue', 'crystal_ball_purple', 'crystal_ball_blue',
      'wizard_hat_purple', 'wizard_hat_blue', 'magical_wand_purple',
      'magical_wand_green', 'cottage_home', 'flaming_sword', 'magical_potion',
      'wizards_staff', 'glowing_runes', 'defensive_shield', 'skull_medallion',
      'treasure_and_key', 'midnight_sorceress', 'malefic_crown',
      'deaths_edge', 'spirit_embers', 'eldritch_ring', 'fire', 'water', 'air',
      'earth', 'lightning', 'balance',
    ],
    'scifi': [
      'dream_dive_stars', 'mecha_break', 'starlight_revolver',
      'wallach_spaceport', 'cameraman_glitch', 'space_battle',
      'starlight_whales', 'steampunk_cat_ears', 'mech_flora', 'bowler_hat',
      'brass_beats', 'timekeepers_clock', 'flux_alchemy', 'stardust',
      'black_hole', 'constellations', 'solar_orbit', 'ufo',
      'astronaut_helmet', 'glitch', 'cybernetic', 'digital_sunrise',
    ],
    'event': [],
    'animals': [
      'champions_tactibear', 'tactibear_flex', 'inzoi_psycat', 'cow_glider',
      'jeff_the_land_shark', 'rift_butterfly', 'wolf_morph', 'bunny',
      'greenhouse_cat', 'a_duck', 'gone_fishin', 'sleepy_bee', 'baker_bear',
      'berry_bunny', 'mochi_bunny_pink', 'mochi_bunny_blue', 'donut_cow',
      'donut_cat', 'donut_bear', 'bread_doggy', 'ice_cream_frog',
      'jelly_bear', 'chicken_nugget', 'playful_lofi_cat', 'cat_ear_headset',
      'bunny_zzzs', 'cozy_cat',
    ],
    'nature': [
      'forest_frolic', 'blossomburst', 'sunflowers', 'head_in_the_clouds',
      'head_in_the_clouds_sunset', 'sproutling', 'bloomling', 'implant',
    ],
    'food': [
      'lights_camera_action_teal', 'egg', 'bubble_tea', 'fried_egg',
      'green_fried_egg', 'morning_coffee', 'toast', 'burnt_toast',
      'blueberry_jam', 'donut', 'pancakes',
    ],
    'aesthetic': [
      'jet_ring', 'freshly_picked', 'shower_stroll', 'hoppy_day',
      'afternoon_breeze', 'snowfall', 'the_final_peel', 'warframe_clem',
      'dart_monkey', 'kom', 'mr_m', 'fc_26_icon', 'skate',
      'airona_fireworks', 'travel_ring', 'a_real_fungi', 'cab_monster',
      'black_phone_2', 'cosy_deer', 'atsus_mask', 'lights_camera_action_orange',
      'hoppy_boi', 'echo_4', 'nba_2k26', 'the_conjuring_last_rites',
      'eye_of_prophesy', 'espn', 'wendys_x_wednesday', 'bf_soldier_helmet',
      'bing_bong', 'hank_hill', 'the_entity', 'descendant', 'sweet_tooth',
      'chomp_chomp', 'call_of_duty_mobile', 'thps_half_pipe', 'palia',
      'supercell', 'm3gan_2_0', '28_years_later', 'r6_siege_x_avatar',
      'towerborne_play', 'ballerina', 'ultron', 'open_beta',
      'jurassic_world_rebirth', 'mission_impossible', 'bad_guys_2',
      'shield_saw', 'friend_of_dex', 'hackclaw', 'slurp_barrel',
      'signal_from_tau_ceti', 'emma_frost', 'face_of_corruption',
      'clicker', 'touch_grass', 'supply_llama', 'gallica', 'khazan',
      'split', 'pathojen', 'big_dill_chain', 'exoborne', 'scout',
      'fuchsia_agent', 'wingmans_got_it', 'rec_room_lightning', 'shadow',
      'tga_controller', 'shield_potion', 'bush_camper', 'batarang',
      'torgal_puppy', 'hailey', 'los_santos', 'wingman_boba', 'warp_helmet',
      'mokoko', 'im_a_clown', 'infinite_swirl', 'im_dancin', 'finger_gun',
      'bandit_mask', 'mad_moxxi', 'elpis', 'loot_lightshow', 'terrarium',
      'rainy_canopy', 'snowdrops', 'neon_decora_hair', 'neon_spike_choker',
      'neon_spike_choker_black', 'mischievous_kitties',
      'mischievous_kitties_blue', 'skully_charms', 'rawr_xd', 'gomah',
      'shenron', 'mini_goku', 'mini_vegeta', 'glorio', 'mini_supreme_kai',
      'mini_piccolo', 'panzy', 'the_thing', 'invisible_woman', 'human_torch',
      'silver_surfer', 'yunara', 'speakerwoman', 'tv_woman', 'g_toilet',
      'juggernaut_astro', 'skibidi_toilet', 'sippy_juice', 'beach_hat',
      'bubble', 'fireflies', 'izuku_midoriya', 'katsuki_bakugo',
      'ochaco_uraraka', 'shoto_todoroki', 'endeavor', 'hawks', 'all_might',
      'tomura_shigaraki', 'dewdrop', 'happy_harvest', 'shroomling',
      'shroomling_brown', 'shroomling_blue', 'shroomling_purple',
      'shroomling_pink', 'hammy', 'hammy_blue', 'hammy_pink', 'hammy_green',
      'lightsabers_blue_and_red', 'lightsabers_green_and_red',
      'r2_d2_on_tatooine', 'curious_bb_8', 'yoda_on_dagobah',
      'millennium_falcon_hyperdrive', 'copium', 'trash', 'grass_toucher',
      'press_f_black', 'press_f_white', 'git_gud', 'questionable', 'nibbles',
      'nom_kitty', 'toilet_lid', 'feeling_cute', 'buffering',
      'rocket_puncher', 'got_xenoglossy', 'armamenter', 'e_d_hacker',
      'lava_blobs', 'lava_blobs_pink', 'lava_blobs_blue', 'lava_blobs_slime',
      'luminescent_lotus', 'woolgathering', 'study_session', 'group_hug',
      'cozy_post_it', 'cozy_post_it_festive', 'neon_nibbles', 'uwu_xp',
      'hex_lights', 'feelin_awe', 'feelin_panic', 'feelin_nervous',
      'feelin_scrumptious', 'chromawave', 'oasis', 'rainy_mood',
      'cozy_headphones', 'doodling',
    ],
  };

  static const Map<String, String> catalogDisplayNames = {
    'ggez': 'GGEZ',
    'o_n_i': 'O.N.I',
    'ufo': 'UFO',
    'lego_fortnite': 'LEGO® Fortnite',
    'valorant_summer_kickoff': 'VALORANT Summer Kickoff',
    'valorant_champions_2024': 'VALORANT Champions 2024',
    'disxcore_headset': 'DISXCORE Headset',
    'frag_out': 'FRAG OUT',
    'i_love_repo': 'I Love R.E.P.O.',
    'the_fantastic_four': 'The Fantastic Four',
    'spongebob': 'SpongeBob',
    'musclebob': 'MuscleBob',
    'r2_d2_on_tatooine': 'R2-D2 on Tatooine',
    'rawr_xd': 'Rawr xD',
    'g_toilet': 'G-Toilet',
    'nba_2k26': 'NBA 2K26',
    'fc_26_icon': 'FC 26 Icon',
    'kom': 'KOM',
    'mr_m': 'Mr. M',
    'tga_controller': 'TGA Controller',
    'm3gan_2_0': 'M3GAN 2.0',
    'r6_siege_x_avatar': 'R6 Siege X Avatar',
    'bf_soldier_helmet': 'BF Soldier Helmet',
    'thps_half_pipe': 'THPS Half Pipe',
  };

  /// Builds human readable name from code
  static String formatName(String code) {
    if (catalogDisplayNames.containsKey(code)) {
      return catalogDisplayNames[code]!;
    }
    return code
        .split('_')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  /// Get entire catalog, prioritizing server /catalog endpoint with local fallback
  Future<List<AvatarDecorationModel>> getCatalog() async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.avatarDecorationCatalog);
      final d = _asMap(resp.data);
      if (d['success'] == true && d['data'] is Map) {
        final catalogMap = d['data']['catalog'];
        if (catalogMap is Map) {
          final list = <AvatarDecorationModel>[];
          int idCounter = 1;
          catalogMap.forEach((categoryKey, itemsList) {
            if (itemsList is List) {
              for (final rawItem in itemsList) {
                if (rawItem is Map) {
                  final itemMap = Map<String, dynamic>.from(rawItem);
                  itemMap['category'] ??= categoryKey.toString();
                  itemMap['id'] ??= idCounter++;
                  list.add(AvatarDecorationModel.fromJson(itemMap));
                }
              }
            }
          });
          if (list.isNotEmpty) return list;
        }
      }
    } catch (_) {}

    // Fallback: build from hardcoded catalog
    return _buildLocalCatalog();
  }

  List<AvatarDecorationModel> _buildLocalCatalog() {
    final list = <AvatarDecorationModel>[];
    int idCounter = 1;

    defaultCatalog.forEach((category, codes) {
      for (final code in codes) {
        final url = 'https://discord-decoration.art/decorations/$code.png';
        list.add(
          AvatarDecorationModel(
            id: idCounter++,
            code: code,
            name: formatName(code),
            category: category,
            imageUrl: url,
            thumbnailUrl: url,
            isActive: true,
            isOwned: true,
            localAvailable: false,
          ),
        );
      }
    });

    return list;
  }

  /// List decorations with real server-side & fallback pagination support
  Future<Map<String, dynamic>> getDecorations({
    String? category,
    String? search,
    bool ownedOnly = false,
    int page = 1,
    int perPage = 24,
  }) async {
    List<AvatarDecorationModel> decorations = [];
    UserActiveDecorationModel? currentDec;
    List<String> categories = [
      'seasonal', 'gaming', 'anime', 'characters', 'fantasy',
      'scifi', 'animals', 'nature', 'food', 'aesthetic',
    ];
    bool hasNext = false;
    int totalCount = 0;
    int totalPages = 1;

    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
        if (category != null && category.isNotEmpty && category != 'all') 'category': category,
        if (search != null && search.isNotEmpty) 'search': search,
        if (ownedOnly) 'owned_only': 'true',
      };

      final resp = await ApiClient.instance.get(
        ApiEndpoints.avatarDecorations,
        queryParameters: queryParams,
      );

      final d = _asMap(resp.data);
      if (d['success'] == true && d['data'] is Map) {
        final dataMap = Map<String, dynamic>.from(d['data'] as Map);
        final rawList = dataMap['decorations'];
        if (rawList is List && rawList.isNotEmpty) {
          for (final item in rawList) {
            if (item is Map) {
              decorations.add(AvatarDecorationModel.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }

        if (dataMap['current_decoration'] is Map) {
          currentDec = UserActiveDecorationModel.fromJson(
            Map<String, dynamic>.from(dataMap['current_decoration'] as Map),
          );
        }

        if (dataMap['categories'] is List && (dataMap['categories'] as List).isNotEmpty) {
          categories = (dataMap['categories'] as List).map((c) => c.toString()).toList();
        }

        if (dataMap['pagination'] is Map) {
          final p = Map<String, dynamic>.from(dataMap['pagination'] as Map);
          hasNext = p['has_next'] == true;
          totalCount = p['total'] is int
              ? p['total'] as int
              : (int.tryParse(p['total']?.toString() ?? '0') ?? decorations.length);
          totalPages = p['pages'] is int
              ? p['pages'] as int
              : (int.tryParse(p['pages']?.toString() ?? '1') ?? 1);
        } else {
          totalCount = decorations.length;
          hasNext = false;
        }
      }
    } catch (_) {}

    // Fallback: If decorations is empty (e.g. offline/DB seeding), paginate from local catalog
    if (decorations.isEmpty) {
      final catalog = await getCatalog();
      var filtered = catalog;

      if (category != null && category.isNotEmpty && category != 'all') {
        filtered = filtered
            .where((d) => d.category.toLowerCase() == category.toLowerCase())
            .toList();
      }

      if (search != null && search.isNotEmpty) {
        final q = search.toLowerCase();
        filtered = filtered
            .where(
              (d) =>
                  d.name.toLowerCase().contains(q) ||
                  d.code.toLowerCase().contains(q),
            )
            .toList();
      }

      totalCount = filtered.length;
      totalPages = (totalCount / perPage).ceil();
      final start = (page - 1) * perPage;
      final end = (start + perPage).clamp(0, totalCount);
      decorations = start < totalCount ? filtered.sublist(start, end) : <AvatarDecorationModel>[];
      hasNext = page < totalPages;
    }

    // Restore active decoration from local storage if server returned null
    currentDec ??= await getLocalActiveDecoration();

    return {
      'decorations': decorations,
      'current_decoration': currentDec,
      'categories': categories,
      'total': totalCount,
      'has_next': hasNext,
      'page': page,
      'pages': totalPages,
    };
  }

  /// Get list of categories and counts with automatic catalog counting
  Future<List<AvatarDecorationCategoryModel>> getCategories() async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.avatarDecorationCategories);
      final d = _asMap(resp.data);
      if (d['success'] == true && d['data'] is Map) {
        final rawList = (d['data'] as Map)['categories'];
        if (rawList is List && rawList.isNotEmpty) {
          final res = rawList
              .whereType<Map>()
              .map((c) => AvatarDecorationCategoryModel.fromJson(Map<String, dynamic>.from(c)))
              .toList();
          if (res.isNotEmpty) return res;
        }
      }
    } catch (_) {}

    // Fallback: Compute counts from default catalog
    final categories = <AvatarDecorationCategoryModel>[];
    defaultCatalog.forEach((catName, items) {
      if (items.isNotEmpty) {
        categories.add(AvatarDecorationCategoryModel(name: catName, count: items.length));
      }
    });

    return categories;
  }

  /// Get user's owned decorations (falls back to all catalog items)
  Future<Map<String, dynamic>> getMyDecorations() async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.avatarDecorationMy);
      final d = _asMap(resp.data);
      if (d['success'] == true && d['data'] is Map) {
        final dataMap = Map<String, dynamic>.from(d['data'] as Map);
        final rawList = dataMap['decorations'];
        final decorations = <AvatarDecorationModel>[];
        if (rawList is List && rawList.isNotEmpty) {
          for (final item in rawList) {
            if (item is Map) {
              decorations.add(AvatarDecorationModel.fromJson(Map<String, dynamic>.from(item)));
            }
          }
          UserActiveDecorationModel? currentDec;
          if (dataMap['current_decoration'] is Map) {
            currentDec = UserActiveDecorationModel.fromJson(
              Map<String, dynamic>.from(dataMap['current_decoration'] as Map),
            );
          }
          currentDec ??= await getLocalActiveDecoration();
          return {
            'decorations': decorations,
            'current_decoration': currentDec,
            'total': dataMap['total'] ?? decorations.length,
          };
        }
      }
    } catch (_) {}

    final catalog = await getCatalog();
    final currentDec = await getLocalActiveDecoration();
    return {
      'decorations': catalog,
      'current_decoration': currentDec,
      'total': catalog.length,
    };
  }

  /// Select & activate decoration with seamless offline / DB fallback
  Future<UserActiveDecorationModel> selectDecoration({
    int? decorationId,
    String? code,
    String? name,
    String? imageUrl,
    double scale = 1.0,
    int offsetX = 0,
    int offsetY = 0,
  }) async {
    UserActiveDecorationModel? activeModel;

    final targetCode = (code != null && code.isNotEmpty)
        ? code
        : (decorationId != null ? 'avatar_$decorationId' : '');

    try {
      final resp = await ApiClient.instance.post(
        ApiEndpoints.userAvatarDecoration,
        data: {
          'code': targetCode,
          'scale': scale,
          'offset_x': offsetX,
          'offset_y': offsetY,
        },
      );

      final d = _asMap(resp.data);
      if (d['success'] == true && d['data'] is Map) {
        final dataMap = Map<String, dynamic>.from(d['data'] as Map);
        if (dataMap['avatar_decoration'] is Map) {
          activeModel = UserActiveDecorationModel.fromJson(
            Map<String, dynamic>.from(dataMap['avatar_decoration'] as Map),
          );
        }
      }
    } catch (_) {}

    if (activeModel == null) {
      try {
        final resp = await ApiClient.instance.post(
          ApiEndpoints.avatarDecorationSelect,
          data: {
            'code': targetCode,
            if (decorationId != null) 'decoration_id': decorationId,
            'scale': scale,
            'offset_x': offsetX,
            'offset_y': offsetY,
          },
        );

        final d = _asMap(resp.data);
        if (d['success'] == true && d['data'] is Map) {
          final dataMap = Map<String, dynamic>.from(d['data'] as Map);
          if (dataMap['avatar_decoration'] is Map) {
            activeModel = UserActiveDecorationModel.fromJson(
              Map<String, dynamic>.from(dataMap['avatar_decoration'] as Map),
            );
          }
        }
      } catch (_) {}
    }

    // Fallback if server table not seeded yet: create valid local active model
    activeModel ??= UserActiveDecorationModel(
      id: decorationId ?? targetCode.hashCode.abs(),
      code: targetCode,
      name: name ?? formatName(targetCode),
      imageUrl: imageUrl ??
          (targetCode.isNotEmpty
              ? 'https://img.avatardecoration.com/decorations/$targetCode.png'
              : ''),
      scale: scale,
      offsetX: offsetX,
      offsetY: offsetY,
    );

    await saveLocalActiveDecoration(activeModel);
    return activeModel;
  }

  /// Remove active decoration
  Future<bool> removeActiveDecoration() async {
    try {
      await ApiClient.instance.delete(ApiEndpoints.userAvatarDecoration);
    } catch (_) {}
    try {
      await ApiClient.instance.delete(ApiEndpoints.avatarDecorationSelect);
    } catch (_) {}

    await clearLocalActiveDecoration();
    return true;
  }

  /// Get locally persisted active decoration
  Future<UserActiveDecorationModel?> getLocalActiveDecoration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_prefActiveKey);
      if (str != null && str.isNotEmpty) {
        final j = jsonDecode(str);
        if (j is Map<String, dynamic>) {
          return UserActiveDecorationModel.fromJson(j);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Save locally persisted active decoration
  Future<void> saveLocalActiveDecoration(UserActiveDecorationModel model) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefActiveKey, jsonEncode(model.toJson()));
    } catch (_) {}
  }

  /// Clear locally persisted active decoration
  Future<void> clearLocalActiveDecoration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefActiveKey);
    } catch (_) {}
  }

  /// Get stats
  Future<AvatarDecorationStatsModel?> getStats() async {
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.avatarDecorationStats);
      final d = _asMap(resp.data);
      if (d['success'] == true && d['data'] is Map) {
        return AvatarDecorationStatsModel.fromJson(
          Map<String, dynamic>.from(d['data'] as Map),
        );
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }
}