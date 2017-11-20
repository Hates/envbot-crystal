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
            if event.mentions("status")
              reply = event.reply(text: @envs.to_s)
              session.send(reply)
              next
            end

            event_text = event.text.downcase

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
