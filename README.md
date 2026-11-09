# dotfiles

Neovim（プラグインなしの最小構成）、WezTerm、Git、競プロ用スクリプトの設定です。macOS / Ubuntu / Windows（WSL2）で使えます。

## セットアップ（macOS / Ubuntu 共通）

```bash
git clone https://github.com/ritemosu/dotfiles.git ~/dotfiles
sh ~/dotfiles/cp/install.sh
```

`install.sh` が行うこと:

- Ubuntu の場合は `g++ clangd python3 pipx xclip` を apt で入れる
- `oj` がなければ `pipx install online-judge-tools`
- `~/.config/nvim` を `dotfiles/nvim/nvim` へのリンクにする（既存の設定は退避）
- `~/.config/wezterm` を `dotfiles/wezterm` へのリンクにする（既存の設定は退避。WSL では Windows 側へコピー）
- Git の共通設定を `~/.gitconfig` から include し、`~/.config/git/ignore` をリンクする
- `cp-build` `cpt` `cpnew` を `~/.local/bin` にリンクする
- `~/CP` に `compile_flags.txt` と `.clangd` を置く（clangd 用）
- `~/CP/atcoder` も `~/CP/ac-library` もなければ ACL を clone する
- `~/CP/CP_Library`（自作ライブラリ、private）を clone する（GitHub に SSH キーの登録が必要）

Neovim は 0.11 以上が必要です（`vim.lsp.config` を使っています）。Ubuntu の apt 版は古いことが多いので、公式の AppImage か tarball を使ってください。

## Windows でのセットアップ（WSL2）

競プロ環境は WSL2 の Ubuntu の中に作り、ターミナルは Windows Terminal を使います（WezTerm はスマート アプリ コントロールにブロックされることがあるため）。

1. PowerShell を管理者で開き、`wsl --install` を実行して再起動する。起動した Ubuntu でユーザー名とパスワードを決める
2. Ubuntu の中で次を実行する

   ```bash
   sudo apt update && sudo apt install -y git curl
   git clone https://github.com/ritemosu/dotfiles.git ~/dotfiles
   sh ~/dotfiles/cp/install.sh
   git config --global user.name "ritemosu"
   git config --global user.email "190578955+ritemosu@users.noreply.github.com"
   ```

3. Windows Terminal を開き直す。Ubuntu が開き、背景が透過した青い配色になる

`install.sh` は Windows Terminal の settings.json に `windows-terminal/settings.json` の内容をマージする（元のファイルは `settings.json.bak-*` として残る）。

| 操作 | キー |
| --- | --- |
| 新しいタブ / タブを閉じる | Alt+T / Alt+W |
| 左右に分割 / 上下に分割 / 分割を閉じる | Alt+Q / Alt+B / Alt+M |
| 分割した画面の移動 | Alt+H / J / K / L |
| 分割した画面の最大化切り替え | Alt+Z |
| コピー / 貼り付け | Alt+C / Alt+V |
| タブ切り替え | Alt+1〜9、Ctrl+Tab |
| 全画面 | Alt+F |

- クリップボードは win32yank、ブラウザは wslview で Windows 側と連携する
- 作業ファイルは `~/CP`（WSL 側）に置く。`/mnt/c` の下はビルドが遅い
- WezTerm を使える PC では、`install.sh` が WezTerm の設定も `%USERPROFILE%\.config\wezterm` にコピーする

## 競プロの流れ

```bash
cpnew https://atcoder.jp/contests/abc400   # URL をそのまま貼る（abc400 だけでも可）
cpnew https://atcoder.jp/contests/adt_all_20251106_1   # ADT も同じ
cpnew abc400 a b      # 問題を指定する場合
cd ~/CP/contests/abc400/a
nvim main.cpp
```

Neovim 内のキー:

| キー | 動作 |
| --- | --- |
| `Space t`（`F5`） | ビルドしてサンプル（`test/`）で `oj t` |
| `Space r`（`F6`） | ビルドして手入力で実行 |
| `Space s`（`F8`） | テストして提出（`cps`） |
| `q` | テスト画面を閉じる（終了後は結果の最終行にカーソルがある。`k` や `Ctrl-u` で上へスクロール） |
| `:P b` | 同じコンテストの b 問題に切り替え（保存してから移動、Tab 補完あり） |
| `Space n` / `Space p` | 次 / 前の問題へ |
| `Space l` | ライブラリ一覧を開く。文字を打って絞り込み、Tab で選んで Enter で `int main()` の直前に挿入 |
| `:tree_diameter` | ライブラリ名だけ打って Enter で挿入 |
| `:Lib seg uf` | 複数まとめて挿入 |
| `:%y` | ファイル全体をクリップボードへコピー（提出用） |
| `Ctrl-Space` | 補完を手動で開く（`.` `->` `::` の後は自動） |
| `Tab` / `Shift-Tab` | 補完候補の選択、`Ctrl-y` で確定 |
| `(` `[` `{` | 閉じ括弧も入れてカーソルを中に置く。`{}` の中で Enter を押すとブロックに展開、閉じ括弧を打つと飛び越える |

シェルからは `cpt` でビルドとサンプルテスト、`cpt -e 1e-6` で誤差ジャッジです。

## 提出

1. 最初に 1 回（と cookie の期限切れ時）: 普段のブラウザで AtCoder にログインし、開発者ツールの Application → Cookies → `atcoder.jp` から `REVEL_SESSION` の値をコピーして `atcoder-login` に貼る（`oj login` は Cloudflare で止まるので使わない）
2. 問題フォルダで `cps` を実行する。サンプルが全部通ったら `oj s` で C++23 (GCC 15.2.0)（ID 6017）として提出する。言語を変えるときは `CP_LANG=6116 cps` のように指定する
3. コンテスト外は提出フォームに CAPTCHA があり `oj s` が失敗する。そのときは `main.cpp` をクリップボードにコピーして問題ページを開くので、手で貼って提出する

## oj のパッチ

AtCoder のメモリ制限表記が `MB` から `MiB` に変わり、oj が `assert parsed_memory_limit` で落ちます。
`cp/patch-oj.py` が oj 本体を修正します（`install.sh` から自動で実行。oj を入れ直したら再実行）。

## ライブラリの扱い

- ACL: `#include <atcoder/all>` のまま書く。AtCoder はそのまま提出できる。他サイトでは `oj-bundle`（`pipx install online-judge-verify-helper`）で展開してから提出する。
- 自作ライブラリ: `~/CP/CP_Library` に 1 ファイル 1 ライブラリで置く（`main()` は書かない）。`:ファイル名`（`tree-diameter.hpp` なら `:tree_diameter`）か `Space l` で `int main()` の直前に貼り付ける。置いた直後から使える。`archive/` は除外
- ライブラリのファイルには `#include <bits/stdc++.h>` と `using namespace std;` を書いたままにしておく。ファイル単体でコンパイルや clangd のチェックができ、貼り付け時には重複分が自動で消える
- 貼り付け時、`#include <bits/stdc++.h>` や `using namespace std;` など、すでに書いてある行は重複させない。同じライブラリを 2 回貼ろうとすると `already inserted` になる
