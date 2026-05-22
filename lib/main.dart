import 'dart:async';
import 'dart:convert'; // JSON変換用に追加
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 端末保存用に追加

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '学習バイトアプリ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'sans-serif', 
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontFamily: 'sans-serif'),
          bodyMedium: TextStyle(fontFamily: 'sans-serif'),
        ),
      ),
      home: const MainNavigationContainer(),
    );
  }
}

// カレンダーの予定データ（JSON変換に対応）
class CalendarEvent {
  final int year;
  final int month;
  final int day;
  final String title;
  final Color color; 
  CalendarEvent({required this.year, required this.month, required this.day, required this.title, this.color = const Color(0xFF34A8F2)});

  Map<String, dynamic> toJson() => {
    'year': year,
    'month': month,
    'day': day,
    'title': title,
    'color': color.value,
  };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
    year: json['year'],
    month: json['month'],
    day: json['day'],
    title: json['title'],
    color: Color(json['color']),
  );
}

// リマインダーデータ（JSON変換に対応）
class ReminderItemData {
  final int targetMonth;
  final int targetDay; 
  final String title;
  ReminderItemData({required this.targetMonth, required this.targetDay, required this.title});

  Map<String, dynamic> toJson() => {
    'targetMonth': targetMonth,
    'targetDay': targetDay,
    'title': title,
  };

  factory ReminderItemData.fromJson(Map<String, dynamic> json) => ReminderItemData(
    targetMonth: json['targetMonth'],
    targetDay: json['targetDay'],
    title: json['title'],
  );
}

class MainNavigationContainer extends StatefulWidget {
  const MainNavigationContainer({super.key});

  @override
  State<MainNavigationContainer> createState() => _MainNavigationContainerState();
}

class _MainNavigationContainerState extends State<MainNavigationContainer> with SingleTickerProviderStateMixin {
  int _currentTab = 2; 
  int _currentBaitScreen = 1; 
  
  int _totalMoney = 0;

  String? _selectedSubject;
  int _displayMinutes = 0;

  int _remainingSeconds = 0;
  int _elapsedSeconds = 0; 
  Timer? _timer;

  int _lastEarnedMoney = 0;
  int _lastDisplayMinutes = 0;

  // アニメーション用変数
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  bool _showLevelUpMotion = false;

  final int _currentYear = 2026;
  final int _currentMonth = 5;
  final int _currentDay = 20;

  int _displayYear = 2026;
  int _displayMonth = 5;
  int _selectedDay = 20; 

  // 初期データ（データが未保存の場合のデフォルト値）
  List<CalendarEvent> _calendarEvents = [
    CalendarEvent(year: 2026, month: 5, day: 15, title: '会議', color: const Color(0xFF4A90E2)),
    CalendarEvent(year: 2026, month: 5, day: 24, title: '課題提出', color: const Color(0xFFF5A623)),
    CalendarEvent(year: 2026, month: 5, day: 27, title: '予約確認', color: const Color(0xFF4A90E2)),
  ];

  List<ReminderItemData> _reminderList = [
    ReminderItemData(targetMonth: 5, targetDay: 24, title: 'マインドマップ提出'),
    ReminderItemData(targetMonth: 5, targetDay: 27, title: '提出物の締め切り'),
  ];

