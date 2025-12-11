import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../layout/main.dart';

class HomePage extends StatefulWidget {
  final Function(int index) onTapMenu;
  final List<MenuItemConfig> visibleMenuItems;

  const HomePage({
    super.key,
    required this.onTapMenu,
    required this.visibleMenuItems,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin {
  final CarouselSliderController _carouselController =
      CarouselSliderController();
  int _currentIndex = 0;

  final List<String> imageList = [
    "assets/img/banner1.jpg",
    "assets/img/banner2.jpg",
    "assets/img/banner3.jpg",
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _precacheImages();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Get menu items for grid (exclude home & profile, only show enabled)
  List<MenuItemConfig> get _gridMenuItems {
    return widget.visibleMenuItems.where((item) {
      // Exclude home and profile from grid
      if (item.id == 'home' || item.id == 'profile') return false;
      return true;
    }).toList();
  }

  // Precache images for better performance
  void _precacheImages() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        for (var img in imageList) {
          precacheImage(AssetImage(img), context);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Scaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carousel Slider
            _buildCarousel(),

            const SizedBox(height: 24),

            // Section Title
            _buildSectionTitle(),

            const SizedBox(height: 16),

            // Menu Grid (Dynamic)
            _buildMenuGrid(),

            const SizedBox(height: 24),

            // Info Section
            _buildInfoSection(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCarousel() {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        CarouselSlider.builder(
          carouselController: _carouselController,
          itemCount: imageList.length,
          itemBuilder: (context, index, realIdx) {
            // Calculate cache width with safety check
            final screenWidth = MediaQuery.of(context).size.width;
            final pixelRatio = MediaQuery.of(context).devicePixelRatio;
            final calculatedWidth = (screenWidth * pixelRatio).round();
            // Ensure cacheWidth is positive and reasonable
            final cacheWidth = calculatedWidth > 0 ? calculatedWidth : null;

            return ClipRRect(
              borderRadius: BorderRadius.circular(0),
              child: Image.asset(
                imageList[index],
                fit: BoxFit.cover,
                width: double.infinity,
                // Use cacheWidth only if it's valid (positive)
                cacheWidth: cacheWidth,
                errorBuilder: (context, error, stackTrace) {
                  return _buildErrorPlaceholder(index);
                },
              ),
            );
          },
          options: CarouselOptions(
            height: 200,
            viewportFraction: 1.0,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 4),
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
            autoPlayCurve: Curves.fastOutSlowIn,
            enableInfiniteScroll: true,
            pauseAutoPlayOnTouch: true,
            pauseAutoPlayOnManualNavigate: true,
            scrollPhysics: const BouncingScrollPhysics(),
            onPageChanged: (index, reason) {
              if (mounted) {
                setState(() => _currentIndex = index);
              }
            },
          ),
        ),

        // Indicator dots
        Positioned(
          bottom: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: imageList.asMap().entries.map((entry) {
              return GestureDetector(
                onTap: () => _carouselController.animateToPage(entry.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: _currentIndex == entry.key ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _currentIndex == entry.key
                        ? Colors.white
                        : Colors.white54,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorPlaceholder(int index) {
    return Container(
      color: Colors.blue.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported,
              size: 48,
              color: Colors.blue.shade300,
            ),
            const SizedBox(height: 8),
            Text(
              'Banner ${index + 1}',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle() {
    final menuCount = _gridMenuItems.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Menu Navigasi",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$menuCount menu',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGrid() {
    final gridItems = _gridMenuItems;

    if (gridItems.isEmpty) {
      return _buildEmptyMenu();
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: gridItems.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: gridItems.length == 1 ? 1 : 2,
        childAspectRatio: gridItems.length == 1 ? 2.5 : 1.3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemBuilder: (context, index) {
        return _buildMenuItem(gridItems[index]);
      },
    );
  }

  Widget _buildEmptyMenu() {
    // Find profile index for login navigation
    final profileIndex = widget.visibleMenuItems.indexWhere(
      (m) => m.id == 'profile',
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(Icons.login, size: 64, color: Colors.blue.shade300),
          const SizedBox(height: 16),
          Text(
            'Selamat Datang!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Silakan login untuk mengakses fitur aplikasi',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: profileIndex != -1
                ? () => widget.onTapMenu(profileIndex)
                : null,
            icon: const Icon(Icons.person),
            label: const Text('Login Sekarang'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(MenuItemConfig item) {
    // Find actual index in visibleMenuItems for navigation
    final actualIndex = widget.visibleMenuItems.indexWhere(
      (m) => m.id == item.id,
    );

    // Determine colors based on menu state
    final bool isDisabled = !item.enabled;
    final List<Color> gradientColors = isDisabled
        ? [Colors.grey.shade400, Colors.grey.shade500]
        : item.adminOnly
        ? [Colors.orange.shade400, Colors.orange.shade600]
        : [Colors.blue.shade400, Colors.blue.shade600];

    final Color shadowColor = isDisabled
        ? Colors.grey.withOpacity(0.2)
        : item.adminOnly
        ? Colors.orange.withOpacity(0.3)
        : Colors.blue.withOpacity(0.3);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: actualIndex != -1 ? () => widget.onTapMenu(actualIndex) : null,
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.white.withOpacity(0.3),
        highlightColor: Colors.white.withOpacity(0.1),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Main content
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.icon, size: 36, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      item.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),

              // Badges
              if (isDisabled)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.lock,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),

              if (item.adminOnly && !isDisabled)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield, size: 10, color: Colors.white),
                        SizedBox(width: 2),
                        Text(
                          'Admin',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MAJSF Scanner App',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Aplikasi untuk scan barcode & QR code untuk manajemen inventory',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
