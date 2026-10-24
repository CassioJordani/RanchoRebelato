import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/cpf.dart';
import '../models/enrollment.dart';
import '../models/expense.dart';
import '../models/monthly_expense_report.dart';
import '../models/organization_member.dart';
import '../models/student.dart';
import '../models/user_role.dart';
import '../models/workshop_class.dart';
import '../services/auth_services.dart';
import '../services/firestore_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.authService});

  final AuthService authService;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _firestoreService = FirestoreService();
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserRole?>(
      stream: _firestoreService.watchCurrentUserRole(),
      builder: (context, snapshot) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_titleForIndex(_selectedIndex)),
            actions: [
              IconButton(
                tooltip: 'Sair',
                onPressed: widget.authService.logout,
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: _buildBody(snapshot),
        );
      },
    );
  }

  Widget _buildBody(AsyncSnapshot<UserRole?> roleSnapshot) {
    if (widget.authService.initializationError != null) {
      return _MessageView(
        icon: Icons.cloud_off_outlined,
        title: 'Não foi possível configurar o acesso',
        message:
            '${_errorMessage(widget.authService.initializationError!)} '
            'Verifique se as regras atualizadas do Firestore foram publicadas e entre novamente.',
        action: TextButton.icon(
          onPressed: widget.authService.logout,
          icon: const Icon(Icons.logout),
          label: const Text('Sair e tentar novamente'),
        ),
      );
    }
    if (roleSnapshot.hasError) {
      return _MessageView(
        icon: Icons.cloud_off_outlined,
        title: 'Não foi possível carregar seu perfil',
        message: _errorMessage(roleSnapshot.error!),
      );
    }
    if (roleSnapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    final role = roleSnapshot.data;
    if (role == null) {
      return _MessageView(
        icon: Icons.lock_outline,
        title: 'Conta ainda não vinculada ao Rancho',
        message:
            'No Firestore, crie organizations/${FirestoreService.organizationId}/members/${widget.authService.usuario!.uid} '
            'com um campo role: admin, coordinator, instructor ou viewer. '
            'Depois volte a entrar no aplicativo.',
        action: TextButton.icon(
          onPressed: widget.authService.logout,
          icon: const Icon(Icons.logout),
          label: const Text('Sair'),
        ),
      );
    }

    final tabs = _tabsForRole(role);
    if (_selectedIndex >= tabs.length) _selectedIndex = 0;
    final tab = tabs[_selectedIndex];
    return Column(
      children: [
        Expanded(child: tab.builder(context, role, _firestoreService)),
        if (role != UserRole.instructor)
          NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _navigate,
            destinations: tabs
                .map(
                  (tab) => NavigationDestination(
                    icon: Icon(tab.icon),
                    label: tab.label,
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  List<_HomeTab> _tabsForRole(UserRole role) {
    if (role == UserRole.instructor) {
      return [
        _HomeTab(
          label: 'Minhas turmas',
          icon: Icons.menu_book_outlined,
          builder: (context, role, service) =>
              _ClassesPage(role: role, service: service),
        ),
      ];
    }
    return [
      _HomeTab(
        label: 'Resumo',
        icon: Icons.dashboard_outlined,
        builder: (context, role, service) =>
            _DashboardPage(role: role, service: service, onNavigate: _navigate),
      ),
      _HomeTab(
        label: 'Turmas',
        icon: Icons.menu_book_outlined,
        builder: (context, role, service) =>
            _ClassesPage(role: role, service: service),
      ),
      _HomeTab(
        label: 'Alunos',
        icon: Icons.people_outline,
        builder: (context, role, service) =>
            _StudentsPage(role: role, service: service),
      ),
      if (role != UserRole.viewer)
        _HomeTab(
          label: 'Despesas',
          icon: Icons.receipt_long_outlined,
          builder: (context, role, service) =>
              _ExpensesPage(role: role, service: service),
        ),
      if (role == UserRole.admin || role == UserRole.coordinator)
        _HomeTab(
          label: 'Usuários',
          icon: Icons.manage_accounts_outlined,
          builder: (context, role, service) =>
              _MembersPage(service: service, currentUid: _currentUid),
        ),
    ];
  }

  void _navigate(int index) {
    setState(() => _selectedIndex = index);
  }

  String get _currentUid => widget.authService.usuario!.uid;

  String _titleForIndex(int index) {
    if (index == 0) return 'Rancho Rebelato';
    if (index == 1) return 'Turmas';
    if (index == 2) return 'Alunos';
    if (index == 3) return 'Relatório de despesas';
    return 'Usuários';
  }
}

class _HomeTab {
  const _HomeTab({
    required this.label,
    required this.icon,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final Widget Function(
    BuildContext context,
    UserRole role,
    FirestoreService service,
  )
  builder;
}

class _DashboardPage extends StatelessWidget {
  const _DashboardPage({
    required this.role,
    required this.service,
    required this.onNavigate,
  });

  final UserRole role;
  final FirestoreService service;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Visão geral', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('Acompanhe as oficinas, os alunos e os gastos do Rancho.'),
        const SizedBox(height: 20),
        StreamBuilder<List<WorkshopClass>>(
          stream: service.watchClasses(role: role),
          builder: (context, snapshot) {
            if (snapshot.hasError) return _InlineError(error: snapshot.error!);
            if (!snapshot.hasData) {
              return const LinearProgressIndicator();
            }
            final classes = snapshot.data!;
            return _SummaryCard(
              icon: Icons.menu_book_outlined,
              title: 'Turmas ativas',
              value: '${classes.where((item) => item.isActive).length}',
              onTap: () => onNavigate(1),
            );
          },
        ),
        const SizedBox(height: 12),
        if (role == UserRole.viewer)
          _SummaryCard(
            icon: Icons.people_outline,
            title: 'Dados dos alunos',
            value: 'Acesso restrito',
            onTap: () => onNavigate(2),
          )
        else
          StreamBuilder<List<Student>>(
            stream: service.watchStudents(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _InlineError(error: snapshot.error!);
              }
              if (!snapshot.hasData) {
                return const LinearProgressIndicator();
              }
              final students = snapshot.data!
                  .where((student) => student.isActive)
                  .length;
              return _SummaryCard(
                icon: Icons.people_outline,
                title: 'Alunos ativos',
                value: '$students',
                onTap: () => onNavigate(2),
              );
            },
          ),
        const SizedBox(height: 12),
        if (role != UserRole.viewer)
          StreamBuilder<MonthlyExpenseReport>(
            stream: service.watchMonthlyExpenses(now),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _InlineError(error: snapshot.error!);
              }
              if (!snapshot.hasData) {
                return const LinearProgressIndicator();
              }
              return _SummaryCard(
                icon: Icons.payments_outlined,
                title: 'Despesas deste mês',
                value: _formatCurrency(snapshot.data!.totalCents),
                onTap: () => onNavigate(3),
              );
            },
          ),
        const SizedBox(height: 24),
        Text('Acesso rápido', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => onNavigate(1),
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Ver turmas'),
            ),
            OutlinedButton.icon(
              onPressed: () => onNavigate(2),
              icon: const Icon(Icons.people_outline),
              label: const Text('Ver alunos'),
            ),
            if (role != UserRole.viewer)
              OutlinedButton.icon(
                onPressed: () => onNavigate(3),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Ver despesas'),
              ),
          ],
        ),
      ],
    );
  }
}

