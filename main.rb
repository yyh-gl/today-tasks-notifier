require 'dotenv/load'
require 'trello'
require 'slack-notifier'

# ---------------------------------------------------------------
## 初期設定

## Trello
Trello.configure do |config|
  config.developer_public_key = ENV['API_KEY']
  config.member_token = ENV['TOKEN']
end

## システム全般
# 今日の開始時間と終了時間を取得
# タイムゾーンは関係ない。Timeクラスが吸収してくれる。
now = Time.now
TODAY_START_TIME = Time.local(now.year, now.month, now.day, 0, 0, 0)
TODAY_END_TIME = Time.local(now.year, now.month, now.day, 23, 59, 59)

# ---------------------------------------------------------------
## ライブラリ

# 期限が本日中または期限切れのタスクとWIPリストにあるタスクを取得
def get_today_tasks(lists)
  today_task_cards = []
  limit_over_cards = []
  lists.each do |list|
    next if list.name == 'DONE'

    if list.name == 'WIP'
      # TODO: もっとスマートにできるはず
      list.cards.each do |card|
        if card.due.present? && card.due < TODAY_START_TIME
          limit_over_cards << card
        else
          today_task_cards << card
        end
      end
    else
      list.cards.each do |card|
        next if card.due.nil?

        if TODAY_START_TIME <= card.due && card.due <= TODAY_END_TIME
          today_task_cards << card
        elsif card.due < TODAY_START_TIME
          limit_over_cards << card
        end
      end
    end
  end

  return today_task_cards, limit_over_cards
end

# Slack通知
# TODO: main と tech の決め打ち部分を可変にして汎用的にする
def send_slack(today_tasks)
  slack_notifier = Slack::Notifier.new(ENV['WEBHOOK_URL'])

  message = <<"MESSAGE"
:pencil2::pencil2::pencil2: 今日のタスク :pencil2::pencil2::pencil2:

           :mega: 総タスク数 #{format('%02d', today_tasks[:main].size + today_tasks[:tech].size)} 個 :mega:
   :space_invader: → 期限切れタスク数 #{format('%02d', today_tasks[:main_limit].size + today_tasks[:tech_limit].size)} 個 :space_invader:


           :mario2::dash: :kana-me::kana-i::kana-nn: :mario2::dash:

MESSAGE

  last_index = 0

  # メインボード内のタスク一覧
  today_tasks[:main].each_with_index do |task, i|
    if task.due.present? && TODAY_START_TIME <= task.due && task.due <= TODAY_END_TIME
      message += ":cubimal_chick:【M#{format('%02d', i + 1)}】 *_#{task.name}_*\n"
    else
      message += ":small_orange_diamond:【M#{format('%02d', i + 1)}】 *_#{task.name}_*\n"
    end

    message += "    :curly_loop: _#{task.short_url} _\n"

    task.due.nil? ? limit = "なるはや" : limit = (task.due + 9.hour).to_s[0..-5]
    message += "    :alarm_clock: `#{limit}`\n\n"

    last_index = i + 1
  end

  # メインボード内の期限が切れているタスク一覧
  if today_tasks[:main_limit].present?
    today_tasks[:main_limit].each do |task|
      last_index += 1

      message += ":space_invader:【M#{format('%02d', last_index)}】 *_#{task.name}_*\n"
      message += "    :curly_loop: _#{task.short_url} _\n"
      message += "    :alarm_clock: `#{(task.due + 9.hour).to_s[0..-5]}` :face_palm:\n\n"
    end
  end

  # 技術向上ボード内のタスク一覧
  message += "\n          :mario2::dash: :kanji-waza::kanji-jutsu::kanji-mukau::kanji-ue: :mario2::dash:\n\n"
  today_tasks[:tech].each_with_index do |task, i|
    if task.due.present? && TODAY_START_TIME <= task.due && task.due <= TODAY_END_TIME
      message += ":cubimal_chick:【T#{format('%02d', i + 1)}】 *_#{task.name}_*\n"
    else
      message += ":small_orange_diamond:【T#{format('%02d', i + 1)}】 *_#{task.name}_*\n"
    end

    message += "    :curly_loop: _#{task.short_url} _\n"

    task.due.nil? ? limit = "なるはや" : limit = (task.due + 9.hour).to_s[0..-5]
    message += "    :alarm_clock: `#{limit}`\n\n"

    last_index = i + 1
  end

  # 技術向上ボード内の期限が切れているタスク一覧
  if today_tasks[:tech_limit].present?
    today_tasks[:tech_limit].each_with_index do |task|
      last_index += 1

      message += ":space_invader:【T#{format('%02d', last_index)}】 *_#{task.name}_*\n"
      message += "    :curly_loop: _#{task.short_url} _\n"
      message += "    :alarm_clock: `#{(task.due + 9.hour).to_s[0..-5]}` :face_palm:\n\n"
    end
  end

  message += "\n            :mario2::dash: がんばろ :mario2::dash:\n"

  slack_notifier.ping(message)
end

# ---------------------------------------------------------------
## メイン処理

# 指定ボードを取得
main_board = Trello::Board.find(ENV['MAIN_BOARD_ID'])
tech_board = Trello::Board.find(ENV['TECH_BOARD_ID'])

# 指定ボードに紐づくリスト一覧を取得
main_lists = main_board.lists
tech_lists = tech_board.lists

# リストから今日やるべきタスクを取得
main_today_tasks, main_limit_over_tasks = get_today_tasks(main_lists)
tech_today_tasks, tech_limit_over_tasks = get_today_tasks(tech_lists)

today_tasks = {
  main: main_today_tasks,
  main_limit: main_limit_over_tasks,
  tech: tech_today_tasks,
  tech_limit: tech_limit_over_tasks,
}

send_slack(today_tasks)
