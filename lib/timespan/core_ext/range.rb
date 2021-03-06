class TimespanRange < DelegateDecorator
  attr_accessor :unit, :range

  def initialize range, unit = :minutes
    range = (0..60) if range.min == nil || range.max == nil
    super(range, except: %w{to_s to_str})
    @range = Timespan.new between: range
    @unit = unit.to_s.pluralize.to_sym
  end

  def to_str
    to_s
  end

  def to_s
    range.min.nil? ? 'no timespan range' : "#{range.min} to #{range.max} #{unit}"
  end
end

class DurationRange < DelegateDecorator
  attr_accessor :unit, :range

  def initialize range, unit = :minutes
    range = (0..60) if range.min == nil || range.max == nil  
    super(range, except: %w{to_s to_str})
    @unit = unit.to_s.pluralize.to_sym
    @range = range
  end

  def to_str
    to_s
  end

  def to_s
    range.min.nil? ? 'no duration range' : "#{range.min} to #{range.max} #{unit}"
  end

  def __evolve_to_duration_range__
    self
  end

  def mongoize
    {:from => range.min.to_i, :to => range.max.to_i}
  end

  def between? duration
    obj = case duration
    when Duration
      duration
    else
      Duration.new duration
    end
    obj.total >= min && obj.total <= max
  end

  class << self
    # See http://mongoid.org/en/mongoid/docs/upgrading.html        

    # Serialize a Hash (with DurationRange keys) or a DurationRange to
    # a BSON serializable type.
    #
    # @param [Timespan, Hash, Integer, String] value
    # @return [Hash] Timespan in seconds
    def mongoize object
      mongoized = case object
      when DurationRange then object.mongoize
      when Hash
        object
      when Range
        object.send(:seconds).mongoize
      else
        object
      end
      # puts "mongoized: #{mongoized} - Hash"
      mongoized
    end

    # Deserialize a Timespan given the hash stored by Mongodb
    #
    # @param [Hash] Timespan as hash
    # @return [Timespan] deserialized Timespan
    def demongoize(object)
      return if !object
      
      demongoized = case object
      when Hash
        object.__evolve_to_duration_range__
      else
        raise "Unable to demongoize DurationRange from: #{object}"
      end    
      # puts "demongoized: #{demongoized} - #{demongoized.class}"
      demongoized
    end

    # Converts the object that was supplied to a criteria and converts it
    # into a database friendly form.
    def evolve(object)
      object.__evolve_to_duration_range__.mongoize
    end 

    protected

    def parse duration
      if duration.kind_of? Numeric
         return Duration.new duration
      else
        case duration
        when Timespan
          duration.duration
        when Duration
          duration
        when Hash
          Duration.new duration
        when Time
          duration.to_i
        when DateTime, Date
          duration.to_time.to_i
        when String
          Duration.new parse_duration(duration)
        else
          raise ArgumentError, "Unsupported duration type: #{duration.inspect} of class #{duration.class}"
        end 
      end
    end

  end 
end

class Range
  [:seconds, :minutes, :hours, :days, :weeks, :months, :years].each do |unit|
    define_method unit do |type = :duration|
      timerange = Range.new self.min.send(unit), self.max.send(unit)
      type == :timespan ? TimespanRange.new(timerange, unit) : DurationRange.new(timerange, unit)      
    end
  end
end