#!/usr/bin/env ruby
# リンクアイコン (assets/link-*.svg) の生成器。
# 各サービスの favicon を 12 列グリッドのピクセルアートに再構成する。
# 1 セル 4px、64x64 タイル(bg #161b22 / stroke #30363d / rx 8)。
# rows の文字を palette で色に対応させる ('.' は透過)。
#
# 使い方: ruby scripts/gen_link_icons.rb [出力ディレクトリ(省略時 assets)]

CELL = 4
TILE = 64

ICONS = {
  # X favicon: 白の 𝕏 (太い「\」3px + 細い「/」2px、45° 一定周期、端は水平カット)
  "x" => {
    label: "X: x.com/yamanaoRuby",
    palette: { "#" => "#ffffff" },
    rows: [
      "###.......##",
      ".###.....##.",
      "..###...##..",
      "...###.##...",
      "....####....",
      ".....###....",
      "....#####...",
      "...##..###..",
      "..##....###.",
      ".##......###",
    ]
  },
  # Zenn favicon: 青 (#3EA8FF) の斜めストローク 2 本 (等幅 3px・一定周期の階段)
  "zenn" => {
    label: "Zenn: zenn.dev/naoki_ymd",
    palette: { "#" => "#3ea8ff" },
    rows: [
      ".......###..",
      "......###...",
      "......###...",
      ".....###....",
      "....###.....",
      "....###.....",
      "...###..###.",
      "..###..###..",
      "..###..###..",
      ".###..###...",
      "###..###....",
      "###..###....",
    ]
  },
  # connpass favicon: 赤 (#D52E02) のチケット + 白 (W) の C
  "connpass" => {
    label: "connpass: connpass.com/user/nakiymRuby/",
    palette: { "#" => "#d52e02", "W" => "#ffffff" },
    rows: [
      "############",
      "############",
      "####WWWW####",
      "####W#######",
      ".###W######.",
      ".###W######.",
      "####W#######",
      "####WWWW####",
      "############",
      "############",
    ]
  },
  # portfolio: 赤 (#D32F2F、yamanao.me のアクセント) の家アイコン
  "portfolio" => {
    label: "Portfolio: yamanao.me",
    palette: { "#" => "#d32f2f" },
    rows: [
      ".....##.....",
      "....####....",
      "...##..##...",
      "..##....##..",
      ".##......##.",
      "############",
      ".#........#.",
      ".#..####..#.",
      ".#..#..#..#.",
      ".#..#..#..#.",
      ".##########.",
    ]
  },
  # Gmail favicon (2026): 左脚 赤・右脚 虹グラデーションの M
  "email" => {
    label: "Email: yamanao.dev@gmail.com",
    palette: {
      "P" => "#ff5b8c", # pink (top-left corner)
      "R" => "#fc413d", # red (left leg + left diagonal)
      "O" => "#fd7a25", # orange (right diagonal)
      "Y" => "#feb409", # yellow
      "L" => "#b9cf2d", # lime
      "G" => "#1ebc5d", # green
      "T" => "#04abae", # teal
      "C" => "#169fd5", # cyan
      "B" => "#3690f5", # blue
    },
    rows: [
      "PPR......OYY",
      "RRRR....OOYY",
      "RR.RR..OO.LL",
      "RR..RROO..GG",
      "RR...RO...TT",
      "RR........TT",
      "RR........CC",
      "RR........BB",
      "RR........BB",
    ]
  },
}

def runs(row)
  # 同色で連続するセルを [開始位置, 長さ, 文字] にまとめる
  result = []
  i = 0
  while i < row.length
    ch = row[i]
    if ch == "."
      i += 1
      next
    end
    j = i
    j += 1 while j < row.length && row[j] == ch
    result << [i, j - i, ch]
    i = j
  end
  result
end

def merged_rects(rows)
  # 各行の run を求め、同一 (開始位置, 長さ, 文字) の run が縦に連続する場合は
  # 1 つの背の高い rect にまとめる。返り値は [x, y, w, h(セル数), 文字]
  open = {}   # [start, len, ch] => 開始行
  result = []
  (rows + [""]).each_with_index do |row, y|
    current = runs(row).to_h { |start, len, ch| [[start, len, ch], true] }
    open.each do |key, y0|
      next if current.key?(key)
      start, len, ch = key
      result << [start, y0, len, y - y0, ch]
    end
    open = open.select { |key, _| current.key?(key) }
    current.each_key { |key| open[key] ||= y }
  end
  result.sort_by { |_, y0, *| y0 }
end

return unless __FILE__ == $0

dir = ARGV[0] || File.expand_path("../assets", __dir__)
ICONS.each do |name, spec|
  w = spec[:rows].map(&:length).max
  h = spec[:rows].length
  ox = (TILE - w * CELL) / 2
  oy = (TILE - h * CELL) / 2
  rects = merged_rects(spec[:rows]).map do |x, y, len, rows_tall, ch|
    color = spec[:palette].fetch(ch)
    fill = spec[:palette].size == 1 ? "" : %( fill="#{color}")
    %(    <rect x="#{ox + x * CELL}" y="#{oy + y * CELL}" width="#{len * CELL}" height="#{rows_tall * CELL}"#{fill}/>)
  end
  group_fill = spec[:palette].size == 1 ? %( fill="#{spec[:palette].values.first}") : ""
  svg = <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{TILE} #{TILE}" width="#{TILE}" height="#{TILE}" role="img" aria-label="#{spec[:label]}">
      <rect x="1" y="1" width="#{TILE - 2}" height="#{TILE - 2}" rx="8" fill="#161b22" stroke="#30363d" stroke-width="1.5"/>
      <g#{group_fill} shape-rendering="crispEdges">
    #{rects.join("\n")}
      </g>
    </svg>
  SVG
  File.write(File.join(dir, "link-#{name}.svg"), svg)
  puts "link-#{name}.svg (#{w}x#{h})"
end
