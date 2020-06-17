require 'byebug'                # optional, may be helpful
require 'open-uri'              # allows open('http://...') to return body
require 'cgi'                   # for escaping URIs
require 'nokogiri'              # XML parser
require 'active_model'          # for validations

class OracleOfBacon

  class InvalidError < RuntimeError ; end
  class NetworkError < RuntimeError ; end
  class InvalidKeyError < RuntimeError ; end

  attr_accessor :from, :to
  attr_reader :api_key, :response, :uri
  
  include ActiveModel::Validations
  validates_presence_of :from
  validates_presence_of :to
  validates_presence_of :api_key
  validate :from_does_not_equal_to

  # Checks that from name is distinct from to name
  def from_does_not_equal_to
    # YOUR CODE HERE
    errors.add(:from, 'From cannot be the same as To') if
      @from == @to
  end

  def initialize(api_key='38b99ce9ec87')
    # your code here
    @api_key = api_key
    @from = @to = 'Kevin Bacon'
    # A minimal RESTful query URI for OOB must include
    # the API key (parameter p), the actor from which
    # to start search (parameter a), and optionally
    # the actor to connect to (optional parameter b;
    # defaults to Kevin Bacon if omitted)
    # Ex. 1 http://oracleofbacon.org/cgi-bin/xml?p=38b99ce9ec87&a=Kevin+Bacon&b=Laurence+Olivier
    # Ex. 2 http://oracleofbacon.org/cgi-bin/xml?p=38b99ce9ec87&a=Carrie+Fisher+(I)&b=Ian+McKellen
  end

  def find_connections
    make_uri_from_arguments
    begin
      xml = URI.parse(uri).read
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
      Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
      Net::ProtocolError => e
      # convert all of these into a generic OracleOfBacon::NetworkError,
      #  but keep the original error message
      # your code here
      raise NetworkError
    end
    # your code here: create the OracleOfBacon::Response object
    @response = Response.new(xml)
  end

  # escaped special characters and builds URI
  def make_uri_from_arguments
    # your code here: set the @uri attribute to properly-escaped URI
    #  constructed from the @from, @to, @api_key arguments
    escaped_from = CGI.escape(@from)
    escaped_to = CGI.escape(@to)
    @uri = 'http://oracleofbacon.org/cgi-bin/xml?p=' + @api_key + '&a=' +
           escaped_from + '&b=' + escaped_to
  end

  # OracleOfBacon::Response to hold a response from the service.
  # It exposes the 'type' and 'data' attribute to the caller.
  # Nested in OracleOfBacon as it is rarely used outside parent class.
  class Response
    attr_reader :type, :data
    # create a Response object from a string of XML markup.
    def initialize(xml)
      @doc = Nokogiri::XML(xml)
      parse_response
    end

    private

    # three response types (graph, spellcheck, error) and unknown
    def parse_response
      if !@doc.xpath('/error').empty?
        parse_error_response
      # your code here: 'elsif' clauses to handle other responses
      # for responses not matching the 3 basic types, the Response
      # object should have type 'unknown' and data 'unknown response'
      elsif !@doc.xpath('/link').empty?
        parse_successful_response
      elsif !@doc.xpath('/spellcheck').empty?
        parse_spellcheck_response
      else
        parse_unknown_response
      end
    end

    def parse_error_response
      @type = :error
      @data = 'Unauthorized access'
    end

    def parse_successful_response
      @type = :graph
      # get all actors and movies
      actors = []
      @doc.xpath('//actor').each do |actor|
        actors << actor.text
      end
      movies = []
      @doc.xpath('//movie').each do |movie|
        movies << movie.text
      end
      # combine them [actor, movie, actor, ...]
      @data = actors.zip(movies).flatten.compact
    end

    def parse_spellcheck_response
      @type = :spellcheck
      # all potential matches
      spellcheck_matches = []
      @doc.xpath('//match').each do |match|
        spellcheck_matches << match.text
      end
      @data = spellcheck_matches
    end

    def parse_unknown_response
      @type = :unknown
      @data = 'unknown response'
    end
  end
end

