import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:toothfile/Dental Chart/tooth_selection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import 'package:archive/archive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:toothfile/touchbar/touch_bar_helper.dart';

class SendFilesDialog extends StatefulWidget {
  final Map<String, dynamic> userData;
  final List<String> initialFilePaths;
  const SendFilesDialog({
    super.key,
    required this.userData,
    this.initialFilePaths = const [],
  });

  @override
  State<SendFilesDialog> createState() => _SendFilesDialogState();
}

class _SendFilesDialogState extends State<SendFilesDialog> {
  List<PlatformFile> _pickedFiles = [];
  bool _advancedOptionsEnabled = false;
  bool _compressAsZip = true;
  String? _selectedToothColor;
  final TextEditingController _customerNameController = TextEditingController();
  List<String> _selectedTeeth = [];
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialFilePaths.isNotEmpty) {
      _pickedFiles = widget.initialFilePaths
          .where((path) => File(path).existsSync())
          .map((path) {
            final file = File(path);
            final size = file.lengthSync();
            final segments = path.split(RegExp(r'[\\/]'));
            final name = segments.isNotEmpty ? segments.last : path;
            return PlatformFile(name: name, size: size, path: path);
          })
          .toList();
    }
    TouchBarHelper.setPopupTouchBar(
      context: context,
      actions: [
        TouchBarHelperAction(
          label: 'Cancel',
          action: () => Navigator.of(context).pop(),
        ),
        TouchBarHelperAction(
          label: 'Send Files',
          action: () => _uploadFilesAndCreateOrder(),
          isPrimary: true,
        ),
      ],
    );
  }

  final Map<String, List<String>> _toothColorGroups = {
    'A': ['A1', 'A2', 'A3', 'A3.5', 'A4'],
    'B': ['B1', 'B2', 'B3', 'B4'],
    'C': ['C1', 'C2', 'C3', 'C4'],
    'D': ['D2', 'D3', 'D4'],
  };

  Color _getShadeGroupColor(String group) {
    switch (group) {
      case 'A':
        return const Color(0xFFFEF3C7);
      case 'B':
        return const Color(0xFFFED7AA);
      case 'C':
        return const Color(0xFFE5E7EB);
      case 'D':
        return const Color(0xFFD1D5DB);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _getShadeGroupAccent(String group) {
    switch (group) {
      case 'A':
        return const Color(0xFFF59E0B);
      case 'B':
        return const Color(0xFFF97316);
      case 'C':
        return const Color(0xFF6B7280);
      case 'D':
        return const Color(0xFF4B5563);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  void _showToothColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final sheetColor = isDark ? const Color(0xFF111827) : Colors.white;
        final borderColor = isDark
            ? const Color(0xFF2B3A55)
            : const Color(0xFFE2E8F0);
        final titleColor = isDark
            ? const Color(0xFFE5E7EB)
            : const Color(0xFF020817);
        final mutedTextColor = isDark
            ? const Color(0xFFA8B3C7)
            : const Color(0xFF64748B);
        final unselectedTextColor = isDark
            ? const Color(0xFFE5E7EB)
            : const Color(0xFF020817);
        return Container(
          decoration: BoxDecoration(
            color: sheetColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: borderColor, width: 1)),
          ),

          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.palette_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Tooth Color',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Vita Classic Shade Guide',
                          style: TextStyle(fontSize: 13, color: mutedTextColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 500),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _toothColorGroups.length,
                  itemBuilder: (context, groupIndex) {
                    final groupKey = _toothColorGroups.keys.elementAt(
                      groupIndex,
                    );
                    final colors = _toothColorGroups[groupKey]!;
                    final groupColor = _getShadeGroupColor(groupKey);
                    final accentColor = _getShadeGroupAccent(groupKey);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: groupColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: accentColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: accentColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: accentColor.withOpacity(0.4),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Shade Group $groupKey',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: accentColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 5,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 1.1,
                                ),
                            itemCount: colors.length,
                            itemBuilder: (context, index) {
                              final color = colors[index];
                              final isSelected = _selectedToothColor == color;

                              return InkWell(
                                onTap: () {
                                  setState(() => _selectedToothColor = color);
                                  Navigator.pop(context);
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? const LinearGradient(
                                            colors: [
                                              Color(0xFF8B5CF6),
                                              Color(0xFF6366F1),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : null,
                                    color: isSelected ? null : groupColor,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF8B5CF6)
                                          : accentColor.withOpacity(0.2),
                                      width: isSelected ? 3 : 2,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF8B5CF6,
                                              ).withOpacity(0.4),
                                              blurRadius: 12,
                                              offset: const Offset(0, 6),
                                            ),
                                          ]
                                        : [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.04,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (isSelected)
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.25,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check_circle_rounded,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        )
                                      else
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                groupColor,
                                                accentColor.withOpacity(0.3),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: accentColor.withOpacity(
                                                0.4,
                                              ),
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: accentColor.withOpacity(
                                                  0.3,
                                                ),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                      const SizedBox(height: 6),
                                      Text(
                                        color,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? Colors.white
                                              : unselectedTextColor,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
      );
      if (result != null) {
        setState(() {
          _pickedFiles = result.files;
        });
      }
    } catch (e) {
      print('Error picking files: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(imageQuality: 85);
      if (images.isNotEmpty) {
        final List<PlatformFile> platformFiles = [];
        for (final x in images) {
          final bytes = await x.readAsBytes();
          platformFiles.add(
            PlatformFile(
              name: x.name,
              size: bytes.length,
              bytes: bytes,
              path: x.path,
            ),
          );
        }
        setState(() {
          _pickedFiles.addAll(platformFiles);
        });
      }
    } catch (e) {
      print('Error picking from gallery: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        final pf = PlatformFile(
          name: photo.name,
          size: bytes.length,
          bytes: bytes,
          path: photo.path,
        );
        setState(() {
          _pickedFiles.add(pf);
        });
      }
    } catch (e) {
      print('Error taking photo: $e');
    }
  }

  void _showUploadOptions() {
    if (Platform.isIOS || Platform.isAndroid) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) {
          return CupertinoTheme(
            data: const CupertinoThemeData(brightness: Brightness.dark),
            child: CupertinoActionSheet(
              actions: [
                CupertinoActionSheetAction(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _pickFromGallery();
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Photo Library'),
                      Icon(CupertinoIcons.photo_on_rectangle),
                    ],
                  ),
                ),
                CupertinoActionSheetAction(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _takePhoto();
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Take Photo'),
                      Icon(CupertinoIcons.camera),
                    ],
                  ),
                ),
                CupertinoActionSheetAction(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _pickFiles();
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Choose File'),
                      Icon(CupertinoIcons.folder),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final sheetColor = isDark ? const Color(0xFF111827) : Colors.white;
          final borderColor = isDark
              ? const Color(0xFF2B3A55)
              : const Color(0xFFE2E8F0);
          final titleColor = isDark
              ? const Color(0xFFE5E7EB)
              : const Color(0xFF020817);
          return Container(
            decoration: BoxDecoration(
              color: sheetColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border(top: BorderSide(color: borderColor, width: 1)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.folder_open_rounded, color: titleColor),
                    title: Text(
                      'Choose File',
                      style: TextStyle(color: titleColor),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      await _pickFiles();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  void _removeFile(int index) {
    setState(() {
      _pickedFiles.removeAt(index);
    });
  }

  Future<Uint8List> _createZipFile(List<PlatformFile> files) async {
    final archive = Archive();

    for (final file in files) {
      Uint8List? fileBytes;

      if (file.bytes != null) {
        fileBytes = file.bytes;
      } else if (file.path != null) {
        final File f = File(file.path!);
        fileBytes = await f.readAsBytes();
      }

      if (fileBytes != null) {
        final archiveFile = ArchiveFile(file.name, fileBytes.length, fileBytes);
        archive.addFile(archiveFile);
      }
    }

    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);
    return Uint8List.fromList(zipData!);
  }

  Future<void> _uploadFilesAndCreateOrder() async {
    if (_pickedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Please select at least one file',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFF97316),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          elevation: 4,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'User not logged in',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            elevation: 4,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final recipientEmail = widget.userData['email'];
      final List<Map<String, dynamic>> receiver = await supabase
          .from('profiles')
          .select('id')
          .eq('email', recipientEmail)
          .limit(1);

      if (receiver.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Recipient not found',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            elevation: 4,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      final receiverId = receiver.first['id'];

      final customerName = _customerNameController.text;
      final selectedToothColor = _selectedToothColor;
      final selectedTeeth = _selectedTeeth;
      final message = _messageController.text;

      final String orderId = const Uuid().v4();

      if (_compressAsZip) {
        final zipBytes = await _createZipFile(_pickedFiles);
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_files.zip';
        final filePath = 'dental-files/${user.id}/$fileName';

        await supabase.storage
            .from('dental-files')
            .uploadBinary(
              filePath,
              zipBytes,
              fileOptions: const FileOptions(upsert: true),
            );

        final insertionData = {
          'order_id': orderId,
          'sender_id': user.id,
          'receiver_id': receiverId,
          'file_name': fileName,
          'file_size': zipBytes.length,
          'file_type': 'zip',
          'file_path': filePath,
          'message': message.isNotEmpty ? message : null,
          'customer_name': customerName.isNotEmpty ? customerName : null,
          'selected_teeth': selectedTeeth.isNotEmpty ? selectedTeeth : null,
          'tooth_color': selectedToothColor,
        };
        await supabase.from('shared_files').insert(insertionData);
      } else {
        for (final file in _pickedFiles) {
          final fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
          final filePath = 'dental-files/${user.id}/$fileName';

          Uint8List? fileBytes;
          if (file.bytes != null) {
            fileBytes = file.bytes;
          } else if (file.path != null) {
            final File f = File(file.path!);
            fileBytes = await f.readAsBytes();
          } else {
            continue;
          }

          if (fileBytes == null) continue;

          await supabase.storage
              .from('dental-files')
              .uploadBinary(
                filePath,
                fileBytes,
                fileOptions: const FileOptions(upsert: true),
              );

          final insertionData = {
            'order_id': orderId,
            'sender_id': user.id,
            'receiver_id': receiverId,
            'file_name': file.name,
            'file_size': file.size,
            'file_type': file.extension ?? 'unknown',
            'file_path': filePath,
            'message': message.isNotEmpty ? message : null,
            'customer_name': customerName.isNotEmpty ? customerName : null,
            'selected_teeth': selectedTeeth.isNotEmpty ? selectedTeeth : null,
            'tooth_color': selectedToothColor,
          };
          await supabase.from('shared_files').insert(insertionData);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Files sent successfully!',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          elevation: 4,
        ),
      );

      setState(() {
        _pickedFiles = [];
        _customerNameController.clear();
        _selectedToothColor = null;
        _selectedTeeth = [];
        _messageController.clear();
        _advancedOptionsEnabled = false;
        _compressAsZip = true;
      });

      Navigator.pop(context);
    } catch (e) {
      print('Error in upload: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Error sending files: $e',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          elevation: 4,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF2B3A55)
        : const Color(0xFFE2E8F0);
    final panelColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final softPanel = isDark
        ? const Color(0xFF1D2A3F)
        : const Color(0xFFF1F5F9);
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF020817);
    final mutedTextColor = isDark
        ? const Color(0xFFA8B3C7)
        : const Color(0xFF64748B);
    final hintTextColor = isDark
        ? const Color(0xFF8FA2BF)
        : const Color(0xFF94A3B8);
    final selectedInfoBorder = isDark
        ? const Color(0xFF2E4365)
        : const Color(0xFFE2E8F0);
    final roleChipBg = isDark
        ? const Color(0xFF1E3A8A)
        : const Color(0xFFDBEAFE);
    final roleChipText = isDark
        ? const Color(0xFFBFDBFE)
        : const Color(0xFF2563EB);
    final onlineBorder = isDark ? const Color(0xFF111827) : Colors.white;
    final dangerSoft = isDark
        ? const Color(0xFF3B1A1A)
        : const Color(0xFFFEE2E2);

    return Container(
      decoration: BoxDecoration(
        color: sheetColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Send Files',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Share files with user',
                        style: TextStyle(fontSize: 13, color: mutedTextColor),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: softPanel,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: mutedTextColor,
                      size: 20,
                    ),
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Form Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recipient Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(
                            0xFF8B5CF6,
                          ).withOpacity(isDark ? 0.16 : 0.05),
                          const Color(
                            0xFF6366F1,
                          ).withOpacity(isDark ? 0.16 : 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selectedInfoBorder),
                    ),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4B5563),
                                    Color(0xFF6B7280),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.transparent,
                                child: Text(
                                  widget.userData['name'] != null &&
                                          widget.userData['name'].isNotEmpty
                                      ? widget.userData['name'][0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22C55E),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: onlineBorder,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.userData['name'] ?? 'Unknown User',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: titleColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: roleChipBg,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      widget.userData['role'] ?? 'User',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: roleChipText,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      widget.userData['email'] ?? 'N/A',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: mutedTextColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Pick Files Button
                  InkWell(
                    onTap: _showUploadOptions,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(
                              0xFF8B5CF6,
                            ).withOpacity(isDark ? 0.16 : 0.05),
                            const Color(
                              0xFF6366F1,
                            ).withOpacity(isDark ? 0.16 : 0.05),
                          ],
                        ),
                        border: Border.all(color: borderColor, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF8B5CF6,
                                  ).withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.folder_open_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Click to choose files',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_pickedFiles.length} file${_pickedFiles.length != 1 ? 's' : ''} selected',
                            style: TextStyle(
                              fontSize: 13,
                              color: mutedTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_pickedFiles.isNotEmpty) ...[
                    const SizedBox(height: 16),

                    // Compress as ZIP option
                    if (_pickedFiles.length > 1)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(
                                0xFF8B5CF6,
                              ).withOpacity(isDark ? 0.16 : 0.05),
                              const Color(
                                0xFF6366F1,
                              ).withOpacity(isDark ? 0.16 : 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: _compressAsZip
                                    ? const LinearGradient(
                                        colors: [
                                          Color(0xFF8B5CF6),
                                          Color(0xFF6366F1),
                                        ],
                                      )
                                    : null,
                                color: _compressAsZip ? null : softPanel,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.folder_zip_rounded,
                                size: 18,
                                color: _compressAsZip
                                    ? Colors.white
                                    : mutedTextColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Compress as ZIP',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: titleColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Bundle all files into one archive',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: mutedTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _compressAsZip,
                              onChanged: (value) {
                                setState(() {
                                  _compressAsZip = value;
                                });
                              },
                              activeColor: const Color(0xFF8B5CF6),
                            ),
                          ],
                        ),
                      ),

                    // Files List
                    ...List.generate(_pickedFiles.length, (index) {
                      final file = _pickedFiles[index];
                      final sizeInKB = (file.size / 1024).toStringAsFixed(1);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: panelColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF8B5CF6),
                                    Color(0xFF6366F1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.insert_drive_file_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    file.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: titleColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$sizeInKB KB',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: mutedTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: dangerSoft,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                  color: Color(0xFFEF4444),
                                ),
                                onPressed: () => _removeFile(index),
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 20),

                  // Advanced Options
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: panelColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDBEAFE),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.tune_rounded,
                                      size: 16,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Advanced Options',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: titleColor,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Add case details',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: mutedTextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _advancedOptionsEnabled,
                              onChanged: (bool value) {
                                setState(() {
                                  _advancedOptionsEnabled = value;
                                });
                              },
                              activeColor: const Color(0xFF8B5CF6),
                            ),
                          ],
                        ),
                        if (_advancedOptionsEnabled) ...[
                          const SizedBox(height: 16),
                          Divider(height: 1, color: borderColor),
                          const SizedBox(height: 16),

                          // Customer Name
                          Text(
                            'Customer Name',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _customerNameController,
                            decoration: InputDecoration(
                              hintText: 'Enter customer name',
                              hintStyle: const TextStyle(
                                color: Color(0xFF8FA2BF),
                              ),
                              prefixIcon: Container(
                                margin: const EdgeInsets.all(10),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDBEAFE),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: Color(0xFF2563EB),
                                  size: 16,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: borderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: borderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFF8B5CF6),
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: sheetColor,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Tooth Color
                          Text(
                            'Tooth Color (Vita Classic Guide)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _showToothColorPicker,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: sheetColor,
                                border: Border.all(color: borderColor),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      gradient: _selectedToothColor != null
                                          ? const LinearGradient(
                                              colors: [
                                                Color(0xFFFBBF24),
                                                Color(0xFFF59E0B),
                                              ],
                                            )
                                          : null,
                                      color: _selectedToothColor != null
                                          ? null
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: _selectedToothColor != null
                                          ? [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFFF59E0B,
                                                ).withOpacity(0.3),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Icon(
                                      Icons.palette_rounded,
                                      size: 18,
                                      color: _selectedToothColor != null
                                          ? Colors.white
                                          : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedToothColor ??
                                              'Select tooth color',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight:
                                                _selectedToothColor != null
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            color: _selectedToothColor != null
                                                ? titleColor
                                                : hintTextColor,
                                          ),
                                        ),
                                        if (_selectedToothColor != null)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getShadeGroupColor(
                                                _selectedToothColor![0],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: _getShadeGroupAccent(
                                                  _selectedToothColor![0],
                                                ).withOpacity(0.3),
                                              ),
                                            ),
                                            child: Text(
                                              'Shade Group ${_selectedToothColor![0]}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: _getShadeGroupAccent(
                                                  _selectedToothColor![0],
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: mutedTextColor,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Dental Chart
                          Text(
                            'Dental Chart - Select Teeth',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap on teeth to select or deselect',
                            style: TextStyle(
                              fontSize: 11,
                              color: mutedTextColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(
                                    0xFF2563EB,
                                  ).withOpacity(isDark ? 0.16 : 0.05),
                                  const Color(
                                    0xFF8B5CF6,
                                  ).withOpacity(isDark ? 0.16 : 0.05),
                                ],
                              ),
                              border: Border.all(color: borderColor, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TeethSelector(
                                  onChange: (List<String> selected) {
                                    setState(() {
                                      _selectedTeeth = selected;
                                    });
                                  },
                                  initiallySelected: _selectedTeeth,
                                  multiSelect: true,
                                ),
                                if (_selectedTeeth.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: sheetColor,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFF2563EB),
                                                    Color(0xFF8B5CF6),
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Icon(
                                                Icons.check_circle_rounded,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${_selectedTeeth.length} ${_selectedTeeth.length == 1 ? 'tooth' : 'teeth'} selected',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: titleColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: _selectedTeeth
                                              .map(
                                                (tooth) => Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    gradient:
                                                        const LinearGradient(
                                                          colors: [
                                                            Color(0xFF2563EB),
                                                            Color(0xFF8B5CF6),
                                                          ],
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: const Color(
                                                          0xFF2563EB,
                                                        ).withOpacity(0.3),
                                                        blurRadius: 4,
                                                        offset: const Offset(
                                                          0,
                                                          2,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Text(
                                                    tooth,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Message Field
                  Text(
                    'Message (Optional)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _messageController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Enter your message here...',
                      hintStyle: const TextStyle(
                        color: Color(0xFF8FA2BF),
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: sheetColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFF8B5CF6),
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Bottom Buttons
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: sheetColor,
              border: Border(top: BorderSide(color: borderColor, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: mutedTextColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _uploadFilesAndCreateOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send_rounded, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Send Files',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
