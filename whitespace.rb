require 'strscan'

# WhiteSpaceの実行クラス
class WhiteSpace
  @tokenizer = nil
  @parser = nil

  def initialize
    file = read_file
    @tokenizer = Tokenizer.new(file)
    tokens = @tokenizer.execute
    @parser = Parser.new(tokens)
    @parser.evaluate
  end


  def read_file
    begin
      ARGF.read
    rescue
      throw "Error: No such file or directory."
    end
  end
end

# 字句解析器クラス
class Tokenizer
  def initialize(code)
    @code = code
    @scanner = StringScanner.new(code)
  end

  # 字句解析の実行
  def execute
    result = []
    # コメントを削除
    remove_comment
    begin
      while true
        # scannerが終端に達した場合は終了
        if is_eos
          break
        end
        # IMPの解析実行
        imp = tokenize_imp
        # コマンドの解析実行
        cmd = self.send("tokenize_cmd_#{imp}")
        # コマンドの引数の解析実行
        params = tokenize_params_push(cmd)
        # 結果を配列に格納
        result << [imp, cmd]
        unless params.nil?
          result << [imp, cmd, params]
        end
      end
    # エラーが発生した場合はエラーを表示
    rescue => e
      STDERR.puts(e.message)
    end
    result
  end

  private

  def is_eos
    @scanner.eos?
  end

  # IMP (s, ts, tt, n, tn) の解析
  def tokenize_imp
    unless @scanner.scan(/\A( |\n|\t[ \n\t])/)
      raise "Invalid IMP: pattern unmatched"
    end

    imps = {
      "s" => :stack,
      "ts" => :arithmetic,
      "tt" => :heap,
      "n" => :flow,
      "tn" => :io
    }
    # トークンを変換
    token = convert_to_tsn(@scanner.matched)
    # IMPのリストに含まれていない場合はエラー
    unless imps.has_key?(token)
      raise "Invalid IMP: (#{token})"
    end
    # IMPのリストに含まれている場合はそのIMPを返す
    imps[token]
  end

  # スタック操作 (s) のコマンド解析
  def tokenize_cmd_stack
    unless @scanner.scan(/\A( |\n[ \n\t]|\t[ \n])/)
      raise "Invalid CMD stack: pattern unmatched"
    end
    cmds = {
      "s" => :push,
      "ns" => :duplicate,
      "ts" => :duplicate_n,
      "nt" => :swap,
      "nn" => :discard,
      "tn" => :discard_n
    }
    # トークンを変換
    token = convert_to_tsn(@scanner.matched)
    # CMDのリストに含まれていない場合はエラー
    unless cmds.has_key?(token)
      raise "Invalid CMD stack: (#{token})"
    end
    # CMDのリストに含まれている場合はそのCMDを返す
    cmds[token]
  end

  # 算術計算 (ts) のコマンド解析
  def tokenize_cmd_arithmetic
    unless @scanner.scan(/\A( [ \t\n]|\t[ \t])/)
      raise "Invalid CMD arithmetic: pattern unmatched"
    end
    cmds = {
      "ss" => :add,
      "st" => :sub,
      "sn" => :mul,
      "ts" => :div,
      "tt" => :mod
    }
    # トークンを変換
    token = convert_to_tsn(@scanner.matched)
    # CMDのリストに含まれていない場合はエラー
    unless cmds.has_key?(token)
      raise "Invalid CMD arithmetic: (#{token})"
    end
    # CMDのリストに含まれている場合はそのCMDを返す
    cmds[token]
  end

  # ヒープアクセス (tt) のコマンド解析
  def tokenize_cmd_heap
    unless @scanner.scan(/\A([ \t])/)
      raise "Invalid CMD heap: pattern unmatched"
    end
    cmds = {
      "s" => :store,
      "t" => :retrieve
    }
    # トークンを変換
    token = convert_to_tsn(@scanner.matched)
    # CMDのリストに含まれていない場合はエラー
    unless cmds.has_key?(token)
      raise "Invalid CMD heap: (#{token})"
    end
    # CMDのリストに含まれている場合はそのCMDを返す
    cmds[token]
  end

  # フロー制御 (n) のコマンド解析
  def tokenize_cmd_flow
    unless @scanner.scan(/\A( [ \t\n]|\t[ \t\n]|\n\n)/)
      raise "Invalid CMD flow: pattern unmatched"
    end
    cmds = {
      "ss" => :label,
      "st" => :call,
      "sn" => :jump,
      "ts" => :jump_zero,
      "tt" => :jump_negative,
      "tn" => :return,
      "nn" => :exit
    }
    # トークンを変換
    token = convert_to_tsn(@scanner.matched)
    # CMDのリストに含まれていない場合はエラー
    unless cmds.has_key?(token)
      raise "Invalid CMD flow: (#{token})"
    end
    # CMDのリストに含まれている場合はそのCMDを返す
    cmds[token]
  end

  # 入出力 (tn) のコマンド解析
  def tokenize_cmd_io
    unless @scanner.scan(/\A( [ \t]|\t[ \t])/)
      raise "Invalid CMD io: pattern unmatched"
    end
    cmds = {
      "ss" => :print_char,
      "st" => :print_num,
      "ts" => :read_char,
      "tt" => :read_num
    }
    # トークンを変換
    token = convert_to_tsn(@scanner.matched)
    # CMDのリストに含まれていない場合はエラー
    unless cmds.has_key?(token)
      raise "Invalid CMD io: (#{token})"
    end
    # CMDのリストに含まれている場合はそのCMDを返す
    cmds[token]
  end

  # コマンドの引数の解析
  def tokenize_params_push(cmd)
    required_cmds = [:push, :label, :call, :jump, :jump_zero, :jump_negative]
    # 引数が必要なコマンドでない場合はnilを返す
    unless required_cmds.include?(cmd)
      return nil
    end
    # 引数が必要なコマンドの場合は引数を解析する
    unless @scanner.scan(/\A([ \t]+\n)/)
      raise "Invalid PARAMS: pattern unmatched"
    end
    # トークンをtsn => 2進数変換 => 10進数変換して返す
    convert_to_binary(convert_to_tsn(@scanner.matched))
  end

  # tsn形式に変換する
  def convert_to_tsn(token)
    token.gsub(/ /, "s").gsub(/\t/, "t").gsub(/\n/, "n")
  end

  # tsn形式を2進数に変換 (s => 0, t => 1, n => 削除)
  def convert_to_binary(token)
    token.gsub(/s/, "0").gsub(/t/, "1").gsub(/n/, "")
  end

  # コメントを削除
  def remove_comment
    @code.gsub!(/[^ \n\t]/, "")
  end
