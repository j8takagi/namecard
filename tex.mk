# tex.mk
# Copyright 2013, j8takagi.
# tex.mk is licensed under the MIT license.

# TEXTARGETS変数が設定されていない場合は、エラー終了
ifndef TEXTARGETS
  $(error "TEXTARGETS is not set.")
else
  $(foreach \
    f, $(TEXTARGETS), \
    $(if $(wildcard $(basename $f).tex),,$(error "$(basename $f).tex needed by $f is not exist.")) \
  )
endif

# DEBUGSH変数が設定されている場合は、デバッグ用にシェルコマンドの詳細が表示される
# 例: DEBUGSH=1 make
ifdef DEBUGSH
  SHELL := /bin/sh -x
endif

.PHONY: tex-warn tex-xbb tex-clean tex-xbb-clean tex-distclean

######################################################################
# シェルコマンドの定義
######################################################################
# TeX commands
TEX := platex
DVIPDFMX := dvipdfmx
EXTRACTBB := extractbb
BIBTEX := pbibtex
MENDEX := mendex
KPSEWHICH := kpsewhich

# TeX command option flags
TEXFLAG := -synctex=1
DVIPDFMXFLAG :=
EXTRACTBBFLAGS :=
BIBTEXFLAG :=
MENDEXFLAG :=

# General commands
CAT := cat
CMP := cmp -s
CP := cp
ECHO := echo
GREP := grep
MKDIR := mkdir
SED := sed
SEQ := seq
TEST := test

######################################################################
# 拡張子
######################################################################
# TeX中間ファイルの拡張子
TEXINTEXT := .aux .fls

# LaTeX中間ファイルの拡張子
#   .bbl: 文献リスト。作成方法はパターンルールで定義
#   .glo: 用語集。\glossaryがあればTeX処理で生成
#   .idx: 索引。\makeindexがあればTeX処理で生成
#   .ind: 索引。作成方法はパターンルールで定義
#   .lof: 図リスト。\listoffiguresがあればTeX処理で生成
#   .lot: 表リスト。\listoftablesがあればTeX処理で生成
#   .out: PDFブックマーク。hyperrefパッケージをbookmarksオプションtrue（初期値）で呼び出していれば、TeX処理で生成
#   .toc: 目次。\tableofcontentsがあればTeX処理で生成
LATEXINTEXT := .bbl .glo .idx .ind .lof .lot .out .toc

# ログファイルの拡張子
#   .log: TeXログ
#   .ilg: 索引ログ
#   .blg: BiBTeXログ
LOGEXT := .log .ilg .blg

# すべてのTeX中間ファイルの拡張子
ALLINTEXT := $(TEXINTEXT) $(LATEXINTEXT) $(LOGEXT) .d .*_prev

# 画像ファイルの拡張子
GRAPHICSEXT := .pdf .eps .jpg .jpeg .png .bmp

# make完了後、中間ファイルを残す
.SECONDARY: $(foreach t,$(TEXTARGETS),$(addprefix $(basename $t),$(ALLINTEXT) .dvi))

# ターゲットファイルの名前から拡張子を除いた部分
BASE = $(basename $<)

######################################################################
# .dファイルの生成と読み込み
# .dファイルには、TeX処理での依存関係が記述される
######################################################################
# .flsファイルから、INPUTファイルを取得。ただし、$TEXMFROOTのファイルを除く
# 取得は、1回のmake実行につき1回だけ行われる
INPUTFILES = $(INPUTFILESre)

INPUTFILESre = $(eval INPUTFILES := \
  $(sort $(filter-out $(BASE).tex $(BASE).aux, $(shell \
    $(SED) -n -e 's/^INPUT \(.\{1,\}\)/\1/p' $(BASE).fls | \
    $(GREP) -v `$(KPSEWHICH) -expand-var '$$TEXMFROOT'` \
  ))))

# .flsファイルから、OUTPUTファイルを取得。ただし、$TEXMFROOTのファイルを除く
# 取得は、1回のmake実行につき1回だけ行われる
OUTPUTFILES = $(OUTFILESre)

OUTFILESre = $(eval OUTPUTFILES := \
  $(sort $(filter-out $(BASE).aux $(BASE).dvi $(BASE).log, \
    $(shell \
      $(SED) -n -e 's/^OUTPUT \(.\{1,\}\)/\1/p' $(BASE).fls | \
      $(GREP) -v `$(KPSEWHICH) -expand-var '$$TEXMFROOT'` \
  ))))

