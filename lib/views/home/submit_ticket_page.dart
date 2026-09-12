import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ticket_provider.dart';
import '../common/confirm_dialog.dart';
import '../common/image_preview.dart';
import '../common/page_insets.dart';

class SubmitTicketPage extends StatefulWidget {
  const SubmitTicketPage({super.key});

  @override
  State<SubmitTicketPage> createState() => _SubmitTicketPageState();
}

class _SubmitTicketPageState extends State<SubmitTicketPage> {
  final _formKey = GlobalKey<FormState>();

  String _purchaseDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String _phone = '';
  String _deviceType = ApiConstants.deviceTypes.first;
  String _brand = ApiConstants.brands.first;
  String _faultType = ApiConstants.problemTypes.first;
  String _campus = ApiConstants.campuses.first;
  String _contactType = ApiConstants.contactTypes.first;
  String _contactNumber = '';
  String _model = '';
  String _description = '';
  String _warrantyStatus = 'unknown'; // expired, under, unknown
  int _duoCampus = 0; // 是否接受跨校区维修（服务端工单记录该意愿）
  bool _isOffline = false;

  final List<String> _uploadedImageUrls = [];
  bool _isUploadingImage = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _phone = user.phone;
      if (user.campus.isNotEmpty &&
          ApiConstants.campuses.contains(user.campus)) {
        _campus = user.campus;
      }
      if (user.qq != null && user.qq!.isNotEmpty) {
        _contactNumber = user.qq!;
      }
    }
  }

  Future<void> _pickPurchaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_purchaseDate) ?? DateTime.now(),
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() => _purchaseDate = DateFormat('yyyy-MM-dd').format(picked));
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final XFile? pickedFile;
    try {
      pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
    } catch (_) {
      // 相册权限被拒等场景：image_picker 会抛出异常而非返回 null
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('无法打开相册，请检查相册权限设置')));
      return;
    }

    if (pickedFile == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    final res = await ApiClient().uploadImage(pickedFile.path);

    if (!mounted) return;

    setState(() {
      _isUploadingImage = false;
    });

    if (res.success && res.data != null && res.data!.isNotEmpty) {
      setState(() {
        _uploadedImageUrls.add(res.data!);
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('图片上传成功')));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.message ?? '图片上传失败')));
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final ok = await showConfirmDialog(
      context,
      title: '确认提交报修？',
      content: '工单提交后不可更改；飞扬维修技术员将根据您预留的信息与您联系。',
      confirmText: '确认提交',
    );

    if (ok != true) return;
    if (!mounted || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    final ticketProvider = context.read<TicketProvider>();
    final auth = context.read<AuthProvider>();

    final finalImageUrl = _uploadedImageUrls.isNotEmpty
        ? _uploadedImageUrls.first
        : ApiConstants.defaultTicketImage;
    // 注意：后端 /v1/ticket/create 的 image 为单值字段，多图仅有第一张生效（与小程序原版一致）

    final success = await ticketProvider.submitTicket(
      uid: auth.user?.uid,
      userNick: auth.user?.nickname,
      purchaseDate: _purchaseDate,
      phone: _phone,
      deviceType: _deviceType,
      computerBrand: _brand,
      description: _description,
      imageUrl: finalImageUrl,
      faultType: _faultType,
      qqOrContact: '$_contactType|$_contactNumber',
      campus: _isOffline ? '线下' : _campus,
      duoCampus: _duoCampus,
      warrantyStatus: _warrantyStatus,
      model: _model,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('报修工单提交成功！')));
      if (auth.user != null) {
        ticketProvider.fetchTickets(role: auth.user!.role, uid: auth.user!.uid);
      }
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ticketProvider.lastActionError ?? '提交失败，请稍后重试')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('提交设备报修')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: pageListPadding(context),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '基本设备信息',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _deviceType,
                      decoration: const InputDecoration(
                        labelText: '设备类型',
                        border: OutlineInputBorder(),
                      ),
                      items: ApiConstants.deviceTypes
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _deviceType = v!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _brand,
                      decoration: const InputDecoration(
                        labelText: '设备品牌',
                        border: OutlineInputBorder(),
                      ),
                      items: ApiConstants.brands
                          .map(
                            (b) => DropdownMenuItem(value: b, child: Text(b)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _brand = v!),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _model,
                      decoration: const InputDecoration(
                        labelText: '具体型号 (选填)',
                        hintText: '如联想小新Pro 16 / 华硕天选7 Pro Max',
                        border: OutlineInputBorder(),
                      ),
                      onSaved: (v) => _model = v?.trim() ?? '',
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _warrantyStatus,
                      decoration: const InputDecoration(
                        labelText: '在保状态',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'expired', child: Text('过保')),
                        DropdownMenuItem(value: 'under', child: Text('在保')),
                        DropdownMenuItem(value: 'unknown', child: Text('未知')),
                      ],
                      onChanged: (v) => setState(() => _warrantyStatus = v!),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _pickPurchaseDate,
                      borderRadius: BorderRadius.circular(4),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '购买时间',
                          helperText: '用于判断保修状态，点击选择日期',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        child: Text(_purchaseDate),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '故障与送修信息',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _faultType,
                      decoration: const InputDecoration(
                        labelText: '问题类型',
                        border: OutlineInputBorder(),
                      ),
                      items: ApiConstants.problemTypes
                          .map(
                            (p) => DropdownMenuItem(value: p, child: Text(p)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _faultType = v!),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('是否线下接单'),
                      subtitle: const Text('参加社团大型线下集中维修时勾选'),
                      value: _isOffline,
                      onChanged: (v) => setState(() => _isOffline = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('接受跨校区维修'),
                      subtitle: const Text('开启后其他校区的技术员也可处理您的工单，通常维修更快'),
                      value: _duoCampus == 1,
                      onChanged: (v) => setState(() => _duoCampus = v ? 1 : 0),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (!_isOffline) ...[
                      DropdownButtonFormField<String>(
                        initialValue: _campus,
                        decoration: const InputDecoration(
                          labelText: '所在校区',
                          border: OutlineInputBorder(),
                        ),
                        items: ApiConstants.campuses
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _campus = v!),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: '问题详细描述',
                        hintText: '请详述设备故障表现（如开机黑屏、风扇狂转、无法进入系统等）',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '请填写问题描述' : null,
                      onSaved: (v) => _description = v?.trim() ?? '',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '联系方式',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: '联系电话',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || !RegExp(r'^\d{11}$').hasMatch(v.trim()))
                          ? '请输入11位手机号'
                          : null,
                      onSaved: (v) => _phone = v?.trim() ?? '',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(
                          width: 120,
                          child: DropdownButtonFormField<String>(
                            initialValue: _contactType,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            items: ApiConstants.contactTypes
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _contactType = v!),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: _contactNumber,
                            decoration: InputDecoration(
                              labelText: '联系账号',
                              hintText: '输入$_contactType',
                              border: const OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? '请输入联系账号'
                                : null,
                            onSaved: (v) => _contactNumber = v?.trim() ?? '',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '故障图片',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '上传故障画面、外观损坏等照片有助于技术员提前准备工具（目前支持 1 张，工单将使用第一张）。',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ..._uploadedImageUrls.map(
                          (url) => Stack(
                            clipBehavior: Clip.none,
                            children: [
                              GestureDetector(
                                onTap: () => showImagePreview(context, url),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    url,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.grey.withValues(alpha: 0.1),
                                      child: const Icon(
                                        Icons.broken_image_outlined,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: -6,
                                right: -6,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _uploadedImageUrls.remove(url);
                                    });
                                  },
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: const Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_uploadedImageUrls.isEmpty)
                          GestureDetector(
                            onTap: _isUploadingImage
                                ? null
                                : _pickAndUploadImage,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.grey.withValues(alpha: 0.3),
                                ),
                              ),
                              child: _isUploadingImage
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.add_a_photo_outlined,
                                      color: Colors.grey,
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('确认提交工单', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
