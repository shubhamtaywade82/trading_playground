# frozen_string_literal: true

class OptionFilters
  IV_PERCENTILE_MAX = 70
  MIN_DTE = 2

  def self.allowed?(iv_percentile:, dte:)
    (iv_percentile.nil? || iv_percentile < IV_PERCENTILE_MAX) &&
      (dte.nil? || dte >= MIN_DTE)
  end
end
