import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/motion.dart';
import '../../shell/app_bar.dart';
import 'help_content.dart';

TextStyle _t(double size, FontWeight w, [Color? c, double h = 1.5]) =>
    GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: w, color: c ?? AppColors.ink, height: h);

/// Panduan penggunaan: daftar topik + pencarian. [initialTopic] langsung membuka satu topik.
class HelpPage extends StatefulWidget {
  const HelpPage({super.key, this.initialTopic});
  final String? initialTopic;

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  bool _match(HelpTopic t, String q) {
    if (q.isEmpty) return true;
    final hay = StringBuffer('${t.title} ${t.summary} ');
    for (final s in t.sections) {
      hay.write('${s.title} ');
      for (final b in s.blocks) {
        hay.write(switch (b) {
          HText(:final text) => text,
          HTip(:final text) => text,
          HBullets(:final items) => items.join(' '),
          HSteps(:final items) => items.join(' '),
          HRoleTable(:final rows) => rows.map((r) => '${r.$1} ${r.$2}').join(' '),
          HImage(:final caption) => caption,
          HApprovalFlow() => 'persetujuan tingkat 1 akhir mengajukan',
        });
        hay.write(' ');
      }
    }
    return hay.toString().toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.initialTopic == null
        ? null
        : helpTopics.where((t) => t.id == widget.initialTopic).firstOrNull;
    if (start != null) return HelpTopicPage(topic: start);

    final q = _q.text.trim().toLowerCase();
    final list = helpTopics.where((t) => _match(t, q)).toList();
    return Scaffold(
      appBar: const RmsAppBar(title: Text('Panduan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          TextField(
            controller: _q,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Cari, mis. "tingkat 1", "refund", "PIN"',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 14),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Tidak ada topik yang cocok.', textAlign: TextAlign.center, style: _t(14, FontWeight.w500, AppColors.muted)),
            ),
          for (var i = 0; i < list.length; i++)
            Entrance(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TopicTile(list[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile(this.t);
  final HelpTopic t;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => HelpTopicPage(topic: t))),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(14)),
            child: Icon(t.icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title, style: _t(15, FontWeight.w800, AppColors.ink, 1.3)),
                const SizedBox(height: 2),
                Text(t.summary, style: _t(12.5, FontWeight.w500, AppColors.muted, 1.4)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.faint),
        ],
      ),
    ),
  );
}

/// Satu topik panduan.
class HelpTopicPage extends StatelessWidget {
  const HelpTopicPage({super.key, required this.topic});
  final HelpTopic topic;

  @override
  Widget build(BuildContext context) {
    var i = 0;
    return Scaffold(
      appBar: RmsAppBar(title: Text(topic.title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Text(topic.summary, style: _t(14, FontWeight.w500, AppColors.muted)),
              const SizedBox(height: 12),
              for (final s in topic.sections)
                Entrance(
                  index: i++,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title, style: _t(16, FontWeight.w800, AppColors.ink, 1.3)),
                        const SizedBox(height: 10),
                        for (final b in s.blocks)
                          Padding(padding: const EdgeInsets.only(bottom: 10), child: _block(b)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _block(HelpBlock b) => switch (b) {
    HText(:final text) => Text(text, style: _t(14, FontWeight.w400, const Color(0xFF3F3A35))),
    HBullets(:final items) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final it in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 8, right: 10),
                  decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                ),
                Expanded(child: Text(it, style: _t(14, FontWeight.w400, const Color(0xFF3F3A35)))),
              ],
            ),
          ),
      ],
    ),
    HSteps(:final items) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var n = 0; n < items.length; n++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(right: 10, top: 1),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(8)),
                  child: Text('${n + 1}', style: _t(12, FontWeight.w800, Colors.white, 1)),
                ),
                Expanded(child: Text(items[n], style: _t(14, FontWeight.w400, const Color(0xFF3F3A35)))),
              ],
            ),
          ),
      ],
    ),
    HTip(:final text, :final warning) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warning ? AppColors.primarySoft : AppColors.sageSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning ? Icons.warning_amber_rounded : Icons.lightbulb_outline_rounded,
            size: 19,
            color: warning ? AppColors.primary : AppColors.sageInk,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: _t(13.5, FontWeight.w600, warning ? AppColors.primaryDeep : AppColors.sageInk),
            ),
          ),
        ],
      ),
    ),
    HImage(:final asset, :final caption) => _GuideImage(asset: asset, caption: caption),
    HRoleTable(:final rows) => Column(
      children: [
        for (var n = 0; n < rows.length; n++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: n == 0 ? null : Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 108, child: Text(rows[n].$1, style: _t(13.5, FontWeight.w800, AppColors.ink, 1.4))),
                Expanded(child: Text(rows[n].$2, style: _t(13, FontWeight.w400, AppColors.muted, 1.45))),
              ],
            ),
          ),
      ],
    ),
    HApprovalFlow() => const ApprovalFlowDiagram(),
  };
}

/// Gambar panduan (screenshot) opsional: bila berkas belum ada di assets/guide, tidak ditampilkan.
class _GuideImage extends StatelessWidget {
  const _GuideImage({required this.asset, required this.caption});
  final String asset;
  final String caption;

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    frameBuilder: (context, child, frame, sync) => frame == null && !sync
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: AppColors.border)),
                  child: child,
                ),
              ),
              const SizedBox(height: 6),
              Text(caption, style: _t(12, FontWeight.w500, AppColors.faint, 1.4)),
            ],
          ),
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
  );
}

/// Diagram alur persetujuan 2 tingkat.
class ApprovalFlowDiagram extends StatelessWidget {
  const ApprovalFlowDiagram({super.key});

  @override
  Widget build(BuildContext context) {
    Widget step(String no, String title, String who, Color bg, Color fg) => Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(no, style: _t(11, FontWeight.w800, fg.withValues(alpha: .7), 1.2)),
          const SizedBox(height: 4),
          Text(title, style: _t(13.5, FontWeight.w800, fg, 1.25)),
          const SizedBox(height: 4),
          Text(who, style: _t(12, FontWeight.w500, fg.withValues(alpha: .8), 1.35)),
        ],
      ),
    );
    final arrow = Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.faint),
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 8,
      children: [
        step('1', 'Mengajukan', 'mis. Gudang membuat PO', AppColors.sunken, AppColors.ink),
        arrow,
        step('2', 'Menyetujui tingkat 1', 'mis. Manager outlet memeriksa', AppColors.ink, Colors.white),
        arrow,
        step('3', 'Menyetujui akhir', 'mis. Owner memutuskan', AppColors.primary, Colors.white),
        arrow,
        step('✓', 'Berlaku', 'PO terkirim, supplier / bahan / pajak aktif', AppColors.sageSoft, AppColors.sageInk),
      ],
    );
  }
}
