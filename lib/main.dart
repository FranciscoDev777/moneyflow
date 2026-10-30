import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const emerald = Color(0xFF10B981);
const deep = Color(0xFF112237);

void main() => runApp(const MoneyFlowApp());

String brl(double n) {
  final s = n.abs().toStringAsFixed(2).split('.');
  final digits =
      s[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
  return '${n < 0 ? '-' : ''}R\$ $digits,${s[1]}';
}

double? parseAmount(String text) {
  final t = text.trim().replaceAll('R\$', '').replaceAll(' ', '');
  if (t.contains(','))
    return double.tryParse(t.replaceAll('.', '').replaceAll(',', '.'));
  return double.tryParse(t);
}

String shortDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class Entry {
  Entry(
      {required this.id,
      required this.title,
      required this.category,
      required this.amount,
      required this.date});
  final String id;
  String title, category;
  double amount;
  DateTime date;
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'date': date.toIso8601String()
      };
  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
      id: j['id'].toString(),
      title: j['title'].toString(),
      category: j['category'].toString(),
      amount: (j['amount'] as num).toDouble(),
      date: DateTime.parse(j['date'].toString()));
}

class Goal {
  Goal(
      {required this.id,
      required this.title,
      required this.target,
      required this.saved});
  final String id;
  String title;
  double target, saved;
  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'target': target, 'saved': saved};
  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
      id: j['id'].toString(),
      title: j['title'].toString(),
      target: (j['target'] as num).toDouble(),
      saved: (j['saved'] as num).toDouble());
}

class MoneyFlowApp extends StatefulWidget {
  const MoneyFlowApp({super.key});
  @override
  State<MoneyFlowApp> createState() => _MoneyFlowAppState();
}

class _MoneyFlowAppState extends State<MoneyFlowApp> {
  bool dark = false;
  void changeTheme(bool v) => setState(() => dark = v);
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MoneyFlow',
        debugShowCheckedModeBanner: false,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: emerald),
            scaffoldBackgroundColor: const Color(0xFFF5F8FA)),
        darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
                seedColor: emerald, brightness: Brightness.dark)),
        home: SplashScreen(onTheme: changeTheme, initialDark: dark),
      );
}