class _ClassesPage extends StatelessWidget {
  const _ClassesPage({required this.role, required this.service});

  final UserRole role;
  final FirestoreService service;

  @override
  Widget build(BuildContext context) {
    final canManage = role == UserRole.admin || role == UserRole.coordinator;
    return Scaffold(
      body: StreamBuilder<List<WorkshopClass>>(
        stream: service.watchClasses(role: role),
        builder: (context, snapshot) {
          if (snapshot.hasError) return _ErrorView(error: snapshot.error!);
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final classes = snapshot.data!;
          if (classes.isEmpty) {
            return _EmptyView(
              icon: Icons.menu_book_outlined,
              title: 'Nenhuma turma cadastrada',
              message: canManage
                  ? 'Use o botão + para cadastrar a primeira turma.'
                  : 'As turmas atribuídas a você aparecerão aqui.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: classes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _ClassCard(
              workshopClass: classes[index],
              canManage: canManage,
              canReadMemberProfiles: role != UserRole.viewer,
              service: service,
            ),
          );
        },
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showClassForm(context, service),
              icon: const Icon(Icons.add),
              label: const Text('Nova turma'),
            )
          : null,
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.workshopClass,
    required this.canManage,
    required this.canReadMemberProfiles,
    required this.service,
  });

  final WorkshopClass workshopClass;
  final bool canManage;
  final bool canReadMemberProfiles;
  final FirestoreService service;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        controlAffinity: ListTileControlAffinity.leading,
        leading: CircleAvatar(
          child: Icon(_iconForCategory(workshopClass.category)),
        ),
        title: Text(workshopClass.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${workshopClass.category} · limite de ${workshopClass.capacity} alunos',
            ),
            if (canReadMemberProfiles)
              StreamBuilder<String?>(
                stream: service.watchMemberName(workshopClass.instructorUid),
                builder: (context, snapshot) => Text(
                  'Instrutor: ${snapshot.data ?? 'Não identificado'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              Text(
                'Instrutor: informação restrita',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              label: Text(workshopClass.isActive ? 'Ativa' : 'Inativa'),
              visualDensity: VisualDensity.compact,
            ),
            if (canManage)
              PopupMenuButton<String>(
                tooltip: 'Ações da turma',
                onSelected: (action) {
                  if (action == 'edit') {
                    _showClassForm(
                      context,
                      service,
                      workshopClass: workshopClass,
                    );
                  } else if (action == 'toggle') {
                    _setClassStatus(
                      context,
                      service,
                      workshopClass,
                      !workshopClass.isActive,
                    );
                  } else if (action == 'delete') {
                    _confirmDeleteClass(context, service, workshopClass);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Editar turma'),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(
                      workshopClass.isActive
                          ? 'Inativar turma'
                          : 'Ativar turma',
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Excluir turma'),
                  ),
                ],
              ),
          ],
        ),
        children: [
          StreamBuilder<List<Enrollment>>(
            stream: service.watchEnrollments(workshopClass.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: _InlineError(error: snapshot.error!),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                );
              }
              final enrollments = snapshot.data!;
              return Column(
                children: [
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.people_outline),
                    title: Text(
                      'Matrículas: ${enrollments.length}/${workshopClass.capacity}',
                    ),
                    subtitle: Text(
                      canReadMemberProfiles
                          ? 'Instrutor UID: ${workshopClass.instructorUid}'
                          : 'Instrutor: informação restrita',
                    ),
                  ),
                  if (enrollments.isNotEmpty)
                    ...enrollments.map(
                      (enrollment) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.school_outlined),
                        title: Text(enrollment.studentName),
                        subtitle: Text(
                          '${enrollment.status == 'active' ? 'Ativa' : 'Inativa'} · '
                          '${_dateLabel(enrollment.enrolledAt)}',
                        ),
                        trailing: canManage
                            ? IconButton(
                                tooltip: 'Editar matrícula',
                                onPressed: () => _showEnrollmentForm(
                                  context,
                                  service,
                                  workshopClass,
                                  enrollment: enrollment,
                                ),
                                icon: const Icon(Icons.edit_outlined),
                              )
                            : null,
                      ),
                    ),
                  if (canManage)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed:
                                enrollments.length >= workshopClass.capacity
                                ? null
                                : () => _showEnrollmentForm(
                                    context,
                                    service,
                                    workshopClass,
                                  ),
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text('Matricular aluno'),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

