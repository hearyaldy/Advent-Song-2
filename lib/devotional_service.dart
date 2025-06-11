// devotional_service.dart - Simple version that works offline first
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class DevotionalService {
  static Future<Map<String, dynamic>> getTodaysDevotional() async {
    try {
      // 1. Try cache first (for today)
      final cached = await _getCachedDevotional();
      if (cached != null) {
        print('Loading devotional from cache');
        return cached;
      }

      // 2. Generate daily devotional from built-in content
      final devotional = _generateDailyDevotional();

      // 3. Cache it for today
      await _cacheDevotional(devotional);

      print('Generated new daily devotional');
      return devotional;
    } catch (e) {
      print('Error in getTodaysDevotional: $e');
      // Return a basic fallback
      return _getBasicFallback();
    }
  }

  static Map<String, dynamic> _generateDailyDevotional() {
    final today = DateTime.now();
    final dayOfYear = today.difference(DateTime(today.year, 1, 1)).inDays;

    // Use day of year as seed for consistent daily content
    final random = Random(dayOfYear);
    final devotional = _devotionals[random.nextInt(_devotionals.length)];

    return {
      ...devotional,
      'id': 'daily_${DateFormat('yyyy-MM-dd').format(today)}',
      'date': DateFormat('yyyy-MM-dd').format(today),
    };
  }

  static Future<Map<String, dynamic>?> _getCachedDevotional() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final cachedJson = prefs.getString('devotional_$today');

    if (cachedJson != null) {
      try {
        return json.decode(cachedJson);
      } catch (e) {
        await prefs.remove('devotional_$today');
      }
    }
    return null;
  }

  static Future<void> _cacheDevotional(Map<String, dynamic> devotional) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await prefs.setString('devotional_$today', json.encode(devotional));

    // Clean old cache (keep only last 30 days)
    await _cleanOldCache(prefs);
  }

  static Future<void> _cleanOldCache(SharedPreferences prefs) async {
    final keys = prefs.getKeys().where((key) => key.startsWith('devotional_'));
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));

    for (final key in keys) {
      try {
        final dateStr = key.replaceFirst('devotional_', '');
        final date = DateTime.parse(dateStr);
        if (date.isBefore(cutoffDate)) {
          await prefs.remove(key);
        }
      } catch (e) {
        await prefs.remove(key);
      }
    }
  }

  static Map<String, dynamic> _getBasicFallback() {
    return {
      'id': 'fallback_${DateTime.now().millisecondsSinceEpoch}',
      'title': 'Daily Encouragement',
      'content':
          'Take time today to reflect on God\'s goodness and mercy. In every situation, remember that He is with you and His love for you is unfailing.',
      'verse':
          'The Lord your God is with you, the Mighty Warrior who saves. He will take great delight in you; in his love he will no longer rebuke you, but will rejoice over you with singing.',
      'reference': 'Zephaniah 3:17',
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'source': 'Built-in',
      'author': 'Lagu Advent',
    };
  }

  // Rich collection of devotional content
  static final List<Map<String, dynamic>> _devotionals = [
    {
      'title': 'Walking in Faith',
      'content':
          'Faith is not about knowing all the answers or seeing the entire path ahead. It\'s about taking the next step, trusting that God is guiding your way. When uncertainty clouds your vision, remember that His light shines brightest in the darkness. Each step of faith, no matter how small, brings you closer to His perfect plan for your life.',
      'verse':
          'Trust in the Lord with all your heart and lean not on your own understanding; in all your ways submit to him, and he will make your paths straight.',
      'reference': 'Proverbs 3:5-6',
      'source': 'Built-in',
      'author': 'Lagu Advent',
    },
    {
      'title': 'The Peace of Christ',
      'content':
          'In a world filled with anxiety and turmoil, Christ offers us a peace that transcends understanding. This peace doesn\'t come from the absence of problems, but from the presence of God in our midst. When storms rage around you, anchor your heart in His promises. Let His peace guard your mind and heart, knowing that He is in control of every circumstance.',
      'verse':
          'Peace I leave with you; my peace I give you. I do not give to you as the world gives. Do not let your hearts be troubled and do not be afraid.',
      'reference': 'John 14:27',
      'source': 'Built-in',
      'author': 'Lagu Advent',
    },
    {
      'title': 'Unconditional Love',
      'content':
          'God\'s love for you is not based on your performance, achievements, or worthiness. It\'s rooted in His character - unchanging, eternal, and perfect. When you feel unlovable or make mistakes, remember that His love remains constant. This love has the power to transform, heal, and restore. Let it fill every empty space in your heart today.',
      'verse':
          'For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.',
      'reference': 'John 3:16',
      'source': 'Built-in',
      'author': 'Lagu Advent',
    },
    {
      'title': 'Strength in Weakness',
      'content':
          'Your weaknesses are not obstacles to God\'s power - they are invitations for His strength to be displayed. When you feel inadequate or overwhelmed, remember that God chooses the weak things of this world to shame the strong. In your vulnerability, His grace is sufficient. Allow His strength to be perfected in your weakness today.',
      'verse':
          'But he said to me, "My grace is sufficient for you, for my power is made perfect in weakness." Therefore I will boast all the more gladly about my weaknesses, so that Christ\'s power may rest on me.',
      'reference': '2 Corinthians 12:9',
      'source': 'Built-in',
      'author': 'Lagu Advent',
    },
    {
      'title': 'Hope in Difficult Times',
      'content':
          'Even in the darkest moments, hope remains. It\'s not wishful thinking or denial of reality - it\'s confident expectation based on God\'s faithful character. When circumstances seem impossible, remember that nothing is too difficult for God. He has a purpose in every season, including the difficult ones. Hold onto hope, for your story is not over.',
      'verse':
          'For I know the plans I have for you," declares the Lord, "plans to prosper you and not to harm you, plans to give you hope and a future.',
      'reference': 'Jeremiah 29:11',
      'source': 'Built-in',
      'author': 'Lagu Advent',
    },
    {
      'title': 'The Joy of the Lord',
      'content':
          'Joy is not dependent on your circumstances - it flows from your relationship with God. Even in sorrow, this divine joy can coexist with pain, bringing light to dark places. The joy of the Lord is your strength, sustaining you through every trial. Choose to find reasons for gratitude today, and let His joy be your portion.',
      'verse': 'Do not grieve, for the joy of the Lord is your strength.',
      'reference': 'Nehemiah 8:10',
      'source': 'Built-in',
      'author': 'Lagu Advent',
    },
    {
      'title': 'God\'s Faithfulness',
      'content':
          'Throughout history, God has never failed to keep His promises. His faithfulness spans generations, remaining constant when everything else changes. Today, you can trust in His proven track record of love and care. Whatever you\'re facing, remember His faithfulness in the past and rest in the assurance of His continued faithfulness in your future.',
      'verse':
          'Great is your faithfulness, O Lord; your mercies are new every morning.',
      'reference': 'Lamentations 3:23',
      'source': 'Built-in',
      'author': 'Lagu Advent',
    },
    {
      'title': 'Walking in Purpose',
      'content':
          'You were created with intention and designed for a purpose. Every experience, every gift, every passion has been woven together by God for His glory and your fulfillment. Don\'t underestimate the importance of your calling. Whether big or small in the world\'s eyes, your purpose matters in God\'s kingdom. Step boldly into what He has prepared for you.',
      'verse':
          'For we are God\'s handiwork, created in Christ Jesus to do good works, which God prepared in advance for us to do.',
      'reference': 'Ephesians 2:10',
      'source': 'Built-in',
      'author': 'Lagu Advent',
    },
    {
      'title': 'Divine Protection',
      'content':
          'You are not walking through life alone or unprotected. God\'s watchful eye is always upon you, His mighty hand ready to shield and deliver. Under the shadow of His wings, you find refuge from every storm. Trust in His protection today, knowing that no weapon formed against you shall prosper.',
      'verse':
          'He will cover you with his feathers, and under his wings you will find refuge; his faithfulness will be your shield and rampart.',
      'reference': 'Psalm 91:4',
      'source': 'Built-in',
      'author': 'Lagu Advent',
    },
    {
      'title': 'Forgiveness and Grace',
      'content':
          'God\'s forgiveness is complete and His grace is abundant. When guilt and shame try to define you, remember that you are defined by His love and grace instead. Your past mistakes do not determine your future. In Christ, you are a new creation - the old has gone, the new has come. Walk in the freedom of His forgiveness today.',
      'verse':
          'Therefore, if anyone is in Christ, the new creation has come: The old has gone, the new is here!',
      'reference': '2 Corinthians 5:17',
      'source': 'Built-in',
      'author': 'Lagu Advent',
    },
  ];
}
