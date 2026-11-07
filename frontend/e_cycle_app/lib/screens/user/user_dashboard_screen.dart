import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'schedule_pickup_screen.dart';

import '../../models/pickup_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/pickup_service.dart';
import '../../widgets/ec_auth_shell.dart';
import '../auth/login_screen.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  final PickupService _service = PickupService();
  late Future<List<PickupModel>> _pickupsFuture;
  String _selectedStatusFilter =
      'all'; // all, pending, assigned, collected, recycled, cancelled

  @override
  void initState() {
    super.initState();
    _pickupsFuture = Future.value([]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadPickups();
    });
  }

  void _loadPickups() {
    final token = context.read<AuthProvider>().token;

    setState(() {
      _pickupsFuture = token == null
          ? Future.error('Please sign in to view your pickups.')
          : _service.getMyPickups(token);
    });
  }

  Future<void> _openScheduleScreen() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SchedulePickupScreen()),
    );
    if (created == true && mounted) {
      _loadPickups();
    }
  }

  Future<void> _cancelPickup(PickupModel pickup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel pickup?'),
        content: Text(
          'Are you sure you want to cancel your ${pickup.category} pickup?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep pickup'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
            ),
            child: const Text('Cancel pickup'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in again to cancel a pickup.'),
        ),
      );
      return;
    }

    try {
      await _service.cancelPickup(token: token, pickupId: pickup.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pickup cancelled successfully.'),
          backgroundColor: ecoGreen,
        ),
      );

      _loadPickups();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFB42318),
        ),
      );
    }
  }

  void _showPickupDetails(PickupModel pickup) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (context, scrollCtrl) {
            return SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDDF5E8),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.devices_other_rounded,
                          color: ecoGreen,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pickup.category,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: ecoDark,
                              ),
                            ),
                            Text(
                              '${pickup.quantity} item(s) • ${pickup.estimatedWeightKg.toStringAsFixed(1)} kg',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  const Text(
                    'Pickup Status Timeline',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: ecoDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTimeline(pickup),

                  const Divider(height: 32),
                  const Text(
                    'Location & Details',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: ecoDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pickup.pickupAddress,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse(
                        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(pickup.pickupAddress)}',
                      );
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    icon: const Icon(Icons.navigation_rounded, size: 16),
                    label: const Text('View on Google Maps'),
                    style: TextButton.styleFrom(foregroundColor: ecoGreen),
                  ),

                  if (pickup.assignedAgentName != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FAF7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5EDE6)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.badge_rounded, color: ecoGreen),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Assigned Agent: ${pickup.assignedAgentName}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (pickup.assignedAgentPhone != null &&
                                    pickup.assignedAgentPhone!.isNotEmpty)
                                  Text(
                                    pickup.assignedAgentPhone!,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (pickup.status == 'pending') ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(sheetCtx).pop();
                          _cancelPickup(pickup);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB42318),
                          side: const BorderSide(color: Color(0xFFB42318)),
                        ),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel this Pickup Request'),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTimeline(PickupModel pickup) {
    final isCancelled = pickup.status == 'cancelled';
    final isAssigned =
        pickup.status == 'assigned' ||
        pickup.status == 'collected' ||
        pickup.status == 'recycled';
    final isCollected =
        pickup.status == 'collected' || pickup.status == 'recycled';
    final isRecycled = pickup.status == 'recycled';

    if (isCancelled) {
      return Row(
        children: [
          const Icon(Icons.cancel_rounded, color: Color(0xFFB42318), size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cancelled',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB42318),
                  ),
                ),
                Text(
                  'This pickup was cancelled by the user.',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _TimelineStep(
          title: 'Requested',
          subtitle:
              'Scheduled for ${pickup.scheduledDate.day}/${pickup.scheduledDate.month}/${pickup.scheduledDate.year}',
          isActive: true,
          isDone: true,
        ),
        _TimelineStep(
          title: 'Agent Assigned',
          subtitle: isAssigned
              ? (pickup.assignedAgentName ?? 'Agent Assigned')
              : 'Awaiting coordinator assignment',
          isActive: isAssigned,
          isDone: isCollected || isRecycled,
        ),
        _TimelineStep(
          title: 'Collected',
          subtitle: isCollected
              ? 'Collected by agent'
              : 'Pending pickup from address',
          isActive: isCollected,
          isDone: isRecycled,
        ),
        _TimelineStep(
          title: 'Recycled & Rewarded',
          subtitle: isRecycled
              ? 'Processed at recycling center • Reward credited!'
              : 'Final certified processing',
          isActive: isRecycled,
          isDone: isRecycled,
          isLast: true,
        ),
      ],
    );
  }

  Future<void> _showRewardsDialog() async {
    final auth = context.read<AuthProvider>();
    final rewardsData = await auth.getRewards();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (dialogCtx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.85,
          minChildSize: 0.45,
          builder: (context, scrollCtrl) {
            return SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF103B2E), Color(0xFF087F5B)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.stars_rounded,
                          color: Color(0xFFB9F6D3),
                          size: 48,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your Reward Balance',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${rewardsData?.totalPoints ?? 0} Points',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Points Earning History',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: ecoDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if ((rewardsData?.history ?? []).isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No reward points earned yet.\nPoints are credited once your e-waste is verified and recycled by our certified partners!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54, height: 1.5),
                        ),
                      ),
                    )
                  else
                    ...rewardsData!.history.map((tx) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5EDE6)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.recycling_rounded,
                              color: ecoGreen,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tx.category,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '${tx.quantity} item(s) • ${tx.weight.toStringAsFixed(1)} kg',
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDDF5E8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '+${tx.points} pts',
                                style: const TextStyle(
                                  color: ecoGreen,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showProfileDialog() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;

    final nameCtrl = TextEditingController(text: user?.name ?? '');
    final phoneCtrl = TextEditingController(text: user?.phone ?? '');
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'My Profile & Settings',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(dialogCtx);
                    final ok = await auth.updateProfile(
                      name: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                    );
                    if (ok) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Profile updated successfully!'),
                          backgroundColor: ecoGreen,
                        ),
                      );
                      nav.pop();
                    }
                  },
                  style: FilledButton.styleFrom(backgroundColor: ecoGreen),
                  child: const Text('Save Profile Changes'),
                ),
                const Divider(height: 32),
                const Text(
                  'Change Password',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: currentPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: newPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password (min 8 chars)',
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(dialogCtx);
                    final ok = await auth.changePassword(
                      currentPassword: currentPassCtrl.text,
                      newPassword: newPassCtrl.text,
                    );
                    if (ok) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Password changed successfully!'),
                          backgroundColor: ecoGreen,
                        ),
                      );
                      nav.pop();
                    } else if (auth.error != null) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(auth.error!),
                          backgroundColor: Colors.red.shade700,
                        ),
                      );
                    }
                  },
                  child: const Text('Update Password'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: ecoBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 22,
        title: const Row(
          children: [
            Icon(Icons.recycling_rounded, color: ecoGreen, size: 29),
            SizedBox(width: 9),
            Text(
              'E-Cycle',
              style: TextStyle(
                color: ecoDark,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'My Rewards',
            onPressed: _showRewardsDialog,
            icon: const Icon(Icons.stars_rounded, color: Color(0xFFC47A12)),
          ),
          IconButton(
            tooltip: 'Refresh pickups',
            onPressed: _loadPickups,
            icon: const Icon(Icons.refresh_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Account options',
            onSelected: (value) {
              if (value == 'logout') {
                auth.logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              } else if (value == 'profile') {
                _showProfileDialog();
              } else if (value == 'rewards') {
                _showRewardsDialog();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'rewards',
                child: Row(
                  children: [
                    Icon(Icons.stars_rounded, color: Color(0xFFC47A12)),
                    SizedBox(width: 10),
                    Text('My Rewards & Impact'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline_rounded),
                    SizedBox(width: 10),
                    Text('Profile & Security'),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Log out'),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: CircleAvatar(
                backgroundColor: const Color(0xFFDDF5E8),
                child: Text(
                  (user?.name.isNotEmpty ?? false)
                      ? user!.name[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    color: ecoGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openScheduleScreen,
        backgroundColor: ecoGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Schedule Pickup',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 850;

          return RefreshIndicator(
            onRefresh: () async {
              _loadPickups();
              try {
                await _pickupsFuture;
              } catch (_) {}
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: wide ? 38 : 20,
                vertical: 28,
              ),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${user?.name ?? 'Recycler'} 👋',
                          style: TextStyle(
                            color: ecoDark,
                            fontSize: wide ? 30 : 25,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Make a difference, one device at a time.',
                          style: TextStyle(color: Colors.black54, fontSize: 14),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: _showRewardsDialog,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDDF5E8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFB9F6D3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.stars_rounded,
                              color: ecoGreen,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${user?.rewardPoints ?? 0} pts',
                              style: const TextStyle(
                                color: ecoDark,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                _ImpactBanner(onSchedule: _openScheduleScreen),
                const SizedBox(height: 28),

                const Text(
                  'Your recycling activity',
                  style: TextStyle(
                    color: ecoDark,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 15),
                FutureBuilder<List<PickupModel>>(
                  future: _pickupsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (snapshot.hasError) {
                      return _MessageCard(
                        icon: Icons.cloud_off_rounded,
                        title: 'Could not load your activity',
                        message: snapshot.error.toString().replaceFirst(
                          'Exception: ',
                          '',
                        ),
                        actionLabel: 'Try again',
                        onAction: _loadPickups,
                      );
                    }

                    final pickups = snapshot.data ?? [];
                    final pending = pickups
                        .where((p) => p.status == 'pending')
                        .length;
                    final collected = pickups
                        .where(
                          (p) =>
                              p.status == 'collected' || p.status == 'recycled',
                        )
                        .length;
                    final weight = pickups.fold<double>(
                      0,
                      (total, p) =>
                          total +
                          ((p.status == 'collected' || p.status == 'recycled')
                              ? p.estimatedWeightKg
                              : 0),
                    );

                    final filteredPickups = pickups.where((p) {
                      if (_selectedStatusFilter == 'all') return true;
                      return p.status == _selectedStatusFilter;
                    }).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, box) {
                            final columns = box.maxWidth >= 650 ? 3 : 2;
                            final cardWidth =
                                (box.maxWidth - 12 * (columns - 1)) / columns;

                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: cardWidth,
                                  child: _StatCard(
                                    label: 'Total requests',
                                    value: '${pickups.length}',
                                    icon: Icons.inventory_2_outlined,
                                    color: const Color(0xFF2369B0),
                                  ),
                                ),
                                SizedBox(
                                  width: cardWidth,
                                  child: _StatCard(
                                    label: 'Awaiting pickup',
                                    value: '$pending',
                                    icon: Icons.schedule_rounded,
                                    color: const Color(0xFFC47A12),
                                  ),
                                ),
                                SizedBox(
                                  width: cardWidth,
                                  child: _StatCard(
                                    label: 'Collected / recycled',
                                    value: '$collected',
                                    icon: Icons.recycling_rounded,
                                    color: ecoGreen,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(19),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE6EDE7)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F5E9),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.scale_outlined,
                                  color: ecoGreen,
                                  size: 25,
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Estimated processed weight',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      'Diverted safely from electronic waste landfills',
                                      style: TextStyle(
                                        color: ecoDark,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${weight.toStringAsFixed(1)} kg',
                                style: const TextStyle(
                                  color: ecoGreen,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 19,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Filter by status chips
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Pickup Requests',
                                style: TextStyle(
                                  color: ecoDark,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              '${filteredPickups.length} showing',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _FilterStatusChip(
                              label: 'All',
                              isSelected: _selectedStatusFilter == 'all',
                              onSelected: () =>
                                  setState(() => _selectedStatusFilter = 'all'),
                            ),
                            _FilterStatusChip(
                              label: 'Pending',
                              isSelected: _selectedStatusFilter == 'pending',
                              onSelected: () => setState(
                                () => _selectedStatusFilter = 'pending',
                              ),
                            ),
                            _FilterStatusChip(
                              label: 'Assigned',
                              isSelected: _selectedStatusFilter == 'assigned',
                              onSelected: () => setState(
                                () => _selectedStatusFilter = 'assigned',
                              ),
                            ),
                            _FilterStatusChip(
                              label: 'Collected',
                              isSelected: _selectedStatusFilter == 'collected',
                              onSelected: () => setState(
                                () => _selectedStatusFilter = 'collected',
                              ),
                            ),
                            _FilterStatusChip(
                              label: 'Recycled',
                              isSelected: _selectedStatusFilter == 'recycled',
                              onSelected: () => setState(
                                () => _selectedStatusFilter = 'recycled',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        if (filteredPickups.isEmpty)
                          const _MessageCard(
                            icon: Icons.recycling_rounded,
                            title: 'No matching pickups found',
                            message: 'Try switching your filter or schedule a new pickup request.',
                          )
                        else
                          ...filteredPickups.map(
                            (pickup) => InkWell(
                              onTap: () => _showPickupDetails(pickup),
                              borderRadius: BorderRadius.circular(17),
                              child: _PickupCard(
                                pickup: pickup,
                                onCancel: () => _cancelPickup(pickup),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilterStatusChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterStatusChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: const Color(0xFFDDF5E8),
      labelStyle: TextStyle(
        color: isSelected ? ecoGreen : Colors.black87,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      side: BorderSide(color: isSelected ? ecoGreen : const Color(0xFFE5EDE6)),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isActive;
  final bool isDone;
  final bool isLast;

  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.isDone,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDone
        ? ecoGreen
        : (isActive ? const Color(0xFF2369B0) : Colors.grey.shade400);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isDone ? ecoGreen : Colors.white,
                  border: Border.all(color: color, width: 2),
                  shape: BoxShape.circle,
                ),
                child: isDone
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isDone ? ecoGreen : Colors.grey.shade300,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isActive ? ecoDark : Colors.black45,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImpactBanner extends StatelessWidget {
  final VoidCallback onSchedule;

  const _ImpactBanner({required this.onSchedule});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF103B2E), Color(0xFF087F5B)],
        ),
        borderRadius: BorderRadius.circular(23),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 460;

          final message = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A cleaner future starts with you.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Give old electronics a responsible second life.',
                style: TextStyle(color: Color(0xFFD8F3E4), height: 1.5),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onSchedule,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB9F6D3),
                  foregroundColor: ecoDark,
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Schedule a pickup'),
              ),
            ],
          );

          if (compact) return message;

          return Row(
            children: [
              Expanded(child: message),
              const SizedBox(width: 16),
              const Icon(
                Icons.energy_savings_leaf_rounded,
                size: 82,
                color: Color(0xFFB9F6D3),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 125),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EDE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 15),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              color: ecoDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _PickupCard extends StatelessWidget {
  final PickupModel pickup;
  final VoidCallback onCancel;

  const _PickupCard({required this.pickup, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final color = switch (pickup.status) {
      'pending' => const Color(0xFFC47A12),
      'assigned' => const Color(0xFF2369B0),
      'collected' => ecoGreen,
      'recycled' => const Color(0xFF168765),
      'cancelled' => const Color(0xFFB42318),
      _ => Colors.grey,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE6EDE7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE9F5ED),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.devices_rounded, color: ecoGreen, size: 25),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pickup.category,
                  style: const TextStyle(
                    color: ecoDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${pickup.scheduledDate.day.toString().padLeft(2, '0')}/'
                  '${pickup.scheduledDate.month.toString().padLeft(2, '0')}/'
                  '${pickup.scheduledDate.year}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  pickup.pickupAddress,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        pickup.status.toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Tap for details →',
                      style: TextStyle(color: Colors.black38, fontSize: 11),
                    ),
                  ],
                ),
                if (pickup.status == 'pending') ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.cancel_outlined, size: 17),
                      label: const Text('Cancel pickup'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFB42318),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${pickup.quantity} item${pickup.quantity == 1 ? '' : 's'}',
            style: const TextStyle(
              color: ecoDark,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EDE7)),
      ),
      child: Column(
        children: [
          Icon(icon, color: ecoGreen, size: 38),
          const SizedBox(height: 13),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ecoDark,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              height: 1.5,
              fontSize: 13,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
