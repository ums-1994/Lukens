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
                            trailing: Text(
                              (c['status'] ?? '').toString(),
                              style: PremiumTheme.labelMedium
                                  .copyWith(color: Colors.white70),
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
