require 'dotenv/load'
require 'trello'

# ---------------------------------------------------------------
# Trello 初期設定

Trello.configure do |config|
  config.developer_public_key = ENV['DEVELOPER_PUBLIC_KEY']
  config.member_token = ENV['MEMBER_TOKEN']
end

# ---------------------------------------------------------------
# ライブラリ

# 期限が本日中のタスクとWIPリストにあるタスクを取得
def get_today_tasks(lists)
  # 今日の開始時間と終了時間を取得
  # タイムゾーンは関係ない。Timeクラスが吸収してくれる。
  now = Time.now
  today_start_time = Time.local(now.year, now.month, now.day, 0, 0, 0)
  today_end_time = Time.local(now.year, now.month, now.day, 23, 59, 59)

  today_task_cards = []
  lists.each do |list|
    next if list.name == 'DONE'

    if list.name == 'WIP'
      # TODO: もっとスマートにできるはず
      list.cards.each do |card|
        today_task_cards << card
      end
    else
      list.cards.each do |card|
        next if card.due.nil?

        today_task_cards << card if today_start_time <= card.due && card.due <= today_end_time
      end
    end
  end
  today_task_cards
end

# Slack通知


# ---------------------------------------------------------------
# メイン処理

# 指定ボードを取得
main_board = Trello::Board.find(ENV['MAIN_BOARD_ID'])
tech_board = Trello::Board.find(ENV['TECH_BOARD_ID'])

# 指定ボードに紐づくリスト一覧を取得
main_lists = main_board.lists
tech_lists = tech_board.lists

# リストから今日やるべきタスクを取得
today_tasks = {
  main: get_today_tasks(main_lists),
  tech: get_today_tasks(tech_lists)
}
