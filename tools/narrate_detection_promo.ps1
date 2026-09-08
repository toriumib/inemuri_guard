$ErrorActionPreference = 'Stop'
$promoOut = Join-Path $PSScriptRoot '../store_assets/promo_detection'
$promoVoice = New-Object -ComObject SAPI.SpVoice
foreach ($promoLanguage in @('ja','en')) {
    $promoVoiceName = if ($promoLanguage -eq 'ja') { 'Haruka' } else { 'Zira' }
    $promoVoice.Voice = @($promoVoice.GetVoices() | Where-Object { $_.GetDescription().Contains($promoVoiceName) })[0]
    $promoVoice.Rate = 1
    $promoSpeech = if ($promoLanguage -eq 'ja') {
        'カメラで居眠りの兆候を検知。音や振動でお知らせ。居眠りガードです。これは、AIで作った架空の顔を、実際のウェブアプリに入力した映像。目を閉じた時間を数えて、アラートが出ます。スマホ幅のウェブ表示と、アンドロイドの秒数設定も紹介。眠いときは、無理せず休憩を。'
    } else {
        'Eyes closing at your desk? Drowsiness Guard uses your camera to detect prolonged eye closure and alert you. This fictional AI face is fed into the real web app. Watch the timer, then the alert. We also show a phone-sized web view and Android timing settings. This is a software demonstration, not proof of sleep detection accuracy. If you feel sleepy, take a break.'
    }
    $promoWav = Join-Path $promoOut "narration-$promoLanguage.wav"
    $promoStream = New-Object -ComObject SAPI.SpFileStream
    $promoStream.Open($promoWav,3)
    $promoVoice.AudioOutputStream = $promoStream
    [void]$promoVoice.Speak($promoSpeech)
    $promoStream.Close()
    & ffmpeg -y -v error -i (Join-Path $promoOut "detection-demo-$promoLanguage.mp4") -i $promoWav -map 0:v -map 1:a -af 'apad' -t 28 -c:v copy -c:a aac -movflags +faststart (Join-Path $promoOut "detection-demo-voiced-$promoLanguage.mp4")
    if ($LASTEXITCODE -ne 0) { throw 'Narration mux failed' }
}