enum _StudentFilter { all, active, inactive }

class _StudentsPage extends StatefulWidget {
  const _StudentsPage({required this.role, required this.service});

  final UserRole role;
  final FirestoreService service;

  @override
  State<_StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<_StudentsPage> {
  final _searchController = TextEditingController();
  _StudentFilter _filter = _StudentFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canManage =
        widget.role == UserRole.admin || widget.role == UserRole.coordinator;
    if (widget.role == UserRole.viewer) {
      return const Scaffold(
        body: _MessageView(
          icon: Icons.lock_outline,
          title: 'Dados pessoais restritos',
          message: 'A consulta a cadastros de alunos, incluindo CPF e endereço, está disponível apenas para administração e coordenação.',
        ),
      );
    }
    return Scaffold(
      body: StreamBuilder<List<Student>>(
        stream: widget.service.watchStudents(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return _ErrorView(error: snapshot.error!);
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final query = _normalizeSearch(_searchController.text);
          final cpfQuery = _digitsOnly(query);
          final students = snapshot.data!.where((student) {
            final statusMatches = switch (_filter) {
              _StudentFilter.all => true,
              _StudentFilter.active => student.isActive,
              _StudentFilter.inactive => !student.isActive,
            };
            final textMatches =
                query.isEmpty ||
                _normalizeSearch(
                  '${student.fullName} ${student.guardianName} '
                  '${student.guardianRelationship}',
                ).contains(query) ||
                (cpfQuery.isNotEmpty &&
                    (_digitsOnly(student.cpf).contains(cpfQuery) ||
                        _digitsOnly(student.guardianCpf).contains(cpfQuery)));
            return statusMatches && textMatches;
          }).toList();
          if (students.isEmpty) {
            return Column(
              children: [
                _studentSearchAndFilters(),
                Expanded(
                  child: _EmptyView(
                    icon: Icons.people_outline,
                    title: snapshot.data!.isEmpty
                        ? 'Nenhum aluno cadastrado'
                        : 'Nenhum aluno encontrado',
                    message: snapshot.data!.isEmpty && canManage
                        ? 'Use o botão + para cadastrar o primeiro aluno.'
                        : 'Altere a busca ou o filtro de status.',
                  ),
                ),
              ],
            );
          }
          return Column(
            children: [
              _studentSearchAndFilters(),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: students.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final student = students[index];
                    final details = <String>[
                      if (student.phone.isNotEmpty) 'Tel.: ${student.phone}',
                      if (student.cpf.isNotEmpty) 'CPF: ${student.cpf}',
                      if (student.birthDate != null)
                        'Nascimento: ${_dateLabel(student.birthDate!)}',
                      if (student.address.isNotEmpty)
                        'Endereço: ${student.address}',
                      if (student.guardianName.isNotEmpty)
                        'Responsável: ${student.guardianName}'
                            '${student.guardianRelationship.isEmpty ? '' : ' (${student.guardianRelationship})'}',
                      if (student.guardianCpf.isNotEmpty)
                        'CPF responsável: ${student.guardianCpf}',
                      if (student.guardianPhone.isNotEmpty)
                        'Tel. responsável: ${student.guardianPhone}',
                    ];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            student.fullName.isEmpty
                                ? '?'
                                : student.fullName
                                      .substring(0, 1)
                                      .toUpperCase(),
                          ),
                        ),
                        title: Text(student.fullName),
                        subtitle: Text(
                          details.isEmpty
                              ? 'Sem informações adicionais'
                              : details.join('\n'),
                        ),
                        isThreeLine: details.length > 1,
                        trailing: canManage
                            ? Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  IconButton(
                                    tooltip: 'Editar aluno',
                                    onPressed: () => _showStudentForm(
                                      context,
                                      widget.service,
                                      student: student,
                                    ),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  Switch(
                                    value: student.isActive,
                                    onChanged: (value) => _setStudentStatus(
                                      context,
                                      widget.service,
                                      student,
                                      value,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Excluir aluno',
                                    onPressed: () => _confirmDeleteStudent(
                                      context,
                                      widget.service,
                                      student,
                                    ),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              )
                            : Chip(
                                label: Text(
                                  student.isActive ? 'Ativo' : 'Inativo',
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showStudentForm(context, widget.service),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Novo aluno'),
            )
          : null,
    );
  }

  Widget _studentSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Buscar nome, responsável ou CPF',
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _studentFilterChip('Todos', _StudentFilter.all),
              _studentFilterChip('Ativos', _StudentFilter.active),
              _studentFilterChip('Inativos', _StudentFilter.inactive),
            ],
          ),
        ],
      ),
    );
  }

  Widget _studentFilterChip(String label, _StudentFilter filter) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == filter,
      onSelected: (_) => setState(() => _filter = filter),
    );
  }
}