  final List<String> _frequentEvents = ['テスト', '提出物', '塾', '部活', '補習', '会議'];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut, 
    );
    
    // 起動時に端末からデータを読み込む
    _loadSavedData();
  }

  // 📥 データの読み込み処理
  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _totalMoney = prefs.getInt('totalMoney') ?? 0;

      // カレンダー予定の復元
      final List<String>? calendarJsonList = prefs.getStringList('calendarEvents');
      if (calendarJsonList != null) {
        _calendarEvents = calendarJsonList
            .map((item) => CalendarEvent.fromJson(jsonDecode(item)))
            .toList();
      }

      // リマインダーの復元
      final List<String>? reminderJsonList = prefs.getStringList('reminderList');
      if (reminderJsonList != null) {
        _reminderList = reminderJsonList
            .map((item) => ReminderItemData.fromJson(jsonDecode(item)))
            .toList();
      }
    });
  }

  // 💾 データの保存処理
  Future<void> _saveAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('totalMoney', _totalMoney);

    // カレンダーを文字列リストにシリアライズして保存
    List<String> calendarJsonList = _calendarEvents
        .map((event) => jsonEncode(event.toJson()))
        .toList();
    await prefs.setStringList('calendarEvents', calendarJsonList);

    // リマインダーを文字列リストにシリアライズして保存
    List<String> reminderJsonList = _reminderList
        .map((item) => jsonEncode(item.toJson()))
        .toList();
    await prefs.setStringList('reminderList', reminderJsonList);
  }

  int _calculateLevel(int money) {
    int m = money;
    int level = 1;
    int nextLevelNeed = 200;
    while (m >= nextLevelNeed) {
      m -= nextLevelNeed;
      level++;
      nextLevelNeed += 100;
    }
    return level;
  }

  int get _currentLevel => _calculateLevel(_totalMoney);

  // 基本の時給に「レベル5ごとに+1円」のボーナスを追加した計算式
  int get _wagePerMinute {
    int lvl = _currentLevel;
    int baseWage = 3; 
    if (lvl == 1) baseWage = 10; 
    if (lvl == 2) baseWage = 5;  
    
    int bonus = lvl ~/ 5;
    return baseWage + bonus;
  }

  int _getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  int _getStartOffset(int year, int month) {
    DateTime firstDay = DateTime(year, month, 1);
    return firstDay.weekday == 7 ? 0 : firstDay.weekday;
  }

  void _changeMonth(int increment) {
    setState(() {
      _displayMonth += increment;
      if (_displayMonth > 12) {
        _displayMonth = 1;
        _displayYear++;
      } else if (_displayMonth < 1) {
        _displayMonth = 12;
        _displayYear--;
      }
      _selectedDay = 1; 
    });
  }

  void _startTimer() {
    _remainingSeconds = _displayMinutes * 60;
    _elapsedSeconds = 0; 
    setState(() { _currentBaitScreen = 3; });
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
          _elapsedSeconds++;
        });
      } else {
        _endBait(isFinished: true);
      }
    });
  }

  void _endBait({required bool isFinished}) {
    _timer?.cancel();
    int actualMinutes = isFinished ? _displayMinutes : (_elapsedSeconds / 60).toInt();
    int reward = actualMinutes * _wagePerMinute;

    int oldLevel = _currentLevel; 
    int newLevel = _calculateLevel(_totalMoney + reward); 

    setState(() {
      _totalMoney += reward;
      _lastEarnedMoney = reward;
      _lastDisplayMinutes = actualMinutes;
      _currentBaitScreen = 4; 
      
      if (newLevel > oldLevel) {
        _showLevelUpMotion = true;
        _animController.forward(from: 0.0);
      } else {
        _showLevelUpMotion = false;
      }
    });
    
    // お金が変動したので自動セーブ
    _saveAllData();
  }

  void _resetAndGoHome() {
    setState(() {
      _selectedSubject = null;
      _displayMinutes = 0;
      _currentBaitScreen = 1;
      _showLevelUpMotion = false;
      _animController.reset();
    });
  }

  // カレンダー用予定追加ダイアログ
  void _showAddEventDialog() {
    final textController = TextEditingController();
    bool reflectToReminder = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('$_displayMonth月$_selectedDay日の予定を追加'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                decoration: const InputDecoration(hintText: '予定タイトルを入力'),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text(
                  'リマインダーにも追加しますか？', 
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                value: reflectToReminder,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF3DA9FC),
                onChanged: (bool? value) {
                  setDialogState(() { reflectToReminder = value ?? false; });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('キャンセル')
            ),
            TextButton(
              onPressed: () {
                if (textController.text.isNotEmpty) {
                  setState(() {
                    _calendarEvents.add(CalendarEvent(
                      year: _displayYear,
                      month: _displayMonth,
                      day: _selectedDay,
                      title: textController.text,
                      color: const Color(0xFF4A90E2),
                    ));
                    
                    if (reflectToReminder) {
                      _reminderList.add(ReminderItemData(
                        targetMonth: _displayMonth, 
                        targetDay: _selectedDay, 
                        title: textController.text,
                      ));
                    }
                  });
                  // 予定が追加されたので自動セーブ
                  _saveAllData();
                }
                Navigator.pop(context);
              },
              child: const Text('追加', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FAFB),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopHeader(), 
            Expanded(
              child: _buildMainContent(), 
            ),
          ],
        ),
      ),
      bottomNavigationBar: (_currentBaitScreen == 3 || _currentBaitScreen == 4) ? null : _buildBottomTabBar(),
    );
  }

  Widget _buildMainContent() {
    switch (_currentTab) {
      case 0:
        return _buildCalendarTabWithGridTitles();
      case 1:
        return _buildBetaPlaceholder('グラフ機能');
      case 2:
        return _buildBaitFlowStack();
      case 3:
        return _buildBetaPlaceholder('ガチャ機能');
      case 4:
        return _buildBetaPlaceholder('トーク機能');
      default:
        return _buildBaitFlowStack();
    }
  }

  Widget _buildBetaPlaceholder(String featureName) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFE3F6FC),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.construction_rounded,
                size: 54,
                color: Color(0xFF3DA9FC),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              featureName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'ベータ版で実装予定',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: const Color(0xFFE3F6FC),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Lv.$_currentLevel', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('現在の所持金', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
              Text(
                _totalMoney.toString().padLeft(7, '0'),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomTabBar() {
    return BottomNavigationBar(
      currentIndex: _currentTab,
      onTap: (index) {
        setState(() {
          _currentTab = index;
          if (index == 2) _currentBaitScreen = 1;
        });
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: const Color(0xFF3DA9FC),
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.black87,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.calendar_month, size: 26), label: 'カレンダー'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart, size: 26), label: 'グラフ'),
        BottomNavigationBarItem(icon: Icon(Icons.home, size: 32), label: 'ホーム'),
        BottomNavigationBarItem(icon: Icon(Icons.balance, size: 26), label: 'ガチャ'),
        BottomNavigationBarItem(icon: Icon(Icons.mail_outline, size: 26), label: 'トーク'),
      ],
    );
  }

  Widget _buildBaitFlowStack() {
    return IndexedStack(
      index: _currentBaitScreen - 1,
      children: [
        _buildHomeScreen(),
        _buildSetupScreen(),
        _buildTimerScreen(),
        _buildResultScreen(),
      ],
    );
  }

  Widget _buildCalendarTabWithGridTitles() {
    int daysInMonth = _getDaysInMonth(_displayYear, _displayMonth);
    int startOffset = _getStartOffset(_displayYear, _displayMonth);
    int totalCells = daysInMonth + startOffset;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('$_displayMonth月', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              Text('$_displayYear年', style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_box, size: 24, color: Colors.blue), 
                onPressed: _showAddEventDialog, 
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.arrow_left, color: Colors.black, size: 22),
                label: const Text('前月', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              TextButton.icon(
                onPressed: () => _changeMonth(1),
                icon: const Text('翌月', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                label: const Icon(Icons.arrow_right, color: Colors.black, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 4),

          Row(
            children: ['日', '月', '火', '水', '木', '金', '土'].map((day) {
              Color textColor = Colors.black87;
              if (day == '日') textColor = Colors.red;
              if (day == '土') textColor = Colors.blue;
              return Expanded(
                child: Center(child: Text(day, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor))),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),

          Container(
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300)),
            child: GridView.builder(
              shrinkWrap: true, 
              physics: const NeverScrollableScrollPhysics(), 
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.85, 
                mainAxisSpacing: 1,
                crossAxisSpacing: 1,
              ),
              itemCount: totalCells,
              itemBuilder: (context, index) {
                if (index < startOffset) {
                  return Container(color: Colors.grey.shade50); 
                }

                int dayNum = index - startOffset + 1;
                bool isSelected = _selectedDay == dayNum;
                bool isToday = _displayYear == _currentYear && _displayMonth == _currentMonth && dayNum == _currentDay;

                List<CalendarEvent> dayEvents = _calendarEvents.where((e) => e.year == _displayYear && e.month == _displayMonth && e.day == dayNum).toList();

                int weekdayIndex = index % 7; 
                Color dayColor = Colors.black87;
                if (weekdayIndex == 0) dayColor = Colors.red; 
                if (weekdayIndex == 6) dayColor = Colors.blue; 

                return InkWell(
                  onTap: () {
                    setState(() { _selectedDay = dayNum; });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFE3F6FC) : Colors.white,
                      border: Border.all(color: isSelected ? const Color(0xFF40A9FF) : Colors.grey.shade200, width: isSelected ? 1.5 : 0.5),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: isToday ? const BoxDecoration(color: Colors.blue, shape: BoxShape.circle) : null,
                          child: Text(
                            '$dayNum',
                            style: TextStyle(
                              fontSize: 11, 
                              fontWeight: FontWeight.bold, 
                              color: isToday ? Colors.white : dayColor
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Expanded(
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(), 
                            padding: EdgeInsets.zero,
                            itemCount: dayEvents.length,
                            itemBuilder: (context, evIndex) {
                              final ev = dayEvents[evIndex];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                                decoration: BoxDecoration(
                                  color: ev.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(2),
                                  border: Border(left: BorderSide(color: ev.color, width: 2)),
                                ),
                                child: Text(
                                  ev.title,
                                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: ev.color, overflow: TextOverflow.ellipsis),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          _buildFrequentEventsRow(),
          const Divider(height: 16, thickness: 1),
          
          Row(
            children: [
              const Text('リマインダー', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_box, size: 22, color: Colors.blue), 
                onPressed: _showAddReminderDialog, 
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildReminderListView(),
        ],
      ),
    );
  }

  Widget _buildFrequentEventsRow() {
    return SizedBox(
      height: 26,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _frequentEvents.length,
        itemBuilder: (context, index) {
          final freqTitle = _frequentEvents[index];
          return Container(
            margin: const EdgeInsets.only(right: 6),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.black87,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: () {
                setState(() {
                  _calendarEvents.add(CalendarEvent(year: _displayYear, month: _displayMonth, day: _selectedDay, title: freqTitle));
                });
                // クイック予定追加時も自動セーブ
                _saveAllData();
              },
              child: Text(freqTitle, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReminderListView() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(), 
      itemCount: _reminderList.length,
      itemBuilder: (context, index) {
        final item = _reminderList[index];
        int calcDaysLeft = item.targetDay - _currentDay;
        if (item.targetMonth > _currentMonth) calcDaysLeft += 30;
        if (calcDaysLeft < 0) calcDaysLeft = 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: calcDaysLeft <= 3 ? const Color(0xFFFFF1F0) : const Color(0xFFE6F7F8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Text('あと$calcDaysLeft日', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: calcDaysLeft <= 3 ? Colors.red : Colors.black87)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(item.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
              Text('${item.targetMonth}/${item.targetDay}', style: const TextStyle(fontSize: 12, color: Colors.black45)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHomeScreen() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            InkWell(
              onTap: () => setState(() => _currentBaitScreen = 2),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(color: const Color(0xFFEBF8FC), borderRadius: BorderRadius.circular(24)),
                child: const Column(
                  children: [
                    Text('バイトスタート', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black)),
                    SizedBox(height: 12),
                    Text('ここをタップ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Text('キャラ広場', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 10),
            _buildBetaPlaceholder('キャラ広場機能'),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupScreen() {
    bool isStartEnabled = _selectedSubject != null && _displayMinutes > 0;
    final List<Map<String, dynamic>> subjects = [
      {'name': '国語', 'color': const Color(0xFFFF3B30)},
      {'name': '数学', 'color': const Color(0xFF34A8F2)},
      {'name': '社会', 'color': const Color(0xFFFFD60A)},
      {'name': '理科', 'color': const Color(0xFF34C759)},
      {'name': '英語', 'color': const Color(0xFFAF52DE)},
      {'name': 'その他', 'color': const Color(0xFF8E8E93)},
    ];

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('何のバイトをしますか？', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.85, crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              final sub = subjects[index];
              bool isSelected = _selectedSubject == sub['name'];
              Color textColor = sub['name'] == '社会' ? Colors.black : Colors.white;
              
              return InkWell(
                onTap: () => setState(() { _selectedSubject = sub['name']; }),
                child: Container(
                  decoration: BoxDecoration(
                    color: sub['color'],
                    borderRadius: BorderRadius.circular(16),
                    border: isSelected ? Border.all(color: Colors.black, width: 4) : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(sub['name'], style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 4),
                      Text(
                        '($_wagePerMinute円/分)', 
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              _buildTimeButton('25分', 25),
              const SizedBox(width: 10),
              _buildTimeButton('50分', 50),
              const SizedBox(width: 10),
              _buildTimeButton('90分', 90),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isStartEnabled ? Colors.white : Colors.grey.shade200, padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: isStartEnabled ? _startTimer : null,
            child: Text('スタート', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isStartEnabled ? Colors.black : Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeButton(String text, int minutes) {
    bool isSelected = _displayMinutes == minutes;
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C781), side: isSelected ? const BorderSide(color: Colors.black, width: 4) : null),
        onPressed: () => setState(() => _displayMinutes = minutes),
        child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }

  Widget _buildTimerScreen() {
    int minutes = _remainingSeconds ~/ 60;
    int seconds = _remainingSeconds % 60;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, 
        crossAxisAlignment: CrossAxisAlignment.center, 
        children: [
          const Text(
            'バイトに集中しています...',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          Text(
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}', 
            style: const TextStyle(fontSize: 76, fontWeight: FontWeight.bold, letterSpacing: 2)
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: 160,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _endBait(isFinished: false), 
              child: const Text('中断する', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultScreen() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center, 
            crossAxisAlignment: CrossAxisAlignment.center, 
            children: [
              const Icon(Icons.stars, size: 64, color: Colors.amber),
              const SizedBox(height: 16),
              const Text('おつかれさまでした！', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Text(
                '$_lastDisplayMinutes 分 の勉強を達成！', 
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 8),
              Text(
                '+$_lastEarnedMoney 円 獲得しました！', 
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.redAccent)
              ),
              const SizedBox(height: 16),
              Text(
                '現在のレベル: Lv.$_currentLevel',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              const SizedBox(height: 50),
              SizedBox(
                width: 200,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3DA9FC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
                  ),
                  onPressed: _resetAndGoHome, 
                  child: const Text('ホームに戻る', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),

          if (_showLevelUpMotion)
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24), 
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_upward, size: 48, color: Colors.white),
                    SizedBox(height: 4),
                    Text(
                      'LEVEL UP!!',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showAddReminderDialog() {
    final titleController = TextEditingController();
    final dayController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('リマインダー追加'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: dayController, decoration: const InputDecoration(labelText: '日 (数値のみ)')),
            TextField(controller: titleController, decoration: const InputDecoration(labelText: '内容')),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('追加する', style: TextStyle(fontWeight: FontWeight.bold)), 
            onPressed: () {
              if (titleController.text.isNotEmpty && dayController.text.isNotEmpty) {
                setState(() {
                  _reminderList.add(ReminderItemData(
                    targetMonth: _displayMonth, 
                    targetDay: int.parse(dayController.text), 
                    title: titleController.text
                  ));
                });
                // リマインダー追加時も自動セーブ
                _saveAllData();
              }
              Navigator.pop(context);
            }
          ),
        ],
      ),
    );
  }
}