end

# 構文解析器クラス
class Parser
  # 初期化
  def initialize(tokens)
    STDIN.sync = true
    STDOUT.sync = true
    @stack = []
    @heap = {}
    @pc = 0
    @tokens = tokens
    @subroutines = []
    @labels = Hash.new do |hash, key|
      @tokens.each_with_index do |(_, cmd, params), index|
        if cmd == :label
          hash[params] = index
        end
      end
      hash[key]
    end
  end

  # 構文解析の実行
  def evaluate
      loop do
        imp, cmd, params = @tokens[@pc]
        @pc += 1
        STDOUT << "#{imp} #{cmd} #{params}\n"
        self.send("execute_#{imp}", cmd, params)
      end
  end

  private

  # スタック操作 (s) の実行
  def execute_stack(cmd, params)
    case cmd
    when :push
      @stack.push(params)
    when :duplicate
      @stack.push(@stack.last)
    when :duplicate_n
      @stack.push(@stack[-params])
    when :swap
      @stack.push(@stack.slice!(-2))
    when :discard
      @stack.pop
    when :discard_n
      @stack.slice!(-params)
    else
      raise SyntaxError.new("Invalid syntax stack: unknown command (#{cmd}) at #{@pc}")
    end
  end

  # 算術計算 (ts) の実行
  def execute_arithmetic(cmd, params)
    f_elm = convert_to_decimal(@stack.pop)
    s_elm = convert_to_decimal(@stack.pop)
    case cmd
    when :add
      @stack.push(convert_to_binary(s_elm + f_elm))
    when :sub
      @stack.push(convert_to_binary(s_elm - f_elm))
    when :mul
      @stack.push(convert_to_binary(s_elm * f_elm))
    when :div
      @stack.push(convert_to_binary(s_elm / f_elm))
    when :mod
      @stack.push(convert_to_binary(s_elm % f_elm))
    else
      raise SyntaxError.new("Invalid syntax arithmetic: unknown command (#{cmd}) at #{@pc}")
    end
  end

  # ヒープアクセス (tt) の実行
  def execute_heap(cmd, params)
    case cmd
    when :store
      value = @stack.pop
      key = @stack.pop
      @heap[key] = value
    when :retrieve
      @stack.push(@heap[@stack.pop])
    else
      raise SyntaxError.new("Invalid syntax heap: unknown command (#{cmd}) at #{@pc}")
    end
  end

  # フロー制御 (n) の実行
  def execute_flow(cmd, params)
    case cmd
    when :label
      @labels[params] = @pc
    when :call
      @subroutines.push(@pc)
      @pc = @labels[params]
    when :jump
      @pc = @labels[params]
    when :jump_zero
      # 0以外の場合は何もしない
      unless convert_to_decimal(@stack.pop) == 0
        return
      end
      @pc = @labels[params]
    when :jump_negative
      # 負の数でない場合は何もしない
      unless convert_to_decimal(@stack.pop) < 0
        return
      end
      @pc = @labels[params]
    when :return
      @pc = @subroutines.pop
    when :exit
      exit
    else
      raise SyntaxError.new("Invalid syntax flow: unknown command (#{cmd}) at #{@pc}")
    end
  end

  # 入出力 (tn) の実行
  def execute_io(cmd, params)
    case cmd
    when :print_char
      STDOUT <<  convert_to_string(@stack.pop)
    when :print_num
      STDOUT <<  convert_to_decimal(@stack.pop)
    when :read_char
      @stack.push(STDIN.getc)
    when :read_num
      @stack.push(STDIN.gets.to_i)
    else
      raise SyntaxError.new("Invalid syntax io: unknown command (#{cmd}) at #{@pc}")
    end
  end

  # 2進数を10進数に変換
  def convert_to_decimal(binary)
    if binary.nil?
      throw StandardError.new("Error: value is nil.")
    end
    # 先頭の符号を取得
    sign = binary[0]
    # 先頭の符号を削除
    bin = binary.slice(0)
    # 2進数を10進数に変換
    decimal = bin.to_i(2)
    # 符号を付ける
    sign == "0" ? decimal : -decimal
  end

  # 10進数を2進数に変換
  def convert_to_binary(decimal)
    # 2進数に変換して、先頭に符号を付ける (0 => 正, 1 => 負)
    decimal.to_s(2).prepend(decimal < 0 ? "1" : "0")
  end

  # 2進数を文字列に変換
  def convert_to_string(binary)
    convert_to_decimal(binary).chr
  end

end

# WhiteSpaceの実行
#
WhiteSpace.new