require 'dotenv/load'
require 'trello'
require 'slack-notifier'

# ---------------------------------------------------------------
# Trello 初期設定

Trello.configure do |config|
  config.developer_public_key = ENV['API_KEY']
  config.member_token = ENV['TOKEN']
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
def send_slack(today_tasks)
  slack_notifier = Slack::Notifier.new(ENV['WEBHOOK_URL'])

  message = <<"MESSAGE"
:pencil2::pencil2::pencil2: 今日のタスク :pencil2::pencil2::pencil2:

            :mario2::dash: メイン :mario2::dash:
MESSAGE

  today_tasks[:main].each_with_index do |task, i|
    message += ":small_orange_diamond:【M#{format('%02d', i + 1)}】 *_#{task.name}_*\n"

    task.due.nil? ? limit = "なるはや" : limit = (task.due + 9.hour).to_s[0..-5]
    message += "    :alarm_clock: `#{limit}`\n\n"
  end

  message += "\n            :mario2::dash: 技術向上 :mario2::dash:\n"
  today_tasks[:tech].each_with_index do |task, i|
    message += ":small_orange_diamond:【M#{format('%02d', i + 1)}】 *_#{task.name}_*\n"

    task.due.nil? ? limit = "なるはや" : limit = (task.due + 9.hour).to_s[0..-5]
    message += "    :alarm_clock: `#{limit}`\n\n"
  end

  message += "\n            :mario2::dash: がんばろ :mario2::dash:\n"

  slack_notifier.ping(message)
end

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

send_slack(today_tasks)
