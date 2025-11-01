import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WeeklyPlanCreatePage extends StatefulWidget {
  const WeeklyPlanCreatePage({super.key});

  @override
  State<WeeklyPlanCreatePage> createState() => _WeeklyPlanCreatePageState();
}

class _WeeklyPlanCreatePageState extends State<WeeklyPlanCreatePage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  
  // Plan modu
  int _selectedMode = 0; // 0: Hedef Odaklı, 1: Saat Saat
  
  // Hedef odaklı plan için
  final Map<String, List<String>> _goalBasedPlan = {
    'Pazartesi': [],
    'Salı': [],
    'Çarşamba': [],
    'Perşembe': [],
    'Cuma': [],
    'Cumartesi': [],
    'Pazar': [],
  };
  
  // Saat saat plan için
  final Map<String, List<TimeSlot>> _timeBasedPlan = {
    'Pazartesi': [],
    'Salı': [],
    'Çarşamba': [],
    'Perşembe': [],
    'Cuma': [],
    'Cumartesi': [],
    'Pazar': [],
  };
  
  bool _isLoading = false;
  String _selectedDay = 'Pazartesi';
  
  final List<String> _weekDays = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedDay = _weekDays[_tabController.index];
        });
      }
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _savePlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Validate that at least one day has activities
    bool hasActivities = false;
    
    if (_selectedMode == 0) {
      hasActivities = _goalBasedPlan.values.any((list) => list.isNotEmpty);
    } else {
      hasActivities = _timeBasedPlan.values.any((list) => list.isNotEmpty);
    }
    
    if (!hasActivities) {
      _showSnackBar('Lütfen en az bir gün için plan ekleyin!', isError: true);
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      Map<String, dynamic> planData = {
        'userId': user.uid,
        'planType': _selectedMode == 0 ? 'goal-based' : 'time-based',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (_selectedMode == 0) {
        // Hedef odaklı plan
        _weekDays.forEach((day) {
          planData[day] = _goalBasedPlan[day] ?? [];
        });
      } else {
        // Saat saat plan - TimeSlot'ları Map'e çevir
        _weekDays.forEach((day) {
          planData[day] = (_timeBasedPlan[day] ?? []).map((slot) {
            return '${slot.startTime} - ${slot.endTime}: ${slot.activity}';
          }).toList();
        });
      }
      
      // Firestore'a kaydet
      await FirebaseFirestore.instance
          .collection('plans')
          .doc(user.uid)
          .set(planData);
      
      if (mounted) {
        _showSnackBar('Haftalık planınız başarıyla kaydedildi!', isError: false);
        await Future.delayed(const Duration(seconds: 1));
        Navigator.pop(context, true); // true = plan created
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Hata: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
  
  void _addGoalBasedActivity() {
    showDialog(
      context: context,
      builder: (context) {
        String activity = '';
        return AlertDialog(
          title: Text('$_selectedDay - Aktivite Ekle'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Örn: Matematik konusu çalış',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => activity = value,
            textCapitalization: TextCapitalization.sentences,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (activity.trim().isNotEmpty) {
                  setState(() {
                    _goalBasedPlan[_selectedDay]!.add(activity.trim());
                  });
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ekle'),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }
  
  void _addTimeBasedActivity() {
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    String activity = '';
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('$_selectedDay - Zaman Dilimi Ekle'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.access_time, color: Colors.deepPurple),
                      title: const Text('Başlangıç Saati'),
                      subtitle: Text(
                        startTime != null
                            ? '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}'
                            : 'Seçilmedi',
                      ),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: Colors.deepPurple,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (time != null) {
                          setDialogState(() => startTime = time);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: const Icon(Icons.access_time, color: Colors.deepPurple),
                      title: const Text('Bitiş Saati'),
                      subtitle: Text(
                        endTime != null
                            ? '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}'
                            : 'Seçilmedi',
                      ),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: Colors.deepPurple,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (time != null) {
                          setDialogState(() => endTime = time);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Aktivite',
                        hintText: 'Örn: Matematik çalış',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => activity = value,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (startTime != null &&
                        endTime != null &&
                        activity.trim().isNotEmpty) {
                      setState(() {
                        _timeBasedPlan[_selectedDay]!.add(
                          TimeSlot(
                            startTime: '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}',
                            endTime: '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}',
                            activity: activity.trim(),
                          ),
                        );
                      });
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Lütfen tüm alanları doldurun'),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Ekle'),
                ),
              ],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            );
          },
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.deepPurple,
        title: const Text(
          'Haftalık Plan Oluştur',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildPlanModeSelector(),
          _buildDayTabs(),
          Expanded(
            child: _selectedMode == 0
                ? _buildGoalBasedPlanView()
                : _buildTimeBasedPlanView(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }
  
  Widget _buildPlanModeSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plan Türü Seçin',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildModeCard(
                  index: 0,
                  icon: Icons.flag_outlined,
                  title: 'Hedef Odaklı',
                  subtitle: 'Yapılacaklar listesi',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModeCard(
                  index: 1,
                  icon: Icons.schedule_outlined,
                  title: 'Saat Saat',
                  subtitle: 'Zaman dilimleri',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildModeCard({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedMode == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMode = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.deepPurple : Colors.grey.shade600,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.deepPurple : Colors.black87,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDayTabs() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: Colors.deepPurple,
        labelColor: Colors.deepPurple,
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 14,
        ),
        tabs: _weekDays.map((day) {
          final dayShort = day.substring(0, 3);
          final count = _selectedMode == 0
              ? _goalBasedPlan[day]?.length ?? 0
              : _timeBasedPlan[day]?.length ?? 0;
          
          return Tab(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(dayShort),
                if (count > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      count.toString(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildGoalBasedPlanView() {
    return TabBarView(
      controller: _tabController,
      children: _weekDays.map((day) {
        final activities = _goalBasedPlan[day] ?? [];
        
        return Column(
          children: [
            Expanded(
              child: activities.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: activities.length,
                      itemBuilder: (context, index) {
                        return _buildGoalActivityCard(
                          activity: activities[index],
                          index: index,
                          day: day,
                        );
                      },
                    ),
            ),
          ],
        );
      }).toList(),
    );
  }
  
  Widget _buildTimeBasedPlanView() {
    return TabBarView(
      controller: _tabController,
      children: _weekDays.map((day) {
        final timeSlots = _timeBasedPlan[day] ?? [];
        
        return Column(
          children: [
            Expanded(
              child: timeSlots.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: timeSlots.length,
                      itemBuilder: (context, index) {
                        return _buildTimeSlotCard(
                          slot: timeSlots[index],
                          index: index,
                          day: day,
                        );
                      },
                    ),
            ),
          ],
        );
      }).toList(),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _selectedMode == 0 ? Icons.playlist_add : Icons.schedule,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Henüz aktivite eklenmedi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aşağıdaki butona basarak\naktivite ekleyebilirsiniz',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGoalActivityCard({
    required String activity,
    required int index,
    required String day,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
          ),
        ),
        title: Text(
          activity,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () {
            setState(() {
              _goalBasedPlan[day]!.removeAt(index);
            });
          },
        ),
      ),
    );
  }
  
  Widget _buildTimeSlotCard({
    required TimeSlot slot,
    required int index,
    required String day,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.schedule,
            color: Colors.blue,
            size: 24,
          ),
        ),
        title: Text(
          slot.activity,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${slot.startTime} - ${slot.endTime}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () {
            setState(() {
              _timeBasedPlan[day]!.removeAt(index);
            });
          },
        ),
      ),
    );
  }
  
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _selectedMode == 0
                    ? _addGoalBasedActivity
                    : _addTimeBasedActivity,
                icon: const Icon(Icons.add),
                label: Text(
                  _selectedMode == 0 ? 'Aktivite Ekle' : 'Zaman Dilimi Ekle',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.deepPurple, width: 2),
                  foregroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _savePlan,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_isLoading ? 'Kaydediliyor...' : 'Kaydet'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// TimeSlot sınıfı
class TimeSlot {
  final String startTime;
  final String endTime;
  final String activity;
  
  TimeSlot({
    required this.startTime,
    required this.endTime,
    required this.activity,
  });
}