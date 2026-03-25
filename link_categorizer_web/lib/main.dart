import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Link Categorizer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        scaffoldBackgroundColor: const Color(0xFFF1F5F9), // Very light gray-blue background
        useMaterial3: true,
        fontFamily: 'Segoe UI', // Clean sans-serif
      ),
      home: const CategorizerPage(),
    );
  }
}

class LogItem {
  String text;
  String state; 
  LogItem({required this.text, required this.state});
}

class CategorizerPage extends StatefulWidget {
  const CategorizerPage({super.key});

  @override
  State<CategorizerPage> createState() => _CategorizerPageState();
}

class _CategorizerPageState extends State<CategorizerPage> {
  final TextEditingController _geminiKeyCtrl = TextEditingController();
  final TextEditingController _notionTokenCtrl = TextEditingController();
  final TextEditingController _dbIdCtrl = TextEditingController();
  final TextEditingController _linksCtrl = TextEditingController();
  
  bool _isProcessing = false;
  final List<LogItem> _results = [];

  @override
  void initState() {
    super.initState();
    _loadSavedKeys();
  }

  Future<void> _loadSavedKeys() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _geminiKeyCtrl.text = prefs.getString('gemini_key') ?? '';
      _notionTokenCtrl.text = prefs.getString('notion_token') ?? '';
      _dbIdCtrl.text = prefs.getString('db_id') ?? '';
    });
  }

  Future<void> _saveKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_key', _geminiKeyCtrl.text);
    await prefs.setString('notion_token', _notionTokenCtrl.text);
    await prefs.setString('db_id', _dbIdCtrl.text);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Configuration saved successfully.", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _processLinks() async {
    final rawLinks = _linksCtrl.text.split('\n');
    final urls = rawLinks.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    if (urls.isEmpty || _geminiKeyCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please provide API credentials and at least one URL."),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _results.clear();
    });

    for (String url in urls) {
      setState(() {
        _results.add(LogItem(text: "Processing: $url", state: 'loading'));
      });
      
      try {
        final response = await http.post(
          Uri.parse('http://127.0.0.1:8000/process_link'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "url": url,
            "gemini_key": _geminiKeyCtrl.text,
            "notion_token": _notionTokenCtrl.text,
            "database_id": _dbIdCtrl.text,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            _results[_results.length - 1] = LogItem(
              text: "[${data['category']}] ${data['title']}", 
              state: 'success'
            );
          });
        } else {
          setState(() {
            _results[_results.length - 1] = LogItem(
              text: "Failed: $url (${response.body})", 
              state: 'error'
            );
          });
        }
      } catch (e) {
        setState(() {
          _results[_results.length - 1] = LogItem(
            text: "Network Error: Python server unreachable.", 
            state: 'error'
          );
        });
      }

      await Future.delayed(const Duration(seconds: 10)); 
    }

    setState(() => _isProcessing = false);
  }

  // --- REUSABLE UI COMPONENTS ---

  Widget _buildTextField({required String label, required IconData icon, required TextEditingController controller, bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.black87),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter your ${label.toLowerCase()}',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFF8FAFC), // Very light grey fill
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: isPassword ? Icon(Icons.visibility_outlined, size: 20, color: Colors.grey.shade400) : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required String subtitle, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: Colors.black87),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.link, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Link Categorizer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                Text('Automatically organize your links with AI', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ],
        ),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 24),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Text('Beta', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            // TOP ROW: Config & URLs
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT CARD
                Expanded(
                  child: _buildSectionCard(
                    title: 'API Configuration',
                    subtitle: 'Configure your API credentials to enable link categorization',
                    icon: Icons.settings_outlined,
                    child: Column(
                      children: [
                        _buildTextField(label: 'Gemini API Key', icon: Icons.vpn_key_outlined, controller: _geminiKeyCtrl, isPassword: true),
                        const SizedBox(height: 20),
                        _buildTextField(label: 'Notion Token', icon: Icons.link_outlined, controller: _notionTokenCtrl, isPassword: true),
                        const SizedBox(height: 20),
                        _buildTextField(label: 'Notion Database ID', icon: Icons.storage_outlined, controller: _dbIdCtrl, isPassword: true),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _saveKeys,
                            icon: const Icon(Icons.settings, size: 18),
                            label: const Text('Save Configuration', style: TextStyle(fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4338CA), // Bright Indigo
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // RIGHT CARD
                Expanded(
                  child: _buildSectionCard(
                    title: 'Target URLs',
                    subtitle: 'Enter URLs to categorize (one per line)',
                    icon: Icons.link,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('URLs', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _linksCtrl,
                          maxLines: 13, // Matches the height of the left card nicely
                          style: TextStyle(fontSize: 13, fontFamily: 'monospace', color: Colors.grey.shade700),
                          decoration: InputDecoration(
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing ? null : _processLinks,
                            icon: _isProcessing 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.play_arrow_outlined, size: 20),
                            label: Text(_isProcessing ? 'Processing...' : 'Start Categorization', style: const TextStyle(fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A), // Dark Navy/Slate
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // BOTTOM ROW: Log Output
            _buildSectionCard(
              title: 'Execution Log',
              subtitle: 'Real-time status updates for categorization process',
              icon: Icons.info_outline,
              child: Container(
                constraints: const BoxConstraints(minHeight: 200),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: _results.isEmpty
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, size: 32, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text('No logs yet. Start categorization to see results.', style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      itemCount: _results.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _results[index];
                        return ListTile(
                          leading: _buildStatusIcon(item.state),
                          title: Text(
                            item.text, 
                            style: TextStyle(
                              color: item.state == 'error' ? Colors.red.shade900 : Colors.black87,
                              fontSize: 13,
                              fontFamily: 'monospace',
                            )
                          ),
                          dense: true,
                        );
                      },
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(String state) {
    switch (state) {
      case 'loading':
        return const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
      case 'success':
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      case 'error':
        return const Icon(Icons.error_outline, color: Colors.redAccent, size: 20);
      default:
        return const Icon(Icons.info_outline, size: 20);
    }
  }
}