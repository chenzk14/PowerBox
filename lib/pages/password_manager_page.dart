import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import '../models/password_model.dart';
import '../services/password_storage.dart';
import '../utils/toast_util.dart';

class PasswordManagerPage extends StatefulWidget {
  const PasswordManagerPage({super.key});

  @override
  PasswordManagerPageState createState() => PasswordManagerPageState();
}

class PasswordManagerPageState extends State<PasswordManagerPage> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  List<PasswordEntry> _passwords = [];
  List<PasswordEntry> _filteredPasswords = [];
  bool _isLoading = true;
  bool _isAuthenticated = false;
  final Set<int> _expandedIndices = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _authenticateAndLoad();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
      _filterPasswords();
    });
  }

  void _filterPasswords() {
    if (_searchQuery.isEmpty) {
      _filteredPasswords = List.from(_passwords);
    } else {
      _filteredPasswords = _passwords.where((entry) {
        return entry.name.toLowerCase().contains(_searchQuery);
      }).toList();
    }
    // 重置展开状态，因为索引变了
    _expandedIndices.clear();
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
      // 按创建时间倒序排列，最新添加的在最前面
      passwords.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) {
        setState(() {
          _passwords = passwords;
          _filterPasswords();
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

  Future<void> _showAddEditDialog({PasswordEntry? entry}) async {
    final isEditing = entry != null;
    final nameController = TextEditingController(text: entry?.name ?? '');
    final accountController = TextEditingController(text: entry?.account ?? '');
    final passwordController = TextEditingController(text: entry?.password ?? '');
    bool obscurePassword = true;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? '编辑密码' : '添加密码'),
          content: SizedBox(
            width: double.maxFinite,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDialogInputField(
                      controller: nameController,
                      label: '名称',
                      hintText: '如：微信、支付宝、GitHub',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入名称';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    _buildDialogInputField(
                      controller: accountController,
                      label: '账号',
                      hintText: '用户名/邮箱/手机号',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入账号';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    _buildDialogInputField(
                      controller: passwordController,
                      label: '密码',
                      hintText: '请输入密码',
                      obscureText: obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Color(0xFF9A9AB0),
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入密码';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                
                try {
                  final newEntry = PasswordEntry(
                    id: entry?.id,
                    name: nameController.text.trim(),
                    account: accountController.text.trim(),
                    password: passwordController.text.trim(),
                    createdAt: entry?.createdAt,
                  );

                  if (entry == null) {
                    await PasswordStorage.addPassword(newEntry);
                  } else {
                    await PasswordStorage.updatePassword(newEntry);
                  }

                  if (mounted) {
                    Navigator.pop(dialogContext);
                    showToast(context, entry == null ? '添加成功' : '更新成功');
                    await _loadPasswords();
                  }
                } catch (e) {
                  if (mounted) {
                    showToast(context, '保存失败: $e');
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF4A7CF7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(isEditing ? '保存修改' : '保存密码'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogInputField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              fontSize: 14,
              color: Color(0xFF9A9AB0),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Color(0xFFF5F6FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Color(0xFF4A7CF7), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.red, width: 1.5),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Future<void> _deletePassword(String id) async {
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
        // 在原始列表中查找并删除
        final originalIndex = _passwords.indexWhere((e) => e.id == id);
        if (originalIndex != -1) {
          _passwords.removeAt(originalIndex);
        }
        _filterPasswords(); // 重新过滤
        _expandedIndices.clear();
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
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    SizedBox(height: 16),
                    _buildSearchBar(),
                    SizedBox(height: 16),
                    _filteredPasswords.isEmpty
                        ? _buildEmptyState()
                        : _buildPasswordList(),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: Color(0xFF4A7CF7),
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '密码管理',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            SizedBox(height: 4),
            Text(
              '安全存储账号密码，支持指纹/密码解锁',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF9A9AB0),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(0, 16, 0, 0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索名称',
          hintStyle: TextStyle(
            fontSize: 14,
            color: Color(0xFF9A9AB0),
          ),
          prefixIcon: Icon(Icons.search, color: Color(0xFF9A9AB0), size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Color(0xFF9A9AB0), size: 22),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Color(0xFF4A7CF7), width: 1.5),
          ),
        ),
        style: TextStyle(
          fontSize: 15,
          color: Color(0xFF1A1A2E),
        ),
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
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(0, 8, 0, 100),
      itemCount: _filteredPasswords.length,
      itemBuilder: (context, index) {
        final entry = _filteredPasswords[index];
        final isExpanded = _expandedIndices.contains(index);
        return _buildDismissibleCard(entry, index, isExpanded);
      },
    );
  }

  Widget _buildDismissibleCard(PasswordEntry entry, int index, bool isExpanded) {
    final avatarColor = _getAvatarColor(entry.name);
    
    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.horizontal,
      background: _buildSwipeBackground(
        icon: Icons.copy_all_outlined,
        color: Color(0xFF4A7CF7),
        label: '复制卡片',
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.only(left: 24),
      ),
      secondaryBackground: _buildSwipeBackground(
        icon: Icons.delete_outline,
        color: Colors.red,
        label: '删除',
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 24),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // 右滑复制卡片（生成新卡片可编辑）
          final newEntry = PasswordEntry(
            name: entry.name,
            account: entry.account,
            password: entry.password,
          );
          await PasswordStorage.addPassword(newEntry);
          showToast(context, '已复制卡片，可编辑修改');
          await _loadPasswords();
          return false; // 不关闭
        } else if (direction == DismissDirection.endToStart) {
          // 左滑删除
          await _deletePassword(entry.id);
          return false;
        }
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.name,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              entry.account,
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF9A9AB0),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
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

  Widget _buildSwipeBackground({
    required IconData icon,
    required Color color,
    required String label,
    required Alignment alignment,
    required EdgeInsets padding,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: alignment,
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
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
                onPressed: () => _showAddEditDialog(entry: entry),
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