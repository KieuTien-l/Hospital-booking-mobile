import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/patient.dart';
import '../controllers/patient_profile_controller.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _idCardController;
  
  DateTime? _dateOfBirth;
  String? _gender;

  @override
  void initState() {
    super.initState();
    final patient = context.read<PatientProfileController?>()?.patient;
    final user = context.read<AuthController>().currentUser;

    _nameController = TextEditingController(text: patient?.fullName ?? user?.fullName ?? '');
    _phoneController = TextEditingController(text: patient?.phone ?? user?.phone ?? '');
    _emailController = TextEditingController(text: patient?.email ?? user?.email ?? '');
    _addressController = TextEditingController(text: patient?.address ?? '');
    _idCardController = TextEditingController(text: patient?.nationalId ?? '');
    
    _dateOfBirth = patient?.dateOfBirth;
    _gender = patient?.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _idCardController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    final controller = context.read<PatientProfileController>();
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    
    final currentPatient = controller.patient;
    
    final updatedPatient = Patient(
      id: currentPatient?.id ?? '',
      authUserId: user.id,
      fullName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
      nationalId: _idCardController.text.trim(),
      dateOfBirth: _dateOfBirth,
      gender: _gender,
      avatarUrl: currentPatient?.avatarUrl,
      insuranceNumber: currentPatient?.insuranceNumber,
      ethnicity: currentPatient?.ethnicity,
      occupation: currentPatient?.occupation,
      ward: currentPatient?.ward,
      district: currentPatient?.district,
      province: currentPatient?.province,
      country: currentPatient?.country,
      relationshipToAccountHolder:
          currentPatient?.relationshipToAccountHolder,
      isActive: currentPatient?.isActive ?? true,
      status: currentPatient?.status ?? 'ACTIVE',
    );

    final error = controller.validateProfile(updatedPatient);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final saved = await controller.updatePatient(updatedPatient);
    if (saved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật hồ sơ thành công!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Thông tin cá nhân'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Consumer<PatientProfileController>(
        builder: (context, controller, child) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildTextField(
                  controller: _nameController,
                  label: 'Họ và tên',
                  icon: Icons.person,
                  validator: (value) => value == null || value.trim().isEmpty ? 'Bắt buộc nhập' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _phoneController,
                  label: 'Số điện thoại',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (value) => value == null || value.trim().isEmpty ? 'Bắt buộc nhập' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildDateField(),
                const SizedBox(height: 16),
                _buildDropdown(
                  value: _gender,
                  label: 'Giới tính',
                  icon: Icons.people,
                  items: const ['Nam', 'Nữ', 'Khác'],
                  onChanged: (val) => setState(() => _gender = val),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _idCardController,
                  label: 'CCCD / CMND',
                  icon: Icons.badge,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _addressController,
                  label: 'Địa chỉ',
                  icon: Icons.location_on,
                ),
                const SizedBox(height: 32),
                if (controller.isError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Lỗi: ${controller.errorMessage}',
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ElevatedButton(
                  onPressed: controller.isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: controller.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Lưu thông tin',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primaryDark),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _selectDate,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Ngày sinh',
          prefixIcon: const Icon(Icons.calendar_today, color: AppColors.primaryDark),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        child: Text(
          _dateOfBirth == null ? 'Chọn ngày sinh' : DateFormat('dd/MM/yyyy').format(_dateOfBirth!),
          style: TextStyle(color: _dateOfBirth == null ? Colors.grey : AppColors.textPrimary),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primaryDark),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