class _MembersPage extends StatelessWidget {
  const _MembersPage({required this.service, required this.currentUid});

  final FirestoreService service;
  final String currentUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OrganizationMember>>(
      stream: service.watchMembers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _ErrorView(error: snapshot.error!);
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final members = snapshot.data!;
        if (members.isEmpty) {
          return const _EmptyView(
            icon: Icons.manage_accounts_outlined,
            title: 'Nenhum usuário encontrado',
            message: 'Contas que entrarem no app aparecerão aqui.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: members.length,
          separatorBuilder: (_, _) => const SizedBox(height: 4),
          itemBuilder: (context, index) {
            final member = members[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(
                    member.role == UserRole.viewer
                        ? Icons.visibility_outlined
                        : Icons.person_outline,
                  ),
                ),
                title: Text(
                  member.displayName.isEmpty
                      ? 'Usuário sem nome'
                      : member.displayName,
                ),
                subtitle: Text(
                  [
                    if (member.email.isNotEmpty) member.email,
                    'UID: ${member.uid}',
                    if (member.uid == currentUid) 'Você',
                  ].join('\n'),
                ),
                isThreeLine: true,
                trailing: DropdownButton<UserRole>(
                  value: member.role,
                  hint: const Text('Definir perfil'),
                  onChanged: (role) {
                    if (role != null && role != member.role) {
                      _updateRole(context, service, member, role);
                    }
                  },
                  items: UserRole.values
                      .map(
                        (role) => DropdownMenuItem(
                          value: role,
                          child: Text(_roleLabel(role)),
                        ),
                      )
                      .toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ExpensesPage extends StatefulWidget {
  const _ExpensesPage({required this.role, required this.service});

  final UserRole role;
  final FirestoreService service;

  @override
  State<_ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<_ExpensesPage> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final canManage =
        widget.role == UserRole.admin || widget.role == UserRole.coordinator;
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Mês anterior',
                  onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month - 1),
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _monthLabel(_month),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Próximo mês',
                  onPressed:
                      _month.year == DateTime.now().year &&
                          _month.month == DateTime.now().month
                      ? null
                      : () => setState(
                          () =>
                              _month = DateTime(_month.year, _month.month + 1),
                        ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<MonthlyExpenseReport>(
              stream: widget.service.watchMonthlyExpenses(_month),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ErrorView(error: snapshot.error!);
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final report = snapshot.data!;
                if (report.expenses.isEmpty) {
                  return _EmptyView(
                    icon: Icons.receipt_long_outlined,
                    title: 'Nenhuma despesa neste mês',
                    message: canManage
                        ? 'Use o botão + para registrar uma despesa.'
                        : 'Os lançamentos do mês aparecerão aqui.',
                    header: _TotalCard(totalCents: report.totalCents),
                  );
                }
                final categoryEntries = report.totalsByCategory.entries.toList()
                  ..sort(
                    (first, second) => second.value.compareTo(first.value),
                  );
                final largestCategoryTotal = categoryEntries.first.value;
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _TotalCard(totalCents: report.totalCents),
                    const SizedBox(height: 16),
                    Text(
                      'Total por categoria',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ...categoryEntries.indexed.map((item) {
                      final (index, entry) = item;
                      final color = _expenseCategoryColor(context, index);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: color.withValues(
                                      alpha: 0.14,
                                    ),
                                    child: Icon(
                                      Icons.sell_outlined,
                                      size: 18,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(entry.key)),
                                  Text(
                                    _formatCurrency(entry.value),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                value: entry.value / largestCategoryTotal,
                                minHeight: 6,
                                color: color,
                                backgroundColor: color.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Lançamentos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ...report.expenses.map((expense) {
                      final color = _expenseCategoryColor(
                        context,
                        categoryEntries.indexWhere(
                          (entry) => entry.key == expense.category,
                        ),
                      );
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.14),
                            child: Icon(
                              Icons.receipt_long_outlined,
                              color: color,
                            ),
                          ),
                          subtitle: Text(
                            '${expense.category} · ${_dateLabel(expense.occurredAt)}',
                          ),
                          isThreeLine: true,
                          title: Text(expense.description),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatCurrency(expense.amountCents),
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              if (widget.role == UserRole.admin)
                                PopupMenuButton<String>(
                                  tooltip: 'Ações da despesa',
                                  onSelected: (action) {
                                    if (action == 'edit') {
                                      _showExpenseForm(
                                        context,
                                        widget.service,
                                        expense: expense,
                                      );
                                    } else if (action == 'delete') {
                                      _confirmDeleteExpense(
                                        context,
                                        widget.service,
                                        expense,
                                      );
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Editar'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Excluir'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showExpenseForm(context, widget.service),
              icon: const Icon(Icons.add),
              label: const Text('Nova despesa'),
            )
          : null,
    );
  }
}

Color _expenseCategoryColor(BuildContext context, int index) {
  final scheme = Theme.of(context).colorScheme;
  final colors = [
    scheme.primary,
    scheme.tertiary,
    scheme.secondary,
    const Color(0xFFB85C38),
    const Color(0xFF52796F),
    const Color(0xFF6D597A),
  ];
  return colors[index % colors.length];
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.totalCents});

  final int totalCents;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [scheme.primary, scheme.primary.withValues(alpha: 0.78)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total de despesas no mês',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: Colors.white.withValues(alpha: 0.88)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatCurrency(totalCents),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        trailing: Text(value, style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({
    required this.icon,
    required this.title,
    required this.message,
    this.header,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ?header,
        const SizedBox(height: 48),
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 12),
        Text(title, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return _MessageView(
      icon: Icons.cloud_off_outlined,
      title: 'Erro ao carregar dados',
      message: _errorMessage(error),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Text(
      _errorMessage(error),
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }
}

class _StudentForm extends StatefulWidget {
  const _StudentForm({required this.service, this.student});

  final FirestoreService service;
  final Student? student;

  @override
  State<_StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends State<_StudentForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cpfController = TextEditingController();
  final _addressController = TextEditingController();
  final _guardianNameController = TextEditingController();
  final _guardianRelationshipController = TextEditingController();
  final _guardianPhoneController = TextEditingController();
  final _guardianCpfController = TextEditingController();
  DateTime? _birthDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final student = widget.student;
    if (student != null) {
      _nameController.text = student.fullName;
      _phoneController.text = student.phone;
      _cpfController.text = student.cpf;
      _addressController.text = student.address;
      _guardianNameController.text = student.guardianName;
      _guardianRelationshipController.text = student.guardianRelationship;
      _guardianPhoneController.text = student.guardianPhone;
      _guardianCpfController.text = student.guardianCpf;
      _birthDate = student.birthDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cpfController.dispose();
    _addressController.dispose();
    _guardianNameController.dispose();
    _guardianRelationshipController.dispose();
    _guardianPhoneController.dispose();
    _guardianCpfController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2010),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (selected != null) setState(() => _birthDate = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final student = Student(
        id: widget.student?.id ?? '',
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        isActive: widget.student?.isActive ?? true,
        cpf: _cpfController.text.trim(),
        birthDate: _birthDate,
        address: _addressController.text.trim(),
        guardianName: _guardianNameController.text.trim(),
        guardianRelationship: _guardianRelationshipController.text.trim(),
        guardianPhone: _guardianPhoneController.text.trim(),
        guardianCpf: _guardianCpfController.text.trim(),
      );
      if (widget.student == null) {
        await widget.service.createStudent(student);
      } else {
        await widget.service.updateStudent(student);
      }
      if (mounted) Navigator.pop(context);
    } on FirebaseException catch (error) {
      if (mounted) _showSaveError(context, error);
    } on StateError catch (error) {
      if (mounted) _showSaveError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.student == null ? 'Novo aluno' : 'Editar aluno'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: widget.student == null,
                  decoration: const InputDecoration(labelText: 'Nome completo'),
                  validator: _required,
                ),
                TextFormField(
                  controller: _cpfController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'CPF do aluno'),
                  validator: _cpfValidator,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Data de nascimento'),
                  subtitle: Text(
                    _birthDate == null
                        ? 'Não informada'
                        : _dateLabel(_birthDate!),
                  ),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: _saving ? null : _pickBirthDate,
                ),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefone'),
                ),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Endereço'),
                  maxLines: 2,
                ),
                const Divider(),
                TextFormField(
                  controller: _guardianNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do responsável',
                  ),
                ),
                TextFormField(
                  controller: _guardianRelationshipController,
                  decoration: const InputDecoration(
                    labelText: 'Parentesco/relação',
                  ),
                ),
                TextFormField(
                  controller: _guardianCpfController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'CPF do responsável',
                  ),
                  validator: _cpfValidator,
                ),
                TextFormField(
                  controller: _guardianPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefone do responsável',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}

class _ClassForm extends StatefulWidget {
  const _ClassForm({required this.service, this.workshopClass});

  final FirestoreService service;
  final WorkshopClass? workshopClass;

  @override
  State<_ClassForm> createState() => _ClassFormState();
}

class _ClassFormState extends State<_ClassForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _capacityController = TextEditingController(text: '15');
  String? _selectedInstructorUid;
  bool _saving = false;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final workshopClass = widget.workshopClass;
    if (workshopClass != null) {
      _nameController.text = workshopClass.name;
      _categoryController.text = workshopClass.category;
      _selectedInstructorUid = workshopClass.instructorUid;
      _capacityController.text = workshopClass.capacity.toString();
      _isActive = workshopClass.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedInstructorUid == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      final workshopClass = WorkshopClass(
        id: widget.workshopClass?.id ?? '',
        name: _nameController.text.trim(),
        category: _categoryController.text.trim(),
        instructorUid: _selectedInstructorUid!,
        capacity: int.parse(_capacityController.text.trim()),
        isActive: _isActive,
      );
      if (widget.workshopClass == null) {
        await widget.service.createClass(workshopClass);
      } else {
        await widget.service.updateClass(workshopClass);
      }
      if (mounted) Navigator.pop(context);
    } on FirebaseException catch (error) {
      if (mounted) _showSaveError(context, error);
    } on StateError catch (error) {
      if (mounted) _showSaveError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.workshopClass == null ? 'Nova turma' : 'Editar turma'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: widget.workshopClass == null,
                decoration: const InputDecoration(
                  labelText: 'Nome da turma',
                  hintText: 'Ex.: Dança - Infantil',
                ),
                validator: _required,
              ),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Oficina/categoria',
                  hintText: 'Ex.: Dança',
                ),
                validator: _required,
              ),
              StreamBuilder<List<OrganizationMember>>(
                stream: widget.service.watchInstructors(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _InlineError(error: snapshot.error!);
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(),
                    );
                  }
                  final instructors = snapshot.data!;
                  final selectedInstructorExists = instructors.any(
                    (member) => member.uid == _selectedInstructorUid,
                  );
                  final currentInstructorUnavailable =
                      _selectedInstructorUid != null &&
                      !selectedInstructorExists;
                  return DropdownButtonFormField<String>(
                    initialValue: selectedInstructorExists
                        ? _selectedInstructorUid
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Professor(a)',
                      helperText: currentInstructorUnavailable
                          ? 'O professor atual não está disponível; selecione outro.'
                          : instructors.isEmpty
                          ? 'Nenhum usuário com perfil de instrutor encontrado.'
                          : null,
                    ),
                    items: [
                      ...instructors.map(
                        (member) => DropdownMenuItem(
                          value: member.uid,
                          child: Text(
                            member.displayName.isNotEmpty
                                ? member.displayName
                                : member.email.isNotEmpty
                                ? member.email
                                : 'Professor(a) sem nome',
                          ),
                        ),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (uid) => setState(() {
                            _selectedInstructorUid = uid == null || uid.isEmpty
                                ? null
                                : uid;
                          }),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Selecione um(a) professor(a).'
                        : null,
                  );
                },
              ),
              TextFormField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Vagas'),
                validator: (value) {
                  final number = int.tryParse(value ?? '');
                  return number == null || number <= 0
                      ? 'Informe um número maior que zero.'
                      : null;
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Turma ativa'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}

class _EnrollmentForm extends StatefulWidget {
  const _EnrollmentForm({
    required this.service,
    required this.workshopClass,
    this.enrollment,
  });

  final FirestoreService service;
  final WorkshopClass workshopClass;
  final Enrollment? enrollment;

  @override
  State<_EnrollmentForm> createState() => _EnrollmentFormState();
}

class _EnrollmentFormState extends State<_EnrollmentForm> {
  final _formKey = GlobalKey<FormState>();
  Student? _selectedStudent;
  late DateTime _enrolledAt = widget.enrollment?.enrolledAt ?? DateTime.now();
  late String _status = widget.enrollment?.status ?? 'active';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final enrollment = widget.enrollment;
    if (enrollment != null) {
      _selectedStudent = Student(
        id: enrollment.studentId,
        fullName: enrollment.studentName,
        phone: '',
        isActive: true,
      );
    }
  }

  Future<void> _pickEnrollmentDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _enrolledAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (selected != null) setState(() => _enrolledAt = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedStudent == null) return;
    setState(() => _saving = true);
    try {
      final enrollment = Enrollment(
        id: widget.enrollment?.id ?? '',
        studentId: _selectedStudent!.id,
        studentName: _selectedStudent!.fullName,
        enrolledAt: _enrolledAt,
        status: _status,
      );
      if (widget.enrollment == null) {
        await widget.service.createEnrollment(
          classId: widget.workshopClass.id,
          enrollment: enrollment,
        );
      } else {
        await widget.service.updateEnrollment(
          classId: widget.workshopClass.id,
          enrollment: enrollment,
        );
      }
      if (mounted) Navigator.pop(context);
    } on FirebaseException catch (error) {
      if (mounted) _showSaveError(context, error);
    } on StateError catch (error) {
      if (mounted) _showSaveError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        '${widget.enrollment == null ? 'Matrícula' : 'Editar matrícula'} · '
        '${widget.workshopClass.name}',
      ),
      content: StreamBuilder<List<Student>>(
        stream: widget.service.watchStudents(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return _InlineError(error: snapshot.error!);
          if (!snapshot.hasData) {
            return const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final students = snapshot.data!
              .where(
                (student) =>
                    student.isActive ||
                    student.id == widget.enrollment?.studentId,
              )
              .toList();
          if (students.isEmpty) {
            return const Text('Cadastre um aluno ativo antes de matriculá-lo.');
          }
          return Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue:
                      students.any(
                        (student) => student.id == _selectedStudent?.id,
                      )
                      ? _selectedStudent?.id
                      : null,
                  decoration: const InputDecoration(labelText: 'Aluno'),
                  items: students
                      .map(
                        (student) => DropdownMenuItem(
                          value: student.id,
                          child: Text(student.fullName),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (id) => setState(() {
                          _selectedStudent = id == null
                              ? null
                              : students.firstWhere(
                                  (student) => student.id == id,
                                );
                        }),
                  validator: (value) =>
                      value == null ? 'Selecione um aluno.' : null,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Data da matrícula'),
                  subtitle: Text(_dateLabel(_enrolledAt)),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: _saving ? null : _pickEnrollmentDate,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Ativa')),
                    DropdownMenuItem(value: 'inactive', child: Text('Inativa')),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value != null) setState(() => _status = value);
                        },
                ),
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving || _selectedStudent == null ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Matricular'),
        ),
      ],
    );
  }
}

class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm({required this.service, this.expense});

  final FirestoreService service;
  final Expense? expense;

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  DateTime _occurredAt = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    if (expense != null) {
      _descriptionController.text = expense.description;
      _categoryController.text = expense.category;
      _amountController.text = (expense.amountCents / 100)
          .toStringAsFixed(2)
          .replaceAll('.', ',');
      _occurredAt = expense.occurredAt;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _occurredAt = date);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final cents = _parseAmountToCents(_amountController.text);
    if (cents == null || cents <= 0) return;
    setState(() => _saving = true);
    try {
      if (widget.expense == null) {
        await widget.service.createExpense(
          description: _descriptionController.text.trim(),
          category: _categoryController.text.trim(),
          amountCents: cents,
          occurredAt: _occurredAt,
        );
      } else {
        await widget.service.updateExpense(
          expenseId: widget.expense!.id,
          description: _descriptionController.text.trim(),
          category: _categoryController.text.trim(),
          amountCents: cents,
          occurredAt: _occurredAt,
        );
      }
      if (mounted) Navigator.pop(context);
    } on FirebaseException catch (error) {
      if (mounted) _showSaveError(context, error);
    } on StateError catch (error) {
      if (mounted) _showSaveError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.expense == null ? 'Nova despesa' : 'Editar despesa'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _descriptionController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Descrição'),
                validator: _required,
              ),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  hintText: 'Ex.: Alimentação, Roupas, Material',
                ),
                validator: _required,
              ),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Valor',
                  prefixText: 'R\$ ',
                  hintText: '12,50',
                ),
                validator: (value) {
                  final cents = _parseAmountToCents(value ?? '');
                  return cents == null || cents <= 0
                      ? 'Informe um valor maior que zero.'
                      : null;
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Data da despesa'),
                subtitle: Text(_dateLabel(_occurredAt)),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: _saving ? null : _pickDate,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}

