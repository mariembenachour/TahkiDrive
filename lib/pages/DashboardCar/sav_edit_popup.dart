import 'package:flutter/material.dart';
import '../../services/detailsPannes_service.dart';
import 'package:tahki_drive1/app_dimensions.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // ← ajoute ça


// ─────────────────────────────────────────────
// POPUP DE CONFIRMATION SUPPRESSION
// ─────────────────────────────────────────────
void showDeleteConfirmDialog({
  required BuildContext context,
  required int idSav,
  required VoidCallback onDeleted,
}) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.all(28.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28.r),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.15),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icône
            Container(
              width: 64.w,
              height: 64.h,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Colors.red, size: 32),
            ),
            SizedBox(height: 20.h),
             Text(
              "Supprimer ?",
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Color(0xFF160078),
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              "Cette action est irréversible.\nL'entrée sera définitivement supprimée.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            SizedBox(height: 28.h),
            Row(
              children: [
                // Annuler
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      height: 48.h,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: const Center(
                        child: Text(
                          "Annuler",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF160078),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                // Supprimer
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx);
                      final ok = await DetailPannesService.deleteSav(idSav);
                      if (ok) {
                        onDeleted();
                      }
                    },
                    child: Container(
                      height: 48.h,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF4757), Color(0xFFCC0000)],
                        ),
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          "Supprimer",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// POPUP MODIFICATION — centré, style moderne
// ─────────────────────────────────────────────
void showEditDialog({
  required BuildContext context,
  required Map<String, dynamic> data,
  required VoidCallback onUpdated,
}) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (ctx) => SavEditDialog(data: data, onUpdated: onUpdated),
  );
}

class SavEditDialog extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onUpdated;

  const SavEditDialog({
    super.key,
    required this.data,
    required this.onUpdated,
  });

  @override
  State<SavEditDialog> createState() => _SavEditDialogState();
}

class _SavEditDialogState extends State<SavEditDialog> {
  final _descriptionController = TextEditingController();
  final _costController = TextEditingController();
  DateTime? _selectedDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _descriptionController.text = widget.data['description'] ?? '';
    _costController.text = widget.data['cost']?.toString() ?? '';
    if (widget.data['date_reparation'] != null) {
      try {
        _selectedDate =
            DateTime.parse(widget.data['date_reparation'].toString());
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final body = {
      "date_reparation": (_selectedDate ?? DateTime.now()).toIso8601String().split('T').first,
      "description": _descriptionController.text.trim(),
      "cost": double.tryParse(_costController.text.trim()),
      "garage_id": widget.data['garage_id'],
      "maintenance_type": widget.data['maintenance_type'],
    };
    final ok =
    await DetailPannesService.updateSav(widget.data['id_sav'], body);
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (ok) {
      Navigator.pop(context);
      widget.onUpdated();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:  Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8.w),
            Text("Modifié avec succès ✅"),
          ]),
          backgroundColor: const Color(0xFF7226FF),
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Erreur lors de la modification"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
        ),
      );
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "Choisir une date";
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding:  EdgeInsets.symmetric(horizontal: 20.w, vertical: 40.h),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28.r),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.2),
              blurRadius: 50,
              offset: const Offset(0, 25),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Container(
              padding:  EdgeInsets.fromLTRB(24.w, 20.h, 16.w, 20.h),
              decoration:  BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF7226FF), Color(0xFF160078)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_rounded,
                        color: Colors.white, size: 18),
                  ),
                  SizedBox(width: 12.w),
                   Expanded(
                    child: Text(
                      "Modifier l'entrée",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.all(6.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ──
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type (lecture seule)
                    _buildReadOnlyField(
                      Icons.build_rounded,
                      "Type",
                      widget.data['maintenance_type'] ?? "—",
                    ),
                    SizedBox(height: 16.h),

                    // Date picker
                    GestureDetector(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          builder: (ctx, child) => Theme(
                            data: Theme.of(ctx).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Color(0xFF7226FF),
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (date != null) {
                          setState(() => _selectedDate = date);
                        }
                      },
                      child: _buildFieldContainer(
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7226FF).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: const Icon(Icons.calendar_today_rounded,
                                  color: Color(0xFF7226FF), size: 16),
                            ),
                            SizedBox(width: 12.w),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Date de réparation",
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                Text(
                                  _formatDate(_selectedDate),
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedDate != null
                                        ? const Color(0xFF160078)
                                        : Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Icon(Icons.chevron_right,
                                color: Colors.grey.shade400, size: 18),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Description
                    _buildTextField(
                      controller: _descriptionController,
                      label: "Description",
                      icon: Icons.notes_rounded,
                      maxLines: 3,
                    ),
                    SizedBox(height: 16.h),

                    // Coût
                    _buildTextField(
                      controller: _costController,
                      label: "Coût (DT)",
                      icon: Icons.payments_rounded,
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      suffix: "TND",
                    ),
                    SizedBox(height: 28.h),

                    // Bouton Enregistrer
                    GestureDetector(
                      onTap: _isSubmitting ? null : _submit,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        height: 52.h,
                        decoration: BoxDecoration(
                          gradient: _isSubmitting
                              ? LinearGradient(
                            colors: [
                              Colors.grey.shade300,
                              Colors.grey.shade400
                            ],
                          )
                              : const LinearGradient(
                            colors: [
                              Color(0xFF7226FF),
                              Color(0xFF160078)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18.r),
                          boxShadow: _isSubmitting
                              ? []
                              : [
                            BoxShadow(
                              color: const Color(0xFF7226FF)
                                  .withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isSubmitting
                              ? SizedBox(
                            width: 22.w,
                            height: 22.h,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                              :  Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.save_rounded,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 8.w),
                              Text(
                                "Enregistrer",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(IconData icon, String label, String value) {
    return _buildFieldContainer(
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: Colors.grey.shade500, size: 16),
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11.sp, color: Colors.grey.shade500)),
              Text(value,
                  style:  TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF160078))),
            ],
          ),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text("lecture seule",
                style: TextStyle(
                    fontSize: 10.sp, color: Colors.grey.shade400)),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldContainer({required Widget child}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F8FF),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE8E0FF)),
      ),
      child: child,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? suffix,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: Color(0xFF160078)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
        TextStyle(fontSize: 13.sp, color: Colors.grey.shade500),
        prefixIcon: Container(
          margin: EdgeInsets.all(10.w),
          padding: EdgeInsets.all(7.w),
          decoration: BoxDecoration(
            color: const Color(0xFF7226FF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(icon, color: const Color(0xFF7226FF), size: 16),
        ),
        suffixText: suffix,
        suffixStyle: TextStyle(
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500),
        filled: true,
        fillColor: const Color(0xFFF9F8FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: const BorderSide(color: Color(0xFFE8E0FF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: const BorderSide(color: Color(0xFFE8E0FF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide:
          const BorderSide(color: Color(0xFF7226FF), width: 1.5),
        ),
      ),
    );
  }
}
