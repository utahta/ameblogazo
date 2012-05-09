# coding: utf-8
require "ameblogazo/version"
require 'open-uri'
require 'nokogiri'
require 'fileutils'

module Ameblogazo
  class Gazo
    class GazoException < StandardError
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
    
    # 一番最初の画像のURLを取得する
    def _find_image_url(ameba_id)
      image_url = nil
      page = 1
      catch :image_found do
        loop do
          url = "http://ameblo.jp/#{ameba_id}/page-#{page}.html"
          begin
            html = open(url)
          rescue
            raise GazoException, "画像が見つからないです"
          end
          doc = Nokogiri::HTML(html)
          
          a = doc.xpath("//a")
          a.each do |node|
            if /http:\/\/ameblo.jp\/#{ameba_id}\/image-\d{11}-\d{11}.html/ =~ node[:href]
              image_url = node[:href]
              throw :image_found
            end
          end
          page += 1 # 次のページへ
        end
      end
      # 念のためチェック
      if image_url.nil?
        raise GazoException, "画像がみつからないです"
      end
      image_url
    end
  
    # カテゴライズしたパスを返す
    def _categorize(dir, categorize, img)
      # カテゴリー分け（タイトルとか日付）
      if categorize == "title"
        title = img[:alt]
        dir = "#{dir}/#{title}"
      elsif categorize == "date"
        if /http:\/\/stat.ameba.jp\/user_images\/(\d{8})\/.*/ =~ img[:src]
          date = $1
          dir = "#{dir}/#{date}"
        else
          print "うまく日付がとれなかったのでカテゴライズせずに保存します\n"
        end
      end
      dir
    end
    
    # ダウンロード対象のドキュメントを取得
    def _download_doc(url)
      html = open(url)
      doc = Nokogiri::HTML(html)
    end
    
    # ダウンロード対象のURLや保存先を取得
    def _download_info(doc, dir, categorize)
      img = doc.xpath('//img[@id="centerImg"]')
      unless img.empty?
        download_url = img[0][:src]
        filename = File.basename(download_url)
        
        # カテゴリー分け（タイトルとか日付）
        dir = _categorize(dir, categorize, img[0])
        
        # ディレクトリが存在しなければ作成する
        unless File.directory?(dir)
          print "ディレクトリを作成します #{dir}\n"
          FileUtils.mkdir_p(dir)
        end
        download_file = "#{dir}/#{filename}"
        return {:url=>download_url, :file=>download_file}
      end
      return {}
    end
    
    # 画像本体をダウンロード
    def _download_img(url, file)
      open(url) do |doc|
        open(file, 'w') do |fp|
          fp.print doc.read
        end
      end
      filename = File.basename(file)
      print "#{filename} をダウンロードしました\n"
    end
    
    # 次にダウンロードするべきURLを取得する
    def _download_next_url(doc)
      a = doc.xpath('//a[@id="imgLink"]')
      unless a.empty?
        image_url = a[0][:href] # 次の画像URL
      end
    end
    
    # 指定URLの物を保存する
    def _download(url, dir, categorize)
      doc = _download_doc(url)
      info = _download_info(doc, dir, categorize)
  
      if File.exists?(info[:file])
        print "もうダウロード済みみたいです\n"
      else
        _download_img(info[:url], info[:file])
      end
      _download_next_url(doc)
    end
    
    # ダウンロード済みの画像をみつけたら止める
    def _download_periodic(url, dir, categorize)
      doc = _download_doc(url)
      info = _download_info(doc, dir, categorize)
  
      if File.exists?(info[:file])
        print "ダウロード済みの見つけたので終了します\n"
        return nil
      else
        _download_img(info[:url], info[:file])
      end
      _download_next_url(doc)
    end
  
    # 画像を取得する
    # :ameba_id => アメーバID
    # :dir => 保存先ディレクトリ
    # :categorize => タイトル毎などに分類する（デフォルト無効）[nil, "title", "date"]
    # :num => 取得する枚数（新しいものから順番に）[数値]
    def get(options)
      options = _check_options(options)
      ameba_id = options[:ameba_id]
      categorize = options[:categorize]
      dir = options[:dir]
      num = options[:num]
      
      image_url = _find_image_url(ameba_id)
      
      if num
        num.times do |i|
          # 最初にみつけた画像から次の画像へと順番にたどってく
          image_url = _download(image_url, dir, categorize)
          break if image_url.nil?
          sleep(0.3)
        end
      else
        loop do
          # 最初にみつけた画像から次の画像へと順番にたどってく
          image_url = _download(image_url, dir, categorize)
          break if image_url.nil?
          sleep(0.3)
        end
      end
    end
    
    # 取得済みの画像がみつかるまで新しいものから順番に画像を取得する
    # 毎日定期的に取得したいひと向け
    def get_periodic(options)
      options = _check_options(options)
      ameba_id = options[:ameba_id]
      categorize = options[:categorize]
      dir = options[:dir]
      
      image_url = _find_image_url(ameba_id)
      loop do
        # 最初にみつけた画像から次の画像へと順番にたどってく
        image_url = _download_periodic(image_url, dir, categorize)
        break if image_url.nil?
        sleep(0.3)
      end
    end
  end
  
  def download(options)
    gazo = Gazo.new
    gazo.get(options)
  end
  
  def download_periodic(options)
    gazo = Gazo.new
    gazo.get_periodic(options)
  end
  
  module_function :download, :download_periodic
end
