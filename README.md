# 名刺をLaTeXで作成

名刺をLaTeXで作成するためのテンプレート一式です。

## 使い方

### 基本的な作業手順

1. `cd namecard`などで、namecardディレクトリをカレントディレクトリにします
1. namecard.texを編集し、保存します
1. `make`を実行します。namecard.pdfというPDFファイルが作成されます
1. PDFファイルを印刷します。印刷時、100%のサイズで印刷するようにしてください。Macでプレビューから印刷する場合、「プリント」ダイアログの「サイズ調整」を選択してフィールドに「100%」を入力します。


### namecard.texの編集について

namecard.texの編集に際しては、次の点に考慮します。

* 印刷用紙。初期設定では、エーワン株式会社の「マルチカード」、品番「51865」にあわせて設定しています。
* 名刺の内容とレイアウト

#### 印刷用紙にあわせた設定
印刷用紙にあわせて、左右と上下の余白を設定します。`\oddsidemargin`で左側の余白、`\topmargin`で上側の余白、`\textwidth`で本文領域の幅、`\textheight`で本文領域の高さを設定します。
これ以外の余白サイズはすべて0に設定しています（左マージン、上マージンで初期設定されている1インチの余白を`hoffset`と`voffset`の設定で無効化）。なお、私が実際に印刷したときに左余白が4mmずれていたので、それを補正する設定もしています。

#### 名刺の内容とレイアウト
LaTeXのpicture環境を使って名刺の内容を記述しています。picture環境については、[KUMAZAWA Yoshikiさんのサイトの説明](http://www.biwako.shiga-u.ac.jp/sensei/kumazawa/tex/picture.html "picture 環境")などを参考にしてください。picture環境では、`\put`文で文字列を挿入しています。ロゴなどの画像も挿入可能です。また、印刷時の配置を確認するときには、枠線を挿入するとわかりやすいです。

