#!/usr/bin/env ruby

# Reads the bundles you want installed out of your $HOME/.vimrc file,
# then synchronizes .vim/bundles to match, downloading new repositories
# as needed.  It also deletes bundles that are no longer used.
#
# To specify a bundle in your .vimrc, just add a line like this:
#   " --- BUNDLE: git://git.wincent.com/command-t.git
# If you want a branch other than 'master', add the branch name on the end:
#   " --- BUNDLE: git://github.com/vim-ruby/vim-ruby.git noisy
# Or tag or sha1: (this results in a detached head, see 'git help checkout')
#   " --- BUNDLE: git://github.com/bronson/vim-closebuffer.git 0.2
#   " --- BUNDLE: git://github.com/tpope/vim-rails.git 42bb0699

require 'fileutils'
require 'open-uri'

# todo: not a fan of " --- BUNDLE:", hoping someone suggests something better.
# todo: make a way to execute shell commands after a plugin is downloaded?
#   i.e. run 'which rvm >/dev/null 2>&1 && rvm use system; rake make' in command-t


def print_bundle(dir, doc)
  version = date = ''
  FileUtils.cd(dir) do
    version = `git describe --tags 2>/dev/null`.chomp
    version = "n/a" if version == ''
    date = `git log -1 --pretty=format:%ai`.chomp
  end
  doc.printf "  - %-30s %-22s %s\n", "|#{dir}|", version, date.split(' ').first
end


def download(dir, url, tag, doc)
  tagstr = " at #{tag}" if tag
  if test ?d, dir
    puts "updating #{dir} from #{url}#{tagstr}"
    FileUtils.cd(dir) { `git fetch` }
  else
    puts "cloning #{dir} from #{url}#{tagstr}"
    `git clone -q #{url} #{dir}`
  end

  FileUtils.cd(dir) { `git checkout -q #{tag || 'master'}` }
  print_bundle(dir, doc)
end


def read_vimrc
  bundles = []
  File.open("#{ENV['HOME']}/.vimrc") do |file|
    file.each_line do |line|
      bundles.push $1 if line =~ /^\s*"\s*-*\s*BUNDLE:\s*(.*)$/
    end
  end
  bundles
end


def update_bundles(doc)
  existing_bundles = Dir['*']
  vimrc_bundles = read_vimrc

  vimrc_bundles.each do |line|
    url, tag = line.split
    dir = url.split('/').last.gsub(/^vim-|\.git$/, '').gsub(/\.vim$/, '')
    download(dir, url, tag, doc)
    existing_bundles.delete(dir)
  end

  existing_bundles.each do |dir|
    puts "Blowing away #{dir}"
    FileUtils.rm_rf(dir)
  end
end

doc_dir = "#{ENV['HOME']}/.vim/doc"
Dir.mkdir doc_dir unless test ?d, doc_dir 
File.open("#{doc_dir}/bundles.txt", "w") do |doc|
  doc.printf "%-32s %s %32s\n\n", "*bundles.txt*", "Bundles", "Version 0.1"
  doc.puts "These are the bundles installed on your system, along with their\n" +
    "versions and release dates.  Downloaded on #{Time.now}.\n\n" +
    "A version number of 'n/a' means upstream hasn't tagged any releases.\n"

  bundles_dir = "#{ENV['HOME']}/.vim/bundle"
  Dir.mkdir bundles_dir unless test ?d, bundles_dir
  FileUtils.cd(bundles_dir)
  update_bundles(doc)

  doc.puts "\n"
end

puts "updating helptags..."
`vim -e -c "call pathogen#helptags()" -c q`
puts "done!"
