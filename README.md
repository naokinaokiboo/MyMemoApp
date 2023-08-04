# My Memo App

## 概要
- RubyのWebアプリケーションフレームワークである「Sinatra」で作成したメモアプリです。
- 「使い方」の手順により、ローカルで実行することができます。

## 使い方
1. 任意のディレクトリで`git clone`を実行し、コピーを作成して下さい。
2. 必要なライブラリをインストールします。
```
$ bundle install
```
3. 環境変数用の`.env`ファイルを準備

プロジェクトルートに`.env`ファイルを作成し、以下の内容を追加して下さい。  
ただし、`change_me`の部分は独自に値を設定して下さい。
  ```
  SESSIONS_SECRET='change_me'
  ```

4. PostgreSQLを準備

以下のリンクからPostgreSQLをインストール、起動してください。  
https://www.postgresql.org/download/

5. データベースとテーブルを作成

以下のクエリでデータベース`memo_app`を作成してください。
```
CREATE DATABASE memo_app;
```
作成したデータベース`memo_app`に、以下のクエリで`memos`テーブルを作成して下さい。
```
CREATE TABLE memos (
  id uuid PRIMARY KEY,
  title varchar(30) NOT NULL,
  content varchar(200) NOT NULL,
  created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

6. データベース接続情報ファイルを編集

必要に応じて、`database.yml`を自身の環境に合わせて編集してください。
```
db:
  host: localhost
  port: 5432
  dbname: memo_app
  user:
  password:
```

7. アプリケーションを起動します

```
$ bundle exec ruby app.rb
```

8. ブラウザから以下のURLにアクセスして下さい
```
http://localhost:4567/memos
```
