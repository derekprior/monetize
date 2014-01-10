module Monetize
  class CentExtractor
    def initialize(input, currency)
      @input = input
      @currency = currency
    end

    def extract
      # extract method: removes currencies/non-value stuff
      num = input.gsub(/[^\d.,'-]/, '')

      # checking to see if it's negative
      negative = num =~ /^-|-$/ ? true : false

      # what is the decimal character for current currency
      decimal_char = currency.decimal_mark

      # redundancy - removes the negative.
      num = num.sub(/^-|-$/, '') if negative

      if num.include?('-')
        raise ArgumentError, "Invalid currency amount (hyphen)"
      end

      # removes ending characters that are... problematic?
      num.chop! if num.match(/[\.|,]$/)

      # finds non digits and calls them delimiters (assume . ,)
      used_delimiters = num.scan(/[^\d]/)

      case used_delimiters.uniq.length
      when 0
        major, minor = num, 0
      when 2
        thousands_separator, decimal_mark = used_delimiters.uniq

        major, minor = num.gsub(thousands_separator, '').split(decimal_mark)
        min = 0 unless min
      when 1
        decimal_mark = used_delimiters.first

        # Does the parsed decimal mark the currency dec mark?
        if decimal_char == decimal_mark
          major, minor = num.split(decimal_char)
        else
          # did they mean thousands sep??

          # this comment is a lie??
          if num.scan(decimal_mark).length > 1 # multiple matches; treat as decimal_mark
            # assume thousands sep
            major, minor = num.gsub(decimal_mark, ''), 0
          else

            # unexpected delimeter, but appear once
            possible_major, possible_minor = num.split(decimal_mark)
            possible_major ||= "0"
            possible_minor ||= "00"

            # how long is the possible minor string?
            if possible_minor.length != 3 # thousands_separator

              # 100,00 for example - go with the parsed string
              major, minor = possible_major, possible_minor
            else
              if possible_major.length > 3
                # the 100000,00
                # must be a decimal sep so we use the parsed strings
                major, minor = possible_major, possible_minor
              else

                # less than or eq to three
                # 10,000
                # 100,000 for example (major!)
                if decimal_mark == '.'

                  # assume delim is the decimal point
                  major, minor = possible_major, possible_minor
                else

                  # the whole thing is the major - use it all
                  major, minor = "#{possible_major}#{possible_minor}", 0
                end
              end
            end
          end
        end
      else
        raise ArgumentError, "Invalid currency amount"
      end

      cents = major.to_i * currency.subunit_to_unit
      minor = minor.to_s
      minor = if minor.size < currency.decimal_places
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

      cents += minor

      negative ? cents * -1 : cents
    end

    private

    attr_reader :input, :currency
  end
end
