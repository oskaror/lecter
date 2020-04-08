# frozen_string_literal: true

class Lecter::Rack
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    if request.params['lecter_analysis']
      thread = Thread.current
      thread[:items] = ''
      tp = TracePoint.new(:line, :class, :call, :c_call, :return) do |tp|
        if tp.path &&
           !tp.path.include?('/app/views') &&
           !tp.path.include?('/app/helpers') &&
           tp.path.include?(Rails.root.to_s) &&
           # tp.path.include?('/Users/neodelf/.rvm/gems/ruby-2.6.4@test_app/gems/rubocop-0.74.0/lib/rubocop/cop/layout/multiline_method_call_indentation.rb')||
           # tp.path.include?('/Users/neodelf/.rvm/gems/ruby-2.6.4@test_app/gems/rubocop-0.74.0/lib/rubocop/cop/layout/multiline_assignment_layout.rb')) &&
           tp.method_id != :method_added &&
           tp.defined_class != Module &&
           tp.defined_class != Class &&
           tp.defined_class != String &&
           tp.defined_class != Kernel &&
           tp.defined_class != NilClass

          thread[:items] += [tp.path, tp.lineno, tp.defined_class, tp.method_id, tp.event].join(' ') + ';'
        end
      end
      tp.enable
      ActionController::Base.allow_forgery_protection = false
    end

    status, headers, response = @app.call(env)

    if tp
      response = [status.to_s + thread[:items]]
      status = 200
      headers = {}
    end

    [status, headers, response]
  ensure
    if tp
      tp.disable
      ActionController::Base.allow_forgery_protection = true
      Thread.current[:items] = nil
    end
  end
end
