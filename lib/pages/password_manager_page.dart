import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import '../models/password_model.dart';
import '../services/password_storage.dart';
import '../utils/toast_util.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/circle_action_button.dart';

class PasswordManagerPage extends StatefulWidget {
  const PasswordManagerPage({super.key, this.autoAuthenticate = true});

  /// 是否在初始化时自动请求认证。
  /// 作为底部 Tab 使用时传 false，由外部在切换到该页时调用 unlock() 触发。
  final bool autoAuthenticate;

  @override
  PasswordManagerPageState createState() => PasswordManagerPageState();
}

class PasswordManagerPageState extends State<PasswordManagerPage> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  List<PasswordEntry> _passwords = [];
  List<PasswordEntry> _filteredPasswords = [];
  bool _isLoading = true;
  bool _isAuthenticated = false;
  bool _authenticating = false;
  final Set<int> _expandedIndices = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.autoAuthenticate) {
      _authenticateAndLoad();
    }
    _searchController.addListener(_onSearchChanged);
  }

  /// 供外部（底部 Tab 切换）调用，未认证时触发身份验证
  void unlock() {
    if (_isAuthenticated || _authenticating) return;
    _authenticateAndLoad();
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
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
    });

    final authenticated = await _authenticate();
    if (!mounted) return;

    if (authenticated) {
      setState(() {
        _isAuthenticated = true;
        _authenticating = false;
      });
      await _loadPasswords();
    } else {
      // 作为底部 Tab 使用时不退出页面，停留在锁定状态等待重新解锁
      setState(() {
        _authenticating = false;
      });
      showToast(context, '认证失败或已取消');
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

  Future<void> _showAddEditDialog({
    PasswordEntry? entry,
    bool isCopy = false,
  }) async {
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
          title: Text(
            isCopy ? '复制信息' : (isEditing ? '编辑密码' : '添加密码'),
          ),
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
                          color: Color(0xFF999999),
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
                backgroundColor: Color(0xFF333333),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('保存'),
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
            color: Color(0xFF333333),
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
              color: Color(0xFF999999),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Color(0xFFF5F5F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Color(0xFF333333), width: 1.5),
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

  // 复制账号信息到剪贴板（每条信息一行）
  Future<void> _copyAccountInfo(PasswordEntry entry) async {
    final text = '名称：${entry.name}\n账号：${entry.account}\n密码：${entry.password}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showToast(context, '账号信息已复制');
  }

  // 右滑第二段：复制卡片（生成新卡片后立即打开编辑弹框）
  Future<void> _duplicateCard(PasswordEntry entry) async {
    final newEntry = PasswordEntry(
      name: entry.name,
      account: entry.account,
      password: entry.password,
    );
    await PasswordStorage.addPassword(newEntry);
    if (!mounted) return;
    // 先刷新列表，让复制出的卡片出现在页面上
    await _loadPasswords();
    if (!mounted) return;
    // 复制完立刻进入编辑，方便直接修改副本信息
    await _showAddEditDialog(entry: newEntry, isCopy: true);
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
        backgroundColor: Color(0xFFF5F5F5),
        body: SafeArea(
          child: Column(
            children: [
              AppTopBar(),
              Expanded(
                child: Center(
                  child: _authenticating
                      ? CircularProgressIndicator()
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Color(0xFF333333).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.lock_outline,
                                size: 36,
                                color: Color(0xFF333333),
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              '密码管理已锁定',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333333),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '验证身份后查看已保存的密码',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF999999),
                              ),
                            ),
                            SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _authenticateAndLoad,
                              icon: Icon(Icons.fingerprint, size: 18),
                              label: Text('解锁'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF333333),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(),
            // 固定区域：页面标题 + 搜索框，滚动时保持不动
            Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  SizedBox(height: 16),
                  _buildSearchBar(),
                  // 搜索框与下方列表之间留出间距
                  SizedBox(height: 12),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _filteredPasswords.isEmpty
                      ? _buildEmptyState()
                      : _buildPasswordList(),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        // 上移避开底部导航栏
        padding: EdgeInsets.only(bottom: 78),
        // 与首页打卡按钮保持同样的圆形渐变样式
        child: CircleActionButton(
          onTap: () => _showAddEditDialog(),
          icon: Icons.add,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '密码管理',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              SizedBox(height: 4),
//               Text(
//                 '安全存储账号密码，支持指纹/密码解锁',
//                 style: TextStyle(
//                   fontSize: 12,
//                   color: Color(0xFF999999),
//                 ),
//               ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
//       padding: EdgeInsets.fromLTRB(0, 6, 0, 0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索名称',
          hintStyle: TextStyle(
            fontSize: 14,
            color: Color(0xFF999999),
          ),
          prefixIcon: Icon(Icons.search, color: Color(0xFF999999), size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Color(0xFF999999), size: 22),
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
            borderSide: BorderSide(color: Color(0xFF333333), width: 1.5),
          ),
        ),
        style: TextStyle(
          fontSize: 15,
          color: Color(0xFF333333),
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
              color: Color(0xFF333333).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_outline,
              size: 48,
              color: Color(0xFF333333),
            ),
          ),
          SizedBox(height: 16),
          Text(
            '暂无密码记录',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '点击右下角添加第一条记录',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF999999),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordList() {
    return ListView.builder(
      // 列表自身可滚动，标题和搜索框固定在上方
      padding: EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: _filteredPasswords.length,
      itemBuilder: (context, index) {
        final entry = _filteredPasswords[index];
        final isExpanded = _expandedIndices.contains(index);
        return _buildSwipeCard(entry, index, isExpanded);
      },
    );
  }

  Widget _buildSwipeCard(PasswordEntry entry, int index, bool isExpanded) {
    final avatarColor = _getAvatarColor(entry.name);
    
    // 右滑分段：第一段为编辑，继续右滑为复制卡片；按住过程中左滑为取消
    return _SwipeCard(
      key: ValueKey(entry.id),
      onEdit: () {
        _showAddEditDialog(entry: entry);
      },
      onCopyCard: () {
        _duplicateCard(entry);
      },
      onDelete: () {
        _deletePassword(entry.id);
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFFE1E1E1)),
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
                                color: Color(0xFF333333),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              entry.account,
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF999999),
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
                          color: Color(0xFF999999),
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
        color: Color(0xFFFAFAFA),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(
          top: BorderSide(
            color: Color(0xFFE1E1E1),
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
              // 主操作：复制账号信息（深色实心）
              TextButton.icon(
                onPressed: () => _copyAccountInfo(entry),
                icon: Icon(Icons.copy_all_outlined, size: 18, color: Colors.white),
                label: Text(
                  '复制账号信息',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Color(0xFF333333),
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              SizedBox(width: 8),
              // 次操作：编辑（白底细边框）
              TextButton.icon(
                onPressed: () => _showAddEditDialog(entry: entry),
                icon: Icon(Icons.edit_outlined, size: 18, color: Color(0xFF333333)),
                label: Text(
                  '编辑',
                  style: TextStyle(
                    color: Color(0xFF333333),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Color(0xFFE1E1E1)),
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
        Icon(icon, size: 18, color: Color(0xFF999999)),
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
                  color: Color(0xFF999999),
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontFamily: isPassword ? 'monospace' : null,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getAvatarColor(String name) {
    // 卡片整体保持黑白，仅头像色块保留彩色，作为列表中的识别点
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

enum _SwipeDirection { none, right, left }

/// 支持分段右滑的卡片。
/// 右滑第一段松手为编辑，继续右滑到第二段松手为复制卡片；
/// 右滑过程中向左回拉则取消；直接左滑为删除。
class _SwipeCard extends StatefulWidget {
  const _SwipeCard({
    super.key,
    required this.child,
    required this.onEdit,
    required this.onCopyCard,
    required this.onDelete,
  });

  final Widget child;
  final VoidCallback onEdit;
  final VoidCallback onCopyCard;
  final VoidCallback onDelete;

  @override
  State<_SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<_SwipeCard> {
  // 第一段：编辑（占卡片一半）；第二段：复制卡片（一半之后）
  // 最大拖动距离等于卡片宽度，即可以完全拉出卡片
  static const double _editRatio = 0.5;
  static const double _copyRatio = 0.78;
  static const double _deleteThreshold = 112;

  // 卡片实际宽度，由 LayoutBuilder 测量后写入
  double _cardWidth = 0;

  double get _editThreshold => _cardWidth * _editRatio;
  double get _copyThreshold => _cardWidth * _copyRatio;
  double get _maxDrag => _cardWidth;

  double _offset = 0;
  bool _dragging = false;
  _SwipeDirection _direction = _SwipeDirection.none;

  // 当前所处震动阶段：0 无 / 1 编辑段 / 2 复制段 / 3 删除段
  // 用于保证跨入某个区间的瞬间只震动一次，避免拖动过程中每帧重复触发
  int _hapticStage = 0;

  void _handleDragStart(DragStartDetails details) {
    _hapticStage = 0;
    setState(() {
      _dragging = true;
      _direction = _SwipeDirection.none;
      _offset = 0;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final delta = details.delta.dx;
    if (delta == 0) return;

    final nextDirection = _direction == _SwipeDirection.none
        ? (delta > 0 ? _SwipeDirection.right : _SwipeDirection.left)
        : _direction;
    final nextOffset = nextDirection == _SwipeDirection.right
        // 右滑过程中向左回拉即为取消，offset 不会变成负数
        ? (_offset + delta).clamp(0.0, _maxDrag)
        : (_offset + delta).clamp(-_maxDrag, 0.0);

    _updateHaptic(nextDirection, nextOffset);

    setState(() {
      _direction = nextDirection;
      _offset = nextOffset;
    });
  }

  // 跨入新区间时给一次轻反馈
  void _updateHaptic(_SwipeDirection direction, double offset) {
    int stage = 0;
    if (direction == _SwipeDirection.right) {
      if (offset >= _copyThreshold) {
        stage = 2;
      } else if (offset >= _editThreshold) {
        stage = 1;
      }
    } else if (direction == _SwipeDirection.left &&
        offset <= -_deleteThreshold) {
      stage = 3;
    }
    if (stage == _hapticStage) return;
    _hapticStage = stage;
    if (stage > 0) {
      HapticFeedback.selectionClick();
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    final offset = _offset;
    final direction = _direction;
    _reset();
    if (offset == 0) return;
    if (direction == _SwipeDirection.right) {
      if (offset >= _copyThreshold) {
        HapticFeedback.mediumImpact();
        widget.onCopyCard();
      } else if (offset >= _editThreshold) {
        HapticFeedback.mediumImpact();
        widget.onEdit();
      }
    } else if (direction == _SwipeDirection.left &&
        offset <= -_deleteThreshold) {
      HapticFeedback.mediumImpact();
      widget.onDelete();
    }
  }

  void _handleDragCancel() {
    _hapticStage = 0;
    _reset();
  }

  void _reset() {
    if (!mounted) return;
    setState(() {
      _dragging = false;
      _offset = 0;
      _direction = _SwipeDirection.none;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 记录卡片实际宽度，手势阈值按该宽度计算
          _cardWidth = constraints.maxWidth;
          return Stack(
            fit: StackFit.passthrough,
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: _buildBackground()),
              AnimatedContainer(
                duration:
                    _dragging ? Duration.zero : Duration(milliseconds: 180),
                curve: Curves.easeOut,
                transform: Matrix4.translationValues(_offset, 0, 0),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: _handleDragStart,
                  onHorizontalDragUpdate: _handleDragUpdate,
                  onHorizontalDragEnd: _handleDragEnd,
                  onHorizontalDragCancel: _handleDragCancel,
                  child: widget.child,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBackground() {
    if (_direction == _SwipeDirection.left) {
      return _buildSwipeBackground(
        icon: Icons.delete_outline,
        color: Colors.red,
        label: '删除',
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 24),
      );
    }
    if (_offset >= _copyThreshold) {
      return _buildSwipeBackground(
        icon: Icons.copy_all_outlined,
        color: Color(0xFF333333),
        label: '复制卡片',
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.only(left: 24),
      );
    }
    if (_offset > 0) {
      return _buildSwipeBackground(
        icon: Icons.edit_outlined,
        color: Color(0xFF333333),
        label: '编辑',
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.only(left: 24),
      );
    }
    return SizedBox.shrink();
  }
}

Widget _buildSwipeBackground({
  required IconData icon,
  required Color color,
  required String label,
  required Alignment alignment,
  required EdgeInsets padding,
}) {
  return Container(
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