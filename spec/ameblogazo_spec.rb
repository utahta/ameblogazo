# coding: utf-8
require 'spec_helper'

describe Ameblogazo::Gazo do
  before(:all) do
    @gazo = Ameblogazo::Gazo.new
  end

  describe "オプションをチェックするとき" do
    it "nilだったら例外を投げること" do
      expect{ @gazo._check_options(nil) }.to raise_error(Ameblogazo::Gazo::GazoException)
    end
    it "ディレクトリが指定されていなかったら例外を投げること" do
      options = {}
      expect{ @gazo._check_options(options) }.to raise_error(Ameblogazo::Gazo::GazoException)
    end
    it "枚数指定の値が数値以外だったら例外を投げること" do
      options = {:dir=>'/tmp', :num=>'abc'}
      expect{ @gazo._check_options(options) }.to raise_error(Ameblogazo::Gazo::GazoException)
    end
  end
  
  describe "最初の画像のURLを取得するとき" do
    it "無効なIDが渡されたら例外を投げること" do
      expect{ @gazo._find_image_url("ameblogazotest") }.to raise_error(Ameblogazo::Gazo::GazoException)
    end
    
    it "返ってくる値がnilではないこと" do
      @gazo._find_image_url("staff").nil?.should == false
    end
  end
  
  describe "画像をダウンロードするとき" do
    before(:all) do
      url = @gazo._find_image_url("staff")
      @gazo.instance_eval{@driver.visit(url)}
    end
    
    it "ダウンロードURLや保存先が取得できること" do
      @gazo._get_info("/tmp", "title").empty?.should == false
    end
    
    it "次の画像に移動できること" do
      @gazo._next_page
    end
  end
end
