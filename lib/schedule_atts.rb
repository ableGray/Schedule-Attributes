require 'ice_cube'
require 'active_support'
require 'active_support/time_with_zone'
require 'ostruct'

module ScheduleAtts
  # Your code goes here...
  DAY_NAMES = Date::DAYNAMES.map(&:downcase).map(&:to_sym)
  def schedule
    @schedule ||= begin
      if schedule_yaml.blank?
        IceCube::Schedule.new(Date.today.to_time).tap{|sched| sched.add_recurrence_rule(IceCube::Rule.daily) }
      else
        IceCube::Schedule.from_yaml(schedule_yaml)
      end
    end
  end

  def schedule_attributes=(options)
    options = options.dup
    options[:interval] = options[:interval].to_i
    options[:start_date] &&= ScheduleAttributes.parse_in_timezone(options[:start_date]) # IS: in icecube master, start_date is deprecated in favor of start_time
    options[:date]       &&= ScheduleAttributes.parse_in_timezone(options[:date])
    # options[:until_date] &&= ScheduleAttributes.parse_in_timezone(options[:until_date])
    options[:end_time] &&= ScheduleAttributes.parse_in_timezone(options[:end_time]) if options[:ends] == 'eventually'  # IS: in icecube master, end_time is deprecated in favor of until_time

    if options[:repeat].to_i == 0
      @schedule = IceCube::Schedule.new(options[:date])
      @schedule.add_recurrence_date(options[:date])
    else
      @schedule = IceCube::Schedule.new(options[:start_date], options)

      rule = case options[:interval_unit]
        when 'day'
          IceCube::Rule.daily options[:interval]
        when 'week'
          IceCube::Rule.weekly(options[:interval]).day( *IceCube::DAYS.keys.select{|day| options[day].to_i == 1 } )
        when 'month'
          IceCube::Rule.monthly options[:interval]
      end

      rule.until(options[:end_time]) if options[:ends] == 'eventually'

      @schedule.add_recurrence_rule(rule)
    end

    self.schedule_yaml = @schedule.to_yaml
  end

  def schedule_attributes
    atts = {}

    s = schedule_yaml ? IceCube::Schedule.from_yaml(schedule_yaml) : schedule

    if rule = s.rrules.last
      atts[:repeat]     = 1
      atts[:start_date] = s.start_date.to_date
      atts[:date]       = Date.today # for populating the other part of the form

      rule_hash = rule.to_hash
      atts[:interval] = rule_hash[:interval]

      case rule
      when IceCube::DailyRule
        atts[:interval_unit] = 'day'
      when IceCube::WeeklyRule
        atts[:interval_unit] = 'week'
        rule_hash[:validations][:day].each do |day_idx|
          atts[ DAY_NAMES[day_idx] ] = 1
        end
      when IceCube::MonthlyRule
        atts[:interval_unit] = 'month'
      end

      if rule.until_date
        atts[:until_date] = rule.until_date.to_date
        atts[:end_time] = rule.until_date.to_date
        atts[:ends] = 'eventually'
      else
        atts[:ends] = 'never'
      end
    else
      atts[:repeat]     = 0
      atts[:date]       = s.start_date.to_date
      atts[:start_date] = Date.today # for populating the other part of the form
    end

    OpenStruct.new(atts)
  end

  # TODO: test this
  def self.parse_in_timezone(str)
    if Time.respond_to? :zone
      Time.zone.parse(str)
    else
      Time.parse(str)
    end
  end
end

# TODO: we shouldn't need this
ScheduleAttributes = ScheduleAtts

#TODO: this should be merged into ice_cube, or at least, make a pull request or something.
class IceCube::Rule
  def ==(other)
    to_hash == other.to_hash
  end
end

class IceCube::Schedule
  def ==(other)
    to_hash == other.to_hash
  end
end