Future<void> _showClassForm(
  BuildContext context,
  FirestoreService service, {
  WorkshopClass? workshopClass,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _ClassForm(service: service, workshopClass: workshopClass),
  );
}

Future<void> _showStudentForm(
  BuildContext context,
  FirestoreService service, {
  Student? student,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _StudentForm(service: service, student: student),
  );
}

Future<void> _showExpenseForm(
  BuildContext context,
  FirestoreService service, {
  Expense? expense,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _ExpenseForm(service: service, expense: expense),
  );
}

Future<void> _showEnrollmentForm(
  BuildContext context,
  FirestoreService service,
  WorkshopClass workshopClass, {
  Enrollment? enrollment,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _EnrollmentForm(
      service: service,
      workshopClass: workshopClass,
      enrollment: enrollment,
    ),
  );
}

Future<void> _setClassStatus(
  BuildContext context,
  FirestoreService service,
  WorkshopClass workshopClass,
  bool isActive,
) async {
  try {
    await service.updateClass(
      WorkshopClass(
        id: workshopClass.id,
        name: workshopClass.name,
        category: workshopClass.category,
        instructorUid: workshopClass.instructorUid,
        capacity: workshopClass.capacity,
        isActive: isActive,
      ),
    );
  } on FirebaseException catch (error) {
    if (context.mounted) _showSaveError(context, error);
  }
}

