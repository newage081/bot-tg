require 'bundler/setup'
require 'telegram/bot'
require 'active_record'
require 'prawn'
require 'prawn/table'
require 'dotenv/load'

# Подключение к базе данных
ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'])

# Модели ActiveRecord
class Personal < ActiveRecord::Base
  has_many :vaccinations
end

class Vaccine < ActiveRecord::Base
  has_many :vaccinations
end

class Vaccination < ActiveRecord::Base
  belongs_to :personal
  belongs_to :vaccine
end

class VaccinationSchedule < ActiveRecord::Base
  belongs_to :personal
  belongs_to :vaccine
  belongs_to :room
end

# Отчеты
def calculate_vaccine_counts(month)
  vaccine_counts = Hash.new(0)
  scheduled_vaccinations = VaccinationSchedule.where(vaccination_date: month.beginning_of_month..month.end_of_month)

  scheduled_vaccinations.each do |schedule|
    vaccine_counts[schedule.vaccine.name] += 1
  end

  vaccine_counts
end

def generate_vaccine_order_report(month)
  vaccine_counts = calculate_vaccine_counts(month)

  pdf = Prawn::Document.new
  font_path = Rails.root.join("app/assets/fonts/NotoSans-Regular.ttf")
  pdf.font_families.update("NotoSans" => { normal: font_path.to_s })
  pdf.font "NotoSans"

  pdf.text "Количество необходимых вакцин на #{month.strftime('%m.%y')}", size: 20
  pdf.move_down 20

  vaccine_counts.each do |vaccine_name, count|
    pdf.text "#{vaccine_name} -- #{count} шт.", size: 14
    pdf.move_down 10
  end

  pdf.render
end

# Telegram бот
Telegram::Bot::Client.run(ENV['7417079281:AAH2LAjLcOjGBT7boK7iRkxO5s8z1piCZvc']) do |bot|
  bot.listen do |message|
    case message.text
    when '/start'
      bot.api.send_message(chat_id: message.chat.id, text: "Привет! Я бот для генерации отчётов о вакцинации.")
    when '/generate_order_report'
      month = Date.today.beginning_of_month
      pdf_data = generate_vaccine_order_report(month)

      bot.api.send_document(chat_id: message.chat.id, document: Faraday::UploadIO.new(StringIO.new(pdf_data), 'application/pdf'))
    when '/generate_employee_report'
      # Здесь можно добавить логику для генерации отчета о вакцинации сотрудников
      bot.api.send_message(chat_id: message.chat.id, text: "Эта функция еще в разработке.")
    else
      bot.api.send_message(chat_id: message.chat.id, text: "Я не понимаю вашего сообщения.")
    end
  end
end
