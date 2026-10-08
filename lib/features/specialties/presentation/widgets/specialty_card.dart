import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../domain/entities/specialty.dart';

class SpecialtyCard extends StatefulWidget {
  const SpecialtyCard({
    super.key,
    required this.specialty,
    required this.onTap,
    this.selected = false,
  });

  final Specialty specialty;
  final VoidCallback onTap;
  final bool selected;

  @override
  State<SpecialtyCard> createState() => _SpecialtyCardState();
}

class _SpecialtyCardState extends State<SpecialtyCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium!
        .copyWith(color: AppColors.textSecondary, height: 1.6);
    return Semantics(
      selected: widget.selected,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: widget.selected ? AppColors.primaryDark : AppColors.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.specialty.name.toUpperCase(),
                        style: Theme.of(context).textTheme.titleMedium!
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (widget.specialty.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final painter = TextPainter(
                              text: TextSpan(
                                text: widget.specialty.description,
                                style: style,
                              ),
                              maxLines: 2,
                              textDirection: Directionality.of(context),
                              textScaler: MediaQuery.textScalerOf(context),
                            )..layout(maxWidth: constraints.maxWidth);
                            final overflows = painter.didExceedMaxLines;
                            painter.dispose();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.specialty.description,
                                  style: style,
                                  maxLines: _expanded ? null : 2,
                                  overflow: _expanded
                                      ? TextOverflow.visible
                                      : TextOverflow.ellipsis,
                                ),
                                if (overflows)
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.textOnPrimary,
                                      padding: EdgeInsets.zero,
                                      alignment: Alignment.centerLeft,
                                    ),
                                    onPressed: () =>
                                        setState(() => _expanded = !_expanded),
                                    child: Text(
                                      _expanded ? 'Thu gọn' : 'Xem thêm',
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
