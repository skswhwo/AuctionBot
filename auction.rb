require 'telegram/bot'
require './Item'
require './Participant'
require './Dealer'

@token = ''
@auction_chat_id = ''  #test

public_command = [  
  "/status",
  "/regist"
]

command =  [
  "/command",
  "/check",
  "/status",
  "/setTitle", 
  "/setDesc", 
  "/setPrice", 
  "/item",
  "/start", 
  "/finish",
  "/stop"]

  Telegram::Bot::Client.run(@token, logger: Logger.new("output.log")) do |bot|  
  @bot = bot
  @bot.logger.info('Bot has been started')
  
  @current_item     = nil
  @dealer           = nil
  @ongoing_auction  = false
  @histories        = []  
  @input_command    = nil
  @timer            = nil
  
  def isDealer?
    @dealer != nil && @dealer.chat_id == @message.chat.id
  end
  
  def initialize_auction
    @bot.logger.info("initialize_auction")
    @dealer           = nil
    @item             = Item.new
    @ongoing_auction  = false
    @histories        = []
    @input_command    = nil
    @timer.kill if @timer
  end
  
  def current_price
    if @histories.count > 0
      @histories.last.price
    else
      @item.price
    end
  end
  
  def last_participant
    if @histories.count > 0
      @histories.last
    else
      nil
    end
  end
  
  @bot.listen do |message|
    @message = message
  
    def check_timer
      @timer.kill if @timer
      @timer = Thread.new do
        sleep 540
        if @ongoing_auction
          @bot.api.send_message(chat_id: @auction_chat_id, text: "경매 종료 1분전 입니다.")
          sleep 60
          if @ongoing_auction
            if last_participant 
              @bot.api.send_message(chat_id: @auction_chat_id, text: "경매가 종료되었습니다")
              @bot.api.send_message(chat_id: @auction_chat_id, text: "최종 낙찰가는 #{last_participant.price}원 입니다")
              @bot.api.send_message(chat_id: @auction_chat_id, text: "#{last_participant.name}님 축하드립니다. 짝짝짝")
              @bot.api.send_message(chat_id: last_participant.chat_id, text: "#{last_participant.name}님 낙찰 축하드립니다. 짝짝짝")
            else 
              @bot.api.send_message(chat_id: @auction_chat_id, text: "경매가 유찰되었습니다.\n다음에 또 만나요~")
            end
            initialize_auction
          end
        end
      end
    end
      
    def getPrice
      price = Integer(@message.text) rescue nil
      @bot.api.send_message(chat_id: @message.chat.id, text: "가격을 잘못 입력하셨습니다. ex> 2000") if price == nil
      price
    end
    
    if message.text.start_with?('/message,')
      
      @bot.api.send_message(chat_id: @auction_chat_id, text: message.text[9..-1])
      
    elsif isDealer?
      if command.include?(message.text)
        #command        
        
        @input_command = nil
        
        case message.text
        when '/command'
          
          @bot.api.send_message(chat_id: @dealer.chat_id, text: command.inspect)
          
        when '/check'
          
          @bot.logger.info(message.inspect)
          @bot.logger.info(message.chat.id)
          @bot.api.send_message(chat_id: @dealer.chat_id, text: "debug, #{message.from.first_name}")
          
        when '/status'
          
          if @ongoing_auction
            @bot.api.send_message(chat_id: @auction_chat_id, text: "진행 중인 상품은 '#{@item.title}' 입니다")
            @bot.api.send_message(chat_id: @auction_chat_id, text: "#{@item.desc}")
            @bot.api.send_message(chat_id: @auction_chat_id, text: "현재 호가는 #{current_price}원 입니다")
            if last_participant
              @bot.api.send_message(chat_id: @dealer.chat_id, text: "#{last_participant.name}님이 최고가 입니다")
            else
              @bot.api.send_message(chat_id: @dealer.chat_id, text: "아직 참가자가 없습니다.")
            end
          else
            @bot.api.send_message(chat_id: message.chat.id, text: "아직 경매 물품이 올라오지 않았습니다.")
          end       
        
        when '/setTitle'
          @bot.api.send_message(chat_id: message.chat.id, text: "상품 이름을 입력해 주세요")
          @input_command = :setTitle
        when '/setDesc'
          @bot.api.send_message(chat_id: message.chat.id, text: "상품 설명을 입력해 주세요")
          @input_command = :setDesc
        when '/setPrice'
          @bot.api.send_message(chat_id: message.chat.id, text: "상품 가격을 입력해 주세요")
          @input_command = :setPrice
        when '/item'
          if @item.title
            @bot.api.send_message(chat_id: message.chat.id, text: "상품: #{@item.title}")
          else
            @bot.api.send_message(chat_id: message.chat.id, text: "need to enter 'setTitle'")
          end
          
          if @item.desc
            @bot.api.send_message(chat_id: message.chat.id, text: "상세정보: #{@item.desc}")
          else
            @bot.api.send_message(chat_id: message.chat.id, text: "need to enter 'setDesc'")
          end
          
          if @item.price
            @bot.api.send_message(chat_id: message.chat.id, text: "가격: #{@item.price}")
          else
            @bot.api.send_message(chat_id: message.chat.id, text: "need to enter 'setPrice'")
          end
        when '/start'
          if @item.isValid?
            @bot.api.send_message(chat_id: message.chat.id, text: "경매를 시작합니다")
            @bot.api.send_message(chat_id: @auction_chat_id, text: "새로운 경매 물품이 올라왔습니다")
            @bot.api.send_message(chat_id: @auction_chat_id, text: @item.title)
            @bot.api.send_message(chat_id: @auction_chat_id, text: @item.desc)
            @bot.api.send_message(chat_id: @auction_chat_id, text: "경매가는 #{@item.price}원부터 시작하겠습니다")
            @bot.api.send_message(chat_id: @auction_chat_id, text: "마지막 호가 후, 10분이 지나면 경매가 종료됩니다")
            @ongoing_auction = true
            check_timer
          else
            @bot.api.send_message(chat_id: message.chat.id, text: "경매 물품 정보를 아직 입력하지 않았습니다")
          end
        when '/finish'

          if @ongoing_auction == false
            @bot.api.send_message(chat_id: message.chat.id, text: "진행 중인 경매가 없습니다.")
          elsif last_participant 
            @bot.api.send_message(chat_id: @auction_chat_id, text: "경매가 종료되었습니다")
            @bot.api.send_message(chat_id: @auction_chat_id, text: "최종 낙찰가는 #{last_participant.price}원 입니다")
            @bot.api.send_message(chat_id: @auction_chat_id, text: "#{last_participant.name}님 축하드립니다. 짝짝짝")
            @bot.api.send_message(chat_id: last_participant.chat_id, text: "#{last_participant.name}님 낙찰 축하드립니다. 짝짝짝")
          else 
            @bot.api.send_message(chat_id: @auction_chat_id, text: "경매가 유찰되었습니다.\n다음에 또 만나요~")
          end
          initialize_auction
          
        when '/stop'
          @bot.api.send_message(chat_id: message.chat.id, text: "경매를 종료합니다")
          initialize_auction
        end  
        
      else
        #configuration or price
        
        if @input_command
          if @input_command == :setTitle
            @item.title = message.text
            @input_command = nil
          elsif @input_command == :setDesc
            @item.desc = message.text
            @input_command = nil
          elsif @input_command == :setPrice
            @item.price = getPrice
            @input_command = nil if @item.price != nil
          end
        else
          if @ongoing_auction
            
            if getPrice
              if @item.price < getPrice
                participant         = Participant.new
                participant.name    = message.from.first_name
                participant.chat_id = message.chat.id 
                participant.price   = getPrice
                @histories << participant
                @bot.api.send_message(chat_id: @auction_chat_id, text: "#{participant.price}원 나왔습니다")              
                @bot.logger.info("#{@item.title} > \t #{participant.name} \t #{getPrice}")
                check_timer
              else 
                @bot.api.send_message(chat_id: message.chat.id, text: "호가보다 적은 금액을 입력하셨습니다")
              end
            end
            
          end
        end        
      end      
      
    else
      if public_command.include?(message.text) 
        #message (status, regist)
        case message.text
        when '/status'
          
          if @ongoing_auction
            @bot.api.send_message(chat_id: message.chat.id, text: "진행 중인 상품은 '#{@item.title}' 입니다")
            @bot.api.send_message(chat_id: message.chat.id, text: "#{@item.desc}")
            @bot.api.send_message(chat_id: message.chat.id, text: "현재 호가는 #{current_price}원 입니다")
            if last_participant
              if last_participant.chat_id == message.chat.id
                @bot.api.send_message(chat_id: message.chat.id, text: "현재 고객님이 최고가 입니다")
              end
            else
              @bot.api.send_message(chat_id: message.chat.id, text: "아직 참가자가 없습니다.")
            end
          else
            @bot.api.send_message(chat_id: message.chat.id, text: "아직 경매 물품이 올라오지 않았습니다.")
          end       
          
        when '/regist'          
          if @dealer
            @bot.api.send_message(chat_id: message.chat.id, text: "경매가 진행중이거나, 등록 절차가 진행중입니다.")
          else
            initialize_auction
            @dealer = Dealer.new
            @dealer.chat_id = message.chat.id
            @bot.api.send_message(chat_id: message.chat.id, text: "경매 등록 절차를 진행합니다.")
          end
        end 
           
      else
        #message
        if @ongoing_auction
          
          if getPrice
            if @item.price < getPrice
              participant         = Participant.new
              participant.name    = message.from.first_name
              participant.chat_id = message.chat.id 
              participant.price   = getPrice
              @histories << participant
              @bot.api.send_message(chat_id: @auction_chat_id, text: "#{participant.price}원 나왔습니다")
              @bot.logger.info("#{@item.title} > \t #{participant.name} \t #{getPrice}")
              check_timer
            else 
              @bot.api.send_message(chat_id: message.chat.id, text: "호가보다 적은 금액을 입력하셨습니다")
            end
          end
          
        end
      end            
    end
    
  end   
end
