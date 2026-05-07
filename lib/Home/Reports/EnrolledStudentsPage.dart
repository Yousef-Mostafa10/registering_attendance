import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Auth/api_service.dart';
import '../../Auth/colors.dart';

/// صفحة عرض الطلاب المسجلين في الكورس
/// GET /Course/get-enrolled-students/{courseId}?search=
/// مع Debounce 300ms على حقل البحث
class EnrolledStudentsPage extends StatefulWidget {
  final String courseId;
  const EnrolledStudentsPage({Key? key, required this.courseId}) : super(key: key);

  @override
  State<EnrolledStudentsPage> createState() => _EnrolledStudentsPageState();
}

class _EnrolledStudentsPageState extends State<EnrolledStudentsPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _isLoading = false;
  String _errorMessage = '';
  List<dynamic> _students = [];
  String _lastSearch = '';

  @override
  void initState() {
    super.initState();
    _fetch();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (_searchCtrl.text != _lastSearch) {
        _lastSearch = _searchCtrl.text;
        _fetch(search: _lastSearch);
      }
    });
  }

  Future<void> _fetch({String? search}) async {
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      if (token.isEmpty) throw Exception('Not authenticated');

      // URL الصحيح: GET /Course/get-enrolled-students/{courseId}?search=
      final res = await ApiService.getEnrolledStudents(
        courseId: widget.courseId,
        token: token,
        search: search?.isNotEmpty == true ? search : null,
      );

      if (res['statusCode'] == 200) {
        final data = jsonDecode(res['body']);
        List<dynamic> list = [];
        if (data is List) list = data;
        else if (data is Map && data.containsKey(r'$values')) list = data[r'$values'] ?? [];

        if (mounted) setState(() => _students = list);
      } else {
        setState(() => _errorMessage = 'Error ${res['statusCode']}: ${res['body']}');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color accent = Color(0xFF0277BD);

    return Scaffold(
      backgroundColor: AppColors.lightColor2,
      appBar: AppBar(
        title: const Text('Enrolled Students'),
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetch(search: _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                const SizedBox(width: 12),
                const Icon(Icons.search, color: Colors.white70),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Search by name or university code...',
                      hintStyle: TextStyle(color: Colors.white60),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (_searchCtrl.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white70),
                    onPressed: () => _searchCtrl.clear(),
                  ),
              ]),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
        children: [
          if (!_isLoading && _errorMessage.isEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                const Icon(Icons.group, size: 18, color: accent),
                const SizedBox(width: 8),
                Text('${_students.length} student(s) enrolled',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: accent)),
              ]),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: accent))
                : _errorMessage.isNotEmpty
                    ? _buildError()
                    : _students.isEmpty
                        ? _buildEmpty()
                        : LayoutBuilder(builder: (context, constraints) {
                            final w = constraints.maxWidth;
                            final cols = w >= 900 ? 3 : w >= 600 ? 2 : 1;
                            if (cols > 1) {
                              return GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cols,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: cols == 3 ? 1.8 : 2.2,
                                ),
                                itemCount: _students.length,
                                itemBuilder: (_, i) => _studentCard(_students[i], i + 1),
                              );
                            }
                            return ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _students.length,
                              itemBuilder: (_, i) => _studentCard(_students[i], i + 1),
                            );
                          }),
          ),
        ],
      ),
        ),
      ),
    );
  }

  Widget _studentCard(Map<String, dynamic> student, int rank) {
    final String name = student['studentName'] ?? student['name'] ?? 'Unknown';
    final String code = student['universityCode'] ?? student['code'] ?? '—';
    final String email = student['email'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF0277BD).withOpacity(0.1),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(color: Color(0xFF0277BD), fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Code: $code', style: TextStyle(color: AppColors.darkColor.withOpacity(0.5), fontSize: 12)),
          if (email.isNotEmpty)
            Text(email, style: TextStyle(color: AppColors.darkColor.withOpacity(0.4), fontSize: 11)),
        ]),
        trailing: Text(
          '#$rank',
          style: TextStyle(color: AppColors.darkColor.withOpacity(0.4), fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildError() => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.error_outline, size: 64, color: AppColors.errorColor),
    const SizedBox(height: 16),
    Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.errorColor)),
    const SizedBox(height: 16),
    ElevatedButton(onPressed: _fetch, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0277BD)), child: const Text('Retry')),
  ])));

  Widget _buildEmpty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.people_outline, size: 72, color: AppColors.darkColor.withOpacity(0.2)),
    const SizedBox(height: 16),
    Text(
      _searchCtrl.text.isEmpty ? 'No students enrolled yet' : 'No students match your search',
      style: TextStyle(fontSize: 16, color: AppColors.darkColor.withOpacity(0.5)),
      textAlign: TextAlign.center,
    ),
  ]));
}
