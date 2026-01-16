import 'package:flutter/material.dart';

/// Breakpoint for desktop vs mobile layout
const double kDesktopBreakpoint = 768.0;

/// Minimum sidebar width (desktop)
const double kSidebarMinWidth = 280.0;

/// Maximum sidebar width (desktop)
const double kSidebarMaxWidth = 400.0;

/// Default sidebar width (desktop)
const double kSidebarDefaultWidth = 320.0;

/// Mobile sidebar width as percentage of screen
const double kMobileSidebarWidthFactor = 0.8;

/// Animation duration
const Duration kSidebarAnimationDuration = Duration(milliseconds: 300);

/// A responsive sidebar widget that adapts to screen size.
///
/// Desktop (>= 768px): Always visible on right side, can be hidden/shown with toggle,
/// resizable width (280px - 400px).
///
/// Mobile (< 768px): Hidden by default, can be shown with swipe from right edge
/// or button tap, takes ~80% of screen width when open.
class ResponsiveSidebar extends StatefulWidget {
  /// The main content widget (left side on desktop)
  final Widget child;

  /// The sidebar content widget
  final Widget sidebar;

  /// Callback when sidebar visibility changes
  final ValueChanged<bool>? onVisibilityChanged;

  /// Whether the sidebar should be initially visible on desktop
  final bool initiallyVisible;

  /// Header widget for the sidebar (optional)
  final Widget? sidebarHeader;

  const ResponsiveSidebar({
    super.key,
    required this.child,
    required this.sidebar,
    this.onVisibilityChanged,
    this.initiallyVisible = true,
    this.sidebarHeader,
  });

  @override
  State<ResponsiveSidebar> createState() => ResponsiveSidebarState();
}

