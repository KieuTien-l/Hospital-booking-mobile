import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/state/view_state.dart';
import '../../domain/entities/specialty.dart';
import '../controllers/specialty_controller.dart';

/// FE-28: Patient-facing specialty directory.
/// [onSelected] connects to the doctor list when that screen is available.
class SpecialtyListPage extends StatefulWidget {
  const SpecialtyListPage({super.key, this.onSelected});

  final ValueChanged<Specialty>? onSelected;

  @override
  State<SpecialtyListPage> createState() => _SpecialtyListPageState();
}

class _SpecialtyListPageState extends State<SpecialtyListPage> {
  static const _blue = Color(0xFF0753AB);
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SpecialtyController>().loadSpecialties();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SpecialtyController>();
    final query = _query.trim().toLowerCase();
    final items = controller.specialties
        .where((item) => item.isActive && item.name.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _blue,
        elevation: 0,
        title: const Text('Danh sách chuyên khoa',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Khám đúng chuyên khoa',
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700,
                          color: Color(0xFF163958))),
                  const SizedBox(height: 5),
                  const Text('Tìm chuyên khoa phù hợp với nhu cầu thăm khám của bạn.',
                      style: TextStyle(color: Color(0xFF61788B))),
                  const SizedBox(height: 18),
                  TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm chuyên khoa...',
                      prefixIcon: const Icon(Icons.search, color: _blue),
                      filled: true,
                      fillColor: const Color(0xFFF3F8FC),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Builder(builder: (context) {
                if (controller.status == ViewState.loading ||
                    controller.status == ViewState.initial) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (controller.status == ViewState.error) {
                  return _StatusMessage(
                    icon: Icons.wifi_off_rounded,
                    title: 'Không tải được chuyên khoa',
                    message: controller.errorMessage ?? 'Vui lòng thử lại sau.',
                    action: () => controller.loadSpecialties(),
                  );
                }
                if (items.isEmpty) {
                  return _StatusMessage(
                    icon: Icons.search_off_rounded,
                    title: query.isEmpty ? 'Chưa có chuyên khoa' : 'Không tìm thấy kết quả',
                    message: query.isEmpty
                        ? 'Danh sách chuyên khoa hiện chưa có dữ liệu.'
                        : 'Hãy thử tìm kiếm bằng tên khác.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: controller.loadSpecialties,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: items.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('${items.length} chuyên khoa',
                              style: const TextStyle(fontWeight: FontWeight.w700,
                                  color: Color(0xFF163958), fontSize: 16)),
                        );
                      }
                      final specialty = items[index - 1];
                      return _SpecialtyCard(
                        specialty: specialty,
                        onTap: () {
                          if (widget.onSelected != null) {
                            widget.onSelected!(specialty);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text(
                                  'Danh sách bác sĩ sẽ được kết nối ở bước tiếp theo.')),
                            );
                          }
                        },
                      );
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpecialtyCard extends StatelessWidget {
  const _SpecialtyCard({required this.specialty, required this.onTap});

  final Specialty specialty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = specialty.imageUrl?.trim();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE3EDF6)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: imageUrl == null || imageUrl.isEmpty
                      ? const _ImageFallback()
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const _ImageFallback(),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(specialty.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF163958))),
                    const SizedBox(height: 6),
                    Text(
                      specialty.description.isEmpty
                          ? 'Tìm hiểu và lựa chọn bác sĩ phù hợp'
                          : specialty.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFF61788B), fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF0753AB)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFFEAF4FF),
        child: Center(child: Icon(Icons.medical_services_outlined,
            color: Color(0xFF0753AB), size: 32)),
      );
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 54, color: const Color(0xFF87B8E8)),
              const SizedBox(height: 14),
              Text(title, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              if (action != null) ...[
                const SizedBox(height: 16),
                FilledButton(onPressed: action, child: const Text('Thử lại')),
              ],
            ],
          ),
        ),
      );
}
