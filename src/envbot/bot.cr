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
        if event = event.as?(Slack::Event::Message) # weird casting here.. can i put it in slack.cr?
          if event.from(session.me)
            # This message is from me, dont reply to me
            next
          end
          if session.me.as?(Slack::User)
            event_text = event.text.downcase

            if event.mentions("help")
              reply = String.build do |reply|
                reply << "*envbot instructions :joan:*\n"
                reply << "take|taking|using {X} - take an environment\n"
                reply << "done|finished {X} - release an environment\n"
                reply << "who|show {X} - show who has an environment\n"
                reply << "envs - show the current environments\n"
                reply << "free - show the current free envs\n"
                reply << "taken - show the current used envs\n"
              end

              session.send(event.reply(text: reply))
              next
            end

            if event.mentions("envs")
              session.send(event.reply(text: "#{@envs.keys.map { |e| e.upcase }.join(", ")} at your service :thisisfine:"))
              next
            end

            if event.mentions("free")
              free_environments = @envs.reject { |k,v| !v.nil? }
              if free_environments.size == @envs.size
                session.send(event.reply("Looks like all environments are free :fry:"))
              elsif free_environments.size == 0
                session.send(event.reply("Looks like all environments are taken :aliens:"))
              elsif free_environments.size == 1
                session.send(event.reply(text: "#{free_environments.keys.first.upcase} is free"))
              else
                session.send(event.reply(text: "#{free_environments.keys.map { |e| e.upcase }.join(", ")} are free"))
              end

              next
            end

            if event.mentions("taken")
              taken_environments = @envs.reject { |k,v| v.nil? }
              if taken_environments.size == @envs.size
                session.send(event.reply("Looks like all environments are taken :aliens:"))
              elsif taken_environments.size == 0
                session.send(event.reply("Looks like all environments are free :fry:"))
              elsif taken_environments.size == 1
                session.send(event.reply(text: "#{taken_environments.keys.first.upcase} is taken"))
              else
                session.send(event.reply(text: "#{taken_environments.keys.map { |e| e.upcase }.join(", ")} are taken"))
              end

              next
            end

            who_match_query = /(who|show).*(#{@envs.keys.join("|")}).*/i
            puts "Who query regex: #{who_match_query}"
            who = event_text.match(who_match_query)
            puts "Who query env: #{who}"

            if who
              if who[2]
                who_env = who[2].upcase
                if @envs.has_key?(who_env)
                  if @envs[who_env]
                    session.send(event.reply(text: "<@#{@envs[who_env]}> is using #{who_env}"))
                  else
                    session.send(event.reply(text: "Looks like no one is using #{who_env} :woah:"))
                  end
                end
              end

              next
            end

            env_match_query = /.*(#{@envs.keys.join("|")}).*/i
            puts "Query regex: #{env_match_query}"
            query_env = event_text.match(env_match_query)
            puts "Query env: #{query_env}"

            next unless query_env
            next unless query_env[1]

            taking = event_text =~ /.*(TAKE|TAKING|USING).*/i
            done = event_text =~ /.*(DONE|FINISHED).*/i

            if taking
              status = "Looks like #{event.user} is taking #{query_env[1].upcase}"
              @envs[query_env[1].upcase] = event.user
            elsif done
              status = "Looks like #{event.user} is done #{query_env[1].upcase}"
              @envs[query_env[1].upcase] = nil
            end

            puts status
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
