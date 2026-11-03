# dotfiles

[chezmoi](https://www.chezmoi.io/) で管理している個人の dotfiles。複数のマシンで共通設定(vim / shell / git など)を同期しつつ、マシン固有の設定はリポジトリ外に分離している。

- **公開リポジトリ**。秘密情報(SSH 鍵など)は一切コミットしない。
- 秘密の個人鍵は **Bitwarden** から復元する。
- `setup.sh` でゼロからの再現(macOS / Linux)と、バージョン差分の検知ができる。

## 構成

| 要素 | 役割 |
| --- | --- |
| `.chezmoiroot` → `home` | chezmoi のソースは `home/` 配下 |
| `home/` | 管理対象の dotfiles(`dot_zshrc` などの chezmoi 命名規則) |
| `setup.sh` | ブートストラップ/ツール導入/鍵復元/バージョン診断 |
| `versions.lock` | 管理ツールのバージョン基準(ドリフト検知の比較元) |

chezmoi 本体の設定(`~/.config/chezmoi/chezmoi.toml`)は各マシンにローカルで生成され、**リポジトリには含めない**。`email` と `work`(仕事用のマシンか)を保持する。

## 新しいマシンでのセットアップ

```sh
git clone https://github.com/rn404/dotfiles.git ~/Works/rn404/dotfiles
cd ~/Works/rn404/dotfiles

# 共通セットアップ一式(Homebrew/apt → dotfiles 反映 → CLI ツール導入)
./setup.sh all

# 個人 SSH 鍵も一緒に復元する場合(Bitwarden のアンロックが必要)
export BW_SESSION="$(bw unlock --raw)"
./setup.sh all --with-personal-key
```

鍵を用意する前でも取得できるよう、最初は HTTPS で clone する。このマシンから push するときは `git remote set-url origin git@github.com:rn404/dotfiles.git` で切り替える。

## chezmoi 基本コマンド

**ソース(このリポジトリの `home/`)が正本**。実ファイル(`~/.zshrc` 等)は展開された結果と考える。

| コマンド | 役割 |
| --- | --- |
| `chezmoi edit ~/.zshrc` | ソースを編集(正本を直接いじる基本形) |
| `chezmoi edit --apply ~/.zshrc` | ソース編集 + 実ファイルへ反映を一括 |
| `chezmoi add ~/.zshrc` | 実ファイルの現状をソースへ取り込む(ツールが書き換えた設定の回収) |
| `chezmoi apply` | ソースの内容を実ファイルへ反映 |
| `chezmoi diff` | ソースと実ファイルの差分を表示(反映はしない) |
| `chezmoi status` | 差分を1文字コードで一覧(軽い点検) |
| `chezmoi verify` | 差分があれば非ゼロ終了(自動チェック向き) |
| `chezmoi unmanaged` | ホーム配下で未管理のファイルを洗い出す |
| `chezmoi update` | `git pull` + `apply` を一括(受け取り側で最新取得) |
| `chezmoi cd` | ソースディレクトリへ移動 |

## 日々の同期フロー

### 変更をリポジトリに取り込む(変更したマシン側)

```sh
# 実ファイルを編集したら、その差分を chezmoi のソースに取り込む
chezmoi add ~/.zshrc            # 変更したファイルを指定
chezmoi cd                      # ソースディレクトリへ

git add -A
git commit -m "Update zshrc"
git push
```

> 直接 `home/` 配下のソースを編集した場合は `chezmoi apply` で実ファイルへ反映する。

### 実ファイルが直接書き換わったとき(他ツールや Coding Agent)

gh / nvim などのツールや Coding Agent は、ソースを介さず**実ファイルを直接書き換える**。この状態でうっかり `chezmoi apply` すると、その変更が**ソースで上書きされて消える**(管理下ファイルの in-place ドリフト)。定期的に点検して回収する:

```sh
chezmoi status    # M が付いた管理下ファイル = 実ファイル側で変わっている
chezmoi diff      # 中身を確認

# 実ファイル側の変更を残したい → ソースへ取り込む
chezmoi add ~/.claude/CLAUDE.md
# ソース側を正としたい(実ファイルの変更を捨てる) → そのまま反映
chezmoi apply
```

> なお `chezmoi status`/`diff` は**管理下ファイル**の差分しか見ない。「そもそも未追加のファイル」は `chezmoi unmanaged` で洗い出す。

> `~/.claude/settings.json` はテンプレート(`private_settings.json.tmpl`)で、パスを `{{ .chezmoi.homeDir }}` に置き換えて公開している。`chezmoi add` で取り込まず、ソースを `chezmoi edit` で直す。Herdr のフックは `~/.claude/hooks/herdr-agent-state.sh` があるマシンでだけ有効になる。

### エージェント共通の指示

共通の指示は `~/.config/agents/AGENTS.md` を正本にする。Claude Code は `~/.claude/CLAUDE.md` の `@` で取り込み、Codex は `~/.codex/AGENTS.md` のシンボリックリンクで読む。Claude Code 専用の指示だけを `~/.claude/CLAUDE.md` に書く。

### 他マシンで最新を受け取る(受け取り側のマシン上で実行)

別のマシンに移り、そのマシン上で実行する。リモートのソースを取得して実ファイルへ反映する:

```sh
chezmoi update    # git pull + apply を一括で実行
```

いきなり反映せず、これから当たる差分を先に確認したいとき:

```sh
chezmoi git pull    # ソースだけ先に更新(apply はまだしない)
chezmoi diff        # これから反映される差分を表示
chezmoi apply       # 問題なければ反映
```

## バージョン差分(ドリフト)の検知

ツールのバージョンはハード固定しない方針だが、`versions.lock` を基準に**差異を検知**できる。

```sh
./setup.sh doctor            # 現在のバージョンを versions.lock と照合
./setup.sh doctor --record   # 現在のバージョンを新しい基準として記録
```

出力例:

```
  TOOL             CURRENT        EXPECTED       STATUS
  nvim             0.12.3         0.11.0         DRIFT
  fd               -              10.2.0         MISSING
  starship         1.24.0         1.24.0         ok
```

- `DRIFT` … 基準とバージョンが食い違う
- `MISSING` … 基準にあるがこのマシンに未インストール
- `untracked` … インストール済みだが基準に未記録

新バージョンで問題なければ `./setup.sh doctor --record` で基準を更新し、`versions.lock` を commit / push すれば全マシンの「あるべき版」が揃う。

## 秘密情報の扱い

| 種類 | 保管先 | 復元方法 |
| --- | --- | --- |
| 個人 SSH 鍵 (`id_ed25519`) | Bitwarden | `./setup.sh ssh-key`(要 `BW_SESSION`) |

- 公開鍵と `allowed_signers` はコミットせず、秘密鍵から**その場で再生成**する(`ssh-key` が実施)。

## マシン固有の設定

個人用と仕事用で切り替えたい設定など、共通の設定に含めないものは、リポジトリに載せず各マシンに直接置く。どちらも管理対象外なので、無くても問題ない。

- `~/.config/git/local.gitconfig`: git の追加設定。`.gitconfig` の末尾で読み込む
- `~/.config/zsh/conf.d/*.zsh`: シェルの追加設定。`.zshrc` が読み込む

## Neovim だけを使う

root 権限がないマシンや、シェルと git の設定を変えたくないマシンでは、Neovim と LazyVim の設定だけを入れられる。

```sh
git clone https://github.com/rn404/dotfiles.git ~/dotfiles
~/dotfiles/setup.sh nvim
```

ツールは mise で入れ、展開するのは `~/.config/nvim` だけ。`email` の設定も不要。Tree-sitter のパーサーをビルドするには C コンパイラが必要で、無くても編集はできる。`mise use -g` がグローバル設定を書き換えるので、`.config/mise/config.toml` を chezmoi で管理しているマシンでは使わない。

## `setup.sh` サブコマンド

```
./setup.sh all [--with-personal-key]   共通セットアップ一式(任意で個人鍵も復元)
./setup.sh homebrew                     Homebrew のみ導入(macOS)
./setup.sh dotfiles                     chezmoi 設定生成 + apply のみ
./setup.sh nvim                         Neovim と設定のみ(root 不要)
./setup.sh tools                        CLI ツールのみ導入
./setup.sh ssh-key                      Bitwarden から個人 SSH 鍵を復元
./setup.sh doctor [--record]            バージョン照合(--record で基準を再記録)
```

引数なしで実行すると usage を表示し、何も実行しない。macOS(Homebrew)と Linux(apt + 公式インストーラ)に対応。

## 出典

`~/.claude/skills/` 配下の一部は他者の成果物を利用している。更新確認しやすいよう、ソースは**無改変**で取り込んでいる(出典と本家を diff できる)。

| スキル | 出典 | ライセンス |
| --- | --- | --- |
| `cognitive-rhythm-writing` | [k16shikano/gist 67625f2a](https://gist.github.com/k16shikano/67625f2a7d96e3bbdfae8d571a936063) | Unlicense(パブリックドメイン) |
| `japanese-tech-writing` | [k16shikano/gist 67625f2a](https://gist.github.com/k16shikano/67625f2a7d96e3bbdfae8d571a936063) | Unlicense(パブリックドメイン) |

`cite-primary-sources` は自作。
