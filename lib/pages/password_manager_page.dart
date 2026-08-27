import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import '../models/password_model.dart';
import '../services/password_storage.dart';
import '../utils/toast_util.dart';
import 'add_password_page.dart';

class PasswordManagerPage extends StatefulWidget {
  const PasswordManagerPage({super.key});

  @override
  PasswordManagerPageState createState() => PasswordManagerPageState();
}

class PasswordManagerPageState extends State<PasswordManagerPage> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  List<PasswordEntry> _passwords = [];
  bool _isLoading = true;
  bool _isAuthenticated = false;
  final Set<int> _expandedIndices = {};

  @override
  void initState() {
    super.initState();
    _authenticateAndLoad();
  }

  Future<void> _authenticateAndLoad() async {
    final authenticated = await _authenticate();
    if (mounted) {
      if (authenticated) {
        setState(() {
          _isAuthenticated = true;
        });
        await _loadPasswords();
      } else {
        Navigator.pop(context);
        showToast(context, '认证失败或已取消');
      }
    }
  }

  Future<bool> _authenticate() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      
      final hasBiometrics = availableBiometrics.isNotEmpty;
      final hasDeviceCredentials = await _localAuth.isDeviceSupported();
      
      if (!hasBiometrics && !hasDeviceCredentials) {
        print('设备未设置生物识别或锁屏密码，跳过认证');
        return true;
      }

      if (!canCheckBiometrics && !isDeviceSupported) {
        return true;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: '请验证身份以访问密码管理',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      
      if (!authenticated) {
        return false;
      }
      
      return true;
    } on PlatformException catch (e) {
      print('认证错误: $e');
      if (e.code == 'no_fragment_activity') {
        print('Activity不是FragmentActivity，跳过认证');
        return true;
      }
      return false;
    }
  }

  Future<void> _loadPasswords() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final passwords = await PasswordStorage.loadPasswords();
      if (mounted) {
        setState(() {
          _passwords = passwords;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        showToast(context, '加载失败: $e');
      }
    }
  }

  Future<void> _navigateToAddPassword({PasswordEntry? entry}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPasswordPage(entry: entry),
      ),
    );
    
    if (result == true && mounted) {
      await _loadPasswords();
    }
  }

  Future<void> _deletePassword(int index, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认删除'),
        content: Text('确定要删除这条密码记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirm == true && mounted) {
      await PasswordStorage.deletePassword(id);
      setState(() {
        _passwords.removeAt(index);
        _expandedIndices.remove(index);
      });
      showToast(context, '删除成功');
    }
  }

  void _toggleExpand(int index) {
    setState(() {
      if (_expandedIndices.contains(index)) {
        _expandedIndices.remove(index);
      } else {
        _expandedIndices.clear();
        _expandedIndices.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return Scaffold(
        backgroundColor: Color(0xFFF5F6FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text('密码管理'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _passwords.isEmpty
              ? _buildEmptyState()
              : _buildPasswordList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddPassword(),
        backgroundColor: Color(0xFF4A7CF7),
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Color(0xFF4A7CF7).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_outline,
              size: 48,
              color: Color(0xFF4A7CF7),
            ),
          ),
          SizedBox(height: 16),
          Text(
            '暂无密码记录',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '点击右下角添加第一条记录',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF9A9AB0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordList() {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _passwords.length,
      itemBuilder: (context, index) {
        final entry = _passwords[index];
        final isExpanded = _expandedIndices.contains(index);
        return _buildDismissibleCard(entry, index, isExpanded);
      },
    );
  }

  Widget _buildDismissibleCard(PasswordEntry entry, int index, bool isExpanded) {
    final avatarColor = _getAvatarColor(entry.name);
    
    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 24),
        child: Icon(
          Icons.delete_outline,
          color: Colors.red,
          size: 28,
        ),
      ),
      confirmDismiss: (direction) async {
        await _deletePassword(index, entry.id);
        return false;
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isExpanded ? 0.08 : 0.04),
              blurRadius: isExpanded ? 16 : 8,
              offset: Offset(0, isExpanded ? 4 : 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _toggleExpand(index),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: avatarColor,
                        child: Text(
                          entry.avatarText,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          entry.name,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: Duration(milliseconds: 300),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: Color(0xFF9A9AB0),
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedCrossFade(
                  firstChild: SizedBox.shrink(),
                  secondChild: _buildDetailSection(entry),
                  crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: Duration(milliseconds: 300),
                  sizeCurve: Curves.easeInOut,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(PasswordEntry entry) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Color(0xFFF9FAFC),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(
          top: BorderSide(
            color: Color(0xFFE8EAF0),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 12),
          _buildDetailRow('账号', entry.account, Icons.person_outline),
          SizedBox(height: 12),
          _buildDetailRow('密码', entry.password, Icons.lock_outline, isPassword: true),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _navigateToAddPassword(entry: entry),
                icon: Icon(Icons.edit_outlined, size: 18, color: Color(0xFF4A7CF7)),
                label: Text(
                  '编辑',
                  style: TextStyle(
                    color: Color(0xFF4A7CF7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, {bool isPassword = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Color(0xFF9A9AB0)),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9A9AB0),
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 15,
                        fontFamily: isPassword ? 'monospace' : null,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy, size: 18, color: Color(0xFF4A7CF7)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value));
                      showToast(context, '${label}已复制');
                    },
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    splashRadius: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      Color(0xFF4A7CF7),
      Color(0xFFFF9F43),
      Color(0xFF2ED573),
      Color(0xFFEE5A6F),
      Color(0xFF9C88FF),
      Color(0xFF00D2D3),
      Color(0xFFFF6B9D),
      Color(0xFF54A0FF),
    ];
    final index = name.hashCode.abs() % colors.length;
    return colors[index];
  }
}