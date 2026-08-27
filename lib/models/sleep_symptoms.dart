/// Widely-published warning signs that accompany daytime sleepiness, and the
/// conditions a clinician would consider when they appear.
///
/// ⚠️ IMPORTANT — this is deliberately NOT a screening instrument.
///
/// It is not the Epworth Sleepiness Scale, STOP-BANG, or any other validated
/// questionnaire (those are copyrighted and require licensing anyway). There
/// is no score, no cut-off, and no verdict. Each item exists so the user can
/// (a) recognise a symptom worth mentioning and (b) walk into an appointment
/// able to describe it. `related` names conditions that are *associated with*
/// the symptom in the literature — never a conclusion about this user.
class SleepSymptom {
  final String id;
  final String label;
  final String detail;

  /// Conditions a doctor may want to rule out when this symptom is present.
  final List<String> related;

  /// Symptoms that warrant prompt medical advice on their own, regardless of
  /// how many others are ticked.
  final bool urgent;

  const SleepSymptom({
    required this.id,
    required this.label,
    required this.detail,
    required this.related,
    this.urgent = false,
  });
}

const sleepSymptoms = <SleepSymptom>[
  SleepSymptom(
    id: 'driving',
    label: '運転中に眠くなった／ヒヤリとしたことがある',
    detail: '居眠り運転は命に関わります。眠気の原因がはっきりするまで運転は控えてください。',
    related: ['早めの受診が必要'],
    urgent: true,
  ),
  SleepSymptom(
    id: 'snore_stop',
    label: 'いびきが大きい／寝ている間に呼吸が止まると言われた',
    detail: '同居している人からの指摘は重要な情報です。診察時に伝えてください。',
    related: ['睡眠時無呼吸症候群'],
  ),
  SleepSymptom(
    id: 'morning_headache',
    label: '朝起きたときに頭痛や口の渇きがある',
    detail: '夜間に呼吸が浅くなっているときに出やすい症状です。',
    related: ['睡眠時無呼吸症候群'],
  ),
  SleepSymptom(
    id: 'cataplexy',
    label: '笑ったり驚いたりすると体の力が抜ける',
    detail: '感情が動いたときに膝が崩れる、あごの力が抜けるなど。情動脱力発作と呼ばれます。',
    related: ['ナルコレプシー'],
  ),
  SleepSymptom(
    id: 'sleep_paralysis',
    label: '金縛りや、寝入りばな・起き際の幻覚がある',
    detail: '意識はあるのに体が動かない、実在しないものが見える・聞こえるなど。',
    related: ['ナルコレプシー'],
  ),
  SleepSymptom(
    id: 'sleep_attack',
    label: '突然、抗えない強い眠気に襲われる',
    detail: '会話中や食事中など、通常なら眠らない場面でも眠ってしまう場合。',
    related: ['ナルコレプシー', '特発性過眠症'],
  ),
  SleepSymptom(
    id: 'thirst_urine',
    label: 'のどが異常に渇く／トイレが近い／体重が減った',
    detail: '眠気とあわせて出ることがある全身症状です。',
    related: ['糖尿病'],
  ),
  SleepSymptom(
    id: 'fatigue_cold',
    label: '十分寝てもだるい／寒がりになった／むくみがある',
    detail: '睡眠の問題ではなく、代謝や血液の状態が背景にあることがあります。',
    related: ['甲状腺機能低下症', '貧血'],
  ),
  SleepSymptom(
    id: 'restless_legs',
    label: '脚がむずむずして寝つけない',
    detail: 'じっとしていると脚に不快感が出て、動かすと楽になるのが特徴です。',
    related: ['レストレスレッグス症候群'],
  ),
];
