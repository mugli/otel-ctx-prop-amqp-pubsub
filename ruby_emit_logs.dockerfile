FROM ruby:3.1.2
WORKDIR /app
COPY Gemfile .
COPY Gemfile.lock .
RUN bundle install
COPY ruby_emit_logs.rb .
CMD ["ruby", "ruby_emit_logs.rb"]
