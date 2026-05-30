import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:tahki_drive1/pages/DashboardDriver/PathsPage.dart';
import '../../services/path_service.dart';
import 'package:tahki_drive1/app_dimensions.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // ← ajoute ça


const Color _blue     = Color(0xFF006AD7);
const Color _blueDark = Color(0xFF21277B);
const Color _greyBlue = Color(0xFF5F83B1);

String _fmtTime(String? iso) {
  if (iso == null || iso.isEmpty) return '--:--';
  try { return DateFormat('HH:mm').format(DateTime.parse(iso).toLocal()); }
  catch (_) { return '--:--'; }
}

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final dt  = DateTime.parse(iso).toLocal();
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day)
      return "Aujourd'hui";
    final y = now.subtract(const Duration(days: 1));
    if (dt.year == y.year && dt.month == y.month && dt.day == y.day)
      return 'Hier';
    return DateFormat('dd MMM', 'fr').format(dt);
  } catch (_) { return '—'; }
}

class RecentPathsSection extends StatefulWidget {
  const RecentPathsSection({super.key});
  @override
  State<RecentPathsSection> createState() => _RecentPathsSectionState();
}

class _RecentPathsSectionState extends State<RecentPathsSection> {
  List<Map<String, dynamic>> _paths = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await PathService.getRecentPaths(limit: 3);
    if (mounted) setState(() { _paths = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30.r),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 20, offset: const Offset(0, 10),
        )],
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: _blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15.r),
                    ),
                    child: const Icon(Icons.route_rounded, color: _blue, size: 20),
                  ),
                   SizedBox(width: 10.w),
                  Text("Trajets récents",
                    style: GoogleFonts.poppins(
                        fontSize: 16.sp, fontWeight: FontWeight.bold, color: _blueDark),
                  ),
                ]),
                TextButton(
                  onPressed: _loading ? null : () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const PathsPage())),
                  style: TextButton.styleFrom(foregroundColor: _blue),
                  child: Text("Voir tout",
                    style: GoogleFonts.poppins(
                        color: _blue, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
             SizedBox(height: 16.h),
            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(color: _blue),
              ))
            else if (_paths.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Column(children: [
                  Icon(Icons.route_outlined, size: 40.w, color: _greyBlue.withOpacity(0.5)),
                   SizedBox(height: 8.h),
                  Text("Aucun trajet enregistré",
                      style: GoogleFonts.poppins(fontSize: 13.sp, color: _greyBlue)),
                ])),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _paths.length,
                separatorBuilder: (_, __) => const Divider(height: 20),
                itemBuilder: (ctx, i) => _PathTile(path: _paths[i]),
              ),
          ],
        ),
      ),
    );
  }
}

class _PathTile extends StatelessWidget {
  final Map<String, dynamic> path;
  const _PathTile({required this.path});

  @override
  Widget build(BuildContext context) {
    final date  = _fmtDate(path['begin_path_time'] as String?);
    final start = _fmtTime(path['begin_path_time'] as String?);
    final end   = _fmtTime(path['end_path_time']   as String?);

    return Row(children: [
      Container(
        width: 46.w, height: 46.h,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_blue, _blueDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: const Icon(Icons.directions_car_rounded,
            color: Colors.white, size: 22),
      ),
       SizedBox(width: 14.w),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(date, style: GoogleFonts.poppins(
              fontSize: 13.sp, fontWeight: FontWeight.w600, color: _blueDark)),
           SizedBox(height: 3.h),
          Text("$start → $end",
              style: GoogleFonts.poppins(fontSize: 12.sp, color: _greyBlue)),
        ],
      )),
    ]);
  }
}
