import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Evidence-based habits for reducing daytime sleepiness.
///
/// Two things this screen is careful about:
///  * It leads with the honest caveat that sleep-hygiene advice *alone* has
///    not shown clinically meaningful benefit for insomnia in trials — CBT-I
///    is the guideline first-line treatment. Presenting tips as a cure would
///    misrepresent the evidence.
///  * Every claim carries its source so it can be checked.
class ImproveScreen extends StatelessWidget {
  const ImproveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '日中の眠気を減らす',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '研究で効果が確認されている習慣を、根拠つきで並べています。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.surface2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.border),
                  ),
                  child: Text(
                    'はじめに正直なところ：下の生活習慣（睡眠衛生）だけでは、'
                    '慢性的な不眠に対して臨床的に十分な改善は出ないことが'
                    '複数の研究で示されています。眠れない状態が続く場合は、'
                    '習慣の工夫にとどめず「不眠症の認知行動療法（CBT-I）」を'
                    '扱う医療機関に相談するのが近道です。',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _HabitCard(
          number: 1,
          title: '起きる時刻を毎日そろえる',
          body:
              '寝る時刻より「起きる時刻」を固定するほうが体内時計は安定します。'
              '休日の寝だめは時差ボケに近い状態を作り、月曜の眠気を強めます。',
          source:
              'AASM 臨床実践ガイドライン（Edinger JD, et al. J Clin Sleep Med. 2021;17(2):255-262）',
        ),
        const _HabitCard(
          number: 2,
          title: 'カフェインは就寝の約9時間前まで',
          body:
              'メタ解析では、カフェイン摂取により総睡眠時間が平均45分短くなり、'
              '寝つきも約9分遅くなりました。コーヒー1杯（約107mg）なら'
              '就寝の8.8時間前まで、というのが解析から示された目安です。'
              '23時に寝るなら14時ごろが最後の1杯になります。',
          source:
              'Gardiner C, et al. "The effect of caffeine on subsequent sleep: '
              'A systematic review and meta-analysis." Sleep Med Rev. 2023;69:101764.',
        ),
        const _HabitCard(
          number: 3,
          title: '朝、起きて1時間以内に光を浴びる',
          body:
              '朝の強い光は体内時計を前倒しし、夜の入眠を早めます。'
              '窓際で数分過ごす、通勤で一駅歩くなど、屋外の明るさに当たるのが確実です。',
          source: '体内時計への光の作用に基づく一般的な推奨（AASM ガイドラインの生活指導に含まれる）',
        ),
        const _HabitCard(
          number: 4,
          title: 'ベッドは「眠るため」だけに使う',
          body:
              'ベッドでスマホを見たり仕事をしたりすると、脳が寝床を覚醒の場所として'
              '学習します。眠れないまま20分以上経ったら一度ベッドを出る——'
              'これは刺激制御法と呼ばれ、CBT-I の中核をなす技法のひとつです。',
          source:
              'AASM 臨床実践ガイドライン（Edinger JD, et al. J Clin Sleep Med. 2021;17(2):255-262）',
        ),
        const _HabitCard(
          number: 5,
          title: '眠気は我慢せず10分の仮眠にする',
          body:
              '10分の仮眠は起きた直後から眠気・疲労感・認知課題の成績を改善し、'
              'その効果は最大155分続きました。眠気と戦い続けるより効率的です。'
              'ただし仮眠は睡眠不足の埋め合わせにはならず、夜の睡眠を削る理由にはできません。',
          source: 'Brooks A, Lack L. SLEEP. 2006;29(6):831-840.',
        ),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.psychology_outlined,
                      size: 18,
                      color: c.accentGood,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '不眠が続くなら CBT-I',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '不眠症の認知行動療法（CBT-I）は、米国睡眠医学会のガイドラインで'
                  '慢性不眠症の第一選択とされています。メタ解析では寝つきまでの時間が'
                  '約19分、夜中に目が覚めている時間が約26分短縮し、'
                  'その効果は治療終了後も持続しました。'
                  '睡眠薬と比べて効果は同等以上で、より長続きすると報告されています。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Trauer JM, et al. "Cognitive Behavioral Therapy for Chronic '
                  'Insomnia: A Systematic Review and Meta-analysis." '
                  'Ann Intern Med. 2015;163(3):191-204.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: c.textDim,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Text(
              'これらは一般的な健康情報で、個別の診断や治療の代わりにはなりません。'
              '効果の出かたには個人差があります。'
              '生活を整えても日中の眠気が続く場合、睡眠時無呼吸症候群など'
              '治療が必要な病気が隠れていることがあるため、医療機関にご相談ください。',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _HabitCard extends StatelessWidget {
  final int number;
  final String title;
  final String body;
  final String source;

  const _HabitCard({
    required this.number,
    required this.title,
    required this.body,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.accentGood.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      '$number',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: c.accentGood,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(body, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 7),
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
          ),
        ),
      ),
    );
  }
}
