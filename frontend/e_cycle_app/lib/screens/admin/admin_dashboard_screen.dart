import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/admin_models.dart';
import '../../models/pickup_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_service.dart';
import '../../widgets/ec_auth_shell.dart';
import '../auth/login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminService _adminService = AdminService();

  int _selectedTabIndex = 0;
  bool _isLoading = false;
  String? _errorMessage;

  // Cached data
  AdminStatsModel? _stats;
  List<PickupModel> _pickups = [];
  List<AdminAgentModel> _agents = [];
  List<AdminUserModel> _users = [];
  AdminAnalyticsModel? _analytics;

  // Filters for Pickups tab
  String _pickupStatusFilter = 'all';
  String _pickupCategoryFilter = 'all';
  final TextEditingController _pickupSearchController = TextEditingController();
  final TextEditingController _userSearchController = TextEditingController();

  static const List<String> _categories = [
    'all',
    'Mobile Phones',
    'Laptops & Computers',
    'Batteries',
    'Televisions & Monitors',
    'Home Appliances',
    'Other Electronics',
  ];

  static const List<String> _statuses = [
    'all',
    'pending',
    'assigned',
    'collected',
    'recycled',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentTabData();
    });
  }

  @override
  void dispose() {
    _pickupSearchController.dispose();
    _userSearchController.dispose();
    super.dispose();
  }

  String? get _token => context.read<AuthProvider>().token;

  Future<void> _loadCurrentTabData() async {
    final token = _token;
    if (token == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_selectedTabIndex == 0) {
        // Overview
        final statsFuture = _adminService.getStats(token);
        final pickupsFuture = _adminService.getAllPickups(token, limit: 10);
        final results = await Future.wait([statsFuture, pickupsFuture]);
        _stats = results[0] as AdminStatsModel;
        _pickups = (results[1] as AdminPickupsResult).pickups;
      } else if (_selectedTabIndex == 1 || _selectedTabIndex == 2) {
        // Pickups or Assign tab
        final result = await _adminService.getAllPickups(
          token,
          status: _selectedTabIndex == 2 ? 'pending' : _pickupStatusFilter,
          category: _pickupCategoryFilter,
          search: _pickupSearchController.text,
        );
        _pickups = result.pickups;

        // If in assign tab, also load active agents
        if (_selectedTabIndex == 2) {
          _agents = await _adminService.getAgents(token, activeOnly: true);
        }
      } else if (_selectedTabIndex == 3) {
        // Agents
        _agents = await _adminService.getAgents(token, activeOnly: false);
      } else if (_selectedTabIndex == 4) {
        // Users
        _users = await _adminService.getUsers(
          token,
          search: _userSearchController.text,
        );
      } else if (_selectedTabIndex == 5) {
        // Analytics
        _analytics = await _adminService.getAnalytics(token);
      } else if (_selectedTabIndex == 6) {
        // Map coordination
        final result = await _adminService.getAllPickups(token, limit: 100);
        _pickups = result.pickups;
      } else if (_selectedTabIndex == 7) {
        // Reports
        _stats = await _adminService.getStats(token);
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAssignDialog(PickupModel pickup) async {
    final token = _token;
    if (token == null) return;

    List<AdminAgentModel> activeAgents = _agents;
    if (activeAgents.isEmpty) {
      try {
        activeAgents = await _adminService.getAgents(token, activeOnly: true);
      } catch (e) {
        _showToast(e.toString().replaceFirst('Exception: ', ''), error: true);
        return;
      }
    }

    if (activeAgents.isEmpty) {
      _showToast(
        'No active collection agents available. Please register or activate an agent first.',
        error: true,
      );
      return;
    }

    String? selectedAgentId = activeAgents.first.id;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.assignment_ind_rounded, color: ecoGreen),
                  SizedBox(width: 10),
                  Text(
                    'Assign Collection Agent',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pickup Category: ${pickup.category}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Items: ${pickup.quantity} (${pickup.estimatedWeightKg.toStringAsFixed(1)} kg)',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Address: ${pickup.pickupAddress}',
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const Divider(height: 24),
                  const Text(
                    'Select an active collection agent:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedAgentId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF7FAF7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: activeAgents.map((agent) {
                      return DropdownMenuItem(
                        value: agent.id,
                        child: Text(
                          '${agent.name} (${agent.assignedCount} active)',
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedAgentId = val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                  style: FilledButton.styleFrom(backgroundColor: ecoGreen),
                  child: const Text('Confirm Assignment'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && selectedAgentId != null) {
      try {
        await _adminService.assignPickup(
          token: token,
          pickupId: pickup.id,
          agentId: selectedAgentId!,
        );
        _showToast('Pickup successfully assigned to agent! 📋');
        _loadCurrentTabData();
      } catch (e) {
        _showToast(e.toString().replaceFirst('Exception: ', ''), error: true);
      }
    }
  }

  Future<void> _showCreateAgentDialog() async {
    final token = _token;
    if (token == null) return;

    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1_rounded, color: ecoGreen),
              SizedBox(width: 10),
              Text(
                'Register Collection Agent',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Agent Full Name',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (v) =>
                        (v?.trim().length ?? 0) < 2 ? 'Enter valid name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Agent Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (v) =>
                        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(v?.trim() ?? '')
                        ? 'Valid email required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Contact Phone',
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Initial Password (min 8 chars)',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (v) =>
                        (v?.length ?? 0) < 8 ? 'Minimum 8 characters' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(dialogCtx).pop(true);
                }
              },
              style: FilledButton.styleFrom(backgroundColor: ecoGreen),
              child: const Text('Create Agent'),
            ),
          ],
        );
      },
    );

    if (created == true) {
      try {
        await _adminService.createAgent(
          token: token,
          name: nameCtrl.text.trim(),
          email: emailCtrl.text.trim(),
          password: passCtrl.text,
          phone: phoneCtrl.text.trim(),
        );
        _showToast('Collection agent account created successfully! 👤');
        _loadCurrentTabData();
      } catch (e) {
        _showToast(e.toString().replaceFirst('Exception: ', ''), error: true);
      }
    }
  }

  Future<void> _toggleUserStatus(
    String userId,
    String name,
    bool currentStatus,
  ) async {
    final token = _token;
    if (token == null) return;

    final action = currentStatus ? 'deactivate' : 'activate';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Confirm $action'),
        content: Text(
          'Are you sure you want to $action the account for $name?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: currentStatus ? Colors.red.shade700 : ecoGreen,
            ),
            child: Text(action.toUpperCase()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _adminService.toggleUserStatus(token: token, userId: userId);
        _showToast(
          'Account successfully ${currentStatus ? "deactivated" : "activated"}!',
        );
        _loadCurrentTabData();
      } catch (e) {
        _showToast(e.toString().replaceFirst('Exception: ', ''), error: true);
      }
    }
  }

  void _showToast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFFB42318) : ecoGreen,
      ),
    );
  }

  void _logout() {
    context.read<AuthProvider>().logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final adminUser = context.watch<AuthProvider>().user;

    final sidebar = Container(
      width: 260,
      color: ecoDark,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
            child: const Row(
              children: [
                Icon(Icons.recycling_rounded, color: ecoMint, size: 32),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'E-Cycle Admin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Central Coordinator',
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _navItem(
                  0,
                  'Dashboard',
                  Icons.dashboard_outlined,
                  Icons.dashboard_rounded,
                ),
                _navItem(
                  1,
                  'All Pickups',
                  Icons.inventory_2_outlined,
                  Icons.inventory_2_rounded,
                ),
                _navItem(
                  2,
                  'Assign Pickups',
                  Icons.assignment_ind_outlined,
                  Icons.assignment_ind_rounded,
                ),
                _navItem(
                  3,
                  'Collection Agents',
                  Icons.badge_outlined,
                  Icons.badge_rounded,
                ),
                _navItem(
                  4,
                  'Users Directory',
                  Icons.people_outline_rounded,
                  Icons.people_rounded,
                ),
                _navItem(
                  5,
                  'Recycling Analytics',
                  Icons.bar_chart_outlined,
                  Icons.bar_chart_rounded,
                ),
                _navItem(
                  6,
                  'Map Locations',
                  Icons.map_outlined,
                  Icons.map_rounded,
                ),
                _navItem(
                  7,
                  'Reports & Summary',
                  Icons.description_outlined,
                  Icons.description_rounded,
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Admin Profile & Logout
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: ecoGreen,
                  foregroundColor: Colors.white,
                  child: Text(
                    (adminUser?.name.isNotEmpty ?? false)
                        ? adminUser!.name[0].toUpperCase()
                        : 'A',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        adminUser?.name ?? 'Admin',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const Text(
                        'Administrator',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                  tooltip: 'Log out',
                  onPressed: _logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: ecoBackground,
      appBar: wide
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              title: const Text(
                'E-Cycle Admin',
                style: TextStyle(color: ecoDark, fontWeight: FontWeight.w800),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _loadCurrentTabData,
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: _logout,
                ),
              ],
            ),
      drawer: wide ? null : Drawer(child: sidebar),
      body: Row(
        children: [
          if (wide) sidebar,
          Expanded(
            child: Column(
              children: [
                if (wide)
                  Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE5EDE6)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _getTabTitle(_selectedTabIndex),
                          style: const TextStyle(
                            color: ecoDark,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _loadCurrentTabData,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFDDF5E8),
                            foregroundColor: ecoDark,
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Refresh Data'),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                      ? Center(
                          child: _MessageCard(
                            icon: Icons.cloud_off_rounded,
                            title: 'Could not load admin data',
                            message: _errorMessage!,
                            actionLabel: 'Try again',
                            onAction: _loadCurrentTabData,
                          ),
                        )
                      : _buildActiveTabView(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(int index, String title, IconData icon, IconData activeIcon) {
    final isSelected = _selectedTabIndex == index;
    return ListTile(
      leading: Icon(
        isSelected ? activeIcon : icon,
        color: isSelected ? ecoMint : Colors.white70,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          fontSize: 13,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Colors.white.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      onTap: () {
        setState(() => _selectedTabIndex = index);
        _loadCurrentTabData();
      },
    );
  }

  String _getTabTitle(int index) {
    switch (index) {
      case 0:
        return 'System Overview & KPIs';
      case 1:
        return 'Pickup Requests Management';
      case 2:
        return 'Assign Pending Pickups';
      case 3:
        return 'Collection Agents Workload';
      case 4:
        return 'Registered Users Directory';
      case 5:
        return 'Recycling Trends & Analytics';
      case 6:
        return 'Pickup Geographic Map';
      case 7:
        return 'Executive Recycling Reports';
      default:
        return 'Admin Dashboard';
    }
  }

  Widget _buildActiveTabView() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildPickupsTab();
      case 2:
        return _buildAssignTab();
      case 3:
        return _buildAgentsTab();
      case 4:
        return _buildUsersTab();
      case 5:
        return _buildAnalyticsTab();
      case 6:
        return _buildMapTab();
      case 7:
        return _buildReportsTab();
      default:
        return _buildOverviewTab();
    }
  }

  // 1. OVERVIEW TAB
  Widget _buildOverviewTab() {
    final stats = _stats;
    if (stats == null) {
      return const Center(child: Text('No stats available'));
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Metric cards
        LayoutBuilder(
          builder: (context, box) {
            final columns = box.maxWidth >= 1000
                ? 4
                : (box.maxWidth >= 600 ? 2 : 1);
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 2.2,
              children: [
                _AdminMetricCard(
                  label: 'Total Pickups',
                  value: '${stats.totalPickups}',
                  subtitle: '${stats.pendingPickups} awaiting assignment',
                  icon: Icons.inventory_2_rounded,
                  color: const Color(0xFF2463B5),
                ),
                _AdminMetricCard(
                  label: 'Recycled Pickups',
                  value: '${stats.recycledPickups}',
                  subtitle: '${stats.collectedPickups} collected in transit',
                  icon: Icons.recycling_rounded,
                  color: ecoGreen,
                ),
                _AdminMetricCard(
                  label: 'Recycled Weight',
                  value: '${stats.totalRecycledWeightKg.toStringAsFixed(1)} kg',
                  subtitle:
                      '${stats.totalEstimatedWeightKg.toStringAsFixed(1)} kg estimated total',
                  icon: Icons.scale_rounded,
                  color: const Color(0xFF0F766E),
                ),
                _AdminMetricCard(
                  label: 'Registered Network',
                  value: '${stats.totalUsers + stats.totalAgents}',
                  subtitle:
                      '${stats.totalUsers} users • ${stats.totalAgents} agents',
                  icon: Icons.groups_rounded,
                  color: const Color(0xFF9333EA),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),

        // Status breakdown bar
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5EDE6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pickup Status Pipeline',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: ecoDark,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 10,
                children: [
                  _StatusIndicator(
                    label: 'Pending',
                    count: stats.pendingPickups,
                    color: const Color(0xFFC47A12),
                  ),
                  _StatusIndicator(
                    label: 'Assigned',
                    count: stats.assignedPickups,
                    color: const Color(0xFF2463B5),
                  ),
                  _StatusIndicator(
                    label: 'Collected',
                    count: stats.collectedPickups,
                    color: const Color(0xFF0F766E),
                  ),
                  _StatusIndicator(
                    label: 'Recycled',
                    count: stats.recycledPickups,
                    color: ecoGreen,
                  ),
                  _StatusIndicator(
                    label: 'Cancelled',
                    count: stats.cancelledPickups,
                    color: const Color(0xFFB42318),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Recent Requests
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Pickup Requests',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: ecoDark,
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() => _selectedTabIndex = 1);
                _loadCurrentTabData();
              },
              child: const Text('View All Pickups →'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_pickups.isEmpty)
          const _MessageCard(
            icon: Icons.inbox_outlined,
            title: 'No pickups found',
            message: 'User pickup requests will appear here.',
          )
        else
          ..._pickups
              .take(5)
              .map(
                (p) => _PickupAdminCard(
                  pickup: p,
                  onAssign: () => _showAssignDialog(p),
                ),
              ),
      ],
    );
  }

  // 2. PICKUPS TAB
  Widget _buildPickupsTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Filter bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5EDE6)),
          ),
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _pickupSearchController,
                  decoration: InputDecoration(
                    hintText: 'Search address or notes...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onSubmitted: (_) => _loadCurrentTabData(),
                ),
              ),
              DropdownButton<String>(
                value: _pickupStatusFilter,
                items: _statuses
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          s == 'all' ? 'All Statuses' : s.toUpperCase(),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _pickupStatusFilter = val);
                    _loadCurrentTabData();
                  }
                },
              ),
              DropdownButton<String>(
                value: _pickupCategoryFilter,
                items: _categories
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c == 'all' ? 'All Categories' : c),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _pickupCategoryFilter = val);
                    _loadCurrentTabData();
                  }
                },
              ),
              FilledButton.icon(
                onPressed: _loadCurrentTabData,
                style: FilledButton.styleFrom(backgroundColor: ecoGreen),
                icon: const Icon(Icons.filter_list_rounded, size: 18),
                label: const Text('Apply Filter'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '${_pickups.length} pickup requests found',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 14),

        if (_pickups.isEmpty)
          const _MessageCard(
            icon: Icons.inventory_2_outlined,
            title: 'No matching pickups',
            message: 'Try adjusting your search or status filter.',
          )
        else
          ..._pickups.map(
            (p) => _PickupAdminCard(
              pickup: p,
              onAssign: () => _showAssignDialog(p),
            ),
          ),
      ],
    );
  }

  // 3. ASSIGN TAB
  Widget _buildAssignTab() {
    final pendingPickups = _pickups
        .where((p) => p.status == 'pending')
        .toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFDDF5E8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFB9F6D3)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.assignment_ind_rounded,
                color: ecoGreen,
                size: 30,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Assign Pickups to Agents',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: ecoDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pendingPickups.length} pending pickup(s) eligible for agent assignment.',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (pendingPickups.isEmpty)
          const _MessageCard(
            icon: Icons.check_circle_outline_rounded,
            title: 'All pending pickups assigned!',
            message: 'No pending requests awaiting assignment right now.',
          )
        else
          ...pendingPickups.map(
            (p) => _PickupAdminCard(
              pickup: p,
              isAssignView: true,
              onAssign: () => _showAssignDialog(p),
            ),
          ),
      ],
    );
  }

  // 4. AGENTS TAB
  Widget _buildAgentsTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_agents.length} Collection Agents',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: ecoDark,
              ),
            ),
            FilledButton.icon(
              onPressed: _showCreateAgentDialog,
              style: FilledButton.styleFrom(backgroundColor: ecoGreen),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add New Agent'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_agents.isEmpty)
          _MessageCard(
            icon: Icons.badge_outlined,
            title: 'No collection agents yet',
            message: 'Click "Add New Agent" above to register an agent.',
            actionLabel: 'Add Agent',
            onAction: _showCreateAgentDialog,
          )
        else
          ..._agents.map((agent) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5EDE6)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: agent.isActive
                        ? const Color(0xFFDDF5E8)
                        : Colors.grey.shade200,
                    foregroundColor: agent.isActive ? ecoGreen : Colors.grey,
                    child: Text(
                      agent.name.isNotEmpty ? agent.name[0].toUpperCase() : 'A',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              agent.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: ecoDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: agent.isActive
                                    ? Colors.green.shade50
                                    : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                agent.isActive ? 'ACTIVE' : 'INACTIVE',
                                style: TextStyle(
                                  color: agent.isActive
                                      ? ecoGreen
                                      : Colors.red.shade700,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${agent.email}  •  ${agent.phone}',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Workload: ${agent.assignedCount} assigned  •  ${agent.collectedCount} collected  •  ${agent.recycledCount} recycled',
                          style: const TextStyle(
                            color: ecoDark,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: agent.isActive,
                    activeThumbColor: ecoGreen,
                    onChanged: (_) =>
                        _toggleUserStatus(agent.id, agent.name, agent.isActive),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // 5. USERS TAB
  Widget _buildUsersTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _userSearchController,
                decoration: InputDecoration(
                  hintText: 'Search users by name, email, or phone...',
                  prefixIcon: const Icon(Icons.search),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSubmitted: (_) => _loadCurrentTabData(),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _loadCurrentTabData,
              style: FilledButton.styleFrom(backgroundColor: ecoGreen),
              icon: const Icon(Icons.search),
              label: const Text('Search'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          '${_users.length} registered users',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 14),

        if (_users.isEmpty)
          const _MessageCard(
            icon: Icons.people_outline_rounded,
            title: 'No users found',
            message: 'Try searching with a different term.',
          )
        else
          ..._users.map((user) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5EDE6)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFFDDF5E8),
                    foregroundColor: ecoGreen,
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: ecoDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${user.email}  •  ${user.phone.isNotEmpty ? user.phone : "No phone"}',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F5E9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${user.rewardPoints} Reward Points 🌟',
                                style: const TextStyle(
                                  color: ecoGreen,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${user.pickupCount} pickup request(s)',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: user.isActive,
                    activeThumbColor: ecoGreen,
                    onChanged: (_) =>
                        _toggleUserStatus(user.id, user.name, user.isActive),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // 6. ANALYTICS TAB
  Widget _buildAnalyticsTab() {
    final analytics = _analytics;
    if (analytics == null) {
      return const Center(child: Text('No analytics data available'));
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Category Distribution
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5EDE6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'E-Waste Categories Breakdown',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: ecoDark,
                ),
              ),
              const SizedBox(height: 16),
              if (analytics.categories.isEmpty)
                const Text(
                  'No pickup category records yet.',
                  style: TextStyle(color: Colors.black54),
                )
              else
                ...analytics.categories.map((cat) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            cat.category,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${cat.count} items',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          '${cat.weight.toStringAsFixed(1)} kg',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: ecoGreen,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Agent Leaderboard
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5EDE6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Agent Collection Leaderboard',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: ecoDark,
                ),
              ),
              const SizedBox(height: 16),
              if (analytics.agentPerformance.isEmpty)
                const Text(
                  'No agent performance data recorded yet.',
                  style: TextStyle(color: Colors.black54),
                )
              else
                ...analytics.agentPerformance.map((rank) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7FAF7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.emoji_events_rounded,
                          color: Color(0xFFC47A12),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rank.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: ecoDark,
                                ),
                              ),
                              Text(
                                rank.email,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${rank.recycledCount} Recycled',
                          style: const TextStyle(
                            color: ecoGreen,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  // 7. MAP VIEW TAB
  Widget _buildMapTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFDDF5E8),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            children: [
              Icon(Icons.map_rounded, color: ecoGreen, size: 32),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pickup Geographic Coordination',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: ecoDark,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Coordinate collection routes with integrated Google Maps directions.',
                      style: TextStyle(color: Colors.black87, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ..._pickups.map((pickup) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5EDE6)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: ecoGreen,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pickup.category,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: ecoDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pickup.pickupAddress,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 13,
                        ),
                      ),
                      if (pickup.latitude != null && pickup.longitude != null)
                        Text(
                          'GPS: ${pickup.latitude}, ${pickup.longitude}',
                          style: const TextStyle(
                            color: Colors.black45,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(
                      pickup.latitude != null && pickup.longitude != null
                          ? 'https://www.google.com/maps/search/?api=1&query=${pickup.latitude},${pickup.longitude}'
                          : 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(pickup.pickupAddress)}',
                    );
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const Text('Open Map'),
                  style: TextButton.styleFrom(foregroundColor: ecoGreen),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // 8. REPORTS TAB
  Widget _buildReportsTab() {
    final stats = _stats;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5EDE6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.assessment_rounded, color: ecoGreen, size: 30),
                  SizedBox(width: 12),
                  Text(
                    'E-Cycle Executive Environmental Report',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: ecoDark,
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              _ReportRow(
                label: 'Total Electronic Waste Diverted from Landfill',
                value:
                    '${stats?.totalRecycledWeightKg.toStringAsFixed(1) ?? "0"} kg',
              ),
              _ReportRow(
                label: 'Estimated Equivalent CO2 Emissions Saved',
                value:
                    '${((stats?.totalRecycledWeightKg ?? 0) * 1.8).toStringAsFixed(1)} kg CO2e',
              ),
              _ReportRow(
                label: 'Total Certified Recycled Pickups',
                value: '${stats?.recycledPickups ?? 0} completed',
              ),
              _ReportRow(
                label: 'Active Collection Personnel',
                value: '${stats?.totalAgents ?? 0} agents',
              ),
              _ReportRow(
                label: 'Participating Recycler Community',
                value: '${stats?.totalUsers ?? 0} households & businesses',
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAF7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'All statistics are calculated from verified collection and recycling events in the E-Cycle MongoDB database.',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReportRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: ecoGreen,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusIndicator({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.black54, fontSize: 13),
        ),
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _AdminMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _AdminMetricCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5EDE6)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: ecoDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickupAdminCard extends StatelessWidget {
  final PickupModel pickup;
  final VoidCallback onAssign;
  final bool isAssignView;

  const _PickupAdminCard({
    required this.pickup,
    required this.onAssign,
    this.isAssignView = false,
  });

  Color get _statusColor {
    switch (pickup.status) {
      case 'pending':
        return const Color(0xFFC47A12);
      case 'assigned':
        return const Color(0xFF2463B5);
      case 'collected':
        return const Color(0xFF0F766E);
      case 'recycled':
        return ecoGreen;
      case 'cancelled':
        return const Color(0xFFB42318);
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5EDE6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE5F5EC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.devices_rounded, color: ecoGreen, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      pickup.category,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: ecoDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        pickup.status.toUpperCase(),
                        style: TextStyle(
                          color: _statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Scheduled: $dateStr  •  ${pickup.quantity} item(s)  •  ${pickup.estimatedWeightKg.toStringAsFixed(1)} kg',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  pickup.pickupAddress,
                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                ),
                if (pickup.assignedAgentName != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Assigned to: ${pickup.assignedAgentName} (${pickup.assignedAgentPhone ?? ""})',
                    style: const TextStyle(
                      color: Color(0xFF2463B5),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (pickup.status == 'pending') ...[
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: onAssign,
              style: FilledButton.styleFrom(backgroundColor: ecoGreen),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
              label: const Text('Assign Agent'),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5EDE6)),
      ),
      child: Column(
        children: [
          Icon(icon, color: ecoGreen, size: 40),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: ecoDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(backgroundColor: ecoGreen),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
