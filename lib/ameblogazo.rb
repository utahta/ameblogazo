# coding: utf-8
require "ameblogazo/version"
require 'open-uri'
require 'fileutils'
require 'capybara'
require 'capybara/dsl'
require 'capybara-webkit'

module Ameblogazo
  class Gazo
    class GazoException < StandardError
    end
    
    class Driver
      include Capybara::DSL
    end

    class WebkitDriver < Driver
      def initialize()
        Capybara.default_driver = :webkit
        Capybara.javascript_driver = :webkit
      end
    end

    class SeleniumDriver < Driver
      def initialize()
        Capybara.default_driver = :selenium
        Capybara.javascript_driver = :selenium
      end
    end
    
    # オプションチェック
    def _check_options(options)
      if options.nil? or !options.is_a?(Hash)
        raise GazoException, "オプションがnil、もしくはハッシュじゃないです"
      end
      if options[:dir].nil?
        raise GazoException, "ディレクトリ(:dir)を指定してください"
      end
      if options[:num]
        options[:num] = options[:num].to_s
        if (/^\d+$/ =~ options[:num]).nil?
          raise GazoException, "数値じゃないです"
          return
        end
        options[:num] = options[:num].to_i
      end
      options
    end
    
    # driver初期化
    def _init_driver(selenium)
      if selenium
        @driver = SeleniumDriver.new
      else
        @driver = WebkitDriver.new
      end
    end
    
    # 一番最初の画像のURLを取得する
    def _find_image_url(ameba_id)
      puts "検索中..."
      image_url = nil
      catch :image_found do
        100.times do |i|
          page = i+1
          url = "http://ameblo.jp/#{ameba_id}/page-#{page}.html"
          begin
            html = open(url)
          rescue
            raise GazoException, "画像が見つからなかったです"
          end
          doc = Nokogiri::HTML(html)
          
          # 有効なameba_idか確認
          sorry = doc.xpath("//body[@class='sorry']")
          unless sorry.empty?
            raise GazoException, "存在しないIDです"
          end
          
          a = doc.xpath("//a")
          a.each do |node|
            if /http:\/\/ameblo.jp\/#{ameba_id}\/image-\d{11}-\d{11}.html/ =~ node[:href]
              image_url = node[:href]
              throw :image_found
            end
          end
          sleep(0.1)
        end
      end
      # 念のためチェック
      if image_url.nil?
        raise GazoException, "画像がみつからなかったです"
      end
      image_url
    end
    
    # ダウンロード対象のURLや保存先を取得
    def _get_info(dir, categorize)
      img = @driver.find(:xpath, '//img[@id="imgItem"]')
      download_url = img[:src]
      filename = File.basename(download_url)
      title = @driver.find("#entryLink").text
      date = download_url[/\d{8}/]
      
      # カテゴリー分け（タイトルとか日付）
      if categorize == "title"
        dir = "#{dir}/#{title}"
      elsif categorize == "date"
        if date
          dir = "#{dir}/#{date}"
        else
          puts "うまく日付がとれなかったのでカテゴライズせずに保存します"
        end
      end
      
      # ディレクトリが存在しなければ作成する
      unless File.directory?(dir)
        print "ディレクトリを作成します #{dir}\n"
        FileUtils.mkdir_p(dir)
      end
      download_file = "#{dir}/#{filename}"
      {:url=>download_url, :file=>download_file, :title=>title, :date=>date}
    end
        
    # 次にダウンロードするべき画像を開く
    def _next_page()
      @driver.find("#nextNavi").click
    end

    # 画像をダウンロードして保存
    def _save_img(url, file)
      open(url) do |doc|
        open(file, 'w') do |fp|
          fp.print doc.read
        end
      end
      filename = File.basename(file)
      puts "#{filename} を保存しました"
    end
    
    # 画像を保存する
    # :ameba_id => アメーバID
    # :dir => 保存先ディレクトリ
    # :categorize => タイトル毎などに分類する（デフォルト無効）[nil, "title", "date"]
    # :num => 取得する枚数（新しいものから順番に）[数値]
    def fetch(options)
      options = _check_options(options)
      ameba_id = options[:ameba_id]
      categorize = options[:categorize]
      dir = options[:dir]
      num = options[:num]
      
      # driver初期化
      _init_driver(options[:selenium])
      
      # 画像ページに移動
      @driver.visit(_find_image_url(ameba_id))
      
      # 最初にみつけた画像から次の画像へと順番にたどってく
      info_list = []
      loop.with_index do |_, i|
        break if i == num # 指定枚数で終了
        info = _get_info(dir, categorize)
        break if !info_list[0].nil? and info_list[0][:file] == info[:file]
        info_list.push(info)
        
        if File.exists?(info[:file])
          if num
            puts "既にダウンロードされている画像です"
          else
            puts "ダウンロード済みの画像が見つかったので終了します"
            break
          end
        else
          _save_img(info[:url], info[:file])
        end
        _next_page
        sleep(0.5)
      end
    end
    
    # 画像の情報を取得する
    def info(options)
      options = _check_options(options)
      ameba_id = options[:ameba_id]
      categorize = options[:categorize]
      dir = options[:dir]
      num = options[:num]
      
      # driver初期化
      _init_driver(options[:selenium])
      
      # 画像ページに移動
      @driver.visit(_find_image_url(ameba_id))
      
      # 最初にみつけた画像から次の画像へと順番にたどってく
      info_list = []
      loop.with_index do |a, i|
        break if i == num # 指定枚数で終了
        info = _get_info(dir, categorize)
        break if !info_list[0].nil? and info_list[0][:file] == info[:file]
        info_list.push(info)
        _next_page
        sleep(0.5)
      end
      info_list
    end
  end
  
  def download(options)
    gazo = Gazo.new
    gazo.fetch(options)
  end
  
  def info(options)
    gazo = Gazo.new
    gazo.info(options)
  end
  
  module_function :download, :info
end
