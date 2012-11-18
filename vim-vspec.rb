require 'formula'

class VimVspec < Formula
  homepage 'https://github.com/kana/vim-vspec'
  url 'git://github.com/kana/vim-vspec.git', :using => :git

  def install
    prefix.install Dir['bin']
  end # def install
end # class VimVspec < Formula

