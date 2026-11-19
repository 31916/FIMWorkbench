# FIM Workbench

Simulinkモデルの配線と演算ブロックを調べ、選んだ箇所に故障を組み込んだコピーを生成します。設定画面では故障ごとに種類、ON/OFF、値、開始・終了時刻を編集できます。複数箇所へ同時に注入でき、同じ信号に対する複数の変換も設定できます。

## FIMとの関係

FIM Workbenchは、Ezio Bartocci、Leonardo Mariani、Dejan Ničković、Drishti Yadavによる **FIM（Fault Injection and Mutation for Simulink）** の故障定義を採用した独立のMATLABアドオンです。これらの故障をSimulinkの標準ブロックで生成し、注入箇所の探索、設定画面、保存をWorkbench側で実装しています。配布アドオンと対象モデルが使うMathWorks製品で実行できます。[FIMの原著論文（ESEC/FSE 2022）](https://doi.org/10.1145/3540250.3558932)・[著者によるFIMの実装](https://gitlab.com/DrishtiYadav/fimtool/-/tree/a110acf2b718eab4cdf65f938203f60009fa0510)

FIMが定義する**全15種類**（信号故障10種類、演算子置換5種類）を実装しています。さらにWorkbench独自の `gain` と `stuck_at` を加えた計17種類を指定できます。FIMでいう「Stuck-at」は故障直前の値を保持する `hold_last` です。[FIMの故障・演算子の定義](https://gitlab.com/DrishtiYadav/fimtool/-/blob/a110acf2b718eab4cdf65f938203f60009fa0510/FaultInjector_Master/Readme.txt)

## インストールして使う

1. `FIMWorkbench-2.1.0.mltbx` をダウンロードし、MATLABの「ファイル」パネルでダブルクリックして「インストール」を選びます。[v2.1.0 のインストーラー](https://github.com/31916/FIMWorkbench/releases/download/v2.1.0/FIMWorkbench-2.1.0.mltbx)
2. 「アプリ」タブの `FIMWorkbench` を開きます。コマンドウィンドウに `FIMWorkbench` と入力しても同じ画面が開きます。
3. 同梱モデルは、一覧から `AT` などを選び「ベンチマークを開く」を押します。自分のモデルは、普段使うSimulinkプロジェクトや初期化スクリプトを開いた状態で「元モデル」と新しい「作業用コピー」の保存先を指定し、「作業用コピーを作成」を押します。対応する各箇所に1つずつ、初期状態がOFFの故障を設定します。
4. 故障設定画面で種類・ON/OFF・値・時間を選び、Simulinkの「実行」を押します。「モデルを保存」で変更を保存します。同梱モデルは同じ一覧から、自分のコピーは「保存したコピーを開く」から再開できます。

必要な環境はMATLABとSimulinkです。Stateflow、Deep Learning Toolboxなど、モデルが使う追加製品も必要です。パッケージの対象はR2026a以降、検証環境はLinux版R2026aです。インストール先に日本語を含む場合、SBモデルの学習済み重みはMATLABセッション用の一時コピーから読み込みます。削除する場合はMATLABの「アドオン」で「FIM Workbench」を選び、アンインストールします。編集したモデルは各利用者の作業フォルダに保存されます。[MathWorksのインストール手順](https://www.mathworks.com/help/matlab/matlab_env/get-add-ons.html)

## ソースから起動・ビルドする

このリポジトリをクローンし、MATLABの現在のフォルダをリポジトリのルートにします。`FIMWorkbench` を実行すると起動画面が開きます。インストーラーを作る場合は次の2行を実行します。

~~~matlab
addpath(fullfile(pwd,'packaging'))
installer = build_fimworkbench_toolbox(fullfile(pwd,'dist'))
~~~

`dist/` に生成された `.mltbx` を他の利用者に渡せます。配布版のソースはGitタグ `v2.1.0` で取得できます。

旧版からの更新も同じ手順です。保存済みモデルは「保存したコピーを開く」から再開できます。**新しい種類・箇所を使うときは、元モデルから別名で作業用コピーを生成**してください。同梱のAFCで新しい故障枠を試すには、AFCの作業用モデルを閉じ、`fimwb.openBenchmark('AFC',fullfile(pwd,'AFC_2_1'))` で新しいフォルダを指定します。1.0.0用のスクリプトでは起動コマンドを `FIMWorkbench`、関数の接頭辞を `fimwb.` に変更します。

## テスト済みモデルを開く

インストール後は任意の作業フォルダで実行できます。ソースZIPから使う場合は、このREADMEがあるフォルダをMATLABの現在のフォルダにします。

~~~matlab
[window, file] = fimwb.openBenchmark('AT');
open_system(file)
~~~

ATの場合は101箇所のチェックボックスが開きます。例えば、箇所「E106_1__51_inport2」はスロットルからエンジンに入る枝です。故障に「bias」、値に「1」を指定してONにすると、この枝でスロットルの値に1を加えます。開始を5、終了を10にすれば、5秒以上10秒未満だけ適用します。Simulinkの実行ボタンで動作を確認できます。

「モデルを保存」で作業用コピーに保存します。新しいモデルは全箇所OFFで開き、保存済みのコピーでは前回の設定を読み込みます。ATの既定の保存先はMATLABの個人フォルダ（`userpath`）の `FIMWorkbench/AT/` です。`userpath` が空の環境では `prefdir` を使います。上の `file` は実際の保存先のフルパスです。作業先は第2引数で指定できます。旧ZIPの `work/AT/` に作業用モデルを保存済みの場合は、そのフォルダを指定すれば引き継げます。モデル名には `AT`、`AFC`、`NN`、`CC`、`SC`、`PM`、`F16`、`SB1`～`SB5` を指定できます。各行の故障の適用条件は、その箇所の信号型・実行周期・ブロック種別に従います。

## 自分のモデルと故障の組み合わせ

対象の `.mdl` または `.slx` が通常どおりコンパイルできるように、モデルの初期化スクリプトやデータ辞書、参照ライブラリを準備します。`scan` の `id` を設定ファイルの `site` に使います。`source` と `destinations` で元の配線を、`faults` と `reason` で適用可能な故障と対象外の理由を確認できます。モデルの構造が変わったときは再度スキャンします。

~~~matlab
tool = fileparts(which('FIMWorkbench'));
addpath(tool, fullfile(tool,'verification','sources','at_data'))
src = fullfile(tool,'verification','sources','ARCH','transmission','Autotrans_shift.mdl');
sites = fimwb.scan(src);
list = struct2table(sites,'AsArray',true);
disp(list(:,{'id','kind','source','dataType','reason'}))

out = fullfile(pwd,'work');
if ~isfolder(out), mkdir(out); end
file = fullfile(out,'my_at.mdl');
fimwb.build(src,fullfile(tool,'examples','at-combination.json'),file)
fimwb.editor(file)
~~~

同じ箇所を複数行に指定すると**記載順**に適用します。例えば下の2行をともにONにすると、出力は `(入力 + 1) × 1.25` になります。別の `site` を追加すれば各箇所で同時に働きます。分岐前の共通信号に加えた変化は各枝へ伝わり、枝固有の故障はその後に適用されます。演算ブロックには1つの置換枠があり、その種類と演算子を切り替えられます。

~~~json
{
  "faults": [
    {"site":"E106_1__51_inport2","type":"bias","enabled":true,"value":1},
    {"site":"E106_1__51_inport2","type":"gain","enabled":false,"value":1.25}
  ]
}
~~~

`build` の出力には新しいファイル名を指定します。生成後はMATLABから個別に変更することもできます。下の `2` は設定ファイルの2行目の番号です。

~~~matlab
load_system(file)
fimwb.setFault('my_at',2,struct('enabled',true,'value',1.5))
fimwb.setFault('my_at',1,struct('start',2,'stop',5))
save_system('my_at')
~~~

## 適用可能な全箇所へ自動生成する

故障ごとの値を配列で指定すると、箇所と値の組み合わせを自動列挙します。`plan` は設定を返し、`sweep` は各設定を1つずつ適用したモデルを生成してコンパイルします。`sweep` の第4引数で生成する設定番号を絞れます。全件を生成する呼び出しは次のとおりです。

~~~matlab
profiles = fullfile(tool,'examples','profiles.json');
[cases, excluded] = fimwb.plan(src,profiles);
results = fimwb.sweep(src,profiles,fullfile(out,'sweep'));
~~~

モデル、設定JSON、チェックサムは設定ごとのフォルダに保存します。再実行時は照合済みのモデルを再利用し、結果行に `compiled`、`reused`、または `failed` と理由を残します。複数故障をまとめる場合は、選んだ設定を `fimwb.build(src,struct('faults',cases([i,j])),newFile)` へ渡せます。個別モデルと全箇所モデルは、どちらも `fimwb.editor` で開けます。

## 指定できる故障

| FIMでの名称 | 設定の `type` | 動作・値 |
|---|---|---|
| Negate | `negate` | 符号を反転 |
| Invert | `invert` | 0なら1、非ゼロなら0 |
| Stuck-at 0 | `zero` | 0に固定 |
| Absolute | `absolute` | 絶対値を出力 |
| Noise | `noise` | 帯域制限付きホワイトノイズを加算。`value` はパワー、`period` は標本周期（秒）、`seed` は乱数のシード |
| Bias/Offset | `bias` | 指定した正または負の値を加算 |
| Stuck-at | `hold_last` | 開始直前の値を保持。時刻0から有効なら初期値は `value`。連続系では直前のソルバーの主要ステップの値 |
| Time Delay | `delay` | 指定秒数の遅延。初期出力は0。離散信号では元の周期の整数倍 |
| Bit Flip | `bit_flip` | ブール信号の真偽を反転 |
| Package Drop | `package_drop` | 指定した値で出力を置換 |
| ROR | `ror` | 比較演算子を `>`、`<`、`<=`、`>=`、`==`、`~=` から選択 |
| LOR | `lor` | 論理演算子を `AND`、`OR`、`NAND`、`NOR`、`XOR`、`NXOR`（排他的論理和の否定）から選択 |
| S2P | `s2p` | 和を積に置換 |
| P2S | `p2s` | 積を和に置換 |
| ASR | `asr` | 入力ごとの符号を置換。2入力では `+-`、`--`、`++`、`-+` |

JSONやMATLABでは表のFIM名をそのまま `type` に指定できます。演算子は名前に加えて原版の番号でも指定できます。例えば `{"type":"LOR","value":6}` の置換先は `NXOR` です。番号は上表の並びの左から順に1から始まります。Workbench独自の `gain` は信号に指定の倍率を掛け、`stuck_at` は指定した値に固定します。

LORを試すには、AFCの故障設定画面で `O1688` の行を選び、画面下の置換先で `XOR` を選んで「ON」にします。JSONでは `{"site":"O1688","type":"lor","enabled":true,"value":"XOR","start":5,"stop":10}` で同じ箇所を5秒以上10秒未満だけ切り替えられます。画面には、その入力で使えて元の演算子と異なる置換先が表示されます。例えば1入力・スカラーの `NOT` は `AND` または `OR` に置換できます。1入力のベクトルを論理集約するブロックでは、出力形状を保てる置換を選べます。

有効期間の既定はシミュレーション開始から終了までです。`start` と `stop` は秒単位で、終了の空欄は期限なしです。一定の時間だけ注入するときは、終了に開始時刻と持続時間の和を指定します。整数へのバイアス・ゲインは32ビットまでの整数型で扱い、計算後に元の型へ丸めて飽和させます。実数ベクトルはバイアス・ゲインなどの要素ごとの変換に対応します。スキャンは現在アクティブなSimulink階層の配線を扱います。サブシステムの入出力、マスクやリンク内の編集可能な配線、分岐前、接続先ごとの枝を区別します。モデル参照先の内部を試す場合は、その参照モデルを入力に指定します。

## ARCH-COMPでの検証

検証対象はARCH-COMP 2026の反例探索部門です。8系統のうちSBを5モデルに展開した計12モデルです。PMは原著者が公開した単一LRL入力・PACE_COUNT出力の `Model1_Scenario1_Faulty` を比較元に使いました。SB1～SB5は大会向けに選定された5つのSimulinkモデルと対応する学習済み重みを使い、検証コピーでは著者環境の絶対パスを同梱した重みのファイル名に張り替えています。F16の公式実行入口はMATLABのODEなので、シミュレーションごとにODEを呼ぶSimulinkブロックを用い、その観測出力1箇所を検証しました。[2026年部門報告](https://easychair.org/publications/paper/DtZ3/open)・[公式モデル](https://gitlab.com/goranf/ARCH-COMP/-/tree/2238327987e2e3b81f9bcc38b2ad250013deba04/models/FALS)・[PMの配布元](https://github.com/3MD3/3MD3/blob/5a1688de66b1974f6f07362495ccc0cfba957124/Model1/Scenario1.m)・[大会用SBの配布元](https://github.com/lyudeyun/FalBenchGen_ARCHCOMP25/tree/4d4729f428780a8a01bc0173873506c8d71a9f38)

- **全箇所の設置確認**　抽出した967候補中、設定を保存・再コンパイルしても残る923箇所にそれぞれ独立した故障枠を設置しました。モデルごとに全枠を同時にOFFにし、規定時間の全出力と時刻列を元モデルと照合しました。制御用の接続など34箇所と、SBの予測ブロックが再生成する内部配線10箇所を対象外としました。各除外理由と、各箇所に割り当てた枠番号・モデルファイル名は `verification/all_sites/<モデル>/sites.csv` にあります。
- **ON時の波形確認**　各モデルで同一入力を使い、全OFF、バイアスのみ、ゲインのみ、2故障同時、数値変更、再び全OFFを検証しました。ネイティブSimulinkの11モデルでは内部の接続先だけへの注入と、内部・出力の同時注入も検証しました。比較は指定した故障変換式と時刻列に対して行っています。全105比較の最大絶対誤差は0でした。[モデル別の結果](verification/results.csv)
- **編集画面の確認**　12モデルそれぞれで作業用コピーを開き、故障種類の切替、チェックボックス、数値変更、入力エラーの取り消し、シミュレーション、保存後の再読込を確認しました。[画面操作の結果](verification/editor.csv)
- **設定の列挙**　同梱のプロファイルで12,957件の単一故障設定を列挙しました。各モデルの `fault_plan.csv` が設定の一覧、`verification/arch2026/<モデル>/traces.mat` が代表設定で実際に比較した波形です。
- **論理演算子の置換**　12モデルのうち、AFCの5箇所で計22通りのLORを適用できました。各設定を編集画面からONにして実行し、元のSimulinkブロックを直接置換した参照モデルと比較しました。置換箇所の出力112,200点とモデル出力1,072,588点はすべて一致しました。[LORの全設定と比較結果](verification/lor.csv)
- **故障別の確認**　合成モデルでFIMの15種類とWorkbench独自の2種類を検証しました。LORは6演算子を2入力の全真理値で、RORは6演算子を、ASRは2入力の4符号列を検証しました。故障の併用、時間窓、配列信号も含む53比較の最大絶対誤差は、単精度のノイズ強度試験の約4.77×10⁻⁷でした。[故障別の結果](verification/fault_types/results.csv)

検証環境はLinux上のMATLAB R2026a・Simulinkです。Stateflow、Deep Learning Toolboxなど、各ベンチマークが使う製品も必要です。F16には本プロジェクトのR2026a互換処理を使用します。モデルを一から再取得する場合は、シェルで `python3 benchmarks/fetch_sources.py --project /path/to/project` を実行します。取得元のコミットとSHA-256を固定してあり、付属済みのファイルは同じコマンドで照合できます。

新しい保存先で再試験するには、MATLABで `addpath(fullfile(fileparts(which('FIMWorkbench')),'benchmarks'))` を実行し、`run_arch_suite(新しい保存先)` で代表設定、`check_all_sites(新しい保存先)` で全箇所の設置と全OFF、`test_fault_types(新しい保存先)` で故障の種類と順序を検証できます。`verify_arch_lor(出力CSVのパス)` は各LOR設定を元のブロックを直接変更したモデルと照合します。各試験には別々の保存先を指定します。
