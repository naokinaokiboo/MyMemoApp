# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader'
require 'json'
require 'securerandom'

NUM_OF_MEMOS_PER_PAGE = 3
NUM_OF_PAGE_LINK_BEFORE_CURRENT = 3
NUM_OF_PAGE_LINK_AFTER_CURRENT = 3
JSON_FILE_PATH = './public/memos.json'

class Memo
  attr_reader :id
  attr_accessor :title, :content

  class << self
    def all
      all_memos = load_json
      all_memos.map do |memo|
        Memo.new(memo['title'], memo['content'], memo['id'])
      end
    end

    def find_by_id(id)
      all_memos = load_json
      target = all_memos.find { |memo| memo['id'] == id }
      target && Memo.new(target['title'], target['content'], target['id'])
    end

    def load_json
      unless File.exist?(JSON_FILE_PATH)
        File.open(JSON_FILE_PATH, 'w') do |file|
          file.write('[]')
        end
      end
      JSON.load_file(JSON_FILE_PATH)
    end

    def size
      load_json.size
    end
  end

  def initialize(title, content, id = nil)
    @id = id || SecureRandom.uuid
    @title = title
    @content = content
  end

  def add
    all_memos = Memo.load_json
    all_memos << { 'id' => @id, 'title' => @title, 'content' => @content }
    write_to_json_file(all_memos)
  end

  def delete
    all_memos = Memo.load_json
    all_memos.delete_if { |memo| memo['id'] == @id }
    write_to_json_file(all_memos)
  end

  def update
    all_memos = Memo.load_json
    target_memo = all_memos.find { |memo| memo['id'] == @id }
    target_memo['title'] = @title
    target_memo['content'] = @content

    write_to_json_file(all_memos)
  end

  private

  def write_to_json_file(all_memos)
    File.open(JSON_FILE_PATH, 'w') do |file|
      JSON.dump(all_memos, file)
    end
  end
end

use Rack::Session::Cookie,
    expire_after: 3600,
    secret: '240b204d-8239-4d61-9bc3-607718dc984b'

helpers do
  def h(text)
    Rack::Utils.escape_html(text)
  end

  def redirect_to_not_found
    # リダイレクト先URLに特別な意味はなく、存在しないURLであればよい
    redirect('404_not_found')
  end
end

get '/' do
  session[:page] = 1
  redirect('/memos')
end

get '/memos/page=:num' do |page_num|
  redirect_to_not_found if page_num.to_i > calc_num_of_page

  session[:page] = page_num.to_i
  redirect('/memos')
end

get '/memos' do
  session[:page] = 1 if session[:page].nil?
  @current_page = session[:page].to_i

  @memo_objects = Memo.all
  @first_index_to_display = NUM_OF_MEMOS_PER_PAGE * (@current_page - 1) + 1
  @last_index_to_display = NUM_OF_MEMOS_PER_PAGE * @current_page

  @start_page_num = @current_page - NUM_OF_PAGE_LINK_BEFORE_CURRENT
  @end_page_num = @current_page + NUM_OF_PAGE_LINK_AFTER_CURRENT
  @num_of_page = calc_num_of_page

  erb :contents
end

get '/memos/new' do
  erb :new
end

get '/memos/:id' do |memo_id|
  memo_objects = Memo.all
  @memo, index = nil
  memo_objects.each_with_index do |memo_ob, idx|
    if memo_ob.id == memo_id
      @memo = memo_ob
      index = idx
    end
  end

  @prev_memo_id = index.zero? ? nil : memo_objects[index - 1].id
  @next_memo_id = index == memo_objects.size - 1 ? nil : memo_objects[index + 1].id

  erb :show
end

get '/memos/:id/edit' do |memo_id|
  @memo = Memo.find_by_id(memo_id)
  redirect_to_not_found if @memo.nil?

  erb :edit
end

post '/memos' do
  memo = Memo.new(params['title'], params['content'])
  memo.add

  session[:page] = calc_num_of_page
  redirect('/memos')
end

patch '/memos/:id' do |memo_id|
  target_memo = Memo.find_by_id(memo_id)
  target_memo.title = params['title']
  target_memo.content = params['content']
  target_memo.update

  redirect("/memos/#{target_memo.id}")
end

delete '/memos/:id' do |memo_id|
  target_memo = Memo.find_by_id(memo_id)
  target_memo.delete

  num_of_page = calc_num_of_page
  session[:page] = num_of_page if session[:page] > num_of_page

  redirect('/memos')
end

not_found do
  '404 Not Found'
end

def calc_num_of_page
  (Memo.size / NUM_OF_MEMOS_PER_PAGE.to_f).ceil
end
