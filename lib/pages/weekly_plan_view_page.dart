import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WeeklyPlanViewPage extends StatefulWidget {
  const WeeklyPlanViewPage({super.key});

  @override
  State<WeeklyPlanViewPage> createState() => _WeeklyPlanViewPageState();
}

class _WeeklyPlanViewPageState extends State<WeeklyPlanViewPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  bool _isLoading = true;
  bool _hasPlan = false;
  String _planType = '';
  Map<String, dynamic> _planData = {};
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
    _loadPlan();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadPlan() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final doc = await FirebaseFirestore.instance
          .collection('plans')
          .doc(user.uid)
          .get();
      
      if (doc.exists) {
        setState(() {
          _hasPlan = true;
          _planType = doc.data()?['planType'] ?? '';
          _planData = doc.data() ?? {};
        });
      } else {
        setState(() {
          _hasPlan = false;
        });
      }
    } catch (e) {
      print('Error loading plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Plan yüklenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _deletePlan() async {
    // Onay dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Planı Sil'),
        content: const Text('Haftalık planınızı silmek istediğinizden emin misiniz?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      await FirebaseFirestore.instance
          .collection('plans')
          .doc(user.uid)
          .delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plan başarıyla silindi'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // true = plan deleted
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.deepPurple,
        title: const Text(
          'Haftalık Planım',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: _hasPlan && !_isLoading
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  onPressed: _deletePlan,
                  tooltip: 'Planı Sil',
                ),
              ]
            : null,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.deepPurple,
              ),
            )
          : !_hasPlan
              ? _buildNoPlanView()
              : _buildPlanView(),
    );
  }
  
  Widget _buildNoPlanView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today_outlined,
                size: 80,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Henüz Plan Oluşturmadınız',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Haftalık planınızı oluşturarak\nhedeflerinize ulaşmaya başlayın',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.add),
              label: const Text('Plan Oluştur'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPlanView() {
    return Column(
      children: [
        _buildPlanTypeHeader(),
        _buildDayTabs(),
        Expanded(
          child: _planType == 'goal-based'
              ? _buildGoalBasedView()
              : _buildTimeBasedView(),
        ),
      ],
    );
  }
  
  Widget _buildPlanTypeHeader() {
    final isGoalBased = _planType == 'goal-based';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isGoalBased
              ? [Colors.purple.shade400, Colors.purple.shade600]
              : [Colors.blue.shade400, Colors.blue.shade600],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isGoalBased ? Icons.checklist_rounded : Icons.schedule_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isGoalBased ? 'Hedef Odaklı Plan' : 'Saat Saat Plan',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isGoalBased
                      ? 'Yapılacaklar listesi'
                      : 'Zaman dilimleri',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
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
          final activities = _getActivitiesForDay(day);
          final count = activities.length;
          
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
  
  List<dynamic> _getActivitiesForDay(String day) {
    if (_planData[day] == null) return [];
    return _planData[day] as List<dynamic>;
  }
  
  Widget _buildGoalBasedView() {
    return TabBarView(
      controller: _tabController,
      children: _weekDays.map((day) {
        final activities = _getActivitiesForDay(day);
        
        return activities.isEmpty
            ? _buildEmptyDayView()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: activities.length,
                itemBuilder: (context, index) {
                  final activity = activities[index] as String;
                  return _buildGoalActivityCard(activity, index);
                },
              );
      }).toList(),
    );
  }
  
  Widget _buildTimeBasedView() {
    return TabBarView(
      controller: _tabController,
      children: _weekDays.map((day) {
        final activities = _getActivitiesForDay(day);
        
        return activities.isEmpty
            ? _buildEmptyDayView()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: activities.length,
                itemBuilder: (context, index) {
                  final activity = activities[index] as Map<String, dynamic>;
                  return _buildTimeSlotCard(activity);
                },
              );
      }).toList(),
    );
  }
  
  Widget _buildEmptyDayView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Bu gün için plan yok',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGoalActivityCard(String activity, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade400, Colors.purple.shade600],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                activity,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.check_circle_outline,
                color: Colors.green.shade600,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTimeSlotCard(Map<String, dynamic> activity) {
    final startTime = activity['startTime'] ?? '';
    final endTime = activity['endTime'] ?? '';
    final activityName = activity['activity'] ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.schedule,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activityName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$startTime - $endTime',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.check_circle_outline,
                color: Colors.green.shade600,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}