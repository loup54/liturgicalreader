import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import './widgets/contextual_info_widget.dart';
import './widgets/dismissible_app_bar_widget.dart';
import './widgets/reading_content_widget.dart';
import './widgets/reading_toolbar_widget.dart';

class ReadingDetail extends StatefulWidget {
  const ReadingDetail({Key? key}) : super(key: key);

  @override
  State<ReadingDetail> createState() => _ReadingDetailState();
}

class _ReadingDetailState extends State<ReadingDetail>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();

  late AnimationController _appBarAnimationController;
  late AnimationController _contextAnimationController;

  bool _isAppBarVisible = true;
  bool _isContextVisible = false;
  bool _isBookmarked = false;
  double _textScaleFactor = 1.0;
  int _currentReadingIndex = 0;

  // Mock data - in real app this would come from arguments/API
  final List<Map<String, dynamic>> _readings = [
    {
      'title': 'First Reading',
      'source': 'Isaiah 55:10-11',
      'liturgicalContext': 'Sunday in Ordinary Time',
      'content':
          '''Thus says the Lord: Just as from the heavens the rain and snow come down and do not return there till they have watered the earth, making it fertile and fruitful, giving seed to the one who sows and bread to the one who eats, so shall my word be that goes forth from my mouth; my word shall not return to me void, but shall do my will, achieving the end for which I sent it. The word of the Lord.''',
      'audioUrl': 'https://example.com/audio/reading1.mp3',
    },
    {
      'title': 'Responsorial Psalm',
      'source': 'Psalm 65:10-14',
      'liturgicalContext': 'Sunday in Ordinary Time',
      'content':
          '''R. The seed that falls on good ground will yield a fruitful harvest. You have visited the land and watered it; greatly have you enriched it. God\'s watercourses are filled; you have prepared the grain. R. The seed that falls on good ground will yield a fruitful harvest. Thus have you prepared the land: drenching its furrows, breaking up its clods, softening it with showers, blessing its yield. R. The seed that falls on good ground will yield a fruitful harvest.''',
      'audioUrl': 'https://example.com/audio/psalm.mp3',
    },
    {
      'title': 'Gospel',
      'source': 'Matthew 13:1-23',
      'liturgicalContext': 'Sunday in Ordinary Time',
      'content':
          '''On that day, Jesus went out of the house and sat down by the sea. Such large crowds gathered around him that he got into a boat and sat down, and the whole crowd stood along the shore. And he spoke to them at length in parables, saying: "A sower went out to sow. And as he sowed, some seed fell on the path, and birds came and ate it up. Some fell on rocky ground, where it had little soil. It sprang up at once because the soil was not deep, and when the sun rose it was scorched, and it withered for lack of roots. Some seed fell among thorns, and the thorns grew up and choked it. But some seed fell on rich soil, and produced fruit, a hundred or sixty or thirtyfold. Whoever has ears ought to hear." The Gospel of the Lord.''',
      'audioUrl': 'https://example.com/audio/gospel.mp3',
    },
  ];

  final Map<String, String> _saintOfTheDay = {
    'name': 'Saint Mary Magdalene',
    'feast': 'July 22',
    'description':
        'The Apostle to the Apostles, first witness to the Resurrection',
  };

  final Map<String, String> _liturgicalSeason = {
    'season': 'Ordinary Time',
    'color': 'Green',
    'description': 'A time for growth in Christian living and discipleship',
  };

  @override
  void initState() {
    super.initState();
    _appBarAnimationController = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
    _contextAnimationController = AnimationController(
        duration: const Duration(milliseconds: 400), vsync: this);

    _scrollController.addListener(_handleScroll);
    _appBarAnimationController.forward();

    // Get arguments if any
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _currentReadingIndex = args['readingIndex'] ?? 0;
        _isBookmarked = args['isBookmarked'] ?? false;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    _appBarAnimationController.dispose();
    _contextAnimationController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final bool shouldShowAppBar = _scrollController.offset <= 50;
    if (shouldShowAppBar != _isAppBarVisible) {
      setState(() {
        _isAppBarVisible = shouldShowAppBar;
      });
      if (_isAppBarVisible) {
        _appBarAnimationController.forward();
      } else {
        _appBarAnimationController.reverse();
      }
    }
  }

  void _toggleBookmark() {
    setState(() {
      _isBookmarked = !_isBookmarked;
    });

    HapticFeedback.lightImpact();

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(_isBookmarked ? 'Reading bookmarked' : 'Bookmark removed'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating));
  }

  void _shareReading() {
    final currentReading = _readings[_currentReadingIndex];
    // In real app, implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Sharing "${currentReading['title']}"'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating));
  }

  void _adjustTextSize(double delta) {
    setState(() {
      _textScaleFactor = (_textScaleFactor + delta).clamp(0.8, 2.0);
    });
  }

  void _toggleContextInfo() {
    setState(() {
      _isContextVisible = !_isContextVisible;
    });

    if (_isContextVisible) {
      _contextAnimationController.forward();
    } else {
      _contextAnimationController.reverse();
    }
  }

  void _navigateToReading(int index) {
    if (index >= 0 && index < _readings.length) {
      setState(() {
        _currentReadingIndex = index;
      });
      _pageController.animateToPage(index,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(children: [
      // Main content
      Column(
        children: [
          // Animated App Bar
          DismissibleAppBarWidget(
            animationController: _appBarAnimationController,
            isVisible: _isAppBarVisible,
            title: _readings[_currentReadingIndex]['title'],
            onBackPressed: () => Navigator.of(context).pop(),
            onContextPressed: _toggleContextInfo,
          ),

          // Content area
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _readings.length,
              itemBuilder: (context, index) {
                return ReadingContentWidget(
                  title: _readings[index]['title'],
                  source: _readings[index]['source'],
                  liturgicalContext: _readings[index]['liturgicalContext'],
                  content: _readings[index]['content'],
                  textScaleFactor: _textScaleFactor,
                );
              },
              onPageChanged: (index) {
                setState(() {
                  _currentReadingIndex = index;
                });
              },
            ),
          ),
        ],
      ),

      // Bottom Toolbar
      Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: ReadingToolbarWidget(
              isBookmarked: _isBookmarked,
              onBookmarkPressed: _toggleBookmark,
              onSharePressed: _shareReading,
              onTextSizeIncrease: () => _adjustTextSize(0.1),
              onTextSizeDecrease: () => _adjustTextSize(-0.1),
              currentReadingIndex: _currentReadingIndex,
              totalReadings: _readings.length,
              onNavigateToReading: _navigateToReading)),

      // Contextual Information Sheet
      if (_isContextVisible)
        ContextualInfoWidget(
            animationController: _contextAnimationController,
            saintOfTheDay: _saintOfTheDay,
            liturgicalSeason: _liturgicalSeason,
            relatedReadings: ['Acts 8:26-40', 'Psalm 119:105', 'Luke 24:13-35'],
            onClose: _toggleContextInfo),
    ]));
  }
}
