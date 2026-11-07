import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/agent_pickup_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/agent_service.dart';
import '../../widgets/ec_auth_shell.dart';
import '../auth/login_screen.dart';

class AgentDashboardScreen extends StatefulWidget {
  const AgentDashboardScreen({super.key});

  @override
  State<AgentDashboardScreen> createState() => _AgentDashboardScreenState();
}

class _AgentDashboardScreenState extends State<AgentDashboardScreen> {
  final AgentService _service = AgentService();
  late Future<List<AgentPickupModel>> _pickupsFuture;
  final Set<String> _updatingIds = {};
  String _selectedFilter = 'all'; // all, today, pending, completed

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
      _pickupsFuture = token == null || token.isEmpty
          ? Future.error('Please sign in again to view assigned pickups.')
          : _service.getAssignedPickups(token);
    });
  }

  Future<void> _confirmAndUpdateStatus(
    AgentPickupModel pickup,
    String nextStatus,
  ) async {
    final isCollecting = nextStatus == 'collected';
    final actionName = isCollecting ? 'Mark as Collected' : 'Mark as Recycled';
    final actionDescription = isCollecting
        ? 'Confirm that you have picked up ${pickup.quantity} item(s) (${pickup.category}) from ${pickup.requesterName} at ${pickup.pickupAddress}?'
        : 'Confirm that ${pickup.quantity} item(s) (${pickup.estimatedWeightKg.toStringAsFixed(1)} kg) have been delivered to the certified recycling center? Reward points will be credited to the customer.';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isCollecting
                  ? Icons.local_shipping_rounded
                  : Icons.recycling_rounded,
              color: ecoGreen,
            ),
            const SizedBox(width: 10),
            Text(
              actionName,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Text(
          actionDescription,
          style: const TextStyle(height: 1.5, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: ecoGreen),
            child: Text(actionName),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) {
      _showMessage('Session expired. Please sign in again.', error: true);
      return;
    }

    setState(() => _updatingIds.add(pickup.id));
    try {
      await _service.updatePickupStatus(
        token: token,
        pickupId: pickup.id,
        status: nextStatus,
      );

      if (!mounted) return;
      _showMessage(
        isCollecting
            ? 'Pickup successfully marked as collected! 📦'
            : 'Pickup successfully recycled! Rewards credited to user. ♻️',
      );
      _loadPickups();
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _updatingIds.remove(pickup.id));
    }
  }

  Future<void> _openDirections(AgentPickupModel pickup) async {
    Uri uri;
    if (pickup.latitude != null && pickup.longitude != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${pickup.latitude},${pickup.longitude}',
      );
    } else {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(pickup.pickupAddress)}',
      );
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showMessage('Could not launch maps application.', error: true);
    }
  }

  Future<void> _callCustomer(String phone) async {
    if (phone.isEmpty) {
      _showMessage('Customer contact number not available.', error: true);
      return;
    }

    final uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showMessage('Could not initiate phone call.', error: true);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFFB42318) : ecoGreen,
      ),
    );
  }

  Future<void> _logout() async {
    context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final agentName = auth.user?.name ?? 'Collection Agent';

    return Scaffold(
      backgroundColor: ecoBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Row(
          children: [
            Icon(Icons.recycling_rounded, color: ecoGreen, size: 28),
            SizedBox(width: 9),
            Text(
              'E-Cycle Agent Portal',
              style: TextStyle(
                color: ecoDark,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh assigned pickups',
            onPressed: _loadPickups,
            icon: const Icon(Icons.refresh_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') _logout();
            },
            itemBuilder: (_) => const [
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
                foregroundColor: ecoGreen,
                child: Text(
                  agentName.isNotEmpty ? agentName[0].toUpperCase() : 'A',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadPickups(),
        child: FutureBuilder<List<AgentPickupModel>>(
          future: _pickupsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _MessageCard(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load assigned pickups',
                    message: snapshot.error.toString().replaceFirst(
                      'Exception: ',
                      '',
                    ),
                    actionLabel: 'Try again',
                    onAction: _loadPickups,
                  ),
                ),
              );
            }

            final allPickups = snapshot.data ?? [];
            final pending = allPickups
                .where((p) => p.status == 'assigned')
                .length;
            final collected = allPickups
                .where((p) => p.status == 'collected')
                .length;
            final recycled = allPickups
                .where((p) => p.status == 'recycled')
                .length;
            final todayCount = allPickups
                .where((p) => _isToday(p.scheduledDate))
                .length;

            final displayedPickups = allPickups.where((p) {
              switch (_selectedFilter) {
                case 'today':
                  return _isToday(p.scheduledDate);
                case 'pending':
                  return p.status == 'assigned';
                case 'completed':
                  return p.status == 'collected' || p.status == 'recycled';
                default:
                  return true;
              }
            }).toList();

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Hello, $agentName 👋',
                  style: const TextStyle(
                    color: ecoDark,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Manage your scheduled collections, route directions, and recycling verification.',
                  style: TextStyle(color: Colors.black54, height: 1.5),
                ),
                const SizedBox(height: 22),

                // Statistics Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 900 ? 4 : 2;
                    return GridView.count(
                      crossAxisCount: columns,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: columns == 4 ? 2.5 : 2.4,
                      children: [
                        _StatCard(
                          label: "Today's Pickups",
                          value: '$todayCount',
                          icon: Icons.today_rounded,
                          iconColor: const Color(0xFF087F5B),
                        ),
                        _StatCard(
                          label: 'Pending Collection',
                          value: '$pending',
                          icon: Icons.assignment_outlined,
                          iconColor: const Color(0xFFB76A00),
                        ),
                        _StatCard(
                          label: 'Collected / Transit',
                          value: '$collected',
                          icon: Icons.local_shipping_outlined,
                          iconColor: const Color(0xFF2463B5),
                        ),
                        _StatCard(
                          label: 'Recycled & Verified',
                          value: '$recycled',
                          icon: Icons.recycling_rounded,
                          iconColor: const Color(0xFF168765),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),

                // Filter tabs
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Assigned Workload',
                        style: TextStyle(
                          color: ecoDark,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${displayedPickups.length} of ${allPickups.length}',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChip(
                      label: 'All (${allPickups.length})',
                      isSelected: _selectedFilter == 'all',
                      onSelected: () => setState(() => _selectedFilter = 'all'),
                    ),
                    _FilterChip(
                      label: 'Today ($todayCount)',
                      isSelected: _selectedFilter == 'today',
                      onSelected: () =>
                          setState(() => _selectedFilter = 'today'),
                    ),
                    _FilterChip(
                      label: 'Pending Collection ($pending)',
                      isSelected: _selectedFilter == 'pending',
                      onSelected: () =>
                          setState(() => _selectedFilter = 'pending'),
                    ),
                    _FilterChip(
                      label: 'Completed (${collected + recycled})',
                      isSelected: _selectedFilter == 'completed',
                      onSelected: () =>
                          setState(() => _selectedFilter = 'completed'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                if (displayedPickups.isEmpty)
                  const _MessageCard(
                    icon: Icons.inbox_outlined,
                    title: 'No pickups match this filter',
                    message: 'Pickups assigned to you will show up here based on your selected criteria.',
                  )
                else
                  ...displayedPickups.map((pickup) {
                    final busy = _updatingIds.contains(pickup.id);
                    final nextStatus = pickup.status == 'assigned'
                        ? 'collected'
                        : pickup.status == 'collected'
                        ? 'recycled'
                        : null;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _AgentPickupCard(
                        pickup: pickup,
                        busy: busy,
                        nextStatus: nextStatus,
                        onUpdate: nextStatus == null
                            ? null
                            : () => _confirmAndUpdateStatus(pickup, nextStatus),
                        onOpenDirections: () => _openDirections(pickup),
                        onCall: () => _callCustomer(pickup.requesterPhone),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({
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
      ),
      side: BorderSide(color: isSelected ? ecoGreen : const Color(0xFFE1E9E3)),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E9E3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: ecoDark,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentPickupCard extends StatelessWidget {
  final AgentPickupModel pickup;
  final bool busy;
  final String? nextStatus;
  final VoidCallback? onUpdate;
  final VoidCallback onOpenDirections;
  final VoidCallback onCall;

  const _AgentPickupCard({
    required this.pickup,
    required this.busy,
    required this.nextStatus,
    required this.onUpdate,
    required this.onOpenDirections,
    required this.onCall,
  });

  Color get _statusColor {
    switch (pickup.status) {
      case 'assigned':
        return const Color(0xFFB76A00);
      case 'collected':
        return const Color(0xFF2463B5);
      case 'recycled':
        return ecoGreen;
      default:
        return Colors.black54;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${pickup.scheduledDate.day.toString().padLeft(2, '0')}/'
        '${pickup.scheduledDate.month.toString().padLeft(2, '0')}/'
        '${pickup.scheduledDate.year}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1E9E3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F5EC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.devices_other_rounded, color: ecoGreen),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pickup.category,
                      style: const TextStyle(
                        color: ecoDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Scheduled: $dateStr  •  ${pickup.quantity} item(s)  •  ${pickup.estimatedWeightKg.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  pickup.status.toUpperCase(),
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 28),

          // Customer details
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.person_outline_rounded,
                size: 18,
                color: Colors.black45,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pickup.requesterName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ecoDark,
                    fontSize: 14,
                  ),
                ),
              ),
              if (pickup.requesterPhone.isNotEmpty)
                IconButton(
                  icon: const Icon(
                    Icons.phone_in_talk_rounded,
                    color: ecoGreen,
                    size: 20,
                  ),
                  tooltip: 'Call customer',
                  onPressed: onCall,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),

          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 18,
                color: Colors.black45,
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
              TextButton.icon(
                onPressed: onOpenDirections,
                icon: const Icon(Icons.navigation_rounded, size: 16),
                label: const Text('Directions'),
                style: TextButton.styleFrom(
                  foregroundColor: ecoGreen,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),

          if (pickup.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAF7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Notes: ${pickup.description}',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ),
          ],

          if (nextStatus != null) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: busy ? null : onUpdate,
                style: FilledButton.styleFrom(
                  backgroundColor: ecoGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        nextStatus == 'collected'
                            ? Icons.local_shipping_rounded
                            : Icons.recycling_rounded,
                      ),
                label: Text(
                  busy
                      ? 'Processing...'
                      : nextStatus == 'collected'
                      ? 'Mark as Collected'
                      : 'Mark as Recycled & Credit Points',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
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
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1E9E3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: ecoGreen, size: 42),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ecoDark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, height: 1.5),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
