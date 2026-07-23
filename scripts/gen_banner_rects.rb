#!/usr/bin/env ruby
# figlet バナー (ANSI Shadow) を rect 化して assets/dino-ruby.svg に埋め込む生成器。
#
# 背景: バナーを <text> + monospace フォント指定で描くと、スマホ (GitHub mobile /
# iOS Safari) には指定フォントがなく、█ や ╔ ═ などのブロック罫線文字が代替フォント
# で異なる文字幅になり行ごとにずれて崩れる。rect ならフォント非依存で崩れない
# (ゲーム画面・リンクアイコンが崩れないのと同じ理由)。
#
# 使い方: ruby scripts/gen_banner_rects.rb
#   assets/dino-ruby.svg 内の BEGIN/END figlet-rects マーカー間を再生成する。

SVG_PATH = File.expand_path("../assets/dino-ruby.svg", __dir__)

# 元の figlet yamanao (ANSI Shadow)。1 行 1 色は本物のターミナルで再現可能な範囲。
ROWS = [
  ["#ff8fab", "██╗   ██╗ █████╗ ███╗   ███╗ █████╗ ███╗   ██╗ █████╗  ██████╗ "],
  ["#ff6b93", "╚██╗ ██╔╝██╔══██╗████╗ ████║██╔══██╗████╗  ██║██╔══██╗██╔═══██╗"],
  ["#f0447a", " ╚████╔╝ ███████║██╔████╔██║███████║██╔██╗ ██║███████║██║   ██║"],
  ["#d92c63", "  ╚██╔╝  ██╔══██║██║╚██╔╝██║██╔══██║██║╚██╗██║██╔══██║██║   ██║"],
  ["#b3204e", "   ██║   ██║  ██║██║ ╚═╝ ██║██║  ██║██║ ╚████║██║  ██║╚██████╔╝"],
  ["#8b1538", "   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝   ╚═╝╚═╝  ╚═╝ ╚═════╝ "],
].freeze

# 文字セル: 旧 <text> 描画 (font-size 13px, 等幅 0.6em) と同じ見た目に合わせる
X0 = 16       # 旧 text の x
Y0 = 62       # 旧 1 行目 baseline 72 - ascent 相当
CW = 7.8      # 文字送り (13px * 0.6)
CH = 13.0     # 行送り (baseline 間隔と同じ)

# 二重罫線のストローク: 太さ T、セル中央から GAP だけ離した 2 本
T = 1.4
XL = 1.7      # 左縦ストロークの左端 (中央 3.9 - 0.8 - 1.4)
XR = 4.7      # 右縦ストロークの左端 (中央 3.9 + 0.8)
YT = 4.3      # 上横ストロークの上端 (中央 6.5 - 0.8 - 1.4)
YB = 7.3      # 下横ストロークの上端 (中央 6.5 + 0.8)

# 1 文字分の rect 群 (セル内相対座標 [x, y, w, h])
def char_rects(ch)
  case ch
  when " " then []
  when "█" then [[0, 0, CW, CH]]
  when "║" then [[XL, 0, T, CH], [XR, 0, T, CH]]
  when "═" then [[0, YT, CW, T], [0, YB, CW, T]]
  when "╔" # 外側: 左縦 + 上横が右下へ / 内側: 右縦 + 下横
    [[XL, YT, T, CH - YT], [XL, YT, CW - XL, T],
     [XR, YB, T, CH - YB], [XR, YB, CW - XR, T]]
  when "╗"
    [[XR, YT, T, CH - YT], [0, YT, XR + T, T],
     [XL, YB, T, CH - YB], [0, YB, XL + T, T]]
  when "╚"
    [[XL, 0, T, YB + T], [XL, YB, CW - XL, T],
     [XR, 0, T, YT + T], [XR, YT, CW - XR, T]]
  when "╝"
    [[XR, 0, T, YB + T], [0, YB, XR + T, T],
     [XL, 0, T, YT + T], [0, YT, XL + T, T]]
  else
    raise "unsupported char: #{ch.inspect}"
  end
end

# 同じ y・高さで水平に接する rect を 1 本にまとめる (█ の連続、╚═╝ の横棒など)
def merge_horizontal(rects)
  rects.group_by { |_, y, _, h| [y.round(2), h.round(2)] }.flat_map do |_, group|
    group.sort_by { |x, _, _, _| x }.each_with_object([]) do |rect, merged|
      last = merged.last
      if last && rect[0] <= last[0] + last[2] + 0.01
        last[2] = [last[2], rect[0] + rect[2] - last[0]].max
      else
        merged << rect.dup
      end
    end
  end.sort_by { |x, y, _, _| [y, x] }
end

def fmt(v)
  ("%.2f" % v).sub(/\.?0+\z/, "")
end

banner = ROWS.each_with_index.map do |(color, line), row|
  rects = line.each_char.with_index.flat_map do |ch, col|
    char_rects(ch).map do |x, y, w, h|
      [X0 + col * CW + x, Y0 + row * CH + y, w, h]
    end
  end
  body = merge_horizontal(rects).map do |x, y, w, h|
    %(      <rect x="#{fmt(x)}" y="#{fmt(y)}" width="#{fmt(w)}" height="#{fmt(h)}"/>)
  end
  ["    <g fill=\"#{color}\">", *body, "    </g>"]
end.flatten.join("\n")

svg = File.read(SVG_PATH, encoding: "UTF-8")
markers = /(<!-- BEGIN figlet-rects[^>]*-->\n).*?(  <!-- END figlet-rects -->)/m
raise "markers not found in #{SVG_PATH}" unless svg.match?(markers)

File.write(SVG_PATH, svg.sub(markers, "\\1#{banner}\n\\2"))
rect_count = banner.scan("<rect").size
puts "dino-ruby.svg: figlet banner -> #{rect_count} rects"
