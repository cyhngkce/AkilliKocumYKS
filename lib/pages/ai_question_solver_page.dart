import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:akillikocum/config/api_config.dart';

class AiQuestionSolverPage extends StatefulWidget {
  const AiQuestionSolverPage({super.key});

  @override
  State<AiQuestionSolverPage> createState() => _AiQuestionSolverPageState();
}

class _AiQuestionSolverPageState extends State<AiQuestionSolverPage>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isAnalyzing = false;
  String? _solution;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = image;
          _solution = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Galeri açılırken hata oluştu: $e');
    }
  }
  
  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = image;
          _solution = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Kamera açılırken hata oluştu: $e');
    }
  }
  
  Future<String> _encodeImageToBase64(XFile image) async {
    final bytes = await image.readAsBytes();
    return base64Encode(bytes);
  }
  
  Future<void> _analyzeQuestion() async {
    if (_selectedImage == null) {
      _showErrorSnackBar('Lütfen önce bir görsel seçin');
      return;
    }
    
    setState(() {
      _isAnalyzing = true;
      _solution = null;
      _errorMessage = null;
    });
    
    try {
      // Görseli base64'e çevir
      final base64Image = await _encodeImageToBase64(_selectedImage!);
      
      // DeepSeek API'ye istek gönder
      final response = await http.post(
        Uri.parse(ApiConfig.deepSeekApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${ApiConfig.deepSeekApiKey}',
        },
        body: jsonEncode({
          'model': 'deepseek-chat',
          'messages': [
            {
              'role': 'system',
              'content': '''Sen deneyimli bir öğretmen ve YKS (Yükseköğretim Kurumları Sınavı) uzmanısın. 
Öğrencilere soruları detaylı ve anlaşılır bir şekilde çözmekte ustasın.

Görevlerin:
1. Görüntüdeki soruyu dikkatlice analiz et
2. Sorunun hangi konuya ait olduğunu belirle
3. Adım adım çözüm sun
4. Her adımda neden o işlemi yaptığını açıkla
5. Alternatif çözüm yöntemleri varsa belirt
6. Benzer sorular için ipuçları ver
7. Konuyla ilgili önemli formülleri hatırlat

Cevabını şu formatta ver:
📚 KONU: [Konu adı]
📝 SORU TİPİ: [Soru tipi]

🔍 ANALİZ:
[Sorunun analizi]

✅ ÇÖZÜM:
[Adım adım detaylı çözüm]

💡 İPUÇLARI:
[Önemli noktalar ve ipuçları]

📖 FORMÜLLER:
[İlgili formüller]

Açıklaman Türkçe, net, anlaşılır ve öğretici olmalı.'''
            },
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': 'Bu soruyu detaylı bir şekilde çözer misin? Adım adım açıklayarak ilerle.'
                },
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/jpeg;base64,$base64Image'
                  }
                }
              ]
            }
          ],
          'temperature': 0.7,
          'max_tokens': 2000,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        setState(() {
          _solution = content;
          _isAnalyzing = false;
        });
      } else {
        throw Exception('API Hatası: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _errorMessage = 'Analiz yapılırken hata oluştu: $e';
      });
      _showErrorSnackBar(_errorMessage!);
    }
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
  
  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Soru Fotoğrafı Seç',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            _buildSourceOption(
              icon: Icons.photo_library_rounded,
              title: 'Galeriden Seç',
              subtitle: 'Var olan bir fotoğrafı seç',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
            const SizedBox(height: 12),
            _buildSourceOption(
              icon: Icons.camera_alt_rounded,
              title: 'Fotoğraf Çek',
              subtitle: 'Kamera ile yeni fotoğraf çek',
              color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                _pickImageFromCamera();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSourceOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 20),
          ],
        ),
      ),
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
          'AI Soru Çözücü',
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
          _buildHeaderCard(),
          Expanded(
            child: _selectedImage == null
                ? _buildEmptyState()
                : _buildContentView(),
          ),
        ],
      ),
      floatingActionButton: _selectedImage != null && !_isAnalyzing && _solution == null
          ? ScaleTransition(
              scale: _pulseAnimation,
              child: FloatingActionButton.extended(
                onPressed: _analyzeQuestion,
                backgroundColor: Colors.deepPurple,
                icon: const Icon(Icons.auto_awesome, color: Colors.white),
                label: const Text(
                  'Soruyu Çöz',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
  
  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade600],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI ile Soru Çöz',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sorunun fotoğrafını çek, detaylı çözüm al',
                  style: TextStyle(
                    fontSize: 13,
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
  
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurple.shade100,
                    Colors.deepPurple.shade50,
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                size: 80,
                color: Colors.deepPurple.shade400,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Sorunun Fotoğrafını Ekle',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Çözmek istediğin sorunun fotoğrafını\nçek veya galerinden seç',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            _buildFeatureList(),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _showImageSourceDialog,
              icon: const Icon(Icons.add_photo_alternate, size: 24),
              label: const Text(
                'Fotoğraf Ekle',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFeatureList() {
    final features = [
      {'icon': Icons.auto_awesome, 'text': 'Yapay zeka destekli çözüm'},
      {'icon': Icons.description_outlined, 'text': 'Adım adım detaylı açıklama'},
      {'icon': Icons.lightbulb_outline, 'text': 'Konuyla ilgili ipuçları'},
      {'icon': Icons.functions, 'text': 'İlgili formüller ve kurallar'},
    ];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: features.map((feature) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    feature['icon'] as IconData,
                    color: Colors.deepPurple,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    feature['text'] as String,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
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
  
  Widget _buildContentView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImagePreview(),
          const SizedBox(height: 16),
          if (_isAnalyzing) _buildLoadingWidget(),
          if (_solution != null) _buildSolutionWidget(),
          const SizedBox(height: 100), // FAB için boşluk
        ],
      ),
    );
  }
  
  Widget _buildImagePreview() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.image_outlined,
                  color: Colors.deepPurple,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Seçilen Soru',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _selectedImage = null;
                      _solution = null;
                      _errorMessage = null;
                    });
                  },
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: Image.file(
              File(_selectedImage!.path),
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoadingWidget() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.deepPurple.shade400,
                    ),
                  ),
                ),
                Icon(
                  Icons.auto_awesome,
                  color: Colors.deepPurple.shade400,
                  size: 32,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'AI Soruyu Analiz Ediyor...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Bu işlem birkaç saniye sürebilir',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildSolutionWidget() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
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
                  gradient: LinearGradient(
                    colors: [
                      Colors.green.shade400,
                      Colors.green.shade600,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Çözüm Hazır!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: SelectableText(
              _solution!,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedImage = null;
                      _solution = null;
                      _errorMessage = null;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Yeni Soru'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.deepPurple, width: 2),
                    foregroundColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}