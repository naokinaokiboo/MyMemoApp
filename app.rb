# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader'
require 'pg'
require 'securerandom'
require 'dotenv/load'
require 'yaml'

NUM_OF_MEMOS_PER_PAGE = 3
NUM_OF_PAGE_LINK_BEFORE_CURRENT = 3
NUM_OF_PAGE_LINK_AFTER_CURRENT = 3
TABLE_NAME = 'memos'
DB_CONFIG_FILE = './database.yml'

class Memo
  attr_reader :id
  attr_accessor :title, :content

  class << self
    def all
      sql = "SELECT * FROM #{TABLE_NAME} ORDER BY created_at;"
      all_memos = execute(sql)
      all_memos.map do |memo|
        Memo.new(memo['title'], memo['content'], memo['id'])
      end
    end

    def find_by_id(id)
      sql = "SELECT * FROM #{TABLE_NAME} WHERE id = $1;"
      result = execute(sql, [id])
      target = result.first
      target && Memo.new(target['title'], target['content'], target['id'])
    end

    def execute(sql, params = [])
      @db_conf ||= YAML.load_file(DB_CONFIG_FILE)['db']
      @connection ||= PG::Connection.new(@db_conf)
      @connection.exec_params(sql, params)
    end

    def size
      sql = "SELECT COUNT(*) FROM #{TABLE_NAME};"
      result = execute(sql)
      result.first['count'].to_i
    end

    def close_connection
      return if @connection.nil?

      @connection.close
      @connection = nil
    end
  end

  def initialize(title, content, id = nil)
    @id = id || SecureRandom.uuid
    @title = title
    @content = content
  end

  def add
    sql = "INSERT INTO #{TABLE_NAME} (id, title, content) VALUES ($1, $2 ,$3);"
    Memo.execute(sql, [@id, @title, @content])
  end

  def delete
    sql = "DELETE FROM #{TABLE_NAME} WHERE id = $1;"
    Memo.execute(sql, [@id])
  end

  def update
    sql = "UPDATE #{TABLE_NAME} SET title = $1, content = $2 WHERE id = $3;"
    Memo.execute(sql, [@title, @content, @id])
  end
end

use Rack::Session::Cookie,
    expire_after: 3600,
    secret: ENV['SESSIONS_SECRET']

helpers do
  def h(text)
    Rack::Utils.escape_html(text)
  end
end

after do
  Memo.close_connection
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

  @memos = Memo.all
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
  memos = Memo.all
  @memo, index = nil
  memos.each_with_index do |memo, idx|
    if memo.id == memo_id
      @memo = memo
      index = idx
    end
  end

  redirect_to_not_found if index.nil?

  @prev_memo_id = index.zero? ? nil : memos[index - 1].id
  @next_memo_id = index == memos.size - 1 ? nil : memos[index + 1].id

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

def redirect_to_not_found
  # リダイレクト先URLに特別な意味はなく、存在しないURLであればよい
  redirect('404_not_found')
end
