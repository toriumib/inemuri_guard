$ErrorActionPreference = 'Stop'
$promoOut = Join-Path $PSScriptRoot '../store_assets/promo_detection'
$promoVoice = New-Object -ComObject SAPI.SpVoice
foreach ($promoLanguage in @('ja','en')) {
    $promoVoiceName = if ($promoLanguage -eq 'ja') { 'Haruka' } else { 'Zira' }
    $promoVoice.Voice = @($promoVoice.GetVoices() | Where-Object { $_.GetDescription().Contains($promoVoiceName) })[0]
    $promoVoice.Rate = 1
    $promoSpeech = if ($promoLanguage -eq 'ja') {
        'カメラで居眠りを検知して、音や振動でお知らせ。ウェブとアンドロイドで使える、居眠りガード。パソコン作業中、勉強中、気づいたら目を閉じてた。そんなあなたのためのアプリです。まぶたが閉じ続けるとアラート。何秒で知らせるかも、自分に合わせて調整できます。会社や電車では、振動やイヤホンを活用。音の出る場所は、使う前に確認を。まずは、居眠りガードで検索。'
    } else {
        'Camera-based drowsiness alerts, on the web and Android. Meet Drowsiness Guard. Working at your computer, studying, and suddenly your eyes drift shut? This app is for you. When your eyes stay closed, it alerts you with sound or vibration. Choose how many seconds to wait. At the office or on the train, try vibration or earphones. Always check where the sound plays before you start. Try Drowsiness Guard today.'
    }
    $promoWav = Join-Path $promoOut "narration-$promoLanguage.wav"
    $promoStream = New-Object -ComObject SAPI.SpFileStream
    $promoStream.Open($promoWav,3)
    $promoVoice.AudioOutputStream = $promoStream
    [void]$promoVoice.Speak($promoSpeech)
    $promoStream.Close()
    & ffmpeg -y -v error -i (Join-Path $promoOut "detection-demo-$promoLanguage.mp4") -i $promoWav -map 0:v -map 1:a -af 'apad' -t 30 -c:v copy -c:a aac -movflags +faststart (Join-Path $promoOut "detection-demo-voiced-$promoLanguage.mp4")
    if ($LASTEXITCODE -ne 0) { throw 'Narration mux failed' }
}
