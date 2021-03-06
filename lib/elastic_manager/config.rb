require 'json'
require 'yajl'
require 'elastic_manager/logger'

module Config
  include Logging

  MAIN_PARAMS = %w[TASK INDICES FROM TO]
  MAIN_PARAMS.freeze

  ADDITIONAL_PARAMS = %w[ES_URL TIMEOUT_WRITE TIMEOUT_CONNECT TIMEOUT_READ RETRY SLEEP FORCE SETTINGS]
  ADDITIONAL_PARAMS.freeze

  BANNER_ENV = "Missing argument: #{MAIN_PARAMS.join(', ')}. "
  BANNER_ENV << "Usage: #{MAIN_PARAMS.map{ |p| "#{p}=#{p}"}.join(' ')} "
  BANNER_ENV << "#{ADDITIONAL_PARAMS.map{ |p| "#{p}=#{p}"}.join(' ')} elastic_manager"

  BANNER_ARGV = "Missing argument: #{MAIN_PARAMS.join(', ')}. "
  BANNER_ARGV << "Usage: elastic_manager #{MAIN_PARAMS.map{ |p| "--#{p.downcase}=#{p.downcase}"}.join(' ')} "
  BANNER_ARGV << "#{ADDITIONAL_PARAMS.map{ |p| "--#{p.downcase}=#{p.downcase}"}.join(' ')}"

  def make_default_config
    default = Hash.new { |hash, key| hash[key] = Hash.new(&hash.default_proc) }

    default['es']['url']          = 'http://127.0.0.1:9200'
    default['retry']              = '10'
    default['sleep']              = '60'
    default['force']              = 'false'
    default['timeout']['write']   = '2'
    default['timeout']['connect'] = '3'
    default['timeout']['read']    = '60'
    default['settings']           = {}

    log.debug "default config: #{default.inspect}"
    default
  end

  def option_parser(result)
    OptionParser.new do |parser|
      MAIN_PARAMS.each do |param|
        parser.on("--#{param.downcase}=#{param}") do |pr|
          result[param.downcase] = pr
        end
      end

      ADDITIONAL_PARAMS.each do |param|
        parser.on("--#{param.downcase}=#{param}") do |pr|
          params = param.split('_')

          if params.length == 2
            result[params[0].downcase][params[1].downcase] = pr
          elsif params.length == 1
            if params[0].downcase == 'settings'
              result[params[0].downcase] = json_parse(pr)
            else
              result[params[0].downcase] = pr
            end
          end
        end
      end
    end.parse!

    result
  end

  def get_env_vars(var, result)
    vars = var.split('_')

    if vars.length == 2
      result[vars[0].downcase][vars[1].downcase] = ENV[var]
    elsif vars.length == 1
      if vars[0].downcase == 'settings'
        result[vars[0].downcase] = json_parse(ENV[var])
      else
        result[vars[0].downcase] = ENV[var]
      end
    end

    result
  end

  def env_parser(result)
    MAIN_PARAMS.each do |var|
      if ENV[var] == '' || ENV[var].nil?
        log.fatal BANNER_ENV
        exit 1
      end

      result[var.downcase] = ENV[var]
    end

    ADDITIONAL_PARAMS.each do |var|
      result = get_env_vars(var, result) unless ENV[var] == '' || ENV[var].nil?
    end

    result
  end

  def load_from_env
    log.debug "will load config from ENV variables"

    result = make_default_config
    result = env_parser(result)

    log.debug "env config: #{result.inspect}"
    result
  end

  def load_from_argv
    require 'optparse'

    log.debug "will load config from passed arguments"
    result = make_default_config
    result = option_parser(result)

    if MAIN_PARAMS.map { |p| p.downcase }.map { |key| result[key].empty? }.any?{ |a| a == true }
      log.fatal BANNER_ARGV
      exit 1
    end

    log.debug "argv config: #{result.inspect}"
    result
  end
end
