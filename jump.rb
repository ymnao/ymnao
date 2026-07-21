#!/usr/bin/env ruby
# frozen_string_literal: true

# jump.rb — a tiny terminal runner, styled to match assets/dino-ruby.svg.
#   $ ruby jump.rb
#   SPACE to jump, q to quit.

require "io/console"

abort("jump.rb needs an interactive terminal") unless $stdin.tty?

term_h, term_w = IO.console.winsize
if term_w < 64 || term_h < 16
  abort("jump.rb needs at least a 64x16 terminal (yours: #{term_w}x#{term_h})")
end

WIDTH    = (term_w - 4).clamp(60, 120)
SKY      = (term_h - 6).clamp(10, 20)   # rows above the ground line
PLAYER_X = 10         # gem center column
SPEED    = 1          # columns per frame
GRAVITY  = 0.09
JUMP_V   = 1.45
FPS      = 60

RESET  = "\e[0m"
C_DIM  = "\e[38;2;110;118;129m"  # gray #6e7681
C_OVER = "\e[38;2;248;81;73m"    # red  #f85149

# Palette letters used in sprite color maps (same colors as the SVG)
PALETTE = {
  "h" => "\e[38;2;255;143;171m", # ruby light  #ff8fab
  "m" => "\e[38;2;224;36;94m",   # ruby mid    #e0245e
  "d" => "\e[38;2;139;21;56m",   # ruby dark   #8b1538
  "g" => "\e[38;2;63;185;80m",   # cactus      #3fb950
  "G" => "\e[38;2;46;160;67m",   # cactus dark #2ea043
}.freeze

# Sprites: [chars, color map] per row; bottom row sits on the ground line
GEM = [
  ["  ▄▄▄▄▄▄▄  ", "  hhhhhhh  "],
  ["▄█████████▄", "hhhmmmmmmdd"],
  [" ▀███████▀ ", " mmmmmmmdd "],
  ["   ▀███▀   ", "   mmddd   "],
  ["     ▀     ", "     d     "],
].freeze

# Clouds like the SVG: a wide flat base ellipse + a smaller puff offset right
CLOUD_BIG   = ["      ▄▄▄▄  ", "▄██████████▄"].freeze
CLOUD_SMALL = ["    ▄▄  ", "▄██████▄"].freeze

CACTUS_SPRITES = {
  small: [
    ["█ █  ", "g g  "],
    ["▀▄█ █", "ggg G"],
    ["  █▄▀", "  gGG"],
    ["  ▀  ", "  g  "],
  ],
  big: [
    ["  █  ", "  g  "],
    ["█ █  ", "g g  "],
    ["▀▄█ █", "ggg G"],
    ["  █▄▀", "  gGG"],
    ["  █  ", "  g  "],
    ["  ▀  ", "  g  "],
  ],
}.freeze

Cactus = Struct.new(:x, :kind)

# Sprites sit with their bottom row ON the ground-line row (grid row SKY)
def draw(grid, x, rows, lift = 0)
  rows.each_with_index do |(chars, colors), ri|
    gy = SKY + 1 - rows.length + ri - lift
    next unless (0..SKY).cover?(gy)
    chars.each_char.with_index do |ch, i|
      next if ch == " "
      gx = x + i
      grid[gy][gx] = [ch, PALETTE[colors[i]]] if (0...WIDTH).cover?(gx)
    end
  end
end

y      = 0.0          # gem height above ground (rows)
vy     = 0.0
cacti  = []
tick   = 0
next_spawn = 100      # frames until the next cactus

%w[INT TERM HUP].each { |sig| Signal.trap(sig) { exit } }

print "\e[?25l\e[2J"
begin
  $stdin.raw do
    loop do
      frame_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      while (key = $stdin.read_nonblock(1, exception: false))
        break if key == :wait_readable
        exit if ["q", "\u0003"].include?(key)
        vy = JUMP_V if key == " " && y.zero?
      end

      vy -= GRAVITY
      y = [y + vy, 0.0].max
      vy = 0.0 if y.zero? && vy.negative?

      tick += 1
      next_spawn -= 1
      if next_spawn <= 0 && (cacti.empty? || cacti.last.x < WIDTH - 40)
        cacti << Cactus.new(WIDTH - 5, rand < 0.65 ? :small : :big)
        next_spawn = 55 + rand(75)   # steady but not metronomic
      end
      cacti.each { |c| c.x -= SPEED }
      cacti.reject! { |c| c.x < -5 }

      # gem hitbox: 7 columns around center, bottom row at height y
      hit = cacti.any? do |c|
        c.x <= PLAYER_X + 3 && c.x + 4 >= PLAYER_X - 3 && y.round < CACTUS_SPRITES[c.kind].length
      end
      if hit
        print "\e[#{SKY + 4};1H\e[2K  #{C_OVER}GAME OVER#{RESET} — score: #{tick / 20}  (any key: retry / q: quit)\r\n"
        exit if ["q", "\u0003"].include?($stdin.getch)
        cacti.clear
        tick = 0
        y = 0.0
        vy = 0.0
        next_spawn = 100
        print "\e[2J"
        next
      end

      # grid of [char, color]; the last row (SKY) is the ground line itself
      grid = Array.new(SKY + 1) { Array.new(WIDTH) { [" ", nil] } }
      grid[SKY] = Array.new(WIDTH) { ["─", C_DIM] }

      # clouds (slow parallax, like the SVG)
      cl1 = WIDTH - (tick / 8) % (WIDTH + 16)
      cl2 = WIDTH - ((tick + 840) / 12) % (WIDTH + 16)
      [[CLOUD_BIG, 0, cl1], [CLOUD_SMALL, 2, cl2]].each do |sprite, row, cx|
        sprite.each_with_index do |chars, ri|
          chars.each_char.with_index do |ch, i|
            next if ch == " "
            gx = cx + i
            grid[row + ri][gx] = [ch, C_DIM] if (0...WIDTH).cover?(gx)
          end
        end
      end

      cacti.each { |c| draw(grid, c.x, CACTUS_SPRITES[c.kind]) }

      # ruby gem, tip resting on the ground line when y == 0
      lift = y.round.clamp(0, SKY + 1 - GEM.length)
      draw(grid, PLAYER_X - 5, GEM, lift)

      frame = +"\e[H"
      frame << "  #{C_DIM}score: #{tick / 20}#{RESET}\r\n"
      grid.each do |cells|
        frame << "  "
        cur = nil
        cells.each do |ch, color|
          if color != cur
            frame << (color || RESET)
            cur = color
          end
          frame << ch
        end
        frame << RESET << "\r\n"
      end
      dashes = (0...WIDTH).map { |i| ((i + tick * SPEED) % 12) < 3 ? "▪" : " " }.join
      frame << "  #{C_DIM}#{dashes}#{RESET}\r\n"
      print frame

      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - frame_start
      sleep [1.0 / FPS - elapsed, 0].max
    end
  end
ensure
  print "\e[?25h\n"
end
