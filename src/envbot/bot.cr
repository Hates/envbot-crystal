require "slack"

module EnvBot
  class Bot
    getter slack

    def initialize()
      @envs = {} of String => (String | Nil)
      @slack = Slack.new(token: ENV["SLACK_TOKEN"])

      ENV["ENVS"].split(",").each do |env|
        @envs[env] = nil
      end
    end

    def run
      @slack.on(Slack::Event::Message) do |session, event|
        if event = event.as?(Slack::Event::Message)
          if event.from(session.me)
            # This message is from me, dont reply to me
            next
          end

          if session.me.as?(Slack::User)
            event_text = event.text.downcase

            if event.mentions("^help$")
              session.send(event.reply(text: help_reply))
              next
            end

            if event.mentions("^envs$")
              reply = envs_reply(session, "Current Environments", "", @envs)
              session.send(event.reply(text: reply))
              next
            end

            if event.mentions("^free$")
              reply = envs_reply(session, "Current Free Environments", "Looks like there are no free environments :aliens:", @envs.reject { |k,v| !v.nil? })
              session.send(event.reply(text: reply))
              next
            end

            if event.mentions("^taken$")
              reply = envs_reply(session, "Current Taken Environments", "Looks like there are no taken environments :aliens:", @envs.reject { |k,v| v.nil? })
              session.send(event.reply(text: reply))
              next
            end

            who_match_query = /(WHO|SHOW).*(#{@envs.keys.join("|")}).*/i
            who = event_text.match(who_match_query)

            if who && who[2]
              who_env = who[2].upcase
              if @envs.has_key?(who_env)
                if @envs[who_env]
                  session.send(event.reply(text: "<@#{@envs[who_env]}> is using #{who_env}"))
                else
                  session.send(event.reply(text: "Looks like no one is using #{who_env} :tumbleweed:"))
                end
              end

              next
            end

            env_match_query = /.*(#{@envs.keys.join("|")}).*/i
            query_env = event_text.match(env_match_query)

            next unless query_env
            next unless query_env[1]

            taking = event_text =~ /.*(TAKE|TAKING|USING|GRABBING).*/i
            done = event_text =~ /.*(DONE|FINISHED).*/i

            user = session.users.by_id[event.user]

            if taking
              status = "`#{user}` now has #{query_env[1].upcase}"
              @envs[query_env[1].upcase] = event.user
              session.send(event.reply(text: status))
            elsif done
              status = "`#{user}` is done with #{query_env[1].upcase}"
              @envs[query_env[1].upcase] = nil
              session.send(event.reply(text: status))
            end
          end
        end
      end

      spawn {
        slack.run
      }

      sleep
    end

    def help_reply
      String.build do |reply|
        reply << "*envbot instructions :joan:*\n"
        reply << "`take|taking|using|grabbing {X}` - take an environment\n"
        reply << "`done|finished {X}` - release an environment\n"
        reply << "`who|show {X}` - show who has an environment\n"
        reply << "`envs` - show the current environments\n"
        reply << "`free` - show the current free envs\n"
        reply << "`taken` - show the current used envs\n"
      end
    end

    def envs_reply(session : Slack, title, empty_title, envs)
      if envs.size == 0
        return empty_title
      end

      String.build do |reply|
        reply << "*#{title}*\n"
        envs.each do |k,v|
          if envs[k].nil?
            reply << "#{k}: `Free`\n"
          else
            user = session.users.by_id[envs[k]]
            reply << "#{k}: Taken by `#{user}`\n"
          end
        end
      end
    end
  end
end
