import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DismissibleAppBarWidget extends StatelessWidget {
  final AnimationController animationController;
  final bool isVisible;
  final String title;
  final VoidCallback onBackPressed;
  final VoidCallback onContextPressed;

  const DismissibleAppBarWidget({
    Key? key,
    required this.animationController,
    required this.isVisible,
    required this.title,
    required this.onBackPressed,
    required this.onContextPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -60 * (1 - animationController.value)),
          child: Container(
            height: 60 + MediaQuery.of(context).padding.top,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .scaffoldBackgroundColor
                  .withValues(alpha: 0.95),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios),
                      onPressed: onBackPressed,
                      tooltip: 'Back',
                    ),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.crimsonText(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline),
                      onPressed: onContextPressed,
                      tooltip: 'Additional context',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
