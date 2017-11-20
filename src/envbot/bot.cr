require "slack"

module EnvBot
  class Bot
    def initialize()
      @envs = {} of String => String
    end

    def run
      slack = Slack.new(token: ENV["SLACK_TOKEN"])

      slack.on(Slack::Event::Message) do |session, event|
        if event = event.as?(Slack::Event::Message) # weird casting here.. can i put it in slack.cr?
          if event.from(session.me)
            # This message is from me, dont reply to me
            next
          end
          if session.me.as?(Slack::User)
            event_text = event.text.downcase

            if event.mentions("help")
              reply = String.build do |reply|
                reply << "take PO{X} - take a po environment\n"
                reply << "done PO{X} - release a po environment\n"
                reply << "who PO{X} - show who has a PO environment\n"
                reply << "free - show the current used envs"
              end

              session.send(event.reply(text: reply))
              next
            end

            if event.mentions("free")
              if @envs.empty?
                session.send(event.reply("Looks like all environments are free :thinking_face:"))
                next
              end

              if @envs.size == 1
                session.send(event.reply(text: "#{@envs.keys.join(",")} is currently in use"))
              else
                session.send(event.reply(text: "#{@envs.keys.join(",")} are currently in use"))
              end

              next
            end

            who = event_text.match(/who (po\d*)/)
            if who
              if who[1]
                puts "Checking who for #{who[1]}"
                if @envs[who[1]]
                  session.send(event.reply(text: "<@#{@envs[who[1]]}> is using #{who[1]}"))
                end
              end

              next
            end

            environment = event_text.match(/.*(po\d*)\s?.*/)
            next unless environment
            next unless environment[1]

            taking = event_text =~ /.*taking.*/
            done = event_text =~ /.*done.*/

            if taking
              status = "Looks like <@#{event.user}> is taking #{environment[1]}"
              @envs[environment[1]] = event.user
            elsif done
              status = "Looks like <@#{event.user}> is done #{environment[1]}"
              @envs.delete(environment[1])
            end

            puts status
            puts @envs

          end
        end
      end

      spawn {
        slack.run
      }

      sleep
    end
  end
end