class SplashScreen extends StatefulWidget {
  const SplashScreen(
      {super.key, required this.onTheme, required this.initialDark});
  final ValueChanged<bool> onTheme;
  final bool initialDark;
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => Dashboard(onTheme: widget.onTheme)));
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: deep,
        body: SafeArea(
            child: Column(children: [
          const Spacer(),
          TweenAnimationBuilder<double>(
              tween: Tween(begin: .75, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutBack,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Image.asset('assets/images/logo.png',
                  width: 132, height: 132)),
          const SizedBox(height: 20),
          const Text('MoneyFlow',
              style: TextStyle(
                  fontSize: 36,
                  color: Colors.white,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Seu dinheiro no controle.',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
          const Spacer(),
          const CircularProgressIndicator(color: emerald),
          const SizedBox(height: 36),
        ])),
      );
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key, required this.onTheme});
  final ValueChanged<bool> onTheme;
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final entries = <Entry>[];
  final goals = <Goal>[];
  String userName = 'Meu perfil';
  double budget = 1500;
  bool dark = false, loading = true, showBalance = true;
  int tab = 0;
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final categories = [
    'Alimentação',
    'Transporte',
    'Moradia',
    'Saúde',
    'Lazer',
    'Educação',
    'Trabalho',
    'Outros'
  ];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    try {
      final rawE = jsonDecode(p.getString('mf_entries') ?? '[]') as List;
      final rawG = jsonDecode(p.getString('mf_goals') ?? '[]') as List;
      entries.addAll(
          rawE.map((e) => Entry.fromJson(Map<String, dynamic>.from(e as Map))));
      goals.addAll(
          rawG.map((g) => Goal.fromJson(Map<String, dynamic>.from(g as Map))));
    } catch (_) {
      entries.clear();
      goals.clear();
    }
    if (!mounted) return;
    setState(() {
      userName = p.getString('mf_name') ?? 'Meu perfil';
      budget = p.getDouble('mf_budget') ?? 1500;
      dark = p.getBool('mf_dark') ?? false;
      loading = false;
    });
    widget.onTheme(dark);
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        'mf_entries', jsonEncode(entries.map((e) => e.toJson()).toList()));
    await p.setString(
        'mf_goals', jsonEncode(goals.map((g) => g.toJson()).toList()));
    await p.setString('mf_name', userName);
    await p.setDouble('mf_budget', budget);
    await p.setBool('mf_dark', dark);
  }

  void refresh() {
    setState(() {});
    save();
  }

  double get balance => entries.fold(0, (sum, e) => sum + e.amount);
  List<Entry> get monthly => entries
      .where((e) =>
          e.date.year == selectedMonth.year &&
          e.date.month == selectedMonth.month)
      .toList();
  double get income =>
      monthly.where((e) => e.amount > 0).fold(0, (s, e) => s + e.amount);
  double get expenses =>
      monthly.where((e) => e.amount < 0).fold(0, (s, e) => s - e.amount);
  List<Entry> get sorted =>
      [...entries]..sort((a, b) => b.date.compareTo(a.date));
  void notify(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
  Widget panel(Widget child) => Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.all(18), child: child));
  Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      child: Text(title,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)));
  Widget stat(String title, String value, IconData icon, Color color) =>
      Expanded(
          child: panel(
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 5),
        FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)))
      ])));
  void changeMonth(int delta) => setState(() => selectedMonth =
      DateTime(selectedMonth.year, selectedMonth.month + delta));
  Widget monthPicker() =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(
            onPressed: () => changeMonth(-1),
            icon: const Icon(Icons.chevron_left)),
        Text(
            '${selectedMonth.month.toString().padLeft(2, '0')}/${selectedMonth.year}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        IconButton(
            onPressed: () => changeMonth(1),
            icon: const Icon(Icons.chevron_right))
      ]);

  Future<void> editEntry({Entry? original, bool expense = true}) async {
    final title = TextEditingController(text: original?.title ?? '');
    final value = TextEditingController(
        text: original == null
            ? ''
            : original.amount.abs().toStringAsFixed(2).replaceAll('.', ','));
    String category =
        original?.category ?? (expense ? 'Alimentação' : 'Trabalho');
    bool isExpense = original == null ? expense : original.amount < 0;
    final result = await showDialog<Entry>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                  title: Text(original == null
                      ? 'Nova movimentação'
                      : 'Editar movimentação'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('Receita')),
                          ButtonSegment(value: true, label: Text('Despesa'))
                        ],
                        selected: {
                          isExpense
                        },
                        onSelectionChanged: (s) =>
                            update(() => isExpense = s.first)),
                    const SizedBox(height: 12),
                    TextField(
                        controller: title,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                            labelText: 'Descrição',
                            border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(
                        controller: value,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Valor (R\$)',
                            border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                        value: category,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Categoria',
                            border: OutlineInputBorder()),
                        items: categories
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) update(() => category = v);
                        }),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancelar')),
                    FilledButton(
                        onPressed: () {
                          final number = parseAmount(value.text);
                          if (title.text.trim().isEmpty ||
                              number == null ||
                              !number.isFinite ||
                              number <= 0) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Informe uma descrição e um valor válido.')));
                            return;
                          }
                          Navigator.pop(
                              dialogContext,
                              Entry(
                                  id: original?.id ??
                                      DateTime.now()
                                          .microsecondsSinceEpoch
                                          .toString(),
                                  title: title.text.trim(),
                                  category: category,
                                  amount: isExpense ? -number : number,
                                  date: original?.date ?? DateTime.now()));
                        },
                        child: const Text('Salvar'))
                  ],
                )));
    // Controllers are deliberately not disposed immediately after pop: the dialog exit animation may still be active.
    if (result == null || !mounted) return;
    if (original == null) {
      entries.add(result);
    } else {
      final i = entries.indexWhere((e) => e.id == original.id);
      if (i >= 0) entries[i] = result;
    }
    refresh();
    notify('Movimentação salva!');
  }

  Future<void> removeEntry(Entry e) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Excluir movimentação?'),
                content: Text(e.title),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancelar')),
                  TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Excluir'))
                ]));
    if (yes == true) {
      entries.removeWhere((x) => x.id == e.id);
      refresh();
    }
  }

  Widget entryTile(Entry e) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
          backgroundColor: e.amount >= 0
              ? emerald.withValues(alpha: .14)
              : Colors.red.withValues(alpha: .12),
          child: Icon(e.amount >= 0 ? Icons.south_west : Icons.north_east,
              color: e.amount >= 0 ? emerald : Colors.red)),
      title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${e.category} • ${shortDate(e.date)}'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(brl(e.amount),
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: e.amount >= 0 ? emerald : null)),
        PopupMenuButton<String>(
            onSelected: (s) =>
                s == 'edit' ? editEntry(original: e) : removeEntry(e),
            itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'delete', child: Text('Excluir'))
                ])
      ]));
  Widget empty(String message) => Padding(
      padding: const EdgeInsets.all(22),
      child: Center(child: Text(message, textAlign: TextAlign.center)));

  Widget homePage() => ListView(padding: const EdgeInsets.all(18), children: [
        Text('Olá, $userName 👋',
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        const Text('Acompanhe seu dinheiro em um só lugar.'),
        const SizedBox(height: 20),
        Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                gradient:
                    const LinearGradient(colors: [deep, Color(0xFF194D56)]),
                borderRadius: BorderRadius.circular(24)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('Saldo total',
                    style: TextStyle(color: Colors.white70)),
                const Spacer(),
                IconButton(
                    onPressed: () => setState(() => showBalance = !showBalance),
                    icon: Icon(
                        showBalance
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.white))
              ]),
              Text(showBalance ? brl(balance) : '••••••',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              const Text('MoneyFlow • Seu dinheiro no controle',
                  style: TextStyle(color: Colors.white70))
            ])),
        const SizedBox(height: 15),
        monthPicker(),
        Row(children: [
          stat('Receitas', brl(income), Icons.arrow_downward, emerald),
          const SizedBox(width: 8),
          stat('Despesas', brl(expenses), Icons.arrow_upward, Colors.redAccent)
        ]),
        Row(children: [
          Expanded(
              child: FilledButton.icon(
                  onPressed: () => editEntry(expense: false),
                  icon: const Icon(Icons.add),
                  label: const Text('Receita'))),
          const SizedBox(width: 10),
          Expanded(
              child: OutlinedButton.icon(
                  onPressed: () => editEntry(expense: true),
                  icon: const Icon(Icons.remove),
                  label: const Text('Despesa')))
        ]),
        section('Orçamento do mês'),
        budgetCard(),
        section('Movimentações recentes'),
        if (sorted.isEmpty)
          panel(empty('Adicione sua primeira receita ou despesa.'))
        else
          panel(Column(children: sorted.take(5).map(entryTile).toList())),
        TextButton(
            onPressed: () => setState(() => tab = 1),
            child: const Text('Ver histórico completo')),
      ]);
  Widget budgetCard() {
    final ratio = budget > 0 ? expenses / budget : 0.0;
    return panel(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text('${brl(expenses)} de ${brl(budget)}',
                style: const TextStyle(fontWeight: FontWeight.bold))),
        if (ratio >= .8)
          const Icon(Icons.warning_amber_rounded, color: Colors.orange)
      ]),
      const SizedBox(height: 10),
      LinearProgressIndicator(
          value: ratio.clamp(0.0, 1.0),
          minHeight: 9,
          borderRadius: BorderRadius.circular(12),
          color: ratio >= 1 ? Colors.red : emerald),
      const SizedBox(height: 8),
      Text(ratio >= 1
          ? 'Limite mensal atingido!'
          : ratio >= .8
              ? 'Atenção: você já usou ${(ratio * 100).round()}% do limite.'
              : 'Você usou ${(ratio * 100).round()}% do orçamento.')
    ]));
  }

  Widget historyPage() {
    return HistoryContent(
        entries: sorted,
        onEdit: (e) => editEntry(original: e),
        onDelete: removeEntry,
        entryTile: entryTile);
  }

  Future<void> editGoal({Goal? original}) async {
    final title = TextEditingController(text: original?.title ?? '');
    final target =
        TextEditingController(text: original?.target.toString() ?? '');
    final result = await showDialog<Goal>(
        context: context,
        builder: (c) => AlertDialog(
                title: Text(original == null ? 'Nova meta' : 'Editar meta'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'Objetivo')),
                  TextField(
                      controller: target,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Valor desejado (R\$)'))
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () {
                        final v = parseAmount(target.text);
                        if (title.text.trim().isEmpty ||
                            v == null ||
                            !v.isFinite ||
                            v <= 0) {
                          notify('Preencha uma meta válida.');
                          return;
                        }
                        Navigator.pop(
                            c,
                            Goal(
                                id: original?.id ??
                                    DateTime.now()
                                        .microsecondsSinceEpoch
                                        .toString(),
                                title: title.text.trim(),
                                target: v,
                                saved: original?.saved ?? 0));
                      },
                      child: const Text('Salvar'))
                ]));
    if (result == null || !mounted) return;
    if (original == null) {
      goals.add(result);
    } else {
      final i = goals.indexWhere((g) => g.id == original.id);
      if (i >= 0) goals[i] = result;
    }
    refresh();
  }

  Future<void> deposit(Goal g) async {
    final ctrl = TextEditingController();
    final amount = await showDialog<double>(
        context: context,
        builder: (c) => AlertDialog(
                title: Text('Guardar para ${g.title}'),
                content: TextField(
                    controller: ctrl,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Valor (R\$)')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () {
                        final n = parseAmount(ctrl.text);
                        if (n == null || !n.isFinite || n <= 0) {
                          notify('Informe um valor válido.');
                          return;
                        }
                        Navigator.pop(c, n);
                      },
                      child: const Text('Adicionar'))
                ]));
    if (amount != null && mounted) {
      g.saved += amount;
      refresh();
      notify('Valor adicionado à meta.');
    }
  }

  Widget goalsPage() => ListView(padding: const EdgeInsets.all(18), children: [
        section('Minhas metas'),
        FilledButton.icon(
            onPressed: () => editGoal(),
            icon: const Icon(Icons.add),
            label: const Text('Criar meta')),
        const SizedBox(height: 14),
        if (goals.isEmpty)
          panel(empty('Crie uma meta para começar a economizar.')),
        ...goals.map((g) => panel(
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(g.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 17))),
                PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') {
                        editGoal(original: g);
                      } else {
                        goals.remove(g);
                        refresh();
                      }
                    },
                    itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Editar')),
                          PopupMenuItem(value: 'delete', child: Text('Excluir'))
                        ])
              ]),
              Text('${brl(g.saved)} / ${brl(g.target)}'),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                  value: (g.saved / g.target).clamp(0.0, 1.0),
                  minHeight: 9,
                  borderRadius: BorderRadius.circular(12)),
              const SizedBox(height: 12),
              Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                      onPressed: () => deposit(g),
                      icon: const Icon(Icons.add),
                      label: const Text('Guardar valor')))
            ]))),
        panel(const Text(
            'As metas são um acompanhamento separado do saldo. Guardar um valor aqui não movimenta a conta automaticamente.',
            style: TextStyle(fontSize: 12))),
      ]);
  Widget analyticsPage() {
    final map = <String, double>{};
    for (final e in monthly.where((e) => e.amount < 0)) {
      map[e.category] = (map[e.category] ?? 0) - e.amount;
    }
    final items = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final net = income - expenses;
    return ListView(padding: const EdgeInsets.all(18), children: [
      section('Relatório mensal'),
      monthPicker(),
      Row(children: [
        stat('Entradas', brl(income), Icons.trending_up, emerald),
        const SizedBox(width: 8),
        stat('Saídas', brl(expenses), Icons.trending_down, Colors.red)
      ]),
      panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Resultado do mês',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(brl(net),
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: net >= 0 ? emerald : Colors.red)),
        const SizedBox(height: 14),
        const Text('Receitas x despesas'),
        const SizedBox(height: 10),
        _bar('Receitas', income, math.max(income, expenses), emerald),
        const SizedBox(height: 8),
        _bar('Despesas', expenses, math.max(income, expenses), Colors.redAccent)
      ])),
      section('Despesas por categoria'),
      if (items.isEmpty)
        panel(empty('Sem despesas neste mês.'))
      else
        panel(Column(children: [
          SizedBox(
              height: 180,
              child: CustomPaint(
                  painter: DonutPainter(items.map((e) => e.value).toList()),
                  child: Center(
                      child: Text(brl(expenses),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 20))))),
          const SizedBox(height: 14),
          ...items.asMap().entries.map((it) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                CircleAvatar(
                    radius: 6,
                    backgroundColor: DonutPainter
                        .palette[it.key % DonutPainter.palette.length]),
                const SizedBox(width: 10),
                Expanded(child: Text(it.value.key)),
                Text(brl(it.value.value))
              ])))
        ]))
    ]);
  }

  Widget _bar(String label, double amount, double max, Color color) =>
      Row(children: [
        SizedBox(width: 72, child: Text(label)),
        Expanded(
            child: LinearProgressIndicator(
                value: max == 0 ? 0 : amount / max,
                minHeight: 12,
                borderRadius: BorderRadius.circular(10),
                color: color))
      ]);
  Future<void> editProfile() async {
    final name = TextEditingController(text: userName);
    final limit = TextEditingController(
        text: budget.toStringAsFixed(2).replaceAll('.', ','));
    final result = await showDialog<(String, double)>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Editar perfil'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Seu nome')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: limit,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Limite mensal (R\$)'))
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () {
                        final v = parseAmount(limit.text);
                        if (name.text.trim().isEmpty ||
                            v == null ||
                            !v.isFinite ||
                            v <= 0) {
                          notify('Preencha nome e limite válidos.');
                          return;
                        }
                        Navigator.pop(c, (name.text.trim(), v));
                      },
                      child: const Text('Salvar'))
                ]));
    if (result != null && mounted) {
      userName = result.$1;
      budget = result.$2;
      refresh();
    }
  }

  Widget profilePage() =>
      ListView(padding: const EdgeInsets.all(18), children: [
        const SizedBox(height: 24),
        Center(
            child: CircleAvatar(
                radius: 42,
                backgroundColor: emerald.withValues(alpha: .15),
                child: const Icon(Icons.person, color: emerald, size: 45))),
        const SizedBox(height: 12),
        Center(
            child: Text(userName,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 23))),
        const Center(child: Text('Perfil local • MoneyFlow')),
        const SizedBox(height: 24),
        panel(Column(children: [
          ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar nome e orçamento'),
              onTap: editProfile),
          const Divider(),
          SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Modo escuro'),
              value: dark,
              onChanged: (v) {
                setState(() => dark = v);
                widget.onTheme(v);
                save();
              }),
          const Divider(),
          ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Limite mensal'),
              subtitle: Text(brl(budget)),
              onTap: editProfile)
        ])),
        panel(const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Dados armazenados neste dispositivo'),
            subtitle: Text(
                'Sem conexão bancária, login ou sincronização em nuvem.'))),
        const Center(
            child:
                Text('MoneyFlow 2.0 • Flutter', style: TextStyle(fontSize: 12)))
      ]);
  @override
  Widget build(BuildContext context) {
    const labels = ['Início', 'Histórico', 'Análises', 'Metas', 'Perfil'];
    const icons = [
      Icons.home_outlined,
      Icons.receipt_long_outlined,
      Icons.pie_chart_outline,
      Icons.flag_outlined,
      Icons.person_outline
    ];
    return Scaffold(
        appBar: AppBar(
            title: Row(children: [
              Image.asset('assets/images/logo.png', width: 36, height: 36),
              const SizedBox(width: 10),
              const Text('MoneyFlow',
                  style: TextStyle(fontWeight: FontWeight.w800))
            ]),
            actions: [
              IconButton(
                  tooltip: 'Perfil',
                  onPressed: () => setState(() => tab = 4),
                  icon: const Icon(Icons.account_circle_outlined))
            ]),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : IndexedStack(index: tab, children: [
                homePage(),
                historyPage(),
                analyticsPage(),
                goalsPage(),
                profilePage()
              ]),
        bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (v) => setState(() => tab = v),
            destinations: List.generate(
                labels.length,
                (i) => NavigationDestination(
                    icon: Icon(icons[i]), label: labels[i]))));
  }
}