Future<void> _setStudentStatus(
  BuildContext context,
  FirestoreService service,
  Student student,
  bool isActive,
) async {
  try {
    await service.updateStudent(_copyStudent(student, isActive: isActive));
  } on FirebaseException catch (error) {
    if (context.mounted) _showSaveError(context, error);
  }
}

Future<void> _confirmDeleteClass(
  BuildContext context,
  FirestoreService service,
  WorkshopClass workshopClass,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Excluir turma?'),
      content: Text(
        'A turma "${workshopClass.name}" e suas matrículas serão excluídas permanentemente.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Excluir'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await service.deleteClass(workshopClass.id);
  } on FirebaseException catch (error) {
    if (context.mounted) _showSaveError(context, error);
  }
}

Future<void> _confirmDeleteExpense(
  BuildContext context,
  FirestoreService service,
  Expense expense,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Excluir despesa?'),
      content: Text(
        'O lançamento "${expense.description}" será excluído permanentemente.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Excluir'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await service.deleteExpense(expense.id);
  } on FirebaseException catch (error) {
    if (context.mounted) _showSaveError(context, error);
  }
}

Future<void> _confirmDeleteStudent(
  BuildContext context,
  FirestoreService service,
  Student student,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Excluir aluno?'),
      content: Text(
        'O cadastro de "${student.fullName}" será removido. '
        'Os registros de matrícula existentes serão preservados como histórico.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Excluir aluno'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await service.deleteStudent(student.id);
  } on FirebaseException catch (error) {
    if (context.mounted) _showSaveError(context, error);
  }
}

