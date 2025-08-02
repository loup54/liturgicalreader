import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ContextualInfoWidget extends StatelessWidget {
  final AnimationController animationController;
  final Map<String, String> saintOfTheDay;
  final Map<String, String> liturgicalSeason;
  final List<String> relatedReadings;
  final VoidCallback onClose;

  const ContextualInfoWidget({
    Key? key,
    required this.animationController,
    required this.saintOfTheDay,
    required this.liturgicalSeason,
    required this.relatedReadings,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            color:
                Colors.black.withValues(alpha: 0.5 * animationController.value),
            child: GestureDetector(
              onTap: onClose,
              child: Container(
                color: Colors.transparent,
                child: DraggableScrollableSheet(
                  initialChildSize: 0.7,
                  minChildSize: 0.5,
                  maxChildSize: 0.9,
                  builder: (context, scrollController) {
                    return Transform.translate(
                      offset: Offset(
                        0,
                        MediaQuery.of(context).size.height *
                            (1 - animationController.value),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context)
                                  .shadowColor
                                  .withValues(alpha: 0.2),
                              blurRadius: 16,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Handle
                            Container(
                              margin: const EdgeInsets.only(top: 12),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),

                            // Header
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Additional Context',
                                      style: GoogleFonts.crimsonText(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: onClose,
                                  ),
                                ],
                              ),
                            ),

                            // Content
                            Expanded(
                              child: ListView(
                                controller: scrollController,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                children: [
                                  // Saint of the Day
                                  _buildContextSection(
                                    context,
                                    title: 'Saint of the Day',
                                    icon: Icons.person,
                                    children: [
                                      _buildInfoTile(
                                        context,
                                        saintOfTheDay['name'] ?? '',
                                        saintOfTheDay['feast'] ?? '',
                                        Icons.calendar_today,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        saintOfTheDay['description'] ?? '',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          height: 1.5,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),

                                  // Liturgical Season
                                  _buildContextSection(
                                    context,
                                    title: 'Liturgical Season',
                                    icon: Icons.nature,
                                    children: [
                                      _buildInfoTile(
                                        context,
                                        liturgicalSeason['season'] ?? '',
                                        'Liturgical Color: ${liturgicalSeason['color'] ?? ''}',
                                        Icons.palette,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        liturgicalSeason['description'] ?? '',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          height: 1.5,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),

                                  // Related Readings
                                  _buildContextSection(
                                    context,
                                    title: 'Related Readings',
                                    icon: Icons.book,
                                    children: relatedReadings.map((reading) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
                                        child: _buildRelatedReadingTile(
                                            context, reading),
                                      );
                                    }).toList(),
                                  ),

                                  const SizedBox(height: 40), // Bottom padding
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContextSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.crimsonText(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedReadingTile(BuildContext context, String reading) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              reading,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 12,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}
