import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/client_service.dart';
import '../../theme/premium_theme.dart';

class FinanceClientManagementPage extends StatefulWidget {
  const FinanceClientManagementPage({super.key});

  @override
  State<FinanceClientManagementPage> createState() =>
      _FinanceClientManagementPageState();
}

class _FinanceClientManagementPageState
    extends State<FinanceClientManagementPage> {
  bool _loading = false;
  List<Map<String, dynamic>> _clients = [];

  Future<void> _editClient(Map<String, dynamic> client) async {
    final id = client['id'];
    if (id == null) return;

    final nameController = TextEditingController(
        text: (client['company_name'] ?? client['name'] ?? '').toString());
    final holdingController = TextEditingController(
        text: (client['holding_information'] ?? '').toString());
    final addressController =
        TextEditingController(text: (client['address'] ?? '').toString());
    final contactNameController = TextEditingController(
        text: (client['contact_person'] ?? '').toString());
    final contactEmailController = TextEditingController(
        text: (client['client_contact_email'] ?? client['email'] ?? '')
            .toString());
    final contactMobileController = TextEditingController(
        text: (client['client_contact_mobile'] ?? client['phone'] ?? '')
            .toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Client'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Client Name'),
                ),
                TextField(
                  controller: holdingController,
                  decoration:
                      const InputDecoration(labelText: 'Holding / Group'),
                ),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                TextField(
                  controller: contactNameController,
                  decoration: const InputDecoration(labelText: 'Contact Name'),
                ),
                TextField(
                  controller: contactEmailController,
                  decoration: const InputDecoration(labelText: 'Contact Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextField(
                  controller: contactMobileController,
                  decoration:
                      const InputDecoration(labelText: 'Contact Mobile'),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    final token = AuthService.token;
    if (token == null) return;

    setState(() => _loading = true);
    try {
      final result = await ClientService.updateClient(
        token: token,
        clientId: id is int ? id : int.tryParse(id.toString()) ?? 0,
        companyName: nameController.text.trim(),
        email: contactEmailController.text.trim(),
        contactPerson: contactNameController.text.trim(),
        phone: contactMobileController.text.trim(),
        holdingInformation: holdingController.text.trim(),
        address: addressController.text.trim(),
        clientContactEmail: contactEmailController.text.trim(),
        clientContactMobile: contactMobileController.text.trim(),
      );

      final success = result != null && result['success'] == true;
      if (!success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update client')),
        );
        return;
      }

      await _loadClients();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteClient(Map<String, dynamic> client) async {
    final id = client['id'];
    if (id == null) return;

    final name =
        (client['company_name'] ?? client['name'] ?? '').toString().trim();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Client'),
        content: Text(
          name.isNotEmpty
              ? 'Delete "$name"? This cannot be undone.'
              : 'Delete this client? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: PremiumTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final token = AuthService.token;
    if (token == null) return;

    setState(() => _loading = true);
    try {
      final deleted = await ClientService.deleteClient(
        token: token,
        clientId: id is int ? id : int.tryParse(id.toString()) ?? 0,
      );
      if (!deleted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete client')),
        );
        return;
      }
      await _loadClients();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadClients());
  }

  Future<void> _loadClients() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final token = AuthService.token;
      if (token == null) return;
      final clients = await ClientService.getClients(token);
      if (!mounted) return;
      setState(() {
        _clients = List<Map<String, dynamic>>.from(clients);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Client Management',
          style: PremiumTheme.titleLarge.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 12),
        _buildAddClientCard(context),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: PremiumTheme.darkBg2.withOpacity(0.9),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: PremiumTheme.teal),
                  )
                : _clients.isEmpty
                    ? Center(
                        child: Text(
                          'No clients yet.',
                          style: PremiumTheme.bodyMedium
                              .copyWith(color: Colors.white70),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _clients.length,
                        separatorBuilder: (_, __) => Divider(
                          color: Colors.white.withOpacity(0.08),
                          height: 20,
                        ),
                        itemBuilder: (context, index) {
                          final c = _clients[index];
                          final name = (c['company_name'] ?? c['name'] ?? '')
                              .toString()
                              .trim();
                          final email = (c['email'] ?? '').toString().trim();
                          final contact =
                              (c['contact_person'] ?? '').toString().trim();

                          return ListTile(
                            title: Text(
                              name.isNotEmpty
                                  ? name
                                  : (email.isNotEmpty ? email : 'Client'),
                              style: PremiumTheme.bodyLarge
                                  .copyWith(color: Colors.white),
                            ),
                            subtitle: Text(
                              [
                                if (email.isNotEmpty) email,
                                if (contact.isNotEmpty) contact,
                              ].join(' • '),
                              style: PremiumTheme.bodyMedium
                                  .copyWith(color: Colors.white70),
                            ),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert,
                                  color: Colors.white70),
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  await _editClient(c);
                                } else if (value == 'delete') {
                                  await _deleteClient(c);
                                }
                              },
                              itemBuilder: (ctx) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddClientCard(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () async {
        final result =
            await Navigator.pushNamed(context, '/finance/clients/add');
        if (!mounted) return;
        if (result == true) {
          await _loadClients();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: PremiumTheme.darkBg2.withOpacity(0.85),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: PremiumTheme.tealGradient,
              ),
              child: const Icon(Icons.add, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Client',
                    style: PremiumTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Enter a new client and make it available for managers',
                    style:
                        PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }
}