Future<void> _updateRole(
  BuildContext context,
  FirestoreService service,
  OrganizationMember member,
  UserRole role,
) async {
  try {
    await service.updateMemberRole(member.uid, role);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Perfil de ${member.displayName.isEmpty ? member.email : member.displayName} '
            'alterado para ${_roleLabel(role)}.',
          ),
        ),
      );
    }
  } on FirebaseException catch (error) {
    if (context.mounted) _showSaveError(context, error);
  }
}

Student _copyStudent(Student student, {bool? isActive}) => Student(
  id: student.id,
  fullName: student.fullName,
  phone: student.phone,
  isActive: isActive ?? student.isActive,
  cpf: student.cpf,
  birthDate: student.birthDate,
  address: student.address,
  guardianName: student.guardianName,
  guardianRelationship: student.guardianRelationship,
  guardianPhone: student.guardianPhone,
  guardianCpf: student.guardianCpf,
);

String? _required(String? value) {
  return value == null || value.trim().isEmpty ? 'Campo obrigatório.' : null;
}

String? _cpfValidator(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return isValidCpf(value) ? null : 'Informe um CPF válido.';
}

String _roleLabel(UserRole role) {
  return switch (role) {
    UserRole.admin => 'Administrador',
    UserRole.coordinator => 'Coordenação',
    UserRole.instructor => 'Instrutor(a)',
    UserRole.viewer => 'Visualização',
  };
}

