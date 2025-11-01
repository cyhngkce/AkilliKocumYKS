import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WeeklyPlanCreatePage extends StatefulWidget {
  final bool isEdit;
  final Map<String, dynamic>? existingPlanData;
  
  const WeeklyPlanCreatePage({
    super.key,
    this.isEdit = false,
    this.existingPlanData,
  });

  @override
  State<WeeklyPlanCreatePage> createState() => _WeeklyPlanCreatePageState();
}

class _WeeklyPlanCreatePageState extends State<WeeklyPlanCreatePage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  
  // Plan türü seçim aşaması
  bool _planTypeSelected = false;
  
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
    
    // Düzenleme modundaysa mevcut planı yükle
    if (widget.isEdit && widget.existingPlanData != null) {
      _loadExistingPlan();
    }
  }
  
  void _loadExistingPlan() {
    final data = widget.existingPlanData!;
    
    // Plan türünü belirle
    final planType = data['planType'] ?? 'goal-based';
    _selectedMode = planType == 'goal-based' ? 0 : 1;
    _planTypeSelected = true;
    
    // Verileri yükle
    for (String day in _weekDays) {
      if (data.containsKey(day)) {
        if (_selectedMode == 0) {
          // Hedef odaklı plan
          final activities = data[day] as List<dynamic>?;
          if (activities != null) {
            _goalBasedPlan[day] = activities.map((e) => e.toString()).toList();
          }
        } else {
          // Saat saat plan
          final timeSlots = data[day] as List<dynamic>?;
          if (timeSlots != null) {
            _timeBasedPlan[day] = timeSlots.map((e) {
              final slot = e as Map<String, dynamic>;
              return TimeSlot(
                startTime: slot['startTime'] ?? '',
                endTime: slot['endTime'] ?? '',
                activity: slot['activity'] ?? '',
              );
            }).toList();
          }
        }
      }
    }
    
    setState(() {});
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  // Saat sıralaması için karşılaştırma fonksiyonu
  int _compareTimeSlots(TimeSlot a, TimeSlot b) {
    try {
      final aTime = a.startTime.split(':');
      final bTime = b.startTime.split(':');
      
      final aHour = int.parse(aTime[0]);
      final aMin = int.parse(aTime[1]);
      final bHour = int.parse(bTime[0]);
      final bMin = int.parse(bTime[1]);
      
      if (aHour != bHour) {
        return aHour.compareTo(bHour);
      }
      return aMin.compareTo(bMin);
    } catch (e) {
      return 0;
    }
  }
  
  Future<void> _savePlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Validasyon kontrolleri
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
        'createdAt': widget.isEdit ? widget.existingPlanData!['createdAt'] : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (_selectedMode == 0) {
        // Hedef odaklı plan
        _weekDays.forEach((day) {
          planData[day] = _goalBasedPlan[day] ?? [];
        });
      } else {
        // Saat saat plan - Saatlere göre sırala ve Map'e çevir
        _weekDays.forEach((day) {
          final slots = _timeBasedPlan[day] ?? [];
          // Saatlere göre sırala
          slots.sort(_compareTimeSlots);
          
          planData[day] = slots.map((slot) {
            return {
              'startTime': slot.startTime,
              'endTime': slot.endTime,
              'activity': slot.activity,
              'completed': false, // Yeni eklenen: tamamlanma durumu
            };
          }).toList();
        });
      }
      
      // Firestore'a kaydet
      await FirebaseFirestore.instance
          .collection('plans')
          .doc(user.uid)
          .set(planData);
      
      if (mounted) {
        _showSnackBar(
          widget.isEdit 
            ? 'Haftalık planınız başarıyla güncellendi!' 
            : 'Haftalık planınız başarıyla kaydedildi!',
          isError: false
        );
        await Future.delayed(const Duration(seconds: 1));
        Navigator.pop(context, true);
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
                        // Ekledikten sonra sırala
                        _timeBasedPlan[_selectedDay]!.sort(_compareTimeSlots);
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
        title: Text(
          widget.isEdit
            ? 'Planı Düzenle'
            : (_planTypeSelected ? 'Plan Oluştur' : 'Plan Türü Seç'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (_planTypeSelected && !widget.isEdit) {
              setState(() => _planTypeSelected = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: _planTypeSelected ? _buildPlanCreationView() : _buildPlanTypeSelection(),
    );
  }
  
  Widget _buildPlanTypeSelection() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_month,
                size: 64,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Hangi Tür Plan Oluşturmak\nİstersiniz?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Size uygun plan türünü seçin',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 48),
            _buildPlanTypeCard(
              mode: 0,
              icon: Icons.checklist_rounded,
              title: 'Hedef Odaklı Plan',
              subtitle: 'Yapılacaklar listesi şeklinde',
              description: 'Her gün için hedeflerinizi belirleyin ve tamamlayın',
              color: Colors.purple,
            ),
            const SizedBox(height: 20),
            _buildPlanTypeCard(
              mode: 1,
              icon: Icons.schedule_rounded,
              title: 'Saat Saat Plan',
              subtitle: 'Zaman dilimleri şeklinde',
              description: 'Gününüzü saat bazında planlayın ve takip edin',
              color: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPlanTypeCard({
    required int mode,
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required MaterialColor color,
  }) {
    final isSelected = _selectedMode == mode;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMode = mode;
          _planTypeSelected = true;
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.shade400, color.shade600],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.shade400, color.shade600],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Bu Planı Seç',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPlanCreationView() {
    return Column(
      children: [
        _buildDayTabs(),
        Expanded(
          child: _selectedMode == 0
              ? _buildGoalBasedPlanView()
              : _buildTimeBasedPlanView(),
        ),
        _buildBottomBar(),
      ],
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