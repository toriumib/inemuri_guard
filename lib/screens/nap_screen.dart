import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/alarm_service.dart';
import '../services/nap_timer_service.dart';
import '../services/sleep_log_service.dart';
import '../services/stats_service.dart';
import '../services/support_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pomodoro_card.dart';
import '../widgets/ring_timer.dart';

/// What each nap length did in Brooks & Lack (2006) — the study that compared
/// 5 / 10 / 20 / 30-minute naps against a no-nap control in the same subjects.
/// Shown per-preset so the choice is informed rather than arbitrary.
const _napEvidence = {
  5: '効果はごくわずか',
  10: '直後から効く',
  20: '効果は約35分後',
  30: '寝ぼけが出やすい',
};

class NapScreen extends StatefulWidget {
  const NapScreen({super.key});

  @override
  State<NapScreen> createState() => _NapScreenState();
}

class _NapScreenState extends State<NapScreen> {
  NapPhase _prevPhase = NapPhase.idle;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final nap = context.watch<NapTimerService>();
    final alarm = context.read<AlarmService>();
    final stats = context.read<StatsService>();
    final sleepLog = context.read<SleepLogService>();

    if (nap.phase == NapPhase.done && _prevPhase != NapPhase.done) {
      final minutes = nap.minutes;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        alarm.start();
        final crossedLine = await stats.bumpNap(minutes);
        await sleepLog.add(SleepEventType.nap, note: '$minutes分');
        if (context.mounted) {
          _showNapAnimalReveal(context, minutes);
        }
        if (crossedLine && context.mounted) {
          _showShortSleeperEasterEgg(context);
        }
        // Ask for a review only after the app has actually delivered value a
        // few times — asking earlier just earns one-star ratings.
        if (stats.napsAllTime == 3 || stats.napsAllTime == 12) {
          await SupportService.requestInAppReview();
        }
      });
    } else if (nap.phase != NapPhase.done && _prevPhase == NapPhase.done) {
      WidgetsBinding.instance.addPostFrameCallback((_) => alarm.stop());
    }
    _prevPhase = nap.phase;

    final nearEnd = nap.phase == NapPhase.running && nap.fraction <= 0.1;
    final ringColor = nearEnd ? c.accentAlert : c.accentNap;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'パワーナップタイマー',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '眠気を我慢するより短く区切って眠るほうが、日中の眠気と作業成績が回復しやすいと報告されています。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: SizedBox(
                      width: 200,
                      height: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(200, 200),
                            painter: RingTimerPainter(
                              fraction: nap.fraction,
                              trackColor: c.surface2,
                              progressColor: ringColor,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                nap.formatted,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 48,
                                ),
                              ),
                              Text(
                                nap.phase == NapPhase.done
                                    ? '起きる時間です'
                                    : (nap.phase == NapPhase.running
                                          ? '残り時間'
                                          : '仮眠時間'),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  for (final m in NapTimerService.presets)
                    _NapPresetRow(
                      minutes: m,
                      evidence: _napEvidence[m] ?? '',
                      recommended: m == NapTimerService.recommendedMinutes,
                      selected:
                          nap.minutes == m && nap.phase != NapPhase.running,
                      enabled: nap.phase != NapPhase.running,
                      onTap: () => nap.selectPreset(m),
                    ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: c.accentAlert,
                            foregroundColor: c.accentAlertInk,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: nap.phase == NapPhase.running
                              ? null
                              : () {
                                  alarm.stop();
                                  nap.start();
                                },
                          child: const Text('仮眠を開始'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed:
                              nap.phase == NapPhase.running ||
                                  nap.phase == NapPhase.done
                              ? () {
                                  alarm.stop();
                                  nap.cancel();
                                }
                              : null,
                          child: const Text('キャンセル'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const PomodoroCard(),
          const SizedBox(height: 16),
          const _EvidenceCard(),
        ],
      ),
    );
  }
}

class _NapPresetRow extends StatelessWidget {
  final int minutes;
  final String evidence;
  final bool recommended;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _NapPresetRow({
    required this.minutes,
    required this.evidence,
    required this.recommended,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? c.accentNap : c.surface2,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 46,
                    child: Text(
                      '$minutes分',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: selected ? c.accentNapInk : c.text,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      evidence,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: selected
                            ? c.accentNapInk.withValues(alpha: 0.85)
                            : c.textDim,
                      ),
                    ),
                  ),
                  if (recommended) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? c.accentNapInk.withValues(alpha: 0.2)
                            : c.accentGood.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'おすすめ',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: selected ? c.accentNapInk : c.accentGood,
                        ),
                      ),
                    ),
                  ],
                  if (selected) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.check, size: 18, color: c.accentNapInk),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The evidence behind the numbers above, cited so it can be checked rather