# \includeや\inputで読み込まれるTeXファイルを.flsから取得する
TEXSUBFILESFLS = $(filter %.tex,$(INPUTFILES))

# filesで指定したファイルのコメント・verbatim環境・verb| | 以外の部分から、
# ctlseqで指定したコントロールシークエンス（\\ctlseq[ ]{ }）のブレース{}で囲まれた引数を取得する
# コンマで区切られた引数は、コンマをスペースに置換する
# 用例: $(call ctlseq_bracearg,files,ctlseq)
define ctlseq_bracearg
  $(shell \
    $(SED) -e '/^\s*%/d' -e 's/\([^\]\)\s*%.*/\1/g' $(wildcard $1) | \
      $(SED) -e 's/\\verb|[^|]*|//g' | \
      $(SED) -e 's/}/}%/g; y/}%/}\n/' | \
      $(SED) -e '/\\begin{verbatim}/,/\\end{verbatim}/d' | \
      $(SED) -n $(foreach c,$2,-e 's/.*\\$c\(\[[^]]*\]\)\{0,1\}{\([^}]*\)}$$/\2/p') | \
      $(SED) -e 'y/,/ /' \
  )
endef

# 引数rootfileで指定した.texiファイルから、引数ctlseqで指定されたファイルを再帰的に取得する
# 用例: $(shell (call incfiles,rootfile))
define incfiles
  incadd="$1"; \
  while test -n "$${incadd}"; do \
    incfiles="$${incfiles} $${incadd}"; \
    incadd="`\
        for f in $${incadd}; do \
          if $(TEST) $$f = "${f%.*}"; then ff=$$f.tex; else ff=$$f; fi; \
          if $(TEST) -e $${ff}; then \
            $(SED) -e '/^\s*%/d' -e 's/\([^\]\)\s*%.*/\1/g' $${ff} | \
              $(SED) -e 's/\\verb|[^|]*|//g' | \
              $(SED) -e 's/}/}%/g; y/}%/}\n/' | \
              $(SED) -e '/\\begin{verbatim}/,/\\end{verbatim}/d' | \
              $(SED) -n $(foreach c,$2,-e 's/.*\\$c{\([^}]*\)}$$/\1/p'); \
          fi;
        done \
      `"; \
  done; \
  $(ECHO) $${incfiles}
endef

# \includeや\inputで読み込まれるTeXファイルをソースから取得する
# 取得は、1回のmake実行につき1回だけ行われる
TEXSUBFILES = $(TEXSUBFILESre)

TEXSUBFILESre = $(eval TEXSUBFILES := \
  $(filter-out $(BASE).tex,$(sort $(addsuffix .tex,$(basename \
    $(shell $(call incfiles,$(BASE).tex,include input)) \
  )))))

# $(BASE).texで読み込まれる中間ファイルを.flsから取得する
# .idxは、.indへ置換
TEXINTFILES = \
  $(sort $(subst .idx,.ind, \
    $(filter $(addprefix $(BASE),$(LATEXINTEXT)),$(INPUTFILES) $(OUTPUTFILES)) \
  ))

TEXINTFILES_PREV = $(addsuffix _prev,$(TEXINTFILES))

# \includegraphicsで読み込まれる画像ファイルを$(BASE).texと$(TEXSUBFILES)、および.flsファイルから取得する
# 取得は、1回のmake実行につき1回だけ行われる
GRAPHICFILES = $(GRAPHICFILESre)

GRAPHICFILESre = $(eval GRAPHICFILES := \
  $(sort \
    $(call ctlseq_bracearg,$(BASE).tex $(TEXSUBFILES),includegraphics) \
    $(filter $(addprefix %,$(GRAPHICSEXT)),$(INPUTFILES)) \
  ))

# .flsから取得した、そのほかの読み込みファイル（スタイル・クラスファイルなど）
OTHERFILES = $(sort $(filter-out %.aux $(TEXINTFILES) $(TEXSUBFILES) $(GRAPHICFILES),$(INPUTFILES)))

# \bibliography命令で読み込まれる文献データベースファイルをTeXファイルから取得する
# 取得は、1回のmake実行につき1回だけ行われる
BIBFILES = $(BIBFILESre)

BIBFILESre = $(eval BIBFILES := \
  $(addsuffix .bib,$(basename \
    $(call ctlseq_bracearg,$(BASE).tex $(TEXSUBFILES),bibliography) \
  )))

# TeXファイルの依存関係をターゲットファイルへ追加
define ADD_DEP_TEXSUBFILES
  $(ECHO) >>$@
  $(ECHO) '# Files called from \include or \input - .tex' >>$@
  $(ECHO) '$(BASE).aux: $(TEXSUBFILES)' >>$@
endef

# TeX中間ファイルの依存関係をターゲットファイルへ追加
define ADD_DEP_TEXINTFILES
  $(ECHO) >>$@
  $(ECHO) '# TeX Intermediate Files' >>$@
  $(ECHO) '#' >>$@
  $(ECHO) '# $$(COMPILE.tex) := $(TEXCMD)' >>$@
  $(ECHO) '# $$(COMPILES.tex) := $(subst $(EXITWARN),exit 1,$(subst $(EXITNOTFOUND),exit 0,$(subst $(COMPILE.tex),$(TEXCMD),$(COMPILES.tex))))' >>$@
  $(ECHO) '#' >>$@
  $(ECHO) '$(BASE).dvi:: $(sort $(TEXINTFILES_PREV) $(if $(BIBFILES),$(BASE).bbl_prev))' >>$@
  $(ECHO) '	@$$(COMPILE.tex)' >>$@
  $(ECHO) >>$@
  $(ECHO) '$(BASE).dvi:: $(BASE).aux' >>$@
  $(ECHO) '	@$$(COMPILES.tex)' >>$@
endef

# 画像ファイルの依存関係をターゲットファイルへ追加する
define ADD_DEP_GRAPHICFILES
  $(ECHO) >>$@
  $(ECHO) '# Files called from \includegraphics - $(GRAPHICSEXT)' >>$@
  $(ECHO) '$(BASE).aux: $(GRAPHICFILES)' >>$@
endef

# .xbbファイルの依存関係をターゲットファイルへ追加する
define ADD_DEP_XBBFILES
  $(ECHO) >>$@
  $(ECHO) '# .xbb files with: $(filter-out .eps,$(GRAPHICSEXT))' >>$@
  $(ECHO) '$(BASE).aux: $(addsuffix .xbb,$(basename $(filter-out %.eps,$(GRAPHICFILES))))' >>$@
endef

# 文献リスト作成用ファイルの依存関係をターゲットファイルへ追加する
define ADD_DEP_BIBFILES
  $(ECHO) >>$@
  $(ECHO) '# Bibliography files: .aux, .bib -> .bbl -> .div' >>$@
  $(ECHO) '$(BASE).bbl: $(BIBFILES) $(BASE).tex' >>$@
endef

# そのほかのファイル（TeXシステム以外のクラス・スタイルファイルなど）の依存関係をターゲットファイルへ追加する
define ADD_DEP_OTHERFILES
  $(ECHO) >>$@
  $(ECHO) '# Other files' >>$@
  $(ECHO) '$(BASE).aux: $(OTHERFILES)' >>$@
endef

# .dファイルを作成するパターンルール
%.d: %.fls
    # 遅延展開されるMakefile変数を展開する。実際の表示はしない
	@$(foreach f, INPUTFILES OUTPUTFILES TEXSUBFILES GRAPHICFILES BIBFILES, $(ECHO) '$f=$($f)'>/dev/null; )
    # .dファイルに書き込まれる変数をコマンドラインへ出力する
	@$(if $(strip $(TEXSUBFILES) $(TEXINTFILES) $(GRAPHICFILES) $(BIBFILES)), \
      $(ECHO) 'Makefile variables'; \
      $(foreach f, TEXSUBFILES TEXINTFILES GRAPHICFILES BIBFILES, $(if $($f),$(ECHO) '  $f=$($f)'; )) \
    )
    # ターゲットファイル（.dファイル）を作成し、自身の依存関係を出力する
	@$(ECHO) $(BASE).d: $(strip $(BASE).tex $(BASE).fls $(TEXSUBFILES)) >$@
    # TeXファイルがある場合、依存関係をターゲットファイルへ追加する
	@$(if $(TEXSUBFILES),$(ADD_DEP_TEXSUBFILES))
ifeq (,$(filter-out %latex,$(TEX)))
    # 中間ファイルがある場合、依存関係をターゲットファイルへ追加する
	@$(if $(strip $(TEXINTFILES) $(BIBFILES)),$(ADD_DEP_TEXINTFILES))
    # 画像ファイルがある場合、依存関係をターゲットファイルへ追加する
	@$(if $(GRAPHICFILES),$(ADD_DEP_GRAPHICFILES))
    # バウンディング情報ファイルがある場合、依存関係をターゲットファイルへ追加する
	@$(if $(filter-out %.eps,$(GRAPHICFILES)),$(ADD_DEP_XBBFILES))
    # 文献リストファイルがある場合、依存関係をターゲットファイルへ追加する
	@$(if $(BIBFILES),$(ADD_DEP_BIBFILES))
    # そのほかのファイルがある場合、依存関係をターゲットファイルへ追加する
	@$(if $(OTHERFILES),$(ADD_DEP_OTHERFILES))
endif
    # ターゲットファイルが作成されたことをコマンドラインへ出力する
	@$(ECHO) '$@ is generated by scanning $(strip $(BASE).tex $(TEXSUBFILES)) and $(BASE).fls.'

# 変数TEXTARGETSで指定されたターゲットファイルに対応する
# .dファイルをインクルードし、依存関係を取得する
# ターゲット末尾に clean、xbb、.tex、.d が含まれている場合は除く
ifeq (,$(filter %clean %xbb %.tex %.d %.fls,$(MAKECMDGOALS)))
  -include $(addsuffix .d,$(basename $(TEXTARGETS)))
endif

######################################################################
# dviおよびPDFファイルを生成するパターンルール
# TeX -> dvi -> PDF
######################################################################
# TeX処理（コンパイル）
TEXCMD = $(TEX) -interaction=batchmode $(TEXFLAG) $(BASE).tex

# エラー発生時にログのエラー部分を、行頭に「<TeXファイル名>:<行番号>:」を付けて表示する
COMPILE.tex = \
  $(ECHO) $(TEXCMD); $(TEXCMD) >/dev/null 2>&1 || \
 ( \
    $(SED) -n -e '/^!/,/^$$/p' $(BASE).log | \
      $(SED) -e 's/.*\s*l\.\([0-9]*\)\s*.*/$(BASE).tex:\1: &/' >&2; \
    exit 1; \
  )

# 相互参照未定義の警告
WARN_UNDEFREF := There were undefined references.

# TeX処理の繰り返し
# ログファイルに警告がある場合は警告がなくなるまで、最大LIMで指定された回数分、処理を実行する
LIM := 3
LIMMSG := $(TEX) is run $(LIM) times, but there are still undefined references.

EXITNOTFOUND = if $(TEST) $$? -eq 1; then exit 0; else exit $$?; fi

EXITWARN = \
  $(ECHO) "$(LIMMSG)" >&2; \
  $(SED) -n -e "/^LaTeX Warning:/,/^$$/p" $(BASE).log | \
    $(SED) -e "s/.*\s*line \([0-9]*\)\s*.*/$(BASE).tex:\1: &/" >&2; \
  exit 1

COMPILES.tex = \
  for i in `$(SEQ) 0 $(LIM)`; do \
    if $(TEST) $$i -lt $(LIM); then \
      $(GREP) -F "$(WARN_UNDEFREF)" $(BASE).log || $(EXITNOTFOUND) && $(COMPILE.tex); \
    else \
      $(EXITWARN); \
    fi; \
  done;

# DVI -> PDF
DVIPDFCMD = $(DVIPDFMX) $(DVIPDFMXFLAG) $(BASE).dvi

# ログを.logファイルへ追加出力
COMPILE.dvi = \
  $(ECHO) $(DVIPDFCMD); $(DVIPDFCMD) >>$(BASE).log 2>&1 || \
    ( \
      $(SED) -n -e '/^Output written on $(BASE)\.dvi/,$$p' $(BASE).log; \
      exit 1 \
    )

# TeX -> aux
%.aux: %.tex
	@$(COMPILE.tex)

# aux -> dvi
%.dvi: %.aux
	@$(COMPILES.tex)

# tex -> dvi
%.dvi: %.tex
	@$(COMPILE.tex)
	@$(COMPILES.tex)

# dvi -> PDF
%.pdf: %.dvi
	@$(COMPILE.dvi)

######################################################################
# ファイルリストファイル（.fls）作成
######################################################################
# .flsファイル作成用の一時ディレクトリー
FLSDIR := .fls.temp

# $(BASE).flsファイルの作成
FLSCMD = $(TEX) -interaction=nonstopmode -recorder -output-directory=$(FLSDIR) $(BASE).tex

GENERETE.fls = \
  if $(TEST) ! -e $(FLSDIR); then \
    $(MKDIR) $(FLSDIR); \
  fi; \
  $(FLSCMD) 1>/dev/null 2>&1; \
  $(SED) -e 's|$(FLSDIR)/||g' $(FLSDIR)/$(BASE).fls >$(BASE).fls; \
  if $(TEST) -e $(BASE).fls; then \
    $(ECHO) '$(BASE).fls is generated.'; \
    $(RM) -r $(FLSDIR); \
  else \
    $(ECHO) '$(BASE).fls is not generated.' >&2; \
    exit 1; \
  fi

%.fls: %.tex
	@-$(GENERETE.fls)

######################################################################
# LaTeX中間ファイルを生成するパターンルール
######################################################################
# ターゲットファイルと必須ファイルを比較し、
# 内容が異なる場合はターゲットファイルの内容を必須ファイルに置き換える
CMPPREV = $(CMP) $< $@ && $(ECHO) '$@ is up to date.' || $(CP) -p -v $< $@

# 図リスト
%.lof: %.tex
	@$(MAKE) -s $(BASE).aux

%.lof_prev: %.lof
	@$(CMPPREV)

# 表リスト
%.lot: %.tex
	@$(MAKE) -s $(BASE).aux

%.lot_prev: %.lot
	@$(CMPPREV)

# PDFブックマーク
%.out: %.tex
	@$(MAKE) -s $(BASE).aux

%.out_prev: %.out
	@$(CMPPREV)

# 目次
%.toc: %.tex
	@$(MAKE) -s $(BASE).aux

%.toc_prev: %.toc
	@$(CMPPREV)

######################################################################
# 索引用中間ファイルを生成するパターンルール
######################################################################
# 索引用中間ファイル作成コマンド
MENDEXCMD = $(MENDEX) $(MENDEXFLAG) $(BASE).idx

COMPILE.idx = $(ECHO) $(MENDEXCMD); $(MENDEXCMD) >/dev/null 2>&1 || ($(CAT) $(BASE).ilg >&2; exit 1)

# .tex -> .idx
%.idx: %.tex
	@$(MAKE) -s $(BASE).aux

%.idx_prev: %.idx
	@$(CMPPREV)

# .idx -> .ind
%.ind: %.idx_prev
	@$(COMPILE.idx)

%.ind_prev: %.ind
	@$(CMPPREV)

######################################################################
# 文献リスト用中間ファイルを生成するパターンルール
######################################################################
# 文献リスト用中間ファイル作成コマンド
BIBTEXCMD = $(BIBTEX) $(BIBTEXFLAG) $(BASE).aux

COMPILE.bib = $(ECHO) $(BIBTEXCMD); $(BIBTEXCMD) >/dev/null 2>&1 || ($(CAT) $(BASE).blg >&2; exit 1)

# TeX -> .aux -> .bib
%.bbl: %.tex
	@$(MAKE) -s $(BASE).aux
	@$(COMPILE.bib)

%.bbl_prev: %.bbl
	@$(CMPPREV)

######################################################################
# バウンディング情報ファイルを生成するパターンルール
######################################################################
%.xbb: %.pdf
	$(EXTRACTBB) $(EXTRACTBBFLAGS) $<

%.xbb: %.jpeg
	$(EXTRACTBB) $(EXTRACTBBFLAGS) $<

%.xbb: %.jpg
	$(EXTRACTBB) $(EXTRACTBBFLAGS) $<

%.xbb: %.png
	$(EXTRACTBB) $(EXTRACTBBFLAGS) $<

%.xbb: %.bmp
	$(EXTRACTBB) $(EXTRACTBBFLAGS) $<

######################################################################
# ターゲット
######################################################################
# 警告
tex-warn:
	@$(ECHO) "Check current directory, or target of Makefile." >&2; exit 2

# すべての画像ファイルに対してextractbbを実行
tex-xbb:
	$(MAKE) -s $(addsuffix .xbb,$(basename $(wildcard $(addprefix *,$(GRAPHICSEXT)))))

# 中間ファイルの削除
tex-clean:
	$(RM) $(addprefix *,$(ALLINTEXT))
	$(RM) -r $(FLSDIR)
ifeq (,$(filter %.dvi,$(TEXTARGETS)))
	$(RM) *.dvi
endif

# .xbbファイルの削除
tex-xbb-clean:
	$(RM) *.xbb

# 生成されたすべてのファイルの削除
tex-distclean: tex-clean tex-xbb-clean
ifneq (,$(filter %.dvi,$(TEXTARGETS)))
	$(RM) *.dvi
endif
	$(RM) *.synctex.gz
	$(RM) $(TEXTARGETS)
