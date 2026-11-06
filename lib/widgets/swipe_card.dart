import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _SwipeDirection { none, right, left }

/// 支持分段右滑的卡片。
/// 右滑第一段松手为编辑；若传入 onCopyCard，继续右滑到第二段松手为「复制卡片」；
/// 右滑过程中向左回拉则取消；直接左滑松手为删除。
///
/// - 快递页：不传 onCopyCard，右滑只触发编辑
/// - 密码页：传 onCopyCard，右滑第一段编辑、第二段复制卡片
class SwipeCard extends StatefulWidget {
  const SwipeCard({
    super.key,
    required this.child,
    required this.onEdit,
    required this.onDelete,
    this.onCopyCard,
  });

  final Widget child;

  /// 右滑第一段松手：编辑
  final VoidCallback onEdit;

  /// 左滑超过删除阈值松手：删除
  final VoidCallback onDelete;

  /// 右滑第二段松手：复制卡片。
  /// 为 null 时右滑只有一段（编辑）。
  final VoidCallback? onCopyCard;

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard> {
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
      if (widget.onCopyCard != null && offset >= _copyThreshold) {
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
      if (widget.onCopyCard != null && offset >= _copyThreshold) {
        HapticFeedback.mediumImpact();
        widget.onCopyCard!();
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
    if (widget.onCopyCard != null && _offset >= _copyThreshold) {
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
