module Monetize
  class CentExtractor
    def initialize(input, currency)
      @value_string = input.gsub(/[^\d.,'-]/, '')
      @currency = currency

      if value_string =~ /^-|-$/
        @is_negative = true
        value_string.sub!('-','')
      end

      if value_string.match(/[\.|,]$/)
        value_string.chop!
      end

      @used_delimiters = value_string.scan(/[^\d]/)
    end

    def to_cents
      cents = major_cents + minor_cents

      # Where??
      if negative?
        cents * -1
      else
        cents
      end
    end

    def major_cents
      major_part.to_i * currency.subunit_to_unit
    end

    def minor_cents
      #minor = minor.to_s
      minor = minor_part
      if minor.size < currency.decimal_places
        # 5
        # 500
        # 50
        (minor + ("0" * currency.decimal_places))[0,currency.decimal_places].to_i
      elsif minor.size > currency.decimal_places
        # roudning cents
        if minor[currency.decimal_places,1].to_i >= 5
          minor[0,currency.decimal_places].to_i+1
        else
          minor[0,currency.decimal_places].to_i
        end
      else
        minor.to_i
      end
    end

    def major_part
      parts[0]
    end

    def minor_part
      parts[1]
    end

    def parts
      @parts ||= parse
    end

    def parse
      num = value_string

      if num.include?('-')
        raise ArgumentError, "Invalid currency amount (hyphen)"
      end

      case used_delimiters.uniq.length
      when 0
        major, minor = parse_with_no_delimiters(num)
      when 1
        major, minor = parse_with_one_delimiter(num, used_delimiters)
      when 2
        major, minor = parse_with_two_delimiters(num, used_delimiters)
      else
        raise ArgumentError, "Invalid currency amount"
      end

      [ major, minor ]

    end

    private

    attr_reader :value_string, :currency, :used_delimiters

    def negative?
      @is_negative
    end

    def currency_decimal_mark
      currency.decimal_mark
    end

    def parse_with_no_delimiters(value_string)
      [ value_string, "0" ]
    end

    def parse_with_two_delimiters(value_string, used_delimiters)
      thousands_separator, decimal_mark = used_delimiters.uniq
      value_string.gsub(thousands_separator, '').split(decimal_mark)
    end

    def parse_with_one_delimiter(value_string, used_delimiters)
      decimal_mark = used_delimiters.first

      # Does the parsed decimal mark the currency dec mark?
      if currency_decimal_mark == decimal_mark
        value_string.split(currency_decimal_mark)
      else
        if value_string.scan(decimal_mark).length > 1
          # assume thousands sep
          [ value_string.gsub(decimal_mark, ''), "0" ]
        else
          # unexpected delimeter, but appear once
          possible_major, possible_minor = value_string.split(decimal_mark)
          possible_major ||= "0"
          possible_minor ||= "00"

          # how long is the possible minor string?
          if possible_minor.length != 3 # thousands_separator

            # 100,00 for example - go with the parsed string
            [ possible_major, possible_minor ]
          else
            if possible_major.length > 3
              # the 100000,00
              # must be a decimal sep so we use the parsed strings
              [ possible_major, possible_minor ]
            else
              # less than or eq to three
              if decimal_mark == '.'

                # assume delim is the decimal point
                [ possible_major, possible_minor ]
              else

                # the whole thing is the major - use it all
                [ "#{possible_major}#{possible_minor}", "0" ]
              end
            end
          end
        end
      end
    end
  end
end
