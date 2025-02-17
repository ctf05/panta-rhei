import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'models/person_model.dart';
import 'state/app_state.dart';
import 'screens/main_calendar_tab.dart';
import 'screens/events_tab.dart';
import 'screens/person_tab.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const PantaRheiApp());
}

class PantaRheiApp extends StatelessWidget {
  const PantaRheiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: MaterialApp(
        title: 'Panta Rhei',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.light(
            primary: const Color(0xFFa12c34),      // Changed to secondary color for less intensity
            secondary: const Color(0xFFec4755),     // Original primary color
            tertiary: const Color(0xFFffba75),      // Kept tertiary
            background: const Color(0xFFfef8e0),    // Kept background
            surface: const Color(0xFFfef8e0),       // Kept surface
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onTertiary: Colors.black,
            onBackground: Colors.black,
            onSurface: Colors.black,
          ),
          textTheme: const TextTheme(
            displayLarge: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1a4966),
            ),
            displayMedium: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1a4966),
            ),
            bodyLarge: TextStyle(
              fontSize: 16,
              color: Color(0xFF1a4966),
            ),
            bodyMedium: TextStyle(
              fontSize: 14,
              color: Color(0xFF1a4966),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFF1a4966),
                width: 2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFF1a4966),
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFFec4755),
                width: 2,
              ),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFec4755),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFec4755),
              side: const BorderSide(color: Color(0xFFec4755), width: 2),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          cardTheme: CardTheme(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(
                color: Color(0xFF1a4966),
                width: 1,
              ),
            ),
            color: Colors.white,
          ),
        ),
        home: const MainScreen(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final List<TabData> _fixedTabs = [
    TabData(
      label: 'Main Calendar',
      builder: (_) => const MainCalendarTab(),
    ),
    TabData(
      label: 'Events',
      builder: (_) => const EventsTab(),
    ),
  ];
  List<TabData> _personTabs = [];

  @override
  void initState() {
    super.initState();
    _updateTabController();

    // Listen to people changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().addListener(_onAppStateChanged);
      _loadPeople();
    });
  }

  @override
  void dispose() {
    context.read<AppState>().removeListener(_onAppStateChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onAppStateChanged() {
    final people = context.read<AppState>().people;
    if (people != null) {
      final currentIds = _personTabs.map((tab) {
        final personTab = tab.builder(context) as PersonTab;
        return personTab.personId;
      }).toSet();

      final newTabs = people.where((person) => !currentIds.contains(person.id))
          .map((person) => TabData(
        label: person.name,
        builder: (_) => PersonTab(personId: person.id),
        canClose: true,
      )).toList();

      if (newTabs.isNotEmpty) {
        setState(() {
          _personTabs.addAll(newTabs);
          _updateTabController();
        });
      }
    }
  }

  void _loadPeople() {
    final people = context.read<AppState>().people;
    if (people != null) {
      setState(() {
        _personTabs = people.map((person) => TabData(
          label: person.name,
          builder: (_) => PersonTab(personId: person.id),
          canClose: true,
        )).toList();
        _updateTabController();
      });
    }
  }

  void _updateTabController() {
    _tabController = TabController(
      length: _fixedTabs.length + _personTabs.length,
      vsync: this,
    );
  }

  void _addPersonTab() async {
    final person = Person(
      name: 'New Person ${_personTabs.length + 1}',
      availability: [],
    );

    try {
      await context.read<AppState>().createPerson(person);
      setState(() {
        _personTabs.add(
          TabData(
            label: person.name,
            builder: (_) => PersonTab(personId: person.id),
            canClose: true,
          ),
        );
        _updateTabController();
        _tabController.animateTo(_tabController.length - 1);  // Switch to new tab
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating person: $e')),
      );
    }
  }

  void _closeTab(int index) async {
    if (index < _fixedTabs.length) return;

    final personTab = _personTabs[index - _fixedTabs.length];
    final personId = (personTab.builder(context) as PersonTab).personId;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Person'),
        content: Text('Are you sure you want to delete ${personTab.label}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Delete from database
        await context.read<AppState>().deletePerson(personId);

        // Remove tab
        setState(() {
          _personTabs.removeAt(index - _fixedTabs.length);
          _updateTabController();
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting person: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTabs = [..._fixedTabs, ..._personTabs];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: const Text(
          'Panta Rhei',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: allTabs.map((tab) {
            return tab.canClose
                ? Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tab.label),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _closeTab(allTabs.indexOf(tab)),
                    child: const Icon(Icons.close, size: 16),
                  ),
                ],
              ),
            )
                : Tab(text: tab.label);
          }).toList(),
          indicatorColor: Theme.of(context).colorScheme.tertiary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabAlignment: TabAlignment.start,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.white),
            onPressed: _addPersonTab,
            tooltip: 'Add Person Tab',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: allTabs.map((tab) => tab.builder(context)).toList(),
      ),
    );
  }
}

class TabData {
  final String label;
  final Widget Function(BuildContext) builder;
  final bool canClose;

  TabData({
    required this.label,
    required this.builder,
    this.canClose = false,
  });
}