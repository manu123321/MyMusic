import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlaylistCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? imagePath;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final Color? themeColor;
  final Widget? badge;

  const PlaylistCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.imagePath,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.themeColor,
    this.badge,
  });

  @override
  State<PlaylistCard> createState() => _PlaylistCardState();
}

class _PlaylistCardState extends State<PlaylistCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _elevationAnimation = Tween<double>(
      begin: 2.0,
      end: 8.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Playlist: ${widget.title}',
      hint: '${widget.subtitle}. Tap to open playlist.',
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: _elevationAnimation.value,
                    offset: Offset(0, _elevationAnimation.value / 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onTap?.call();
                  },
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    widget.onLongPress?.call();
                  },
                  onTapDown: (_) {
                    setState(() {
                      _isPressed = true;
                    });
                    _animationController.forward();
                  },
                  onTapUp: (_) {
                    setState(() {
                      _isPressed = false;
                    });
                    _animationController.reverse();
                  },
                  onTapCancel: () {
                    setState(() {
                      _isPressed = false;
                    });
                    _animationController.reverse();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.isSelected 
                          ? (widget.themeColor ?? const Color(0xFF00E676)).withOpacity(0.1)
                          : Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                      border: widget.isSelected
                          ? Border.all(
                              color: widget.themeColor ?? const Color(0xFF00E676),
                              width: 2,
                            )
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image with enhanced styling
                        Expanded(
                          flex: 3,
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                                child: _buildImage(),
                              ),
                              if (widget.badge != null)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: widget.badge!,
                                ),
                              // Gradient overlay for better text readability
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.7),
                                      ],
                                    ),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Text content with enhanced styling
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  widget.title,
                                  style: TextStyle(
                                    color: widget.isSelected 
                                        ? (widget.themeColor ?? const Color(0xFF00E676))
                                        : Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.subtitle,
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildImage() {
    if (widget.imagePath != null) {
      return Image.file(
        File(widget.imagePath!),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        cacheWidth: 200,
        cacheHeight: 200,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultImage();
        },
      );
    } else {
      return _buildDefaultImage();
    }
  }
  
  Widget _buildDefaultImage() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.themeColor?.withOpacity(0.3) ?? Colors.grey[800]!,
            widget.themeColor?.withOpacity(0.1) ?? Colors.grey[900]!,
          ],
        ),
      ),
      child: Icon(
        Icons.playlist_play_rounded,
        color: widget.themeColor ?? Colors.white,
        size: 48,
      ),
    );
  }
}
