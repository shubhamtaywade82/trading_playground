# frozen_string_literal: true

require_relative '../patterns/head_and_shoulders'
require_relative '../patterns/double_top_bottom'
require_relative '../patterns/triangle'
require_relative '../patterns/flag_pennant'
require_relative '../patterns/engulfing'

class PatternEngine
  PATTERNS = [
    HeadAndShoulders,
    DoubleTopBottom,
    Triangle,
    FlagPennant
  ].freeze

  def self.run(context)
    candles_15m = context[:candles_15m]
    candles_5m  = context[:candles_5m]

    PATTERNS.each do |pattern_class|
      instance = build_instance(pattern_class, context)
      next unless instance.valid?

      return instance
    end

    # Engulfing needs optional support/resistance
    eng = Engulfing.new(
      candles_5m,
      support_level: context[:support_level],
      resistance_level: context[:resistance_level]
    )
    return eng if eng.valid?

    nil
  end

  def self.build_instance(klass, context)
    case klass.name
    when 'HeadAndShoulders'
      HeadAndShoulders.new(context[:candles_15m], context[:candles_5m])
    when 'DoubleTopBottom'
      DoubleTopBottom.new(context[:candles_15m], context[:candles_5m])
    when 'Triangle'
      Triangle.new(context[:candles_15m], context[:candles_5m])
    when 'FlagPennant'
      FlagPennant.new(context[:candles_15m], context[:candles_5m])
    else
      klass.new(context[:candles_15m], context[:candles_5m])
    end
  end
end
