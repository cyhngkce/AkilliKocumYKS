import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:akillikocum/pages/home_page.dart';

class GoalSettingPage extends StatefulWidget {
  const GoalSettingPage({super.key});

  @override
  State<GoalSettingPage> createState() => _GoalSettingPageState();
}

class _GoalSettingPageState extends State<GoalSettingPage> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  
  // Controllers
  final TextEditingController _targetSchoolController = TextEditingController();
  final TextEditingController _targetDepartmentController = TextEditingController();
  final TextEditingController _targetRankController = TextEditingController();
  
  // State variables
  int _currentStep = 0;
  bool _isLoading = false;
  
  // Popular schools list for suggestions
  final List<String> _popularSchools = [
    'Boğaziçi Üniversitesi',
    'Orta Doğu Teknik Üniversitesi',
    'İstanbul Teknik Üniversitesi',
    'Hacettepe Üniversitesi',
    'İstanbul Üniversitesi',
    'Ankara Üniversitesi',
    'Koç Üniversitesi',
    'Sabancı Üniversitesi',
    'Bilkent Üniversitesi',
    'Marmara Üniversitesi',
  ];
  
  List<String> _filteredSchools = [];
  bool _showSchoolSuggestions = false;
  
  @override
  void initState() {
    super.initState();
    _filteredSchools = _popularSchools;
  }
  
  @override
  void dispose() {
    _targetSchoolController.dispose();
    _targetDepartmentController.dispose();
    _targetRankController.dispose();
    _pageController.dispose();
    super.dispose();
  }
  
  void _filterSchools(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredSchools = _popularSchools;
      } else {
        _filteredSchools = _popularSchools
            .where((school) => school.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
      _showSchoolSuggestions = query.isNotEmpty;
    });
  }
  
  Future<void> _saveGoals() async {
    if (_targetSchoolController.text.trim().isEmpty) {
      _showSnackBar('Lütfen hedef okul girin', isError: true);
      return;
    }
    
    if (_targetDepartmentController.text.trim().isEmpty) {
      _showSnackBar('Lütfen hedef bölüm girin', isError: true);
      return;
    }
    
    if (_targetRankController.text.trim().isEmpty) {
      _showSnackBar('Lütfen hedef sıralama girin', isError: true);
      return;
    }
    
    // Validate rank is a number
    final rank = int.tryParse(_targetRankController.text.trim());
    if (rank == null || rank <= 0) {
      _showSnackBar('Lütfen geçerli bir sıralama girin', isError: true);
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı bulunamadı. Lütfen tekrar giriş yapın.');
      }
      
      // Save to Firestore goals collection
      await FirebaseFirestore.instance.collection('goals').doc(user.uid).set({
        'userId': user.uid,
        'targetSchool': _targetSchoolController.text.trim(),
        'targetDepartment': _targetDepartmentController.text.trim(),
        'targetRank': rank,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        _showSnackBar('Hedefleriniz başarıyla kaydedildi!', isError: false);
        
        // Navigate to home page
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        }
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
  
  void _nextStep() {
    if (_currentStep == 0) {
      // Hedef okul kontrolü
      if (_targetSchoolController.text.trim().isEmpty) {
        _showSnackBar('Lütfen hedef okul girin', isError: true);
        return;
      }
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else if (_currentStep == 1) {
      // Hedef bölüm kontrolü
      if (_targetDepartmentController.text.trim().isEmpty) {
        _showSnackBar('Lütfen hedef bölüm girin', isError: true);
        return;
      }
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else if (_currentStep == 2) {
      // Son adım - sıralama kontrolü ve kaydet
      _saveGoals();
    }
  }
  
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade300,
              Colors.deepPurple.shade700,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildProgressIndicator(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildSchoolStep(),
                    _buildDepartmentStep(),
                    _buildRankStep(),
                  ],
                ),
              ),
              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
            ),
            child: const Icon(
              Icons.flag_outlined,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Hedeflerini Belirle',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Başarıya giden yolda ilk adım',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16),
      child: Row(
        children: List.generate(3, (index) {
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: index <= _currentStep
                    ? Colors.white
                    : Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
  
  Widget _buildSchoolStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hedef Üniversite',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hangi üniversiteyi hedefliyorsun?',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _targetSchoolController,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration(
                label: 'Üniversite Adı',
                hint: 'Örn: Boğaziçi Üniversitesi',
                icon: Icons.school_outlined,
              ),
              onChanged: _filterSchools,
              onTap: () {
                setState(() {
                  _showSchoolSuggestions = true;
                  _filteredSchools = _popularSchools;
                });
              },
            ),
            if (_showSchoolSuggestions && _filteredSchools.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filteredSchools.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(Icons.school, color: Colors.deepPurple),
                      title: Text(_filteredSchools[index]),
                      onTap: () {
                        setState(() {
                          _targetSchoolController.text = _filteredSchools[index];
                          _showSchoolSuggestions = false;
                        });
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Hedef üniversiteniz, çalışma planınızı şekillendirecek.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade900,
                      ),
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
  
  Widget _buildDepartmentStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hedef Bölüm',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hangi bölümü kazanmak istiyorsun?',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _targetDepartmentController,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration(
                label: 'Bölüm Adı',
                hint: 'Örn: Bilgisayar Mühendisliği',
                icon: Icons.bookmark_outline,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.amber.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bölümünüzü net olarak belirleyin. Bu, motivasyonunuzu artıracak.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber.shade900,
                      ),
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
  
  Widget _buildRankStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hedef Sıralama',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kaçıncı sıralamayı hedefliyorsun?',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _targetRankController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration(
                label: 'Hedef Sıralama',
                hint: 'Örn: 5000',
                icon: Icons.emoji_events_outlined,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.trending_up, color: Colors.green.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Hedef sıralamanız, gerçekçi ve ulaşılabilir olmalı.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurple.shade400,
                    Colors.deepPurple.shade600,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.rocket_launch,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Hedefleriniz Hazır!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Başarıya giden yolculuğunuz başlamak üzere',
                    textAlign: TextAlign.center,
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
      ),
    );
  }
  
  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }
  
  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.deepPurple),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Geri',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: _currentStep == 0 ? 1 : 1,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _currentStep == 2 ? 'Tamamla' : 'Devam',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
  
  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }
}