class ResponsiveSidebarState extends State<ResponsiveSidebar>
    with SingleTickerProviderStateMixin {
  /// Animation controller for sidebar slide animation
  late AnimationController _animationController;

  /// Slide animation (0.0 = closed, 1.0 = open)
  late Animation<double> _slideAnimation;

  /// Current sidebar width (desktop only)
  double _sidebarWidth = kSidebarDefaultWidth;

  /// Whether sidebar is visible (desktop: toggle state, mobile: open state)
  bool _isVisible = true;

  /// Whether user is currently dragging the sidebar
  bool _isDragging = false;

  /// Drag start position for gesture handling
  double _dragStartX = 0.0;

  @override
  void initState() {
    super.initState();
    _isVisible = widget.initiallyVisible;

    _animationController = AnimationController(
      vsync: this,
      duration: kSidebarAnimationDuration,
      value: _isVisible ? 1.0 : 0.0,
    );

    _slideAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Returns true if the current screen is desktop size
  bool get _isDesktop => MediaQuery.of(context).size.width >= kDesktopBreakpoint;

  /// Returns the sidebar width based on screen size
  double get _effectiveSidebarWidth {
    if (_isDesktop) {
      return _sidebarWidth;
    } else {
      return MediaQuery.of(context).size.width * kMobileSidebarWidthFactor;
    }
  }

  /// Toggle sidebar visibility with animation
  void toggleSidebar() {
    setState(() {
      _isVisible = !_isVisible;
    });

    if (_isVisible) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }

    widget.onVisibilityChanged?.call(_isVisible);
  }

  /// Show sidebar with animation
  void showSidebar() {
    if (!_isVisible) {
      setState(() {
        _isVisible = true;
      });
      _animationController.forward();
      widget.onVisibilityChanged?.call(true);
    }
  }

  /// Hide sidebar with animation
  void hideSidebar() {
    if (_isVisible) {
      setState(() {
        _isVisible = false;
      });
      _animationController.reverse();
      widget.onVisibilityChanged?.call(false);
    }
  }

  /// Handle drag start
  void _onHorizontalDragStart(DragStartDetails details) {
    _isDragging = true;
    _dragStartX = details.globalPosition.dx;
    _animationController.stop();
  }

  /// Handle drag update for mobile swipe gesture
  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    final sidebarWidth = _effectiveSidebarWidth;

    // Calculate new animation value based on drag position
    final dragDelta = details.globalPosition.dx - _dragStartX;

    if (_isVisible) {
      // Dragging to close (right to left drag)
      final newValue = 1.0 + (dragDelta / sidebarWidth);
      _animationController.value = newValue.clamp(0.0, 1.0);
    } else {
      // Dragging to open (left to right drag from right edge)
      final newValue = -dragDelta / sidebarWidth;
      _animationController.value = newValue.clamp(0.0, 1.0);
    }
  }

  /// Handle drag end - snap to nearest state based on velocity and position
  void _onHorizontalDragEnd(DragEndDetails details) {
    _isDragging = false;

    final velocity = details.primaryVelocity ?? 0.0;
    final currentValue = _animationController.value;

    // Determine final state based on velocity and current position
    // Positive velocity = dragging left (close), Negative = dragging right (open)
    bool shouldOpen;

    if (velocity.abs() > 500) {
      // High velocity - follow the direction
      shouldOpen = velocity < 0;
    } else {
      // Low velocity - snap to nearest state (threshold at 50%)
      shouldOpen = currentValue > 0.5;
    }

    if (shouldOpen) {
      _animationController.forward();
      if (!_isVisible) {
        setState(() {
          _isVisible = true;
        });
        widget.onVisibilityChanged?.call(true);
      }
    } else {
      _animationController.reverse();
      if (_isVisible) {
        setState(() {
          _isVisible = false;
        });
        widget.onVisibilityChanged?.call(false);
      }
    }
  }

  /// Handle resize drag for desktop
  void _onResizeDragUpdate(DragUpdateDetails details) {
    setState(() {
      _sidebarWidth =
          (_sidebarWidth - details.delta.dx).clamp(kSidebarMinWidth, kSidebarMaxWidth);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isDesktop) {
      return _buildDesktopLayout(colorScheme);
    } else {
      return _buildMobileLayout(colorScheme);
    }
  }

  /// Build desktop layout with sidebar always in layout flow
  Widget _buildDesktopLayout(ColorScheme colorScheme) {
    return Row(
      children: [
        // Main content
        Expanded(child: widget.child),

        // Animated sidebar container
        AnimatedBuilder(
          animation: _slideAnimation,
          builder: (context, child) {
            if (_slideAnimation.value == 0.0) {
              return const SizedBox.shrink();
            }

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Resize handle
                GestureDetector(
                  onHorizontalDragUpdate: _onResizeDragUpdate,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    child: Container(
                      width: 4,
                      color: colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                ),

                // Sidebar content
                SizedBox(
                  width: _sidebarWidth * _slideAnimation.value,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      maxWidth: _sidebarWidth,
                      child: Container(
                        width: _sidebarWidth,
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          border: Border(
                            left: BorderSide(
                              color: colorScheme.outline.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            if (widget.sidebarHeader != null) widget.sidebarHeader!,
                            Expanded(child: widget.sidebar),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// Build mobile layout with overlay sidebar
  Widget _buildMobileLayout(ColorScheme colorScheme) {
    return Stack(
      children: [
        // Main content
        widget.child,

        // Swipe detection area on right edge
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: GestureDetector(
            onHorizontalDragStart: _onHorizontalDragStart,
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            behavior: HitTestBehavior.translucent,
            child: Container(
              width: 20,
              color: Colors.transparent,
            ),
          ),
        ),

        // Animated scrim (darkening overlay when sidebar is open)
        AnimatedBuilder(
          animation: _slideAnimation,
          builder: (context, child) {
            if (_slideAnimation.value == 0.0) {
              return const SizedBox.shrink();
            }

            return GestureDetector(
              onTap: hideSidebar,
              child: Container(
                color: Colors.black.withOpacity(0.3 * _slideAnimation.value),
              ),
            );
          },
        ),

        // Sidebar panel (slides in from right)
        AnimatedBuilder(
          animation: _slideAnimation,
          builder: (context, child) {
            final sidebarWidth = _effectiveSidebarWidth;
            final offset = sidebarWidth * (1.0 - _slideAnimation.value);

            return Positioned(
              right: -offset,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onHorizontalDragStart: _onHorizontalDragStart,
                onHorizontalDragUpdate: _onHorizontalDragUpdate,
                onHorizontalDragEnd: _onHorizontalDragEnd,
                child: Container(
                  width: sidebarWidth,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(-2, 0),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    left: false,
                    child: Column(
                      children: [
                        if (widget.sidebarHeader != null) widget.sidebarHeader!,
                        Expanded(child: widget.sidebar),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// A widget that rebuilds when animation value changes
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}

/// Sidebar header widget with title and close button
class SidebarHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onClose;
  final bool showCloseButton;

  const SidebarHeader({
    super.key,
    required this.title,
    this.onClose,
    this.showCloseButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: colorScheme.onSurface,
              decoration: TextDecoration.none,
            ),
          ),
          const Spacer(),
          if (showCloseButton)
            IconButton(
              onPressed: onClose,
              icon: Icon(
                Icons.close,
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
              tooltip: 'Close',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
        ],
      ),
    );
  }
}

/// Sidebar toggle button widget for app bars
class SidebarToggleButton extends StatelessWidget {
  final bool isVisible;
  final VoidCallback onToggle;

  const SidebarToggleButton({
    super.key,
    required this.isVisible,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      onPressed: onToggle,
      icon: Icon(
        isVisible ? Icons.chevron_right : Icons.people_outline,
        color: colorScheme.primary,
      ),
      tooltip: isVisible ? 'Hide sidebar' : 'Show network',
    );
  }
}