class HistoryContent extends StatefulWidget {
  const HistoryContent(
      {super.key,
      required this.entries,
      required this.onEdit,
      required this.onDelete,
      required this.entryTile});
  final List<Entry> entries;
  final ValueChanged<Entry> onEdit, onDelete;
  final Widget Function(Entry) entryTile;
  @override
  State<HistoryContent> createState() => _HistoryContentState();
}

class _HistoryContentState extends State<HistoryContent> {
  String search = '', filter = 'Todas';
  @override
  Widget build(BuildContext context) {
    final filtered = widget.entries
        .where((e) =>
            e.title.toLowerCase().contains(search.toLowerCase()) &&
            (filter == 'Todas' ||
                (filter == 'Receitas' ? e.amount > 0 : e.amount < 0)))
        .toList();
    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Histórico de movimentações',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 15),
      TextField(
          onChanged: (s) => setState(() => search = s),
          decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Pesquisar descrição',
              border: OutlineInputBorder())),
      const SizedBox(height: 10),
      Wrap(
          spacing: 8,
          children: ['Todas', 'Receitas', 'Despesas']
              .map((v) => ChoiceChip(
                  label: Text(v),
                  selected: filter == v,
                  onSelected: (_) => setState(() => filter = v)))
              .toList()),
      const SizedBox(height: 12),
      if (filtered.isEmpty)
        const Center(
            child: Padding(
                padding: EdgeInsets.all(28),
                child: Text('Nenhuma movimentação encontrada.')))
      else
        Card(
            elevation: 0,
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child:
                    Column(children: filtered.map(widget.entryTile).toList())))
    ]);
  }
}

class DonutPainter extends CustomPainter {
  DonutPainter(this.values);
  final List<double> values;
  static const palette = [
    emerald,
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFEF4444),
    Color(0xFF06B6D4),
    Color(0xFF84CC16),
    Color(0xFF64748B)
  ];
  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (s, v) => s + v);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 12;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20;
    if (total <= 0) {
      p.color = Colors.grey.withValues(alpha: .2);
      canvas.drawCircle(center, radius, p);
      return;
    }
    var angle = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = 2 * math.pi * values[i] / total;
      p.color = palette[i % palette.length];
      canvas.drawArc(rect, angle, sweep, false, p);
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant DonutPainter old) =>
      old.values.toString() != values.toString();
}
