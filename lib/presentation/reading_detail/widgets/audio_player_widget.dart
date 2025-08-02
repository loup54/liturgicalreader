import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final String title;
  final String source;

  const AudioPlayerWidget({
    Key? key,
    required this.audioUrl,
    required this.title,
    required this.source,
  }) : super(key: key);

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget>
    with TickerProviderStateMixin {
  late AnimationController _playButtonController;
  bool _isPlaying = false;
  bool _isLoading = false;
  double _progress = 0.0;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration =
      const Duration(minutes: 3, seconds: 45); // Mock duration

  @override
  void initState() {
    super.initState();
    _playButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _playButtonController.dispose();
    super.dispose();
  }

  void _togglePlayPause() async {
    HapticFeedback.lightImpact();

    setState(() {
      _isLoading = true;
    });

    // Simulate loading delay
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _isPlaying = !_isPlaying;
      _isLoading = false;
    });

    if (_isPlaying) {
      _playButtonController.forward();
      _startProgressSimulation();
    } else {
      _playButtonController.reverse();
    }
  }

  void _startProgressSimulation() {
    // Simulate audio progress - in real app, this would be driven by actual audio player
    if (_isPlaying) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_isPlaying && mounted) {
          setState(() {
            _progress += 0.001;
            _currentPosition = Duration(
              milliseconds: (_totalDuration.inMilliseconds * _progress).round(),
            );

            if (_progress >= 1.0) {
              _progress = 1.0;
              _isPlaying = false;
              _playButtonController.reverse();
            } else {
              _startProgressSimulation();
            }
          });
        }
      });
    }
  }

  void _seekTo(double value) {
    setState(() {
      _progress = value;
      _currentPosition = Duration(
        milliseconds: (_totalDuration.inMilliseconds * value).round(),
      );
    });
    HapticFeedback.selectionClick();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.headphones,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Audio Reading',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title and Source
            Text(
              widget.source,
              style: GoogleFonts.crimsonText(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),

            // Progress Bar
            Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 16),
                    activeTrackColor: Theme.of(context).colorScheme.primary,
                    inactiveTrackColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.3),
                    thumbColor: Theme.of(context).colorScheme.primary,
                  ),
                  child: Slider(
                    value: _progress,
                    onChanged: _seekTo,
                    min: 0.0,
                    max: 1.0,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_currentPosition),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                      Text(
                        _formatDuration(_totalDuration),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Control Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.replay_10),
                  onPressed: () {
                    _seekTo((_progress - 0.1).clamp(0.0, 1.0));
                  },
                  tooltip: 'Replay 10 seconds',
                ),
                const SizedBox(width: 16),

                // Play/Pause Button
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: _togglePlayPause,
                      child: _isLoading
                          ? const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : AnimatedBuilder(
                              animation: _playButtonController,
                              builder: (context, child) {
                                return Icon(
                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 28,
                                );
                              },
                            ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.forward_30),
                  onPressed: () {
                    _seekTo((_progress + 0.15).clamp(0.0, 1.0));
                  },
                  tooltip: 'Forward 30 seconds',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
