# frozen_string_literal: true

class BasePattern
  attr_reader :signal

  def initialize
    @signal = nil
  end

  def valid?
    raise NotImplementedError
  end

  def direction
    raise NotImplementedError
  end
end
