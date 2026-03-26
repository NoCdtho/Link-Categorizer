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
      title: 'URLHUB',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0C10), // Deep space black/blue
        useMaterial3: true,
        fontFamily: 'Segoe UI',
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
  int _urlCount = 0;
  final List<LogItem> _results = [];

  // Theme Colors based on your screenshot
  final Color _cardColor = const Color(0xFF161B22);
  final Color _inputColor = const Color(0xFF010409);
  final Color _borderColor = const Color(0xFF30363D);
  final Color _neonPurple = const Color(0xFF8B5CF6);
  final Color _neonPink = const Color(0xFFEC4899);

  @override
  void initState() {
    super.initState();
    _loadSavedKeys();
    _linksCtrl.addListener(_updateUrlCount);
  }

  @override
  void dispose() {
    _linksCtrl.removeListener(_updateUrlCount);
    _linksCtrl.dispose();
    super.dispose();
  }

  void _updateUrlCount() {
    final rawLinks = _linksCtrl.text.split('\n');
    final count = rawLinks.where((e) => e.trim().isNotEmpty).length;
    setState(() {
      _urlCount = count;
    });
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
          backgroundColor: _neonPurple,
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
          backgroundColor: Colors.redAccent,
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
          // MAKE SURE TO CHANGE THIS BACK TO YOUR RENDER URL BEFORE DEPLOYING
          Uri.parse('https://link-categorizer-backend.onrender.com/process_link'),
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

  // --- REUSABLE NEON WIDGETS ---

  Widget _buildTextField({required String label, required TextEditingController controller, bool isPassword = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (maxLines == 1) ...[
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          obscureText: isPassword,
          maxLines: maxLines,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade300, fontFamily: maxLines > 1 ? 'monospace' : 'Segoe UI'),
          decoration: InputDecoration(
            hintText: maxLines > 1 ? 'https://example.com\nhttps://another-site.com' : 'Enter your ${label.toLowerCase()}',
            hintStyle: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            filled: true,
            fillColor: _inputColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            suffixIcon: isPassword ? Icon(Icons.visibility_outlined, size: 18, color: Colors.grey.shade600) : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _neonPurple, width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildNeonCard({required String title, required String subtitle, required IconData icon, required Widget child, Gradient? headerGradient, Color? headerColor}) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colored Header Area
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: headerGradient,
              color: headerColor,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Colors.white),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),
          // Content Area
          Padding(
            padding: const EdgeInsets.all(24),
            child: child,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _cardColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _borderColor, height: 1),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _neonPurple, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.link, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('URLHUB', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2)),
                Text('Automatically organize your links with AI', style: TextStyle(fontSize: 12, color: Colors.white54)),
              ],
            ),
          ],
        ),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _neonPurple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _neonPurple.withOpacity(0.5)),
              ),
              child: Text('Beta', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _neonPurple)),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            // TOP: Execution Log
            _buildNeonCard(
              title: 'Execution Log',
              subtitle: 'Real-time status updates for categorization process',
              icon: Icons.info_outline,
              headerColor: _cardColor, // Dark header
              child: Container(
                constraints: const BoxConstraints(minHeight: 300),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _inputColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _borderColor),
                ),
                child: _results.isEmpty
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline, size: 32, color: Colors.white24),
                          SizedBox(height: 12),
                          Text('No logs yet. Start categorization to see results.', style: TextStyle(color: Colors.white38)),
                        ],
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        itemCount: _results.length,
                        separatorBuilder: (context, index) => Divider(height: 1, color: _borderColor),
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          return ListTile(
                            leading: _buildStatusIcon(item.state),
                            title: Text(
                                item.text,
                                style: TextStyle(
                                  color: item.state == 'error' ? _neonPink : Colors.white70,
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

            const SizedBox(height: 24),

            // BOTTOM ROW: Target URLs & API Config
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT CARD: Target URLs
                Expanded(
                  child: _buildNeonCard(
                    title: 'Target URLs',
                    subtitle: 'Enter URLs to categorize',
                    icon: Icons.link,
                    headerGradient: LinearGradient(colors: [_neonPurple, _neonPink]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(label: '', controller: _linksCtrl, maxLines: 6),
                        const SizedBox(height: 12),
                        Text('$_urlCount URLs entered', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [_neonPurple, _neonPink]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing ? null : _processLinks,
                            icon: _isProcessing
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.play_circle_outline, size: 20),
                            label: Text(_isProcessing ? 'Processing...' : 'Start Categorization', style: const TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(width: 24),
                
                // RIGHT CARD: API Config
                Expanded(
                  child: _buildNeonCard(
                    title: 'API Configuration',
                    subtitle: 'Configure your API credentials',
                    icon: Icons.settings_outlined,
                    headerColor: _neonPurple,
                    child: Column(
                      children: [
                        _buildTextField(label: 'Gemini API Key', controller: _geminiKeyCtrl, isPassword: true),
                        const SizedBox(height: 16),
                        _buildTextField(label: 'Notion Token', controller: _notionTokenCtrl, isPassword: true),
                        const SizedBox(height: 16),
                        _buildTextField(label: 'Notion Database ID', controller: _dbIdCtrl, isPassword: true),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _saveKeys,
                            icon: const Icon(Icons.save_outlined, size: 18),
                            label: const Text('Save Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _neonPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 20),
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
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(String state) {
    switch (state) {
      case 'loading':
        return SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _neonPurple));
      case 'success':
        return const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20);
      case 'error':
        return Icon(Icons.error_outline, color: _neonPink, size: 20);
      default:
        return const Icon(Icons.info_outline, size: 20, color: Colors.white54);
    }
  }
}