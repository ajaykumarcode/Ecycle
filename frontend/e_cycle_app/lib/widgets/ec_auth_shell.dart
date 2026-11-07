import 'package:flutter/material.dart';

const ecoGreen = Color(0xFF087F5B);
const ecoDark = Color(0xFF102C24);
const ecoMint = Color(0xFFB9F6D3);
const ecoBackground = Color(0xFFF5F8F5);

class EcoAuthShell extends StatelessWidget {
  final Widget child;
  final bool isLogin;

  const EcoAuthShell({super.key, required this.child, required this.isLogin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ecoBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 850;

            if (!wide) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      children: [
                        const SizedBox(height: 18),
                        const _BrandHeader(),
                        const SizedBox(height: 34),
                        child,
                        const SizedBox(height: 26),
                        const _Footer(),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF0D4031),
                          Color(0xFF087F5B),
                          Color(0xFF125E48),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -100,
                          right: -80,
                          child: _GlowCircle(size: 320),
                        ),
                        Positioned(
                          bottom: -130,
                          left: -70,
                          child: _GlowCircle(size: 360),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(48),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.recycling_rounded,
                                    color: ecoMint,
                                    size: 35,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'E-Cycle',
                                    style: TextStyle(
                                      fontSize: 27,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.8,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.eco_rounded,
                                color: ecoMint,
                                size: 70,
                              ),
                              const SizedBox(height: 26),
                              Text(
                                isLogin
                                    ? 'Give your e-waste a second life.'
                                    : 'Small actions. A greener future.',
                                style: const TextStyle(
                                  fontSize: 40,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -1.4,
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Schedule responsible collections, track '
                                'your recycling journey and earn rewards '
                                'while keeping our planet cleaner.',
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.8,
                                  color: Color(0xFFD8F3E4),
                                ),
                              ),
                              const SizedBox(height: 34),
                              const Row(
                                children: [
                                  _FeatureChip(
                                    icon: Icons.local_shipping_outlined,
                                    label: 'Easy pickup',
                                  ),
                                  SizedBox(width: 12),
                                  _FeatureChip(
                                    icon: Icons.stars_rounded,
                                    label: 'Earn rewards',
                                  ),
                                ],
                              ),
                              const Spacer(),
                              const Text(
                                'RECYCLE SMARTER. LIVE GREENER.',
                                style: TextStyle(
                                  color: Color(0xFFC4E9D6),
                                  letterSpacing: 2,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(44),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 410),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.recycling_rounded, color: ecoGreen, size: 34),
        SizedBox(width: 10),
        Text(
          'E-Cycle',
          style: TextStyle(
            color: ecoDark,
            fontSize: 27,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
      ],
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;

  const _GlowCircle({required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.045),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: ecoMint),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'A better tomorrow starts with what we recycle today.',
      textAlign: TextAlign.center,
      style: TextStyle(color: Colors.black54, fontSize: 12),
    );
  }
}
