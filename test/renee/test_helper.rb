require 'rubygems'
gem 'minitest'
require 'minitest/autorun'
gem 'rack-test'
require 'rack/test'
$: << File.expand_path('../../lib', __FILE__)
require 'renee'

class ColoredIO
  ESC = "\e["
  NND = "#{ESC}0m"

  def initialize(io)
    @io = io
  end

  def print(o)
    case o
    when "."
      @io.send(:print, "#{ESC}32m#{o}#{NND}")
    when "E"
      @io.send(:print, "#{ESC}33m#{o}#{NND}")
    when "F"
      @io.send(:print, "#{ESC}31m#{o}#{NND}")
    else
      @io.send(:print, o)
    end
  end

  def puts(*o)
    super
  end
end

MiniTest::Unit.output = ColoredIO.new(MiniTest::Unit.output)

## TEST HELPERS
class MiniTest::Spec
  include Rack::Test::Methods

  def default_views_path
    File.dirname(__FILE__) + "/views"
  end

  def blog_app
    file = File.expand_path("../../../examples/blog/config.ru", __FILE__)
    app = Rack::Builder.parse_file(file).first
    @app = Rack::Lint.new(app)
  end

  def app
    @app
  end

  alias :response :last_response
end
