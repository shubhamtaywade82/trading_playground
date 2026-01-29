# frozen_string_literal: true

# Represents a valid pattern signal. Execute via broker (DhanHQ, etc.) when wired.
# Named PatternSignal to avoid conflict with Ruby's built-in Signal.
class PatternSignal
  attr_reader :direction, :pattern, :sl, :tp, :payload

  def initialize(direction, pattern: nil, sl: nil, tp: nil, payload: {})
    @direction = direction
    @pattern = pattern
    @sl = sl
    @tp = tp
    @payload = payload
  end

  def execute
    # Placeholder: wire to DhanHQ or Delta when ready.
    { direction: direction, pattern: pattern, sl: sl, tp: tp }
  end
end