/// than taken on faith. Deliberately states the limits of each finding.
class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final body = Theme.of(context).textTheme.bodyMedium;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science_outlined, size: 18, color: c.accentGood),
                const SizedBox(width: 6),
                Text('根拠にした研究', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            _Finding(
              title: '10分がもっとも効率が良かった',
              body:
                  '5・10・20・30分の仮眠を同じ参加者で比較した実験では、10分の仮眠だけが'
                  '起きた直後から眠気・疲労感・認知課題の成績すべてで改善を示し、'
                  'その効果は最大155分続きました。5分では効果がほとんど確認されず、'
                  '20分では効果が出るまで約35分かかり、30分では起床直後に'
                  '一時的な能力低下（睡眠慣性＝寝ぼけ）が見られました。',
              source:
                  'Brooks A, Lack L. "A Brief Afternoon Nap Following Nocturnal '
                  'Sleep Restriction: Which Nap Duration is Most Recuperative?" '
                  'SLEEP. 2006;29(6):831-840.',
            ),
            Divider(height: 26, color: c.border),
            _Finding(
              title: '長い仮眠ほど「寝ぼけ」が残りやすい',
              body:
                  '起床直後に判断力や反応が一時的に落ちる睡眠慣性は、深い睡眠段階に'
                  '入ってから起きるほど強く出ます。仕事の合間に取る仮眠を短く'
                  '区切るのは、この寝ぼけを避けるためです。',
              source:
                  'Hilditch CJ, McHill AW. "Sleep inertia: current insights." '
                  'Nature and Science of Sleep. 2019;11:155-165.',
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.border),
              ),
              child: Text(
                '注意：これらは少人数の健康な成人を対象にした実験結果で、'
                '効果の出かたには個人差があります。仮眠は睡眠不足の代わりにはならず、'
                '夜の睡眠時間を削る理由にはできません。'
                '日中の強い眠気が続く場合は、睡眠時無呼吸症候群などが隠れていることも'
                'あるため医療機関にご相談ください。',
                style: body?.copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Finding extends StatelessWidget {
  final String title;
  final String body;
  final String source;
  const _Finding({
    required this.title,
    required this.body,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(body, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 6),
        Text(
          source,
          style: TextStyle(
            fontSize: 11,
            height: 1.5,
            color: c.textDim,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _NapAnimal {
  final String emoji;
  final String name;
  final String comment;
  const _NapAnimal(this.emoji, this.name, this.comment);
}

const _napAnimals = {
  5: _NapAnimal('🐹', 'ハムスター', 'ちょこっと仮眠、おつかれさま'),
  10: _NapAnimal('🐿️', 'リス', 'ちょうどいい長さ！'),
  20: _NapAnimal('🦦', 'カワウソ', 'そろそろ効いてくるよ'),
  30: _NapAnimal('🐨', 'コアラ', 'ちょっと寝ぼけるかも'),
};

/// Small, non-blocking reveal after every nap — just for fun, not a feature
/// anyone depends on.
void _showNapAnimalReveal(BuildContext context, int minutes) {
  final animal =
      _napAnimals[minutes] ?? const _NapAnimal('😴', 'いきもの', 'おつかれさま');
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('${animal.emoji} ${animal.name}登場！ ${animal.comment}'),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// A little joke, not a feature: cross 30 minutes of naps in one day and
/// クイヤ shows up. クイヤ is a running internet gag from a 『ダウンタウンの
/// ガキの使いやあらへんで！』クイズ企画 — asked "9が嫌いな動物は？"
/// (正解は「9(く)を好かん」＝スカンク)、松本人志さんが即興で「クイヤ、
/// しっぽもある」と押し通したのが元ネタ。実在しない完全な架空の動物で、
/// ネット上の「生態」もぜんぶ後付けのフェイク。ここでは「1日30分睡眠」
/// ショートスリーパー系チャレンジへの軽いツッコミ役として拝借している。
void _showShortSleeperEasterEgg(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('🦄 クイヤより'),
      content: const Text(
        '今日の仮眠、合計30分こえたね。\n\n'
        '（ちなみに自分は『ガキの使い』のクイズで松本人志さんがとっさに作った、'
        '実在しない架空の動物です。しっぽはあるけど9が嫌いなだけで他に特技はありません）\n\n'
        '本題：「1日30分睡眠」のショートスリーパー系チャレンジは、体質が特殊な'
        'ごく一部の人の話で、医学的に誰でも真似できるものじゃないよ。\n\n'
        'このアプリは「起きるための仮眠」用。寝不足を仮眠だけで帳消しにしようとせず、'
        '夜はちゃんと寝てね。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('了解'),
        ),
      ],
    ),
  );
}