String _normalizeSearch(String value) {
  return value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('â', 'a')
      .replaceAll('é', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c')
      .trim();
}

String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

void _showSaveError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Não foi possível salvar: ${_errorMessage(error)}')),
  );
}

String _errorMessage(Object error) {
  if (error is FirebaseException) {
    if (error.code == 'permission-denied') {
      return 'Acesso negado. Confira se seu usuário tem perfil válido em members e se as regras do Firestore estão publicadas.';
    }
    return error.message ?? 'Firebase (${error.code}).';
  }
  return error.toString();
}

String _formatCurrency(int cents) {
  final value = (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
  final parts = value.split(',');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return 'R\$ $whole,${parts.last}';
}

String _monthLabel(DateTime month) {
  const months = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];
  return '${months[month.month - 1]} de ${month.year}';
}

String _dateLabel(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

int? _parseAmountToCents(String text) {
  var normalized = text.trim().replaceAll('R\$', '').replaceAll(' ', '');
  if (normalized.contains(',')) {
    normalized = normalized.replaceAll('.', '').replaceFirst(',', '.');
  }
  final value = double.tryParse(normalized);
  if (value == null || !value.isFinite) return null;
  return (value * 100).round();
}

IconData _iconForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'dança':
      return Icons.music_note;
    case 'música':
      return Icons.piano;
    case 'artesanato':
    case 'bordado':
      return Icons.handyman_outlined;
    case 'informática':
      return Icons.computer;
    default:
      return Icons.palette_outlined;
  }
}
