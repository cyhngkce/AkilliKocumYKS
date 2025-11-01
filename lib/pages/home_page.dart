import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:akillikocum/pages/weekly_plan_create_page.dart';
import 'package:akillikocum/pages/weekly_plan_view_page.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final user = FirebaseAuth.instance.currentUser;
  
  // User data
  String userName = '';
  String targetSchool = '';
  String targetDepartment = '';
  int targetRank = 0;
  bool hasWeeklyPlan = false;
  bool isLoading = true;
  
  // Countdown
  late Timer _timer;
  Duration _timeUntilTYT = const Duration();
  
  // TYT Sınav Tarihi
  final DateTime tytExamDate = DateTime(2026, 6, 20, 10, 0); // 20 Haziran 2026 10:00
  
  // Motivasyon sözleri
  final List<String> motivationalQuotes = [
    "Başarı, küçük çabaların günden güne tekrarlanmasıdır. 💪",
    "Hayallerinizin peşinden gitmeye başladığınız gün, her şey mümkün olur. ✨",
    "Bugün yaptığın fedakarlık, yarının başarısıdır. 🌟",
    "İmkansız, sadece denemeyenlerin sözlüğündedir. 🚀",
    "Her gün, hedefinize bir adım daha yakınsınız. 🎯",
    "Azim ve çalışma, başarının anahtarıdır. 🔑",
    "Kendinize inanın, sınırlarınızı zorlayın! 💫",
    "Büyük başarılar, küçük adımlarla başlar. 👣",
    "Yorulabilirsiniz, ama asla pes etmeyin! 🦾",
    "En karanlık gece bile bir sabaha uyanır. 🌅",
  ];
  
  String dailyQuote = '';
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
    _startCountdown();
    _setDailyQuote();
  }
  
  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
  
  void _setDailyQuote() {
    final today = DateTime.now();
    final seed = today.year * 10000 + today.month * 100 + today.day;
    final index = seed % motivationalQuotes.length;
    setState(() {
      dailyQuote = motivationalQuotes[index];
    });
  }
  
  void _startCountdown() {
    _updateCountdown();
    _timer = Timer.periodic(const Duration(hours: 1), (timer) {
      _updateCountdown();
    });
  }
  
  void _updateCountdown() {
    final now = DateTime.now();
    setState(() {
      _timeUntilTYT = tytExamDate.difference(now);
    });
  }
  
  Future<void> _loadUserData() async {
    if (user == null) return;
    
    try {
      // Load user profile
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      
      if (userDoc.exists) {
        setState(() {
          userName = userDoc.data()?['name'] ?? '';
        });
      }
      
      // Load goals
      final goalsDoc = await FirebaseFirestore.instance
          .collection('goals')
          .doc(user!.uid)
          .get();
      
      if (goalsDoc.exists) {
        setState(() {
          targetSchool = goalsDoc.data()?['targetSchool'] ?? '';
          targetDepartment = goalsDoc.data()?['targetDepartment'] ?? '';
          targetRank = goalsDoc.data()?['targetRank'] ?? 0;
        });
      }
      
      // Check if user has weekly plan
      final plansQuery = await FirebaseFirestore.instance
          .collection('plans')
          .doc(user!.uid)
          .get();
      
      setState(() {
        hasWeeklyPlan = plansQuery.exists;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }
  
  String _getCountdownText() {
    if (_timeUntilTYT.isNegative) {
      return 'TYT sınavı geçti';
    }
    
    final totalDays = _timeUntilTYT.inDays;
    final years = totalDays ~/ 365;
    final remainingDaysAfterYears = totalDays % 365;
    final months = remainingDaysAfterYears ~/ 30;
    final days = remainingDaysAfterYears % 30;
    final hours = _timeUntilTYT.inHours % 24;
    
    List<String> parts = [];
    if (years > 0) parts.add('$years yıl');
    if (months > 0) parts.add('$months ay');
    if (days > 0) parts.add('$days gün');
    
    return parts.isEmpty ? 'Bugün!' : parts.join(' ');
  }
  
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.deepPurple),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        color: Colors.deepPurple,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildQuoteCard(),
              _buildGoalCard(),
              _buildCountdownCard(),
              _buildFeaturesGrid(),
              const SizedBox(height: 100), // Space for bottom nav
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
  
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.deepPurple,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Colors.deepPurple,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Akıllı Koçum',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'YKS',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {
            // TODO: Bildirimler sayfası
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bildirimler özelliği yakında!')),
            );
          },
        ),
      ],
    );
  }
  
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.deepPurple,
            Colors.deepPurple.shade300,
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hoş Geldin, $userName! 👋',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateTime.now().hour < 12
                ? 'Günaydın! Yeni bir gün, yeni bir fırsat 🌅'
                : DateTime.now().hour < 18
                    ? 'İyi günler! Çalışmalarına devam et 📚'
                    : 'İyi akşamlar! Başarılı bir gün geçirdin 🌙',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuoteCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade400, Colors.orange.shade400],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.format_quote,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              dailyQuote,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGoalCard() {
    if (targetSchool.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.deepPurple.shade100, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.1),
            blurRadius: 10,
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.flag_rounded,
                  color: Colors.deepPurple,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Mevcut Hedefin',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.deepPurple.shade50,
                  Colors.deepPurple.shade100,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        targetSchool,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (targetDepartment.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          targetDepartment,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.deepPurple.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        'Hedef Sıralama: ${_formatNumber(targetRank)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.deepPurple.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.deepPurple,
                  size: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCountdownCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade400,
            Colors.blue.shade600,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Hayallerine Ulaşmana',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _getCountdownText(),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'TYT Sınav Tarihi: ${tytExamDate.day} ${_getMonthName(tytExamDate.month)} ${tytExamDate.year}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            'Saat: ${tytExamDate.hour.toString().padLeft(2, '0')}:${tytExamDate.minute.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildFeaturesGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Özellikler',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              // Responsive card sizing
              final cardWidth = (constraints.maxWidth - 16) / 2;
              final cardHeight = cardWidth * 0.95; // Slightly shorter aspect ratio
              
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: _buildFeatureCard(
                      icon: hasWeeklyPlan ? Icons.visibility_rounded : Icons.calendar_today_rounded,
                      title: hasWeeklyPlan ? 'Haftalık Planını\nGörüntüle' : 'Haftalık Plan\nOluştur',
                      color1: const Color(0xFFAB47BC),
                      color2: const Color(0xFF8E24AA),
                      onTap: () async {
                        if (hasWeeklyPlan) {
                          // Plan görüntüleme sayfasına git
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WeeklyPlanViewPage(),
                            ),
                          );
                          
                          // Plan silindiyse ana sayfayı yenile
                          if (result == true) {
                            _loadUserData();
                          }
                        } else {
                          // Plan oluşturma sayfasına git
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WeeklyPlanCreatePage(),
                            ),
                          );
                          
                          // Plan oluşturulduysa ana sayfayı yenile
                          if (result == true) {
                            _loadUserData();
                          }
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: _buildFeatureCard(
                      icon: Icons.analytics_rounded,
                      title: 'Deneme\nAnalizi Yap',
                      color1: const Color(0xFF42A5F5),
                      color2: const Color(0xFF1E88E5),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Deneme analizi özelliği yakında!'),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: _buildFeatureCard(
                      icon: Icons.menu_book_rounded,
                      title: 'Konu\nÖzetleri',
                      color1: const Color(0xFF66BB6A),
                      color2: const Color(0xFF43A047),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Konu özetleri özelliği yakında!'),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: _buildFeatureCard(
                      icon: Icons.help_outline_rounded,
                      title: 'Sorunu\nÇözelim',
                      color1: const Color(0xFFFFA726),
                      color2: const Color(0xFFFB8C00),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Soru çözme özelliği yakında!'),
                          ),
                        );
                      },
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
  
  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required Color color1,
    required Color color2,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color1, color2],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color1.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      icon,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildBottomNav() {
    return Container(
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_rounded,
                label: 'Ana Sayfa',
                isSelected: true,
                onTap: () {},
              ),
              _buildNavItem(
                icon: Icons.psychology_rounded,
                label: 'AI Asistan',
                isSelected: false,
                onTap: () {
                  // TODO: AI Asistan sayfası
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('AI Asistan özelliği yakında!'),
                    ),
                  );
                },
              ),
              _buildNavItem(
                icon: Icons.person_rounded,
                label: 'Profil',
                isSelected: false,
                onTap: () {
                  // TODO: Profil sayfası
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profil sayfası yakında!'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.deepPurple : Colors.grey.shade600,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.deepPurple : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
  
  String _getMonthName(int month) {
    const months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return months[month - 1];
  }
}